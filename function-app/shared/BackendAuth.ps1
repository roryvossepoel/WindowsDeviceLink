using namespace System.Security.Cryptography
using namespace System.Security.Cryptography.X509Certificates
using namespace System.Text

function Get-WindowsDeviceLinkBackendMetadata {
    [ordered]@{
        apiVersion = '1.0'
        minimumModuleVersion = '0.10.0'
        capabilities = @('TenantCatalog','MultitenantLookup','Reconcile','Offboarding')
    }
}

function Test-WindowsDeviceLinkSharedSecret {
    param(
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Provided
    )

    $left = [Encoding]::UTF8.GetBytes($Expected)
    $right = [Encoding]::UTF8.GetBytes($Provided)
    if ($left.Length -ne $right.Length) { return $false }
    [CryptographicOperations]::FixedTimeEquals($left, $right)
}

function ConvertTo-Base64Url {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
}

function Get-BackendCertificate {
    param(
        [Parameter(Mandatory)][string]$CredentialSetting,
        [string]$PasswordSetting
    )

    $pfxBase64 = [Environment]::GetEnvironmentVariable($CredentialSetting)
    if ([string]::IsNullOrWhiteSpace($pfxBase64)) { return $null }

    try {
        $bytes = [Convert]::FromBase64String($pfxBase64)
        $password = if ($PasswordSetting) { [Environment]::GetEnvironmentVariable($PasswordSetting) } else { $null }
        return [X509Certificate2]::new(
            $bytes,
            $password,
            [X509KeyStorageFlags]::EphemeralKeySet
        )
    }
    catch {
        throw 'The configured Graph certificate could not be loaded from the Key Vault-backed application setting.'
    }
}

function New-ClientAssertion {
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][X509Certificate2]$Certificate
    )

    $now = [DateTimeOffset]::UtcNow
    $audience = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $header = @{
        alg = 'RS256'
        typ = 'JWT'
        x5t = ConvertTo-Base64Url -Bytes $Certificate.GetCertHash()
    } | ConvertTo-Json -Compress

    $payload = @{
        aud = $audience
        iss = $ClientId
        sub = $ClientId
        jti = [guid]::NewGuid().ToString()
        nbf = $now.AddMinutes(-2).ToUnixTimeSeconds()
        exp = $now.AddMinutes(8).ToUnixTimeSeconds()
    } | ConvertTo-Json -Compress

    $unsigned = '{0}.{1}' -f (
        ConvertTo-Base64Url -Bytes ([Encoding]::UTF8.GetBytes($header))
    ),(
        ConvertTo-Base64Url -Bytes ([Encoding]::UTF8.GetBytes($payload))
    )

    $rsa = [RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
    if (-not $rsa) { throw 'The configured certificate does not contain an RSA private key.' }

    try {
        $signature = $rsa.SignData(
            [Encoding]::UTF8.GetBytes($unsigned),
            [HashAlgorithmName]::SHA256,
            [RSASignaturePadding]::Pkcs1
        )
    }
    finally {
        $rsa.Dispose()
    }

    '{0}.{1}' -f $unsigned,(ConvertTo-Base64Url -Bytes $signature)
}

function Get-WindowsDeviceLinkBackendConfiguration {
    $raw = [Environment]::GetEnvironmentVariable('WINDOWSDEVICELINK_CONFIGURATION_JSON')
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw 'WINDOWSDEVICELINK_CONFIGURATION_JSON is not configured.'
    }
    if ([Text.Encoding]::UTF8.GetByteCount($raw) -gt 1MB) {
        throw 'The backend configuration exceeds 1 MiB.'
    }

    try { $document = $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'WINDOWSDEVICELINK_CONFIGURATION_JSON is not valid JSON.' }

    $rootFields = @('schemaVersion','mode','defaultTenantId','authenticationProfiles','tenants')
    foreach ($property in $document.PSObject.Properties) {
        if ($property.Name -cnotin $rootFields) { throw "Unknown backend configuration field '$($property.Name)'." }
    }
    if ($document.schemaVersion -isnot [int] -and $document.schemaVersion -isnot [long]) { throw 'schemaVersion must be integer 1.' }
    if ([int64]$document.schemaVersion -ne 1) { throw 'schemaVersion must be integer 1.' }
    if ([string]$document.mode -cne 'Backend') { throw "mode must be 'Backend'." }
    if (-not $document.authenticationProfiles -or $document.authenticationProfiles -isnot [pscustomobject]) {
        throw 'authenticationProfiles must be a non-empty JSON object.'
    }
    if ($document.tenants -isnot [array] -or @($document.tenants).Count -eq 0) {
        throw 'tenants must be a non-empty JSON array.'
    }

    $profiles = @{}
    foreach ($profileProperty in $document.authenticationProfiles.PSObject.Properties) {
        $profileName = [string]$profileProperty.Name
        $profile = $profileProperty.Value
        if ([string]::IsNullOrWhiteSpace($profileName) -or $profileName.Length -gt 128 -or $profileName -match '[\x00-\x1f\x7f]' -or $profile -isnot [pscustomobject]) {
            throw 'Every authentication profile must have a name and an object value.'
        }
        if ($profiles.ContainsKey($profileName.ToLowerInvariant())) { throw "Duplicate authentication profile '$profileName'." }
        foreach ($property in $profile.PSObject.Properties) {
            if ($property.Name -cnotin @('method','clientId','credentialSetting','certificatePasswordSetting')) {
                throw "Unknown field '$($property.Name)' in authentication profile '$profileName'."
            }
        }
        $method = [string]$profile.method
        if ($method -cnotin @('Certificate','ClientSecret')) {
            throw "Authentication profile '$profileName' must use Certificate or ClientSecret."
        }
        $clientId = [guid]::Empty
        if (-not [guid]::TryParse([string]$profile.clientId,[ref]$clientId) -or $clientId -eq [guid]::Empty) {
            throw "Authentication profile '$profileName' has an invalid clientId."
        }
        $credentialSetting = ([string]$profile.credentialSetting).Trim()
        if ($credentialSetting -notmatch '^WINDOWSDEVICELINK_GRAPH_[A-Z0-9_]{1,96}$') {
            throw "Authentication profile '$profileName' has an invalid credentialSetting."
        }
        $passwordSetting = ([string]$profile.certificatePasswordSetting).Trim()
        if ($passwordSetting -and ($method -ne 'Certificate' -or $passwordSetting -notmatch '^WINDOWSDEVICELINK_GRAPH_[A-Z0-9_]{1,96}$')) {
            throw "Authentication profile '$profileName' has an invalid certificatePasswordSetting."
        }
        $profiles[$profileName.ToLowerInvariant()] = [pscustomobject]@{
            Name = $profileName
            Method = $method
            ClientId = $clientId.ToString()
            CredentialSetting = $credentialSetting
            CertificatePasswordSetting = $passwordSetting
        }
    }
    if ($profiles.Count -eq 0) { throw 'At least one authentication profile is required.' }

    $tenants = @{}
    $names = @{}
    foreach ($tenant in @($document.tenants)) {
        if ($tenant -isnot [pscustomobject]) { throw 'Every tenant must be a JSON object.' }
        foreach ($property in $tenant.PSObject.Properties) {
            if ($property.Name -cnotin @('name','tenantId','authenticationProfile')) {
                throw "Unknown tenant field '$($property.Name)'."
            }
        }
        $name = ([string]$tenant.name).Trim()
        if ([string]::IsNullOrWhiteSpace($name) -or $name.Length -gt 128 -or $name -match '[\x00-\x1f\x7f]') {
            throw 'Every tenant must have a valid name of at most 128 characters.'
        }
        if ($names.ContainsKey($name.ToLowerInvariant())) { throw "Duplicate tenant name '$name'." }
        $tenantGuid = [guid]::Empty
        if (-not [guid]::TryParse([string]$tenant.tenantId,[ref]$tenantGuid) -or $tenantGuid -eq [guid]::Empty) {
            throw "Tenant '$name' has an invalid tenantId."
        }
        $tenantId = $tenantGuid.ToString()
        if ($tenants.ContainsKey($tenantId)) { throw "Duplicate tenantId '$tenantId'." }
        $profileKey = ([string]$tenant.authenticationProfile).Trim().ToLowerInvariant()
        if (-not $profiles.ContainsKey($profileKey)) { throw "Tenant '$name' references an unknown authentication profile." }
        $tenants[$tenantId] = [pscustomobject]@{
            Name = $name
            TenantId = $tenantId
            AuthenticationProfile = $profiles[$profileKey]
        }
        $names[$name.ToLowerInvariant()] = $true
    }

    $defaultTenantId = ([string]$document.defaultTenantId).Trim().ToLowerInvariant()
    if ($defaultTenantId) {
        $defaultGuid = [guid]::Empty
        if (-not [guid]::TryParse($defaultTenantId,[ref]$defaultGuid) -or -not $tenants.ContainsKey($defaultGuid.ToString())) {
            throw 'defaultTenantId must reference a configured tenant.'
        }
        $defaultTenantId = $defaultGuid.ToString()
    }

    [pscustomobject]@{ Tenants=$tenants; AuthenticationProfiles=$profiles; DefaultTenantId=$defaultTenantId }
}

function Get-WindowsDeviceLinkBackendTenant {
    param([Parameter(Mandatory)][string]$TenantId)
    $configuration = Get-WindowsDeviceLinkBackendConfiguration
    $parsed = [guid]::Empty
    if (-not [guid]::TryParse($TenantId,[ref]$parsed) -or -not $configuration.Tenants.ContainsKey($parsed.ToString())) {
        throw 'The requested tenant is not configured.'
    }
    $configuration.Tenants[$parsed.ToString()]
}

function Get-WindowsDeviceLinkBackendGraphToken {
    param(
        [Parameter(Mandatory)][string]$TenantId
    )

    $tenant = Get-WindowsDeviceLinkBackendTenant -TenantId $TenantId
    $profile = $tenant.AuthenticationProfile
    $ClientId = $profile.ClientId
    $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $certificate = $null
    $clientSecret = $null
    if ($profile.Method -eq 'Certificate') {
        $certificate = Get-BackendCertificate -CredentialSetting $profile.CredentialSetting -PasswordSetting $profile.CertificatePasswordSetting
    }
    else {
        $clientSecret = [Environment]::GetEnvironmentVariable($profile.CredentialSetting)
    }

    if ($certificate) {
        $assertion = $null
        try {
            $assertion = New-ClientAssertion -TenantId $TenantId -ClientId $ClientId -Certificate $certificate
            $body = @{
                client_id = $ClientId
                scope = 'https://graph.microsoft.com/.default'
                grant_type = 'client_credentials'
                client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
                client_assertion = $assertion
            }
            return (Invoke-RestMethod -Method POST -Uri $tokenUri -ContentType 'application/x-www-form-urlencoded' -Body $body -ErrorAction Stop).access_token
        }
        finally {
            $certificate.Dispose()
            $assertion = $null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($clientSecret)) {
        $body = @{
            client_id = $ClientId
            scope = 'https://graph.microsoft.com/.default'
            grant_type = 'client_credentials'
            client_secret = $clientSecret
        }
        return (Invoke-RestMethod -Method POST -Uri $tokenUri -ContentType 'application/x-www-form-urlencoded' -Body $body -ErrorAction Stop).access_token
    }

    throw "No Graph credential is configured for tenant '$TenantId'."
}

function Get-WindowsDeviceLinkAllowedTenants {
    @((Get-WindowsDeviceLinkBackendConfiguration).Tenants.Keys | Sort-Object)
}

function Get-WindowsDeviceLinkTenantNames {
    $result = @{}
    foreach ($tenant in (Get-WindowsDeviceLinkBackendConfiguration).Tenants.Values) { $result[$tenant.TenantId] = $tenant.Name }
    $result
}

function Get-WindowsDeviceLinkUpstreamFailure {
    param(
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    # Never return exception messages, response bodies, tokens or assertions.
    $statusCode = $null
    $upstreamErrorCode = $null
    $aadstsCodes = @()
    $upstreamCorrelationId = $null
    try {
        if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) {
            $statusCode = [int]$ErrorRecord.Exception.Response.StatusCode
        }
    } catch {}

    try {
        $raw = [string]$ErrorRecord.ErrorDetails.Message
        if (-not [string]::IsNullOrWhiteSpace($raw) -and $raw.Length -le 65536) {
            $detail = $raw | ConvertFrom-Json -ErrorAction Stop
            $candidate = if ($detail.error -is [string]) { $detail.error } else { [string]$detail.error.code }
            # Only known protocol codes may reach logs or API responses.
            if ($candidate -in @(
                'invalid_request','invalid_client','invalid_grant','invalid_scope',
                'unauthorized_client','unsupported_grant_type','invalid_resource',
                'interaction_required','temporarily_unavailable','server_error',
                'InvalidAuthenticationToken','Authentication_MissingOrMalformed',
                'Authorization_RequestDenied','AccessDenied','Forbidden',
                'BadRequest','Request_BadRequest','ResourceNotFound',
                'Request_ResourceNotFound','TooManyRequests','ServiceNotAvailable',
                'InternalServerError','UnknownError','NotSupported'
            )) {
                $upstreamErrorCode = [string]$candidate
            }

            $aadstsCodes = @(
                foreach ($code in @($detail.error_codes)) {
                    if ([string]$code -match '^[0-9]{3,10}$') { 'AADSTS' + [string]$code }
                }
            )
            if ($aadstsCodes.Count -eq 0 -and [string]$detail.error_description -match '\bAADSTS([0-9]{3,10})\b') {
                $aadstsCodes = @('AADSTS' + $Matches[1])
            }

            $correlation = [string]$detail.correlation_id
            if (-not $correlation -and $detail.error -isnot [string]) {
                $correlation = [string]$detail.error.innerError.'request-id'
            }
            $parsedId = [guid]::Empty
            if ([guid]::TryParse($correlation, [ref]$parsedId)) {
                $upstreamCorrelationId = $parsedId.ToString()
            }
        }
    } catch {}

    [pscustomobject]@{
        statusCode = $statusCode
        upstreamErrorCode = $upstreamErrorCode
        aadstsCodes = $aadstsCodes
        upstreamCorrelationId = $upstreamCorrelationId
    }
}

function Invoke-WindowsDeviceLinkGraphCollection {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$AccessToken,
        [ValidateRange(1,1000)][int]$MaxPages = 100
    )

    $headers = @{ Authorization = "Bearer $AccessToken" }
    $next = $Uri
    $page = 0

    while ($next) {
        $page++
        if ($page -gt $MaxPages) {
            throw "Graph collection paging exceeded the safety limit of $MaxPages pages."
        }

        $response = Invoke-RestMethod -Method GET -Uri $next -Headers $headers -ErrorAction Stop
        foreach ($record in @($response.value)) {
            $record
        }
        $next = [string]$response.'@odata.nextLink'
    }
}
