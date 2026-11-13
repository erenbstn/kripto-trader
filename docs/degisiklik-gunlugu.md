# Değişiklik Günlüğü

Uygulama ve strateji sürümleri burada tutulur. Her kayıt: ne değişti, neden, nasıl geri alınır.

## pusula_app 1.1.1 — 2026-11-14 (GitHub Releases Uygulama İçi APK Güncelleyici ve Otomatik Derleme)

**Eklendi ve Güncellendi** (`pusula_app/lib/src/update/`, `.github/workflows/release-apk.yml`, `araclar/keystore-olustur.ps1`, `araclar/surum-yayinla.ps1`)
- **Uygulama İçi Güncelleyici (`AppUpdateService`, `AppVersion`, `AppUpdateState`):** GitHub Releases (`releases/latest`) üzerinden yeni `versionCode` / SemVer kontrolü yapar, yalnızca güvenilir HTTPS GitHub bağlantılarından (`.apk`) indirir ve Android `FileProvider` + `REQUEST_INSTALL_PACKAGES` kanalı (`app.pusula/update`) ile verileri koruyarak sistem kurulum ekranını açar.
- **Arayüz Entegrasyonu (`OzetScreen`, `AyarScreen`, `AppSettings`):** GitHub deposu (`kullanici/depo`) ayarı, açılışta sessiz kontrol anahtarı, ilerleme çubuklu indirme kartı ve ana sayfada güncelleme uyarısı eklendi (`app_updater_test.dart` birim testleri dahil).
- **Sabit Release İmzalama ve CI/CD:** `build.gradle.kts` `key.properties` desteğine kavuşturuldu; `araclar/keystore-olustur.ps1`, `araclar/surum-yayinla.ps1` ve `.github/workflows/release-apk.yml` (etiket itildiğinde testi geçirip release APK yayınlayan GitHub Actions akışı) eklendi.

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_app 1.1.0 & pusula_core 0.5.0 — 2026-11-13 (K9 Analiz Motoru İyileştirmeleri ve K10 Mobil/Web Arayüz Yenilemesi)

**Eklendi ve Güncellendi** (`pusula_core/lib/src/analysis/`, `pusula_app/lib/`)
- **Analiz Motoru İyileştirmeleri (`K9`, Strateji `v2.1.0`):**
  - `TradingCosts` (`trading_costs.dart`): kripto (%0,20) ve BIST (%0,30) gidiş-dönüş işlem maliyeti tahminleriyle net Ö/R hesabı ve maliyet/risk oranı süzgeci eklendi.
  - `SignalEngine` (`signal_engine.dart`) ve `ConfidenceScorer` (`confidence_score.dart`): veri tazeliği süzgeci (`maxSignalBarAge`), kovalama (`> 1.5 ATR`), kırılım fitil reddi ve düşük hacim süzgeçleri (`FunnelStage.quality`), rejime duyarlı güven eşiği (Boğa 50, Yatay 54, Ayı 58) ve kalite düzeltmesi eklendi.
  - `MarketScanner` (`market_scanner.dart`) & `ScanRunner` (`scan_runner.dart`): tüm BIST + sabit 10 kripto evrenini tarayan, stop sonrası 6 mum soğuma ve piyasa başına açık sinyal sınırı (Kripto 4, BIST 5) uygulayan, elenen adayları aşama ve gerekçesiyle (`ScanOutcome.nearMisses`) döndüren tarama hunisi eklendi. Birim testleri (`pusula_core/test/market_scanner_test.dart`) eklendi.
- **Gerçek Uygulama Canlı Kipli Başlangıç (`main.dart`, `pusula_controller.dart`):**
  - `demoSeedProvider` testlerde ve önizlemede varsayılan `true` bırakılırken gerçek uygulamada (`main.dart`) `false` yapıldı; örnek sinyaller asla gerçek öneri olarak gösterilmez, eşiği geçen fırsat yoksa portföy dürüstçe %100 nakit görünür.
- **Mobil & Web Tasarım Yenilemesi (`K10`):**
  - `gunduz_theme.dart` & `widgets/common.dart`: `PusulaPalette` (açık GÜNDÜZ + koyu tema), `PusulaSpace` (`wideBreakpoint = 900`, `maxContentWidth = 1240`), duyarlı iki sütunlu `PageBody`, `ConfidenceRing`, `PriceLadder`, `ConfidenceBars`, `EmptyNote`, `CardHeader` eklendi.
  - `signal_card.dart`, `recommendation_card.dart`, `ozet_screen.dart`, `oneri_screen.dart`, `sinyal_screen.dart`, `ayar_screen.dart`: yeni kart hiyerarşisi, karar kartı, tarama hunisi özeti, elenen adaylar kartı ve `PageBody` yerleşimi uygulandı.
  - `main.dart`: Web/geniş ekranlarda (`>= 900 px`) sol `NavigationRail`, dar/mobil ekranlarda alt `NavigationBar` ve `AppBar` tarama ilerleme çubuğu eklendi.

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_app 1.0.1 & pusula_core 0.4.1 — 2026-11-10 (Canlı Fiyat Bağlantısı ve İş Yatırım Sıralama Düzeltmesi)

**Düzeltildi ve Eklendi** (`pusula_app/lib/src/state/pusula_controller.dart`, `pusula_core/lib/src/data/isyatirim_provider.dart`, `araclar/cors_proxy.dart`)
- **Canlı Piyasa Fiyatları (`refreshLiveMarketData`):** `PusulaController` içine gerçek zamanlı `MarketDataService` (`BinanceProvider`, `YahooProvider`, `IsYatirimProvider`) bağlantısı eklendi. Uygulama açılışında ve üst çubuktaki yenile (`Icons.sync`) düğmesiyle tüm 10 kripto varlığın (Binance Spot/Futures) ve BIST izleme listesinin (Yahoo Finance `.IS` / İş Yatırım) canlı fiyatları çekilerek hem **Canlı Piyasa Fiyatları** kartı hem de aktif sinyal giriş/stop/hedef seviyeleri gerçek piyasa verisiyle güncellenir.
- **Eski Sabit Tohum Fiyatlarının Temizlenmesi:** İlk sürümde yer alan sabit örnek fiyatlar (`BTC 86.400`, `SOL 148,80`, `ASELS 92,75`, `AKBNK 64,25`) kaldırıldı; gerçek güncel seviyelerle (`BTC ~73.506 $`, `SOL ~82,90 $`, `LINK ~10,30 $`, `THYAO 313,75 TL`, `ASELS 337,00 TL`, `AKBNK 70,70 TL`, `XU100 11.661,86`) kalibre edildi ve SQLite'taki eski tohum kayıtlarının otomatik temizlenmesi sağlandı.
- **İş Yatırım Kronolojik Sıralama Düzeltmesi (`IsYatirimProvider`):** İş Yatırım `HisseTekil` uç noktasının satırları karışık tarih sırasıyla döndürmesi nedeniyle son kapanış fiyatının eski bir tarihten okunması hatası, satırlar `openTime` alanına göre kronolojik sıralanarak giderildi (birim testi eklendi, toplam 67 çekirdek testi).
- **PC (Chrome / Web) CORS Köprüsü (`araclar/cors_proxy.dart`):** Bilgisayarda Chrome üzerinden çalıştırıldığında Yahoo Finance ve İş Yatırım isteklerinin tarayıcı CORS engeline takılmaması için `araclar/ortam.ps1` içine `127.0.0.1:8787` üzerinde çalışan yerel salt-okunur köprü eklendi.

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_app 1.0.0 — 2026-11-10 (Faz 7 — Yayına Hazırlık)

**Eklendi** (`docs/gizlilik-ve-play-beyan.md` ve `pusula_app/lib/src/screens/ayar_screen.dart`)
- Gizlilik metni (bağlanılan açık uçlar, yerel SQLite'ta tutulan veriler, asla toplanmayan veriler).
- Yasal uyarılar, BIST/Yahoo veri lisans ve gecikme sınırları, SPK düzenlemeleri notu ve eski Telegram bot token'ını `@BotFather` üzerinden iptal etme hatırlatması.
- Çok kullanıcı denetimi ve ayarları varsayılana sıfırlama (`resetSettingsToDefault`).
- Google Play Console beyan kontrol listesi (Finansal Özellikler Beyanı, Veri Güvenliği Formu, Ön Plan Servisi `dataSync`, Hedef SDK 36).

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_core 0.4.0 & pusula_app 0.3.0 — 2026-11-10 (Faz 6)

**Eklendi** (`pusula_core/lib/src/learning/` ve `pusula_app/lib/src/screens/ayar_screen.dart`)
- `StrategyOptimizer`, `WilsonInterval`, `StrategyPerformanceStats`: sinyal günlüğündeki kapanmış sinyallerden strateji ve rejim bazında kazanma oranı, ortalama R ve Wilson %95 güven aralığı hesabı.
- `StrategyVersionRecord`, `StrategyVersionStore`, `MemoryStrategyVersionStore`: sürümlü strateji parametreleri (`minConfidenceScore`, `minVolumeRatio`, `atrStopMultiplier`, `enabledInSideways`) ve `rollbackToPrevious()` ile tek dokunuşla önceki sürüme geri alma.
- **30 sinyal aşırı uyum yasağı (Kısıt 9):** strateji başına en az 30 kapanmış sinyal birikmeden hiçbir parametre değişmez; 30'un altında yalnızca gözlem metni ve Wilson %95 güven aralığı üretilir.

**Geri alma:** Uygulama içinden `rollbackToPrevious()` veya `git revert` ile önceki commit'e dönülebilir.

## pusula_app 0.2.0 — 2026-11-10 (Faz 5)

**Eklendi** (`pusula_app/lib/src/`)
- `GunduzTheme` ve `GunduzColors` (`theme/gunduz_theme.dart`): `#F6F4EF` zemin, `#FFFFFF` kartlar, `#1B1B1B` metin, `#5B4BDB` / `#3B2FA8` vurgu, `#D85A30` mercan ikincil vurgu, 14 px köşe, ince çizgili kartlar, açık (varsayılan) ve koyu tema, `DisclaimerBanner`, `DataProvenanceBadge` ve `+`/`-` işaretli `SignedMetricChip`.
- `Donut3DChart` ve `Donut3DPainter` (`widgets/donut_3d_chart.dart`): derinlik sıralamalı (Painter's Algorithm) eliptik 3D bütçe ağırlık halkası, sürükleyerek döndürme, dilime dokununca varlık detay penceresi, pil tasarrufu / animasyon azaltmada düz 2D sade mod.
- 4 alt gezinme ekranı (`screens/`):
  - `OzetScreen`: haftalık özet, 3D halka, açık sinyaller, son yerel bildirimler.
  - `OneriScreen`: önce geçen hafta sonucu (`"Geçen hafta raporu: henüz veri yok"`), sonra BIST ve Kripto yeni öneri kartları (`RecommendationDetailCard`), ayrıca Geçmiş arşivi ve ileriye dönük performans eğrisi.
  - `SinyalScreen`: Kripto ve BIST ayrı kısa vade haftalık raporları + canlı sinyal akışı.
  - `AyarScreen`: bütçe, risk iştahı, tema/animasyon/pil tasarrufu, bildirim kanalları, sessiz saatler, OEM pil muafiyet rehberi, `ProviderHealth` durumu.

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_app 0.1.0 — 2026-11-10 (Faz 4)

**Eklendi** (`pusula_app/`)
- Flutter Android + Web projesi (`app.pusula.pusula_app`), `pusula_core` yerel paket bağlantısı, `flutter_riverpod`, `sqflite`.
- `StorageBundle` (`lib/src/storage/`): `SqliteCandleCache`, `SqliteSignalJournalStore`, `SqliteWeeklyReportStore`, `SqliteSettingsStore` ve JSON dışa/içe aktarım (`exportToJson` / `importFromJson`). Web ve test ortamında otomatik bellek içi (`inMemory`) yedekleme.
- `NotificationCoordinator` ve `NotificationFormatter` (`lib/src/notifications/`): 4 kanal (`Sinyal`, `Sonuç`, `Rapor`, `Sistem`), yerel Android `NotificationManager` köprüsü, Türkçe virgüllü bildirim biçimlendiricileri, aynı sembol için 10 dk birleştirme, sessiz saat kuyruğu + sabah tek özet bildirimi, günlük üst sınır ve tekrar anahtarı (`dedupKey`).
- `BackgroundScheduler` (`lib/src/background/`) ve yerel Kotlin servisleri (`MainActivity.kt`): WorkManager 15 dk periyodik tarama, Pazar 09:00 TRT ve BIST açılış/kapanış kesin alarmları (`AlarmManager`), isteğe bağlı "Canlı İzleme" ön plan servisi (`PusulaLiveMonitorService`, `dataSync`) ve üretici (Samsung/Xiaomi/Oppo/Pixel) pil optimizasyonu muafiyet rehberi.

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_core 0.3.0 — 2026-11-10 (Faz 3)

**Eklendi** (`pusula_core/lib/src/report/`)
- `PortfolioWeightAllocator` ve `RiskAppetite` (Temkinli 0,6×, Dengeli 1,0×, Atak 1,4×): eşit risk bütçesinden (%0,5–%1,5) ağırlık türetme; tek varlık (%20), kripto toplamı (%40), toplam açık risk (%6) ve en az nakit (%20) sınırlarıyla orantılı küçültme; eşik üstü fırsat yoksa `%100 nakit` ("Bu hafta net fırsat yok, nakitte kal").
- `WeeklyReportGenerator`, `WeeklyReport`, `LastWeekReview`, `ShortTermWeeklyReport`: Pazar günü sırasıyla (1) geçen hafta raporu (kayıt yoksa "Geçen hafta raporu: henüz veri yok"), (2) kısa vade haftalık raporu (BIST ve Kripto ayrı, strateji kırılımlı), (3) yeni haftanın önerileri (BIST ve Kripto ayrı).
- `WeeklyReportStore` ve `MemoryWeeklyReportStore`: haftalık rapor arşivi ve yalnızca ileriye dönük gerçekleşen sonuçlardan oluşan 100 bazlı performans eğrisi (`PerformanceCurvePoint`).

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_core 0.2.0 — 2026-11-10 (Faz 2, Strateji 2.0.0)

**Eklendi** (`pusula_core/lib/src/analysis/` ve `lib/src/journal/`)
- `Indicators`: Wilder RSI, ATR (Python referans motoruyla birebir uyumlu), SMA, EMA, VWAP, ADX ve gerçekleşen oynaklık.
- `RegimeDetector`: BTCUSDT ve XU100 için EMA50/200 eğimi + ADX + oynaklık ile Boğa / Yatay / Ayı rejim tespiti; Ayı rejiminde kırılım kurulumlarını devre dışı bırakma ve risk çarpanını 0,5×'e düşürme.
- `SetupScanner`: 6 kurulum (`orb`, `breakout_20d`, `bull_flag`, `reclaim_ma20`, `oversold_bounce`, `vwap_breakout`); BIST'te 5 dk scalp engeli ve fiyat adımına yuvarlanmış giriş bölgesi.
- `MultiTimeframeAnalyzer`: sinyal dilimi + bir üst zaman dilimi trend teyidi.
- `ExitPlanner`: yapı/ATR tabanlı stop, kademeli hedefler (`1R` ve `2R`), başabaş tetikleyici, süre sınırı, geçersiz kılma koşulu ve BIST tavan/taban yakınlık uyarısı.
- `MonteCarloSimulator`: blok önyükleme (`blockSize = 4`), %95 güven aralığı, sabitlenebilir tohum. `replay_historical_sessions` taşınmadı.
- `NewsAnalyzer` ve `WhaleAnalyzer`: yanlış pozitif üreten genel takma adlar (`link`, `sol`, `gold`, `eth`, `default`) daraltıldı; emir defteri dengesi vetodan çıkarılıp bilgi alanına alındı; vadeli fonlama vetosu korundu.
- `ConfidenceScorer` ve `SignalEngine`: 6 bileşenli 0–100 güven skoru ve uçtan uca sinyal değerlendirme hunisi.
- `SignalJournalStore` ve `SignalOutcomeTracker`: kalıcı sinyal kaydı ve `açık → hedef1 → hedef2 | stop | süre doldu | geçersiz` yaşam döngüsü (aynı mumda stop öncelikli).

**Geri alma:** `git revert` ile önceki commit'e dönülebilir.

## pusula_core 0.1.0 — 2026-11-10 (Faz 1)

**Eklendi** (saf Dart paketi, `pusula_core/`)
- Veri katmanı: `MarketDataProvider` soyutlaması; Binance (spot + futures), Yahoo (`.IS` ve `-USD`),
  İş Yatırım (BIST günlük, yedek) sağlayıcıları.
- `MarketDataService`: sıralı yedekleme, önbellek (tazelik = dilimin 1/3'ü, 30 sn–30 dk), eski veriyi
  "bayat" işaretiyle döndürme, sağlayıcı sağlık kaydı.
- `RateLimiter`: istekler arası en az aralık; 429 veya üç ardışık hatada üstel soğuma (30 sn → 15 dk).
- BIST takvimi (2026 resmî, 2027 öngörü), seans aşamaları, yarım günler; fiyat adımı, ±%10 marj, lot.
- BIST evreni: 75 aday + likidite süzgeci; sabit 10'luk kripto evreni.
- 40 birim testi (ağsız, sahte HTTP) ve elle çalıştırılan canlı duman testi (`tool/smoke.dart`).

**Strateji:** henüz yok (Faz 2).

**Geri alma:** `git revert`; paket bağımsızdır, Python motorunu etkilemez.

## 1.1.0 — 2026-11-10 (Python referans motoru, Faz 0)

**Kaldırıldı**
- Telegram tamamen: `agents/telegram_agent.py`, `main.py` içindeki bot komutları ve gönderimler,
  `config.json` içindeki `telegram` bloğu (bot token dahil), `.env.example`, README bölümleri.
- `termux_tek_tik_kurulum.py`: içinde `config.json` (token dahil) base64 olarak gömülüydü.
- `paketle_termux.py`: `.env` dosyasını pakete gömen araç.
- `main.py` içindeki `.env` okuyucu (`load_dotenv`). Motor artık hiçbir sır dosyası okumaz.

**Eklendi**
- `agents/notifier.py`: yalnızca yerel bildirim (konsol + `data/notifications.jsonl`). Ağ isteği yok.
- `config.json` → `notifications` bloğu (yalnızca aç/kapa tercihleri, sır yok).
- `.gitignore`, `docs/kararlar.md`, `docs/plan.md`.

**Neden:** kullanıcı kısıtı (Telegram iptal, ifşa olan token) ve "sır düz metinde durmaz" kuralı.

**Geri alma:** bu değişiklik git'in ilk commit'idir; öncesi kayıtlı değildir. Silinen dosyalar bilinçli
olarak kurtarılamaz bırakıldı (sır içeriyorlardı).

**Strateji:** değişmedi (1.0 kuralları). Strateji 2.0.0 değişiklikleri `kararlar.md` K7'de planlı.
