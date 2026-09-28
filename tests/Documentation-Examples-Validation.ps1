<#
Parse current documentation examples without executing them. Check literal public
WindowsDeviceLink command names, named parameters, parameter-set compatibility and
literal ValidateSet values against the exact staged module. Dynamic/splatted values
and actual authentication/hardware behavior require separate tests.
#>
[CmdletBinding()]
param(
    [string]$ModulePath = (Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1'),
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Import-Module $ModulePath -Force -ErrorAction Stop
$commands = @{}
Get-Command -Module WindowsDeviceLink | ForEach-Object { $commands[$_.Name] = $_ }

function Get-ExampleErrors {
    param([string]$Code)
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$tokens, [ref]$parseErrors)
    foreach ($errorRecord in $parseErrors) {
        "line $($errorRecord.Extent.StartLineNumber): invalid PowerShell: $($errorRecord.Message)"
    }
    if ($parseErrors.Count -gt 0) { return }
    $calls = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($call in $calls) {
        $name = $call.GetCommandName()
        if (-not $name -or $name -notmatch '^[A-Za-z]+-(WindowsDeviceLink|WinPEDeviceLink)') { continue }
        $location = "line $($call.Extent.StartLineNumber): $name"
        if (-not $commands.ContainsKey($name)) {
            "$location is not an exported command"
            continue
        }
        $command = $commands[$name]
        $used = @()
        $hasSplat = $false
        for ($index = 1; $index -lt $call.CommandElements.Count; $index++) {
            $element = $call.CommandElements[$index]
            if ($element -is [System.Management.Automation.Language.VariableExpressionAst] -and $element.Splatted) {
                $hasSplat = $true
            }
            if ($element -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
            $parameterName = $element.ParameterName
            $parameter = $command.Parameters[$parameterName]
            if (-not $parameter) {
                $parameter = $command.Parameters.Values | Where-Object { $_.Aliases -contains $parameterName } | Select-Object -First 1
            }
            if (-not $parameter) {
                "$location has an unknown parameter -$parameterName (use full parameter names in documentation)"
                continue
            }
            $used += $parameter.Name
            $argument = $element.Argument
            if (-not $argument -and $index + 1 -lt $call.CommandElements.Count) {
                $argument = $call.CommandElements[$index + 1]
            }
            if ($argument -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                foreach ($attribute in $parameter.Attributes) {
                    if ($attribute -is [System.Management.Automation.ValidateSetAttribute] -and
                        $attribute.ValidValues -notcontains $argument.Value) {
                        "$location has unsupported -$parameterName value '$($argument.Value)'"
                    }
                }
            }
        }
        if ($used.Count -gt 0 -and -not $hasSplat) {
            $matchingSets = @($command.ParameterSets | Where-Object {
                $names = @($_.Parameters.Name)
                @($used | Where-Object { $names -notcontains $_ }).Count -eq 0
            })
            if ($matchingSets.Count -eq 0) { "$location combines incompatible parameter sets" }
        }
    }
}

# Negative fixtures prove the gate rejects stale examples without running commands.
foreach ($bad in @(
    'Initialize-WindowsDeviceLink -Method Interactive -CompleteAssociation',
    'Show-WindowsDeviceLink -Method ClientSecret',
    'Test-WinPEDeviceLinkSupport',
    'Set-WindowsDeviceLinkTenant -Method Interactive -BackendUri https://example.invalid/api',
    'Show-WindowsDeviceLink ('
)) {
    if (@(Get-ExampleErrors -Code $bad).Count -eq 0) { throw "Checker accepted an invalid example: $bad" }
}
foreach ($good in @(
    'Initialize-WindowsDeviceLink -Method Interactive -Associate -WhatIf',
    'Show-WindowsDeviceLink -Configuration $config',
    'Get-WindowsDeviceLink | Register-WindowsDeviceLink -Method DeviceCode',
    'Set-WindowsDeviceLinkTenant -BackendUri https://example.invalid/api -BackendApiKey $apiKey -TargetTenantId $tenant'
)) {
    $failures = @(Get-ExampleErrors -Code $good)
    if ($failures.Count -gt 0) { throw "Checker rejected a valid example: $($failures -join '; ')" }
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$failures = @()
$count = 0
$historical = @('docs/TEST-MATRIX-0.10.0.md', 'docs/NEXT-STEPS-UEFI-ASSOCIATION-LIFECYCLE.md')
Get-ChildItem -LiteralPath $root -Filter '*.md' -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    if ($relative -like 'docs/releases/*' -or $relative -like '.git/*' -or $relative -in $historical) { return }
    $text = [System.IO.File]::ReadAllText($_.FullName)
    $blocks = [regex]::Matches($text, '(?ms)^```(?:powershell|ps1|ps)[ \t]*\r?\n(?<code>.*?)^```[ \t]*\r?$')
    foreach ($block in $blocks) {
        $count++
        $start = [regex]::Matches($text.Substring(0, $block.Index), '\n').Count + 1
        foreach ($failure in @(Get-ExampleErrors -Code $block.Groups['code'].Value)) {
            $failures += "${relative}:$start example $failure"
        }
    }
}
if ($count -eq 0) { throw 'No PowerShell documentation examples were found.' }
if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
Write-Host "PASS: $count current PowerShell documentation blocks parsed and checked against the staged public contract; no examples executed."
