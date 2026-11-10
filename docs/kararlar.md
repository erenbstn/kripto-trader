# Karar Kaydı — Pusula (çalışma adı)

Son güncelleme: 2026-11-10 · Durum: Faz 0–4 tamamlandı.

Bu dosya mimari, teknoloji ve analiz kararlarını gerekçeleriyle tutar. Her karar geri alınabilir;
değişirse eskisi silinmez, "değişti" notuyla kalır.

> Bu belge ve uygulamanın ürettiği hiçbir şey yatırım tavsiyesi değildir.

---

## 0. Mevcut proje özeti (okuma sonucu)

1. `kripto-trader`: sıfır bağımlılıklı Python 3; `main.py` içindeki `MultiAgentOrchestrator` 11 ajanı sırayla çağırır.
2. Akış: Scanner → News → Whale → Entry → Exit → TimeMachine → Budget → Risk → Paper Broker → Alerts → (eskiden Telegram).
3. Veri: Binance açık uçları (spot, olmazsa futures), yedek Yahoo `-USD`. Anahtar yok.
4. Scanner 5 dk mumda 6 kurulum arar (ORB, 20-bar kırılım, boğa bayrağı, MA20 geri kazanım, RSI tepkisi, VWAP kırılımı).
5. Entry yalnızca kapanmış mumla tetiklenir; Exit OR-orta/OR-dip/ATR stop + 2R hedef + 1R'de başabaş üretir.
6. TimeMachine geçmiş mum oranlarından 10.000 Monte Carlo yolu üretir ve beklenen R düşükse veto eder.
7. Budget + Risk: 500 $ sanal kasa, işlem başı 50 $ risk, 16 kural; Broker sanal pozisyon açar, Alerts stop/hedef/süre izler.
8. Yalnızca long; 10 varlıklık sabit beyaz liste; 60 sn tarama, 15 sn izleme döngüsü.
9. Testler: 8 birim/entegrasyon testi, sentetik mumlarla (hepsi geçiyor).
10. BIST, haftalık öneri, sinyal günlüğü, rapor, mobil arayüz yok.

### Bulunan riskler ve eksikler

| # | Bulgu | Etki | Ne yapıldı / yapılacak |
|---|---|---|---|
| R1 | Bot token'ı `config.json` içinde düz metindi; ayrıca `termux_tek_tik_kurulum.py` içinde base64 olarak gömülüydü | Sır ifşası | İkisi de silindi (Faz 0). Token'ı BotFather'dan iptal etmek kullanıcıda. |
| R2 | `paketle_termux.py` varsa `.env` dosyasını da pakete gömüyordu | Sır sızıntı yolu | Dosya silindi. |
| R3 | Haber eşleşmesi çok genel takma adlar kullanıyor (`link`, `sol`, `gold`, `eth`, `default`) | Yanlış veto / yanlış pozitif | Faz 2'de varlık adı + bağlam eşleşmesine çevrilecek. |
| R4 | TimeMachine havuzu mumları `i % seans` ile dilimliyor; dilimin gerçek saatle ilgisi yok | Olasılıklar sahte kesinlik taşıyor | Faz 2: blok önyükleme (block bootstrap) + güven aralığı. |
| R5 | `replay_historical_sessions` geçmiş seanslarda kural testi yapıyor | "Geçmiş veriyle backtest yok" kısıtıyla çelişir | Yeni motora taşınmayacak (bkz. K7). |
| R6 | 20 seviyelik emir defteri dengesi veto girdisi | Gürültü, kolay manipüle edilir | Karar ağırlığından çıkarılıp bilgi alanına indirilecek. |
| R7 | Piyasa rejimi yok; her koşulda aynı kırılım kuralları | Yatay/düşen piyasada sahte kırılım | Faz 2: rejim tespiti. |
| R8 | `main.py` tek dosyada orkestrasyon + sunum | Mobilde yeniden kullanılamaz | Yeni motor katmanlı paket olarak yazılacak. |
| R9 | Git deposu yok | Değişiklik geri alınamıyor | `.gitignore` eklendi; `git init` önerilir (kullanıcı kararı). |
| R10 | Sinyal sonucu kalıcı günlükte izlenmiyor (yalnızca sanal kasa) | Haftalık rapor ve kendini geliştirme için veri yok | Faz 2: sinyal günlüğü. |

---

## K1. Mimari: Flutter + analiz motoru Dart'ta, uygulamanın içinde (seçenek A)

| Ölçüt | A) Flutter, motor Dart'ta | B) Python gömme (Chaquopy) + Kotlin arayüz | C) Termux + yerel API |
|---|---|---|---|
| Mevcut kodu yeniden kullanma | Yok, yeniden yazılır (~2.800 satır) | Yüksek | Tam |
| Tek kurulum (APK) | Evet | Evet | Hayır: Termux + betik + uygulama |
| Arka plan | WorkManager + alarm + isteğe bağlı ön plan servisi | Aynı Android kısıtları, Python başlatma maliyeti ek | Termux wake-lock; pil dostu değil, OEM'ler öldürür |
| Google Play | Uygun | Uygun (Chaquopy açık kaynak), APK +25–40 MB | Uygun değil (Termux bağımlılığı mağazada yayınlanamaz) |
| iOS ihtimali | Var (tek kod tabanı) | Yok | Yok |
| Çok kullanıcı | Doğal: her kurulum kendi verisi | Doğal | Pratikte imkânsız |
| Test | `dart test`, cihazsız | pytest + enstrümantasyon | pytest |
| Bedel | Yeniden yazım emeği | İki dil, iki hata ayıklama dünyası | Yayın yolu kapalı |

**Karar: A.** Gerekçe: mağaza + iOS + çok kullanıcı hedefini tek kod tabanıyla yalnızca A karşılıyor.
Motor zaten kökten değişiyor (BIST, haftalık öneri, sinyal günlüğü, sanal kasa yerine sinyal takibi);
"yeniden kullanım" avantajı bu yüzden küçük. Python motoru referans olarak kalır, ürün değildir.

**Yapı:** iki paket.
- `pusula_core/` — saf Dart (Flutter'a bağımlı değil): veri sağlayıcılar, göstergeler, stratejiler, rejim,
  sinyal günlüğü, haftalık rapor, ağırlıklandırma. Cihazsız `dart test` ile sınanır, arka plan izolatında çalışır.
- `pusula_app/` — Flutter: ekranlar, 3D halka, bildirimler, arka plan zamanlama, kalıcı depolama.

**Durum yönetimi:** Riverpod (derleme zamanı güvenli, izolat/arka plan ile uyumlu, test edilebilir).
**Depolama:** SQLite (`sqflite`); motor yalnızca soyut depo arayüzü görür, testte bellek içi depo kullanılır.

### Arka planda "sürekli çalışma" — dürüst değerlendirme

Android'de sunucusuz, kesintisiz ve pil dostu bir döngü yoktur. Üç katman kullanılacak:

| Katman | Ne için | Gerçekçi davranış |
|---|---|---|
| WorkManager, 15 dk periyot (en düşük izinli) | Tarama, açık sinyal takibi | Doze'da ertelenir; gece 30–60 dk'ya uzayabilir. Garanti değil. |
| Kesin alarm (`setExactAndAllowWhileIdle`) | Pazar raporu, BIST açılış/kapanış | Dakika hassasiyetinde; Android 14+ izin ister. |
| Ön plan servisi "Canlı izleme" (kullanıcı açar, kalıcı bildirimli) | 1 dk döngü istenen dönemler | En güvenilir yol; pil tüketir. Android 15'te `dataSync` türü 24 saatte 6 saatle sınırlı. |

- Kişisel kurulumda (APK elle yüklenir) ön plan servisi serbestçe kullanılabilir; pil optimizasyonundan
  muafiyet kullanıcıya adım adım yaptırılır. Xiaomi/Samsung/Oppo gibi üreticilerin kendi öldürücüleri için
  ek ayar gerekir ve bu doğrulanana kadar garanti verilemez.
- Mağaza sürümünde varsayılan WorkManager + alarm olur; ön plan servisi yalnızca kullanıcının başlattığı
  süreli oturumdur ve Play Console'da tür beyanı gerekir.
- Sonuç: arka planda sinyal gecikmesi tipik olarak 0–15 dk, kötü durumda 1 saate kadar. 5 dk'lık mum
  stratejileri bu yüzden arka planda "kırılım anı" değil "kapanmış mum teyidi + giriş bölgesi" olarak sunulur.
- **iOS notu:** BGTaskScheduler fırsatçıdır, periyot garanti etmez. Sunucusuz sürekli sinyal iOS'ta mümkün
  değil; iOS sürümü ancak haftalık rapor + uygulama açıkken yenileme olarak çalışır. Anlık bildirim için
  push sunucusu gerekir, bu da "sıfır para" kısıtıyla çelişir. Ayrıca Apple geliştirici hesabı yıllık ücretlidir.

---

## K2. Veri kaynakları

### Kripto
Birincil Binance açık piyasa verisi (`data-api.binance.vision`, gecikmesiz, anahtarsız); `XAGUSDT` ve
`SIRENUSDT` spot'ta yoksa futures ucu. Yedek: Yahoo `-USD`. Mevcut davranış korunur.

### Borsa İstanbul

| Kaynak | Veri | Gecikme | Limit / kararlılık | Kullanım koşulu | Rol |
|---|---|---|---|---|---|
| Yahoo Finance `.IS` (chart ucu) | Günlük + gün içi OHLCV | ~15 dk | Resmî API değil; belgesiz kısıtlama, ara ara 429 | Kişisel, ticari olmayan kullanım; yeniden dağıtım yasak | **Birincil** |
| İş Yatırım açık JSON ucu (`HisseTekil`) | Günlük en yüksek/en düşük/kapanış, TL hacim, piyasa değeri (açılış yok) | Gün sonu | Belgesiz, değişebilir | Açık lisans yok | **Yedek (günlük)** — 2026-11-10'da canlı doğrulandı |
| Stooq CSV | Günlük | Gün sonu | 2026'dan beri CAPTCHA ile alınan anahtar + günlük kota | Kişisel | **Elendi** (otomatikleştirilemez) |
| KAP | Bildirimler (fiyat değil) | Anlık | Resmî ücretsiz API yok | Kamuya açık | Haber/olay vetosu için, Faz 2'de değerlendirilecek |
| TCMB EVDS | USD/TRY, faiz, enflasyon | Günlük | Sağlam | Ücretsiz ama kişiye özel anahtar ister | İsteğe bağlı; anahtarı kullanıcı girer, cihazın güvenli deposunda durur |
| Borsa İstanbul resmî veri | Her şey | Lisansa göre | Sağlam | Ücretli lisans | Kapsam dışı (sıfır para) |

**Karar:** sağlayıcı soyutlaması (`MarketDataProvider`), sıralı yedekleme, disk önbelleği (mum bazında,
kapanmış mum bir kez indirilir), istek aralığı sınırlama ve geri çekilme (backoff). Her veri noktası
kaynağını ve yaşını taşır; ekranda "veri 17 dk gecikmeli · Yahoo" gibi gösterilir.

**Gecikmeli veriyle gün içi sinyalin sınırı:** 15 dk veri gecikmesi + 15 dk arka plan periyodu = sinyal
30 dk'ya kadar bayat olabilir. Bu yüzden BIST'te "kısa vade" 5 dk'lık scalp değil, 1 saatlik/günlük mumda
1–5 günlük salınım işlemidir; giriş nokta değil bölge olarak verilir; "stopa yakın" uyarıları yaklaşık
değerdir ve öyle etiketlenir. Açılış boşlukları ve ±%10 fiyat marjı stopun kayarak gerçekleşmesine yol
açabilir; raporlar bunu ayrı satırda gösterir.

**Yayın kısıtı (kullanıcıya bildirilecek):** Yahoo koşulları ticari kullanımı ve yeniden dağıtımı yasaklar;
BIST verisinin (gecikmeli dahil) üçüncü kişilere sunulması Borsa İstanbul lisansına tabidir. Kişisel
kullanımda sorun yok. Mağazada çok kullanıcıya açılırken BIST fiyat verisi için ücretsiz ve lisansı temiz
bir kaynak şu an görünmüyor. Bu, "sıfır para" kısıtıyla yayın hedefi arasındaki açık çatışmadır.

### BIST evreni ve takvim
- Evren: BIST 100 bileşenleri (uygulama içi liste, çeyreklik güncellenir) → likidite süzgeci: 20 günlük
  ortalama işlem hacmi (TL) en yüksek 40 hisse ve alt eşik üstü; son 20 günde 5'ten fazla tavan/taban
  günü olanlar ve veri boşluğu olanlar elenir. Gerekçe: gecikmeli veriyle yalnızca derin tahtalarda makul giriş bulunur.
- Takvim: 09:40 açılış seansı, 10:00–18:00 sürekli işlem, 18:00–18:10 kapanış; yarım gün (arife, 28 Ekim)
  12:30/12:40; 2026 resmî tatil tablosu gömülü, her yıl güncellenir. ±%10 günlük fiyat marjı, lot = 1 pay, T+2.

---

### Faz 1 canlı doğrulama (2026-11-10)

- Kripto: 10 varlığın hepsi geldi; 8'i Binance spot, `XAGUSDT` ve `SIRENUSDT` futures ucundan.
- BIST: 75 adayın 75'i Yahoo `.IS` üzerinden geldi (77 istek, hata ve hız sınırı yok; istekler arası 350 ms).
- Likidite süzgeci (20 günlük ortalama en az 300 mn TL, ilk 40): 40 hisse seçildi; 33'ü düşük likidite,
  1'i tavan/taban sıklığı, 2'si sıra dışı kalarak elendi. En likit: ASELS, THYAO, AKBNK.
- Yahoo saatlik BIST mumları 09:30 TRT hizalıdır; seans kapanışına göre kırpılır.
- Yahoo `exchangeDataDelayedBy` alanını boş döndürüyor; 15 dk gecikme varsayımı korunur ve bir mum,
  bitişinden 15 dk sonra "kapanmış" sayılır.
- İş Yatırım açılış fiyatı vermiyor; açılış önceki kapanıştan türetilir, seri "yaklaşık açılış" işaretlenir.

## K3. Haftalık öneri: ağırlık ve sınırlar

Ağırlık, eşit risk bütçesinden türetilir: her öneriye güven skoruna göre bütçenin %0,5–%1,5'i kadar risk
ayrılır; `ağırlık = risk payı / stop mesafesi (%)`. Güçlü sinyal → daha büyük risk payı; dar stop → daha
büyük ağırlık (aynı riskle).

| Sınır (risk iştahı "dengeli") | Değer | Gerekçe |
|---|---|---|
| Tek varlık üst sınırı | %20 | Tek hata portföyü en fazla ~%2–3 etkiler |
| Toplam açık risk (Σ ağırlık × stop mesafesi) | %6 | Tüm stoplar aynı hafta çalışsa bile kayıp sınırlı |
| Kripto toplamı | %40 | Oynaklık ve hafta sonu boşluk riski |
| En az nakit | %20 | Fırsat ve hata payı |
| Öneri sayısı | 0–6, sabit değil | Eşik üstü skor yoksa "net fırsat yok, nakitte kal" |
| Ayı rejimi | Risk payları yarıya iner | Düşen piyasada long-only strateji zayıf |

"Temkinli" ve "atak" ayarları bu değerleri sırasıyla 0,6× ve 1,4× ölçekler (tek varlık sınırı en çok %25).
Tutar gösterimi kullanıcının girdiği bütçeyle çarpılarak yapılır; uygulama emir açmaz.
- **Sıralı orantılı küçültme (Faz 3 uygulaması):** Ağırlık hesaplamasında önce tek varlık tavanı (%20 / %12 / %25), ardından kripto toplam tavanı (%40 / %24 / %56), ardından toplam açık risk tavanı (%6 / %3,6 / %8,4) ve son olarak en az nakit tamponu (%20 / %35 / %15) sırasıyla uygulanır; her aşamada sınır aşımı varsa ilgili grup orantılı küçültülür. Performans eğrisi yalnızca ileriye dönük gerçekleşen haftalık raporlardan (100 bazlı bileşik endeks) üretilir.

---

## K4. Görsel tasarım — teknik uygulama (stil "GÜNDÜZ", sabit)

| Seçenek | 3D halka için | Maliyet | Karar |
|---|---|---|---|
| `CustomPainter` ile sahte 3D (eliptik üst yüz + yan duvar dilimleri, boyacı sıralaması) | Tam denetim, dokunma isabeti hesaplanabilir | Ek paket yok, 60 fps, yalnızca etkileşimde çizer | **Seçildi** |
| Gerçek 3D motor (`flutter_scene`, three.js WebView) | Gerçek ışık/gölge | Ağır, deneysel, pil ve APK boyutu | Elendi |
| Hazır animasyon (Rive/Lottie) | Güzel ama veri bağlı dilimler zor | Paket + varlık boyutu | Elendi |

- Renkler (tasarım belirteçleri): zemin `#F6F4EF`, kart `#FFFFFF`, metin `#1B1B1B`, vurgu `#5B4BDB` /
  koyu `#3B2FA8`, ikincil `#D85A30`; kazanç/zarar sade yeşil/kırmızı, her zaman işaret ve metinle birlikte
  (yalnız renge dayanmaz). Köşe 14 px, ince ayırıcı çizgi, gölge yerine çizgi.
- Animasyon: yalnızca gömülü `AnimationController` ve örtük animasyonlar; sürekli dönen şey yok, halka
  dokununca/sürükleyince hareket eder. Sistem "animasyonları azalt" ayarı veya pil tasarrufu açıksa
  geçişler anlık, halka düz 2D olur.
- Gezinme: Özet · Öneri (içinde Geçmiş) · Sinyal · Ayar. Koyu tema desteklenir, varsayılan açık.
- Yazı tipi: sistem yazı tipi (çalışma anında font indirme yok; gizlilik ve çevrimdışı çalışma).
- Bildirim kanalları: Sinyal (yüksek), Sonuç (yüksek), Rapor (normal), Sistem (düşük). Aynı varlık için
  10 dk içinde birleştirme, sessiz saatlerde kuyruğa alıp tek özet, günlük üst sınır, tekrar anahtarı.
- **Faz 4 uygulama detayları (2026-11-10):**
  - Android Gradle Plugin 9.1 / Kotlin 2.4 ile üçüncü parti arka plan eklentilerinde oluşabilecek derleme uyumsuzluklarını önlemek için WorkManager (`androidx.work:work-runtime-ktx:2.10.0`), kesin alarmlar (`AlarmManager.setExactAndAllowWhileIdle`) ve "Canlı İzleme" ön plan servisi (`PusulaLiveMonitorService`, `foregroundServiceType="dataSync"`) doğrudan yerel Kotlin katmanında (`MainActivity.kt`) yazıldı ve `MethodChannel('app.pusula/background')` üzerinden Dart (`BackgroundScheduler`) ile bağlandı.
  - Kalıcı depolama (`StorageBundle`): Android'de `sqflite` (`pusula_local.db`) kullanılır; Web önizlemesinde ve birim testlerinde otomatik olarak bellek içi depolara (`StorageBundle.inMemory()`) düşer. JSON dışa/içe aktarım (`exportToJson` / `importFromJson`) tüm ayarları, sinyal günlüğünü ve haftalık raporları kapsar.

---

## K5. Geliştirme ortamı (bu bilgisayar, 2026-11-10)

| Araç | Durum |
|---|---|
| Python 3.11, Node 22, Git 2.43, adb (platform-tools) | Kurulu |
| Flutter SDK (Dart dahil) | **Yok** |
| JDK 17 | **Yok** |
| Android SDK (cmdline-tools, platform, build-tools) | **Yok** |
| Boş disk | 42 GB |

**Kuruldu (2026-11-10, kullanıcı onayıyla):** `C:\Users\eren_\dev` altına Flutter stable (Dart 3.13.7),
Temurin JDK 17.0.21 (SHA-256 doğrulandı), Android komut satırı araçları + platform 36 + build-tools 36.
Yönetici yetkisi kullanılmadı, sistem PATH'i ve kayıt defteri değiştirilmedi; ortam `araclar/ortam.ps1`
(veya `ortam.sh`) ile oturum bazında açılır. Android SDK lisans sözleşmeleri kurulum sırasında kabul edildi.

İlk plan: Flutter SDK (~1 GB indirme, ~3 GB disk), Temurin JDK 17
(~0,3 GB), Android komut satırı araçları + platform + build-tools (~1,2 GB), ilk derlemede Gradle/pub
önbelleği (~1,5–2 GB). Toplam ~6–7 GB. Android Studio ve emülatör gerekmez; arayüz Flutter web çıktısıyla
tarayıcıda, gerçek davranış telefonda sınanır. APK derleme ve yükleme adımları kurulumdan sonra README'ye yazılacak.

---

## K6. Gizlilik, güvenlik, yayın

- Uygulamada hesap, analitik, reklam, uzak sunucu yok; tüm veri cihazda. Dışa/içe aktarma JSON ile.
- Koda veya yapılandırmaya anahtar gömülmez. İsteğe bağlı EVDS anahtarı yalnızca cihazın güvenli deposunda.
- Loglara sır, tam URL sorgusu veya kullanıcı bütçesi yazılmaz.
- Her rapor/analiz ekranında sabit "Yatırım tavsiyesi değildir" şeridi.
- Google Play: Finansal özellikler beyanı her uygulama için zorunlu; ön plan servisi türü beyanı gerekir.
  Geliştirici hesabı tek seferlik ücretlidir (para harcatır → yayın anında sorulacak).
- **Hukuki not (hukukçu görüşü değildir):** Türkiye'de başkalarına yönelik al/sat önerisi yayımlamak SPK
  düzenlemelerine tabi olabilir. Uygulamayı başkalarına açmadan önce bu konunun bir uzmana danışılması gerekir.

---

## K7. Teknik analiz değişiklikleri (strateji sürümü 2.0.0, Faz 2'de uygulanacak)

| Değişiklik | Neden |
|---|---|
| Rejim tespiti eklenir (BTC ve XU100: EMA50/200 eğimi, ADX, gerçekleşen oynaklık) | Kırılım kuralları yalnızca uygun rejimde çalışsın |
| Çok zaman dilimli teyit (sinyal dilimi + bir üst dilim trendi) | Tek dilim gürültüsünü azaltır |
| TimeMachine: dilim havuzu yerine blok önyükleme, sonuç güven aralığıyla | R4 |
| `replay_historical_sessions` kaldırılır | "Backtest yok" kısıtı (R5) |
| Emir defteri dengesi vetodan çıkar, bilgi alanı olur; fonlama vetosu kalır | R6 |
| Haber eşleşmesi daraltılır; BIST için KAP başlığı vetosu değerlendirilir | R3 |
| Sanal kasa/broker yerine sinyal günlüğü: her sinyal hedef/stop/süre sonucuna kadar izlenir | Ürün sinyal üretir, emir açmaz |

Not: Monte Carlo süzgeci tek bir canlı sinyalin olasılığını tahmin eder; strateji performansı ölçmez ve
geçmişte strateji sınamaz. Bu yüzden "backtest yok" kısıtının dışında sayıldı ve korundu. Kullanıcı aksi
görüşteyse kaldırılır.

`backtest_3ay.py` ve çıktıları (`data/backtest_3m_report.json`, `data/bars_90d_cache.json`) çalıştırılmadı,
okunmadı, değiştirilmedi; yeni motora girdi olmayacak.

**Aşırı uyum kuralı:** strateji başına en az 30 kapanmış sinyal birikmeden parametre değişmez. Daha az
veriyle yalnızca "gözlem" yazılır, belirsizlik (Wilson aralığı) açıkça gösterilir. Her değişiklik
`docs/degisiklik-gunlugu.md` içinde sürümlenir ve önceki sürüme dönülebilir.

### Faz 2 uygulama detayları (K8 — 2026-11-10)
- **Blok önyükleme (block bootstrap):** `MonteCarloSimulator` varsayılan olarak 4 ardışık mumluk bloklar (`blockSize = 4`) ve 2.500 tekrar kullanır; ortalama R için %95 güven aralığı (`±1.96 × SE`) hesaplanır.
- **Güven skoru (0–100) bileşen ağırlıkları:** Kurulum çakışması (25), hacim/alıcı teyidi (15), piyasa rejimi uyumu (15), üst zaman dilimi uyumu (15), Monte Carlo beklentisi (15), Ödül/Risk oranı (15).
- **Kademeli hedef ve başabaş muhasebesi:** `target1` (1R) görüldüğünde durum `hedef1` olur ve stop giriş fiyatına çekilir; sonrasında başabaş stop çalışırsa ilk kademenin kârı korunarak `+0.5R` gerçekleşmiş sayılır. Aynı mumda hem stop hem hedef görülürse muhafazakâr olarak stop sayılır.

---

## Kaynaklar

- Android ön plan servisi zaman aşımı: https://developer.android.com/develop/background-work/services/fgs/timeout
- Android 15 davranış değişiklikleri: https://developer.android.com/about/versions/15/behavior-changes-15
- Google Play Finansal Hizmetler politikası: https://support.google.com/googleplay/android-developer/answer/9876821
- Google Play finansal özellikler beyanı: https://support.google.com/googleplay/android-developer/answer/13849271
- Stooq anahtar zorunluluğu: https://github.com/pydata/pandas-datareader/issues/1012
- Borsa İstanbul 2026 tatil tablosu: https://www.borsaistanbul.com/files/pay-piyasasi-2026-yili-tatil-tablosu.pdf
- Flutter Windows kurulumu: https://docs.flutter.dev/get-started/install/windows/mobile

Doğrulanamayanlar: Yahoo `.IS` gecikmesinin güncel değeri (15 dk varsayıldı), İş Yatırım uçlarının bugünkü
durumu, Play'in yeni kişisel hesaplar için kapalı test şartı, kapanış seansı bitişi (18:10 varsayıldı).
Bunlar Faz 1 ve Faz 7'de canlı kontrol edilecek.
