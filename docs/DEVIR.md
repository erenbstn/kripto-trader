# Devir Belgesi — Pusula

Tarih: 2026-11-10 · Bu belge, projeyi devralacak yapay zekâ (veya geliştirici) için tek başına yeterli
olacak şekilde yazıldı. Önce bunu, sonra `docs/kararlar.md` ve `docs/plan.md` dosyalarını oku.

---

## 1. Yapıştırılacak başlangıç komutu (prompt)

```text
Rol: Kıdemli mobil uygulama + yazılım mimarı ve nicel analiz mühendisisin.

Bu depoda (C:\Users\eren_\Desktop\Kript_Multi_Agent\kripto-trader) "Pusula" adlı kişisel yatırım
asistanı geliştiriliyor: Borsa İstanbul + kripto için telefonda çalışan, kendi kendine analiz yapan,
yalnızca yerel bildirim gönderen bir Flutter uygulaması. Faz 0 ve Faz 1 bitti ve commit edildi.
Senin işin Faz 2'den Faz 7'ye kadar devam etmek.

Önce şunları sırayla oku: docs/DEVIR.md (tamamı), docs/kararlar.md, docs/plan.md,
docs/degisiklik-gunlugu.md, README.md, sonra pusula_core/lib altındaki tüm kod ve pusula_core/test.
Python referans motoru için main.py ve agents/*.py dosyalarını oku.

Çalışma kuralları:
- Mimari, teknoloji, kod yapısı, test stratejisi ve teknik analiz kararları sende; onay isteme.
  Her kararı gerekçesiyle docs/kararlar.md'ye ekle.
- Yalnızca şu beş durumda dur ve sor: (1) para harcatacak bir şey, (2) bilgisayara yeni yazılım
  kurulumu (neyi, neden, boyutu), (3) gizlilik/güvenlik riski, (4) görsel stili değiştirme isteği,
  (5) DEVIR.md bölüm 2'deki kısıtlardan biriyle çelişki.
- Her fazı kodla, testleri yaz ve çalıştır, docs/plan.md + docs/degisiklik-gunlugu.md + README.md'yi
  güncelle, faz başına bir git commit at, sonunda kısa durum raporu ver: ne çalışıyor, ne DOĞRULANAMADI.
- Her terminalde önce ortamı aç: PowerShell `. .\araclar\ortam.ps1` veya Git Bash `source araclar/ortam.sh`.

Faz 2'den başla.
```

---

## 2. Kesin kısıtlar (kullanıcı kararı, değiştirilemez)

1. **Telegram ve başka mesajlaşma servisi yok.** Bildirimler yalnızca uygulamanın yerel bildirimleridir.
2. **Geçmiş veriyle backtest yok.** `backtest_3ay.py` çalıştırılmaz, yeni backtest yazılmaz, geçmiş mumlarda
   strateji sınanmaz. Raporlardaki getiriler yalnızca sistemin ileriye dönük ürettiği sinyallerin gerçekleşen
   sonuçlarıdır. İlk haftada "geçen hafta raporu: henüz veri yok" denir; veri uydurulmaz.
   Doğrulama: birim testler, kod incelemesi, sentetik veri.
3. **Monte Carlo süzgeci kalır, `replay_historical_sessions` taşınmaz** (kullanıcı 2026-11-10'da onayladı).
4. **Sıfır para.** Ücretli API, abonelik, sunucu yok. Sunucu telefonun kendisi.
5. **Emir ve anahtar yok.** Borsa/aracı kurum API anahtarı istenmez, canlı emir kodu yazılmaz.
   Sistem yalnızca sinyal üretir ve sonucunu izler.
6. **Gizlilik.** Hiçbir anahtar/token düz metin yapılandırmada veya logda durmaz. `.env` hiçbir araçla
   okunmaz/yazdırılmaz. Büyük, paketlenmiş veya üretilmiş dosyalar içeriği yazdırılarak incelenmez.
7. **Her rapor/analiz ekranında görünür "Yatırım tavsiyesi değildir" uyarısı.**
8. **Kripto evreni sabit:** ONDOUSDT, HBARUSDT, BTCUSDT, SIRENUSDT, XAGUSDT, LINKUSDT, SOLUSDT, PAXGUSDT,
   XRPUSDT, ETHUSDT.
9. **Görsel stil sabit: "GÜNDÜZ"** (bölüm 6).
10. **Android Studio ve emülatör kurulmaz.** Deneme, adb ile bağlı gerçek telefonda yapılır.
11. **Aşırı uyum yasağı:** strateji başına en az ~30 kapanmış sinyal birikmeden parametre değişmez;
    az veride yalnızca gözlem yazılır, belirsizlik açıkça gösterilir.

---

## 3. Şu anki durum

### Biten işler (3 commit, çalışma ağacı temiz)

| Commit | İçerik |
|---|---|
| `c5d1d14` | Faz 0: Telegram kodu ve bot token'ı silindi; `agents/notifier.py` (yalnızca yerel bildirim) |
| `c06dabe` | Faz 1: `pusula_core` veri katmanı, BIST takvimi ve evreni, 40 test |
| `45f2a11` | Faz 1 belgeleri |

- Python referans motoru: 10 test geçiyor (`python -m unittest discover -s tests`).
- `pusula_core`: `dart analyze` temiz, `dart test` 40/40 geçiyor.
- Canlı duman testi (2026-11-10): 10 kripto varlığı ve 75 BIST adayının tamamı veri döndürdü,
  hız sınırına takılmadı; likidite süzgeci 40 hisse seçti.

### Kurulu araçlar (`C:\Users\eren_\dev`, yönetici yetkisi ve sistem PATH değişikliği yok)

| Araç | Sürüm | Yol |
|---|---|---|
| Flutter (stable) | 3.47.9, Dart 3.13.7 | `dev\flutter` |
| Temurin JDK | 17.0.21 | `dev\jdk-17.0.21+9` |
| Android SDK | platform 36, build-tools 36.0.0, cmdline-tools, platform-tools | `dev\android-sdk` |
| pub önbelleği | — | `dev\pub-cache` |

`flutter doctor`: Flutter, Android araç zinciri, Chrome ve bağlı cihaz tamam. Visual Studio uyarısı
yalnızca Windows masaüstü derlemesi içindir, bu projede gerekmez. İki adb bulunduğu uyarısı zararsız;
sorun çıkarsa `araclar/ortam.*` içindeki sıralama SDK'daki adb'yi öne alır.

Ortam her terminalde elle açılır: `. .\araclar\ortam.ps1` (PowerShell) veya `source araclar/ortam.sh` (Git Bash).

### Henüz yapılmayan / doğrulanmayan

- Faz 2–7'nin tamamı. Flutter uygulaması (`pusula_app`) hiç oluşturulmadı; APK hiç derlenmedi.
- Telefonda hiçbir şey denenmedi (arka plan, bildirim, pil).
- Kullanıcı bot token'ını BotFather'dan iptal etti mi bilinmiyor; hatırlat.
- Belirsiz kalan varsayımlar: Yahoo `.IS` gecikmesi 15 dk kabul edildi (uç bu alanı boş döndürüyor);
  BIST kapanış seansı bitişi 18:10 kabul edildi; 2027 dini bayram tarihleri öngörüdür;
  BIST fiyat adımı tablosu ve aday listesi elle derlendi, resmî kaynakla karşılaştırılmadı.

---

## 4. Depo haritası

```
kripto-trader/
  main.py, agents/, tests/, config.json   Python referans motoru (ürün değil, başvuru kaynağı)
  backtest_3ay.py                          DOKUNMA, ÇALIŞTIRMA (kısıt 2)
  araclar/ortam.ps1, ortam.sh              geliştirme ortamı
  docs/kararlar.md                         tüm kararlar ve gerekçeleri (K1–K7)
  docs/plan.md                             faz tablosu
  docs/degisiklik-gunlugu.md               sürümlü değişiklik günlüğü
  pusula_core/                             saf Dart analiz çekirdeği (Flutter'a bağımlı değil)
    lib/src/model/      market.dart (Market, BarInterval, Instrument), candle.dart (Candle, CandleSeries)
    lib/src/data/       provider.dart, binance_/yahoo_/isyatirim_provider.dart, market_data_service.dart,
                        rate_limiter.dart, candle_cache.dart, http_fetcher.dart, errors.dart
    lib/src/bist/       bist_calendar.dart, bist_rules.dart, bist_universe.dart
    lib/src/crypto/     crypto_universe.dart
    lib/src/util/       clock.dart (Clock, Sleeper: testte sahte saat)
    test/               helpers.dart (FakeFetcher, FakeClock, StubProvider, syntheticCandles) + 3 test dosyası
    tool/smoke.dart     canlı duman testi (elle): dart run tool/smoke.dart --all
  pusula_app/                              HENÜZ YOK (Faz 4'te oluşturulacak)
```

### Çekirdekte uyulması gereken kalıplar

- Ağ yalnızca `HttpFetcher` üzerinden; testlerde `FakeFetcher`. Birim testleri asla gerçek ağa çıkmaz.
- Zaman yalnızca enjekte edilen `Clock` üzerinden; `DateTime.now()` çekirdek mantığında kullanılmaz.
- Tüm zamanlar UTC milisaniye. Türkiye saati sabit UTC+3 (`BistCalendar.toTrt`).
- `CandleSeries.closed` yalnızca kapanmış mumları taşır. Kapanmamış mum sinyal teyidi sayılmaz.
  BIST'te bir mum, bitişinden 15 dk (veri gecikmesi) sonra kapanmış sayılır.
- Her veri kaynağını (`source`), yaşını (`ageAt`) ve bayatlığını (`stale`) taşır; ekranda gösterilecek.
- Depolama çekirdekte soyut arayüzdür (`CandleCache` örneği); kalıcı sürümü uygulama sağlar.
- Kod yorumları, test adları ve kullanıcıya dönük metinler Türkçe.

---

## 5. Kalan fazlar — ne yapılacak

Gerekçeler ve sayısal sınırlar `docs/kararlar.md` içinde (K3 ağırlık sınırları, K7 strateji değişiklikleri).

### Faz 2 — Analiz çekirdeği + sinyal günlüğü (`pusula_core`)

Python karşılıkları: `agents/scanner_agent.py`, `entry_agent.py`, `exit_agent.py`, `timemachine_agent.py`,
`news_agent.py`, `whale_agent.py`.

1. **Göstergeler:** Wilder RSI, ATR, SMA/EMA, VWAP, ADX, gerçekleşen oynaklık. Python `wilder_rsi` ve
   `compute_atr` ile aynı sentetik girdide aynı sonucu verdiğini testle göster (altın değerler sentetik
   mumdan üretilir, piyasa geçmişinden değil).
2. **Kurulumlar:** ORB, 20-bar kırılım, boğa bayrağı, MA20 geri kazanım, RSI tepkisi, VWAP kırılımı.
   Kripto: 5 dk/1 saat. BIST: 1 saat/günlük (5 dk scalp yok; giriş nokta değil bölge).
3. **Rejim tespiti:** BTC ve XU100 için EMA50/200 eğimi + ADX + oynaklık → boğa / yatay / ayı.
   Kırılım kurulumları yalnızca uygun rejimde; ayı rejiminde risk payı yarıya iner.
4. **Çok dilimli teyit:** sinyal dilimi + bir üst dilimin trendi.
5. **Çıkış planı:** ATR/yapı tabanlı stop, kademeli kâr alma (ör. 1R ve 2R), başabaş kuralı, süre sınırı,
   geçersiz kılma koşulu. BIST seviyeleri `BistRules.roundToTick` ile adıma oturtulur; tavan/taban yakınlığı
   uyarı üretir.
6. **Monte Carlo süzgeci:** `simulate_monte_carlo` mantığı korunur ama havuz `i % seans` dilimi yerine blok
   önyükleme ile kurulur; sonuç güven aralığıyla verilir. Tohum sabitlenebilir olmalı (test için).
   `replay_historical_sessions` TAŞINMAZ.
7. **Haber/olay vetosu:** RSS + Korku/Açgözlülük. Takma ad eşleşmesini daralt (`link`, `sol`, `gold`, `eth`,
   `default` yanlış pozitif üretiyor). Emir defteri dengesi vetodan çıkar, bilgi alanı olur; fonlama vetosu kalır.
8. **Sinyal günlüğü:** her sinyal kalıcı kayıt (varlık, strateji, strateji sürümü, giriş bölgesi, stop, hedefler,
   R:R, güven skoru, gerekçe, rejim, veri kaynağı/yaşı, oluşturulma zamanı) ve yaşam döngüsü:
   `açık → hedef1 → hedef2 | stop | süre doldu | geçersiz`. Sonuç izleme mum en yüksek/en düşüğüyle yapılır;
   aynı mumda hem stop hem hedef varsa muhafazakâr olarak stop sayılır. Depo arayüzü soyut, testte bellek içi.
9. **Güven skoru (0–100):** kurulum çakışması, hacim teyidi, rejim uyumu, üst dilim uyumu, Monte Carlo sonucu,
   R:R. Bileşenleri ayrı ayrı sakla (ekranda gerekçe olarak gösterilecek).

Bitti ölçütü: sentetik mumlarla her kurulum ve rejim için test; sinyal yaşam döngüsü testleri; Python ile
gösterge eşleşme testi.

### Faz 3 — Haftalık rapor üretimi (`pusula_core`)

1. **Geçen hafta raporu:** önerilen her varlığın gerçekleşen getirisi, ağırlıklı portföy getirisi,
   hedefe/stopa ulaşanlar, isabet oranı, en iyi/en kötü, "ne öğrendik". Kayıt yoksa "henüz veri yok".
2. **Yeni haftanın önerileri (BIST ve kripto ayrı):** gerekçe (teknik + haber + hacim/momentum), giriş
   bölgesi, kademeli kâr alma, stop, R:R, geçersiz kılma koşulu, güven skoru, ana riskler, bütçe ağırlığı.
   Sayı sabit değil (0–6); eşik üstü yoksa "bu hafta net fırsat yok, nakitte kal".
3. **Ağırlıklandırma (K3):** risk payı = bütçenin %0,5–1,5'i (güvene göre); ağırlık = risk payı / stop mesafesi.
   Sınırlar ("dengeli"): tek varlık %20, toplam açık risk %6, kripto toplamı %40, en az nakit %20.
   "Temkinli" 0,6×, "atak" 1,4×. Sınır aşımında orantılı küçültme; nakit payı açıkça raporlanır.
4. **Kısa vade haftalık raporu:** toplam getiri, sinyal sayısı, isabet oranı, ortalama R, en iyi/en kötü,
   strateji bazında döküm, kripto ve BIST ayrı.
5. Pazar günü sırası: önce geçen hafta raporu, sonra kısa vade raporu, sonra yeni öneriler. Raporlar
   arşivlenir (Geçmiş ekranı ve performans eğrisi için).

Bitti ölçütü: sentetik günlükten rapor üretimi; boş günlük testi; ağırlık sınırı ve toplam ≤ %100 testleri.

### Faz 4 — Mobil iskelet, arka plan, bildirimler (`pusula_app`)

1. `flutter create` (org kimliği kullanıcıya sorulmadan genel bir değer; Android + web hedefi; web yalnızca
   arayüz önizlemesi için). `pusula_core` yol bağımlılığı olarak eklenir.
2. Durum yönetimi Riverpod; depolama SQLite (`sqflite`): mum önbelleği, sinyal günlüğü, raporlar, ayarlar.
3. Arka plan (K1): WorkManager 15 dk periyodik tarama/izleme; Pazar raporu ve BIST açılış/kapanışı için
   kesin alarm; kullanıcı açarsa kalıcı bildirimli "Canlı izleme" ön plan servisi. Pil optimizasyonu
   muafiyeti için yönlendirme ekranı.
4. Yerel bildirimler (`flutter_local_notifications`): kanallar Sinyal/Sonuç/Rapor/Sistem; 10 dk içinde aynı
   varlık için birleştirme, sessiz saatlerde kuyruk + tek özet, günlük üst sınır, tekrar anahtarı.
   Metin örnekleri: "SOL hedefe ulaştı · +%3,2 · 2R", "Pazar raporun hazır · Geçen hafta +%4,8 · 5 yeni öneri",
   "THYAO stop seviyesine yakın · Stop 312,40 · fiyat 314,10".
5. Debug APK derle (`flutter build apk --debug`), `adb install` ile telefona yükle. Adım adım kurulum
   yönergesini README'ye yaz. Sürüm imzalama anahtarı depoya girmez (`.gitignore` hazır).

Bitti ölçütü: uygulama derlenir, APK telefona yüklenir; bildirim birleştirme/sessiz saat mantığı birim testli.
Doğrulanamayanları yaz: Doze, üretici pil öldürücüleri, gerçek tarama sıklığı.

### Faz 5 — Arayüz ve 3D halka

Ekranlar: Özet (haftanın özeti, 3D ağırlık halkası, açık sinyaller, son bildirimler) · Öneri (önce geçen
hafta sonucu, sonra yeni öneriler; BIST/Kripto sekmeleri; detaylı analiz kartları; içinde Geçmiş arşivi ve
performans eğrisi) · Sinyal (canlı akış + haftalık kısa vade raporu) · Ayar (bildirim tercihleri, bütçe
tutarı, risk iştahı, sessiz saatler, veri kaynağı durumu, sürüm ve değişiklik günlüğü).

3D halka: `CustomPainter` ile sahte 3D (eliptik üst yüz + yan duvar, boyacı sıralaması); sürüklenince döner,
dilime dokununca varlık detayı açılır. Sürekli dönen animasyon yok. "Animasyonları azalt" veya pil tasarrufu
açıksa düz 2D ve anlık geçiş. Web çıktısıyla tarayıcıda görsel kontrol, sonra telefonda.

### Faz 6 — Kendini geliştirme

Sinyal günlüğünden strateji bazında istatistik (isabet, ortalama R, Wilson güven aralığı). Sürümlü strateji
yapılandırması (her sürüm saklanır, geri alınabilir). 30 sinyal altında değişiklik uygulanmaz, yalnızca
gözlem yazılır. Her değişiklik uygulama içi değişiklik günlüğüne ve `docs/degisiklik-gunlugu.md`'ye düşer.
Değerlendirme yalnızca ileriye dönük kayıtla yapılır (kısıt 2).

### Faz 7 — Yayına hazırlık

Gizlilik metni, uyarı metinleri, çok kullanıcı denetimi (gömülü kişisel ayar yok), Play beyan listesi
(finansal özellikler, ön plan servisi türü). Açık kısıtları yazılı bırak (bölüm 7).

---

## 6. Görsel stil "GÜNDÜZ" (sabit)

- Zemin `#F6F4EF`, kartlar `#FFFFFF`, metin `#1B1B1B`, ikincil metin sakin gri.
- Vurgu mor/indigo `#5B4BDB` (koyu `#3B2FA8`); ikincil vurgu mercan `#D85A30`; nötr gri.
  Kazanç/zarar renkleri sade; her zaman işaret ve metinle birlikte.
- Köşe 12–16 px, bol boşluk, düz yüzeyler, ince çizgiler.
- Alt gezinme: Özet · Öneri · Sinyal · Ayar.
- Açık tema varsayılan ve öncelikli; koyu tema da desteklenir.
- Sistem yazı tipi; çalışma anında font indirilmez.

---

## 7. Kullanıcıya açıkça söylenmiş, çözülmemiş kısıtlar

- **Veri lisansı:** Yahoo koşulları ticari kullanımı yasaklar; BIST verisini üçüncü kişilere sunmak Borsa
  İstanbul lisansına tabidir. Kişisel kullanım sorunsuz; mağazada çok kullanıcıya açılırken ücretsiz ve
  lisansı temiz bir BIST fiyat kaynağı bulunamadı. "Sıfır para" ile yayın hedefi burada çatışıyor.
- **Hukuk:** Türkiye'de başkalarına al/sat önerisi yayımlamak SPK düzenlemelerine tabi olabilir; yayından
  önce uzman görüşü gerekir.
- **Ücretler:** Google Play geliştirici hesabı tek seferlik, Apple hesabı yıllık ücretlidir. Yayın anında sorulacak.
- **iOS:** sunucusuz sürekli sinyal mümkün değil; yalnızca haftalık rapor + uygulama açıkken yenileme.
- **Arka plan gerçeği:** sinyal gecikmesi tipik 0–15 dk, kötü durumda 1 saate kadar. Telefonda ölçülmedi.

---

## 8. Sık kullanılan komutlar

```powershell
. .\araclar\ortam.ps1                      # ortamı aç (her terminalde)
cd pusula_core; dart pub get; dart analyze; dart test
dart run tool/smoke.dart --all             # canlı duman testi (ağ gerekir)
cd ..; python -m unittest discover -s tests   # Python referans testleri
adb devices                                # telefon bağlı mı
flutter doctor
```
