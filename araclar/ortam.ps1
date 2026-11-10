# Geliştirme ortamı (PowerShell). Kullanım:  . .\araclar\ortam.ps1
# Sistem ayarlarını değiştirmez; yalnızca bu oturum için geçerlidir.
$env:JAVA_HOME = "C:\Users\eren_\dev\jdk-17.0.21+9"
$env:ANDROID_HOME = "C:\Users\eren_\dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_CACHE = "C:\Users\eren_\dev\pub-cache"
$env:Path = "C:\Users\eren_\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;" + $env:Path

# PC (Chrome / Web) önizlemesinde Yahoo Finance ve İş Yatırım CORS engeline takılmaması için
# yerel salt-okunur köprüyü (127.0.0.1:8787) arka planda başlatır.
$proxyScript = Join-Path $PSScriptRoot "cors_proxy.dart"
if (Test-Path $proxyScript) {
  $conn = Get-NetTCPConnection -LocalPort 8787 -State Listen -ErrorAction SilentlyContinue
  if (-not $conn) {
    Start-Process -FilePath "C:\Users\eren_\dev\flutter\bin\dart.bat" -ArgumentList "run `"$proxyScript`"" -WindowStyle Hidden
  }
}
