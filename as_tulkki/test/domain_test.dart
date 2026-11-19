import 'package:flutter_test/flutter_test.dart';
import 'package:as_tulkki/controller.dart';
import 'package:as_tulkki/domain.dart';

class MemoryStore implements DraftStore {
  String? saved;
  bool fail = false;
  final writes = <String>[];
  @override
  Future<String?> read() async => saved;
  @override
  Future<void> write(String value) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (fail) throw StateError('levy täynnä');
    writes.add(value);
    saved = value;
  }
}

void main() {
  test(
    'Ajan syöttö käsin ja siirtyminen paperiin säilyttävät ratakohdistuksen',
    () {
      Map<String, dynamic> manifest(bool manual, bool emit) => {
        'routes': [
          {
            'id': 'r1',
            'sections': [
              {
                'id': 's1',
                'entries': [
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
          {'number': 7, 'routeId': 'r1', 'emit': emit},
        ],
      };
      final old = manifest(false, true);
      final next = manifest(true, true);
      next['routes'][0]['sections'][0]['entries'][0] = {
        'voided': false,
        'kind': 'ula',
        'label': 'ULA',
        'id': 'ula',
        'manualTime': true,
      };
      expect(compatibleRowChange(old, next), true);
      expect(compatibleRowChange(next, old), false);
      expect(compatibleRowChange(old, manifest(true, false)), true);
      final moved = manifest(true, false);
      moved['pairs'][0]['routeId'] = 'other';
      expect(compatibleRowChange(old, moved), false);
      expect(
        sameJsonValue(
          {
            'a': 1,
            'b': [2, 3],
          },
          {
            'b': [2, 3],
            'a': 1,
          },
        ),
        true,
      );
      expect(sameJsonValue([1, 2], [2, 1]), false);
    },
  );
  test('ULA hyväksyy minuutit ja säilyttää sekunnit vanhoissa ajoissa', () {
    final draft = SectionDraft();
    for (final input in ['1845', '18:45']) {
      draft.setTime('ula', input, ula: true);
      expect(draft.value('ula').time, '18:45:00');
    }
    draft.setTime('ula', '18:45:33', ula: true);
    expect(draft.value('ula').time, '18:45:33');
    expect(validClock(normalizeClockInput('2460', ula: true)), isFalse);
    expect(validClock(normalizeClockInput('1845')), isFalse);
  });

  test('Pistekenttä jää pois ilman kirjausta ja kirjattu nolla säilyy', () {
    final draft = SectionDraft();
    expect(draft.toJson().containsKey('otherPenaltyPoints'), isFalse);
    final old = SectionDraft.fromJson({
      ...draft.toJson(),
      'otherPenaltyPoints': null,
    });
    expect(old.toJson().containsKey('otherPenaltyPoints'), isFalse);
    for (var i = 0; i < 3; i++) {
      draft.adjustOtherPenaltyPoints(100);
    }
    expect(draft.otherPenaltyPoints, 300);
    draft.adjustOtherPenaltyPoints(-300);
    final reopened = SectionDraft.fromJson(draft.toJson());
    expect(reopened.otherPenaltyPoints, 0);
    expect(reopened.otherErrors, 0);
  });

  test('Asemakohtainen ajan syöttötapa ohittaa Emit-oletuksen', () {
    const automaticAt = RouteEntry('a', 'AT', EntryKind.at, manualTime: false);
    const manualJat = RouteEntry('j', 'JAT', EntryKind.jat, manualTime: true);
    expect(automaticAt.requiresTime(false), false);
    expect(manualJat.requiresTime(true), true);
  });
  test(
    'Koko kilpailun vahvistus on atominen ja käyttää jaksojen samoja tietoja',
    () {
      final competition = LocalCompetition();
      expect(
        () => competition.completeSections(demoPairs.first, demoSections),
        throwsStateError,
      );
      expect(competition.completed(101), 0);
      competition.draft(101, 'j1').setTime('j1-5', '12:00:00');
      competition.draft(101, 'j2').setMissing('j2-5', true);
      competition.completeSections(demoPairs.first, demoSections);
      expect(competition.completed(101), 3);
      competition.draft(101, 'j2').setMissing('j2-1', true);
      expect(competition.completed(101), 2);
    },
  );
  test('Toistuvat kilvet erotetaan ja puuttumismerkintä poistaa ajan', () {
    final draft = SectionDraft();
    draft.setMissing('j1-3', true);
    expect(draft.value('j1-4').missing, false);
    draft.setTime('j1-5', '12:34:03');
    draft.setMissing('j1-5', true);
    expect(draft.value('j1-5').time, '');
    draft.setTime('j1-5', '12:35:00');
    expect(draft.value('j1-5').missing, false);
    expect(draft.missingSigns(demoSections.first), 1);
  });

  test(
    'Emit muuttaa ULA- ja maalikirjausta mutta ei puuttumisen tarkistusta',
    () {
      final finish = demoSections.last;
      final draft = SectionDraft();
      expect(draft.incomplete(finish, true), isEmpty);
      expect(draft.incomplete(finish, false).single.label, 'M');
      draft.setMissing('j3-4', true);
      expect(draft.incomplete(finish, false), isEmpty);
      expect(draft.missingTimes(finish), 1);
      expect(draft.missingSigns(finish), 0);
      expect(demoSections.first.entries.last.requiresTime(false), true);
      expect(demoSections.first.entries.last.requiresTime(true), false);
    },
  );

  test('Virheellistä aikaa ei hyväksytä ja korjaus poistaa tulkattu-tilan', () {
    expect(validClock('23:59:59'), true);
    for (final bad in [
      '24:00:00',
      '12:60:00',
      '12:00:60',
      '1:02:03',
      '123456',
      '',
    ]) {
      expect(validClock(bad), false);
    }
    final draft = SectionDraft();
    expect(() => draft.complete(demoSections.first, false), throwsStateError);
    draft.setTime('j1-5', '12:34:03');
    draft.setMissing('j1-6', true);
    draft.setTime('j1-7', '12:40:00');
    draft.complete(demoSections.first, false);
    expect(draft.interpreted, true);
    draft.setMissing('j1-2', true);
    expect(draft.interpreted, false);
    expect(draft.completedAt, isNull);
  });

  test('Tallennus säilyttää parit erillisinä ja palauttaa luonnokset', () {
    final competition = LocalCompetition()..reviewer = 'Testitarkastaja';
    competition.draft(101, 'j1').setMissing('j1-3', true);
    competition.draft(102, 'j1').setTime('j1-5', '12:34:03');
    final restored = LocalCompetition.decode(competition.encode());
    expect(restored.reviewer, 'Testitarkastaja');
    expect(restored.draft(101, 'j1').value('j1-3').missing, true);
    expect(restored.draft(102, 'j1').value('j1-3').missing, false);
    expect(restored.draft(102, 'j1').value('j1-5').time, '12:34:03');
    expect(
      () => LocalCompetition.decode('{"schema":99}'),
      throwsFormatException,
    );
  });

  test(
    'Nopeat kirjaukset tallentuvat järjestyksessä ja viimeisin säilyy',
    () async {
      final store = MemoryStore();
      final controller = TulkkiController(store);
      final first = controller.update((c) => c.reviewer = 'Ensimmäinen');
      final second = controller.update((c) => c.reviewer = 'Viimeisin');
      await Future.wait([first, second]);
      expect(controller.saving, false);
      expect(store.writes.length, 2);
      final restored = TulkkiController(store);
      await restored.load();
      expect(restored.competition.reviewer, 'Viimeisin');
    },
  );

  test(
    'Tallennusvirhe näkyy ja uusi yritys säilyttää uusimman luonnoksen',
    () async {
      final store = MemoryStore()..fail = true;
      final controller = TulkkiController(store);
      await controller.update(
        (c) => c.draft(101, 'j1').note = 'Säilytettävä huomautus',
      );
      expect(controller.saveError, isNotNull);
      expect(store.saved, isNull);
      store.fail = false;
      await controller.persist();
      expect(controller.saveError, isNull);
      expect(
        LocalCompetition.decode(store.saved!).draft(101, 'j1').note,
        'Säilytettävä huomautus',
      );
    },
  );
}
