$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\Public\Test-WindowsDeviceLinkSupport.ps1'
$runtimePath = Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\Public\Test-WindowsDeviceLinkRuntime.ps1'
$supportSource = Get-Content -LiteralPath $supportPath -Raw
$runtimeSource = Get-Content -LiteralPath $runtimePath -Raw

function Assert-SourceMatch {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    if ($Source -notmatch $Pattern) {
        throw $FailureMessage
    }
}

Assert-SourceMatch $supportSource 'RuntimeInformation\]::ProcessArchitecture' 'The support probe does not inspect the actual process architecture.'
Assert-SourceMatch $supportSource 'RuntimeInformation\]::OSArchitecture' 'The support probe does not inspect the operating-system architecture.'
Assert-SourceMatch $supportSource '\$processArchitecture\s+-eq\s+''AMD64''' 'AMD64 support was removed from the support probe.'
Assert-SourceMatch $supportSource '\$processArchitecture\s+-eq\s+''ARM64''' 'ARM64 is not recognized by the support probe.'
Assert-SourceMatch $supportSource '\$isEmulatedAmd64OnArm64' 'Emulated AMD64 PowerShell on ARM64 is not detected.'
Assert-SourceMatch $supportSource 'emulated AMD64 PowerShell process cannot use the ARM64 Windows DeviceLink runtime' 'The support probe lacks actionable emulation guidance.'
Assert-SourceMatch $supportSource '\-not\s+\$isWinPE' 'ARM64 support is not restricted to full Windows.'
Assert-SourceMatch $supportSource '\$dllSource\s+-eq\s+''System''' 'ARM64 support is not restricted to the system runtime.'
Assert-SourceMatch $supportSource '\$activationMode\s+-eq\s+''RegisteredWinRT''' 'ARM64 support is not restricted to registered WinRT activation.'
Assert-SourceMatch $supportSource '\$isAmd64Host\s+-or\s+\$isArm64RegisteredWindows' 'The support result does not combine the approved AMD64 and ARM64 routes.'

Assert-SourceMatch $runtimeSource '\$hostArchitecture\s+-eq\s+''ARM64''' 'The runtime probe does not recognize an ARM64 host.'
Assert-SourceMatch $runtimeSource 'RuntimeInformation\]::OSArchitecture' 'The runtime probe does not inspect the operating-system architecture.'
Assert-SourceMatch $runtimeSource '\$isEmulatedAmd64OnArm64' 'The runtime probe does not detect AMD64 emulation on ARM64.'
Assert-SourceMatch $runtimeSource '\$environment\s+-eq\s+''Windows''' 'The runtime probe does not restrict ARM64 to full Windows.'
Assert-SourceMatch $runtimeSource '\$pe\.Architecture\s+-eq\s+''ARM64''' 'The runtime probe does not require an ARM64 DLL on ARM64.'
Assert-SourceMatch $runtimeSource 'ARM64 Windows PE is not supported' 'The ARM64 WinPE boundary is not explicit in diagnostics.'

if ($supportSource -match 'supports AMD64 64-bit PowerShell only' -or $runtimeSource -match 'supports AMD64 64-bit PowerShell only') {
    throw 'An obsolete AMD64-only diagnostic remains in the architecture probes.'
}

Write-Host 'PASS: Architecture policy preserves AMD64 support and permits only registered-system-runtime ARM64 on full Windows.'
