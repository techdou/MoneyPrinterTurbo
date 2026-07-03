param(
    [switch]$NoBrowser,
    [switch]$Foreground,
    [int]$WebPort = 8501,
    [int]$ApiPort = 18080
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path (Join-Path $ScriptDir "..")
$Python = Join-Path $Root ".venv\Scripts\python.exe"
$RunDir = Join-Path $Root ".run"
$LogDir = Join-Path $Root "logs"
$ConfigFile = Join-Path $Root "config.toml"
$ExampleConfig = Join-Path $Root "config.example.toml"

function Test-PortListening {
    param([int]$Port)
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Start-LocalProcess {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$OutLog,
        [string]$ErrLog,
        [string]$PidFile
    )

    # -Foreground 时前台启动 API（-NoNewWindow），日志直接输出到当前控制台，
    # 便于教学和实时排错；默认仍后台启动并重定向到日志文件。
    if ($Foreground -and $Name -eq "API") {
        $process = Start-Process `
            -FilePath $Python `
            -ArgumentList $Arguments `
            -WorkingDirectory $Root `
            -NoNewWindow `
            -PassThru
        Write-Host "$Name started in foreground, pid=$($process.Id)"
    }
    else {
        $process = Start-Process `
            -FilePath $Python `
            -ArgumentList $Arguments `
            -WorkingDirectory $Root `
            -WindowStyle Hidden `
            -RedirectStandardOutput $OutLog `
            -RedirectStandardError $ErrLog `
            -PassThru
        Write-Host "$Name started, pid=$($process.Id)"
    }

    Set-Content -Path $PidFile -Value $process.Id -Encoding ASCII
}

if (-not (Test-Path $Python)) {
    Write-Host "Virtual environment not found. Running uv sync --frozen..."
    Push-Location $Root
    try {
        uv sync --frozen
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $ConfigFile) -and (Test-Path $ExampleConfig)) {
    Copy-Item $ExampleConfig $ConfigFile
    Write-Host "Created config.toml from config.example.toml"
}

New-Item -ItemType Directory -Path $RunDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

if (Test-PortListening -Port $ApiPort) {
    Write-Host "API port $ApiPort is already listening."
}
else {
    Start-LocalProcess `
        -Name "API" `
        -Arguments @("main.py") `
        -OutLog (Join-Path $LogDir "techdou-api.out.log") `
        -ErrLog (Join-Path $LogDir "techdou-api.err.log") `
        -PidFile (Join-Path $RunDir "api.pid")

    # 启动后做一次健康检查，避免 API 进程起来但 import 失败 / 端口未真正监听
    # 时，WebUI 仍照常启动并最终 500。前台模式由用户自行观察，不在此轮询。
    if (-not $Foreground) {
        $apiReady = $false
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep -Milliseconds 500
            try {
                $pingResp = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/ping" -Method Get -TimeoutSec 2
                if ($pingResp -eq "pong") {
                    $apiReady = $true
                    break
                }
            }
            catch {
                # API 还没起来，继续重试
            }
        }
        if (-not $apiReady) {
            $apiErrLog = Join-Path $LogDir "techdou-api.err.log"
            Write-Warning "API did not become healthy on http://127.0.0.1:$ApiPort/ping within 5s."
            Write-Warning "Check the error log: $apiErrLog"
            Write-Warning "Continuing to start WebUI, but API calls may fail."
        }
        else {
            Write-Host "API healthy (GET /ping -> pong)."
        }
    }
}

$SelectedWebPort = $WebPort
$WebPidFile = Join-Path $RunDir "webui.pid"
$ExistingWebPid = if (Test-Path $WebPidFile) { (Get-Content $WebPidFile -Raw).Trim() } else { "" }
$ExistingWebProcess = if ($ExistingWebPid) { Get-Process -Id ([int]$ExistingWebPid) -ErrorAction SilentlyContinue } else { $null }

if ($ExistingWebProcess -and (Test-PortListening -Port $SelectedWebPort)) {
    Write-Host "WebUI is already running, pid=$($ExistingWebProcess.Id)"
}
else {
    while ((Test-PortListening -Port $SelectedWebPort) -and $SelectedWebPort -lt 8599) {
        $SelectedWebPort++
    }

    if (Test-PortListening -Port $SelectedWebPort) {
        throw "No available WebUI port in range $WebPort-8599."
    }

    Start-LocalProcess `
        -Name "WebUI" `
        -Arguments @(
            "-m", "streamlit", "run", ".\webui\Main.py",
            "--server.address=127.0.0.1",
            "--server.port=$SelectedWebPort",
            "--browser.serverAddress=127.0.0.1",
            "--browser.gatherUsageStats=False",
            "--server.showEmailPrompt=False",
            "--server.enableCORS=True"
        ) `
        -OutLog (Join-Path $LogDir "techdou-webui.out.log") `
        -ErrLog (Join-Path $LogDir "techdou-webui.err.log") `
        -PidFile $WebPidFile
}

$WebUrl = "http://127.0.0.1:$SelectedWebPort"
$ApiUrl = "http://127.0.0.1:$ApiPort/docs"

Write-Host "WebUI: $WebUrl"
Write-Host "API docs: $ApiUrl"

if (-not $NoBrowser) {
    Start-Process $WebUrl
}
