<#
.SYNOPSIS
    This script kills all Spotify processes.
.DESCRIPTION
    If you have multiple Spotify processes running, this script will kill all of them.
.PARAMETER ParameterName
    ...
.INPUTS
    ...
.OUTPUTS
    ...
.EXAMPLE
    PS C:\> .\Kill-Spotify.ps1
    This example shows how to use the script.
.NOTES
    For better usage, you can create a shortcut, or a batch file (.bat) to the script and run it like this:
    powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Path\to\Kill-Spotify.ps1"
.LINK
    https://github.com/borsTiHD/daily-scripts
#>

# Get all running Spotify processes
$processes = Get-Process | Where-Object { $_.ProcessName -like "Spotify*" }

# Kill all Spotify processes
foreach ($process in $processes) {
    $process.Kill()
}
