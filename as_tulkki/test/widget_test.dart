import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:as_tulkki/controller.dart';
import 'package:as_tulkki/main.dart';
import 'package:as_tulkki/domain.dart';

import 'domain_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'ULA-aikakenttä tulee avoimeen näkymään syöttötavan päivittyessä',
    (tester) async {
      final controller = TulkkiController(MemoryStore());
      Map<String, dynamic> manifest(bool manual) => {
        'routes': [
          {
            'id': 'r1',
            'name': 'Koe',
            'sections': [
              {
                'id': 's1',
                'name': 'Jakso 1',
                'entries': [
                  {
                    'id': 'jat',
                    'label': 'JAT',
                    'kind': 'jat',
                    'manualTime': false,
                    'voided': false,
                  },
                  {
                    'id': 'ula',
                    'label': 'ULA',
                    'kind': 'ula',
                    'manualTime': manual,
                    'voided': false,
                  },
                ],
              },
            ],
          },
        ],
        'pairs': [
          {
            'number': 7,
            'driver': 'Koe',
            'navigator': 'Koe',
            'routeId': 'r1',
            'emit': true,
          },
        ],
      };
      controller.competition.remote = RemoteCompetition(
        site: 'https://example.fi',
        id: 1,
        token: 'test',
        name: 'Koe',
        revision: 1,
        manifest: manifest(false),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SectionScreen(
            controller: controller,
            pair: controller.competition.pairs.single,
            section: controller.competition.sectionsFor(7).single,
          ),
        ),
      );
      final clock = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Aika',
      );
      expect(clock, findsNothing);
      controller.update((competition) {
        competition.receiveChanges({
          'manifest': manifest(true),
          'revision': 2,
          'events': [],
          'nextCursor': 0,
          'hasMore': false,
        }, editing: controller.editing);
      });
      await tester.pumpAndSettle();
      expect(clock, findsOneWidget);
      await tester.enterText(clock, '180334');
      await tester.pumpAndSettle();
      expect(
        controller.competition.draft(7, 's1').value('ula').time,
        '18:03:34',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

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
