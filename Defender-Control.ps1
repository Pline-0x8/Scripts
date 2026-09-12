function Disable-Defender {
    <#
    .SYNOPSIS
    Permanently disables Windows Defender on Windows 11
    .DESCRIPTION
    Disables Windows Defender via Group Policy, Registry modifications, and service disabling
    #>

    Write-Host "`n[*] Disabling Windows Defender..." -ForegroundColor Yellow

    # Check if running as Administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "[!] This script must be run as Administrator!" -ForegroundColor Red
        return $false
    }

    try {
        # Step 1: Registry modifications for DisableAntiSpyware
        Write-Host "[+] Setting registry DisableAntiSpyware..." -ForegroundColor Cyan
        $regPath1 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        if (-not (Test-Path $regPath1)) {
            New-Item -Path $regPath1 -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath1 -Name "DisableAntiSpyware" -Value 1 -Force

        # Step 2: Registry modifications for DisableAntiVirus
        Write-Host "[+] Setting registry DisableAntiVirus..." -ForegroundColor Cyan
        Set-ItemProperty -Path $regPath1 -Name "DisableAntiVirus" -Value 1 -Force

        # Step 3: Disable Real-Time Protection settings
        Write-Host "[+] Disabling Real-Time Protection components..." -ForegroundColor Cyan
        $regPath2 = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
        if (-not (Test-Path $regPath2)) {
            New-Item -Path $regPath2 -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath2 -Name "DisableBehaviorMonitoring" -Value 1 -Force
        Set-ItemProperty -Path $regPath2 -Name "DisableIOAVProtection" -Value 1 -Force
        Set-ItemProperty -Path $regPath2 -Name "DisableOnAccessProtection" -Value 1 -Force

        # Step 4: Disable via MpPreference (if Defender is still active)
        Write-Host "[+] Disabling via Set-MpPreference..." -ForegroundColor Cyan
        try {
            Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
        } catch {
            Write-Host "[!] Set-MpPreference failed (may already be disabled)" -ForegroundColor Gray
        }

        # Step 5: Disable Windows Update service to prevent Defender re-enabling
        Write-Host "[+] Disabling Windows Update service..." -ForegroundColor Cyan
        Set-Service -Name "WuauServ" -StartupType Disabled -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "WuauServ" -Force -ErrorAction SilentlyContinue

        Write-Host "[+] Disabling Windows Update Medic service..." -ForegroundColor Cyan
        Set-Service -Name "WaaSMedicSvc" -StartupType Disabled -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "WaaSMedicSvc" -Force -ErrorAction SilentlyContinue

        # Verification
        Write-Host "`n[*] Verifying Defender status..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2

        try {
            $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue

            if ($mpStatus) {
                $defenderEnabled = $mpStatus.AntivirusEnabled
                $rtpEnabled = $mpStatus.RealTimeProtectionEnabled

                if (-not $defenderEnabled -or -not $rtpEnabled) {
                    Write-Host "`n[✓] SUCCESS: Windows Defender has been disabled!" -ForegroundColor Green
                    Write-Host "[✓] Antivirus Enabled: $defenderEnabled" -ForegroundColor Green
                    Write-Host "[✓] Real-Time Protection Enabled: $rtpEnabled" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "`n[!] WARNING: Defender still appears to be enabled" -ForegroundColor Yellow
                    Write-Host "[!] Antivirus Enabled: $defenderEnabled" -ForegroundColor Yellow
                    Write-Host "[!] Real-Time Protection Enabled: $rtpEnabled" -ForegroundColor Yellow
                    return $false
                }
            }
        } catch {
            Write-Host "[!] Could not verify via Get-MpComputerStatus" -ForegroundColor Yellow
            Write-Host "[*] Registry changes have been applied. Restart may be required for full verification." -ForegroundColor Yellow
            return $true
        }
    }
    catch {
        Write-Host "`n[!] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Enable-Defender {
    <#
    .SYNOPSIS
    Re-enables Windows Defender on Windows 11
    .DESCRIPTION
    Reverts all changes made by Disable-Defender
    #>

    Write-Host "`n[*] Enabling Windows Defender..." -ForegroundColor Yellow

    # Check if running as Administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "[!] This script must be run as Administrator!" -ForegroundColor Red
        return $false
    }

    try {
        # Step 1: Remove registry disable settings
        Write-Host "[+] Removing DisableAntiSpyware registry setting..." -ForegroundColor Cyan
        $regPath1 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        if (Test-Path $regPath1) {
            Remove-ItemProperty -Path $regPath1 -Name "DisableAntiSpyware" -Force -ErrorAction SilentlyContinue
        }

        Write-Host "[+] Removing DisableAntiVirus registry setting..." -ForegroundColor Cyan
        if (Test-Path $regPath1) {
            Remove-ItemProperty -Path $regPath1 -Name "DisableAntiVirus" -Force -ErrorAction SilentlyContinue
        }

        # Step 2: Reset Real-Time Protection settings
        Write-Host "[+] Resetting Real-Time Protection settings..." -ForegroundColor Cyan
        $regPath2 = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
        if (Test-Path $regPath2) {
            Remove-ItemProperty -Path $regPath2 -Name "DisableBehaviorMonitoring" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath2 -Name "DisableIOAVProtection" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath2 -Name "DisableOnAccessProtection" -Force -ErrorAction SilentlyContinue
        }

        # Step 3: Re-enable via MpPreference
        Write-Host "[+] Re-enabling via Set-MpPreference..." -ForegroundColor Cyan
        try {
            Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
        } catch {
            Write-Host "[!] Set-MpPreference failed (may need restart)" -ForegroundColor Gray
        }

        # Step 4: Re-enable Windows Update service
        Write-Host "[+] Re-enabling Windows Update service..." -ForegroundColor Cyan
        Set-Service -Name "WuauServ" -StartupType Automatic -Force -ErrorAction SilentlyContinue
        Start-Service -Name "WuauServ" -ErrorAction SilentlyContinue

        Write-Host "[+] Re-enabling Windows Update Medic service..." -ForegroundColor Cyan
        Set-Service -Name "WaaSMedicSvc" -StartupType Automatic -Force -ErrorAction SilentlyContinue
        Start-Service -Name "WaaSMedicSvc" -ErrorAction SilentlyContinue

        # Verification
        Write-Host "`n[*] Verifying Defender status..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2

        try {
            $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue

            if ($mpStatus) {
                $defenderEnabled = $mpStatus.AntivirusEnabled
                $rtpEnabled = $mpStatus.RealTimeProtectionEnabled

                if ($defenderEnabled -or $rtpEnabled) {
                    Write-Host "`n[✓] SUCCESS: Windows Defender has been enabled!" -ForegroundColor Green
                    Write-Host "[✓] Antivirus Enabled: $defenderEnabled" -ForegroundColor Green
                    Write-Host "[✓] Real-Time Protection Enabled: $rtpEnabled" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "`n[!] WARNING: Defender may still be disabled" -ForegroundColor Yellow
                    Write-Host "[!] Antivirus Enabled: $defenderEnabled" -ForegroundColor Yellow
                    Write-Host "[!] Real-Time Protection Enabled: $rtpEnabled" -ForegroundColor Yellow
                    Write-Host "[*] Try restarting the system for changes to take full effect" -ForegroundColor Yellow
                    return $false
                }
            }
        } catch {
            Write-Host "[!] Could not verify via Get-MpComputerStatus" -ForegroundColor Yellow
            Write-Host "[*] Registry changes have been applied. Restart may be required for full verification." -ForegroundColor Yellow
            return $true
        }
    }
    catch {
        Write-Host "`n[!] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "`n[+] Defender-Control module loaded successfully!" -ForegroundColor Green
Write-Host "[+] Available functions:" -ForegroundColor Green
Write-Host "    - Disable-Defender   : Disable Windows Defender" -ForegroundColor Cyan
Write-Host "    - Enable-Defender    : Re-enable Windows Defender`n" -ForegroundColor Cyan
