# Pusula — kişisel yatırım asistanı (geliştirme aşamasında)

> **Yatırım tavsiyesi değildir.** Sistem gerçek emir açmaz, borsa/aracı kurum anahtarı kullanmaz;
> yalnızca analiz ve sinyal üretir.

Bu depo üç şeyi barındırır:

1. **Python referans motoru** (`main.py`, `agents/`): 11 ajanlı, sıfır bağımlılıklı kripto analiz motoru.
   Mobil uygulamanın analiz çekirdeği için başvuru kaynağıdır.
2. **`pusula_core/`**: mobil uygulamanın saf Dart analiz çekirdeği (veri katmanı, BIST takvimi/evreni, göstergeler, 6 kurulum, Monte Carlo, sinyal günlüğü, haftalık rapor).
3. **`pusula_app/`**: Flutter (Android + Web önizleme) uygulaması; SQLite kalıcı depolama, yerel bildirim motoru ve Android arka plan zamanlayıcısı. Kararlar: [docs/kararlar.md](docs/kararlar.md),
   plan: [docs/plan.md](docs/plan.md), sürümler: [docs/degisiklik-gunlugu.md](docs/degisiklik-gunlugu.md).

## Durum

| Faz | Durum |
|---|---|
| 0 — Telegram temizliği, token silme | Tamam |
| 1 — Veri katmanı, BIST takvimi ve evreni | Tamam |
| 2 — Analiz çekirdeği ve sinyal günlüğü (`pusula_core` 0.2.0) | Tamam (58 test) |
| 3 — Haftalık rapor ve bütçe ağırlıklandırma (`pusula_core` 0.3.0) | Tamam (63 test) |
| 4 — Flutter iskeleti, depolama, arka plan, yerel bildirimler ve APK (`pusula_app` 0.1.0) | Tamam (8 test + APK) |
| 5 — "GÜNDÜZ" arayüzü, 3D bütçe halkası ve 4 ekran (`pusula_app` 0.2.0) | Tamam (11 test + Web önizleme) |
| 6 — Kendini geliştirme, Wilson %95 GA, 30 sinyal kuralı ve sürüm geri alma (`pusula_core` 0.4.0) | Tamam (66 test) |
| 7 — Yayına hazırlık, gizlilik metni, çok kullanıcı denetimi ve Play beyan listesi (`pusula_app` 1.0.0) | Tamam ([docs/gizlilik-ve-play-beyan.md](docs/gizlilik-ve-play-beyan.md)) |

## Python referans motoru

Kripto evreni sabittir (`config.json` → `watchlist_symbols`): ONDOUSDT, HBARUSDT, BTCUSDT, SIRENUSDT,
XAGUSDT, LINKUSDT, SOLUSDT, PAXGUSDT, XRPUSDT, ETHUSDT.

| # | Ajan | Görev |
|---|---|---|
| 1 | `scanner_agent` | 5 dk mumda 6 kurulum taraması |
| 2 | `news_agent` | RSS + Korku/Açgözlülük; kritik haberde veto |
| 3 | `whale_agent` | Alıcı baskısı, emir defteri, fonlama oranı |
| 4 | `entry_agent` | Yalnızca kapanmış mumla giriş teyidi |
| 5 | `exit_agent` | Stop, hedef, başabaş, süre sınırı |
| 6 | `timemachine_agent` | Monte Carlo olasılık süzgeci |
| 7 | `budget_agent` | Sanal kasaya göre boyut |
| 8 | `risk_agent` | 16 kurallı risk kapısı |
| 9 | `broker_agent` | Sanal (kağıt) pozisyon defteri |
| 10 | `alerts_agent` | Açık pozisyon izleme |
| 11 | `notifier` | Yalnızca yerel bildirim (`data/notifications.jsonl`) |

```powershell
python main.py analyze BTCUSDT   # tek varlık analizi (canlı veri çeker)
python main.py once              # tek tarama + izleme turu
python main.py status            # sanal kasa özeti
python -m unittest discover -s tests   # testler (sentetik veri, ağ gerekmez)
```

`backtest_3ay.py` proje kuralı gereği çalıştırılmaz; performans yalnızca sistemin ileriye dönük
ürettiği sinyallerin gerçekleşen sonuçlarıyla ölçülür.

## Gizlilik

- Kodda, yapılandırmada ve loglarda anahtar/token bulunmaz. Motor `.env` okumaz.
- Bildirimler yalnızca yereldir; hiçbir mesajlaşma servisine veri gitmez.
- Dışarıya giden tek trafik, herkese açık piyasa verisi ve haber akışı istekleridir.

## Geliştirici notları

- Araçlar `C:\Users\eren_\dev` altında (Flutter, JDK 17, Android SDK). Her yeni terminalde önce ortamı açın:
  PowerShell `. .\araclar\ortam.ps1`, Git Bash `source araclar/ortam.sh`.
- Dart çekirdeği: `cd pusula_core; dart pub get; dart analyze; dart test`.
- Canlı duman testi (ağ gerekir, birim testlerin parçası değil): `dart run tool/smoke.dart --all`.
- Testler `config.json` dosyasını okur; yapılandırma şeması değişirse testleri güncelleyin.
- APK derleme ve telefona yükleme adımları:
  ```powershell
  . .\araclar\ortam.ps1
  cd pusula_app
  flutter pub get
  flutter analyze
  flutter test
  flutter build apk --debug
  # Telefon USB hata ayıklama ile bağlıysa:
  adb devices
  adb install -r build\app\outputs\flutter-apk\app-debug.apk
  ```
