[CmdletBinding()]
param(
    [string]$DeviceId,
    [switch]$ConfigOnly
)

$ErrorActionPreference = 'Stop'

$interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
    Where-Object { $_.OperationalStatus -eq 'Up' }
$hotspotIP = $null
$wifiIPs = @()

foreach ($adapter in $interfaces) {
    $properties = $adapter.GetIPProperties()
    $addresses = $properties.UnicastAddresses | Where-Object {
        $_.Address.AddressFamily -eq 'InterNetwork' -and
        $_.Address.IPAddressToString -notlike '169.254.*'
    } | ForEach-Object { $_.Address.IPAddressToString }

    if ($addresses -contains '192.168.137.1') {
        $hotspotIP = '192.168.137.1'
        break
    }

    if ($adapter.NetworkInterfaceType -eq 'Wireless80211' -and
        $properties.GatewayAddresses.Address.AddressFamily -contains 'InterNetwork') {
        $wifiIPs += $addresses
    }
}

if ($hotspotIP) {
    $laptopIP = $hotspotIP
} elseif ($wifiIPs.Count -eq 1) {
    $laptopIP = $wifiIPs[0]
} else {
    throw 'Could not select a single Wi-Fi IPv4 address. Turn on Windows Mobile Hotspot or connect the laptop and phone to the same Wi-Fi, then retry.'
}

$apiUrl = "http://${laptopIP}:5000"
$configDirectory = Join-Path $PSScriptRoot '.dart_tool'
$configPath = Join-Path $configDirectory 'phone-api.json'
New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
@{ API_URL = $apiUrl } | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding ASCII
Write-Host "Phone API URL: $apiUrl"

if ($ConfigOnly) {
    return
}

try {
    Invoke-RestMethod -Uri "$apiUrl/" -TimeoutSec 5 | Out-Null
} catch {
    throw "KapConnect's backend did not respond at $apiUrl. Start it with npm run dev from the backend folder and retry. $($_.Exception.Message)"
}

$flutterArgs = @('run', "--dart-define-from-file=$configPath")
if ($DeviceId) {
    $flutterArgs += @('-d', $DeviceId)
}

Push-Location -LiteralPath $PSScriptRoot
try {
    & flutter @flutterArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
