[CmdletBinding()]
param([string]$ModulePath = (Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1'))
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force
$module=Get-Module WindowsDeviceLink
function Assert-True($Condition,$Message) { if (-not $Condition) { throw "FAIL: $Message" } }
function Read-TestConfiguration([string]$Value) { @(& $module { param($v) Read-WindowsDeviceLinkConfiguration -Configuration $v } $Value) }
function Assert-Rejected([string]$Json) {
    $rejected=$false
    try { $null=Read-TestConfiguration $Json } catch { $rejected=$true }
    Assert-True $rejected 'Invalid configuration was accepted'
}
$a='11111111-1111-1111-1111-111111111111'; $b='22222222-2222-2222-2222-222222222222'
$shared='33333333-3333-3333-3333-333333333333'; $override='44444444-4444-4444-4444-444444444444'
$config=@{ schemaVersion=1;mode='Direct';clientId=$shared;tenants=@(@{name='Tenant Alpha';tenantId=$a},@{name='Tenant Beta';tenantId=$b;clientId=$override}) }
$json=$config | ConvertTo-Json -Depth 5
$entries=@(Read-TestConfiguration $json)
Assert-True ($entries.Count -eq 2 -and $entries[0].ClientId -eq $shared -and $entries[1].ClientId -eq $override) 'Tenant clientId must override the shared clientId'
$single=@{schemaVersion=1;mode='Direct';tenants=@(@{name='Tenant Alpha';tenantId=$a})}|ConvertTo-Json -Depth 5
$one=@(Read-TestConfiguration $single)
Assert-True ($one.Count -eq 1 -and -not $one[0].ClientId) 'Omitted clientId must leave the authentication default intact'
$tempPath=Join-Path ([IO.Path]::GetTempPath()) ('wdl-config-'+[guid]::NewGuid()+'.json')
try {
    $json | Set-Content -LiteralPath $tempPath -Encoding UTF8
    $file=@(Read-TestConfiguration $tempPath)
    Assert-True ($file[1].ClientId -eq $override -and $file[0].Source -ne 'Inline JSON') 'Local configuration loading failed'
} finally { Remove-Item -LiteralPath $tempPath -ErrorAction SilentlyContinue }
# Mock only the HTTP boundary. Use the production reader and parser.
& $module {
    param($Json)
    $script:ConfigurationResponse=$Json; $script:ConfigurationRequests=0
    function script:Invoke-WebRequest {
        param($Uri,$Method,[switch]$UseBasicParsing,$MaximumRedirection,$TimeoutSec,$ErrorAction)
        if ($Uri -ne 'https://config.example.com/devicelink.json' -or $Method -ne 'Get' -or $MaximumRedirection -ne 0 -or $TimeoutSec -ne 15) { throw 'Unsafe download arguments' }
        $script:ConfigurationRequests++
        [pscustomobject]@{StatusCode=200;Content=$script:ConfigurationResponse}
    }
} $json
$web=@(Read-TestConfiguration 'https://config.example.com/devicelink.json')
Assert-True ($web.Count -eq 2 -and $web[1].ClientId -eq $override) 'HTTPS configuration loading failed'
foreach ($invalidUri in @('http://config.example.com/config.json','ftp://config.example.com/config.json','https://user:password@config.example.com/config.json','https://config.example.com/config.json#fragment')) { Assert-Rejected $invalidUri }
Assert-True ((& $module {$script:ConfigurationRequests}) -eq 1) 'Invalid URL was requested'
& $module { $script:ConfigurationResponse='not json' }
Assert-Rejected 'https://config.example.com/devicelink.json'
foreach ($bad in @(
    '{}','[]',"[$single]",'{bad json}',
    '{"schemaVersion":2,"mode":"Direct","tenants":[]}',
    '{"schemaVersion":"1","mode":"Direct","tenants":[]}',
    '{"schemaVersion":true,"mode":"Direct","tenants":[]}',
    '{"schemaVersion":1,"mode":"Backend","tenants":[]}',
    '{"schemaVersion":1,"mode":"Direct","tenants":[]}',
    '{"schemaVersion":1,"mode":"Direct","tenants":{}}'
)) { Assert-Rejected $bad }
foreach ($change in @(
    {param($c)$c.clientId='invalid'},
    {param($c)$c.clientSecret='must-not-be-accepted'},
    {param($c)$c.tenants[0].tenantId='00000000-0000-0000-0000-000000000000'},
    {param($c)$c.tenants[0].name=' '},
    {param($c)$c.tenants[0].name="Bad`nName"},
    {param($c)$c.tenants[0].tenantId=@('not-a-guid')},
    {param($c)$c.tenants[0].clientId=$null},
    {param($c)$c.tenants[1].name='tenant alpha'},
    {param($c)$c.tenants[1].tenantId=$c.tenants[0].tenantId},
    {param($c)$c.tenants[1].secret='not-allowed'}
)) {
    # Use hashtables so new/unknown fields can be introduced on Windows PowerShell 5.1.
    $candidate=@{schemaVersion=1;mode='Direct';clientId=$shared;tenants=@(@{name='Tenant Alpha';tenantId=$a},@{name='Tenant Beta';tenantId=$b})}
    & $change $candidate
    Assert-Rejected ($candidate|ConvertTo-Json -Depth 6)
}
foreach ($conflict in @(@{TenantId=$a},@{ClientId=$shared},@{BackendUri='https://backend.example.com/api/devicelink';BackendApiKey=(ConvertTo-SecureString 'synthetic' -AsPlainText -Force)})) {
    $blocked=$false
    try { Show-WindowsDeviceLink -Configuration $single @conflict } catch { $blocked=$_.Exception.Message -like '*cannot be combined*' }
    Assert-True $blocked 'Conflicting GUI configuration must fail before creating a window'
}
Write-Host 'PASS: file, inline and HTTPS sources share schema, GUID, duplicate, unknown-field and conflict validation'

# Exercise actual GUI selection/auth/display functions without loading WinForms.
$gui=(Get-Command Show-WindowsDeviceLink).ScriptBlock
$guiText=$gui.ToString()
$loadAst=$gui.Ast.Find({param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
    $n.Left.VariablePath.UserPath -eq 'configuredTenants'
},$true)
Assert-True ($null -ne $loadAst) 'GUI configuration loading statement not found'
$loadConfiguration=[scriptblock]::Create($loadAst.Extent.Text)
$start=$guiText.IndexOf('    $effectiveTenants = @{}')
$end=$guiText.IndexOf('    function Get-SelectedTenantId')
$setup=[scriptblock]::Create($guiText.Substring($start,$end-$start))
& {
    # Bridge the private production reader; do not pre-wrap its output here.
    # The previous test injected an array and skipped the GUI's scalar-producing
    # assignment, masking single-tenant failures on Windows PowerShell 5.1.
    function Read-WindowsDeviceLinkConfiguration {
        param([string]$Configuration)
        & $module {param($Value) Read-WindowsDeviceLinkConfiguration -Configuration $Value} $Configuration
    }
    foreach ($name in @('Get-SelectedTenantId','Get-SelectedClientId','Get-TenantDisplayName','Get-GuiAuthParameters','Update-GuiTargetTenantDisplay')) {
        $ast=$gui.Ast.Find({param($n)$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
        . ([scriptblock]::Create($ast.Extent.Text))
    }
    $outerBoundParameters=@{}; $backendMode=$false; $usesInteractiveUserAuthentication=$true
    $Method='Interactive'; $Environment='Global'; $ClientTimeout=100
    $tenantSelector=[pscustomobject]@{SelectedItem=$null}
    $targetTenantValue=[pscustomobject]@{Text=''}; $targetTenantDescription=[pscustomobject]@{Text=''}
    $toolTip=New-Object psobject; $toolTip|Add-Member ScriptMethod SetToolTip {param($Control,$Text)}
    $script:WdlGuiSessionAuthenticated=$false; $script:WdlGuiSessionTenantId=$null
    $singlePath=Join-Path ([IO.Path]::GetTempPath()) ('wdl-single-'+[guid]::NewGuid()+'.json')
    try {
        $single | Set-Content -LiteralPath $singlePath -Encoding UTF8
        & $module {param($Json) $script:ConfigurationResponse=$Json} $single
        foreach ($source in @($single,$singlePath,'https://config.example.com/devicelink.json')) {
            $Configuration=$source; $outerBoundParameters=@{Configuration=$source}
            . $loadConfiguration
            Assert-True ($configuredTenants -is [array] -and $configuredTenants.Count -eq 1) 'GUI must retain one configured tenant as an array'
            . $setup
            Assert-True (-not $showTenantSelector -and (Get-SelectedTenantId) -eq $a) 'Single tenant must be fixed with no selector'
            Update-GuiTargetTenantDisplay
            Assert-True ($targetTenantValue.Text -eq 'Tenant Alpha') 'Single tenant name must display before sign-in'
            $auth=Get-GuiAuthParameters
            Assert-True ($auth.TenantId -eq $a -and -not $auth.ContainsKey('ClientId')) 'Single default-client auth parameters incorrect'
            $script:WdlGuiSessionAuthenticated=$true; $script:WdlGuiSessionTenantId=$a
            Update-GuiTargetTenantDisplay
            Assert-True ($targetTenantValue.Text -eq 'Tenant Alpha') 'Single tenant name must persist after sign-in'
            $script:WdlGuiSessionAuthenticated=$false; $script:WdlGuiSessionTenantId=$null
            Update-GuiTargetTenantDisplay
            Assert-True ($targetTenantValue.Text -eq 'Tenant Alpha' -and (Get-SelectedTenantId) -eq $a) 'Sign-out must preserve the fixed configuration tenant'
        }
    } finally { Remove-Item -LiteralPath $singlePath -ErrorAction SilentlyContinue }
    $Configuration=$json; $outerBoundParameters=@{Configuration=$json}
    . $loadConfiguration
    Assert-True ($configuredTenants -is [array] -and $configuredTenants.Count -eq 2) 'GUI must retain multiple configured tenants'
    . $setup
    Assert-True $showTenantSelector 'Multiple tenants require a selector'
    $blocked=$false
    try { Get-GuiAuthParameters | Out-Null } catch { $blocked=$true }
    Assert-True $blocked 'Multitenant sign-in must require an explicit choice'
    $tenantSelector.SelectedItem='Tenant Beta'
    $auth=Get-GuiAuthParameters
    Assert-True ($auth.TenantId -eq $b -and $auth.ClientId -eq $override) 'Selected tenant clientId not forwarded to Interactive'
    $tenantSelector.SelectedItem='Tenant Alpha'
    $auth=Get-GuiAuthParameters
    Assert-True ($auth.TenantId -eq $a -and $auth.ClientId -eq $shared) 'Shared clientId not forwarded to Interactive'
    function Clear-GuiSessionAuthentication { $script:WdlGuiSessionAccessToken=$null; $script:WdlGuiSessionAuthenticated=$false }
    function Set-GuiSigningInState {}
    function Write-GuiConsole {param($Message)}
    function Invoke-GuiInformationCommand {param($ScriptBlock) & $ScriptBlock}
    function Get-WindowsDeviceLinkDeviceCodeToken {
        param($TenantId,$ClientId)
        $script:CapturedDeviceCodeClient=$ClientId
        [pscustomobject]@{AccessToken='synthetic';TenantId=$TenantId;ExpiresIn=3600;AccountName='operator@example.invalid'}
    }
    $ui=@{Authentication=[pscustomobject]@{Text=''}}; $btnSignIn=[pscustomobject]@{Text=''}
    $Method='DeviceCode'; $tenantSelector.SelectedItem='Tenant Beta'
    $script:WdlGuiSessionAccessToken=$null
    $auth=Get-GuiAuthParameters
    Assert-True ($script:CapturedDeviceCodeClient -eq $override -and $auth.TenantId -eq $b) 'Selected clientId not forwarded to DeviceCode'
    $ClientId=$shared; $TenantId=$a; $outerBoundParameters=@{ClientId=$shared;TenantId=$a}
    . $loadConfiguration
    Assert-True ($configuredTenants -is [array] -and $configuredTenants.Count -eq 0) 'No configuration must produce an empty array'
    . $setup
    $tenantSelector.SelectedItem=$null
    Assert-True ((Get-SelectedClientId) -eq $shared -and (Get-SelectedTenantId) -eq $a -and -not $showTenantSelector) 'Explicit no-configuration behavior changed'
    $outerBoundParameters=@{}
    Assert-True (-not (Get-SelectedClientId) -and -not (Get-SelectedTenantId)) 'Default sign-in must not retain configuration choices'
}
Write-Host 'PASS: single/multiple tenant UI selection, name display and Interactive/DeviceCode client routing'

# Exercise the real sign-out handler and idle-state restoration. Previously sign-out
# refreshed action buttons only, leaving a multi-tenant selector disabled until a
# separate operation (for example Refresh local) restored the idle controls.
Add-Type -AssemblyName System.Windows.Forms
& {
    foreach ($name in @('Invoke-GuiSignIn','Clear-GuiSessionAuthentication','Set-GuiBusy','Get-SelectedTenantId')) {
        $ast=$gui.Ast.Find({param($n)$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
        . ([scriptblock]::Create($ast.Extent.Text))
    }
    function New-TestControl {
        $control=[pscustomobject]@{Enabled=$true;Text='';Visible=$false;UseWaitCursor=$false;ToolTipText=''}
        $control | Add-Member ScriptMethod Invalidate {param($Children)}
        $control | Add-Member ScriptMethod Update {}
        return $control
    }
    function Disconnect-MgGraph { param($ErrorAction) $script:SignOutDisconnected=$true }
    function Get-TenantDisplayName { param($TenantId) 'Tenant Alpha' }
    function Update-GuiTargetTenantDisplay {}
    function Set-GuiCapabilities { $script:SignOutCapabilitiesRefreshed=$true }
    function Set-GuiStatus { param($Text) $script:SignOutStatus=$Text }
    function Write-GuiConsole { param($Message) }
    $toolTip=New-Object psobject; $toolTip | Add-Member ScriptMethod SetToolTip {param($Control,$Text) $Control.ToolTipText=$Text}
    $ui=@{Authentication=(New-TestControl);Endpoint=(New-TestControl);TenantScope=(New-TestControl)}
    foreach ($name in @('CloudState','CloudTenant','CloudId','CloudChecked')) { $ui[$name]=New-TestControl }
    $tenantSelector=New-TestControl; $actionsPanel=New-TestControl; $form=New-TestControl
    $tenantSelector | Add-Member NoteProperty SelectedIndex 1
    $tenantSelector | Add-Member ScriptProperty SelectedItem { if ($this.SelectedIndex -eq 0) { 'Select target tenant...' } else { 'Tenant Alpha' } }
    $tenantChoiceLookup=@{'Select target tenant...'=$null;'Tenant Alpha'='11111111-1111-1111-1111-111111111111'}
    $outerBoundParameters=@{}
    $btnSignIn=New-TestControl; $btnCopyActivity=New-TestControl; $btnClearActivity=New-TestControl
    $statusProgress=New-TestControl; $allActionButtons=@($btnSignIn)
    $backendMode=$false; $usesInteractiveUserAuthentication=$true
    foreach ($Method in @('Interactive','DeviceCode')) {
        foreach ($showTenantSelector in @($true,$false)) {
            $tenantSelector.SelectedIndex=1
            $fixedConfigurationTenantId=if ($showTenantSelector) { $null } else { '11111111-1111-1111-1111-111111111111' }
            $script:WdlGuiSessionAuthenticated=$true
            $script:WdlGuiSessionTenantId=Get-SelectedTenantId
            $script:WdlGuiSessionAccountName='operator@example.invalid'
            $script:WdlGuiSessionAccessToken='synthetic'
            $script:WdlGuiSessionExpiresUtc=[datetime]::UtcNow.AddHours(1)
            $script:WdlGuiCloudStatus=[pscustomobject]@{AssociationPresent=$true;AssociationState='associated';TenantId=(Get-SelectedTenantId);AssociationId='synthetic-association'}
            foreach ($name in @('CloudState','CloudTenant','CloudId','CloudChecked')) {
                $ui[$name].Text='Previous cloud result'
                $ui[$name].ToolTipText='Previous cloud detail'
            }
            Set-GuiBusy -Busy $false
            Assert-True (-not $tenantSelector.Enabled) 'Signed-in tenant selector must stay locked'
            $script:SignOutDisconnected=$false; $script:SignOutCapabilitiesRefreshed=$false
            Invoke-GuiSignIn
            Assert-True (-not $script:WdlGuiSessionAuthenticated -and -not $script:WdlGuiSessionAccessToken -and -not $script:WdlGuiSessionTenantId -and -not $script:WdlGuiSessionAccountName -and -not $script:WdlGuiSessionExpiresUtc) 'Sign-out must clear authentication state'
            Assert-True ($tenantSelector.Enabled -eq $showTenantSelector) 'Sign-out must immediately unlock only a visible tenant selector'
            Assert-True ($script:SignOutCapabilitiesRefreshed -and $script:SignOutStatus -eq 'Signed out') 'Sign-out must refresh capabilities and status'
            Assert-True ($script:SignOutDisconnected -eq ($Method -eq 'Interactive')) 'Sign-out must disconnect Graph only for Interactive'
            Assert-True ($ui.Endpoint.Text -eq 'Not signed in' -and $btnSignIn.Text -eq 'Sign in') 'Sign-out must clear account display'
            if ($showTenantSelector) {
                Assert-True ($tenantSelector.SelectedIndex -eq 0 -and -not (Get-SelectedTenantId)) 'Sign-out must reset the multi-tenant choice to the placeholder with no effective target'
                Assert-True ($ui.TenantScope.Text -eq 'Not selected' -and $ui.TenantScope.ToolTipText -eq 'Not selected') 'Sign-out must clear the previous tenant scope and tooltip'
            }
            else {
                Assert-True ((Get-SelectedTenantId) -eq $fixedConfigurationTenantId -and $ui.TenantScope.Text -eq 'Tenant Alpha') 'Sign-out must preserve a fixed configuration tenant'
            }
            Assert-True ($null -eq $script:WdlGuiCloudStatus) 'Sign-out must discard cached cloud association state'
            foreach ($name in @('CloudState','CloudTenant','CloudId','CloudChecked')) {
                Assert-True ($ui[$name].Text -eq 'Not checked' -and $ui[$name].ToolTipText -eq 'Not checked') "Sign-out must clear $name and its tooltip"
            }
        }
    }
}
Write-Host 'PASS: Interactive/DeviceCode sign-out clears authentication/cloud state and immediately restores tenant selection'
