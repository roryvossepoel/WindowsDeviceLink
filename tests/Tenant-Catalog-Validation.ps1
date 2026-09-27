[CmdletBinding()]
param([string]$ModulePath = (Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1'))

$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw "FAIL: $Message" } }

Remove-Module WindowsDeviceLink -Force -ErrorAction SilentlyContinue
Import-Module (Resolve-Path $ModulePath) -Force

$tenantA = '11111111-1111-1111-1111-111111111111'
$tenantB = '22222222-2222-2222-2222-222222222222'
Assert-True (-not (Get-Command Get-WindowsDeviceLinkTenantCatalog -ErrorAction SilentlyContinue)) 'Direct UI configuration must not be exposed as a public CLI catalog.'
Write-Host 'PASS: Direct configuration remains internal to the UI.'

$backendResponse = [pscustomobject]@{
    success=$true; apiVersion='1.0'; minimumModuleVersion='0.10.0'
    capabilities=@('TenantCatalog','MultitenantLookup','Reconcile','Offboarding'); tenantCount=2
    tenants=@(
        [pscustomobject]@{name='Tenant A';tenantId=$tenantA},
        [pscustomobject]@{name='Tenant B';tenantId=$tenantB}
    )
}
$catalog = & (Get-Module WindowsDeviceLink) {
    param($response)
    Invoke-WindowsDeviceLinkBackendTenantCatalog -BackendUri 'https://example.test/api/devicelink' -BackendApiKey 'safe-test-key' -RequestScript { param($endpoint,$headers) $response }
} $backendResponse
Assert-True ($catalog.apiVersion -eq '1.0') 'Compatible backend handshake was rejected.'

$blocked=$false
$backendResponse.capabilities=@('TenantCatalog','MultitenantLookup')
try {
    $null = & (Get-Module WindowsDeviceLink) {
        param($response)
        Invoke-WindowsDeviceLinkBackendTenantCatalog -BackendUri 'https://example.test/api/devicelink' -BackendApiKey 'safe-test-key' -RequestScript { param($endpoint,$headers) $response }
    } $backendResponse
} catch { $blocked=$true }
Assert-True $blocked 'A backend missing Reconcile capability must fail closed.'

$blocked=$false
$backendResponse.capabilities=@('TenantCatalog','MultitenantLookup','Reconcile','Offboarding')
$backendResponse.apiVersion='2.0'
try {
    $null = & (Get-Module WindowsDeviceLink) {
        param($response)
        Invoke-WindowsDeviceLinkBackendTenantCatalog -BackendUri 'https://example.test/api/devicelink' -BackendApiKey 'safe-test-key' -RequestScript { param($endpoint,$headers) $response }
    } $backendResponse
} catch { $blocked=$true }
Assert-True $blocked 'An incompatible backend API version must fail closed.'
Write-Host 'PASS: backend compatibility handshake accepts v1 and rejects missing capabilities or incompatible versions.'
