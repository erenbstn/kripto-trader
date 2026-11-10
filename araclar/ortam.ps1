# Geliştirme ortamı (PowerShell). Kullanım:  . .\araclar\ortam.ps1
# Sistem ayarlarını değiştirmez; yalnızca bu oturum için geçerlidir.
$env:JAVA_HOME = "C:\Users\eren_\dev\jdk-17.0.21+9"
$env:ANDROID_HOME = "C:\Users\eren_\dev\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_CACHE = "C:\Users\eren_\dev\pub-cache"
$env:Path = "C:\Users\eren_\dev\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;" + $env:Path
