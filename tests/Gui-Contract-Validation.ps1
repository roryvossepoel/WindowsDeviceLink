<#
WindowsDeviceLink GUI contract validation.

This test is hardware-independent and does not open the GUI.
#>

[CmdletBinding()]
param([string]$ModulePath)

$ErrorActionPreference = 'Stop'

if (-not $ModulePath) {
    $ModulePath = Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1'
}

$resolvedModulePath = (Resolve-Path -LiteralPath $ModulePath).Path
Remove-Module WindowsDeviceLink -Force -ErrorAction SilentlyContinue
Import-Module $resolvedModulePath -Force -ErrorAction Stop

$command = Get-Command Show-WindowsDeviceLink -Module WindowsDeviceLink -ErrorAction Stop
$source = $command.ScriptBlock.ToString()

if ($command.Parameters.ContainsKey('WhatIf') -or $command.Parameters.ContainsKey('Confirm')) {
    throw 'FAIL: Show-WindowsDeviceLink itself must not expose mutation controls; state-changing actions are delegated to guarded cmdlets after explicit GUI confirmation.'
}

if (-not $command.Parameters.ContainsKey('Method')) {
    throw 'FAIL: Show-WindowsDeviceLink must expose -Method.'
}
if (-not $command.Parameters.ContainsKey('Configuration') -or $command.Parameters['Configuration'].ParameterType -ne [string]) {
    throw 'FAIL: Show-WindowsDeviceLink must expose one string Configuration parameter.'
}
foreach ($oldParameter in @('Tenants','TenantsUri','TenantsPath')) {
    if ($command.Parameters.ContainsKey($oldParameter)) { throw "FAIL: Obsolete parameter $oldParameter remains." }
}
if (-not $command.Parameters.ContainsKey('WindowsManagementServicePath')) {
    throw 'FAIL: Show-WindowsDeviceLink must expose -WindowsManagementServicePath for Windows PE runtime selection.'
}
foreach ($parameterName in @('BackendUri','BackendApiKey','ViewMode')) {
    if (-not $command.Parameters.ContainsKey($parameterName)) { throw "FAIL: Show-WindowsDeviceLink must expose -$parameterName." }
}
if ($command.Parameters['BackendApiKey'].ParameterType -ne [securestring]) {
    throw 'FAIL: Show-WindowsDeviceLink -BackendApiKey must be SecureString.'
}
$methodParameter = $command.Parameters['Method']
$validateSet = @($methodParameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1)
if (-not $validateSet -or 'Interactive' -notin $validateSet.ValidValues) {
    throw 'FAIL: Show-WindowsDeviceLink -Method must continue to support Interactive.'
}

$methodParameterAst = $command.ScriptBlock.Ast.FindAll(
    {
        param($ast)

        $ast -is [System.Management.Automation.Language.ParameterAst] -and
        $ast.Name.VariablePath.UserPath -eq 'Method'
    },
    $true
) | Select-Object -First 1

if (-not $methodParameterAst) {
    throw 'FAIL: Show-WindowsDeviceLink Method parameter AST could not be resolved.'
}

if ($methodParameterAst.DefaultValue) {
    throw 'FAIL: Show-WindowsDeviceLink -Method must not have a static parameter default; the GUI resolves the default by environment.'
}

$environmentAwareDefault = '$Method = if ($isWinPE) { ''DeviceCode'' } else { ''Interactive'' }'
if ($source -notmatch [regex]::Escape($environmentAwareDefault)) {
    throw 'FAIL: Show-WindowsDeviceLink must default to DeviceCode in Windows PE and Interactive on full Windows when -Method is omitted.'
}


foreach ($required in @(
    'System.Windows.Forms',
    'ShowDialog',
    'MiniNT',
    'Get-GuiRuntimeParameters',
    'Set-GuiCapabilities',
    'Configuration',
    'Get-SelectedClientId',
    'fixedConfigurationTenantId',
    'Read-WindowsDeviceLinkConfiguration',
    'WindowsManagementServicePath',
    'Windows PE',
    'Association is not available in Windows PE',
    'btnAssociateHost',
    'Get-WindowsDeviceLinkLocalAssociation',
    'Get-GuiOperationParameters',
    'Get-WindowsDeviceLinkStatus',
    'Get-WindowsDeviceLink',
    'Initialize-WindowsDeviceLink',
    'Remove-WindowsDeviceLinkAssociation',
    'Reset-WindowsDeviceLinkFirmwareState',
    'Associate',
    'Full DeviceLink offboarding',
    'No cloud association was found. Nothing was removed.',
    'Set-WindowsDeviceLinkTenant',
    'RepairExistingAssociation',
    'Same-tenant repair required',
    'Invoke-WindowsDeviceLinkBackendOffboard',
    'Cloud offboarding completed and verified',
    'Full offboarding completed and verified',
    '$offboardingStatePresent = $cloudPresent -or $localAssociated',
    'Get-WindowsDeviceLinkBackendTenant',
    'Backend mode',
    'Direct mode',
    'Tenant determined by sign-in',
    'Local association',
    'Cloud association',
    "`$assignmentSectionTitle.Text = 'Assignment'",
    "-Title 'Connection'",
    "-Caption 'Manufacturer'",
    "-Caption 'Operating system'",
    'RuntimeInformation]::OSArchitecture',
    '$environmentDisplayText',
    'PowerShell process:',
    "-Caption 'Tenant scope'",
    "'Caption:Endpoint'",
    'Device association',
    'Status',
    'Export',
    'Offboarding',
    'Last checked',
    'Activity log copied to clipboard.',
    '[System.Windows.Forms.Clipboard]::SetText($consoleBox.Text)',
    '$consoleBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical',
    '$consoleBox.WordWrap = $true',
    'Target tenant',
    'Pre-associate',
    'Associate',
    'Remove cloud',
    'Reset local',
    'Remove both',
    'Sign in',
    'Sign out',
    'Signing in...',
    'Waiting for sign-in...',
    '[switch]$Warning',
    'The sign-in window may open behind this window',
    "select 'No, this app only' to avoid registering this device",
    'Actions will target the signed-in tenant.',
    'Disconnect-MgGraph',
    'The authenticated tenant does not match the selected target tenant.',
    '$usesInteractiveUserAuthentication',
    'Non-interactive',
    'Invoke-GuiSignIn',
    'Signed out',
    'Interactive authentication did not complete.',
    'No authenticated Microsoft Graph context was returned.',
    'Signed in; cloud association check failed',
    'Signed in; cloud association loaded',
    'Local state loaded; sign in to check the cloud association',
    'WdlGuiSessionAccessToken',
    'WdlGuiSessionTenantId',
    'WdlGuiSessionAccountName',
    'WdlGuiSessionExpiresUtc',
    'Clear-GuiSessionAuthentication',
    'Clear-GuiSessionAuthentication -ForceGraphDisconnect',
    '[switch]$ForceGraphDisconnect',
    "Method = 'AccessToken'",
    "Write-GuiConsole -Message 'Authenticating once for this Direct-mode UI session.'",
    'the in-memory token will be reused for cloud actions.',
    'Target tenant changed; sign in again to create a Direct-mode session for the selected tenant.',
    'Select a target tenant before signing in or performing a cloud action.',
    '-Configuration cannot be combined with Backend mode, -TenantId or -ClientId. Put Direct tenant/client choices in the configuration.',
    '$hasDirectTenantCatalog',
    '$showTenantSelector',
    'Sign in to select the destination tenant.',
    '$targetTenantRow.Controls.Add($btnSignIn)',
    '$interactiveTenantReady',
    '-not ($usesInteractiveUserAuthentication -and $script:WdlGuiSessionAuthenticated)',
    '$targetTenantValue.Width = [Math]::Max(220,$targetValueRight - $targetTenantValue.Left)',
    '$activityCard.Height = $activityHeight',
    '$activityHeight = [Math]::Max(96,$content.ClientSize.Height - $activityCard.Top - 12)',
    '$consoleBox.Height = [Math]::Max(74,$activityHeight - 22)',
    '$btnAssign.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard',
    'New-GuiFont',
    '$colorCardTint',
    '$colorCardAccent',
    "'Tahoma'",
    "'Assets\WindowsDeviceLink.ico'"
)) {
    if ($source -notmatch [regex]::Escape($required)) {
        throw "FAIL: Show-WindowsDeviceLink is missing expected GUI/delegation contract '$required'."
    }
}

$runtimeHelperPattern = '(?s)function\s+Get-GuiRuntimeParameters\s*\{(?<Body>.*?)\n\s*\}'
$runtimeHelperMatch = [regex]::Match($source,$runtimeHelperPattern)
if (-not $runtimeHelperMatch.Success) {
    throw 'FAIL: GUI runtime-parameter helper was not found.'
}
if ($runtimeHelperMatch.Groups['Body'].Value -match 'TimeoutSeconds') {
    throw 'FAIL: Runtime-only parameters must not pass -TimeoutSeconds to Test-WindowsDeviceLinkSupport.'
}

$operationHelperPattern = '(?s)function\s+Get-GuiOperationParameters\s*\{(?<Body>.*?)\n\s*\}'
$operationHelperMatch = [regex]::Match($source,$operationHelperPattern)
if (-not $operationHelperMatch.Success -or $operationHelperMatch.Groups['Body'].Value -notmatch 'TimeoutSeconds') {
    throw 'FAIL: Operation parameters must include the caller-selected timeout.'
}

foreach ($offboardingEnableContract in @(
    '$btnCloudOffboard.Enabled = $runtimeReady -and $cloudPresent',
    '$btnLocalOffboard.Enabled = Test-GuiLocalResetAvailable',
    '$btnFullOffboard.Enabled = $runtimeReady -and $offboardingStatePresent'
)) {
    if ($source -notmatch [regex]::Escape($offboardingEnableContract)) {
        throw "FAIL: GUI offboarding availability must be based on known removable state: '$offboardingEnableContract'."
    }
}

foreach ($forbidden in @(
    'Invoke-MgGraphRequest',
    'Invoke-WindowsDeviceLinkGraphGet',
    'SetFirmwareEnvironmentVariable',
    'importTenantAssociatedDevice'
)) {
    if ($source -match [regex]::Escape($forbidden)) {
        throw "FAIL: Show-WindowsDeviceLink contains direct lifecycle/backend implementation '$forbidden' instead of delegating to public cmdlets."
    }
}

if ($source -match [regex]::Escape('PlaceholderText')) {
    throw 'FAIL: GUI uses TextBox.PlaceholderText, which is not compatible with Windows PowerShell 5.1 / .NET Framework WinForms.'
}

if ($source -match [regex]::Escape('Show-WindowsDeviceLink is not supported in Windows PE yet')) {
    throw 'FAIL: Show-WindowsDeviceLink must not hard-block Windows PE.'
}

foreach ($inconsistentCloudPlaceholder in @('Not checked yet','Not yet')) {
    if ($source -match [regex]::Escape($inconsistentCloudPlaceholder)) {
        throw "FAIL: Cloud association placeholders must consistently use 'Not checked', not '$inconsistentCloudPlaceholder'."
    }
}

foreach ($cloudField in @('CloudState','CloudTenant','CloudId','CloudChecked')) {
    if ($source -notmatch [regex]::Escape("`$ui.$cloudField.Text = `$cloudPendingText")) {
        throw "FAIL: Cloud association field '$cloudField' must use the shared pending state during lookup."
    }
}

foreach ($cloudPendingState in @('Waiting for sign-in...','Checking...')) {
    if ($source -notmatch [regex]::Escape($cloudPendingState)) {
        throw "FAIL: Cloud association pending state '$cloudPendingState' is missing."
    }
}

foreach ($localField in @('LocalState','Firmware','LinkId','LocalCreated')) {
    if ($source -notmatch [regex]::Escape("`$ui.$localField.Text = 'Not checked'")) {
        throw "FAIL: Local association field '$localField' must use the shared initial 'Not checked' state."
    }
    if ($source -notmatch [regex]::Escape("`$ui.$localField.Text = 'Checking...'")) {
        throw "FAIL: Local association field '$localField' must show the shared 'Checking...' state during refresh."
    }
}

if ($source -notmatch [regex]::Escape("-Title 'Status' -Description 'Refresh local or cloud state.' -Y 46 -Buttons @('Refresh cloud','Refresh local')")) {
    throw 'FAIL: Status actions must contain only cloud and local refresh, in the same order as Offboarding.'
}

if ($source -notmatch [regex]::Escape("-Title 'Export' -Description 'Export DeviceLink CSV for manual import in Intune.' -Y 92 -Buttons @('Export CSV')")) {
    throw 'FAIL: CSV export must use its own compact action row with the manual Intune import explanation.'
}

foreach ($layoutContract in @(
    '$targetTenantRow.Size = [System.Drawing.Size]::new(1030,46)',
    '$assignmentPanel = New-Card -Title '''' -X 14 -Y 294 -Width 1030 -Height 46',
    '$btnSignIn.Size = [System.Drawing.Size]::new(118,28)',
    '$assignmentRow.Size = [System.Drawing.Size]::new(1030,46)',
    '$tenantSelector.ItemHeight = 22',
    '$tenantSelector.Size = [System.Drawing.Size]::new(220,28)',
    '$actionsPanel.Height = 184'
)) {
    if ($source -notmatch [regex]::Escape($layoutContract)) {
        throw "FAIL: Unified action-row layout contract is missing '$layoutContract'."
    }
}

$associationGuardPattern = '(?s)\$canAssociate\s*=\s*\$runtimeReady\s*-and\s*\[string\]\$support\.Environment\s*-ne\s*''WindowsPE'''
if ($source -notmatch $associationGuardPattern) {
    throw 'FAIL: Association must remain capability-disabled in Windows PE.'
}

if ($source -notmatch '(?s)\$btnAssociate\.Enabled\s*=.*\$canAssociate') {
    throw 'FAIL: Associate button must use the Windows PE-aware association capability.'
}

if ($source -notmatch '(?s)if \(\$backendMode\).*Set-WindowsDeviceLinkTenant.*Complete-WindowsDeviceLinkAssociation') {
    throw 'FAIL: Backend association must ensure tenant assignment before completing the local association.'
}

foreach ($requiredPolish in @(
    'cloudKnownAbsent',
    'alreadyAssociated',
    "-Caption 'Link ID'",
    "-Caption 'Created'",
    "'RegistrationResult'",
    "'BeforeStatus'",
    "'AfterStatus'",
    "'AssociationDetails'"
)) {
    if ($source -notmatch [regex]::Escape($requiredPolish)) {
        throw "FAIL: Show-WindowsDeviceLink is missing expected GUI polish contract '$requiredPolish'."
    }
}

# Exercise the actual nested reset policy and click handler without opening WinForms,
# changing firmware, or authenticating to a tenant.
$resetFunctions = foreach ($name in @('Test-GuiLocalResetAvailable','Invoke-GuiLocalOffboard')) {
    $definition = $command.ScriptBlock.Ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if (-not $definition) { throw "FAIL: GUI reset function '$name' was not found." }
    $definition.Extent.Text
}
$resetScript = [scriptblock]::Create($resetFunctions -join [Environment]::NewLine)
$localResetCommands = @(
    'Test-GuiLocalResetAvailable','Confirm-GuiAction','Set-GuiBusy','Set-GuiStatus',
    'Write-GuiConsole','Write-GuiObject','Reset-WindowsDeviceLinkFirmwareState',
    'Refresh-LocalView','Show-GuiError'
)
foreach ($invocation in $resetScript.Ast.FindAll({
    param($node) $node -is [System.Management.Automation.Language.CommandAst]
}, $true)) {
    if ($invocation.GetCommandName() -notin $localResetCommands) {
        throw "FAIL: Unexpected command in the local-only reset path: $($invocation.Extent.Text)"
    }
}
$confirmation = $command.ScriptBlock.Ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Confirm-GuiAction'
}, $true)
if ($confirmation.Extent.Text -notmatch '(?s)if \(\$DefaultNo\)\s*\{\s*\[System.Windows.Forms.MessageBoxDefaultButton\]::Button2' -or
    $confirmation.Extent.Text -notmatch 'MessageBoxIcon\]::Warning,\s*\$defaultButton') {
    throw 'FAIL: Reset confirmation must use the No button as its default selection.'
}
$absent = [pscustomobject]@{ AssociationPresent=$false; AssociationState='NotAssociated' }
$present = [pscustomobject]@{ AssociationPresent=$true; AssociationState='Associated' }
$unknown = [pscustomobject]@{ AssociationPresent=$null; AssociationState='Unknown' }
$cases = @(
    @{ Name='Interactive before sign-in'; Method='Interactive'; Cloud=$null; Allowed=$true },
    @{ Name='DeviceCode before sign-in'; Method='DeviceCode'; Cloud=$null; Allowed=$true },
    @{ Name='WinPE DeviceCode before sign-in'; Method='DeviceCode'; WinPE=$true; Cloud=$null; Allowed=$true },
    @{ Name='Interactive unknown cloud'; Method='Interactive'; Cloud=$unknown; Allowed=$true },
    @{ Name='DeviceCode unknown cloud'; Method='DeviceCode'; Cloud=$unknown; Allowed=$true },
    @{ Name='Interactive existing cloud record'; Method='Interactive'; Cloud=$present; Allowed=$true },
    @{ Name='DeviceCode existing cloud record'; Method='DeviceCode'; Cloud=$present; Allowed=$true },
    @{ Name='Interactive absent cloud'; Method='Interactive'; Cloud=$absent; Allowed=$true },
    @{ Name='Backend unchecked'; Backend=$true; Cloud=$null; Allowed=$false },
    @{ Name='Backend unknown'; Backend=$true; Cloud=$unknown; Allowed=$false },
    @{ Name='Backend present'; Backend=$true; Cloud=$present; Allowed=$false },
    @{ Name='Backend absent'; Backend=$true; Cloud=$absent; Allowed=$true },
    @{ Name='Backend cannot use Interactive exception'; Backend=$true; Method='Interactive'; Cloud=$present; Allowed=$false },
    @{ Name='No local firmware'; Method='Interactive'; Firmware='0/4'; Cloud=$absent; Allowed=$false },
    @{ Name='Partial local firmware'; Method='DeviceCode'; Firmware='1/4'; Cloud=$null; Allowed=$false },
    @{ Name='Unsupported runtime'; Method='Interactive'; Unsupported=$true; Cloud=$null; Allowed=$false },
    @{ Name='Base identity'; Method='DeviceCode'; Firmware='2/4'; Cloud=$null; Allowed=$true },
    @{ Name='Cancel reset'; Method='Interactive'; Cloud=$null; Allowed=$true; Cancel=$true },
    @{ Name='Busy reset'; Method='DeviceCode'; Cloud=$null; Allowed=$true; Busy=$true },
    @{ Name='Reset failure'; Method='Interactive'; Cloud=$null; Allowed=$true; FailReset=$true }
)

foreach ($case in $cases) {
    & {
        param($case, $resetScript)
        . $resetScript
        $backendMode = [bool]$case.Backend
        $Method = [string]$case.Method
        $isWinPE = [bool]$case.WinPE
        $script:WdlGuiSessionAuthenticated = $false
        $script:WdlGuiBusy = [bool]$case.Busy
        $script:WdlGuiSupport = [pscustomobject]@{ Supported=(-not $case.Unsupported) }
        $script:WdlGuiLocalAssociation = [pscustomobject]@{
            FirmwareState=$(if ($case.Firmware) { $case.Firmware } else { '4/4' })
        }
        $script:WdlGuiCloudStatus = $case.Cloud
        $script:GuiResetTrace = New-Object System.Collections.Generic.List[string]
        $script:GuiResetPrompt = $null
        $script:GuiResetStatus = $null

        function Confirm-GuiAction {
            param($Title, $Message, [switch]$DefaultNo)
            if (-not $DefaultNo) { throw 'Local reset confirmation must default to No.' }
            $script:GuiResetTrace.Add('Confirm')
            $script:GuiResetPrompt = $Message
            return (-not $case.Cancel)
        }
        function Set-GuiBusy {
            param([bool]$Busy, [string]$StatusText)
            $script:WdlGuiBusy = $Busy
        }
        function Write-GuiConsole {
            param($Message, [switch]$Command, [switch]$Warning)
            if ($Warning) { $script:GuiResetTrace.Add('Warning') }
        }
        function Write-GuiObject { param($InputObject) }
        function Reset-WindowsDeviceLinkFirmwareState {
            [CmdletBinding(SupportsShouldProcess)] param()
            $script:GuiResetTrace.Add('Reset')
            if ($case.FailReset) { throw 'Mock firmware reset failure.' }
        }
        function Refresh-LocalView { $script:GuiResetTrace.Add('RefreshLocal') }
        function Set-GuiStatus { param($Message) $script:GuiResetStatus=$Message }
        function Show-GuiError { param($Message) $script:GuiResetTrace.Add('Error') }
        function Refresh-CloudView { throw 'Local reset must not check the cloud.' }
        function Get-GuiAuthParameters { throw 'Local reset must not request authentication.' }
        function Invoke-GuiSignIn { throw 'Local reset must not sign in.' }

        if ((Test-GuiLocalResetAvailable) -ne $case.Allowed) {
            throw "FAIL: $($case.Name) availability is incorrect."
        }
        Invoke-GuiLocalOffboard
        $expectedTrace = if (-not $case.Allowed -or $case.Busy) { '' }
            elseif ($case.Cancel) { 'Confirm' }
            elseif ($case.FailReset) { 'Confirm,Warning,Reset,Error' }
            else { 'Confirm,Warning,Reset,RefreshLocal' }
        if (($script:GuiResetTrace -join ',') -ne $expectedTrace) {
            throw "FAIL: $($case.Name) unexpected execution: $($script:GuiResetTrace -join ',')."
        }
        if ($script:GuiResetPrompt -and ($script:GuiResetPrompt -notmatch 'No online check' -or
            $script:GuiResetPrompt -notmatch 'registration remains unchanged')) {
            throw "FAIL: $($case.Name) must disclose the offline scope and remaining cloud registration."
        }
        if ($expectedTrace -eq 'Confirm,Warning,Reset,RefreshLocal' -and
            $script:GuiResetStatus -ne 'Local state reset; cloud registration unchanged') {
            throw "FAIL: $($case.Name) must not report full offboarding."
        }
        if ($case.FailReset -and $script:GuiResetStatus -ne 'Local offboarding failed') {
            throw 'FAIL: A failed local reset must not report success.'
        }
        if (-not [object]::ReferenceEquals($script:WdlGuiCloudStatus, $case.Cloud)) {
            throw 'FAIL: A local reset must not change or clear the last cloud observation.'
        }
        if (-not $case.Busy -and $script:WdlGuiBusy) { throw 'FAIL: Reset must release the busy state.' }
    } $case $resetScript
    Write-Host "PASS: $($case.Name)"
}

# Elevation must be checked before configuration retrieval or GUI/firmware work.
$elevationGuard = $command.ScriptBlock.Ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.IfStatementAst] -and
    $node.Clauses[0].Item1.Extent.Text -eq '-not (Test-WindowsDeviceLinkElevation)'
}, $true)
if (-not $elevationGuard -or $elevationGuard.Extent.Text -notmatch 'Run as administrator' -or
    -not $elevationGuard.Find({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true)) {
    throw 'FAIL: Non-elevated startup must give actionable guidance and return before opening the dashboard.'
}
if ($source.IndexOf('Test-WindowsDeviceLinkElevation') -gt $source.IndexOf('Read-WindowsDeviceLinkConfiguration') -or
    $source.IndexOf('Test-WindowsDeviceLinkElevation') -gt $source.IndexOf('$form = New-Object')) {
    throw 'FAIL: Elevation must be checked before configuration retrieval and dashboard creation.'
}
$module = Get-Module WindowsDeviceLink | Select-Object -First 1
$actualElevation = & $module { Test-WindowsDeviceLinkElevation }
$testIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
try {
    $testPrincipal = New-Object Security.Principal.WindowsPrincipal($testIdentity)
    $expectedElevation = $testPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($actualElevation -ne $expectedElevation) { throw 'FAIL: Elevation detection disagrees with the process token.' }
}
finally { $testIdentity.Dispose() }

Write-Host 'PASS: Show-WindowsDeviceLink is exported, WinPE-aware, WinForms-based, runtime-path capable, and delegates lifecycle actions to existing cmdlets.'
