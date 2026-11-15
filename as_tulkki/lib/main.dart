import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controller.dart';
import 'domain.dart';
import 'join_invitation.dart';

const spruce = Color(0xFF145A48);

class PreferencesDraftStore implements DraftStore {
  static const key = 'as_tulkki_demo_v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Paikallinen tallennus epäonnistui');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = TulkkiController(PreferencesDraftStore());
  try {
    await controller.load();
    runApp(TulkkiApp(controller: controller));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tallennettuja tietoja ei voitu avata. Sulje sovellus ja yritä uudelleen. Tietoja ei ole poistettu.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TulkkiApp extends StatefulWidget {
  const TulkkiApp({super.key, required this.controller});
  final TulkkiController controller;
  @override
  State<TulkkiApp> createState() => _TulkkiAppState();
}

class _TulkkiAppState extends State<TulkkiApp> with WidgetsBindingObserver {
  JoinInvitation? invitation = JoinInvitation.parse(Uri.base);
  TulkkiController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final raw = routeInformation.uri.toString();
    final next = JoinInvitation.parse(
      Uri.base.replace(fragment: raw.startsWith('/') ? raw.substring(1) : raw),
    );
    if (next == null) return false;
    setState(() => invitation = next);
    return true;
  }

  void finishInvitation() {
    setState(() => invitation = null);
    unawaited(
      SystemNavigator.routeInformationUpdated(
        uri: Uri(path: '/'),
        replace: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    initialRoute: '/',
    title: 'AS tulkki',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: spruce,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F7F5)),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => invitation != null
          ? Welcome(
              controller: controller,
              invitation: invitation,
              onJoined: finishInvitation,
              onInvitationCancel: controller.competition.reviewer.isEmpty
                  ? null
                  : finishInvitation,
            )
          : controller.competition.reviewer.isEmpty
          ? Welcome(controller: controller)
          : PairQueue(
              key: ValueKey(controller.competition.identity),
              controller: controller,
            ),
    ),
  );
}

class Welcome extends StatefulWidget {
  const Welcome({
    super.key,
    required this.controller,
    this.invitation,
    this.onJoined,
    this.onInvitationCancel,
  });
  final TulkkiController controller;
  final JoinInvitation? invitation;
  final VoidCallback? onJoined;
  final VoidCallback? onInvitationCancel;
  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  final name = TextEditingController();
  final site = TextEditingController(text: 'https://autosuunnistus.net/');
  final code = TextEditingController();
  bool invalid = false;
  bool joining = false;
  String? joinError;
  @override
  void initState() {
    super.initState();
    name.text = widget.controller.competition.reviewer;
    site.text =
        widget.invitation?.site ??
        widget.controller.competition.remote?.site ??
        'https://autosuunnistus.net/';
    code.text = widget.invitation?.code ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    site.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: spruce,
                  child: Icon(
                    Icons.fact_check_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AS tulkki',
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kilpailukortin tulkkaus, jakso kerrallaan.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              if (widget.invitation != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Kilpailun tiedot on täytetty QR-koodista. Anna tarkastajan nimi ja paina Liity kilpailuun.',
                  ),
                ),
              TextField(
                controller: site,
                enabled: !joining,
                decoration: const InputDecoration(labelText: 'Sivuston osoite'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                enabled: !joining,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Liittymiskoodi AS2026:sta',
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Tarkastajan nimi',
                  errorText: invalid ? 'Anna nimesi' : null,
                ),
              ),
              const SizedBox(height: 16),
              if (joinError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    joinError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.cloud_outlined),
                label: Text(joining ? 'Yhdistetään…' : 'Liity kilpailuun'),
                onPressed: joining
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        setState(() {
                          joining = true;
                          joinError = null;
                        });
                        try {
                          await widget.controller.join(
                            site.text,
                            code.text,
                            name.text,
                          );
                          widget.onJoined?.call();
                          if (mounted && navigator.canPop()) {
                            navigator.pop();
                          }
                        } catch (error) {
                          if (mounted) {
                            setState(
                              () => joinError = error.toString().replaceFirst(
                                RegExp(r'^(Bad state: |FormatException: )'),
                                '',
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => joining = false);
                        }
                      },
              ),
              const SizedBox(height: 24),
              if (widget.invitation == null) ...[
                const Text(
                  'Voit myös kokeilla paikallista esimerkkikilpailua.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Avaa esimerkkikilpailu'),
                  onPressed: joining
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          if (name.text.trim().isEmpty) {
                            setState(() => invalid = true);
                            return;
                          }
                          try {
                            await widget.controller.openDemo(name.text);
                            if (mounted && navigator.canPop()) {
                              navigator.pop();
                            }
                          } catch (error) {
                            if (mounted) {
                              setState(() => joinError = error.toString());
                            }
                          }
                        },
                ),
              ],
              if (widget.onInvitationCancel != null)
                TextButton(
                  onPressed: joining ? null : widget.onInvitationCancel,
                  child: const Text('Palaa aiempaan kilpailuun'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDC2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, size: 22),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Esimerkkikilpailu on paikallinen kokeilu. Sen tiedot tallentuvat vain tähän laitteeseen.',
          ),
        ),
      ],
    ),
  );
}

class SaveStatus extends StatelessWidget {
  const SaveStatus({super.key, required this.controller});
  final TulkkiController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final error =
          controller.saveError ??
          controller.syncError ??
          controller.refreshError;
      final pending = controller.competition.outbox.length;
      final contact = controller.lastContact;
      final contactText = contact == null
          ? 'Ei vielä onnistunutta yhteyttä tässä istunnossa'
          : 'Viimeisin yhteys ${contact.hour.toString().padLeft(2, '0')}:${contact.minute.toString().padLeft(2, '0')}:${contact.second.toString().padLeft(2, '0')}';
      return Material(
        color: error == null
            ? const Color(0xFFE9F2ED)
            : const Color(0xFFFFDAD6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                error == null
                    ? (controller.saving
                          ? Icons.sync
                          : Icons.check_circle_outline)
                    : Icons.error_outline,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (error ??
                          (controller.saving
                              ? 'Tallennetaan laitteelle…'
                              : controller.sending
                              ? 'Lähetetään tulkintaa sivustolle…'
                              : pending > 0
                              ? '$pending tulkintaa odottaa lähettämistä'
                              : controller.onlineCompetition
                              ? 'Luonnokset laitteella. Valmis lähettää tulkinnan sivustolle.'
                              : 'Tallennettu tälle laitteelle')) +
                      (controller.onlineCompetition
                          ? '\n$contactText · Jonossa $pending'
                          : ''),
                ),
              ),
              if (error != null)
                TextButton(
                  onPressed: () async {
                    await controller.persist();
                    await controller.sendPending();
                    await controller.refresh();
                  },
                  child: const Text('Yritä uudelleen'),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class PairQueue extends StatefulWidget {
  const PairQueue({super.key, required this.controller});
  final TulkkiController controller;
  @override
  State<PairQueue> createState() => _PairQueueState();
}

class _PairQueueState extends State<PairQueue> {
  String query = '';
  String? selectedClass;
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final classes = c.competition.pairs.map((p) => p.className).toSet().toList()
      ..sort();
    if (selectedClass != null && !classes.contains(selectedClass))
      selectedClass = null;
    final pairs = c.competition.pairs.where((p) {
      final matches = '${p.number} ${p.driver} ${p.navigator} ${p.className}'
          .toLowerCase()
          .contains(query.toLowerCase().trim());
      final done =
          c.competition.completed(p.number) ==
              c.competition.sectionsFor(p.number).length &&
          c.competition.pendingTimes(p.number) == 0;
      return matches &&
          (selectedClass == null || p.className == selectedClass) &&
          (filter == 0 || (filter == 1 && !done) || (filter == 2 && done));
    }).toList()..sort((a, b) => a.number.compareTo(b.number));
    return Scaffold(
      appBar: AppBar(
        title: const Text('AS tulkki'),
        actions: [
          IconButton(
            tooltip: 'Päivitä tulkinnat sivustolta',
            icon: const Icon(Icons.refresh),
            onPressed: c.refreshing ? null : () => c.synchronize(),
          ),
          IconButton(
            tooltip: 'Vaihda kilpailua tai tarkastajaa',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => Welcome(controller: c)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SaveStatus(controller: c),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                c.competition.remote?.name ?? 'Esimerkkikilpailu',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Tarkastaja: ${c.competition.reviewer}'),
              const SizedBox(height: 16),
              if (!c.onlineCompetition) const DemoNotice(),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Kilpailunumero tai nimi',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('${classes.join('|')}:$selectedClass'),
                initialValue: selectedClass ?? '*',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Luokka'),
                items: [
                  const DropdownMenuItem(
                    value: '*',
                    child: Text('Kaikki luokat'),
                  ),
                  for (final name in classes)
                    DropdownMenuItem(
                      value: name,
                      child: Text(
                        name.isEmpty ? 'Luokka ei tiedossa' : 'Luokka $name',
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => selectedClass = value == '*' ? null : value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['Kaikki', 'Tulkattavat', 'Tulkatut']
                    .asMap()
                    .entries
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e.value),
                        selected: filter == e.key,
                        onSelected: (_) => setState(() => filter = e.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              if (pairs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Kilpailupareja ei löytynyt.'),
                ),
              for (final pair in pairs)
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PairScreen(controller: c, pair: pair),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0EDE6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${pair.number}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: spruce,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pair.driver}\n${pair.navigator}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pair.className.isEmpty
                                      ? 'Luokka ei tiedossa'
                                      : 'Luokka ${pair.className}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  c.competition.started(pair.number)
                                      ? '${c.competition.completed(pair.number)}/${c.competition.sectionsFor(pair.number).length} jaksoa tulkattu${c.competition.pendingTimes(pair.number) > 0 ? ' · täydennä ${c.competition.pendingTimes(pair.number)} aikaa' : ''}'
                                      : 'Ei aloitettu',
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class InterpretationHistory extends StatelessWidget {
  const InterpretationHistory({
    super.key,
    required this.controller,
    required this.pair,
  });
  final TulkkiController controller;
  final CompetitionPair pair;

  String details(Map<String, dynamic> event) {
    final lines = <String>[];
    for (final raw
        in (event['originalSections'] ?? event['sections']) as List) {
      final data = Map<String, dynamic>.from(raw as Map);
      final section = controller.competition
          .sectionsFor(pair.number)
          .where((s) => s.id == data['id'])
          .firstOrNull;
      String label(String id) {
        final saved = event['originalLabels'] is Map
            ? (event['originalLabels'] as Map)[id]
            : null;
        if (saved is String) return saved;
        final index = section?.entries.indexWhere((e) => e.id == id) ?? -1;
        return index < 0
            ? id
            : '${section!.entries[index].label} (rivi ${index + 1})';
      }

      final missing = (data['missingEntryIds'] as List).cast<String>();
      final times = data['times'] is Map
          ? Map<String, dynamic>.from(data['times'] as Map)
          : <String, dynamic>{};
      lines.add(
        '${section?.name ?? data['id']}\nPuuttuvat: ${missing.isEmpty ? 'ei puuttuvia' : missing.map(label).join(', ')}',
      );
      if (times.isNotEmpty)
        lines.add(
          'Ajat: ${times.entries.map((e) => '${label(e.key)} ${e.value}').join(', ')}',
        );
      final points = data['otherPenaltyPoints'];
      lines.add(
        points == null
            ? 'Muut virheet: ${data['otherErrors']} kpl'
            : 'Muut virhepisteet: $points vp',
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final events = controller.competition.history
          .where((e) => e['pairNumber'] == pair.number)
          .toList()
          .reversed;
      return Scaffold(
        appBar: AppBar(title: Text('Pari ${pair.number} · muutoshistoria')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Palvelimelle tallennetut tulkkaukset, uusin ensin. Myös korvaantuneet kirjaukset näkyvät. Historia kertyy tämän version käyttöönotosta; paikalliset luonnokset eivät kuulu historiaan.',
            ),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Ei vielä vastaanotettua muutoshistoriaa.'),
              ),
            for (final event in events)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event['reviewer'] ?? 'Tarkastaja'} · ${DateTime.tryParse(event['savedAt'] as String)?.toLocal().toString().split('.').first ?? event['savedAt']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(details(event)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class PairScreen extends StatelessWidget {
  const PairScreen({super.key, required this.controller, required this.pair});
  final TulkkiController controller;
  final CompetitionPair pair;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('Pari ${pair.number}')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SaveStatus(controller: controller),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${pair.driver}\n${pair.navigator}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '${pair.className.isEmpty ? 'Luokka ei tiedossa' : 'Luokka ${pair.className}'} · ${controller.onlineCompetition ? 'Rata ${pair.routeId}' : 'Esimerkkirata · Lähtö 12:00:00'}\n${pair.emit ? 'Emit käytössä' : 'Käsiajanotto'}',
              ),
              TextButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Muutoshistoria'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => InterpretationHistory(
                      controller: controller,
                      pair: pair,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Koko kilpailu'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SectionScreen(
                      controller: controller,
                      pair: pair,
                      section: controller.competition
                          .sectionsFor(pair.number)
                          .first,
                      wholeCompetition: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final section in controller.competition.sectionsFor(
                pair.number,
              ))
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Icon(
                      controller.competition
                              .draft(pair.number, section.id)
                              .interpreted
                          ? Icons.check_circle
                          : Icons.edit_note,
                      color: spruce,
                      size: 30,
                    ),
                    title: Text(
                      section.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _sectionStatus(
                        controller.competition.draft(pair.number, section.id),
                        section,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SectionScreen(
                          controller: controller,
                          pair: pair,
                          section: section,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                controller.onlineCompetition
                    ? 'Valmis-painike lähettää jakson tai koko kilpailun tulkinnan sivustolle.'
                    : 'Tulkkaus on valmis, kun kaikki jaksot on merkitty tulkatuiksi. Esimerkkitiedot säilyvät tällä laitteella.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  String _sectionStatus(SectionDraft draft, RouteSection section) =>
      draft.interpreted && draft.incomplete(section, pair.emit).isNotEmpty
      ? 'Tulkattu · täydennä ${draft.incomplete(section, pair.emit).length} aikaa'
      : draft.interpreted
      ? controller.onlineCompetition
            ? (draft.synced
                  ? 'Tulkattu · lähetetty sivustolle'
                  : 'Tulkattu · odottaa lähetystä')
            : 'Tulkattu tällä laitteella'
      : draft.started
      ? 'Kesken'
      : 'Ei aloitettu';
}

class SectionScreen extends StatefulWidget {
  const SectionScreen({
    super.key,
    required this.controller,
    required this.pair,
    required this.section,
    this.wholeCompetition = false,
  });
  final TulkkiController controller;
  final CompetitionPair pair;
  final RouteSection section;
  final bool wholeCompetition;
  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  bool showErrors = false;
  bool completing = false;
  List<RouteSection> get sections => widget.wholeCompetition
      ? widget.controller.competition.sectionsFor(widget.pair.number)
      : [
          widget.controller.competition
              .sectionsFor(widget.pair.number)
              .firstWhere((s) => s.id == widget.section.id),
        ];
  SectionDraft draftFor(RouteSection section) =>
      widget.controller.competition.draft(widget.pair.number, section.id);
  bool get interpreted => sections.every((s) => draftFor(s).interpreted);
  @override
  void initState() {
    super.initState();
    widget.controller.editing.addAll(
      sections.map(
        (s) => widget.controller.competition.key(widget.pair.number, s.id),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.editing.removeAll(
      sections.map(
        (s) => widget.controller.competition.key(widget.pair.number, s.id),
      ),
    );
    super.dispose();
  }

  void change(RouteSection section, void Function(SectionDraft) edit) {
    unawaited(
      widget.controller.update((_) {
        final draft = draftFor(section);
        edit(draft);
        draft.changed();
      }),
    );
  }

  Future<void> complete() async {
    FocusScope.of(context).unfocus();
    if (sections.any(
      (s) => draftFor(s).incomplete(s, widget.pair.emit).isNotEmpty,
    )) {
      setState(() => showErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Syötä ajat tai merkitse aikamerkinnät puuttuviksi.'),
        ),
      );
      return;
    }
    setState(() => completing = true);
    await widget.controller.complete(widget.pair, sections);
    if (!mounted) return;
    setState(() => completing = false);
    if (widget.controller.saveError == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.onlineCompetition
                ? (widget.controller.competition.outbox.isEmpty
                      ? 'Tulkinta lähetetty sivustolle.'
                      : 'Tulkinta tallennettu laitteelle. Lähetys odottaa yhteyttä.')
                : widget.wholeCompetition
                ? 'Koko kilpailu tulkattu ja tallennettu tälle laitteelle.'
                : 'Jakso tulkattu ja tallennettu tälle laitteelle.',
          ),
        ),
      );
    }
  }

  Widget sectionEditor(RouteSection section) {
    final draft = draftFor(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.wholeCompetition) ...[
          const SizedBox(height: 20),
          Text(
            section.name,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
        ],
        for (final (index, entry) in section.entries.indexed)
          EntryTile(
            key: ValueKey(entry.id),
            entry: entry,
            index: index + 1,
            emit: widget.pair.emit,
            value: draft.value(entry.id),
            showErrors: showErrors,
            onMissing: (missing) =>
                change(section, (d) => d.setMissing(entry.id, missing)),
            onTime: (time) => change(
              section,
              (d) =>
                  d.setTime(entry.id, time, ula: entry.kind == EntryKind.ula),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Muut virhepisteet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 6),
                const Text('Ylimääräiset AT-, JAT- tai JRT-merkinnät'),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: draft.displayedPenaltyPoints == 0
                          ? null
                          : () => change(
                              section,
                              (d) => d.adjustOtherPenaltyPoints(-100),
                            ),
                      child: const Text('−100 vp'),
                    ),
                    Text(
                      draft.otherPenaltyPoints == null && draft.otherErrors > 0
                          ? '${draft.otherErrors} kpl'
                          : '${draft.displayedPenaltyPoints} vp',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    OutlinedButton(
                      onPressed:
                          draft.displayedPenaltyPoints >=
                              SectionDraft.maxOtherPenaltyPoints
                          ? null
                          : () => change(
                              section,
                              (d) => d.adjustOtherPenaltyPoints(100),
                            ),
                      child: const Text('+100 vp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final missingSigns = sections.fold(
        0,
        (sum, s) => sum + draftFor(s).missingSigns(s),
      );
      final missingTimes = sections.fold(
        0,
        (sum, s) => sum + draftFor(s).missingTimes(s),
      );
      final count = sections.fold(0, (sum, s) => sum + draftFor(s).otherErrors);
      final points = sections.fold(
        0,
        (sum, s) => sum + (draftFor(s).otherPenaltyPoints ?? 0),
      );
      final other = count > 0 ? '$points vp ja $count kpl' : '$points vp';
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.pair.number} · ${widget.wholeCompetition ? 'Koko kilpailu' : widget.section.name}',
          ),
        ),
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle)
              FocusScope.of(context).unfocus();
            return false;
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Vertaa korttia oikeaan riviin. Merkitse vain puuttuvat.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Aika syötetään vain käsin kirjattavilla asemilla. Aikamerkinnän puuttuminen merkitään myös muilla aika-asemilla.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final section in sections) sectionEditor(section),
                  Text(
                    'Yhteenveto: $missingSigns kilpipuutetta, $missingTimes aikapuutetta. Muut virheet: $other.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: completing || interpreted ? null : complete,
                    icon: Icon(
                      interpreted ? Icons.check_circle_outline : Icons.done_all,
                    ),
                    label: Text(
                      completing
                          ? 'Tallennetaan…'
                          : interpreted
                          ? widget.controller.onlineCompetition
                                ? (sections.any(
                                        (s) =>
                                            draftFor(s)
                                                .incomplete(s, widget.pair.emit)
                                                .isNotEmpty,
                                      )
                                      ? 'Tulkattu · täydennä uudet ajat'
                                      : sections.every(
                                          (s) => draftFor(s).synced,
                                        )
                                      ? 'Tulkattu · lähetetty sivustolle'
                                      : 'Valmis · odottaa lähetystä')
                                : 'Tulkattu tällä laitteella'
                          : widget.wholeCompetition
                          ? 'Merkitse koko kilpailu tulkatuksi'
                          : 'Merkitse jakso tulkatuksi',
                    ),
                  ),
                  if (interpreted)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        sections.any(
                              (s) =>
                                  draftFor(s)
                                      .incomplete(s, widget.pair.emit)
                                      .isNotEmpty,
                            )
                            ? 'Täydennä uudet ajat'
                            : 'Tulkkaa uudelleen',
                      ),
                      onPressed: () => widget.controller.update((_) {
                        for (final section in sections)
                          draftFor(section).changed();
                      }),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    widget.wholeCompetition
                        ? 'Vahvistus merkitsee kaikki jaksot tulkatuiksi. Aiemmat jaksoittaiset kirjaukset ovat mukana samassa näkymässä.'
                        : 'Vahvistus tarkoittaa, että koko jakso on tarkastettu. Korjaus avaa jakson uudelleen tulkattavaksi.',
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: SaveStatus(controller: widget.controller),
        ),
      );
    },
  );
}

class EntryTile extends StatefulWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.emit,
    required this.value,
    required this.showErrors,
    required this.onMissing,
    required this.onTime,
  });
  final RouteEntry entry;
  final int index;
  final bool emit;
  final EntryValue value;
  final bool showErrors;
  final ValueChanged<bool> onMissing;
  final ValueChanged<String> onTime;
  @override
  State<EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<EntryTile> {
  late final TextEditingController time;
  final clockFocus = FocusNode();
  bool get ula => widget.entry.kind == EntryKind.ula;

  String displayClock(String value) {
    final formatted = normalizeClockInput(value, ula: ula);
    if (ula && validClock(formatted) && formatted.endsWith(':00')) {
      return formatted.substring(0, 5);
    }
    return formatted;
  }

  @override
  void initState() {
    super.initState();
    time = TextEditingController(text: displayClock(widget.value.time));
    clockFocus.addListener(() {
      if (!clockFocus.hasFocus && !widget.value.missing) {
        final formatted = displayClock(time.text);
        if (formatted != time.text) {
          time.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    clockFocus.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.value.missing;
    final clock = widget.entry.requiresTime(widget.emit);
    final invalid =
        clock &&
        !missing &&
        widget.showErrors &&
        !validClock(normalizeClockInput(time.text, ula: ula));
    return Card(
      color: missing ? const Color(0xFFFFE3DF) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(color: Color(0xFF52645D)),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.entry.label,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Puuttuu'),
                  selected: missing,
                  showCheckmark: true,
                  onSelected: (value) {
                    if (value) time.clear();
                    widget.onMissing(value);
                  },
                ),
              ],
            ),
            if (clock)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: time,
                  focusNode: clockFocus,
                  enabled: !missing,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Aika',
                    hintText: ula ? '1845 tai 18:45' : '180334 tai 18:03:34',
                    errorText: invalid
                        ? (ula
                              ? 'Anna ULA-aika hhmm tai hh:mm tai merkitse puuttuvaksi'
                              : 'Anna aika hhmmss tai hh:mm:ss tai merkitse puuttuvaksi')
                        : null,
                  ),
                  onChanged: (value) {
                    // Webin semantiikkakentän poistuminen vieritysalueelta voi
                    // lähettää tyhjennyksen kohdistuksen jo poistuttua.
                    // Käyttäjän oma tyhjennys kohdistetussa kentässä säilyy.
                    if (value.isEmpty &&
                        !clockFocus.hasFocus &&
                        widget.value.time.isNotEmpty)
                      return;
                    widget.onTime(value);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
