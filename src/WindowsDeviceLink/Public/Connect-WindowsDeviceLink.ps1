function Connect-WindowsDeviceLink {
    <#
    .SYNOPSIS
    Signs an operator into Microsoft Graph using Interactive or DeviceCode authentication.
    .DESCRIPTION
    Direct access requires delegated operator authentication. Use Backend mode for
    unattended provisioning. TenantId is optional; sign-in determines the tenant.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [ValidateNotNullOrEmpty()][string]$TenantId,
        [ValidateNotNullOrEmpty()][string]$ClientId,
        [ValidateNotNullOrEmpty()][string[]]$Scopes = @('DeviceManagementServiceConfig.ReadWrite.All'),
        [Parameter(Mandatory, ParameterSetName = 'DeviceCode')][switch]$UseDeviceCode,
        [ValidateNotNullOrEmpty()][string]$Environment = 'Global',
        [ValidateRange(1, 600)][double]$ClientTimeout = 100
    )

    Initialize-WindowsDeviceLinkOnline
    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is unavailable after dependency initialization.'
    }

    $parameters = @{
        Environment = $Environment
        ClientTimeout = $ClientTimeout
        NoWelcome = $true
        ContextScope = 'Process'
        Scopes = $Scopes
    }
    if ($TenantId) { $parameters.TenantId = $TenantId }
    if ($ClientId) { $parameters.ClientId = $ClientId }
    if ($UseDeviceCode) { $parameters.UseDeviceCode = $true }
    elseif (Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT') {
        throw 'Interactive authentication is unavailable in WinPE. Use DeviceCode or Backend mode.'
    }

    $result = Invoke-WindowsDeviceLinkGraphConnect -Parameters $parameters -MethodName $PSCmdlet.ParameterSetName
    Assert-WindowsDeviceLinkDelegatedContext
    if (-not $UseDeviceCode) {
        Write-Warning "If Windows asks whether to sign in to all apps, select 'No, this app only' to avoid registering this device in the signed-in tenant."
    }
    $result
}
