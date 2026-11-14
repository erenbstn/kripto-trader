import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pusula_core/pusula_core.dart';

import '../theme/gunduz_theme.dart';

/// Türkçe sayı, fiyat ve zaman biçimlendiricileri (ondalık virgül, binlik nokta).
class Fmt {
  const Fmt._();

  static String number(double v, {int decimals = 2}) {
    final neg = v < 0;
    final fixed = v.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    final dec = parts.length > 1 ? ',${parts[1]}' : '';
    return '${neg ? '-' : ''}$buf$dec';
  }

  /// Piyasa ve büyüklüğe göre anlamlı basamak sayısıyla fiyat.
  static String price(double v, Market market) {
    if (market == Market.bist) return number(v, decimals: 2);
    final a = v.abs();
    final d = a >= 1000 ? 0 : (a >= 100 ? 2 : (a >= 1 ? 3 : (a >= 0.01 ? 4 : 6)));
    return number(v, decimals: d);
  }

  static String currency(Market market) => market == Market.bist ? 'TL' : 'USD';

  /// Piyasa para birimi simgesi: BIST → ₺, Kripto → $.
  static String currencySymbol(Market market) => market == Market.bist ? '₺' : '\$';

  /// Para birimi simgesiyle biçimlendirilmiş fiyat: BIST → ₺313,75, Kripto → $73.506.
  static String priceWithCurrency(double v, Market market) => '${currencySymbol(market)}${price(v, market)}';

  /// `%12,5` biçimi; [signed] ise `+%1,2` / `-%0,8`.
  static String pct(double v, {int decimals = 1, bool signed = false}) {
    final body = '%${number(v.abs(), decimals: decimals)}';
    if (!signed) return v < 0 ? '-$body' : body;
    if (v > 0) return '+$body';
    if (v < 0) return '-$body';
    return body;
  }

  static String r(double v, {int decimals = 2}) =>
      '${v > 0 ? '+' : (v < 0 ? '-' : '')}${number(v.abs(), decimals: decimals)}R';

  static String tl(double v) => '${number(v, decimals: 0)} TL';

  static String currencyTry(double v, {int decimals = 0}) => '₺${number(v, decimals: decimals)}';

  static String ago(DateTime t, DateTime now) {
    final d = now.toUtc().difference(t.toUtc());
    if (d.inMinutes < 1) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 48) return '${d.inHours} sa önce';
    return '${d.inDays} gün önce';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Türkiye saatiyle `12.11 14:05`.
  static String dateTimeTrt(DateTime utc) {
    final t = BistCalendar.toTrt(utc);
    return '${_two(t.day)}.${_two(t.month)} ${_two(t.hour)}:${_two(t.minute)}';
  }

  /// Türkiye saatiyle `12.11.2026`.
  static String dateTrt(DateTime utc) {
    final t = BistCalendar.toTrt(utc);
    return '${_two(t.day)}.${_two(t.month)}.${t.year}';
  }

  static String clockTrt(DateTime utc) {
    final t = BistCalendar.toTrt(utc);
    return '${_two(t.hour)}:${_two(t.minute)}';
  }
}

/// Ekran genişliği geniş (masaüstü / web) yerleşim gerektiriyor mu?
bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= PusulaSpace.wideBreakpoint;

/// Sayfa gövdesi: telefonda tek sütun kaydırma listesi, geniş ekranda iki sütunlu pano.
///
/// Telefonda [primary] ardından [secondary] sırayla dizilir (bilgi hiyerarşisi korunur).
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.primaryFlex = 6,
    this.secondaryFlex = 5,
  });

  final List<Widget> primary;
  final List<Widget> secondary;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= PusulaSpace.wideBreakpoint - 96;
        if (!wide || secondary.isEmpty) {
          final list = ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
            children: [...primary, ...secondary],
          );
          if (!wide) return list;
          return Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: list),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 64),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PusulaSpace.maxContentWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: primaryFlex,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: primary),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: secondaryFlex,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: secondary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dikey boşluk kısayolu.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}

/// Bölüm başlığı: başlık + isteğe bağlı açıklama ve sağda eylem.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: p.textDim, height: 1.3)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Küçük renkli etiket.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, required this.color, this.icon, this.filled = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

/// Piyasa etiketi: BIST mor, kripto mercan (renk + metin birlikte).
class MarketTag extends StatelessWidget {
  const MarketTag(this.market, {super.key});
  final Market market;

  static Color colorOf(BuildContext context, Market m) {
    final p = PusulaPalette.of(context);
    return m == Market.bist ? p.accent : p.coral;
  }

  @override
  Widget build(BuildContext context) =>
      Tag(market == Market.bist ? 'BIST' : 'KRİPTO', color: colorOf(context, market));
}

/// Etiket + değer çifti (küçük ölçü kutusu).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.big = false,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: p.textDim, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 20 : 14,
            fontWeight: FontWeight.w800,
            color: valueColor ?? p.text,
            letterSpacing: big ? -0.4 : 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (hint != null) Text(hint!, style: TextStyle(fontSize: 11, color: p.textDim)),
      ],
    );
  }
}

/// 0–100 güven skoru halkası. Renk tek başına anlam taşımaz: sayı her zaman ortada yazar.
class ConfidenceRing extends StatelessWidget {
  const ConfidenceRing({super.key, required this.score, this.size = 52});

  final int score;
  final double size;

  static Color colorFor(PusulaPalette p, int score) =>
      score >= 75 ? p.profit : (score >= 60 ? p.accent : p.coral);

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final color = colorFor(p, score);
    return Semantics(
      label: 'Güven skoru $score / 100',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(fraction: score / 100.0, color: color, track: p.subtle),
          child: Center(
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w800, height: 1.0, color: p.text),
                  ),
                  Text('güven', style: TextStyle(fontSize: size * 0.17, color: p.textDim, height: 1.1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, paint);
    paint.color = color;
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// Stop → giriş → 1R → 2R fiyat merdiveni. Riski (kırmızı) ve ödülü (yeşil) aynı ölçekte gösterir;
/// varsa güncel fiyatı işaretler. Değerler altta metin olarak da yazılır (yalnız renge dayanmaz).
class PriceLadder extends StatelessWidget {
  const PriceLadder({
    super.key,
    required this.market,
    required this.stop,
    required this.entry,
    required this.target1,
    required this.target2,
    this.current,
  });

  final Market market;
  final double stop;
  final double entry;
  final double target1;
  final double target2;
  final double? current;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    Widget label(String title, double value, Color color, CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            Text(
              Fmt.priceWithCurrency(value, market),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: p.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );

    return Semantics(
      label: 'Stop ${Fmt.priceWithCurrency(stop, market)}, giriş ${Fmt.priceWithCurrency(entry, market)}, '
          'birinci hedef ${Fmt.priceWithCurrency(target1, market)}, ana hedef ${Fmt.priceWithCurrency(target2, market)}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              width: double.infinity,
              child: CustomPaint(
                painter: _LadderPainter(
                  stop: stop,
                  entry: entry,
                  target1: target1,
                  target2: target2,
                  current: current,
                  loss: p.loss,
                  profit: p.profit,
                  marker: p.text,
                  card: p.card,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                label('STOP', stop, p.loss, CrossAxisAlignment.start),
                label('GİRİŞ', entry, p.textDim, CrossAxisAlignment.center),
                label('HEDEF 1', target1, p.profit, CrossAxisAlignment.center),
                label('HEDEF 2', target2, p.profit, CrossAxisAlignment.end),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  _LadderPainter({
    required this.stop,
    required this.entry,
    required this.target1,
    required this.target2,
    required this.current,
    required this.loss,
    required this.profit,
    required this.marker,
    required this.card,
  });

  final double stop;
  final double entry;
  final double target1;
  final double target2;
  final double? current;
  final Color loss;
  final Color profit;
  final Color marker;
  final Color card;

  @override
  void paint(Canvas canvas, Size size) {
    final span = target2 - stop;
    if (span <= 0 || size.width <= 0) return;
    double x(double price) => ((price - stop) / span).clamp(0.0, 1.0) * size.width;

    final cy = size.height / 2;
    const h = 8.0;
    final xe = x(entry);
    final r = const Radius.circular(4);

    canvas.drawRRect(
      RRect.fromLTRBAndCorners(0, cy - h / 2, xe, cy + h / 2, topLeft: r, bottomLeft: r),
      Paint()..color = loss.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(xe, cy - h / 2, size.width, cy + h / 2, topRight: r, bottomRight: r),
      Paint()..color = profit.withValues(alpha: 0.75),
    );

    // Giriş ve 1. hedef çentikleri
    final tick = Paint()
      ..color = card
      ..strokeWidth = 2;
    canvas.drawLine(Offset(xe, cy - h / 2), Offset(xe, cy + h / 2), tick);
    final x1 = x(target1);
    canvas.drawLine(Offset(x1, cy - h / 2), Offset(x1, cy + h / 2), tick);

    // Güncel fiyat işareti
    final cur = current;
    if (cur != null && cur > 0) {
      final xc = x(cur);
      canvas.drawCircle(Offset(xc, cy), 6.5, Paint()..color = card);
      canvas.drawCircle(Offset(xc, cy), 4.5, Paint()..color = marker);
    }
  }

  @override
  bool shouldRepaint(covariant _LadderPainter old) =>
      old.stop != stop ||
      old.entry != entry ||
      old.target1 != target1 ||
      old.target2 != target2 ||
      old.current != current ||
      old.loss != loss ||
      old.profit != profit ||
      old.marker != marker;
}

/// Yatay doluluk çubuğu (ör. açık risk / sınır). Animasyonsuz çizilir.
class MeterBar extends StatelessWidget {
  const MeterBar({super.key, required this.fraction, required this.color, this.height = 6});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.subtle)),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: color, child: const SizedBox.expand()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Güven skorunun altı bileşenini (ve varsa kalite düzeltmesini) çubuklarla gösterir.
class ConfidenceBars extends StatelessWidget {
  const ConfidenceBars({super.key, required this.breakdown});

  final ConfidenceBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final rows = <(String, int, int)>[
      ('Kurulum çakışması', breakdown.setupConfluence, 25),
      ('Hacim teyidi', breakdown.volumeConfirmation, 15),
      ('Piyasa rejimi', breakdown.regimeAlignment, 15),
      ('Üst dilim uyumu', breakdown.higherTimeframeAlignment, 15),
      ('Monte Carlo', breakdown.monteCarloScore, 15),
      ('Ödül / Risk (net)', breakdown.rewardRiskScore, 15),
    ];
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 124,
                  child: Text(r.$1, style: TextStyle(fontSize: 12, color: p.textDim)),
                ),
                Expanded(child: MeterBar(fraction: r.$3 == 0 ? 0 : r.$2 / r.$3, color: p.accent)),
                SizedBox(
                  width: 50,
                  child: Text(
                    '+${r.$2}/${r.$3}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        if (breakdown.qualityAdjustment != 0)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kalite düzeltmesi (veri yaşı, maliyet, aşırı ısınma)',
                  style: TextStyle(fontSize: 12, color: p.textDim),
                ),
              ),
              Text(
                '${breakdown.qualityAdjustment}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.loss),
              ),
            ],
          ),
      ],
    );
  }
}

/// Boş durum kutusu: neden boş olduğunu ve ne olacağını söyler.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: p.subtle, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 20, color: p.textDim),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(body!, style: TextStyle(fontSize: 12.5, color: p.textDim, height: 1.35)),
                  ],
                  if (action != null) ...[const SizedBox(height: 10), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Piyasa rejimi etiketi (Boğa / Yatay / Ayı) — ikon + metin.
class RegimeChip extends StatelessWidget {
  const RegimeChip({super.key, required this.marketLabel, required this.regime});

  final String marketLabel;
  final MarketRegime regime;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final (Color color, IconData icon) = switch (regime) {
      MarketRegime.bull => (p.profit, Icons.trending_up),
      MarketRegime.sideways => (p.neutral, Icons.trending_flat),
      MarketRegime.bear => (p.loss, Icons.trending_down),
    };
    return Tag('$marketLabel: ${regime.label}', color: color, icon: icon);
  }
}

/// 100 bazlı performans eğrisi için sade çizgi grafik (ızgara ve animasyon yok).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.height = 72});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final up = values.isEmpty || values.last >= 100.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values: values, line: up ? p.profit : p.loss, base: p.border),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.line, required this.base});
  final List<double> values;
  final Color line;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    // Eğri her zaman 100 tabanından başlar.
    final pts = [100.0, ...values];
    var lo = pts.reduce(math.min);
    var hi = pts.reduce(math.max);
    if (hi - lo < 1.0) {
      hi += 0.5;
      lo -= 0.5;
    }
    double y(double v) => size.height - 4 - ((v - lo) / (hi - lo)) * (size.height - 8);
    double x(int i) => pts.length == 1 ? 0 : i / (pts.length - 1) * size.width;

    final dash = Paint()
      ..color = base
      ..strokeWidth = 1;
    final yBase = y(100.0);
    for (var dx = 0.0; dx < size.width; dx += 8) {
      canvas.drawLine(Offset(dx, yBase), Offset(math.min(dx + 4, size.width), yBase), dash);
    }

    final path = Path()..moveTo(x(0), y(pts[0]));
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(x(i), y(pts[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x(pts.length - 1), y(pts.last)), 3.5, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.line != line;
}

/// Kart içi başlık satırı: ikon rozeti + başlık + isteğe bağlı sağ öğe.
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.icon, required this.title, this.trailing, this.color});

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final c = color ?? p.accent;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.1)),
        ),
        ?trailing,
      ],
    );
  }
}

/// Phantom tarzı dairesel varlık (BIST hisse / Kripto) simgesi.
class SymbolAvatarBadge extends StatelessWidget {
  const SymbolAvatarBadge({
    super.key,
    required this.instrument,
    this.size = 42,
  });

  final Instrument instrument;
  final double size;

  static Color badgeColor(Instrument ins) {
    final s = ins.symbol.toUpperCase();
    if (s.startsWith('BTC')) return const Color(0xFFF7931A);
    if (s.startsWith('ETH')) return const Color(0xFF627EEA);
    if (s.startsWith('SOL')) return const Color(0xFF14F195);
    if (s.startsWith('XRP')) return const Color(0xFF25A768);
    if (s.startsWith('BNB')) return const Color(0xFFF3BA2F);
    if (s.startsWith('LINK')) return const Color(0xFF375BD2);
    if (s.startsWith('AVAX')) return const Color(0xFFE84142);
    if (ins.market == Market.bist) {
      const bistPalette = [
        Color(0xFFAB9FF2),
        Color(0xFF38BDF8),
        Color(0xFF818CF8),
        Color(0xFF2DD4BF),
        Color(0xFFC084FC),
      ];
      return bistPalette[s.hashCode.abs() % bistPalette.length];
    }
    const cryptoPalette = [
      Color(0xFF26D07C),
      Color(0xFF38BDF8),
      Color(0xFFA78BFA),
      Color(0xFFFB923C),
    ];
    return cryptoPalette[s.hashCode.abs() % cryptoPalette.length];
  }

  static String glyphFor(Instrument ins) {
    final s = ins.short.toUpperCase();
    if (s == 'BTC') return '₿';
    if (s == 'ETH') return 'Ξ';
    if (s == 'SOL') return '◎';
    return s.length <= 3 ? s : s.substring(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final bg = badgeColor(instrument);
    final glyph = glyphFor(instrument);
    final darkInk = bg.computeLuminance() > 0.45 ? const Color(0xFF08080A) : Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg.withValues(alpha: p.isDark ? 0.92 : 0.95),
            ),
            alignment: Alignment.center,
            child: Text(
              glyph,
              maxLines: 1,
              style: TextStyle(
                fontSize: glyph.length == 1 ? size * 0.48 : size * 0.28,
                fontWeight: FontWeight.w800,
                color: darkInk,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: instrument.market == Market.bist ? p.accent : p.coral,
                border: Border.all(color: p.background, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Öneri ve sinyaller için zaman ufku (Sadece Spot).
enum InvestmentHorizon {
  daily('Günlük', 'Gün İçi · Spot'),
  weekly('Haftalık', '1 Hafta · Spot'),
  multiWeek('Birkaç Haftalık', '2–4 Hafta · Spot'),
  monthlyLong('Aylık / Uzun Vade', '1+ Ay · Spot');

  const InvestmentHorizon(this.label, this.shortDesc);

  final String label;
  final String shortDesc;
}

/// Bir sinyali/öneriyi günlük, haftalık, birkaç haftalık veya aylık/uzun vade sınıfına ayırır.
InvestmentHorizon classifyHorizon(SignalRecord s) {
  if (!s.isWeeklyProposal) {
    return InvestmentHorizon.daily;
  }
  if (s.strategy == SetupType.breakout20 &&
      (s.interval == BarInterval.d1 || s.instrument.symbol == 'BTCUSDT' || s.instrument.symbol == 'PAXGUSDT')) {
    return InvestmentHorizon.monthlyLong;
  }
  if (s.strategy == SetupType.reclaimMa20 ||
      (s.strategy == SetupType.bullFlag && (s.interval == BarInterval.h4 || s.interval == BarInterval.d1))) {
    return InvestmentHorizon.multiWeek;
  }
  return InvestmentHorizon.weekly;
}

/// Bütçeye göre kesin TL alım tutarı ve alınacak/satılacak adet planı (Sadece Spot).
class OrderSizingPlan {
  const OrderSizingPlan({
    required this.market,
    required this.horizon,
    required this.allocatedTry,
    required this.buyQuantity,
    required this.sellQtyTarget1,
    required this.sellQtyTarget2,
    required this.stopQty,
    required this.entryPrice,
    required this.target1,
    required this.target2,
    required this.stopPrice,
  });

  final Market market;
  final InvestmentHorizon horizon;
  final double allocatedTry;
  final double buyQuantity;
  final double sellQtyTarget1;
  final double sellQtyTarget2;
  final double stopQty;
  final double entryPrice;
  final double target1;
  final double target2;
  final double stopPrice;

  static OrderSizingPlan fromSignal({
    required SignalRecord signal,
    required double allocatedTry,
    required double usdTryRate,
  }) {
    final m = signal.instrument.market;
    final entry = signal.entryPrice;
    final safeTry = allocatedTry < 0 ? 0.0 : allocatedTry;
    double buyQty = 0.0;
    double t1Qty = 0.0;
    double t2Qty = 0.0;

    if (entry > 0 && safeTry > 0) {
      if (m == Market.bist) {
        buyQty = (safeTry / entry).floorToDouble();
        if (buyQty >= 2) {
          t1Qty = (buyQty / 2).ceilToDouble();
          t2Qty = math.max(0.0, buyQty - t1Qty);
        } else {
          t1Qty = buyQty;
          t2Qty = 0.0;
        }
      } else {
        final rate = usdTryRate > 0 ? usdTryRate : 36.50;
        final usdBudget = safeTry / rate;
        buyQty = usdBudget / entry;
        t1Qty = buyQty * 0.5;
        t2Qty = buyQty * 0.5;
      }
    }

    return OrderSizingPlan(
      market: m,
      horizon: classifyHorizon(signal),
      allocatedTry: safeTry,
      buyQuantity: buyQty,
      sellQtyTarget1: t1Qty,
      sellQtyTarget2: t2Qty,
      stopQty: buyQty,
      entryPrice: entry,
      target1: signal.target1,
      target2: signal.target2,
      stopPrice: signal.initialStop,
    );
  }

  static String formatQty(double q, Market m, {String? unit}) {
    final u = unit ?? 'adet';
    if (q <= 0) return '0 $u';
    if (m == Market.bist) {
      return '${Fmt.number(q.roundToDouble(), decimals: 0)} $u';
    }
    final decimals = q >= 100 ? 1 : (q >= 1 ? 2 : (q >= 0.01 ? 4 : 5));
    return '${Fmt.number(q, decimals: decimals)} $u';
  }

  String qtyBuyLabel({String? unit}) => formatQty(buyQuantity, market, unit: unit);
  String qtyT1Label({String? unit}) => formatQty(sellQtyTarget1, market, unit: unit);
  String qtyT2Label({String? unit}) => formatQty(sellQtyTarget2, market, unit: unit);
  String qtyStopLabel({String? unit}) => formatQty(stopQty, market, unit: unit);
}

/// Toplam bütçeyi uzun/haftalık portföy, günlük kalan limit ve nakit koruma arasında böler.
class HorizonBudgetBreakdown {
  const HorizonBudgetBreakdown({
    required this.totalBudgetTry,
    required this.weeklyTry,
    required this.multiWeekTry,
    required this.monthlyLongTry,
    required this.mainInvestedTry,
    required this.remainingPoolTry,
    required this.dailyLimitTry,
    required this.dailyPerSignalTry,
    required this.cashReserveTry,
    required this.dailySignalsCount,
    required this.weeklyCount,
    required this.multiWeekCount,
    required this.monthlyLongCount,
  });

  final double totalBudgetTry;
  final double weeklyTry;
  final double multiWeekTry;
  final double monthlyLongTry;
  final double mainInvestedTry;
  final double remainingPoolTry;
  final double dailyLimitTry;
  final double dailyPerSignalTry;
  final double cashReserveTry;
  final int dailySignalsCount;
  final int weeklyCount;
  final int multiWeekCount;
  final int monthlyLongCount;

  static HorizonBudgetBreakdown compute({
    required double totalBudget,
    required PortfolioAllocationResult allocation,
    required List<SignalRecord> activeDailySignals,
  }) {
    var wTry = 0.0;
    var mwTry = 0.0;
    var mlTry = 0.0;
    var wCnt = 0;
    var mwCnt = 0;
    var mlCnt = 0;

    for (final rec in allocation.recommendations) {
      final tryAmt = totalBudget * rec.weightPct / 100.0;
      switch (classifyHorizon(rec.signal)) {
        case InvestmentHorizon.daily:
        case InvestmentHorizon.weekly:
          wTry += tryAmt;
          wCnt++;
          break;
        case InvestmentHorizon.multiWeek:
          mwTry += tryAmt;
          mwCnt++;
          break;
        case InvestmentHorizon.monthlyLong:
          mlTry += tryAmt;
          mlCnt++;
          break;
      }
    }

    final mainTry = wTry + mwTry + mlTry;
    final remTry = math.max(0.0, totalBudget - mainTry);
    final dailySigs = [
      for (final s in activeDailySignals)
        if (classifyHorizon(s) == InvestmentHorizon.daily) s,
    ];

    double dailyShareCap;
    double remShareRatio;
    switch (allocation.appetite) {
      case RiskAppetite.conservative:
        dailyShareCap = 0.12;
        remShareRatio = 0.40;
        break;
      case RiskAppetite.balanced:
        dailyShareCap = 0.20;
        remShareRatio = 0.50;
        break;
      case RiskAppetite.aggressive:
        dailyShareCap = 0.25;
        remShareRatio = 0.65;
        break;
    }

    final dLimit = dailySigs.isEmpty ? 0.0 : math.min(totalBudget * dailyShareCap, remTry * remShareRatio);
    final slots = math.min(dailySigs.length, 3);
    final perSig = slots > 0 ? dLimit / slots : 0.0;
    final cashTry = math.max(0.0, remTry - dLimit);

    return HorizonBudgetBreakdown(
      totalBudgetTry: totalBudget,
      weeklyTry: wTry,
      multiWeekTry: mwTry,
      monthlyLongTry: mlTry,
      mainInvestedTry: mainTry,
      remainingPoolTry: remTry,
      dailyLimitTry: dLimit,
      dailyPerSignalTry: perSig,
      cashReserveTry: cashTry,
      dailySignalsCount: dailySigs.length,
      weeklyCount: wCnt,
      multiWeekCount: mwCnt,
      monthlyLongCount: mlCnt,
    );
  }
}

/// Kullanıcıdan gelen TL bütçe metnini (ör. "150.000", "75000", "125000,5") sayıya çevirir.
double? parseTryInput(String raw) {
  var s = raw.trim().replaceAll('₺', '').replaceAll('TL', '').replaceAll('tl', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',') && s.contains('.')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (s.contains(',')) {
    s = s.replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  final v = double.tryParse(s);
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
}

/// İki modlu portföy seçim çubuğu: Otomatik Seçsin (tüm evren) vs Kendim Seçeyim (seçtiklerim).
class PortfolioModeSelector extends StatelessWidget {
  const PortfolioModeSelector({
    super.key,
    required this.userSelected,
    required this.selectedCount,
    required this.onModeChanged,
    this.onPickAssets,
    this.autoKey,
    this.customKey,
  });

  final bool userSelected;
  final int selectedCount;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onPickAssets;
  final Key? autoKey;
  final Key? customKey;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);

    Widget pill(Key? key, String title, String tagText, bool active, VoidCallback onTap) => Expanded(
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: active ? p.accentSoft : p.subtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? p.accent : p.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: active ? p.accent : p.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tagText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.textDim),
                  ),
                ],
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            pill(autoKey, 'Otomatik Seçsin', 'Tüm BIST & 10 Kripto', !userSelected, () => onModeChanged(false)),
            const SizedBox(width: 8),
            pill(customKey, 'Kendim Seçeyim', '$selectedCount seçili varlık', userSelected, () => onModeChanged(true)),
          ],
        ),
        if (onPickAssets != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onPickAssets,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.tune_rounded, size: 15),
              label: Text(
                userSelected ? 'Seçtiklerimi Düzenle ($selectedCount)' : 'Varlık Kataloğu',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Vade bazlı bütçe dağılımı ve Kalan Limit kartı (Sadece Spot).
class HorizonBudgetSummaryCard extends StatelessWidget {
  const HorizonBudgetSummaryCard({
    super.key,
    required this.breakdown,
    required this.userSelectedMode,
    required this.selectedCount,
    required this.onModeChanged,
    this.onPickAssets,
    this.onEditBudget,
  });

  final HorizonBudgetBreakdown breakdown;
  final bool userSelectedMode;
  final int selectedCount;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onPickAssets;
  final VoidCallback? onEditBudget;

  @override
  Widget build(BuildContext context) {
    final p = PusulaPalette.of(context);
    final b = breakdown;

    Widget cell(String label, double tryVal, String sub, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: p.subtle,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.textDim, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                Fmt.currencyTry(tryVal),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: p.textDim)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Portföy & Vade Planı',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      Tag('SADECE SPOT', color: p.accent),
                    ],
                  ),
                ),
                if (onEditBudget != null)
                  TextButton(
                    key: const Key('btn_edit_budget_shortcut'),
                    onPressed: onEditBudget,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text(Fmt.currencyTry(b.totalBudgetTry)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            PortfolioModeSelector(
              autoKey: const Key('btn_mode_auto'),
              customKey: const Key('btn_mode_custom'),
              userSelected: userSelectedMode,
              selectedCount: selectedCount,
              onModeChanged: onModeChanged,
              onPickAssets: onPickAssets,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final itemWidth = ((c.maxWidth - 8) / 2).clamp(110.0, 400.0);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: cell('Haftalık', b.weeklyTry, '${b.weeklyCount} öneri', p.accent),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: cell('Birkaç Haftalık', b.multiWeekTry, '${b.multiWeekCount} öneri', p.accent),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: cell('Aylık / Uzun Vade', b.monthlyLongTry, '${b.monthlyLongCount} öneri', p.profit),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: cell('Kalan Limit · Günlük', b.dailyLimitTry, '${b.dailySignalsCount} gün içi', p.coral),
                    ),
                    SizedBox(
                      width: c.maxWidth,
                      child: cell('Nakit Koruma', b.cashReserveTry, 'Emniyet tamponu', p.text),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
