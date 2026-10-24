# SpendSense AI - Robust 7-Day Backend & Cloudflare Tunnel Supervisor
#
# Manages:
# 1. FastAPI backend (port 8000)
# 2. Cloudflare Tunnel (named token or quick tunnel)
# 3. Dynamic URL publishing to backend/.active_tunnel_url, backend_status.json, and frontend/.env
# 4. Continuous watchdog loop with auto-recovery from sleep, disconnects, crashes

param (
    [switch]$RunOnce,
    [int]$WatchdogIntervalSec = 20
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$BackendDir = "$Root\backend"
$FrontendDir = "$Root\frontend"
$StatusFile = "$BackendDir\backend_status.json"
$ActiveUrlFile = "$BackendDir\.active_tunnel_url"
$TunnelLog = "$BackendDir\tunnel.log"
$SupervisorLog = "$BackendDir\supervisor.log"

function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] [$Level] $Msg"
    Write-Host $line
    try {
        Add-Content -Path $SupervisorLog -Value $line -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log "=== SpendSense AI Supervisor Starting ==="

# 1. Resolve cloudflared binary
$CF = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
if (-not (Test-Path $CF)) { $CF = "C:\Program Files\cloudflared\cloudflared.exe" }
if (-not (Test-Path $CF)) {
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) { $CF = $cmd.Source }
}
if (-not (Test-Path $CF)) {
    Write-Log "cloudflared not found! Please install with: winget install Cloudflare.cloudflared" "ERROR"
    exit 1
}
Write-Log "Using cloudflared: $CF"

# 2. Clean up any stale or orphaned processes
function Stop-StaleProcesses {
    Write-Log "Checking for stale processes on port 8000..."
    $conns = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
    if ($conns) {
        foreach ($c in $conns) {
            $pidToKill = $c.OwningProcess
            if ($pidToKill -gt 0) {
                Write-Log "Stopping stale process $pidToKill listening on port 8000" "WARN"
                Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -Seconds 1
    }
    # Stop existing cloudflared instances
    $cfProcs = Get-Process -Name cloudflared -ErrorAction SilentlyContinue
    if ($cfProcs) {
        Write-Log "Stopping existing cloudflared processes..." "WARN"
        $cfProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

Stop-StaleProcesses

# 3. Start Python FastAPI backend
function Start-Backend {
    Write-Log "Starting FastAPI backend (python main.py)..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "python"
    $psi.Arguments = "main.py"
    $psi.WorkingDirectory = $BackendDir
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)

    # Wait for backend health check
    $healthy = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 800
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 2 -ErrorAction Stop
            if ($resp.status -eq "ok") {
                $healthy = $true
                Write-Log "Backend is healthy on http://127.0.0.1:8000 (GeminiConfigured: $($resp.geminiConfigured), Auth: $($resp.authConfigured))" "SUCCESS"
                break
            }
        } catch {}
    }

    if (-not $healthy) {
        Write-Log "FastAPI backend failed to become healthy within 24 seconds!" "ERROR"
        return $null
    }
    return $proc
}

$backendProc = Start-Backend
if (-not $backendProc) {
    Write-Log "Aborting supervisor due to backend startup failure." "ERROR"
    exit 1
}

# 4. Start Cloudflare Tunnel
function Start-Tunnel {
    # Check if a custom token exists in backend/.env
    $envContent = ""
    if (Test-Path "$BackendDir\.env") {
        $envContent = Get-Content "$BackendDir\.env" -Raw
    }
    $tokenMatch = [regex]::Match($envContent, 'CLOUDFLARE_TUNNEL_TOKEN=([^\r\n]+)')
    $customToken = if ($tokenMatch.Success) { $tokenMatch.Groups[1].Value.Trim() } else { "" }

    if (Test-Path $TunnelLog) {
        Remove-Item $TunnelLog -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Starting Cloudflare Tunnel..."
    if ($customToken -ne "") {
        Write-Log "Using Named Cloudflare Tunnel with configured token."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $CF
        $psi.Arguments = "tunnel run --token $customToken"
        $psi.WorkingDirectory = $BackendDir
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        return @{ Process = $proc; IsNamed = $true }
    } else {
        Write-Log "Using Cloudflare Quick Tunnel (auto-recovering)..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c `"$CF`" tunnel --url http://127.0.0.1:8000 2>`"$TunnelLog`""
        $psi.WorkingDirectory = $BackendDir
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        return @{ Process = $proc; IsNamed = $false }
    }
}

function Extract-TunnelUrl {
    param([int]$MaxWaitSec = 25)
    $url = $null
    for ($i = 0; $i -lt $MaxWaitSec; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Path $TunnelLog) {
            try {
                $content = Get-Content -Path $TunnelLog -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $m = [regex]::Match($content, 'https://[a-zA-Z0-9-]+\.trycloudflare\.com')
                    if ($m.Success) {
                        $url = $m.Value
                        break
                    }
                }
            } catch {}
        }
    }
    return $url
}

function Verify-PublicUrl {
    param([string]$Url, [int]$Retries = 10)
    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            $resp = Invoke-RestMethod -Uri "$Url/health" -TimeoutSec 4 -ErrorAction Stop
            if ($resp.status -eq "ok") {
                return $true
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    return $false
}

function Save-ActiveUrl {
    param([string]$Url)
    # 1. backend/.active_tunnel_url
    Set-Content -Path $ActiveUrlFile -Value $Url -Force -ErrorAction SilentlyContinue

    # 2. backend/backend_status.json
    $statusData = @{
        status = "healthy"
        publicUrl = $Url
        localUrl = "http://127.0.0.1:8000"
        lastUpdated = (Get-Date).ToString("o")
        backendPid = if ($backendProc) { $backendProc.Id } else { 0 }
    } | ConvertTo-Json
    Set-Content -Path $StatusFile -Value $statusData -Force -ErrorAction SilentlyContinue

    # 3. frontend/.env
    $frontendEnv = "$FrontendDir\.env"
    if (Test-Path $frontendEnv) {
        $envLines = Get-Content $frontendEnv
        $found = $false
        $newLines = @()
        foreach ($line in $envLines) {
            if ($line -match '^BACKEND_PUBLIC_URL=') {
                $newLines += "BACKEND_PUBLIC_URL=$Url"
                $found = $true
            } else {
                $newLines += $line
            }
        }
        if (-not $found) {
            $newLines += "BACKEND_PUBLIC_URL=$Url"
        }
        Set-Content -Path $frontendEnv -Value $newLines -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Active public URL saved: $Url" "SUCCESS"
}

$tunnelObj = Start-Tunnel
$publicUrl = Extract-TunnelUrl

if ($publicUrl) {
    Write-Log "Captured Cloudflare URL: $publicUrl. Verifying public reachability..."
    $verified = Verify-PublicUrl -Url $publicUrl
    if ($verified) {
        Write-Log "Public HTTPS endpoint verified healthy: $publicUrl" "SUCCESS"
        Save-ActiveUrl -Url $publicUrl
    } else {
        Write-Log "Cloudflare URL was captured but could not be reached over public DNS within timeout." "WARN"
        Save-ActiveUrl -Url $publicUrl
    }
} else {
    Write-Log "Failed to extract tunnel URL within timeout." "ERROR"
}

if ($RunOnce) {
    Write-Log "RunOnce requested. Exiting supervisor."
    exit 0
}

# 5. Continuous Watchdog Loop (7-Day Uptime Protection)
Write-Log "Supervisor entering continuous watchdog loop (interval: ${WatchdogIntervalSec}s)..."
$consecutiveTunnelFailures = 0
$consecutiveBackendFailures = 0
$lastTick = [System.DateTime]::UtcNow

while ($true) {
    Start-Sleep -Seconds $WatchdogIntervalSec
    $now = [System.DateTime]::UtcNow
    $timeDrift = ($now - $lastTick).TotalSeconds
    $lastTick = $now

    # Detect Windows sleep/wake cycle
    if ($timeDrift -gt ($WatchdogIntervalSec * 2.5)) {
        Write-Log "Time jump detected ($([math]::Round($timeDrift))s) - PC likely woke from sleep. Probing services..." "WARN"
    }

    # A. Check Local Backend Health
    $localHealthy = $false
    try {
        $localResp = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 3 -ErrorAction Stop
        if ($localResp.status -eq "ok") {
            $localHealthy = $true
            $consecutiveBackendFailures = 0
        }
    } catch {
        $consecutiveBackendFailures++
    }

    if (-not $localHealthy) {
        Write-Log "Backend health check failed (failure count: $consecutiveBackendFailures)!" "WARN"
        if ($consecutiveBackendFailures -ge 2) {
            Write-Log "Backend unresponsive. Restarting backend process..." "ERROR"
            Stop-StaleProcesses
            $backendProc = Start-Backend
            $consecutiveBackendFailures = 0
        }
    }

    # B. Check Public Tunnel Health
    if ($publicUrl) {
        $pubHealthy = $false
        try {
            $pubResp = Invoke-RestMethod -Uri "$publicUrl/health" -TimeoutSec 4 -ErrorAction Stop
            if ($pubResp.status -eq "ok") {
                $pubHealthy = $true
                $consecutiveTunnelFailures = 0
            }
        } catch {
            $consecutiveTunnelFailures++
        }

        if (-not $pubHealthy) {
            Write-Log "Public tunnel check failed at $publicUrl (failure count: $consecutiveTunnelFailures)" "WARN"
            if ($consecutiveTunnelFailures -ge 2) {
                Write-Log "Tunnel disconnected or rotated. Recovering Cloudflare tunnel..." "ERROR"
                # Stop existing cloudflared
                Get-Process -Name cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                
                # Restart tunnel
                $tunnelObj = Start-Tunnel
                $newUrl = Extract-TunnelUrl
                if ($newUrl) {
                    $publicUrl = $newUrl
                    Write-Log "New tunnel URL established: $publicUrl. Verifying..." "SUCCESS"
                    if (Verify-PublicUrl -Url $publicUrl) {
                        Save-ActiveUrl -Url $publicUrl
                        $consecutiveTunnelFailures = 0
                    }
                } else {
                    Write-Log "Failed to extract new tunnel URL on recovery attempt." "ERROR"
                }
            }
        }
    } else {
        # Try to restart tunnel if we never got an initial URL
        Write-Log "No active public URL. Attempting tunnel start..." "WARN"
        $tunnelObj = Start-Tunnel
        $publicUrl = Extract-TunnelUrl
        if ($publicUrl) {
            Save-ActiveUrl -Url $publicUrl
        }
    }
}
