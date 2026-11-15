import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:as_tulkki/controller.dart';
import 'package:as_tulkki/main.dart';

import 'domain_test.dart' show MemoryStore;

void main() {
  testWidgets('Puhelimen työnkulku avaa oikean parin ja säilyttää puutteen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    final controller = TulkkiController(store);
    await tester.pumpWidget(TulkkiApp(controller: controller));
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Tarkastajan nimi',
      ),
      'Testitarkastaja',
    );
    await tester.ensureVisible(find.text('Avaa esimerkkikilpailu'));
    await tester.tap(find.text('Avaa esimerkkikilpailu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jakso 1'));
    await tester.pumpAndSettle();
    final missing = find.widgetWithText(FilterChip, 'Puuttuu').at(1);
    await tester.ensureVisible(missing);
    await tester.tap(missing);
    await tester.pumpAndSettle();
    expect(controller.competition.draft(101, 'j1').value('j1-2').missing, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // Luonnoksen tallennus käynnistyi testin virtuaalikellolla.
    await tester.pump(const Duration(milliseconds: 10));
    await controller.flush();
    final restored = TulkkiController(store);
    await tester.runAsync(restored.load);
    expect(restored.competition.draft(101, 'j1').value('j1-2').missing, true);
  });
}
