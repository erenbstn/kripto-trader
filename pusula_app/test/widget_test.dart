import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pusula_app/main.dart';
import 'package:pusula_app/src/state/pusula_controller.dart';
import 'package:pusula_app/src/theme/gunduz_theme.dart';
import 'package:pusula_app/src/widgets/common.dart';
import 'package:pusula_core/pusula_core.dart';

void main() {
  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void setWebViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Faz 5 & Phantom UI — 3D Halka, Arama, Bildirim Kapsülü ve 4 Sekme Testleri', () {
    testWidgets('Varsayılan Phantom OLED koyu teması, Nakit kapsülü, toast animasyonu ve 3D halka görünür',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      // Phantom OLED koyu zemin rengi (#08080A) ve varsayılan koyu mod kontrolü
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
      expect(materialApp.darkTheme?.scaffoldBackgroundColor, GunduzColors.darkBackground);

      // Yatırım tavsiyesi değildir uyarısı görünür
      expect(find.textContaining('Yatırım tavsiyesi değildir'), findsWidgets);

      // Phantom bileşenleri: Nakit Koruma kapsülü, yüzen toast kapsülü ve alt arama çubuğu
      expect(find.byKey(const Key('phantom_cash_capsule')), findsOneWidget);
      expect(find.byKey(const Key('phantom_toast_capsule')), findsOneWidget);
      expect(find.byKey(const Key('input_global_search')), findsOneWidget);
      expect(find.byKey(const Key('btn_refresh_live_data')), findsOneWidget);

      // 3D bütçe ağırlık halkası (varsayılan 3D mod) çizilir
      expect(find.byKey(const ValueKey('donut_painter_3d')), findsOneWidget);

      // Halkayı sürükleyince hata vermeden döner
      await tester.drag(find.byKey(const Key('donut_3d_gesture')), const Offset(45, 10));
      await tester.pumpAndSettle();

      // Dilim etiketine dokununca varlık detay alt penceresi açılır
      final thyaoLegend = find.byKey(const Key('donut_legend_bist_THYAO'));
      await Scrollable.ensureVisible(tester.element(thyaoLegend), alignment: 0.45);
      await tester.pumpAndSettle();
      await tester.tap(thyaoLegend);
      await tester.pumpAndSettle();
      expect(find.textContaining('Dilim Detayı'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Alt arama çubuğuna yazıldığında listeler filtrelenir
      await tester.enterText(find.byKey(const Key('input_global_search')), 'SOL');
      await tester.pumpAndSettle();
      expect(find.textContaining('SOL'), findsWidgets);
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

    testWidgets('Faz 7 — Ayar sekmesinde Gizlilik ve Play Beyanı penceresi açılır', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ayar'));
      await tester.pumpAndSettle();

      final pageScrollable = find.descendant(
        of: find.byType(PageBody),
        matching: find.byType(Scrollable),
      ).first;
      final privacyBtn = find.byKey(const Key('btn_privacy_and_legal'));
      await tester.scrollUntilVisible(privacyBtn, 250, scrollable: pageScrollable);
      await tester.drag(pageScrollable, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(privacyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Gizlilik, Lisans ve Play Beyanı'), findsOneWidget);
      expect(find.textContaining('SPK mevzuatına tabi olabilir'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
    });

    testWidgets('Web geniş görünümünde NavigationRail görünür ve tüm sekmeler hatasız açılır', (tester) async {
      setWebViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.text('Öneri'));
      await tester.pumpAndSettle();
      expect(find.text('1. Geçen Hafta Önerilerinin Sonucu'), findsOneWidget);

      await tester.tap(find.text('Sinyal'));
      await tester.pumpAndSettle();
      expect(find.text('Kripto Kısa Vade Özeti'), findsOneWidget);

      await tester.tap(find.text('Ayar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn_privacy_and_legal')), findsOneWidget);
    });

    testWidgets('Gerçek kip (demoSeed=false) başlangıçta sahte sinyal göstermez, tarama bekler', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoSeedProvider.overrideWithValue(false),
            liveNetworkEnabledProvider.overrideWithValue(false),
          ],
          child: const PusulaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Örnek veri'), findsNothing);
      expect(find.text('Şimdilik nakitte'), findsOneWidget);
      expect(find.text('Tarama bekleniyor'), findsOneWidget);
    });

    testWidgets('BIST fiyatları ₺, Kripto fiyatları \$ ile gösterilir; favoriler ve BIST kataloğu çalışır',
        (tester) async {
      expect(Fmt.priceWithCurrency(313.75, Market.bist), '₺313,75');
      expect(Fmt.priceWithCurrency(73506.01, Market.crypto), '\$73.506');
      expect(Fmt.priceWithCurrency(82.90, Market.crypto), '\$82,900');

      setPhoneViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      final pageScrollable = find
          .descendant(
            of: find.byType(PageBody),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      final favFilter = find.byKey(const Key('filter_market_favorites'));
      final scrollableState = tester.state<ScrollableState>(pageScrollable);
      while (favFilter.evaluate().isEmpty &&
          scrollableState.position.pixels < scrollableState.position.maxScrollExtent) {
        scrollableState.position.jumpTo(
          (scrollableState.position.pixels + 250).clamp(
            0.0,
            scrollableState.position.maxScrollExtent,
          ),
        );
        await tester.pump();
      }
      await Scrollable.ensureVisible(tester.element(favFilter), alignment: 0.3);
      await tester.pumpAndSettle();

      await tester.tap(favFilter);
      await tester.pumpAndSettle();

      expect(find.text('₺313,75'), findsWidgets);
      expect(find.text('\$73.506'), findsWidgets);
      expect(find.text('₺155,40'), findsNothing);

      final browserBtn = find.byKey(const Key('btn_open_universe_browser'));
      await Scrollable.ensureVisible(tester.element(browserBtn), alignment: 0.25);
      await tester.pumpAndSettle();
      await tester.tap(browserBtn);
      await tester.pumpAndSettle();

      expect(find.text('Piyasa Kataloğu & Favoriler'), findsOneWidget);
      expect(find.textContaining('Tüm BIST hisselerini tara'), findsOneWidget);

      final sheetSearch = find.byKey(const Key('field_universe_search'));
      await tester.enterText(sheetSearch, 'FROTO');
      await tester.pumpAndSettle();
      expect(find.text('Ford Otosan'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_sheet_fav_FROTO')));
      await tester.pumpAndSettle();

      await tester.enterText(sheetSearch, '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet_tab_crypto')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Kripto taraması ve fiyat ekranı yalnızca belirlediğin 10 kripto için aktiftir'),
        findsOneWidget,
      );
    });

    testWidgets('Sadece Spot, özel bütçe (TL/adet), iki seçim modu ve çoklu vade filtresi çalışır', (tester) async {
      setWebViewport(tester);
      await tester.pumpWidget(const ProviderScope(child: PusulaApp()));
      await tester.pumpAndSettle();

      // Gereksiz uzun uyarı / yönlendirme metni ve kaldıraçlı (Futures) ifadeleri bulunmaz
      expect(find.textContaining('Döndürmek için sürükleyin'), findsNothing);
      expect(find.textContaining('Futures'), findsNothing);

      // Kahraman bütçe alanından özel bütçe (₺200.000) girip uygulayınca TL/adet güncellenir
      await tester.ensureVisible(find.byKey(const Key('btn_hero_budget_selector')));
      await tester.tap(find.byKey(const Key('btn_hero_budget_selector')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('input_custom_budget_try')), '200000');
      await tester.tap(find.byKey(const Key('btn_apply_custom_budget')));
      await tester.pumpAndSettle();

      expect(find.textContaining('200.000'), findsWidgets);
      expect(find.textContaining('adet AL'), findsWidgets);

      // Varsayılan Otomatik Seçsin modunda favori olmayan TUPRS önerilerde/halkada vardır; Kendim Seçeyim'e geçince çıkar
      await tester.tap(find.byKey(const Key('phantom_toast_capsule')), warnIfMissed: false);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('btn_mode_custom'))), alignment: 0.45);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_mode_custom')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('donut_legend_bist_TUPRS')), findsNothing);

      // Öneri sekmesinde vade filtreleri, Günlük Al-Sat · Kalan Limit ve SADECE SPOT etiketleri görünür
      await tester.tap(find.text('Öneri').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_horizon_all')), findsOneWidget);
      expect(find.byKey(const Key('filter_horizon_daily')), findsOneWidget);
      expect(find.byKey(const Key('filter_horizon_weekly')), findsOneWidget);
      expect(find.byKey(const Key('filter_horizon_multiweek')), findsOneWidget);
      expect(find.byKey(const Key('filter_horizon_monthly')), findsOneWidget);
      expect(find.textContaining('Günlük Al-Sat · Kalan Limit'), findsOneWidget);
      expect(find.textContaining('SADECE SPOT'), findsWidgets);

      // Ayar sekmesinde özel bütçe alanı ve çift seçim modu çalışır
      await tester.tap(find.text('Ayar').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('input_ayar_budget_try')), findsOneWidget);
      expect(find.byKey(const Key('ayar_btn_mode_auto')), findsOneWidget);
      expect(find.byKey(const Key('ayar_btn_mode_custom')), findsOneWidget);
    });
  });
}
