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

  // Koyu tema karşılıkları (Phantom OLED paleti)
  static const Color darkBackground = Color(0xFF08080A);
  static const Color darkCard = Color(0xFF16161C);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFF8E8E99);
  static const Color darkBorder = Color(0xFF24242E);
  static const Color darkSubtleSurface = Color(0xFF1F1F28);
  static const Color phantomLavender = Color(0xFFAB9FF2);

  // Kazanç / zarar renkleri (her zaman + / - işareti ve metinle birlikte kullanılır)
  static const Color profitGreen = Color(0xFF26D07C);
  static const Color lossRed = Color(0xFFF2545B);
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
    accent: GunduzColors.phantomLavender,
    accentSoft: Color(0xFF231F38),
    coral: Color(0xFF38BDF8),
    profit: Color(0xFF26D07C),
    loss: Color(0xFFF2545B),
    neutral: Color(0xFF8E8E99),
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

  static const double cardRadius = 20.0;

  static ThemeData light() => _build(PusulaPalette.light);
  static ThemeData dark() => _build(PusulaPalette.dark);

  static ThemeData _build(PusulaPalette p) {
    final primaryAccent = p.isDark ? p.accent : GunduzColors.accent;
    final onPrimaryColor = p.isDark ? const Color(0xFF08080A) : Colors.white;
    final scheme = (p.isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: primaryAccent,
      onPrimary: onPrimaryColor,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.accent,
      secondary: p.coral,
      onSecondary: onPrimaryColor,
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
          side: BorderSide(color: p.isDark ? p.border.withValues(alpha: 0.55) : p.border, width: 1),
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
        backgroundColor: p.isDark ? p.background : p.card,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onPrimaryColor : p.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primaryAccent : p.subtle,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.border),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: onPrimaryColor,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(48, 44),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryAccent,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.isDark ? const Color(0xFF111116) : p.subtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border.withValues(alpha: p.isDark ? 0.55 : 1.0)),
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
                      text: 'Sadece Spot · Yatırım tavsiyesi değildir',
                      style: TextStyle(fontWeight: FontWeight.w800, color: p.text),
                    ),
                    const TextSpan(text: ' · Emir açmaz'),
                  ],
                ),
                style: TextStyle(fontSize: 11.5, height: 1.25, color: p.textDim),
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
      case 'binance_spot':
        return 'Binance Spot';
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
