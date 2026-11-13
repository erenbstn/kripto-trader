<#
.SYNOPSIS
  Sürüm numarasını (+1 buildNumber) artırır, testleri çalıştırır, sürüm etiketi
  oluşturup GitHub'a gönderir. GitHub Actions APK'yı derleyip Releases'a koyar.
.EXAMPLE
  .\araclar\surum-yayinla.ps1
  .\araclar\surum-yayinla.ps1 -VersionName "1.2.0"
#>
param(
  [string]$VersionName = "",
  [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
. (Join-Path $PSScriptRoot "ortam.ps1")

$pubspecPath = Join-Path $repoRoot "pusula_app\pubspec.yaml"
$pubspec = Get-Content -Path $pubspecPath -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
if (-not $m.Success) {
  throw "pubspec.yaml içinde version: X.Y.Z+N satırı bulunamadı."
}

$curName = $m.Groups[1].Value
$curCode = [int]$m.Groups[2].Value
$nextName = if ([string]::IsNullOrWhiteSpace($VersionName)) { $curName } else { $VersionName.Trim() }
$nextCode = $curCode + 1
$nextFull = "$nextName+$nextCode"
$tag = "v$nextFull"

if (-not $SkipTests) {
  Push-Location (Join-Path $repoRoot "pusula_core")
  dart analyze; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  dart test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Pop-Location

  Push-Location (Join-Path $repoRoot "pusula_app")
  flutter analyze; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  flutter test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Pop-Location
}

$updated = [regex]::Replace($pubspec, '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$', "version: $nextFull")
[IO.File]::WriteAllText($pubspecPath, $updated, [Text.UTF8Encoding]::new($false))

Write-Host "Yeni sürüm hazırlandı: $tag"

$remote = git remote 2>$null
if ([string]::IsNullOrWhiteSpace($remote)) {
  Write-Host "Henüz git remote tanımlı değil; yalnızca yerel release APK derleniyor..."
  Push-Location (Join-Path $repoRoot "pusula_app")
  flutter build apk --release --build-name="$nextName" --build-number="$nextCode"
  Pop-Location
  Write-Host "APK hazır: pusula_app\build\app\outputs\flutter-apk\app-release.apk"
  exit 0
}

git add pusula_app/pubspec.yaml
git commit -m "Sürüm $tag"
git tag $tag
git push origin HEAD
git push origin $tag

Write-Host ""
Write-Host "GitHub'a gönderildi: $tag"
Write-Host "GitHub Actions birkaç dakika içinde APK'yı Releases altına yükleyecek;"
Write-Host "ardından telefonundaki Pusula uygulamasında güncelleme bildirimi görünecek."

