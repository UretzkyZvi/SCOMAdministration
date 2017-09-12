#=================================================================================
#  Script to analyze health service status and based on status repair the agent via PowerShell
#
# This script will query OperationsManager db.
# Takes a single parameter of time in minutes to get last ping sample, should be around 5 minutes by default.
# since by default ping check sample take every 5 minutes.
# Will be executed all management servers pool.
# For each health service ping status will be executed task
# if ping status equal 0 then restart agent
# if ping status equal 14 (Bad Address) delete agent
# v 1.0
#=================================================================================

param( [int]$LastSamplesIntervalInMinutes = 5)

$SCRIPT_EVENT_ID = 5211
$SCRIPT_NAME = "HealthServicesAnalyzeAndRepair.ps1"
Set-StrictMode -Version 1
#Event Severity values
$INFORMATION_EVENT_TYPE = 0
$ERROR_EVENT_TYPE = 1 


$api = New-Object -comObject "MOM.ScriptAPI"
#helper function to get registry value 
function GetValueProperty($value)
{
	try{
		 $key = "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup\"
		(Get-ItemProperty $key $value).$value
	}
	catch{
		msg = "Error occurred!{0}Computer:{1}{0}Reason: {2}" -f [Environment]::NewLine, $env:COMPUTERNAME, $_.Exception.Message
		$api.LogScriptEvent($SCRIPT_NAME, $SCRIPT_EVENT_ID, $ERROR_EVENT_TYPE, $msg)
	}	
}



Function Import-GlobalTaskCmdlets()
{

	$SCOMPowerShellKey = "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\Powershell\V2"
	$SCOMModulePath = (Get-ItemProperty $SCOMPowerShellKey).InstallDirectory

    if ($true -eq [string]::IsNullOrEmpty($SCOMModulePath))
    {
        $ErrorMessage = "Path to SCOM cmdlets not found in registry."
		msg = "Error occurred!{0}Computer:{1}{0}Reason: {2}" -f [Environment]::NewLine, $env:COMPUTERNAME, $ErrorMessage
		$api.LogScriptEvent($SCRIPT_NAME, $SCRIPT_EVENT_ID, $ERROR_EVENT_TYPE, $msg)
		exit 
    }   

    $SCOMModulePath = Join-Path $SCOMModulePath "OperationsManager"   

	try
	{
							   
			Import-module $SCOMModulePath
							   
	}
	catch [System.IO.FileNotFoundException]
	{
		$ErrorMessage = "SCOM cmdlets do not exist."
		msg = "Error occurred!{0}Computer:{1}{0}Reason: {2}" -f [Environment]::NewLine, $env:COMPUTERNAME, $ErrorMessage
		$api.LogScriptEvent($SCRIPT_NAME, $SCRIPT_EVENT_ID, $ERROR_EVENT_TYPE, $msg)
		exit 
	}
	catch
	{
            $ErrorMessage = $_.Exception.Message
           	msg = "Error occurred!{0}Computer:{1}{0}Reason: {2}" -f [Environment]::NewLine, $env:COMPUTERNAME, $ErrorMessage
			$api.LogScriptEvent($SCRIPT_NAME, $SCRIPT_EVENT_ID, $ERROR_EVENT_TYPE, $msg)
			exit
	}
					   

}

Import-GlobalTaskCmdlets


$SQLServer = GetValueProperty("DatabaseServerName")
$SQLDBName = GetValueProperty("DatabaseName")

$SqlQuery = @"
SELECT
	tb.StatusCode
   ,tb.AgentServerName
   ,tb.ManagementServerName
   ,d.HealthServiceFQDN
   ,d.HealthServiceID
   ,d.ManagementServer
   ,d.ManagementServerID
FROM (SELECT
		ROW_NUMBER() OVER (PARTITION BY AgentServerName ORDER BY AgentServerName) RN
	   ,Status
	   ,StatusCode
	   ,ResponseTime
	   ,AgentServerName
	   ,ManagementServerName
	   ,TimeGenerated
	   ,DATEADD(MINUTE, ((DATEPART(MINUTE, TimeGenerated) / 5) * 5), DATEADD(HOUR, DATEDIFF(HOUR, 0, TimeGenerated), 0)) AS TimeGeneratedFixed
	FROM EventAllView
	OUTER APPLY (SELECT
			CAST(EventParameters AS XML) AS EventParametersXML) x
	OUTER APPLY (SELECT
			x.value('Param[1]', 'VARCHAR(80)') AS Status
		   ,x.value('Param[2]', 'VARCHAR(80)') AS StatusCode
		   ,x.value('Param[3]', 'VARCHAR(80)') AS ResponseTime
		   ,x.value('Param[4]', 'VARCHAR(80)') AS AgentServerName
		   ,x.value('Param[5]', 'VARCHAR(80)') AS ManagementServerName
		FROM x.EventParametersXML.nodes('/') AS NodeValues (x)) y
	WHERE PublisherName = 'ServerConnectivityCheck'
	AND DATEADD(MINUTE, ((DATEPART(MINUTE, TimeGenerated) / 5) * 5), DATEADD(HOUR, DATEDIFF(HOUR, 0, TimeGenerated), 0)) > 
	
	DATEADD(MINUTE, ((DATEPART(MINUTE, TimeGenerated) / 5) * 5) - $($LastSamplesIntervalInMinutes), DATEADD(HOUR, DATEDIFF(HOUR, 0, TimeGenerated), 0))
) AS tb
JOIN (SELECT
		SourceBME.BaseManagedEntityId HealthServiceID
	   ,TargetBME.BaseManagedEntityId ManagementServerID
	   ,SourceBME.DisplayName AS HealthServiceFQDN
	   ,LEFT(SourceBME.DisplayName, CHARINDEX('.', SourceBME.DisplayName) - 1) AS HealthServiceMachineName
	   ,TargetBME.DisplayName AS ManagementServer
	FROM Relationship R WITH (NOLOCK)
	JOIN (SELECT
			hs.BaseManagedEntityId
		   ,hs.DisplayName
		FROM State s
		LEFT JOIN MaintenanceMode mm
			ON s.BaseManagedEntityId = mm.BaseManagedEntityId
		JOIN (SELECT BaseManagedEntityId ,Name FROM BaseManagedEntity WHERE BaseManagedTypeId = 'A4899740-EF2F-1541-6C1D-51D34B739491') bme
			ON bme.BaseManagedEntityId = s.BaseManagedEntityId
		JOIN MTV_HealthService hs
			ON hs.BaseManagedEntityId = bme.Name
		WHERE MonitorId = 'B59F78CE-C42A-8995-F099-E705DBB34FD4'
		AND HealthState <> 1
		AND (mm.IsInMaintenanceMode = 0
		OR mm.BaseManagedEntityId IS NULL) AND hs.IsAgent=1 ) SourceBME
		ON R.SourceEntityID = SourceBME.BaseManagedEntityID
	JOIN BaseManagedEntity TargetBME
		ON R.TargetEntityID = TargetBME.BaseManagedEntityID
	WHERE R.RelationshipTypeId = dbo.fn_ManagedTypeId_MicrosoftSystemCenterHealthServiceCommunication()) d
	ON d.HealthServiceFQDN = tb.AgentServerName 
WHERE tb.RN = 1
"@

$SQLConn = New-Object System.Data.SqlClient.SqlConnection
$SQLConn.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $SqlQuery
$SqlCmd.Connection = $SQLConn
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd
$DS = New-Object System.Data.DataSet
$SqlAdapter.Fill($DS)
$SQLConn.Close()

try
{
	Foreach($row in $DS.Tables[0].Rows){
		if($row["StatusCode"] -eq 0)
		{
			# the machine answer to ping, it mean restart to agent
			$TaskRestart = Get-SCOMTask -Name SCOMAdministrationAddOns.RestartHealthServiceTask

			$MSInstance = Get-SCOMClassInstance -Id $row["ManagementServerID"]

			$override=@{HealthServiceAgentName=$row["HealthServiceFQDN"]}

			$task_run=Start-SCOMTask -Task $TaskRestart -Instance $MSInstance -Override $override
		}
		if ($row["StatusCode"] -eq 14){
			# the machine have a bad address, it mean the server account in AD was deleted
			$TaskDeleteAgent = Get-SCOMTask -Name SCOMAdministrationAddOns.DeleteHealthServiceTask

			$objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
			$servername ="{0}.{1}" -f $objIPProperties.HostName, $objIPProperties.DomainName
			$class = Get-SCOMClass -Name Microsoft.SystemCenter.ManagementServer
			$MSInstance =  Get-SCOMClassInstance -Class $class | ?{$_.displayname -eq $servername }
		    
			$override=@{AgentName=$row["HealthServiceFQDN"]}

			$task_run=Start-SCOMTask -Task $TaskDeleteAgent -Instance $MSInstance -Override $override
		}
	}
}	
catch
{
        $ErrorMessage = $_.Exception.Message
        msg = "Error occurred!{0}Computer:{1}{0}Reason: {2}" -f [Environment]::NewLine, $env:COMPUTERNAME, $ErrorMessage
		$api.LogScriptEvent($SCRIPT_NAME, $SCRIPT_EVENT_ID, $ERROR_EVENT_TYPE, $msg)
		exit
}
