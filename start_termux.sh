#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Kripto Multi-Agent Day Trader - Android Termux Başlatıcı
# Arka planda 7/24 kesintisiz çalışması için WakeLock + nohup
# ============================================================

cd "$(dirname "$0")" || exit 1

echo "============================================================"
echo "  KRIPTO MULTI-AGENT DAY TRADER (TERMUX 7/24 MODU)"
echo "============================================================"

# Python kontrolü
if ! command -v python &> /dev/null; then
    echo "[*] Python bulunamadı, kuruluyor..."
    pkg update -y && pkg install -y python termux-api
fi

# Telefon uyku moduna geçse bile CPU'nun durmaması için WakeLock al
if command -v termux-wake-lock &> /dev/null; then
    termux-wake-lock
    echo "[+] Termux Wake-Lock aktif edildi (Ekran kapansa da çalışır)."
else
    echo "[!] Uyarı: termux-wake-lock bulunamadı. 'pkg install termux-api' önerilir."
fi

mkdir -p data

if [ "$1" == "--bg" ] || [ "$1" == "-b" ]; then
    echo "[+] Sistem arka planda (nohup) başlatılıyor..."
    nohup python main.py run > data/termux_nohup.log 2>&1 &
    PID=$!
    echo "$PID" > data/trader.pid
    echo "[+] Başlatıldı! PID: $PID"
    echo "[i] Logları canlı izlemek için: tail -f data/trader.log"
    echo "[i] Durdurmak için: kill \$(cat data/trader.pid)"
else
    echo "[+] Sistem ön planda başlatılıyor (Arka plan için: ./start_termux.sh --bg)..."
    python main.py run
fi

