param([string]$JavaHome, [string]$DataDirectory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $JavaHome) {
  $bundled = Get-ChildItem -LiteralPath "$env:TEMP\stewardie-temurin21" -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } |
    Select-Object -First 1
  $JavaHome = if ($bundled) { $bundled.FullName } else { $env:JAVA_HOME }
}
if ($JavaHome) {
  $env:JAVA_HOME = $JavaHome
  $env:PATH = "$(Join-Path $JavaHome 'bin');$env:PATH"
}
$javaVersion = (& java -version 2>&1 | Out-String)
if ($javaVersion -notmatch 'version "(\d+)' -or [int]$Matches[1] -lt 21) {
  throw 'Java 21 or newer is required. Run this script with -JavaHome pointing to its installation.'
}
if (-not $DataDirectory) { $DataDirectory = Join-Path $projectRoot '.local\firebase-emulators' }
$importDirectory = $DataDirectory
if (-not (Test-Path -LiteralPath (Join-Path $importDirectory 'firebase-export-metadata.json'))) {
  $importDirectory = Join-Path $env:TEMP 'stewardie-emulator-data'
}
$firebaseCli = Join-Path $projectRoot 'backend\firebase\functions\node_modules\firebase-tools\lib\bin\firebase.js'
if (-not (Test-Path -LiteralPath $firebaseCli)) { throw 'Run npm ci in backend/firebase/functions first.' }
$cliArgs = @($firebaseCli, 'emulators:start', '--project', 'demo-stewardie', '--only', 'auth,firestore,functions', "--export-on-exit=$DataDirectory")
if (Test-Path -LiteralPath (Join-Path $importDirectory 'firebase-export-metadata.json')) { $cliArgs += "--import=$importDirectory" }
Push-Location $projectRoot
try { & node @cliArgs } finally { Pop-Location }
