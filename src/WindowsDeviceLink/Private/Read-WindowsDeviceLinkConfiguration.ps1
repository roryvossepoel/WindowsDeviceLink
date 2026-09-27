function Read-WindowsDeviceLinkConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Configuration)

    $value = $Configuration.Trim().TrimStart([char]0xFEFF)
    $source = 'Inline JSON'
    if ($value.StartsWith('{') -or $value.StartsWith('[')) {
        $json = $value
    }
    elseif ($value -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        $uri = $null
        if (-not [uri]::TryCreate($value,[UriKind]::Absolute,[ref]$uri) -or
            $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Fragment) {
            throw 'Configuration URLs must use HTTPS without embedded credentials or a fragment.'
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        try {
            # Do not follow redirects to another origin or to HTTP. Configuration is data, never code.
            $response = Invoke-WebRequest -Uri $uri.AbsoluteUri -Method Get -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 15 -ErrorAction Stop
            if ([int]$response.StatusCode -ne 200) { throw 'Unexpected HTTP status.' }
            $json = [string]$response.Content
        }
        catch { throw 'Unable to download configuration. Use a trusted HTTPS endpoint that returns JSON directly (no redirects).' }
        $source = $uri.GetLeftPart([UriPartial]::Path)
    }
    else {
        try {
            $path = Resolve-Path -LiteralPath $Configuration -ErrorAction Stop
            if ($path.Provider.Name -ne 'FileSystem' -or -not (Test-Path -LiteralPath $path.ProviderPath -PathType Leaf)) {
                throw 'Not a file.'
            }
            if ((Get-Item -LiteralPath $path.ProviderPath).Length -gt 1MB) { throw 'File too large.' }
            $json = Get-Content -LiteralPath $path.ProviderPath -Raw -Encoding UTF8 -ErrorAction Stop
            $source = $path.ProviderPath
        }
        catch { throw 'Unable to read configuration. Supply an existing JSON file (up to 1 MiB), an HTTPS URL, or inline JSON.' }
    }

    if ([string]::IsNullOrWhiteSpace($json) -or [Text.Encoding]::UTF8.GetByteCount($json) -gt 1MB) {
        throw 'Configuration must contain JSON and must not exceed 1 MiB.'
    }
    # The root must be an object; ConvertFrom-Json can unwrap single-element arrays.
    if (-not $json.Trim().TrimStart([char]0xFEFF).StartsWith('{')) { throw 'Configuration must be a JSON object.' }
    try { $document = ConvertFrom-Json -InputObject $json -ErrorAction Stop }
    catch { throw 'Configuration contains invalid JSON.' }
    ConvertTo-WindowsDeviceLinkTenantCatalog -InputObject $document -Source $source
}
