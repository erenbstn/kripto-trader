# Değişiklik Günlüğü

Uygulama ve strateji sürümleri burada tutulur. Her kayıt: ne değişti, neden, nasıl geri alınır.

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
