import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pusula_core/pusula_core.dart';

import '../theme/gunduz_theme.dart';

/// 3D / 2D halka grafikteki tek bir bütçe dilimi.
class DonutSliceData {
  const DonutSliceData({
    required this.id,
    required this.label,
    required this.categoryLabel,
    required this.weightPct,
    required this.color,
    required this.subtitle,
    this.recommendation,
  });

  final String id;
  final String label;
  final String categoryLabel;
  final double weightPct;
  final Color color;
  final String subtitle;
  final WeeklyRecommendation? recommendation;
}

/// Dokunulup döndürülebilen sahte-3D (veya pil tasarrufunda düz 2D) bütçe ağırlığı halkası (K4, Faz 5.2).
class Donut3DChart extends StatefulWidget {
  const Donut3DChart({
    super.key,
    required this.slices,
    required this.flat2D,
    required this.budgetAmount,
    this.onSliceTap,
  });

  final List<DonutSliceData> slices;
  final bool flat2D;
  final double budgetAmount;
  final ValueChanged<DonutSliceData>? onSliceTap;

  @override
  State<Donut3DChart> createState() => _Donut3DChartState();
}

class _Donut3DChartState extends State<Donut3DChart> {
  double _rotationRad = -math.pi / 2;
  String? _selectedId;

  List<DonutSliceData> get _normalizedSlices {
    final valid = widget.slices.where((s) => s.weightPct > 0.05).toList();
    if (valid.isEmpty) {
      return const [
        DonutSliceData(
          id: 'cash',
          label: 'Nakit',
          categoryLabel: 'Koruma',
          weightPct: 100.0,
          color: Color(0xFF9CA3AF),
          subtitle: 'Net fırsat yok · %100 nakit',
        ),
      ];
    }
    return valid;
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos = details.localPosition;
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    // Yatay sürükleme veya teğetsel hareket halkayı döndürür; sürekli otomatik dönmez.
    final delta = (details.delta.dx * (dy >= 0 ? -1 : 1) + details.delta.dy * (dx >= 0 ? 1 : -1)) * 0.011;
    setState(() {
      _rotationRad = (_rotationRad + delta) % (2 * math.pi);
    });
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    final hit = _hitTestSlice(details.localPosition, size);
    if (hit != null) {
      setState(() => _selectedId = hit.id);
      widget.onSliceTap?.call(hit);
    }
  }

  DonutSliceData? _hitTestSlice(Offset pos, Size size) {
    final slices = _normalizedSlices;
    final total = slices.fold<double>(0, (a, b) => a + b.weightPct);
    if (total <= 0) return null;

    final tilt = widget.flat2D ? 1.0 : 0.62;
    final center = Offset(size.width / 2, size.height / 2 - (widget.flat2D ? 0 : 10));
    final outerRx = math.min(size.width * 0.39, 136.0);
    final innerRx = outerRx * 0.54;

    final nx = (pos.dx - center.dx);
    final ny = (pos.dy - center.dy) / tilt;
    final dist = math.sqrt(nx * nx + ny * ny);
    if (dist < innerRx * 0.85 || dist > outerRx * 1.18) return null;

    var theta = math.atan2(ny, nx);
    var rel = (theta - _rotationRad) % (2 * math.pi);
    if (rel < 0) rel += 2 * math.pi;

    var acc = 0.0;
    for (final s in slices) {
      final sweep = (s.weightPct / total) * 2 * math.pi;
      if (rel >= acc && rel <= acc + sweep) {
        return s;
      }
      acc += sweep;
    }
    return slices.last;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slices = _normalizedSlices;
    final cashSlice = slices.where((s) => s.id == 'cash').firstOrNull;
    final investedPct = (100.0 - (cashSlice?.weightPct ?? 0.0)).clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.flat2D
                    ? 'Portföy Dağılımı · 2D Sade Mod'
                    : 'Portföy Dağılımı · Spot',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? GunduzColors.phantomLavender : GunduzColors.accent).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.flat2D ? '2D' : '3D Spot',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? GunduzColors.phantomLavender : GunduzColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
         LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
            const height = 220.0;
            final size = Size(width, height);
            return GestureDetector(
              key: const Key('donut_3d_gesture'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _handlePanUpdate(d, size),
              onTapUp: (d) => _handleTapUp(d, size),
              child: SizedBox(
                width: width,
                height: height,
                child: CustomPaint(
                  key: ValueKey('donut_painter_${widget.flat2D ? "2d" : "3d"}'),
                  painter: Donut3DPainter(
                    slices: slices,
                    rotationRad: _rotationRad,
                    flat2D: widget.flat2D,
                    selectedId: _selectedId,
                    investedPct: investedPct,
                    isDark: isDark,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slice in slices)
              InkWell(
                key: Key('donut_legend_${slice.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _selectedId = slice.id);
                  widget.onSliceTap?.call(slice);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selectedId == slice.id
                        ? slice.color.withValues(alpha: 0.18)
                        : (isDark ? GunduzColors.darkSubtleSurface : GunduzColors.subtleSurface),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _selectedId == slice.id
                          ? slice.color
                          : (isDark ? GunduzColors.darkBorder : GunduzColors.border),
                      width: _selectedId == slice.id ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: slice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${slice.label} · %${slice.weightPct.toStringAsFixed(1).replaceAll('.', ',')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? GunduzColors.darkTextPrimary : GunduzColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Eliptik üst yüz + derinlik sıralamalı (Painter's Algorithm) yan duvar dilimleri çizen CustomPainter.
class Donut3DPainter extends CustomPainter {
  Donut3DPainter({
    required this.slices,
    required this.rotationRad,
    required this.flat2D,
    required this.selectedId,
    required this.investedPct,
    required this.isDark,
  });

  final List<DonutSliceData> slices;
  final double rotationRad;
  final bool flat2D;
  final String? selectedId;
  final double investedPct;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, b) => a + b.weightPct);
    if (total <= 0) return;

    final tilt = flat2D ? 1.0 : 0.62;
    final extrusion = flat2D ? 0.0 : 22.0;
    final center = Offset(size.width / 2, size.height / 2 - (flat2D ? 0 : 10));
    final outerRx = math.min(size.width * 0.39, 136.0);
    final outerRy = outerRx * tilt;
    final innerRx = outerRx * 0.54;
    final innerRy = innerRx * tilt;

    // Dilim açı aralıklarını hazırla
    final sliceAngles = <({DonutSliceData slice, double start, double sweep})>[];
    var cursor = rotationRad;
    for (final s in slices) {
      final sweep = (s.weightPct / total) * 2 * math.pi;
      sliceAngles.add((slice: s, start: cursor, sweep: sweep));
      cursor += sweep;
    }

    // 1. 3D modda yan duvarları arkadan öne doğru (sin(midAngle) artan sırada) çiz
    if (!flat2D && extrusion > 0) {
      final wallQuads = <({double depth, Path path, Color color})>[];
      const step = 0.09; // radyan (~5 derece)

      for (final item in sliceAngles) {
        final liftY = item.slice.id == selectedId ? -6.0 : 0.0;
        var a0 = item.start;
        final end = item.start + item.sweep;
        while (a0 < end - 1e-5) {
          final a1 = math.min(a0 + step, end);
          final mid = (a0 + a1) * 0.5;
          final sinMid = math.sin(mid);
          final cosMid = math.cos(mid);

          // Dış yan duvar: ön yarıda (sin > -0.15) görünür
          if (sinMid > -0.15) {
            final p0Top = Offset(
              center.dx + outerRx * math.cos(a0),
              center.dy + liftY + outerRy * math.sin(a0),
            );
            final p1Top = Offset(
              center.dx + outerRx * math.cos(a1),
              center.dy + liftY + outerRy * math.sin(a1),
            );
            final quad = Path()
              ..moveTo(p0Top.dx, p0Top.dy)
              ..lineTo(p1Top.dx, p1Top.dy)
              ..lineTo(p1Top.dx, p1Top.dy + extrusion)
              ..lineTo(p0Top.dx, p0Top.dy + extrusion)
              ..close();
            final shade = (0.64 + 0.18 * cosMid).clamp(0.48, 0.86);
            wallQuads.add((
              depth: sinMid * outerRy + 1.0,
              path: quad,
              color: _scaleBrightness(item.slice.color, shade),
            ));
          }

          // İç delik yan duvarı: arka yarıda (sin < 0.15) görünür
          if (sinMid < 0.15) {
            final p0Top = Offset(
              center.dx + innerRx * math.cos(a0),
              center.dy + liftY + innerRy * math.sin(a0),
            );
            final p1Top = Offset(
              center.dx + innerRx * math.cos(a1),
              center.dy + liftY + innerRy * math.sin(a1),
            );
            final quad = Path()
              ..moveTo(p0Top.dx, p0Top.dy)
              ..lineTo(p1Top.dx, p1Top.dy)
              ..lineTo(p1Top.dx, p1Top.dy + extrusion)
              ..lineTo(p0Top.dx, p0Top.dy + extrusion)
              ..close();
            wallQuads.add((
              depth: sinMid * innerRy - 1.0,
              path: quad,
              color: _scaleBrightness(item.slice.color, 0.56),
            ));
          }

          a0 = a1;
        }
      }

      wallQuads.sort((a, b) => a.depth.compareTo(b.depth));
      final wallPaint = Paint()..style = PaintingStyle.fill;
      for (final w in wallQuads) {
        wallPaint.color = w.color;
        canvas.drawPath(w.path, wallPaint);
      }
    }

    // 2. Üst eliptik yüzleri çiz
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = isDark ? GunduzColors.darkCard : GunduzColors.card;

    for (final item in sliceAngles) {
      final isSelected = item.slice.id == selectedId;
      final liftY = (!flat2D && isSelected) ? -6.0 : 0.0;
      final c = Offset(center.dx, center.dy + liftY);
      final outerRect = Rect.fromCenter(center: c, width: outerRx * 2, height: outerRy * 2);
      final innerRect = Rect.fromCenter(center: c, width: innerRx * 2, height: innerRy * 2);

      final path = Path()
        ..arcTo(outerRect, item.start, item.sweep, true)
        ..arcTo(innerRect, item.start + item.sweep, -item.sweep, false)
        ..close();

      final topPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isSelected ? _scaleBrightness(item.slice.color, 1.08) : item.slice.color;

      canvas.drawPath(path, topPaint);
      canvas.drawPath(path, strokePaint);
    }

    // 3. Merkez özet yazısı
    final titleTp = TextPainter(
      text: TextSpan(
        text: 'YATIRIM PAYI\n',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isDark ? GunduzColors.darkTextSecondary : GunduzColors.textSecondary,
        ),
        children: [
          TextSpan(
            text: '%${investedPct.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? GunduzColors.darkTextPrimary : GunduzColors.textPrimary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    titleTp.paint(
      canvas,
      Offset(center.dx - titleTp.width / 2, center.dy - titleTp.height / 2),
    );
  }

  static Color _scaleBrightness(Color c, double factor) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness * factor).clamp(0.14, 0.88);
    return hsl.withLightness(l).toColor();
  }

  @override
  bool shouldRepaint(covariant Donut3DPainter oldDelegate) {
    return oldDelegate.rotationRad != rotationRad ||
        oldDelegate.flat2D != flat2D ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.investedPct != investedPct ||
        oldDelegate.isDark != isDark ||
        oldDelegate.slices != slices;
  }
}

