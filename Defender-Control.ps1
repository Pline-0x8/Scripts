param([string]$Action, [string]$Param1, [string]$Param2)

$markerFile = "C:\defender-action.txt"

function Disable-Defender {
    param([string]$SavePath)

    Write-Host "`nDisabling Windows Defender..." -ForegroundColor Yellow

    if (-not (Test-Path $markerFile)) {
        Write-Host "Setting up Safe Mode boot..." -ForegroundColor Cyan
        Set-Content -Path $markerFile -Value "disable"
        if ($SavePath) {
            Add-Content -Path $markerFile -Value $SavePath
        }
        cmd /c "bcdedit /set {current} safeboot minimal" 2>$null | Out-Null
        Write-Host "Restarting into Safe Mode..." -ForegroundColor Yellow
        Start-Sleep 2
        cmd /c "shutdown /r /t 5"
        exit
    }

    Write-Host "Safe Mode active - disabling Defender..." -ForegroundColor Green

    if ($SavePath) {
        Write-Host "Saving original values to $SavePath..." -ForegroundColor Cyan
        $backup = @{}
        $services = @("Sense", "WdBoot", "WdFilter", "WdNisDrv", "WdNisSvc", "WinDefend")
        foreach ($svc in $services) {
            $val = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -ErrorAction SilentlyContinue).Start
            $backup["${svc}_Start"] = $val
        }
        $backup | ConvertTo-Json | Out-File -FilePath $SavePath -Encoding UTF8
    }

    $services = @("Sense", "WdBoot", "WdFilter", "WdNisDrv", "WdNisSvc", "WinDefend")
    $policies = @("DisableAntiSpyware", "DisableAntiVirus")
    $rtpPolicies = @("DisableBehaviorMonitoring", "DisableIOAVProtection", "DisableOnAccessProtection", "DisableRealtimeMonitoring")

    Write-Host "Disabling Defender services..." -ForegroundColor Cyan
    foreach ($svc in $services) {
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\$svc" /v Start /t REG_DWORD /d 4 /f 2>$null | Out-Null
    }

    foreach ($policy in $policies) {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v $policy /t REG_DWORD /d 1 /f 2>$null | Out-Null
    }

    foreach ($policy in $rtpPolicies) {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v $policy /t REG_DWORD /d 1 /f 2>$null | Out-Null
    }

    Write-Host "Changes applied. Exiting Safe Mode and rebooting..." -ForegroundColor Green
    Remove-Item $markerFile -Force -ErrorAction SilentlyContinue
    cmd /c "bcdedit /deletevalue {current} safeboot" 2>$null | Out-Null
    Start-Sleep 2
    cmd /c "shutdown /r /t 5"
}

function Enable-Defender {
    param([string]$ConfigPath)

    Write-Host "`nRe-enabling Windows Defender..." -ForegroundColor Yellow

    if (-not (Test-Path $markerFile)) {
        Write-Host "Setting up Safe Mode boot..." -ForegroundColor Cyan
        Set-Content -Path $markerFile -Value "enable"
        if ($ConfigPath) {
            Add-Content -Path $markerFile -Value $ConfigPath
        }
        cmd /c "bcdedit /set {current} safeboot minimal" 2>$null | Out-Null
        Write-Host "Restarting into Safe Mode..." -ForegroundColor Yellow
        Start-Sleep 2
        cmd /c "shutdown /r /t 5"
        exit
    }

    Write-Host "Safe Mode active - enabling Defender..." -ForegroundColor Green

    $policies = @("DisableAntiSpyware", "DisableAntiVirus")
    $rtpPolicies = @("DisableBehaviorMonitoring", "DisableIOAVProtection", "DisableOnAccessProtection", "DisableRealtimeMonitoring")

    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        Write-Host "Restoring from $ConfigPath..." -ForegroundColor Cyan
        $backup = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        foreach ($property in $backup.PSObject.Properties) {
            if ($property.Name -like "*_Start") {
                $svc = $property.Name -replace "_Start", ""
                reg add "HKLM\SYSTEM\CurrentControlSet\Services\$svc" /v Start /t REG_DWORD /d $property.Value /f 2>$null | Out-Null
            }
        }
    } else {
        Write-Host "Restoring Windows 11 defaults..." -ForegroundColor Cyan
        $serviceDefaults = @{ "Sense"=3; "WdBoot"=0; "WdFilter"=0; "WdNisDrv"=4; "WdNisSvc"=4; "WinDefend"=2 }
        foreach ($svc in $serviceDefaults.Keys) {
            reg add "HKLM\SYSTEM\CurrentControlSet\Services\$svc" /v Start /t REG_DWORD /d $serviceDefaults[$svc] /f 2>$null | Out-Null
        }
    }

    Write-Host "Removing disable policies..." -ForegroundColor Cyan
    foreach ($policy in $policies) {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v $policy /f 2>$null | Out-Null
    }

    foreach ($policy in $rtpPolicies) {
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v $policy /f 2>$null | Out-Null
    }

    Write-Host "Changes applied. Exiting Safe Mode and rebooting..." -ForegroundColor Green
    Remove-Item $markerFile -Force -ErrorAction SilentlyContinue
    cmd /c "bcdedit /deletevalue {current} safeboot" 2>$null | Out-Null
    Start-Sleep 2
    cmd /c "shutdown /r /t 5"
}

if (Test-Path $markerFile) {
    $content = Get-Content $markerFile
    $lines = $content -split "`n"
    $action = $lines[0].Trim()
    $path = if ($lines.Count -gt 1) { $lines[1].Trim() } else { $null }

    if ($action -eq "disable") {
        Disable-Defender -SavePath $path
    } elseif ($action -eq "enable") {
        Enable-Defender -ConfigPath $path
    }
} else {
    Write-Host "`nDefender Control - Usage:" -ForegroundColor Cyan
    Write-Host "  Disable-Defender [--save <path>]" -ForegroundColor Gray
    Write-Host "  Enable-Defender [--config <path>]`n" -ForegroundColor Gray
}
