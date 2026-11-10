# Pusula — kişisel yatırım asistanı (geliştirme aşamasında)

> **Yatırım tavsiyesi değildir.** Sistem gerçek emir açmaz, borsa/aracı kurum anahtarı kullanmaz;
> yalnızca analiz ve sinyal üretir.

Bu depo üç şeyi barındırır:

1. **Python referans motoru** (`main.py`, `agents/`): 11 ajanlı, sıfır bağımlılıklı kripto analiz motoru.
   Mobil uygulamanın analiz çekirdeği için başvuru kaynağıdır.
2. **`pusula_core/`**: mobil uygulamanın saf Dart analiz çekirdeği (şu an veri katmanı, BIST takvimi ve evreni).
3. **Mobil uygulama** (henüz başlamadı): Flutter + Dart; Borsa İstanbul ve kriptoyu kapsayan, telefonda
   çalışan, yerel bildirim gönderen uygulama. Kararlar: [docs/kararlar.md](docs/kararlar.md),
   plan: [docs/plan.md](docs/plan.md), sürümler: [docs/degisiklik-gunlugu.md](docs/degisiklik-gunlugu.md).

## Durum

| Faz | Durum |
|---|---|
| 0 — Telegram temizliği, token silme | Tamam |
| 1 — Veri katmanı, BIST takvimi ve evreni | Tamam |
| 2–7 | Sırada |

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
- APK derleme ve telefona yükleme adımları Faz 4'te buraya eklenecek.
