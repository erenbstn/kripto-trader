import 'package:flutter/material.dart';

/// "GÜNDÜZ" görsel tasarım belirteçleri (K4). Palet sabittir; K10 ile bileşen dili yenilendi.
class GunduzColors {
  const GunduzColors._();

  // Açık tema ("GÜNDÜZ" varsayılan)
  static const Color background = Color(0xFFF6F4EF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF5A5852);
  static const Color accent = Color(0xFF5B4BDB);
  static const Color accentDark = Color(0xFF3B2FA8);
  static const Color coral = Color(0xFFD85A30);
  static const Color border = Color(0xFFE2DDD3);
  static const Color subtleSurface = Color(0xFFEDEAE2);

  // Koyu tema karşılıkları
  static const Color darkBackground = Color(0xFF141418);
  static const Color darkCard = Color(0xFF1E1E24);
  static const Color darkTextPrimary = Color(0xFFF3F1EC);
  static const Color darkTextSecondary = Color(0xFFA9A69E);
  static const Color darkBorder = Color(0xFF2E2E38);
  static const Color darkSubtleSurface = Color(0xFF25252E);

  // Kazanç / zarar renkleri (her zaman + / - işareti ve metinle birlikte kullanılır)
  static const Color profitGreen = Color(0xFF1E7E48);
  static const Color lossRed = Color(0xFFB83227);
  static const Color neutralSlate = Color(0xFF6B7280);
}

/// Temaya (açık/koyu) göre çözümlenmiş renk seti. Bileşenler renkleri buradan okur;
/// böylece koyu temada metin/zemin karşıtlığı tek yerden korunur.
class PusulaPalette {
  const PusulaPalette._({
    required this.isDark,
    required this.background,
    required this.card,
    required this.subtle,
    required this.border,
    required this.text,
    required this.textDim,
    required this.accent,
    required this.accentSoft,
    required this.coral,
    required this.profit,
    required this.loss,
    required this.neutral,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color subtle;
  final Color border;
  final Color text;
  final Color textDim;

  /// Metin ve ikon için vurgu (koyu temada daha açık ton: okunabilirlik).
  final Color accent;
  final Color accentSoft;
  final Color coral;
  final Color profit;
  final Color loss;
  final Color neutral;

  static const PusulaPalette light = PusulaPalette._(
    isDark: false,
    background: GunduzColors.background,
    card: GunduzColors.card,
    subtle: GunduzColors.subtleSurface,
    border: GunduzColors.border,
    text: GunduzColors.textPrimary,
    textDim: GunduzColors.textSecondary,
    accent: GunduzColors.accent,
    accentSoft: Color(0xFFECE9FB),
    coral: GunduzColors.coral,
    profit: GunduzColors.profitGreen,
    loss: GunduzColors.lossRed,
    neutral: GunduzColors.neutralSlate,
  );

  static const PusulaPalette dark = PusulaPalette._(
    isDark: true,
    background: GunduzColors.darkBackground,
    card: GunduzColors.darkCard,
    subtle: GunduzColors.darkSubtleSurface,
    border: GunduzColors.darkBorder,
    text: GunduzColors.darkTextPrimary,
    textDim: GunduzColors.darkTextSecondary,
    accent: Color(0xFFA197F2),
    accentSoft: Color(0xFF2B2850),
    coral: Color(0xFFEF8257),
    profit: Color(0xFF52C48B),
    loss: Color(0xFFF0776B),
    neutral: Color(0xFF9CA3AF),
  );

  static PusulaPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Boşluk ve ölçü belirteçleri (4'lük ızgara).
class PusulaSpace {
  const PusulaSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Bu genişlikten itibaren geniş (masaüstü / web) yerleşim kullanılır.
  static const double wideBreakpoint = 900;

  /// Geniş yerleşimde içerik sütununun en fazla genişliği.
  static const double maxContentWidth = 1240;
}

class GunduzTheme {
  const GunduzTheme._();

  static const double cardRadius = 16.0;

  static ThemeData light() => _build(PusulaPalette.light);
  static ThemeData dark() => _build(PusulaPalette.dark);

  static ThemeData _build(PusulaPalette p) {
    final scheme = (p.isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: GunduzColors.accent,
      onPrimary: Colors.white,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.accent,
      secondary: GunduzColors.coral,
      onSecondary: Colors.white,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: p.accent,
      surface: p.card,
      onSurface: p.text,
      onSurfaceVariant: p.textDim,
      surfaceContainerHighest: p.subtle,
      outline: p.border,
      outlineVariant: p.border,
      error: p.loss,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      dividerColor: p.border,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: p.text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentSoft,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? p.accent : p.textDim, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.accent : p.textDim,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.card,
        indicatorColor: p.accentSoft,
        selectedIconTheme: IconThemeData(color: p.accent),
        unselectedIconTheme: IconThemeData(color: p.textDim),
        selectedLabelTextStyle: TextStyle(color: p.accent, fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelTextStyle: TextStyle(color: p.textDim, fontWeight: FontWeight.w500, fontSize: 13),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.accentSoft : p.card,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.accent : p.textDim,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.card,
        selectedColor: p.accentSoft,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : p.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? GunduzColors.accent : p.subtle,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.border),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GunduzColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(48, 44),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textDim,
        subtitleTextStyle: TextStyle(fontSize: 12, color: p.textDim, height: 1.3),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: GunduzColors.accent,
        linearTrackColor: p.subtle,
      ),
    );
  }
}

/// Her analiz ve rapor ekranında sabit görünmesi zorunlu uyarı şeridi (Kısıt 7, K6).
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: p.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 16, color: p.coral),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Yatırım tavsiyesi değildir. ',
                      style: TextStyle(fontWeight: FontWeight.w800, color: p.text),
                    ),
                    const TextSpan(text: 'Pusula emir açmaz, anahtar kullanmaz; yalnızca yerel analiz üretir.'),
                  ],
                ),
                style: TextStyle(fontSize: 12, height: 1.3, color: p.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Veri kaynağını, gecikmesini ve bayatlığını gösteren rozet (K2).
class DataProvenanceBadge extends StatelessWidget {
  const DataProvenanceBadge({
    super.key,
    required this.sourceLabel,
    required this.ageMinutes,
    required this.isStale,
  });

  final String sourceLabel;
  final int ageMinutes;
  final bool isStale;

  static String sourceName(String raw) {
    switch (raw) {
      case 'binance':
        return 'Binance Spot';
      case 'binance_futures':
        return 'Binance Futures';
      case 'yahoo':
        return 'Yahoo Finance';
      case 'isyatirim':
        return 'İş Yatırım';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final String ageText;
    if (ageMinutes <= 1) {
      ageText = 'canlı (<1 dk)';
    } else if (ageMinutes < 120) {
      ageText = 'veri $ageMinutes dk gecikmeli';
    } else if (ageMinutes < 2880) {
      ageText = 'veri ${(ageMinutes / 60).round()} sa önce';
    } else {
      ageText = 'veri ${(ageMinutes / 1440).round()} gün önce';
    }
    final color = isStale ? p.coral : p.textDim;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isStale ? Icons.warning_amber_rounded : Icons.schedule, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${isStale ? 'BAYAT · ' : ''}$ageText · ${sourceName(sourceLabel)}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isStale ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kazanç / zarar değerini her zaman `+`/`-` işareti ve metinle birlikte gösteren etiket (K4).
class SignedMetricChip extends StatelessWidget {
  const SignedMetricChip({
    super.key,
    required this.value,
    required this.suffix,
    this.decimals = 1,
    this.prefix = '',
  });

  final double value;
  final String suffix;
  final int decimals;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final isPositive = value > 0;
    final isNegative = value < 0;
    final sign = isPositive ? '+' : (isNegative ? '-' : '±');
    final absStr = value.abs().toStringAsFixed(decimals).replaceAll('.', ',');
    final statusWord = isPositive ? 'Kazanç' : (isNegative ? 'Kayıp' : 'Başabaş');
    final color = isPositive ? p.profit : (isNegative ? p.loss : p.neutral);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : (isNegative ? Icons.arrow_downward : Icons.remove),
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '$sign$prefix$absStr$suffix ($statusWord)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
