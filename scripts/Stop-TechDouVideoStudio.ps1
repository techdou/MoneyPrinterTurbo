$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path (Join-Path $ScriptDir "..")
$RunDir = Join-Path $Root ".run"

function Get-ChildProcessIds {
    param([int]$ParentProcessId)

    # 用 -Filter 在 CIM 层过滤，而不是拉全表后再 Where-Object。
    # 进程多的机器上后者每层递归都遍历全部进程，会慢到秒级。
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentProcessId"

    foreach ($child in $children) {
        $child.ProcessId
        Get-ChildProcessIds -ParentProcessId $child.ProcessId
    }
}

function Stop-FromPidFile {
    param([string]$PidFile)

    if (-not (Test-Path $PidFile)) {
        return
    }

    $processIdText = (Get-Content $PidFile -Raw).Trim()
    if (-not $processIdText) {
        Remove-Item $PidFile -Force
        return
    }

    $rootProcessId = [int]$processIdText
    $processIds = @(Get-ChildProcessIds -ParentProcessId $rootProcessId) + $rootProcessId
    $processIds = $processIds | Select-Object -Unique

    foreach ($processId in $processIds) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $process.Id -Force
            Write-Host "Stopped pid=$($process.Id)"
        }
    }

    Remove-Item $PidFile -Force
}

Stop-FromPidFile (Join-Path $RunDir "webui.pid")
Stop-FromPidFile (Join-Path $RunDir "api.pid")

Write-Host "TechDou Video Studio local processes stopped."
