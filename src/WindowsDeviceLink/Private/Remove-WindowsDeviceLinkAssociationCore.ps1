function Remove-WindowsDeviceLinkAssociationCore {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [ValidateNotNullOrEmpty()][string]$AssociationId,
        [ValidateNotNullOrEmpty()][string]$SerialNumber,
        [Parameter(Mandatory)][ValidateSet('DeviceCode','Interactive','AccessToken')][string]$Method,
        [ValidateNotNullOrEmpty()][string]$TenantId,
        [ValidateNotNullOrEmpty()][string]$ClientId,
        [securestring]$AccessToken,
        [ValidateNotNullOrEmpty()][string]$Environment = 'Global',
        [ValidateRange(1,600)][double]$ClientTimeout = 100
    )

    if(-not [string]::IsNullOrWhiteSpace($AssociationId) -and -not [string]::IsNullOrWhiteSpace($SerialNumber)){throw 'Specify either -AssociationId or -SerialNumber, not both.'}
    if([string]::IsNullOrWhiteSpace($AssociationId) -and [string]::IsNullOrWhiteSpace($SerialNumber)){
        try {
            $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
            $SerialNumber = [string]$bios.SerialNumber
        }
        catch {
            if(Get-Command Get-WmiObject -ErrorAction SilentlyContinue){
                try {$SerialNumber=[string](Get-WmiObject -Class Win32_BIOS -ErrorAction Stop).SerialNumber}catch{}
            }
        }
        if([string]::IsNullOrWhiteSpace($SerialNumber)){throw 'No target was specified and the local device serial number could not be determined. Specify -SerialNumber or -AssociationId explicitly.'}
        $SerialNumber=$SerialNumber.Trim()
        Write-Information -InformationAction Continue -MessageData "No target specified. Using local device serial number: $SerialNumber"
    }
    $allowedByMethod=@{
        DeviceCode=@('TenantId','ClientId');Interactive=@('TenantId','ClientId');AccessToken=@('TenantId','AccessToken')

    }
    $methodSpecificParameters=@('TenantId','ClientId','AccessToken')
    $invalidParameters=$methodSpecificParameters|Where-Object{$PSBoundParameters.ContainsKey($_)-and $_ -notin $allowedByMethod[$Method]}
    if($invalidParameters){throw "The following parameters are not valid with -Method $Method`: $($invalidParameters -join ', ')."}

    switch($Method){
        'AccessToken'{if (-not $PSBoundParameters.ContainsKey('AccessToken')) { throw '-AccessToken is required for -Method AccessToken.' }}

    }

    $baseUri='https://graph.microsoft.com/beta';$resolvedAssociationId=$AssociationId;$resolvedSerialNumber=$SerialNumber;$nativeAccessToken=$null;$sdkMode=$false
    if($Method -in @('DeviceCode','AccessToken')){
        if($Environment -ne 'Global'){throw 'Native association removal currently supports the Global Microsoft cloud only.'}
        switch($Method){
            'DeviceCode'{$tokenParameters=@{};if($TenantId){$tokenParameters.TenantId=$TenantId};if($ClientId){$tokenParameters.ClientId=$ClientId};Write-Information -InformationAction Continue -MessageData 'Using native OAuth device-code authentication for Device Association removal.';$token=Get-WindowsDeviceLinkDeviceCodeToken @tokenParameters;$nativeAccessToken=$token.AccessToken;$TenantId=$token.TenantId}

            'AccessToken'{$credential=New-Object System.Management.Automation.PSCredential('token',$AccessToken);$nativeAccessToken=$credential.GetNetworkCredential().Password;if(-not $TenantId){$TenantId=Resolve-WindowsDeviceLinkAccessTokenTenantId -AccessToken $nativeAccessToken};$credential=$null}
        }
    } else {
        $connectParams=@{Environment=$Environment;ClientTimeout=$ClientTimeout}
        switch($Method){
            'Interactive'{if($TenantId){$connectParams.TenantId=$TenantId};if($ClientId){$connectParams.ClientId=$ClientId}}

        }
        Connect-WindowsDeviceLink @connectParams|Out-Null;$sdkMode=$true;$context=Get-MgContext;if($context -and $context.TenantId){$TenantId=$context.TenantId}
    }

    try{
        $graphReadParameters=@{};if($sdkMode){$graphReadParameters.SdkMode=$true}else{$graphReadParameters.AccessToken=$nativeAccessToken}
        if(-not $resolvedAssociationId){
            $escapedSerial=$SerialNumber.Replace("'","''");$filter=[uri]::EscapeDataString("serialNumber eq '$escapedSerial'");$lookupUri="$baseUri/deviceManagement/tenantAssociatedDevices?`$filter=$filter"
            $filteredRecords=@(Get-WindowsDeviceLinkGraphCollection -Uri $lookupUri @graphReadParameters)
            $matches=@(Resolve-WindowsDeviceLinkSerialAssociationRecords -Records $filteredRecords -SerialNumber $SerialNumber)
            if($matches.Count -eq 0){
                Write-Information -InformationAction Continue -MessageData 'Filtered serial-number lookup returned no exact match; retrying with client-side matching.'
                $allRecords=@(Get-WindowsDeviceLinkGraphCollection -Uri "$baseUri/deviceManagement/tenantAssociatedDevices" @graphReadParameters)
                $matches=@(Resolve-WindowsDeviceLinkSerialAssociationRecords -Records $allRecords -SerialNumber $SerialNumber -RequireCompleteSerialCoverage)
            }
            if($matches.Count -eq 0){throw "No Device Association record was found for serial number '$SerialNumber'."}
            $resolvedAssociationId=[string]$matches[0].id;$resolvedSerialNumber=[string]$matches[0].serialNumber
            if([string]::IsNullOrWhiteSpace($resolvedAssociationId) -or $resolvedAssociationId -eq [guid]::Empty.ToString()){throw "Microsoft Graph returned a malformed Device Association record for serial number '$SerialNumber': association ID is missing or empty."}
        }

        $deleteUri="$baseUri/deviceManagement/tenantAssociatedDevices/$resolvedAssociationId";$target=if($resolvedSerialNumber){"$resolvedSerialNumber ($resolvedAssociationId)"}else{$resolvedAssociationId}
        if($PSCmdlet.ShouldProcess($target,'Remove Device Association record')){
            try{
                # DELETE is intentionally not automatically retried. A timeout may occur after
                # Graph has already committed the deletion, so blind retry is unsafe.
                if($sdkMode){Invoke-WindowsDeviceLinkGraphDelete -Uri $deleteUri -SdkMode}
                else{Invoke-WindowsDeviceLinkGraphDelete -Uri $deleteUri -AccessToken $nativeAccessToken}
            }catch{
                if($_.Exception.Message -match 'HTTP 404'){throw "Device Association '$resolvedAssociationId' was not found or has already been removed."}
                throw "Device Association removal failed. Association ID: $resolvedAssociationId. $($_.Exception.Message)"
            }
            Write-Information -InformationAction Continue -MessageData "Device Association removed successfully. Association ID: $resolvedAssociationId"
            [pscustomobject]@{PSTypeName='Windows.DeviceLink.AssociationRemovalResult';AssociationId=$resolvedAssociationId;SerialNumber=$resolvedSerialNumber;TenantId=$TenantId;Removed=$true}
        }
    }finally{$nativeAccessToken=$null}
}
