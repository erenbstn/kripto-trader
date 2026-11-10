# Değişiklik Günlüğü

Uygulama ve strateji sürümleri burada tutulur. Her kayıt: ne değişti, neden, nasıl geri alınır.

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

**Geri alma:** depo git altında olmadığı için otomatik geri alma yok. Silinen dosyalar bilinçli olarak
kurtarılamaz bırakıldı (sır içeriyorlardı).

**Strateji:** değişmedi (1.0 kuralları). Strateji 2.0.0 değişiklikleri `kararlar.md` K7'de planlı.
