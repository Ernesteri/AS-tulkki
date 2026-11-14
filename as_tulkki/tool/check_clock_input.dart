import '../lib/domain.dart';

void main() {
  for (final pair in [
    ['180334', '18:03:34'],
    ['000000', '00:00:00'],
    ['235959', '23:59:59'],
    ['18:03:34', '18:03:34'],
    ['240000', '240000'],
    ['186000', '186000'],
    ['180360', '180360'],
    ['18033', '18033'],
    ['', ''],
  ]) {
    if (normalizeClockInput(pair[0]) != pair[1])
      throw StateError('Muotoilu: $pair');
  }
  final draft = SectionDraft();
  draft.setTime('a', '180334');
  if (draft.value('a').time != '18:03:34') throw StateError('Tallennus');
  if (EntryValue.fromJson({'missing': false, 'time': '180334'}).time !=
      '18:03:34')
    throw StateError('Vanhan luonnoksen palautus');
  draft.setTime('a', '240000');
  if (validClock(draft.value('a').time))
    throw StateError('Virheellinen aika hyväksyttiin');
  print(
    'PASS: hhmmss, keskiyö, valmiiksi muotoiltu aika, virheelliset ajat, luonnoksen tallennus ja palautus',
  );
}
