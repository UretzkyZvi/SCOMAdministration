#=================================================================================
#  Script to delete agents via PowerShell
#
# This script will delete agents using the SDK binaries and .NET based SDK commands
# Takes a single parameter of a computer FQDN
# Should be run on a management server
#
# v 1.0
#=================================================================================
param($AgentName)

# For testing manually in PowerShell:
# $AgentName = 'WS2012.opsmgr.net'

#=================================================================================
# Constants section - modify stuff here:

# Assign script name variable for use in event logging
$ScriptName = "DeleteHealthService.ps1"
#=================================================================================

# Gather script start time
$StartTime = Get-Date

# Gather who the script is running as
$whoami = whoami

#Load the MOMScript API and discovery property bag
$momapi = New-Object -comObject "Mom.ScriptAPI"

#Log script event that we are starting task
$momapi.LogScriptEvent($ScriptName,1016,0, "Starting script.  AgentName is ($AgentName).  Running as ($whoami)")

# Begin Main Script
#=================================================================================
# Get SCOM directory for binaries
$SCOMRegKey = "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup"
$SCOMPath = (Get-ItemProperty $SCOMRegKey).InstallDirectory
$SCOMPath = $SCOMPath.TrimEnd("\")
$SCOMSDKPath = "$SCOMPath\SDK Binaries"

#Load SDK binaries
$dummy = [System.Reflection.Assembly]::LoadFrom("$SCOMSDKPath\Microsoft.EnterpriseManagement.Core.dll")
$dummy = [System.Reflection.Assembly]::LoadFrom("$SCOMSDKPath\Microsoft.EnterpriseManagement.OperationsManager.dll")
$dummy = [System.Reflection.Assembly]::LoadFrom("$SCOMSDKPath\Microsoft.EnterpriseManagement.Runtime.dll")

# Connect to management group
$MG = [Microsoft.EnterpriseManagement.ManagementGroup]::Connect($Env:COMPUTERNAME)
$Admin = $MG.GetAdministration()

# Define generic collection list which is required parameter for the SDK delete command
$AgentManagedComputerType = [Microsoft.EnterpriseManagement.Administration.AgentManagedComputer];
$GenericListType = [System.Collections.Generic.List``1]
$GenericList = $GenericListType.MakeGenericType($AgentManagedComputerType)
$AMCList = new-object $GenericList.FullName

# Get the AgentManagedComputer from the name in the most efficient way possible
# This SDK method does not require the performance hit of Get-SCOMAgent or looping through each agent to find the right one
Write-Host "Getting agent details for agent: ($AgentName)"
$query = "Name= '$AgentName'"
$AgentCriteria = New-Object Microsoft.EnterpriseManagement.Administration.AgentManagedComputerCriteria($query)
$Agent = ($Admin.GetAgentManagedComputers($AgentCriteria))[0]
$AgentCount = $Agent.Count

# Log messages to console
IF ($AgentCount -eq 1)
{
  $AgentDisplayName = $Agent.DisplayName
  Write-Host "Found agent: ($AgentDisplayName)"
}
ELSE
{
  Write-Host "ERROR: An Agent with name ($AgentName) not found!"
  Write-Host "Terminating"
  $momapi.LogScriptEvent($ScriptName,1016,2,"`n ERROR: Agent not found with agent name ($AgentName).  Terminating script")
  EXIT
}

# Add our agent to the collection
$AMCList.Add($Agent)

# Delete the agent in the collection
Write-Host "Deleting Agent"
$Admin.DeleteAgentManagedComputers($AMCList)
Write-Host "Agent Deleted"
#=================================================================================
# End Main Script


# Log an event for script ending and total execution time.
$EndTime = Get-Date
$ScriptTime = ($EndTime - $StartTime).TotalSeconds
$momapi.LogScriptEvent($ScriptName,1016,0,"`n Script has completed. `n Deleted ($AgentName).  Runtime is ($ScriptTime)")