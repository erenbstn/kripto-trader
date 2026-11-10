import 'package:flutter/material.dart';

/// "GÜNDÜZ" görsel tasarım belirteçleri (K4, Kısıt 10 — sabit).
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

class GunduzTheme {
  const GunduzTheme._();

  static const double cardRadius = 14.0;

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: GunduzColors.accent,
      onPrimary: Colors.white,
      secondary: GunduzColors.coral,
      onSecondary: Colors.white,
      surface: GunduzColors.card,
      onSurface: GunduzColors.textPrimary,
      error: GunduzColors.lossRed,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: GunduzColors.background,
      dividerColor: GunduzColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: GunduzColors.background,
        foregroundColor: GunduzColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: GunduzColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: GunduzColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: GunduzColors.border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GunduzColors.card,
        indicatorColor: GunduzColors.accent.withValues(alpha: 0.14),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? GunduzColors.accentDark : GunduzColors.textSecondary,
          );
        }),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: GunduzColors.accent,
      onPrimary: Colors.white,
      secondary: GunduzColors.coral,
      onSecondary: Colors.white,
      surface: GunduzColors.darkCard,
      onSurface: GunduzColors.darkTextPrimary,
      error: Color(0xFFE05A4F),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: GunduzColors.darkBackground,
      dividerColor: GunduzColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: GunduzColors.darkBackground,
        foregroundColor: GunduzColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: GunduzColors.darkTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: GunduzColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: GunduzColors.darkBorder, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GunduzColors.darkCard,
        indicatorColor: GunduzColors.accent.withValues(alpha: 0.28),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : GunduzColors.darkTextSecondary,
          );
        }),
      ),
    );
  }
}

/// Her analiz ve rapor ekranında sabit görünmesi zorunlu uyarı şeridi (Kısıt 7, K6).
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? GunduzColors.darkSubtleSurface : GunduzColors.subtleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? GunduzColors.darkBorder : GunduzColors.border,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: GunduzColors.coral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Yatırım tavsiyesi değildir · Sistem emir açmaz ve aracı kurum anahtarı kullanmaz; yalnızca yerel analiz üretir.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? GunduzColors.darkTextPrimary : GunduzColors.textPrimary,
              ),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ageText = ageMinutes <= 1 ? 'canlı (<1 dk)' : 'veri $ageMinutes dk gecikmeli';
    final stalePrefix = isStale ? 'BAYAT · ' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isStale
            ? GunduzColors.coral.withValues(alpha: 0.14)
            : (isDark ? GunduzColors.darkSubtleSurface : GunduzColors.subtleSurface),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isStale
              ? GunduzColors.coral
              : (isDark ? GunduzColors.darkBorder : GunduzColors.border),
        ),
      ),
      child: Text(
        '$stalePrefix$ageText · $sourceLabel',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isStale ? FontWeight.w700 : FontWeight.w500,
          color: isStale
              ? GunduzColors.coral
              : (isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary),
        ),
      ),
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
    final isPositive = value > 0;
    final isNegative = value < 0;
    final sign = isPositive ? '+' : (isNegative ? '-' : '±');
    final absStr = value.abs().toStringAsFixed(decimals).replaceAll('.', ',');
    final statusWord = isPositive ? 'Kazanç' : (isNegative ? 'Kayıp' : 'Başabaş');
    final color = isPositive
        ? GunduzColors.profitGreen
        : (isNegative ? GunduzColors.lossRed : GunduzColors.neutralSlate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$sign$prefix$absStr$suffix ($statusWord)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

