﻿#=================================================================================
#  Script to collect unhealthy HealthService agents via PowerShell
#
# This script will query OperationsManager db.
# Takes a single parameter of inMM it mean if too return unhealthy agent include in maintenance mode agent or not (0 not , 1 include)
# For each health service ping status will be executed check ping task that executed from agent primary management server
# v 1.0
#=================================================================================
param()

$SCRIPT_EVENT_ID = 5220 
$SCRIPT_NAME = "HealthServicesNoPerformanceData.ps1"
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
	* INTO #tmp
FROM dbo.PerformanceDataAllView P
WHERE P.TimeSampled > DATEADD(hour, -12, GETUTCDATE())

SELECT
	C.*
   ,ME.Path
   ,me.IsDeleted INTO #tmp1
FROM dbo.ManagedEntityGenericView ME
INNER JOIN dbo.ManagedTypeView MT
	ON ME.MonitoringClassId = MT.Id
		AND MT.Name = 'Microsoft.SystemCenter.HealthService'
INNER JOIN MaintenanceMode MM
	ON MM.BaseManagedEntityId = ME.Id
		AND MM.IsInMaintenanceMode = 0
LEFT JOIN dbo.PerformanceCounterView C
	ON ME.Id = C.ManagedEntityId
WHERE ME.IsDeleted = 0


SELECT
	*
FROM (SELECT
		c.Path
	   ,c.ManagedEntityId
	   ,CAST(MAX(p.TimeSampled) AS NVARCHAR(50)) AS 'LastSample'
	FROM #tmp1 C
	JOIN State s
		ON s.BaseManagedEntityId = c.ManagedEntityId
	LEFT JOIN #tmp P
		ON C.PerformanceSourceInternalId = P.PerformanceSourceInternalId
	GROUP BY c.Path
			,ManagedEntityId) a
WHERE a.LastSample IS NULL
AND Path NOT IN (SELECT
		hs.DisplayName
	FROM State s
	LEFT JOIN MaintenanceMode mm
		ON s.BaseManagedEntityId = mm.BaseManagedEntityId
	JOIN (SELECT
			BaseManagedEntityId
		   ,Name
		FROM BaseManagedEntity
		WHERE BaseManagedTypeId = 'A4899740-EF2F-1541-6C1D-51D34B739491') bme
		ON bme.BaseManagedEntityId = s.BaseManagedEntityId
	JOIN MTV_HealthService hs
		ON hs.BaseManagedEntityId = bme.Name
	WHERE MonitorId = 'B59F78CE-C42A-8995-F099-E705DBB34FD4'
	AND HealthState <> 1
	AND (mm.IsInMaintenanceMode = 0
	OR mm.BaseManagedEntityId IS NULL)
	AND hs.IsAgent = 1)


DROP TABLE #tmp
DROP TABLE #tmp1
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
	$Task= Get-SCOMTask -Name Microsoft.SystemCenter.ResetHealthServiceStore
	Foreach($row in $DS.Tables[0].Rows){

		$MSInstance = Get-SCOMClassInstance -Id $row["ManagedEntityId"]
		$task_run=Start-SCOMTask -Task $TaskPi -Instance $MSInstance 
	}
}	
catch
{
        $ErrorMessage = $_.Exception.Message
        msg = "Error occurred!{0}Computer:{1}{0}Reason: {2}" -f [Environment]::NewLine, $env:COMPUTERNAME, $ErrorMessage
		$api.LogScriptEvent($SCRIPT_NAME, $SCRIPT_EVENT_ID, $ERROR_EVENT_TYPE, $msg)
		exit
}
