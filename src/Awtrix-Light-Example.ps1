<#
.SYNOPSIS
This Script creates an App and sends a predefined text with an icon to the Awtrix-Light.

.DESCRIPTION
This script shows how to create a simple app and send a text with an icon to the Awtrix-Light.

.PARAMETER AwtrixBaseUrl
The base URL of the Awtrix-Light REST API.

.NOTES
Autor: borsTiHD
Version: 1.0

.LINK
Awtrix-Light Website: https://blueforcer.github.io/awtrix-light/#/api/

.EXAMPLE
.\Send-AwtrixData.ps1 -AwtrixBaseUrl "http://<IP-Adress-Awtrix-Light>/api/"
#>

param (
    [string]$AwtrixBaseUrl
)

# Function to send the command to Awtrix-Light
function SendAwtrixCommand {
    param (
        [string]$endpoint,
        [object]$data
    )

    # Add the API key to the header if needed
    # $headers = @{ "APIKey" = $ApiKey }
    $jsonPayload = $data | ConvertTo-Json

    # Debug
    # Write-Host "URL: $AwtrixBaseUrl$endpoint" # Print URL
    # Write-Host "JSON Payload: $jsonPayload" # Print the JSON payload

    try {
        # If a header is needed, add it to the Invoke-RestMethod command
        # e.g. -Headers $headers
        Invoke-RestMethod -Uri ($AwtrixBaseUrl + $endpoint) -Method Post -Body $jsonPayload -ErrorAction Stop
        Write-Host "Command successfully sent."
    }
    catch {
        Write-Host "Error while sending the command: $($_.Exception.Message)"

        # Print the error details
        Write-Host "Error details:"
        Write-Host $_.Exception.Response.StatusCode.value__ # Print the status code
        Write-Host $_.Exception.Response.StatusDescription # Print the status description
        Write-Host $_.Exception.Response.Content # Print the content
    }
}

# Use param to get the base URL of the Awtrix-Light REST API
# If no parameter is specified, use the default value
if (!$AwtrixBaseUrl) {
    $AwtrixBaseUrl = "http://192.168.2.50/api/"
}

# Configuration
$appName = "testapp" # App name
$appEndpoint = "custom" # App endpoint
$switchEndpoint = "switch" # Switch endpoint

# Create an app
$appData = @{
    "name" = $appName;
}
SendAwtrixCommand -endpoint $appEndpoint -data $appData

# Switch to the app
$switchData = @{
    "name" = $appName;
}
SendAwtrixCommand -endpoint $switchEndpoint -data $switchData

# Send a text to the Awtrix-Light
$textData = @{
    "name" = $appName;
    "text" = "This is an example text";
    # "icon" = "5588"; # Here you need to specify the icon ID. You can find the IDs here: https://blueforcer.github.io/awtrix-light/#/icons / https://developer.lametric.com/icons
    "duration" = 5; # Duration in seconds
    "wakeup" = $true; # Wake up the Awtrix-Light if it is in sleep mode
}
SendAwtrixCommand -endpoint $appEndpoint -data $textData