# Builds the Web version and publishes it for playtesters.
#
#   .\deploy.ps1                 tests, export, push to itch.io, publish latest.json
#   .\deploy.ps1 -NoPush         tests and export only (build\web), nothing is uploaded
#   .\deploy.ps1 -SkipTests      skip the rules tests (not recommended)
#
# Needs: $env:ITCH_TARGET (e.g. "nitzanv2/fallen-pantheons:html5") and a one-time `butler login`.
# Pushing to main on GitHub runs the same steps in CI (.github/workflows/deploy.yml).

param(
	[switch]$NoPush,
	[switch]$SkipTests,
	[string]$ItchTarget = $env:ITCH_TARGET,
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "C:\Users\nitza\Godot\Godot_v4.7.2-stable_win64_console.exe" })
)

# Not "Stop": Windows PowerShell turns any stderr output of git/Godot into a fatal error.
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
$game = Join-Path $root "game"
$out = Join-Path $root "build\web"
$infoPath = Join-Path $game "build_info.json"

if (-not $NoPush -and -not $ItchTarget) {
	throw "Set `$env:ITCH_TARGET (e.g. 'nitzanv2/fallen-pantheons:html5') or pass -ItchTarget, or use -NoPush."
}

if (-not $SkipTests) {
	Write-Host "Running rules tests..."
	$log = & $Godot --headless --path $game --script res://tests/run_tests.gd 2>&1
	$summary = $log | Select-String -Pattern "checks, \d+ failures"
	if ($LASTEXITCODE -ne 0 -or ($log | Select-String -SimpleMatch "SCRIPT ERROR")) {
		$log | Select-String -Pattern "FAIL|SCRIPT ERROR" | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
		throw "Tests failed - nothing was deployed."
	}
	Write-Host $summary
}

$sha = (git -C $root rev-parse --short HEAD 2>$null)
$dirty = (git -C $root status --porcelain 2>$null)
$version = (Get-Date -Format "yyyy.MM.dd-HHmm") + $(if ($sha) { "-$sha" } else { "" }) + $(if ($dirty) { "-local" } else { "" })
Write-Host "Building $version..."

$utf8 = New-Object System.Text.UTF8Encoding($false)
$original = [IO.File]::ReadAllText($infoPath)
try {
	$info = $original | ConvertFrom-Json -ErrorAction Stop
	$info.version = $version
	[IO.File]::WriteAllText($infoPath, ($info | ConvertTo-Json), $utf8)
	if (Test-Path $out) { Remove-Item $out -Recurse -Force }
	New-Item -ItemType Directory -Force $out | Out-Null
	& $Godot --headless --path $game --export-release "Web" $out\index.html 2>&1 | Select-String -Pattern "ERROR" | ForEach-Object { Write-Host $_ }
	if (-not (Test-Path "$out\index.html")) { throw "Export failed (are the 4.7.2 export templates installed?)." }
} finally {
	[IO.File]::WriteAllText($infoPath, $original, $utf8)
}
Write-Host "Exported to $out"
if ($NoPush) { return }

$butler = Get-Command butler -ErrorAction SilentlyContinue
$butlerPath = if ($butler) { $butler.Source } else { Join-Path $root "tools\butler\butler.exe" }
if (-not (Test-Path $butlerPath)) {
	Write-Host "Downloading butler..."
	$zip = Join-Path $env:TEMP "butler.zip"
	Invoke-WebRequest "https://broth.itch.zone/butler/windows-amd64/LATEST/archive/default" -OutFile $zip -ErrorAction Stop
	Expand-Archive $zip (Split-Path $butlerPath) -Force -ErrorAction Stop
	Write-Host "Run '$butlerPath login' once, then deploy again."
	return
}
& $butlerPath push $out $ItchTarget --userversion $version
if ($LASTEXITCODE -ne 0) { throw "butler push failed." }

# The game polls latest.json on the 'builds' branch to tell open tabs a new version exists.
$remote = (git -C $root remote get-url origin 2>$null)
if ($remote) {
	$tmp = Join-Path $env:TEMP "fp_latest_$([guid]::NewGuid().ToString('N'))"
	New-Item -ItemType Directory $tmp | Out-Null
	[IO.File]::WriteAllText("$tmp\latest.json", (@{ version = $version; date = (Get-Date -Format o) } | ConvertTo-Json), $utf8)
	git -C $tmp init -q -b builds
	git -C $tmp add latest.json
	git -C $tmp commit -q -m "Build $version"
	git -C $tmp push -q -f $remote builds
	$pushed = $LASTEXITCODE -eq 0
	Remove-Item $tmp -Recurse -Force
	if (-not $pushed) { throw "Build is on itch.io, but publishing latest.json failed." }
	Write-Host "Published latest.json ($version)."
}
Write-Host "Deployed $version."
