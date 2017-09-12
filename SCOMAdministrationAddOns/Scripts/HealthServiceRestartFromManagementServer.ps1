#=================================================================================
#  Script to restart HealthService agent via PowerShell
#
# This script will use Get-WmiObject command to check ping status and stop, start HealthService service
# Takes a single parameter of a Health Service Computer Name FQDN
# Will be executed from Health Service primary management server.
#
# v 1.0
#=================================================================================
Param($HealthServiceName)


$pingstate = Get-WmiObject -Query "select * from win32_pingstatus where address='$($HealthServiceName)'"

if($pingstate.StatusCode -eq $null -or $pingstate.StatusCode -ne 0)
{
	write-host "No ping response from agent."
}
else
{
    $Error.Clear()
    try{

	  $service = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE name = 'HealthService'" -computerName $HealthServiceName  -ErrorAction Stop
    }
    catch
    {
		$err = $Error[0]
		write-host $err.Exception.Message
	    break
    }

	$rt = $service.stopService()
	$i=0
	while ($service.State -eq "Running" -and $i -le 6)
	{
		Start-Sleep -m 10000
		$i=$i+1
		$service = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE name = 'HealthService'" -computerName $HealthServiceName
	}

	if($service.State -ne "Stopped")
	{
	 write-host "Failed to stop: Terminating..."
	 $process = Get-WmiObject -Query "SELECT * FROM Win32_process WHERE ProcessId = '$($service.ProcessId)'"
	$rt = $process.Terminate()
	 $service = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE name = 'HealthService'" -computerName $HealthServiceName
	}
	$rt = $service.StartService()
	$i=0
	while ($service.State -ne "Running" -and $i -le 6)
	{
		Start-Sleep -m 10000
		$i=$i+1
		$service = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE name = 'HealthService'" -computerName $HealthServiceName
	}
	if($service.State -eq "Running" -and $i -eq 0)
	{
		write-host "Failed to stop, last state:$($service.State)"
	}
	if($service.State -ne "Running" )
	{
		write-host "Failed to start, last state:$($service.State)"
	}
	if($service.State -eq "Running" -and $i -le 6)
	{
		write-host "Restarted Successfully"
	}
}