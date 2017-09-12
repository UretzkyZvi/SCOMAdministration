#=================================================================================
#  Script to ping check via PowerShell
#
# This script will use Get-WmiObject command to check ping status 
# Takes a single parameter of a Health Service Computer Name FQDN
# Will be executed from Health Service primary management server.
# v 1.0
#=================================================================================

param($NetBIOSName,$PrincipalName,$ManagementServerName,$PingSamples,$intervalMilliseconds)
$scomapi = new-object -comObject "MOM.ScriptAPI"

If ($PrincipalName.Trim() -eq ""){
$PrincipalName="."
}


$stateCodes=@{}
$stateCodes.Add(0,"Success");
$stateCodes.Add(14,"Bad address");
$stateCodes.Add(11001,"Buffer Too Small");
$stateCodes.Add(11002,"Destination Net Unreachable");
$stateCodes.Add(11003,"Destination Host Unreachable");
$stateCodes.Add(11004,"Destination Protocol Unreachable");
$stateCodes.Add(11005,"Destination Port Unreachable");
$stateCodes.Add(11006,"No Resources");
$stateCodes.Add(11007,"Bad Option");
$stateCodes.Add(11008,"Hardware Error");
$stateCodes.Add(11009,"Packet Too Big");
$stateCodes.Add(11010,"Request Timed Out");
$stateCodes.Add(11011,"Bad Request");
$stateCodes.Add(11012,"Bad Route");
$stateCodes.Add(11013,"TimeToLive Expired Transit");
$stateCodes.Add(11014,"TimeToLive Expired Reassembly");
$stateCodes.Add(11015,"Parameter Problem");
$stateCodes.Add(11016,"Source Quench");
$stateCodes.Add(11017,"Option Too Big");
$stateCodes.Add(11018,"Bad Destination");
$stateCodes.Add(11032,"Negotiating IPSEC");
$stateCodes.Add(11050,"General Failure");

$Query = "SELECT PrimaryAddressResolutionStatus,StatusCode, ResponseTime FROM Win32_PingStatus WHERE Address = '$PrincipalName'"

for($i=1;$i -le $PingSamples;$i++)
{
    $oStatus = get-wmiobject -Query $Query -ComputerName $ManagementServerName 

    if ($oStatus.PrimaryAddressResolutionStatus -ne 0)
    {
		$Query = "SELECT PrimaryAddressResolutionStatus,StatusCode, ResponseTime FROM Win32_PingStatus WHERE Address = '$NetBIOSName'"

		$oStatus = get-wmiobject -Query $Query -ComputerName $ManagementServerName

		if ($oStatus.PrimaryAddressResolutionStatus -ne 0)
		{
			$StatusCode=14
			$ResponseTime=0
			break
		} 
		else{
			$StatusCode=$oStatus.StatusCode
			$ResponseTime=$oStatus.ResponseTime
			if($StatusCode -eq 0) {break}
			if($StatusCode -ne $null)
			{
				$StatusCode=11003
				$ResponseTime=0
			}
		}
    }
	else{
			$StatusCode=$oStatus.StatusCode
			$ResponseTime=$oStatus.ResponseTime
			if($StatusCode -eq 0) {break}
			if($StatusCode -ne $null)
			{
				$StatusCode=11003
				$ResponseTime=0
			}
		}
		Start-Sleep -m $intervalMilliseconds
}
$scompb = $scomapi.CreatePropertyBag()
$scompb.AddValue("Status", $stateCodes.Item([Int]$StatusCode))
$scompb.AddValue("StatusCode",$StatusCode)
$scompb.AddValue("ResponseTime",$ResponseTime)
$scompb.AddValue("AgentServerName",$PrincipalName)
$scompb.AddValue("ManagementServerName",$ManagementServerName)
$scompb
