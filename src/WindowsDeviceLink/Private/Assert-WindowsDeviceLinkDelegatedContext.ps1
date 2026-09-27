function Assert-WindowsDeviceLinkDelegatedContext {
    [CmdletBinding()]
    param()

    $context = Get-MgContext
    if (-not $context -or [string]$context.AuthType -ne 'Delegated') {
        throw 'Direct mode requires an authenticated delegated operator session. Sign in using Interactive or DeviceCode, or use Backend mode for automation.'
    }
}
