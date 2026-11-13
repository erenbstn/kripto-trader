<#
.SYNOPSIS
  Android Release APK güncellemelerinin telefonundaki mevcut verileri silmeden
  üstüne kurulabilmesi için tek seferlik kişisel imza anahtarı (keystore) üretir.
  Üretilen .jks ve key.properties dosyaları .gitignore kapsamındadır; git'e girmez.
#>
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "ortam.ps1")

$androidDir = Join-Path $repoRoot "pusula_app\android"
$jksPath = Join-Path $androidDir "pusula-release.jks"
$propsPath = Join-Path $androidDir "key.properties"

if (Test-Path $jksPath) {
  Write-Host "Kişisel imza anahtarı zaten mevcut: $jksPath"
  exit 0
}

# Rastgele güçlü parola üret (ekrana yazdırılmaz; yalnızca key.properties içine ve panoya/kullanıcıya özet verilir)
$bytes = New-Object byte[] 18
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$pass = [Convert]::ToBase64String($bytes).Replace("/", "A").Replace("+", "B").Replace("=", "")

& keytool -genkeypair -v `
  -keystore $jksPath `
  -storetype PKCS12 `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias pusula `
  -storepass $pass `
  -keypass $pass `
  -dname "CN=Pusula Kisisel, OU=Mobile, O=Pusula, L=Istanbul, C=TR"

if ($LASTEXITCODE -ne 0) {
  throw "keytool anahtar oluşturamadı."
}

$propsContent = @"
storeFile=pusula-release.jks
storePassword=$pass
keyAlias=pusula
keyPassword=$pass
"@
[IO.File]::WriteAllText($propsPath, $propsContent, [Text.UTF8Encoding]::new($false))

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jksPath))
$b64Out = Join-Path $androidDir "github-secret-base64.txt"
Set-Content -Path $b64Out -Value $b64 -Encoding UTF8

Write-Host ""
Write-Host "Kişisel keystore oluşturuldu (Git'e eklenmez):"
Write-Host "  - Anahtar: $jksPath"
Write-Host "  - Yapılandırma: $propsPath"
Write-Host ""
Write-Host "GitHub Actions ile buluttan otomatik APK yayınlayacaksan repo Settings -> Secrets -> Actions içine ekle:"
Write-Host "  1) PUSULA_KEYSTORE_BASE64   -> $b64Out dosyasının içeriği"
Write-Host "  2) PUSULA_KEYSTORE_PASSWORD -> $propsPath içindeki storePassword değeri"
Write-Host "  (Ekledikten sonra github-secret-base64.txt dosyasını silebilirsin.)"

