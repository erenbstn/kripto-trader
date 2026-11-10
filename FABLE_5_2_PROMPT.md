# Fable 5.2'ye verilecek prompt (v2: Telegram yok, mobil uygulama)

Kullanım: Claude Code'u `kripto-trader` klasöründe aç, modeli Fable 5.2 yap, Shift+Tab ile plan modunda başla, aşağıdaki bloğu yapıştır.
Model mimari, teknoloji ve kod kararlarını kendisi verir; araştırır, planlar ve kodlar.
Kullanıcıya sadece "KARAR YETKİSİ" bölümünde yazan durumlarda sorar.

---

```
Rol: Kıdemli bir mobil uygulama + yazılım mimarı ve nicel analiz mühendisisin.
Bu klasördeki `kripto-trader` projesi (11 ajanlı, sıfır bağımlılıklı Python, kripto için
çalışan analiz motoru) temel alınarak, Borsa İstanbul'u da kapsayan, telefonuma kurulacak
modern bir MOBİL UYGULAMA geliştireceğiz. Önce projeyi baştan sona oku (main.py, agents/*,
config.json, tests/, README.md), mevcut yapıyı özetle, sonra araştırıp planını sun.
Sonra kararları kendin ver ve fazlar halinde kodla.

## KARAR YETKİSİ
- Mimari, teknoloji (Flutter/React Native/Kotlin vb.), state management, klasör yapısı,
  kod standartları, kütüphane seçimi, test stratejisi, teknik analiz değişiklikleri ve
  uygulamanın iç tasarımı tamamen SENİN kararın. Bunlar için onay isteme; seçimini ve
  gerekçesini kısa bir karar kaydına (docs/kararlar.md) yaz.
- Sadece şu durumlarda dur ve bana sor: (1) para harcatacak bir şey çıkarsa, (2) bilgisayarıma
  yazılım kurman gerekirse (neyi, neden, boyutunu söyle), (3) gizlilik veya güvenlik riski
  doğarsa, (4) görsel stil kararını değiştirmek istersen, (5) bu prompt'taki bir kısıtla
  çelişen bir durum çıkarsa.

## ÜRÜN TANIMI
Uygulama, telefonumda sürekli çalışan, kendi kendine analiz yapan ve bana bildirim gönderen
kişisel bir yatırım asistanıdır. Şu an yalnızca benim kullanımım için; ileride başka kişilere
ve başka platformlara (Google Play, belki iOS) yayınlayabilirim. Bu yüzden mimariyi baştan
çok kullanıcılıya ve mağaza yayınına uygun kur (sır/anahtar gömme yok, ayarlar kullanıcıya
özel, mağaza finans uygulaması kurallarına uyum, sorumluluk reddi).

### Üç çalışma şekli (hepsi aynı uygulamada)
1. HAFTALIK ÖNERİ (Borsa İstanbul + Kripto)
   - Her Pazar günü sırayla iki şey üretilir:
     (a) GEÇEN HAFTA RAPORU: geçen hafta önerdiğin her varlığın gerçekleşen getirisi (%),
         toplam portföy getirisi (önerilen ağırlıklara göre), hedefe/stopa ulaşanlar,
         isabet oranı, en iyi/en kötü öneri, kısa değerlendirme ("ne öğrendik").
     (b) ÖNÜMÜZDEKİ HAFTANIN ÖNERİLERİ.
   - Her öneri için: gerekçe (teknik + haber/temel + hacim/momentum), giriş bölgesi,
     kademeli kâr alma seviyeleri, stop-loss, risk/ödül, geçersiz kılma koşulu, güven skoru,
     ana riskler ve BÜTÇE AĞIRLIĞI (% kaçı bu varlığa ayrılmalı).
   - KAÇ ÖNERİ OLACAĞINA SEN KARAR VER: sabit sayı yok. Çok fazla önerme; sadece gerçekten
     güçlü olanları öner. Fırsat yoksa "bu hafta net fırsat yok" de, nakitte kalmayı da bir
     öneri olarak sun. Kripto için bakılacak evren sabit (aşağıda), BIST evrenini sen
     tasarla (örn. BIST30/BIST100'den likidite filtresiyle).
   - Pozisyon ağırlığı: sinyal ne kadar güçlüyse (yüksek güven, güçlü teyit, iyi R:R,
     uygun piyasa rejimi) o kadar yüksek %; zayıfsa düşük %. Toplam ağırlık %100'ü
     aşmasın, nakit payını da sen belirle. Tek varlık üst sınırı ve toplam risk sınırı koy,
     gerekçesini yaz.
   - Karakter/uzunluk sınırı YOK: detaylı, ekranda okunaklı, bölümlere ayrılmış analiz
     ekranları üret.

2. KISA VADELİ SİNYAL MODU (arka planda sürekli)
   - Mevcut ajan akışı (scanner, entry, exit, risk, timemachine, news, whale...) korunur,
     BIST'i de kapsar. Sistem ASLA gerçek emir açmaz; sadece sinyal üretir: giriş, stop,
     hedef, gerekçe, R:R ve bildirim gönderir. Sinyalin sonucunu da takip eder
     (hedef/stop/süre doldu) ve bildirir.
   - Haftalık KISA VADELİ RAPOR: o hafta üretilen tüm kısa vadeli sinyallerin toplam
     getirisi (%), sinyal sayısı, isabet oranı, ortalama R, en iyi/en kötü işlem,
     strateji bazında döküm, kripto ve BIST ayrı ayrı. Bu rapor da Pazar günü, haftalık
     öneri raporuyla birlikte hazırlanır.

3. KENDİNİ GELİŞTİRME
   - Uygulama kendi sinyal günlüğünü tutar ve buna bakarak iyileştirme önerir/uygular.
   - TEKNİK ANALİZİ SERBESTÇE DEĞİŞTİREBİLİRSİN: daha iyi olacağını düşündüğün gösterge,
     strateji, filtre, rejim tespiti, ağırlıklandırma varsa ekle, değiştir veya kaldır.
     Neyi neden değiştirdiğini sürümlü bir değişiklik günlüğüne yaz (config/strateji
     sürümleri, geri alınabilir).
   - Uygulamayı geliştirme (özellikler, kod yapısı, mimari) kararlarını da sen ver.
     Görsel stil kararı aşağıda sabitlendi.

## KESİN KISITLAR
- TELEGRAM TAMAMEN İPTAL: Telegram'la ilgili tüm kodu (telegram_agent.py ve çağrıları),
  config alanlarını, testleri, README bölümlerini ve .env örneklerini kaldır. Mevcut
  config.json'daki bot token'ı sil (token ifşa oldu; ben BotFather'dan iptal edeceğim).
  Başka mesajlaşma servisi de ekleme: bildirimler yalnızca uygulamanın kendi yerel
  bildirimleridir.
- GEÇMİŞ VERİYLE BACKTEST YOK: `backtest_3ay.py`'yi çalıştırma, yeni backtest yazma,
  "son 3 ayda ne kadar iyileşti" ölçümü yapma, geçmiş mumlarda strateji değişikliğini
  yeniden test etme. Haftalık raporlardaki getiriler yalnızca BU SİSTEMİN GERÇEKTEN
  ÜRETTİĞİ önerilerin sonradan gerçekleşen sonuçlarıdır (ileriye dönük kayıt). İlk
  haftada geçmiş olmadığı için "geçen hafta raporu: henüz veri yok" de; veri uydurma.
  Doğrulama için birim testler, kod incelemesi ve sahte (sentetik) veri kullan.
- SIFIR PARA: Ücretli API, abonelik, sunucu kiralama yok. Yalnızca ücretsiz kaynaklar
  ve telefonun kendisi (sunucu telefon). Yayın aşamasında bile ücretli altyapıya
  bağımlı olma; bir kısıt görürsen bana söyle.
- EMİR/ANAHTAR YOK: Borsa/aracı kurum API anahtarı isteme, canlı emir kodu yazma.
- GİZLİLİK: Hiçbir anahtar/token düz metin config'te veya logda durmasın. `.env`
  dosyasını hiçbir araçla okuma/yazdırma.
- Her rapor/analiz ekranında görünür bir "yatırım tavsiyesi değildir" uyarısı olsun.
- Kripto evreni (sabit, config'teki whitelist): ONDOUSDT, HBARUSDT, BTCUSDT,
  SIRENUSDT, XAGUSDT, LINKUSDT, SOLUSDT, PAXGUSDT, XRPUSDT, ETHUSDT.

## ARAŞTIRMA GÖREVLERİ (kodlamadan önce, kısa karşılaştırma tablolarıyla)
1. MİMARİ: "Telefonda sürekli çalışsın + bildirim göndersin + sunucu yok + bedava +
   ileride mağazaya çıkabilsin" gereksinimlerini karşılayan en iyi yolu araştır ve öner.
   En az şu seçenekleri karşılaştır: (A) Flutter/React Native/Kotlin ile yerel uygulama
   ve analiz motorunu uygulamanın içine (Dart/Kotlin vb.) taşımak; (B) Python motorunu
   uygulamaya gömmek (Chaquopy vb.); (C) Termux'ta Python motoru + yerel API, uygulama
   buna bağlanır. Android'in arka plan kısıtlarını (Doze, pil optimizasyonu, foreground
   service, WorkManager) ve "sürekli çalışma" için gerçekçi çözümü dürüstçe değerlendir.
   Mağaza yayınına uygunluk (Google Play finans/yatırım uygulaması politikaları) ve
   iOS ihtimali için de not düş. Seçimini kendin yap ve docs/kararlar.md'ye gerekçelendir.
2. BORSA İSTANBUL VERİSİ: ücretsiz kaynakları karşılaştır (Yahoo Finance .IS, Stooq,
   KAP, TCMB/EVDS, diğerleri): gecikme, istek limiti, kararlılık, kullanım koşulları,
   ticari/çok kullanıcılı kullanıma izin verip vermediği. Gecikmeli veriyle gün içi
   sinyalin sınırlarını dürüstçe yaz. Veri katmanı yedekli, önbellekli, sağlayıcı
   soyutlamalı olsun.
3. MODERN TASARIM (GÖRSEL STİL SABİT: "GÜNDÜZ"): güncel mobil tasarım trendlerini, 3D
   animasyon seçeneklerini ve performans/pil maliyetlerini araştır, teknik uygulamayı
   kendin seç. Stil kararı kullanıcı tarafından verildi, değiştirme:
   - Açık, ferah tema: sıcak krem/kırık beyaz zemin (yaklaşık #F6F4EF), beyaz kartlar,
     koyu metin (yaklaşık #1B1B1B), ikincil metin sakin gri.
   - Ana vurgu rengi mor/indigo (yaklaşık #5B4BDB, koyu tonu #3B2FA8); ikincil vurgu
     mercan/turuncu (yaklaşık #D85A30) ve nötr gri. Başarı/zarar renklerini sade tut.
   - Yuvarlak köşeli kartlar (yaklaşık 12-16 px), bol boşluk, düz yüzeyler, ince çizgiler.
   - Ana 3D görsel: 3D HALKA (donut) grafik; bütçe ağırlıklarını gösterir, dönebilir/
     dokunulabilir, segmente dokununca varlık detayı açılır. Derinlik hissi ver
     (üst yüz + alt kalınlık gölgesi). Diğer ekranlarda hafif 3D geçişler, akıcı mikro
     animasyonlar kullan. Animasyon pili ve performansı tüketmesin; düşük güç modunda
     ve "animasyonu azalt" erişilebilirlik ayarında sadeleşsin.
   - Alt gezinme: Özet, Öneri, Sinyal, Ayar (Geçmiş, Öneri içinde veya ayrı sekme).
   - Uygulama koyu temayı da desteklesin ama varsayılan ve öncelikli tasarım açık temadır.
   - Bildirim metinleri kısa ve net olsun. Örnekler: "SOL hedefe ulaştı · +%3,2 · 2R",
     "Pazar raporun hazır · Geçen hafta +%4,8 · 5 yeni öneri",
     "THYAO stop seviyesine yakın · Stop 312,40 · fiyat 314,10".
4. GELİŞTİRME ORTAMI: Bu Windows bilgisayarda hangi araçlar kurulu (Android SDK,
   JDK, Flutter/Node vb.)? Eksikleri listele. Kurulum gerekiyorsa neyi, neden ve
   boyutunu söyleyip bana sor, onayım olmadan kurma. APK'yı nasıl derleyip telefonuma
   yükleyeceğimi adım adım yaz.

## UYGULAMA İÇERİĞİ (asgari ekranlar; gerisini sen tasarla)
- Ana ekran: bu haftanın özeti, portföy ağırlık dağılımı (3D görsel), açık sinyaller,
  son bildirimler.
- Haftalık Rapor ekranı: önce geçen haftanın sonucu, sonra önümüzdeki haftanın
  önerileri (BIST ve Kripto ayrı sekmeler), her biri detaylı analiz kartı.
- Kısa Vadeli ekran: canlı sinyal akışı + haftalık kısa vadeli performans raporu.
- Geçmiş ekran: eski haftalık raporların arşivi ve performans eğrisi.
- Ayarlar: bildirim tercihleri, bütçe tutarı, risk iştahı, sessiz saatler, veri kaynağı
  durumu, uygulama sürümü ve değişiklik günlüğü.
- Pazar bildirimi: rapor hazır olduğunda "Haftalık rapor hazır" yerel bildirimi.
- Bildirimlerde sinyal ve sonuç bilgisi olsun; spam olmasın (öncelik, birleştirme,
  sessiz saatler).

## ÇALIŞMA ŞEKLİ
1. Projeyi oku, 10 satırda özetle, risk ve eksikleri söyle.
2. Yukarıdaki dört araştırmayı yap, kararlarını docs/kararlar.md'ye yaz ve devam et
   (onay bekleme; sadece "KARAR YETKİSİ" bölümündeki durumlarda sor).
3. Fazlara bölünmüş plan sun. Örnek: Faz 0 Telegram temizliği ve token silme; Faz 1 veri
   katmanı + BIST takvimi (seans, tatil, tavan/taban, lot); Faz 2 analiz çekirdeği +
   sinyal günlüğü; Faz 3 haftalık rapor üretimi (geçen hafta sonucu + yeni öneriler +
   kısa vadeli rapor); Faz 4 mobil uygulama iskeleti + arka plan çalışma + bildirimler;
   Faz 5 arayüz ve 3D animasyonlar; Faz 6 kendini geliştirme modu; Faz 7 yayına
   hazırlık (gizlilik, uyarılar, çok kullanıcı hazırlığı). Planı bana göster, ama onay
   beklemeden Faz 0'dan başla; her faz sonunda kısa durum raporu ver.
4. Her fazı kodla, testleri yaz ve çalıştır, sonunda neyin çalıştığını ve neyin
   DOĞRULANAMADIĞINI (örn. gerçek cihaz, pil davranışı) dürüstçe raporla.
5. İyileştirme kuralı: yeterli örnek birikmeden (strateji başına en az ~30 sinyal)
   parametreleri aşırı uyduma (overfitting); az veriyle değişiklik önerirken
   belirsizliği açıkça yaz.
6. README'yi ve geliştirici notlarını her fazda güncel tut.
```

---

## Notlar (prompt'un dışında)

1. **Token:** `config.json` içindeki bot token ifşa oldu. BotFather'da `/revoke` yap. Prompt zaten dosyadan silinmesini istiyor.
2. **Mimari kararı sende:** "Telefonda sürekli çalışsın" en zor kısım. Android arka plan kısıtları yüzünden Python motorunu uygulamaya gömmek mi, yoksa analizi uygulama diliyle yeniden yazmak mı daha iyi, model araştırıp kendisi karar verecek ve gerekçesini docs/kararlar.md'ye yazacak.
3. **Haftalık % raporu backtest sayılmaz:** Sistemin kendi canlı önerilerinin sonradan gerçekleşen sonucu. Bu yüzden ilk raporda geçmiş olmayacak, veri haftalar içinde birikecek.
4. **Yayın ihtimali:** Başkalarına açarsan Google Play'in finans uygulaması kuralları ve "yatırım tavsiyesi" konusundaki yasal sorumluluk önem kazanır. Bu yüzden prompt'a uyarı ve çok kullanıcı hazırlığı ekledim.
