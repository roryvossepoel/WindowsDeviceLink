[CmdletBinding()]
param([string]$FunctionRoot = (Join-Path $PSScriptRoot '../function-app'))

$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw "FAIL: $Message" } }

. (Join-Path $FunctionRoot 'shared/BackendAuth.ps1')
$setting = 'WINDOWSDEVICELINK_CONFIGURATION_JSON'
$saved = [Environment]::GetEnvironmentVariable($setting)
$tenantA = '11111111-1111-1111-1111-111111111111'
$tenantB = '22222222-2222-2222-2222-222222222222'
$clientA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
$clientB = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'

function Set-TestConfiguration([hashtable]$Value) {
    [Environment]::SetEnvironmentVariable($setting,($Value | ConvertTo-Json -Depth 10 -Compress))
}
function Assert-Rejected([hashtable]$Value,[string]$Message) {
    Set-TestConfiguration $Value
    $rejected=$false
    try { $null=Get-WindowsDeviceLinkBackendConfiguration } catch { $rejected=$true }
    Assert-True $rejected $Message
}
function New-ValidConfiguration {
    @{
        schemaVersion=1; mode='Backend'; defaultTenantId=$tenantA
        authenticationProfiles=@{
            shared=@{method='Certificate';clientId=$clientA;credentialSetting='WINDOWSDEVICELINK_GRAPH_SHARED_CERT';certificatePasswordSetting='WINDOWSDEVICELINK_GRAPH_SHARED_PASSWORD'}
            isolated=@{method='ClientSecret';clientId=$clientB;credentialSetting='WINDOWSDEVICELINK_GRAPH_ISOLATED_SECRET'}
        }
        tenants=@(
            @{name='Tenant Alpha';tenantId=$tenantA;authenticationProfile='shared'},
            @{name='Tenant Beta';tenantId=$tenantB;authenticationProfile='isolated'}
        )
    }
}

try {
    Set-TestConfiguration (New-ValidConfiguration)
    $configuration=Get-WindowsDeviceLinkBackendConfiguration
    Assert-True ($configuration.Tenants.Count -eq 2) 'Both configured tenants were not loaded.'
    Assert-True ($configuration.Tenants[$tenantA].AuthenticationProfile.ClientId -eq $clientA) 'Tenant A did not resolve its shared profile.'
    Assert-True ($configuration.Tenants[$tenantB].AuthenticationProfile.Method -eq 'ClientSecret') 'Tenant B did not resolve its isolated profile.'
    Assert-True ($configuration.DefaultTenantId -eq $tenantA) 'Default tenant was not normalized.'

    $shared=New-ValidConfiguration
    $shared.tenants[1].authenticationProfile='shared'
    Set-TestConfiguration $shared
    $configuration=Get-WindowsDeviceLinkBackendConfiguration
    Assert-True ($configuration.Tenants[$tenantA].AuthenticationProfile -eq $configuration.Tenants[$tenantB].AuthenticationProfile) 'Multiple tenants cannot share one multitenant application profile.'

    foreach ($mutation in @(
        {param($c)$c.schemaVersion='1'},
        {param($c)$c.mode='Direct'},
        {param($c)$c.unknown='value'},
        {param($c)$c.defaultTenantId='99999999-9999-9999-9999-999999999999'},
        {param($c)$c.authenticationProfiles.shared.method='ManagedIdentity'},
        {param($c)$c.authenticationProfiles.shared.clientId='invalid'},
        {param($c)$c.authenticationProfiles.shared.credentialSetting='unsafe-setting'},
        {param($c)$c.authenticationProfiles.shared.credentialSetting='WINDOWSDEVICELINK_API_KEY'},
        {param($c)$c.authenticationProfiles.shared.clientSecret='do-not-accept-secrets'},
        {param($c)$c.tenants[0].authenticationProfile='missing'},
        {param($c)$c.tenants[1].tenantId=$c.tenants[0].tenantId},
        {param($c)$c.tenants[1].name='tenant alpha'},
        {param($c)$c.tenants[0].clientId=$clientA}
    )) {
        $candidate=New-ValidConfiguration
        & $mutation $candidate
        Assert-Rejected $candidate 'Invalid backend configuration was accepted.'
    }

    [Environment]::SetEnvironmentVariable($setting,'{bad json')
    $rejected=$false
    try { $null=Get-WindowsDeviceLinkBackendConfiguration } catch { $rejected=$true }
    Assert-True $rejected 'Malformed backend JSON was accepted.'

    Write-Host 'PASS: backend tenant/profile schema, shared and isolated profiles, unknown fields and fail-closed validation'
}
finally {
    [Environment]::SetEnvironmentVariable($setting,$saved)
}
