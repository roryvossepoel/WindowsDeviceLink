function ConvertTo-WindowsDeviceLinkTenantCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][object]$InputObject,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Source
    )

    function Assert-Fields {
        param($Object,[string[]]$Allowed,[string]$Location)
        if ($Object -isnot [pscustomobject]) { throw "$Location must be a JSON object." }
        foreach ($field in $Object.PSObject.Properties.Name) {
            if ($field -cnotin $Allowed) { throw "$Location contains an unsupported field. Only $($Allowed -join ', ') are allowed; do not include secrets." }
        }
    }
    function Get-ConfigurationGuid {
        param($Value,[string]$Field)
        $parsed = [guid]::Empty
        if ($Value -isnot [string] -or -not [guid]::TryParse($Value,[ref]$parsed) -or $parsed -eq [guid]::Empty) {
            throw "$Field must be a non-empty GUID string."
        }
        $parsed.ToString().ToLowerInvariant()
    }

    Assert-Fields $InputObject @('schemaVersion','mode','clientId','tenants') 'Configuration'
    if ($InputObject.schemaVersion -isnot [int] -and $InputObject.schemaVersion -isnot [long]) { throw 'schemaVersion must be the integer 1.' }
    if ($InputObject.schemaVersion -ne 1) { throw 'Unsupported configuration schemaVersion. Expected 1.' }
    if ($InputObject.mode -isnot [string] -or $InputObject.mode -cne 'Direct') { throw 'Configuration mode must be Direct. Backend obtains its catalog from the API.' }
    if ($InputObject.tenants -isnot [array] -or $InputObject.tenants.Count -eq 0) { throw 'tenants must be a non-empty JSON array.' }

    $sharedClientId = $null
    if ('clientId' -in $InputObject.PSObject.Properties.Name) {
        $sharedClientId = Get-ConfigurationGuid $InputObject.clientId 'clientId'
    }
    $seenNames = @{}
    $seenIds = @{}
    $entries = foreach ($tenant in $InputObject.tenants) {
        Assert-Fields $tenant @('name','tenantId','clientId') 'Tenant entry'
        if ($tenant.name -isnot [string] -or [string]::IsNullOrWhiteSpace($tenant.name) -or
            $tenant.name.Trim().Length -gt 128 -or $tenant.name -match '[\x00-\x1f\x7f]') {
            throw 'Each tenant name must contain 1 to 128 characters without control characters.'
        }
        $name = $tenant.name.Trim()
        $id = Get-ConfigurationGuid $tenant.tenantId 'tenantId'
        if ($seenNames.ContainsKey($name)) { throw 'Tenant names must be unique (case-insensitive).' }
        if ($seenIds.ContainsKey($id)) { throw 'Tenant IDs must be unique.' }
        $seenNames[$name] = $true
        $seenIds[$id] = $true
        $clientId = $sharedClientId
        if ('clientId' -in $tenant.PSObject.Properties.Name) {
            $clientId = Get-ConfigurationGuid $tenant.clientId 'Tenant clientId'
        }
        [pscustomobject]@{
            PSTypeName='Windows.DeviceLink.TenantCatalogEntry'
            Name=$name
            TenantId=$id
            ClientId=$clientId
            Source=$Source
            OperationMode='Direct'
            Enabled=$true
            Capabilities=@('Lookup','Register')
        }
    }
    $entries | Sort-Object Name
}
