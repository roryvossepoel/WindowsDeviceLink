function Test-WindowsDeviceLinkElevation {
    [CmdletBinding()]
    param()

    $identity = $null
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $identity) { $identity.Dispose() }
    }
}
