[CmdletBinding()]
param([string]$ModulePath = (Join-Path $PSScriptRoot '..\src\WindowsDeviceLink\WindowsDeviceLink.psd1'))
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force
$module=Get-Module WindowsDeviceLink
function Assert-True($Condition,$Message) { if (-not $Condition) { throw "FAIL: $Message" } }
function Assert-Rejected([string]$Json) {
    $rejected=$false
    try { $null=Get-WindowsDeviceLinkTenantCatalog -Configuration $Json } catch { $rejected=$true }
    Assert-True $rejected 'Invalid configuration was accepted'
}
$a='11111111-1111-1111-1111-111111111111'; $b='22222222-2222-2222-2222-222222222222'
$shared='33333333-3333-3333-3333-333333333333'; $override='44444444-4444-4444-4444-444444444444'
$config=@{ schemaVersion=1;mode='Direct';clientId=$shared;tenants=@(@{name='Tenant Alpha';tenantId=$a},@{name='Tenant Beta';tenantId=$b;clientId=$override}) }
$json=$config | ConvertTo-Json -Depth 5
$entries=@(Get-WindowsDeviceLinkTenantCatalog -Configuration $json)
Assert-True ($entries.Count -eq 2 -and $entries[0].ClientId -eq $shared -and $entries[1].ClientId -eq $override) 'Tenant clientId must override the shared clientId'
$single=@{schemaVersion=1;mode='Direct';tenants=@(@{name='Tenant Alpha';tenantId=$a})}|ConvertTo-Json -Depth 5
$one=@(Get-WindowsDeviceLinkTenantCatalog -Configuration $single)
Assert-True ($one.Count -eq 1 -and -not $one[0].ClientId) 'Omitted clientId must leave the authentication default intact'
$tempPath=Join-Path ([IO.Path]::GetTempPath()) ('wdl-config-'+[guid]::NewGuid()+'.json')
try {
    $json | Set-Content -LiteralPath $tempPath -Encoding UTF8
    $file=@(Get-WindowsDeviceLinkTenantCatalog -Configuration $tempPath)
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
$web=@(Get-WindowsDeviceLinkTenantCatalog -Configuration 'https://config.example.com/devicelink.json')
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
$start=$guiText.IndexOf('    $effectiveTenants = @{}')
$end=$guiText.IndexOf('    function Get-SelectedTenantId')
$setup=[scriptblock]::Create($guiText.Substring($start,$end-$start))
& {
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
    $configuredTenants=$one
    . $setup
    Assert-True (-not $showTenantSelector -and (Get-SelectedTenantId) -eq $a) 'Single tenant must be fixed with no selector'
    Update-GuiTargetTenantDisplay
    Assert-True ($targetTenantValue.Text -eq 'Tenant Alpha') 'Single tenant name must display before sign-in'
    $auth=Get-GuiAuthParameters
    Assert-True ($auth.TenantId -eq $a -and -not $auth.ContainsKey('ClientId')) 'Single default-client auth parameters incorrect'
    $configuredTenants=$entries
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
    $configuredTenants=@(); $ClientId=$shared; $TenantId=$a; $outerBoundParameters=@{ClientId=$shared;TenantId=$a}
    . $setup
    $tenantSelector.SelectedItem=$null
    Assert-True ((Get-SelectedClientId) -eq $shared -and (Get-SelectedTenantId) -eq $a -and -not $showTenantSelector) 'Explicit no-configuration behavior changed'
    $outerBoundParameters=@{}
    Assert-True (-not (Get-SelectedClientId) -and -not (Get-SelectedTenantId)) 'Default sign-in must not retain configuration choices'
}
Write-Host 'PASS: single/multiple tenant UI selection, name display and Interactive/DeviceCode client routing'
