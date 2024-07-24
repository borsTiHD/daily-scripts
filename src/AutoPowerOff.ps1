<#
.SYNOPSIS
    Auto Power Off Script for Windows 11

.DESCRIPTION
    This PowerShell script prompts the user to set a timer in minutes or hours and shuts down the computer after the specified time.

.PARAMETER
    None

.INPUTS
    None. Prompts user for input.

.OUTPUTS
    None

.NOTES
    Author: borsTiHD
    Date: 2024-07-24
    Version: 1.0

.EXAMPLE
    To run the script:
    1. Open PowerShell with administrative privileges.
    2. Navigate to the directory containing the script using 'cd' command.
    3. Execute the script by typing '.\AutoPowerOff.ps1'.
#>

# Prompt user to select the time unit (minutes or hours)
$timeUnit = Read-Host "Enter the time unit (m for minutes, h for hours):"

# Validate time unit input
if ($timeUnit -ne 'm' -and $timeUnit -ne 'h') {
    Write-Host "Invalid input. Please run the script again and enter 'm' for minutes or 'h' for hours."
    exit
}

# Prompt user to enter the timer value
$timeValue = Read-Host "Enter the timer value (a positive integer):"

# Validate timer value input
if (-not ($timeValue -match '^\d+$') -or [int]$timeValue -le 0) {
    Write-Host "Invalid input. Please run the script again and enter a positive integer for the timer value."
    exit
}

# Convert time value to seconds
if ($timeUnit -eq 'h') {
    $timeInSeconds = [int]$timeValue * 3600
} else {
    $timeInSeconds = [int]$timeValue * 60
}

# Display countdown message
Write-Host "Your computer will shut down in $timeValue $timeUnit."

# Start a timer
Start-Sleep -Seconds $timeInSeconds

# Shut down the computer
Stop-Computer -Force
