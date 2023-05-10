<#
.SYNOPSIS
    This script starts the power saving mode.
.DESCRIPTION
    Use this script to start the power saving mode.
.PARAMETER ParameterName
    ...
.INPUTS
    ...
.OUTPUTS
    ...
.EXAMPLE
    PS C:\> .\Powersaving-Mode.ps1
    This example shows how to use the script.
.NOTES
    For better usage, you can create a shortcut, or a batch file (.bat) to the script and put it in the autostart folder:
    %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe "C:\Powersaving-Mode.ps1"
.LINK
    https://github.com/borsTiHD/daily-scripts
#>

# Activates the power saving mode (GUID: a1841308-3541-4fab-bc81-f71556f20b4a) in Windows
powercfg /s a1841308-3541-4fab-bc81-f71556f20b4a

# Wait 5 seconds
# Start-Sleep -Seconds 5

# Exit the script
Exit
