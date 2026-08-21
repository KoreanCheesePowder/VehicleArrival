$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

Write-Host "==============================================="
Write-Host " C.P Vehicle Arrival Edge Driver v1.3.6"
Write-Host "==============================================="
Write-Host ""

& smartthings --version
if ($LASTEXITCODE -ne 0) { throw "SmartThings CLI not available." }

function Ensure-Capability {
    param(
        [string]$CapId,
        [string]$DefFile,
        [string]$PresFile,
        [string]$TransFile
    )

    Write-Host "Setting capability: $CapId"

    # Create first. If it already exists or access is restricted, continue.
    $createOut = & smartthings capabilities:create -i $DefFile -j 2>&1
    $createCode = $LASTEXITCODE
    $createText = ($createOut | Out-String)

    if ($createCode -ne 0) {
        if ($createText -match "already exists|Conflict|409|403|Forbidden") {
            Write-Host "Capability already exists or direct create is restricted; continuing."
        } else {
            Write-Host $createText
            throw "Capability setup failed: $CapId"
        }
    }

    # Presentation: create first, update fallback.
    $presOut = & smartthings capabilities:presentation:create $CapId -i $PresFile -j 2>&1
    $presCode = $LASTEXITCODE
    if ($presCode -ne 0) {
        $updOut = & smartthings capabilities:presentation:update $CapId -i $PresFile -j 2>&1
        $updCode = $LASTEXITCODE
        if ($updCode -ne 0) {
            $allPresText = (($presOut | Out-String) + ($updOut | Out-String))
            if ($allPresText -match "403|Forbidden") {
                Write-Host "Presentation API returned 403 for $CapId; continuing without abort."
            } else {
                Write-Host $allPresText
                throw "Presentation setup failed: $CapId"
            }
        }
    }

    # Translation is cosmetic only. Do not abort installation on 403/Forbidden.
    $trOut = & smartthings capabilities:translations:upsert $CapId -i $TransFile -j 2>&1
    $trCode = $LASTEXITCODE
    if ($trCode -ne 0) {
        $trText = ($trOut | Out-String)
        if ($trText -match "403|Forbidden") {
            Write-Host "Translation skipped for $CapId (403). Presentation labels remain Korean."
        } else {
            Write-Host $trText
            Write-Host "Translation skipped for $CapId."
        }
    }
}

Write-Host "[1/4] Setting vehicle capabilities..."

Ensure-Capability "buildbook37604.vehicleArrivalEntry" `
    ".\capabilities\vehicle-arrival-entry.json" `
    ".\presentations\vehicle-arrival-entry.json" `
    ".\translations\vehicle-arrival-entry-ko.json"

Ensure-Capability "buildbook37604.vehicleArrivalExit" `
    ".\capabilities\vehicle-arrival-exit.json" `
    ".\presentations\vehicle-arrival-exit.json" `
    ".\translations\vehicle-arrival-exit-ko.json"

Ensure-Capability "buildbook37604.vehicleArrivalSummary" `
    ".\capabilities\vehicle-arrival-summary.json" `
    ".\presentations\vehicle-arrival-summary.json" `
    ".\translations\vehicle-arrival-summary-ko.json"

Write-Host "[2/4] Creating Device Presentation..."
$generated = ".\generated-device-config.json"
if (Test-Path $generated) { Remove-Item $generated -Force }

& smartthings presentation:device-config:create -i ".\device-config.json" -o $generated -j
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $generated)) {
    throw "Device presentation creation failed."
}

$generatedText = [IO.File]::ReadAllText((Resolve-Path $generated),(New-Object Text.UTF8Encoding($false)))
$dp = $generatedText | ConvertFrom-Json
$vid = if ($dp.presentationId) {[string]$dp.presentationId} elseif ($dp.vid) {[string]$dp.vid} else {""}
$mnmn = if ($dp.manufacturerName) {[string]$dp.manufacturerName} elseif ($dp.mnmn) {[string]$dp.mnmn} else {""}

if ([string]::IsNullOrWhiteSpace($vid) -or [string]::IsNullOrWhiteSpace($mnmn)) {
    throw "VID/MNMN read failed."
}

Write-Host "[3/4] Applying Device Presentation VID..."
$profilePath = ".\profiles\vehicle-arrival.yml"
$profile = [IO.File]::ReadAllText((Resolve-Path $profilePath),(New-Object Text.UTF8Encoding($false)))
$profile = [regex]::Replace($profile,'(?m)^\s*mnmn:\s*.*$',"  mnmn: $mnmn")
$profile = [regex]::Replace($profile,'(?m)^\s*vid:\s*.*$',"  vid: $vid")
[IO.File]::WriteAllText((Resolve-Path $profilePath),$profile,(New-Object Text.UTF8Encoding($false)))

Write-Host "[4/4] Packaging/installing v1.3.6..."
& smartthings edge:drivers:package . --install
if ($LASTEXITCODE -ne 0) {
    throw "Driver package/install failed."
}

Write-Host ""
Write-Host "Installation completed."
Write-Host "Detail View:"
Write-Host " - 최근 입차 차량 / 차량번호 / 입차시간"
Write-Host " - 최근 출차 차량 / 차량번호 / 출차시간"
Write-Host " - 제작자 / 버전"
Write-Host "Routine:"
Write-Host " - 입차 감지: 꺼짐 -> 켜짐 -> 약 30초 후 꺼짐"
Write-Host " - 출차 감지: 꺼짐 -> 켜짐 -> 약 30초 후 꺼짐"
Write-Host " - 동일 방향 연속 감지도 매번 OFF -> ON 이벤트 재발행"


Write-Host ""
Write-Host "v1.3.6 profile migration enabled."
Write-Host "Existing Vehicle Arrival device will force-refresh its profile/VID on driver init."
Write-Host "Wait about 10-30 seconds, then check devices:status."


Write-Host ""
Write-Host "Existing-device refresh enabled."
Write-Host "driverVersion should become v1.3.6 within about 15-30 seconds."
