import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusula_app/main.dart';
import 'package:pusula_app/src/theme/gunduz_theme.dart';

void main() {
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Faz 5 — GÜNDÜZ Arayüzü, 3D Halka ve 4 Sekme Widget Testleri', () {
    testWidgets('Varsayılan GÜNDÜZ teması, 3D halka ve Yatırım tavsiyesi değildir şeridi görünür', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      // GÜNDÜZ zemin rengi (#F6F4EF) kontrolü
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.scaffoldBackgroundColor, GunduzColors.background);

      // Yatırım tavsiyesi değildir uyarısı görünür
      expect(find.textContaining('Yatırım tavsiyesi değildir'), findsWidgets);

      // 3D bütçe ağırlık halkası (varsayılan 3D mod) çizilir
      expect(find.byKey(const ValueKey('donut_painter_3d')), findsOneWidget);

      // Halkayı sürükleyince hata vermeden döner
      await tester.drag(find.byKey(const Key('donut_3d_gesture')), const Offset(45, 10));
      await tester.pumpAndSettle();

      // Dilim etiketine dokununca varlık detay alt penceresi açılır
      final thyaoLegend = find.byKey(const Key('donut_legend_bist_THYAO'));
      await tester.tap(thyaoLegend);
      await tester.pumpAndSettle();
      expect(find.textContaining('Dilim Detayı'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('Öneri sekmesinde önce "Geçen hafta raporu: henüz veri yok", sonra yeni öneriler görünür',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      // Öneri sekmesine geç
      await tester.tap(find.text('Öneri'));
      await tester.pumpAndSettle();

      expect(find.text('1. Geçen Hafta Önerilerinin Sonucu'), findsOneWidget);
      expect(find.text('Geçen hafta raporu: henüz veri yok'), findsOneWidget);
      expect(find.text('2. Bu Haftanın Yeni Önerileri'), findsOneWidget);
      expect(find.textContaining('THYAO'), findsWidgets);

      // Geçmiş Arşivi sekmesine geç
      await tester.tap(find.byKey(const Key('tab_oneri_history')));
      await tester.pumpAndSettle();
      expect(find.textContaining('İleriye Dönük Performans Eğrisi'), findsOneWidget);
    });

    testWidgets('Sinyal sekmesinde Kripto ve BIST kısa vade raporları ayrı gösterilir', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sinyal'));
      await tester.pumpAndSettle();

      expect(find.text('Kripto Kısa Vade Özeti'), findsOneWidget);
      expect(find.text('Borsa İstanbul Kısa Vade Özeti'), findsOneWidget);
      expect(find.textContaining('Monte Carlo'), findsWidgets);
    });

    testWidgets('Ayar sekmesinde Animasyonları Azalt açıldığında 3D halka düz 2D moduna geçer',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      // Ayar sekmesine geç
      await tester.tap(find.text('Ayar'));
      await tester.pumpAndSettle();

      final reduceAnimSwitch = find.byKey(const Key('switch_reduce_animations'));
      await tester.tap(reduceAnimSwitch);
      await tester.pumpAndSettle();

      // Özet sekmesine geri dön ve 2D sade modun aktif olduğunu doğrula
      await tester.tap(find.text('Özet'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('donut_painter_2d')), findsOneWidget);
      expect(find.textContaining('2D Sade Mod'), findsOneWidget);
    });
  });
}
