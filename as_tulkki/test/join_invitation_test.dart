import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:as_tulkki/join_invitation.dart';
import 'package:as_tulkki/controller.dart';
import 'package:as_tulkki/main.dart';

import 'domain_test.dart' show MemoryStore;

void main() {
  test('QR-linkki kestää WordPressin alikansion ja sovelluskuoren uudelleenohjauksen', () {
    final invitation = JoinInvitation.parse(
      Uri.parse(
        'https://example.fi/kerho/wp-content/plugins/as-tulkki-yhteys/app/index.php#join=abcdef123456&site=https%3A%2F%2Fexample.fi%2Fkerho%2F',
      ),
    )!;
    expect(invitation.site, 'https://example.fi/kerho/');
    expect(invitation.code, 'ABCDEF123456');
    for (final uri in [
      'https://example.fi/#join=ABCDEF123456&site=https%3A%2F%2Fevil.invalid%2F',
      'https://example.fi/#join=xx&site=https%3A%2F%2Fexample.fi%2F',
      'file:///app#join=ABCDEF123456&site=https%3A%2F%2Fexample.fi%2F',
      'https://example.fi/#join=%ZZ',
    ]) {
      expect(JoinInvitation.parse(Uri.parse(uri)), isNull);
    }
  });
  testWidgets(
    'QR-tiedot esitäytetään mutta vanhoja kirjauksia ei vaihdeta automaattisesti',
    (tester) async {
      final store = MemoryStore();
      final controller = TulkkiController(store);
      await controller.openDemo('Vanha tarkastaja');
      final before = controller.competition.encode();
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Welcome(
            controller: controller,
            invitation: const JoinInvitation(
              'https://example.fi/',
              'ABCDEF123456',
            ),
            onInvitationCancel: () => cancelled = true,
          ),
        ),
      );
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller!.text, 'https://example.fi/');
      expect(fields[1].controller!.text, 'ABCDEF123456');
      expect(fields[2].controller!.text, 'Vanha tarkastaja');
      expect(controller.competition.encode(), before);
      expect(find.text('Avaa esimerkkikilpailu'), findsNothing);
      await tester.ensureVisible(find.text('Palaa aiempaan kilpailuun'));
      await tester.tap(find.text('Palaa aiempaan kilpailuun'));
      expect(cancelled, isTrue);
      expect(controller.competition.encode(), before);
      controller.dispose();
    },
  );
}
