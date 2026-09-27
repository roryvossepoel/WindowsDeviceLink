<# Offline public-auth boundaries, delegated reuse and Backend CLI regression tests. #>
[CmdletBinding()] param([string]$ModulePath)
$ErrorActionPreference='Stop'
if (-not $ModulePath) { $ModulePath=Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1' }
Import-Module $ModulePath -Force
$module=Get-Module WindowsDeviceLink
function Assert-True($Condition,$Message) { if (-not $Condition) { throw "FAIL: $Message" } }
$removed=@('AccessToken','ClientSecret','Certificate','CertificateThumbprint','CertificateSubjectName','EnvironmentVariable','ManagedIdentity','Identity','SendCertificateChain')
foreach ($command in Get-Command -Module WindowsDeviceLink) {
    foreach ($parameter in $removed) {
        Assert-True (-not $command.Parameters.ContainsKey($parameter)) "$($command.Name) exposes $parameter"
    }
    if ($command.Parameters.ContainsKey('Method')) {
        $values=@($command.Parameters.Method.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | ForEach-Object { $_.ValidValues })
        foreach ($value in $values) { Assert-True ($value -in @('Interactive','DeviceCode','Webhook')) "Unexpected public method $value" }
    }
}
foreach ($name in @('Get-WindowsDeviceLinkStatusCore','Register-WindowsDeviceLinkCore','Get-WindowsDeviceLinkAssociationCore','Remove-WindowsDeviceLinkAssociationCore','Initialize-WindowsDeviceLinkCore','Set-WindowsDeviceLinkTenantCore')) {
    Assert-True (-not (Get-Command $name -ErrorAction SilentlyContinue)) "$name leaked into exported commands"
}
foreach ($method in @('AccessToken','ClientSecret','Certificate','CertificateThumbprint','CertificateSubjectName','EnvironmentVariable','ManagedIdentity')) {
    try { Show-WindowsDeviceLink -Method $method; throw 'Unexpected method acceptance' }
    catch { Assert-True ($_.FullyQualifiedErrorId -like '*ParameterArgumentValidationError*') "UI accepted $method or failed after binding" }
}
Write-Host 'PASS: public authentication surface accepts delegated methods only; internal token routes are private'

# A pre-existing app-only SDK context must not bypass the explicit method restrictions.
& $module {
    function script:Get-MgContext { [pscustomobject]@{AuthType='AppOnly';TenantId='test-tenant'} }
    function script:Invoke-MgGraphRequest { throw 'Graph must not be reached' }
}
$inputObject=[pscustomobject]@{SerialNumber='TEST-SERIAL';DeviceLink='TEST-PAYLOAD'}
$inputObject.PSObject.TypeNames.Insert(0,'Windows.DeviceLink.Information')
try { $inputObject | Register-WindowsDeviceLink -Confirm:$false; throw 'Unexpected app-only acceptance' }
catch { Assert-True ($_.Exception.Message -like '*delegated operator session*') 'Existing app-only SDK context was not rejected before Graph mutation' }
Write-Host 'PASS: pre-existing app-only SDK context cannot be used for Direct registration'

# API transport keeps ShouldProcess and pipeline semantics through the public wrapper.
& $module {
    $script:WebhookCalls=0
    function script:Invoke-WindowsDeviceLinkWebhook {
        param($InputObject,$WebhookUri,$WebhookApiKey,$TenantId)
        $script:WebhookCalls++; [pscustomobject]@{Success=$true}
    }
}
$inputObject | Register-WindowsDeviceLink -Method Webhook -WebhookUri 'https://backend.example.com/api/devicelink' -WebhookApiKey 'synthetic-key' -WhatIf
Assert-True ((& $module {$script:WebhookCalls}) -eq 0) 'Webhook WhatIf sent a mutation'
@($inputObject,$inputObject) | Register-WindowsDeviceLink -Method Webhook -WebhookUri 'https://backend.example.com/api/devicelink' -WebhookApiKey 'synthetic-key' -Confirm:$false | Out-Null
Assert-True ((& $module {$script:WebhookCalls}) -eq 2) 'Public registration wrapper lost pipeline records'
Write-Host 'PASS: API registration honors WhatIf and processes each pipeline record'

# Connect forwards only delegated arguments and rejects a missing/invalid context.
& $module {
    function script:Initialize-WindowsDeviceLinkOnline {}
    function script:Connect-MgGraph { param($TenantId,$ClientId,$Scopes,$Environment,$ClientTimeout,$ContextScope,$NoWelcome,$UseDeviceCode) $script:CapturedConnect=$PSBoundParameters }
    function script:Get-MgContext { [pscustomobject]@{AuthType='Delegated';TenantId='test-tenant'} }
}
Connect-WindowsDeviceLink -UseDeviceCode -ClientId 'test-client' | Out-Null
$captured=& $module { $script:CapturedConnect }
Assert-True ($captured.UseDeviceCode -and $captured.ClientId -eq 'test-client' -and $captured.ContextScope -eq 'Process') 'Delegated Connect argument forwarding changed'
& $module { function script:Get-MgContext { $null } }
try { Connect-WindowsDeviceLink -UseDeviceCode; throw 'Unexpected empty-context acceptance' }
catch { Assert-True ($_.Exception.Message -like '*delegated operator session*') 'Empty SDK context was accepted' }
Write-Host 'PASS: delegated Connect forwards arguments and fails closed without a session'

# Exercise public initializer with one operator token reused for both reads and the write.
& $module {
    $script:TokenCount=0; $script:Reads=0; $script:Writes=0
    function script:Get-WindowsDeviceLinkDeviceCodeToken { param($TenantId,$ClientId) $script:TokenCount++; [pscustomobject]@{AccessToken='synthetic-delegated-token';TenantId='test-tenant'} }
    function script:Get-WindowsDeviceLinkStatusCore {
        param($Online,$Method,$Environment,$ClientTimeout,$TimeoutSeconds,$TenantId,$AccessToken)
        if ($Method -ne 'AccessToken' -or -not $AccessToken -or $TenantId -ne 'test-tenant') { throw 'Lost delegated session' }
        $script:Reads++; [pscustomobject]@{ SerialNumber='TEST-SERIAL';LinkId='test-link';State=if($script:Reads -eq 1){'LocalOnly'}else{'Preassociated'} }
    }
    function script:Test-WindowsDeviceLinkHealth {
        param([Parameter(ValueFromPipeline)]$InputObject)
        process { [pscustomobject]@{State=$InputObject.State;Summary='Test';Severity='Information'} }
    }
    function script:Get-WindowsDeviceLink { param($TimeoutSeconds) [pscustomobject]@{SerialNumber='TEST-SERIAL';DeviceLink='TEST-PAYLOAD'} }
    function script:Register-WindowsDeviceLinkCore {
        param($Method,$Environment,$ClientTimeout,$TenantId,$AccessToken,$InputObject,$Confirm)
        if ($Method -ne 'AccessToken' -or -not $AccessToken) { throw 'Lost delegated session for write' }
        $script:Writes++; [pscustomobject]@{Success=$true}
    }
}
$result=Initialize-WindowsDeviceLink -Method DeviceCode -Confirm:$false
$counts=& $module { @($script:TokenCount,$script:Reads,$script:Writes) }
Assert-True ($counts[0] -eq 1 -and $counts[1] -eq 2 -and $counts[2] -eq 1 -and $result.Changed) 'Initializer must acquire once, read twice and write once'
Write-Host 'PASS: public DeviceCode initialization reuses one delegated token across lookup, mutation and verification'

# Backend CLI stays usable without Direct auth; WhatIf must stop offboarding transport.
& $module {
    $script:OffboardCalls=0
    function script:Get-WindowsDeviceLinkBackendStatus {
        param($BackendUri,$BackendApiKey,$TimeoutSeconds)
        if ($BackendApiKey -ne 'synthetic-api-key' -or $TimeoutSeconds -ne 45) { throw 'Incorrect backend forwarding' }
        [pscustomobject]@{CloudChecked=$true;AssociationPresent=$false}
    }
    function script:Invoke-WindowsDeviceLinkBackendOffboard {
        param($BackendUri,$BackendApiKey,$SerialNumber,$TimeoutSeconds)
        if ($BackendApiKey -ne 'synthetic-api-key' -or $SerialNumber -ne 'TEST-SERIAL' -or $TimeoutSeconds -ne 45) { throw 'Incorrect offboard forwarding' }
        $script:OffboardCalls++; [pscustomobject]@{success=$true}
    }
}
$key=ConvertTo-SecureString 'synthetic-api-key' -AsPlainText -Force
$backend=@{BackendUri='https://backend.example.com/api/devicelink';BackendApiKey=$key;TimeoutSeconds=45}
$status=Get-WindowsDeviceLinkStatus @backend
Assert-True ($status.CloudChecked -and -not $status.AssociationPresent) 'Backend CLI status failed'
Remove-WindowsDeviceLinkAssociation @backend -SerialNumber 'TEST-SERIAL' -WhatIf
Assert-True ((& $module {$script:OffboardCalls}) -eq 0) 'WhatIf called offboard API'
Remove-WindowsDeviceLinkAssociation @backend -SerialNumber 'TEST-SERIAL' -Confirm:$false | Out-Null
Assert-True ((& $module {$script:OffboardCalls}) -eq 1) 'Backend removal did not run exactly once'
try { Get-WindowsDeviceLinkStatus @backend -Method DeviceCode; throw 'Unexpected mixed-mode acceptance' }
catch { Assert-True ($_.FullyQualifiedErrorId -like '*AmbiguousParameterSet*') 'Backend status accepted Direct auth parameters' }
Write-Host 'PASS: Backend CLI status/removal forward runtime key and timeout, reject mixed modes, and honor WhatIf'
