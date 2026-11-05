# Bateria completa no Windows (PowerShell).
#   $env:GODOT="C:\Godot\Godot_v4.6-stable_win64_console.exe"; .\perf\run_perf.ps1
param([int]$Runs = 5, [int]$StageSeconds = 60, [int]$Cycles = 5, [switch]$Headless)
$Godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$Project = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $Project ("perf_results\" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$Commit = (git -C $Project rev-parse --short HEAD 2>$null); if (-not $Commit) { $Commit = "n/d" }
$Video = if ($Headless) { @("--headless") } else { @("--windowed", "--resolution", "1280x720") }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

function Invoke-Perf($Name, $TimeoutSec, [string[]]$RunnerArgs) {
	$allArgs = @("--path", $Project) + $Video + @("res://perf/perf_runner.tscn", "--") + $RunnerArgs + @("--out=$Out", "--commit=$Commit")
	$p = Start-Process -FilePath $Godot -ArgumentList $allArgs -PassThru -NoNewWindow `
		-RedirectStandardOutput (Join-Path $Out "perf_$Name.log") -RedirectStandardError (Join-Path $Out "perf_$Name.err.log")
	if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Set-Content (Join-Path $Out "exit_$Name.txt") 124 }
	else { Set-Content (Join-Path $Out "exit_$Name.txt") $p.ExitCode }
	Write-Host "[$Name] saida $(Get-Content (Join-Path $Out "exit_$Name.txt"))"
}

1..$Runs | ForEach-Object { Invoke-Perf "load_$_" 300 @("--mode=load", "--run=$_") }
Invoke-Perf "sustained" (2 * $StageSeconds + $Cycles * 15 + 180) @("--mode=sustained", "--seconds=$StageSeconds", "--cycles=$Cycles")
& $Godot --headless --path $Project -s res://perf/perf_report_cli.gd -- "--dir=$Out"
