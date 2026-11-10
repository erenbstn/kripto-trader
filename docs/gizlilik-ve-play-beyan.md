# Gizlilik Metni, Yasal Uyarılar ve Google Play Beyan Kontrol Listesi — Pusula

Son güncelleme: 2026-11-10 (Faz 7)

> **Yatırım tavsiyesi değildir.** Pusula bir aracı kurum veya portföy yönetim şirketi değildir;
> gerçek emir iletmez, borsa veya aracı kurum API anahtarı istemez ve kullanmaz.

---

## 1. Gizlilik Metni (Kullanıcı Aydınlatma Özeti)

### 1.1 Uygulamanın Bağlandığı Açık Ağ Uçları
Pusula, yalnızca herkese açık ve kimlik doğrulaması gerektirmeyen piyasa verisi uçlarına doğrudan kullanıcının cihazından (`HTTPS GET`) bağlanır:
1. **Binance Açık Piyasa Verisi (`data-api.binance.vision`, `api.binance.com`, `fapi.binance.com`):** Kripto varlıkların (`BTCUSDT`, `SOLUSDT` vb. sabit 10 varlık) kapanmış mum (OHLCV) ve fonlama oranı verileri.
2. **Yahoo Finance (`query1.finance.yahoo.com`):** Borsa İstanbul (`.IS` uzantılı paylar ve `XU100.IS`) yaklaşık 15 dakika gecikmeli mum verileri ve kripto (`-USD`) yedek mum verileri.
3. **İş Yatırım (`www.isyatirim.com.tr`):** Borsa İstanbul payları için gün sonu yedek kapanış ve hacim verileri.

Hiçbir merkezi "Pusula sunucusu", bulut veritabanı, telemetri/analitik servisi veya üçüncü taraf mesajlaşma servisi (Telegram vb.) **yoktur**.

### 1.2 Cihazda Yerel Olarak Saklanan Veriler
Tüm veriler yalnızca kullanıcının telefonundaki yerel SQLite veritabanında (`pusula_local.db`) tutulur:
- Kapanmış mum önbelleği (`candle_cache`)
- İleriye dönük üretilen sinyallerin günlüğü ve gerçekleşen sonuçları (`signal_journal`)
- Pazar günleri üretilen haftalık rapor arşivi (`weekly_reports`)
- Kullanıcının girdiği referans bütçe tutarı, risk iştahı, bildirim ve görünüm tercihleri (`app_settings`)

Kullanıcı dilediği zaman verilerini JSON biçiminde dışa aktarabilir, içe aktarabilir veya uygulama verilerini tamamen silebilir.

### 1.3 Asla Toplanmayan ve İşlenmeyen Veriler
- Ad, e-posta, telefon numarası, T.C. kimlik numarası veya hesap bilgisi **toplanmaz**.
- Borsa, banka veya aracı kurum API anahtarı/şifresi **istenmez ve saklanmaz**.
- Reklam kimliği (Advertising ID), konum, rehber veya kullanım analitiği **toplanmaz**.
- Kullanıcının referans bütçe tutarı loglara veya dış ağ isteklerine **asla yazılmaz**.

---

## 2. Yasal Uyarılar, Veri Lisansı ve Güvenlik Hatırlatması

1. **Yatırım Tavsiyesi Değildir:** Uygulamadaki tüm kurulumlar, güven skorları, Monte Carlo olasılık aralıkları ve haftalık bütçe ağırlıkları matematiksel/teknik kuralların otomatik çıktısıdır; Sermaye Piyasası Kurulu (SPK) mevzuatı kapsamında "yatırım danışmanlığı" teşkil etmez.
2. **Hukuki Uyarı (SPK Düzenlemeleri):** Türkiye'de genel kamuya veya üçüncü kişilere yönelik al/sat önerisi yayımlamak SPK düzenlemelerine tabi olabilir. Uygulamayı kişisel kullanım dışına (mağazada çok kullanıcıya) açmadan önce mutlaka yetkili bir hukukçudan/uzmandan görüş alınmalıdır.
3. **Veri Gecikmesi ve Lisans Sınırları:**
   - Borsa İstanbul verileri ücretsiz kaynaklardan yaklaşık **15 dakika gecikmeli** alınır. Gecikmeli veri, seans açılış boşlukları ve ±%10 günlük fiyat marjı nedeniyle stop veya giriş seviyelerinde kayma (slippage) oluşabilir.
   - Yahoo Finance kullanım koşulları yalnızca kişisel, ticari olmayan kullanıma izin verir; verinin üçüncü kişilere yeniden dağıtımı (redistribution) yasaktır. Çok kullanıcılı ticari yayında Borsa İstanbul ve veri sağlayıcı lisans sözleşmeleri gereklidir.
4. **Güvenlik Hatırlatması (BotFather):** Faz 0 öncesinde eski Python yapılandırmasında düz metin olarak bulunmuş olan Telegram bot token'ı koddan ve geçmiş araçlardan tamamen silinmiştir; ancak token geçmişte ifşa olduğu için Telegram'da `@BotFather` üzerinden `/revoke` komutuyla iptal edilmesi zorunludur.

---

## 3. Çok Kullanıcı Denetimi (Faz 7.3)

| Denetim Kalemi | Durum | Açıklama |
|---|---|---|
| Kodda sabit kişisel dosya yolu (`C:\Users\...`) | **Temiz** | `pusula_core` ve `pusula_app/lib` içinde hiçbir kişisel dosya yolu yoktur; veritabanı yolu çalışma anında `getDatabasesPath()` ile çözülür. |
| Gömülü API anahtarı / token / `.env` okuyucu | **Temiz** | Hiçbir anahtar veya `.env` okuyucu yoktur. |
| Kullanıcıya özel sabit bütçe / portföy | **Temiz** | Bütçe ve risk iştahı `AppSettings` içinde kullanıcı tarafından değiştirilebilir; her kurulum kendi yerel SQLite veritabanıyla başlar. |
| Yedekleme ve sıfırlama | **Hazır** | `StorageBundle.exportToJson()` ve `importFromJson()` ile cihazlar arası taşınabilir. |

---

## 4. Google Play Beyan Kontrol Listesi (Faz 7.4)

> **Not:** Google Play Console geliştirici hesabı açmak tek seferlik ücrete (25 USD) tabidir. "Sıfır para" kısıtı gereği bu adım kullanıcı onayı olmadan gerçekleştirilmez; aşağıdaki liste mağaza başvurusunda doldurulacak resmî beyan özetidir.

| Beyan Başlığı | Seçilecek / Beyan Edilecek Durum | Gerekçe ve Teknik Karşılık |
|---|---|---|
| **Finansal Özellikler Beyanı (Financial Features Declaration)** | "Uygulamam doğrudan finansal işlem, bankacılık, kredi veya kripto para cüzdanı/borsası hizmeti **sunmuyor**; yalnızca piyasa verisi ve teknik analiz bilgisi sağlar." | Uygulama emir açmaz, para transferi yapmaz, cüzdan veya aracı kurum bağlantısı içermez. |
| **Veri Güvenliği Formu (Data Safety)** | "Toplanan veri: **Yok** · Üçüncü taraflarla paylaşılan veri: **Yok**" | Tüm ayarlar ve sinyal günlüğü yalnızca cihaz içinde (`sqflite`) saklanır; uzak sunucu veya analitik SDK'sı yoktur. |
| **Ön Plan Servisi Türü (`FOREGROUND_SERVICE_DATA_SYNC`)** | Tür: `dataSync` (`PusulaLiveMonitorService`) | Yalnızca kullanıcı Ayarlar ekranından "Canlı İzleme" anahtarını elle açtığında başlar; kalıcı bildirim gösterir; kullanıcı kapattığında veya Android 15 6 saatlik sınırında durur. |
| **Kesin Alarm İzni (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`)** | Pazar 09:00 TRT haftalık rapor ve BIST seans açılış/kapanış bildirimleri | `AlarmManager.canScheduleExactAlarms()` kontrol edilir; izin yoksa güvenli `setAndAllowWhileIdle` yedeğine düşer. |
| **Hedef SDK (`targetSdk` / `compileSdk`)** | `36` (Android 16 / API 36 uyumlu) | `pusula_app/android/app/build.gradle.kts` içinde `compileSdk = 36`, `targetSdk = 36`, `minSdk = 24`. |
| **Yeni Kişisel Geliştirici Hesabı Test Şartı** | En az 12 test kullanıcısıyla 14 gün kapalı test | Google Play'in Kasım 2023 sonrası açılan kişisel geliştirici hesapları için zorunlu tuttuğu kapalı test aşaması. |
