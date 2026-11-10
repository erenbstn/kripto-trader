import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../background/background_scheduler.dart';
import '../state/pusula_controller.dart';
import '../theme/gunduz_theme.dart';

/// Sekme 4 — Ayar ekranı (DEVIR.md Faz 5.3).
/// Bildirim tercihleri, bütçe tutarı, risk iştahı, sessiz saatler, pil optimizasyonu rehberi,
/// veri kaynakları sağlık durumu (`ProviderHealth`), sürüm ve değişiklik günlüğü.
class AyarScreen extends ConsumerWidget {
  const AyarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final s = state.settings;
    final sched = state.scheduleSnapshot;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const DisclaimerBanner(),
        const SizedBox(height: 14),
        // 1. Portföy Bütçesi ve Risk İştahı
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portföy Referans Bütçesi ve Risk İştahı',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Seçili Bütçe: ${s.budgetAmount.toStringAsFixed(0)} TL (Yalnızca ağırlık tutarı gösterimi içindir; cihaz dışına çıkmaz)',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final amt in const [50000.0, 100000.0, 250000.0, 500000.0])
                      ChoiceChip(
                        label: Text('${(amt / 1000).toStringAsFixed(0)} Bin TL'),
                        selected: (s.budgetAmount - amt).abs() < 1,
                        onSelected: (_) => controller.updateBudget(amt),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Risk İştahı (K3 Ağırlık Sınırları):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final app in RiskAppetite.values)
                      ChoiceChip(
                        label: Text('${app.label} (${app.scale.toStringAsFixed(1).replaceAll(".", ",")}×)'),
                        selected: s.riskAppetite == app,
                        onSelected: (_) => controller.updateRiskAppetite(app),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 2. Görünüm ("GÜNDÜZ") ve Erişilebilirlik / Pil Tasarrufu
        Card(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('switch_dark_mode'),
                title: const Text('Koyu Tema', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Varsayılan açık tema "GÜNDÜZ" (#F6F4EF) önerilir.'),
                value: s.darkMode,
                onChanged: controller.toggleDarkMode,
              ),
              SwitchListTile(
                key: const Key('switch_reduce_animations'),
                title: const Text('Animasyonları Azalt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Açıldığında 3D halka düz 2D çizilir ve geçişler anlık olur.'),
                value: s.reduceAnimations,
                onChanged: controller.toggleReduceAnimations,
              ),
              SwitchListTile(
                key: const Key('switch_battery_saver'),
                title: const Text('Pil Tasarrufu Modu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Düşük pil tüketimi için 3D gölgelendirmeyi kapatır.'),
                value: s.batterySaverMode,
                onChanged: controller.toggleBatterySaver,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 3. Yerel Bildirim Tercihleri ve Sessiz Saatler
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  'Yerel Bildirim Kanalları (Telegram/Dış Servis Yok)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              SwitchListTile(
                title: const Text('Sinyal Kanalı (Yüksek Önem)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Kapanmış mum teyitli kurulum ve giriş bölgesi bildirimleri'),
                value: s.notifySignal,
                onChanged: (v) => controller.updateNotificationChannels(signal: v),
              ),
              SwitchListTile(
                title: const Text('Sonuç Kanalı (Yüksek Önem)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('1R/2R hedef, stop ve stopa yakınlık bildirimleri (10 dk birleştirmeli)'),
                value: s.notifyOutcome,
                onChanged: (v) => controller.updateNotificationChannels(outcome: v),
              ),
              SwitchListTile(
                title: const Text('Rapor Kanalı (Normal Önem)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Pazar 09:00 TRT haftalık rapor hazır bildirimi'),
                value: s.notifyReport,
                onChanged: (v) => controller.updateNotificationChannels(report: v),
              ),
              SwitchListTile(
                title: const Text('Sessiz Saatler (23:00 – 08:00 TRT)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Gece bildirimleri kuyruğa alınır, sabah tek özet olarak gönderilir.'),
                value: s.quietHoursEnabled,
                onChanged: (v) => controller.updateNotificationChannels(quietHoursEnabled: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 4. Arka Plan Zamanlama ve Pil Optimizasyonu Rehberi
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arka Plan Çalışma ve Pil Optimizasyonu Rehberi (K1)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Periyodik Tarama: WorkManager (${sched.periodicIntervalMinutes} dk) · Sonraki Pazar Raporu: ${BistCalendar.toTrt(sched.nextSundayReportUtc).toIso8601String().substring(0, 16).replaceAll("T", " ")} TRT',
                  style: const TextStyle(fontSize: 12),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Canlı İzleme Ön Plan Servisi (Kalıcı Bildirimli)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Açıldığında kalıcı bildirim gösterir ve Doze kısıtlamasına girmeden izleme yapar (Android 15 dataSync sınırı: 6 saat/24s).',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: s.liveMonitorEnabled,
                  onChanged: controller.toggleLiveMonitor,
                ),
                const Divider(),
                const Text(
                  'Üretici Pil Kısıtlaması Muafiyet Adımları:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final guide in BackgroundScheduler.oemGuides)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${guide.brand}: ${guide.steps}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 5. Veri Kaynakları Sağlık Durumu (ProviderHealth)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Veri Kaynakları Sağlık Durumu (ProviderHealth)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final ph in state.providerHealthList)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          ph.healthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          size: 16,
                          color: ph.healthy ? GunduzColors.profitGreen : GunduzColors.coral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ph.label,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          'Başarılı: ${ph.successCount} · Hata: ${ph.failureCount}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 6. Kendini Geliştirme, 30 Sinyal Kuralı ve Sürümlü Strateji Ayarları (Faz 6)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kendini Geliştirme ve Sürümlü Strateji · v${s.activeStrategyVersion}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: controller.rollbackStrategyVersion,
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Geri Al'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  state.optimizationProposal.summaryReportTr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final st in state.optimizationProposal.statsByStrategy.values.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${st.observationNoteTr}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 7. Sürüm, Gizlilik Metni ve Yasal / Play Beyan Özeti (Faz 7)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sürüm, Gizlilik ve Yasal Beyanlar · Strateji v${s.activeStrategyVersion}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• Gizlilik: Kişisel veri, analitik, konum veya borsa/aracı kurum API anahtarı toplanmaz; tüm veriler yalnızca cihazdaki SQLite veritabanında tutulur.\n'
                  '• Veri Kaynağı ve Lisans: BIST verileri ~15 dk gecikmelidir (Yahoo / İş Yatırım); ticari yeniden dağıtım lisans gerektirir.\n'
                  '• Hukuki Not: Yatırım tavsiyesi değildir; Türkiye\'de üçüncü kişilere öneri yayımlamak SPK düzenlemelerine tabi olabilir.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('btn_privacy_and_legal'),
                      onPressed: () => _showPrivacyDialog(context),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                      label: const Text('Gizlilik ve Play Beyanı'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('btn_reset_defaults'),
                      onPressed: controller.resetSettingsToDefault,
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Ayarları Sıfırla'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gizlilik, Lisans ve Play Beyanı'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Gizlilik: Pusula hiçbir kişisel kimlik, hesap, konum, reklam kimliği veya aracı kurum API anahtarı istemez ve toplamaz. Bütçe tutarı yalnızca cihazda yerel olarak saklanır.\n\n'
            '2. Bağlanılan Açık Uçlar: Binance açık piyasa verisi (data-api.binance.vision), Yahoo Finance (.IS / -USD) ve İş Yatırım.\n\n'
            '3. Yasal Uyarı ve SPK Notu: Üretilen hiçbir içerik yatırım tavsiyesi değildir. Türkiye\'de başkalarına yönelik al/sat önerisi yayımlamak SPK mevzuatına tabi olabilir; yayın öncesi uzman görüşü alınmalıdır.\n\n'
            '4. Veri Lisansı: Yahoo ve BIST verileri yalnızca kişisel kullanım içindir; ticari yeniden dağıtım Borsa İstanbul lisansına tabidir.\n\n'
            '5. Google Play Beyanı: Finansal işlem/cüzdan sunmaz (yalnızca analiz); Veri Güvenliği: Toplanan/paylaşılan veri yok; Ön plan servisi: dataSync (kullanıcı isteğiyle).',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
