$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$channelId = 'cd373cad-c1db-4b2a-943b-6ed6fb51d2fa'
$hubId = 'c9e6b370-41a7-499a-ae95-3496747cd165'
$expectedPackageKey = 'cp-vehicle-arrival'
$expectedVid = 'd570f0a4-6856-3dbb-a2d8-215b4bb5db2d'

if (-not (Get-Command smartthings -ErrorAction SilentlyContinue)) {
    throw 'SmartThings CLI is not installed or not in PATH.'
}
$configText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config.yml') -Raw
if ($configText -notmatch '(?m)^packageKey:\s*cp-vehicle-arrival\s*$') {
    throw 'Package key mismatch. Update cancelled.'
}
$profileText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'profiles/vehicle-arrival.yml') -Raw
if ($profileText -notmatch '(?m)^\s*vid:\s*d570f0a4-6856-3dbb-a2d8-215b4bb5db2d\s*$') {
    throw 'Existing presentation VID mismatch. Update cancelled.'
}

Write-Host 'C.P Vehicle Arrival v1.4.1 - existing driver update' -ForegroundColor Cyan
Write-Host 'Device: cp-vehicle-arrival'
Write-Host 'Existing driver ID: 0e199276-85a9-46d4-b2be-99fde065916c'

# On CLI 2.1.2, --channel and --hub install the packaged update.
# Do not add --install: it conflicts with --hub and causes a CLI exception.
& smartthings edge:drivers:package . "--channel=$channelId" "--hub=$hubId"
if ($LASTEXITCODE -ne 0) {
    throw 'Vehicle Arrival driver update failed.'
}

Write-Host 'UPDATE COMPLETE. Do not remove or re-add the Vehicle Arrival device.' -ForegroundColor Green
Write-Host 'Important: Existing NAS IP settings remain unchanged. If still 192.168.1.92, change to 192.168.1.53 in SmartThings device settings.'
