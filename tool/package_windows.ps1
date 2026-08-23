$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$distributionDirectory = Join-Path $projectRoot 'dist'
$archive = Join-Path $distributionDirectory 'work-experience-library-windows-1.1.0.zip'

Set-Location -LiteralPath $projectRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) {
  $flutterCommand.Source
} else {
  Join-Path $env:USERPROFILE 'flutter-sdk\bin\flutter.bat'
}
if (-not (Test-Path -LiteralPath $flutter)) {
  throw 'Flutter was not found in PATH or under flutter-sdk in the current user profile.'
}

& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
& $flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }
& $flutter test --no-pub
if ($LASTEXITCODE -ne 0) { throw 'flutter test failed.' }
& $flutter build windows --release --no-pub
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed.' }

if (-not (Test-Path -LiteralPath $releaseDirectory)) {
  throw "Windows release directory was not created: $releaseDirectory"
}
New-Item -ItemType Directory -Path $distributionDirectory -Force | Out-Null
if (Test-Path -LiteralPath $archive) {
  Remove-Item -LiteralPath $archive -Force
}
Compress-Archive -Path (Join-Path $releaseDirectory '*') -DestinationPath $archive -CompressionLevel Optimal
Write-Output $archive
