<#
.SYNOPSIS
    Pings a Telnet port and displays the response time.

.DESCRIPTION
    This script pings a Telnet port on a specified host and displays the response time in milliseconds.

.PARAMETER Hostname
    Specifies the hostname or IP address of the target host.

.PARAMETER Port
    Specifies the port number of the Telnet port to ping.

.EXAMPLE
    .\PingTelnetPort.ps1 -Hostname example.com -Port 23
    Pings the Telnet port 23 on the host "example.com" and displays the response time.
.LINK
    https://github.com/borsTiHD/daily-scripts
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$Hostname,
    
    [Parameter(Mandatory=$true)]
    [int]$Port
)

$measure = Measure-Command {
    $result = Test-NetConnection -ComputerName $Hostname -Port $Port
}

Write-Host "Response Time: $($measure.TotalMilliseconds) Milliseconds"
