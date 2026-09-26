[CmdletBinding()]
param([string]$ModulePath = (Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1'))

$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw "FAIL: $Message" } }

Remove-Module WindowsDeviceLink -Force -ErrorAction SilentlyContinue
Import-Module (Resolve-Path $ModulePath) -Force

$tenantA = '11111111-1111-1111-1111-111111111111'
$tenantB = '22222222-2222-2222-2222-222222222222'
$configuration = @{
    schemaVersion=1; mode='Direct'; tenants=@(
        @{name='Tenant B';tenantId=$tenantB}, @{name='Tenant A';tenantId=$tenantA}
    )
} | ConvertTo-Json -Depth 5
$all = @(Get-WindowsDeviceLinkTenantCatalog -Configuration $configuration)
Assert-True ($all.Count -eq 2 -and $all[0].Name -eq 'Tenant A' -and $all[1].TenantId -eq $tenantB) 'Configuration was not normalized and sorted.'
$selected = Get-WindowsDeviceLinkTenantCatalog -Configuration $configuration -Name 'tenant b'
Assert-True ($selected.TenantId -eq $tenantB) 'Case-insensitive name selection failed.'
$selectedById = Get-WindowsDeviceLinkTenantCatalog -Configuration $configuration -TenantId $tenantA
Assert-True ($selectedById.Name -eq 'Tenant A') 'Tenant ID selection failed.'
$blocked = $false
try { $null = Get-WindowsDeviceLinkTenantCatalog -Configuration $configuration -Name 'Missing' } catch { $blocked=$true }
Assert-True $blocked 'A missing selected name must fail closed.'
$command = Get-Command Get-WindowsDeviceLinkTenantCatalog -Module WindowsDeviceLink
Assert-True (-not $command.Parameters.ContainsKey('WhatIf')) 'Tenant catalog reading must remain read-only.'
Write-Host 'PASS: configuration catalog supports name/ID selection.'

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
