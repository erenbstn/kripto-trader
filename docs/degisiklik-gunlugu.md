# Değişiklik Günlüğü

Uygulama ve strateji sürümleri burada tutulur. Her kayıt: ne değişti, neden, nasıl geri alınır.

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
