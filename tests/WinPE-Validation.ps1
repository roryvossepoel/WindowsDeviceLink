<#
WindowsDeviceLink - WinPE validation runner

This public test runner contains no tenant-specific or device-specific values.

When invoked without -Interactive, it performs automation-safe contract validation only
and exits without prompting. Use -Interactive for the live WinPE menu.

Example:
.\WinPE-Validation.ps1 -Interactive

TenantId and ClientId are optional for delegated DeviceCode sign-in.
The public WindowsDeviceLink package does not include Windows.Management.Service.dll.
#>

[CmdletBinding()]
param(
    [string]$TenantId,
    [string]$ClientId,
    [string]$ModulePath,
    [string]$ExportRoot = 'X:\WindowsDeviceLink-Test',
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
function Resolve-WindowsDeviceLinkModule {
    if ($ModulePath) { return (Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop).Path }

    $candidates = @(
        (Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1'),
        (Join-Path $PSScriptRoot 'src\WindowsDeviceLink\WindowsDeviceLink.psd1')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $manual = Read-Host 'Full path to WindowsDeviceLink.psd1'
    return (Resolve-Path -LiteralPath $manual -ErrorAction Stop).Path
}

function Invoke-Test {
    param([string]$Name,[scriptblock]$Body)
    Write-Host ''
    Write-Host "--- $Name ---"
    try {
        & $Body
        Write-Host "PASS: $Name"
    }
    catch {
        Write-Host "FAIL: $Name"
        Write-Host $_.Exception.Message
    }
}

$resolvedModule = Resolve-WindowsDeviceLinkModule
Import-Module $resolvedModule -Force

if (-not $Interactive) {
    $getLocal = Get-Command Get-WindowsDeviceLink -Module WindowsDeviceLink
    if ($getLocal.Parameters.ContainsKey('Online')) {
        throw 'FAIL: Get-WindowsDeviceLink unexpectedly exposes the legacy -Online parameter.'
    }

    $register = Get-Command Register-WindowsDeviceLink -Module WindowsDeviceLink
    if (-not $register.Parameters.ContainsKey('Method')) {
        throw 'FAIL: Register-WindowsDeviceLink is missing -Method.'
    }

    $registerSource = $register.ScriptBlock.ToString()
    if ($registerSource -match '-TenantId is required for -Method DeviceCode') {
        throw 'FAIL: DeviceCode registration unexpectedly requires -TenantId.'
    }

    Write-Host 'PASS: WinPE validation runner uses the current local-identity + explicit cloud-registration contract and is automation-safe by default.'
    return
}

while ($true) {
    Write-Host ''
    Write-Host 'WindowsDeviceLink - WinPE validation'
    Write-Host '1  Support + local generation'
    Write-Host '2  CSV export regression'
    Write-Host '3  Device code + CSV + online registration'
    Write-Host 'Q  Quit'

    $choice = (Read-Host 'Select test').Trim().ToUpperInvariant()
    switch ($choice) {
        '1' { Invoke-Test 'Support + local generation' { Test-WindowsDeviceLinkSupport | Format-List *; Get-WindowsDeviceLink | Format-List Environment,SerialNumber,Manufacturer,Model,LinkId,DllSource,ActivationMode,DllVersion } }
        '2' { Invoke-Test 'CSV export regression' { Get-WindowsDeviceLink -OutputDirectory $ExportRoot | Out-Host } }
        '3' { Invoke-Test 'Device code + CSV + online registration' {
            $deviceLink = Get-WindowsDeviceLink
            $deviceLink | Export-WindowsDeviceLinkCsv -DestinationPath $ExportRoot | Out-Host
            $auth = @{ Method = 'DeviceCode' }
            if ($TenantId) { $auth.TenantId = $TenantId }
            if ($ClientId) { $auth.ClientId = $ClientId }
            $deviceLink | Register-WindowsDeviceLink @auth | Format-List
        } }
        'Q' { return }
        default { Write-Host 'Unknown selection.' }
    }
}
