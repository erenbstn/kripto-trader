import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusula_core/pusula_core.dart';

import '../background/background_scheduler.dart';
import '../state/pusula_controller.dart';
import '../storage/app_settings.dart';
import '../theme/gunduz_theme.dart';
import '../update/app_updater.dart';
import '../widgets/common.dart';

/// Sekme 4 — Ayar (K10 bileşen dili).
///
/// Bütçe ve risk iştahı (K3), görünüm/pil tasarrufu, yerel bildirim kanalları ve sessiz saatler,
/// arka plan zamanlama/pil muafiyet rehberi (K1), veri kaynağı sağlığı, aşırı uyum koruması
/// ve gizlilik/Play beyanı.
class _AyarBudgetField extends StatefulWidget {
  const _AyarBudgetField({required this.budgetAmount, required this.onApply});

  final double budgetAmount;
  final ValueChanged<double> onApply;

  @override
  State<_AyarBudgetField> createState() => _AyarBudgetFieldState();
}

class _AyarBudgetFieldState extends State<_AyarBudgetField> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.budgetAmount.round().toString());
  }

  @override
  void didUpdateWidget(covariant _AyarBudgetField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.budgetAmount - widget.budgetAmount).abs() >= 1) {
      _ctrl.text = widget.budgetAmount.round().toString();
      _error = null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseTryInput(_ctrl.text);
    if (parsed == null || parsed < 1000) {
      setState(() => _error = 'En az ₺1.000 gir');
      return;
    }
    setState(() => _error = null);
    widget.onApply(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('input_ayar_budget_try'),
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Özel bütçe (₺)',
              hintText: 'Örn. 200000',
              errorText: _error,
              suffixText: '₺',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const Key('btn_ayar_apply_budget'),
          onPressed: _submit,
          child: const Text('Uygula'),
        ),
      ],
    );
  }
}

class AyarScreen extends ConsumerWidget {
  const AyarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pusulaControllerProvider);
    final controller = ref.read(pusulaControllerProvider.notifier);
    final p = PusulaPalette.of(context);
    final s = state.settings;
    final sched = state.scheduleSnapshot;

    return PageBody(
      primaryFlex: 6,
      secondaryFlex: 6,
      primary: [
        const DisclaimerBanner(),
        const SectionTitle(
          'Portföy ve görünüm',
          subtitle: 'Spot portföy bütçesi · Mod · Görünüm',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeader(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Portföy bütçesi ve risk · Sadece Spot',
                  trailing: Tag(Fmt.tl(s.budgetAmount), color: p.accent),
                ),
                const Gap(12),
                _AyarBudgetField(
                  budgetAmount: s.budgetAmount,
                  onApply: controller.updateBudget,
                ),
                const Gap(10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amt in const [50000.0, 100000.0, 250000.0, 500000.0, 1000000.0])
                      ChoiceChip(
                        label: Text(amt >= 1000000 ? '1M TL' : '${(amt / 1000).toStringAsFixed(0)} Bin TL'),
                        selected: (s.budgetAmount - amt).abs() < 1,
                        onSelected: (_) => controller.updateBudget(amt),
                      ),
                  ],
                ),
                const Gap(14),
                Text(
                  'Portföy seçim modu',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text),
                ),
                const Gap(8),
                PortfolioModeSelector(
                  userSelected: s.isUserSelectedMode,
                  selectedCount: s.favoriteSymbols.length,
                  autoKey: const Key('ayar_btn_mode_auto'),
                  customKey: const Key('ayar_btn_mode_custom'),
                  onModeChanged: (userSel) => controller.setPortfolioSelectionMode(userSelected: userSel),
                ),
                const Gap(14),
                Text(
                  'Risk iştahı',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text),
                ),
                const Gap(4),
                Text(
                  'Tek varlık ≤%${s.riskAppetite.maxSingleAssetPct.toStringAsFixed(0)} · '
                  'Nakit ≥%${s.riskAppetite.minCashPct.toStringAsFixed(0)} · '
                  'Kripto ≤%${s.riskAppetite.maxCryptoTotalPct.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                const Gap(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final app in RiskAppetite.values)
                      ChoiceChip(
                        label: Text('${app.label} (${app.scale.toStringAsFixed(1).replaceAll(".", ",")}×)'),
                        selected: s.riskAppetite == app,
                        onSelected: (_) => controller.updateRiskAppetite(app),
                      ),
                  ],
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  key: const Key('switch_ayar_scan_all_bist'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tüm Borsa İstanbul hisselerini tara'),
                  subtitle: const Text('Açık: 300+ BIST hissesi · Kapalı: BIST 30'),
                  value: s.scanAllBistUniverse,
                  onChanged: controller.toggleScanAllBistUniverse,
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  key: const Key('switch_ayar_scan_only_favorites'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yalnızca favori varlıkları tara'),
                  subtitle: const Text('Kendim Seçeyim: sadece seçili BIST + 10 kripto'),
                  value: s.scanOnlyFavorites,
                  onChanged: controller.toggleScanOnlyFavorites,
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: CardHeader(
                  icon: Icons.palette_outlined,
                  title: 'Görünüm ve pil tasarrufu',
                ),
              ),
              SwitchListTile(
                key: const Key('switch_dark_mode'),
                title: const Text('Koyu Tema (Phantom OLED)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                  'Phantom esintili koyu OLED tema (#08080A, varsayılan açık). Kapatırsanız açık Gündüz temasına geçer.',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                value: s.darkMode,
                onChanged: controller.toggleDarkMode,
              ),
              const Divider(),
              SwitchListTile(
                key: const Key('switch_reduce_animations'),
                title: const Text('Animasyonları Azalt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                  'Açıldığında 3D halka düz 2D çizilir ve geçişler anlık olur.',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                value: s.reduceAnimations,
                onChanged: controller.toggleReduceAnimations,
              ),
              const Divider(),
              SwitchListTile(
                key: const Key('switch_battery_saver'),
                title: const Text('Pil Tasarrufu Modu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                  'Düşük pil tüketimi için 3D gölgelendirmeyi kapatır.',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                value: s.batterySaverMode,
                onChanged: controller.toggleBatterySaver,
              ),
            ],
          ),
        ),
        const Gap(12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeader(
                  icon: Icons.psychology_outlined,
                  title: 'Strateji ve aşırı uyum koruması',
                  trailing: Tag('v${s.activeStrategyVersion}', color: p.accent),
                ),
                const Gap(10),
                Text(
                  state.optimizationProposal.summaryReportTr,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4),
                ),
                if (state.optimizationProposal.statsByStrategy.isNotEmpty) ...[
                  const Gap(8),
                  for (final st in state.optimizationProposal.statsByStrategy.values.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${st.observationNoteTr}',
                        style: TextStyle(fontSize: 11.5, color: p.textDim, height: 1.35),
                      ),
                    ),
                ],
                const Gap(8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: controller.rollbackStrategyVersion,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Önceki Sürüme Dön'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      secondary: [
        const SectionTitle(
          'Bildirimler ve sistem',
          subtitle: 'Yalnızca yerel bildirimler kullanılır; Telegram veya dış mesajlaşma servisi yoktur.',
        ),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: CardHeader(
                  icon: Icons.notifications_outlined,
                  title: 'Yerel bildirim kanalları',
                  trailing: TextButton(
                    onPressed: controller.triggerSampleNotification,
                    child: const Text('Test Et'),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Sinyal Kanalı (Yüksek Önem)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'Kapanmış mum teyitli kurulum ve giriş bölgesi bildirimleri.',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                value: s.notifySignal,
                onChanged: (v) => controller.updateNotificationChannels(signal: v),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Sonuç Kanalı (Yüksek Önem)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '1R/2R hedef, stop ve stopa yakınlık bildirimleri (10 dk birleştirmeli).',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                value: s.notifyOutcome,
                onChanged: (v) => controller.updateNotificationChannels(outcome: v),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Rapor Kanalı (Normal Önem)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'Pazar 09:00 TRT haftalık rapor hazır bildirimi.',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                value: s.notifyReport,
                onChanged: (v) => controller.updateNotificationChannels(report: v),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Sessiz Saatler (23:00 – 08:00 TRT)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'Gece bildirimleri kuyruğa alınır, sabah tek özet olarak gönderilir.',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
                value: s.quietHoursEnabled,
                onChanged: (v) => controller.updateNotificationChannels(quietHoursEnabled: v),
              ),
            ],
          ),
        ),
        const Gap(12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeader(
                  icon: Icons.schedule_outlined,
                  title: 'Arka plan ve pil muafiyeti (K1)',
                  trailing: Tag(
                    sched.batteryOptimizationIgnored ? 'Muafiyet açık' : 'Kısıtlı olabilir',
                    color: sched.batteryOptimizationIgnored ? p.profit : p.neutral,
                  ),
                ),
                const Gap(10),
                Text(
                  'Periyodik tarama: WorkManager (${sched.periodicIntervalMinutes} dk) · '
                  'Pazar raporu: ${Fmt.dateTimeTrt(sched.nextSundayReportUtc)} TRT',
                  style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35),
                ),
                const Gap(2),
                Text(
                  'Sonraki BIST açılış: ${Fmt.dateTimeTrt(sched.nextBistOpenUtc)} · '
                  'Kapanış: ${Fmt.clockTrt(sched.nextBistCloseUtc)} TRT',
                  style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Canlı İzleme Ön Plan Servisi',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Kalıcı bildirimle Doze kısıtlamasına girmeden izler (Android 15 dataSync: 6 saat/24s).',
                    style: TextStyle(fontSize: 12, color: p.textDim),
                  ),
                  value: s.liveMonitorEnabled,
                  onChanged: controller.toggleLiveMonitor,
                ),
                const Gap(6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.requestBatteryExemption,
                      icon: const Icon(Icons.battery_saver_outlined, size: 16),
                      label: const Text('Pil Muafiyeti İste'),
                    ),
                  ],
                ),
                const Gap(10),
                const Divider(),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  title: const Text(
                    'Üretici pil kısıtlaması muafiyet adımları',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  children: [
                    for (final guide in BackgroundScheduler.oemGuides)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${guide.brand}: ${guide.steps}',
                          style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardHeader(
                  icon: Icons.cloud_done_outlined,
                  title: 'Veri kaynakları sağlığı',
                ),
                const Gap(10),
                if (state.providerHealthList.isEmpty)
                  Text(
                    'İlk tarama çalıştığında Binance, Yahoo Finance ve İş Yatırım sağlık ölçütleri burada görünür.',
                    style: TextStyle(fontSize: 12.5, color: p.textDim, height: 1.35),
                  )
                else
                  for (final (i, ph) in state.providerHealthList.indexed) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            ph.healthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                            size: 16,
                            color: ph.healthy ? p.profit : p.coral,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ph.label,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            'Başarılı: ${ph.successCount} · Hata: ${ph.failureCount}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.textDim),
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),
        ),
        const Gap(12),
        _AppUpdateCard(
          settings: s,
          updateState: state.updateState,
          onEditRepo: () => _showRepoDialog(context, controller, s.updateRepo),
          onToggleAutoCheck: controller.toggleAutoCheckUpdates,
          onCheckNow: controller.checkForAppUpdate,
          onDownloadAndInstall: controller.downloadAndInstallUpdate,
        ),
        const Gap(12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeader(
                  icon: Icons.verified_user_outlined,
                  title: 'Gizlilik ve yasal beyanlar',
                  trailing: Tag('Ücretsiz · Sıfır Maliyet', color: p.neutral),
                ),
                const Gap(10),
                Text(
                  '• Gizlilik: Kişisel veri, analitik, konum veya borsa/aracı kurum API anahtarı toplanmaz; '
                  'tüm veriler yalnızca cihazda tutulur.\n'
                  '• Veri Kaynağı ve Lisans: BIST verileri ~15 dk gecikmelidir (Yahoo / İş Yatırım); '
                  'ticari yeniden dağıtım lisans gerektirir.\n'
                  '• Hukuki Not: Yatırım tavsiyesi değildir; Türkiye\'de üçüncü kişilere öneri yayımlamak '
                  'SPK düzenlemelerine tabi olabilir.',
                  style: TextStyle(fontSize: 12, color: p.textDim, height: 1.4),
                ),
                const Gap(12),
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

  Future<void> _showRepoDialog(
    BuildContext context,
    PusulaController controller,
    String currentRepo,
  ) async {
    final textCtrl = TextEditingController(text: currentRepo);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub Releases Deposu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uygulama güncellemelerini kontrol edeceği GitHub deposunu "kullanici/depo" biçiminde yazın:',
              style: TextStyle(fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('field_update_repo'),
              controller: textCtrl,
              decoration: const InputDecoration(
                hintText: 'ornek-kullanici/kripto-trader',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('btn_save_update_repo'),
            onPressed: () {
              controller.updateGitHubRepo(textCtrl.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    textCtrl.dispose();
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

class _AppUpdateCard extends StatelessWidget {
  const _AppUpdateCard({
    required this.settings,
    required this.updateState,
    required this.onEditRepo,
    required this.onToggleAutoCheck,
    required this.onCheckNow,
    required this.onDownloadAndInstall,
  });

  final AppSettings settings;
  final AppUpdateState updateState;
  final VoidCallback onEditRepo;
  final ValueChanged<bool> onToggleAutoCheck;
  final VoidCallback onCheckNow;
  final VoidCallback onDownloadAndInstall;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final status = updateState.status;
    final rel = updateState.availableRelease;
    final busy = status == UpdateStatus.checking || status == UpdateStatus.downloading;
    final repoText = settings.updateRepo.isEmpty ? 'Tanımlı değil' : settings.updateRepo;

    return Card(
      key: const Key('card_app_update'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(
              icon: Icons.system_update_outlined,
              title: 'Uygulama güncelleme (GitHub Releases)',
              trailing: Tag(updateState.currentVersion.label, color: p.accent),
            ),
            const Gap(10),
            Text(
              kIsWeb
                  ? 'Web sürümü sayfa yenilendiğinde otomatik güncellenir; Android APK güncellemeleri GitHub Releases üzerinden indirilir.'
                  : 'Yeni sürüm yayımlandığında tek dokunuşla APK indirilir ve verilerin korunarak üzerine kurulur.',
              style: TextStyle(fontSize: 12, color: p.textDim, height: 1.35),
            ),
            const Gap(10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Depo: $repoText',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  key: const Key('btn_configure_update_repo'),
                  onPressed: onEditRepo,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(settings.updateRepo.isEmpty ? 'Depo Ekle' : 'Değiştir'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Açılışta Otomatik Denetle',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Depo tanımlıysa açılışta sessizce yeni sürüm kontrol edilir.',
                style: TextStyle(fontSize: 12, color: p.textDim),
              ),
              value: settings.autoCheckUpdates,
              onChanged: onToggleAutoCheck,
            ),
            if (updateState.message != null) ...[
              const Gap(6),
              Text(
                updateState.message!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: status == UpdateStatus.error
                      ? p.loss
                      : (status == UpdateStatus.available || status == UpdateStatus.readyToInstall
                          ? p.accent
                          : p.textDim),
                ),
              ),
            ],
            if (status == UpdateStatus.downloading) ...[
              const Gap(8),
              MeterBar(fraction: updateState.downloadProgress ?? 0.0, color: p.accent),
            ],
            if (!kIsWeb) ...[
              const Gap(10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('btn_check_app_update'),
                    onPressed: busy ? null : onCheckNow,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Güncellemeyi Kontrol Et'),
                  ),
                  if (rel != null &&
                      (status == UpdateStatus.available ||
                          status == UpdateStatus.permissionRequired ||
                          status == UpdateStatus.readyToInstall))
                    FilledButton.icon(
                      key: const Key('btn_download_app_update'),
                      onPressed: onDownloadAndInstall,
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text(
                        status == UpdateStatus.permissionRequired
                            ? 'İzni Verdim, Kur'
                            : 'İndir ve Güncelle (${rel.version.label})',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
