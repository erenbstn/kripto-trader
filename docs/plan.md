# Faz Planı — Pusula

Kararların gerekçesi: [kararlar.md](kararlar.md). Her faz sonunda testler çalıştırılır ve neyin
doğrulanamadığı yazılır.

| Faz | Kapsam | "Bitti" ölçütü | Durum |
|---|---|---|---|
| 0 | Telegram temizliği, token silme, yerel bildirim ajanı | Kodda/yapılandırmada Telegram ve token izi yok; testler geçiyor | **Tamam** |
| 1 | `pusula_core` iskeleti; veri katmanı (sağlayıcı soyutlaması, yedekleme, önbellek, hız sınırı); BIST takvimi (seans, tatil, yarım gün, fiyat marjı, lot); BIST evreni | Sahte HTTP ile sağlayıcı ve yedekleme testleri; takvim testleri; bir canlı duman testi | **Tamam** (40 test; canlı duman testi 2026-11-10) |
| 2 | Analiz çekirdeği (göstergeler, 6 kurulum, rejim, çok dilimli teyit, çıkış planı, Monte Carlo); sinyal günlüğü ve sonuç takibi | Sentetik mumlarla birim testler; Python referansıyla gösterge karşılaştırması; sinyal yaşam döngüsü testi | **Tamam** (58 test) |
| 3 | Haftalık rapor: geçen hafta sonucu, yeni öneriler + ağırlıklar, kısa vade raporu (kripto/BIST ayrı) | Sentetik günlükten rapor üretimi; ilk haftada "henüz veri yok"; ağırlık sınırı testleri | **Tamam** (63 test) |
| 4 | Flutter iskeleti, depolama, WorkManager + alarm + canlı izleme servisi, yerel bildirimler | Uygulama derlenir; zamanlayıcı ve bildirim mantığı birim testli; APK üretilir | **Tamam** (8 uygulama testi + APK derlemesi) |
| 5 | Arayüz ("GÜNDÜZ"), 3D halka, ekranlar, animasyon azaltma | Widget testleri; web önizlemede görsel kontrol; erişilebilirlik denetimi | **Tamam** (11 uygulama/widget testi + `flutter build web`) |
| 6 | Kendini geliştirme: günlükten öneri, sürümlü strateji yapılandırması, geri alma, 30 sinyal kuralı | Az veride değişiklik yapmadığını gösteren testler; sürüm geri alma testi | **Tamam** (66 çekirdek testi) |
| 7 | Yayına hazırlık: gizlilik metni, uyarılar, çok kullanıcı denetimi, Play beyan listesi | Kontrol listesi; açık kalan hukuki/lisans kısıtları yazılı | **Tamam** (`docs/gizlilik-ve-play-beyan.md` + tüm testler) |

## Cihazsız doğrulanamayacaklar (her fazda yinelenecek)

- Doze ve üretici pil öldürücüleri altında gerçek tarama sıklığı.
- Bildirimlerin kilit ekranında ve sessiz saatlerde gerçek davranışı.
- 3D halkanın düşük donanımda kare hızı ve pil etkisi.
- Canlı veri kaynaklarının uzun süreli kararlılığı (429, biçim değişikliği).
