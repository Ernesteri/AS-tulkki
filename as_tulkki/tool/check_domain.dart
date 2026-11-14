// Flutter-moottorista riippumaton sääntöjen koesuoritus.
import '../lib/domain.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final competition = LocalCompetition()..reviewer = 'Koesuoritus';
  final draft = competition.draft(101, 'j1');
  draft.setMissing('j1-3', true);
  check(!draft.value('j1-4').missing, 'Toistuvat 25-kilvet sekoittuivat');
  check(
    draft.incomplete(demoSections.first, false).length == 2,
    'Asemakohtainen valinta rajaa vaaditut ajat',
  );
  draft.setTime('j1-5', '12:34:03');
  draft.setMissing('j1-6', true);
  draft.setTime('j1-7', '12:40:00');
  draft.complete(demoSections.first, false);
  check(draft.interpreted, 'Valmiin jakson vahvistus epäonnistui');
  check(competition.completed(101) == 1, 'Jaksoittainen tila ei säilynyt');
  draft.setMissing('j1-2', true);
  check(!draft.interpreted, 'Korjaus ei avannut jaksoa uudelleen');
  check(
    draft.missingSigns(demoSections.first) == 2,
    'Kilpipuutteiden määrä on väärä',
  );
  check(
    draft.missingTimes(demoSections.first) == 1,
    'Aikapuute sekoittui kilpipuutteisiin',
  );
  final restored = LocalCompetition.decode(competition.encode());
  check(
    restored.encode() == competition.encode(),
    'Tallennuksen palautus muutti tietoja',
  );
  final finish = restored.draft(102, 'j3');
  check(
    finish.incomplete(demoSections.last, true).isEmpty,
    'Emit-maali vaati käsiaikaa',
  );
  check(
    finish.incomplete(demoSections.last, false).length == 1,
    'Käsimaali ei vaatinut aikaa',
  );
  finish.setMissing('j3-4', true);
  check(
    finish.incomplete(demoSections.last, false).isEmpty,
    'Puuttuva maaliaika ei kelvannut tulkatuksi',
  );
  check(
    validClock('23:59:59') &&
        !validClock('24:00:00') &&
        !validClock('12:60:00'),
    'Kellonajan rajat ovat väärin',
  );
  final whole = LocalCompetition();
  var rejected = false;
  try {
    whole.completeSections(demoPairs.first, demoSections);
  } catch (_) {
    rejected = true;
  }
  check(
    rejected && whole.completed(101) == 0,
    'Koko kilpailun vahvistus ei ole atominen',
  );
  whole.draft(101, 'j1').setTime('j1-5', '12:34:03');
  whole.draft(101, 'j2').setMissing('j2-5', true);
  whole.completeSections(demoPairs.first, demoSections);
  check(
    whole.completed(101) == 3,
    'Koko kilpailun vahvistus ei valmistellut kaikkia jaksoja',
  );
  check(
    !demoSections.first.entries[5].requiresTime(false),
    'Automaattinen JAT vaatii ajan',
  );
  print('15 sääntötarkistusta läpäisty.');
}
