<?php
require_once __DIR__ . '/../includes/validation.php';
$checks = 0;
function check(bool $ok, string $name): void {
    global $checks; $checks++;
    if (!$ok) { throw new RuntimeException($name); }
}
function rejects(callable $call, string $name): void {
    try { $call(); } catch (InvalidArgumentException $e) { check(true, $name); return; }
    check(false, $name);
}
$manifest = AS_Tulkki_Data::manifest([
    'routes'=>[['id'=>'r1','name'=>'M','sections'=>[
        ['id'=>'j1','name'=>'Jakso 1','entries'=>[
            ['id'=>'e1','label'=>'15','kind'=>'rt'],
            ['id'=>'e2','label'=>'15','kind'=>'rt'],
            ['id'=>'e3','label'=>'AT','kind'=>'at','manualTime'=>true],
            ['id'=>'e4','label'=>'JAT','kind'=>'jat','manualTime'=>false],
        ]],
        ['id'=>'j2','name'=>'Maali','entries'=>[
            ['id'=>'e5','label'=>'ULA','kind'=>'ula'],
            ['id'=>'e6','label'=>'M','kind'=>'maali'],
        ]],
    ]]],
    'pairs'=>[['number'=>101,'driver'=>'Aino','navigator'=>'Eero','routeId'=>'r1','emit'=>true],
        ['number'=>102,'driver'=>'Sami','navigator'=>'Kaisa','routeId'=>'r1','emit'=>false]],
]);
$body = ['pairNumber'=>101, 'sections'=>[
    ['id'=>'j1','missingEntryIds'=>['e2','e4'],'times'=>['e3'=>'12:34:03']],
    ['id'=>'j2','missingEntryIds'=>[],'times'=>[]],
]];
$result = AS_Tulkki_Data::submission($body, $manifest);
check($result['sections'][0]['missingSigns'] === 1, 'Toistuva numero erotetaan esiintymätunnisteella.');
check($result['sections'][0]['missingTimes'] === 1, 'Automaattinenkin aikamerkintä voi puuttua.');
check(count($result['sections']) === 2, 'Koko kilpailu hyväksytään yhdellä pyynnöllä.');
$bad = $body; unset($bad['sections'][0]['times']['e3']);
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Pakollinen aika puuttuu.');
$bad = $body; $bad['sections'][0]['times']['e3'] = '24:00:00';
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Virheellinen kellonaika.');
$bad = $body; $bad['sections'][0]['missingEntryIds'][] = 'e3';
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Samalla rivillä puuttuva ja aika.');
$bad = $body; $bad['sections'][0]['times']['e4'] = '12:00:00'; $bad['sections'][0]['missingEntryIds'] = [];
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Ei käsin syötettävää aikaa automaattiselle riville.');
$bad = $body; $bad['sections'][0]['missingEntryIds'][] = 'e6';
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Toisen jakson tunniste ei kelpaa.');
$bad = $body; $bad['sections'][0]['missingEntryIds'][] = 'e2';
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Sama esiintymä ei puutu kahdesti.');
$bad = $body; $bad['sections'][] = $body['sections'][0];
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Jakso ei toistu.');
$bad = $body; $bad['pairNumber'] = 999;
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Tuntematon kilpailupari.');
$bad = $body; $bad['pairNumber'] = 102;
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'ULA ja M vaativat ajan ilman Emitiä.');
$bad['sections'][1]['times'] = ['e5'=>'12:00:00','e6'=>'12:30:00'];
check(count(AS_Tulkki_Data::submission($bad,$manifest)['sections']) === 2, 'ULA ja M käsin.');
$bad = $body; $bad['sections'][0]['otherErrors'] = -1;
rejects(fn()=>AS_Tulkki_Data::submission($bad,$manifest), 'Negatiivisia virheitä ei hyväksytä.');
$direct = $body;
$direct['sections'][0]['otherPenaltyPoints'] = 300;
$direct['sections'][1]['otherErrors'] = 2;
$result = AS_Tulkki_Data::submission($direct, $manifest);
check($result['sections'][0]['otherPenaltyPoints'] === 300, 'Suorat pisteet säilyvät.');
check($result['sections'][1]['otherErrors'] === 2 && !isset($result['sections'][1]['otherPenaltyPoints']), 'Vanha jakso säilyy kappalemääränä.');
$old_history = [
    ['id'=>'j1', 'otherPenaltyPoints'=>null, 'otherErrors'=>0],
    ['id'=>'j2', 'otherPenaltyPoints'=>0, 'otherErrors'=>0],
    ['id'=>'j3', 'otherPenaltyPoints'=>300, 'otherErrors'=>0],
    ['id'=>'j4', 'otherErrors'=>2],
];
$history = AS_Tulkki_Data::omit_empty_penalty_points($old_history);
check(!array_key_exists('otherPenaltyPoints', $history[0]), 'Vanhan tapahtuman null poistetaan muutossyötteestä.');
check($history[1] === $old_history[1] && $history[2] === $old_history[2] && $history[3] === $old_history[3], 'Nolla, pisteet ja vanha kappalemäärä säilyvät.');
$direct['sections'][0]['otherPenaltyPoints'] = 350;
rejects(fn()=>AS_Tulkki_Data::submission($direct,$manifest), 'Pisteet annetaan sadan askelin.');
$direct['sections'][0]['otherPenaltyPoints'] = 0;
$direct['sections'][0]['otherErrors'] = 1;
rejects(fn()=>AS_Tulkki_Data::submission($direct,$manifest), 'Samalla jaksolla hyväksytään yksi virheiden esitystapa.');
$bad = $manifest; $bad['routes'][0]['sections'][0]['entries'][1]['id'] = 'e1';
rejects(fn()=>AS_Tulkki_Data::manifest($bad), 'Pysyvä asematunniste on yksikäsitteinen.');
$bad = $manifest; $bad['routes'][0]['sections'][0]['entries'][0]['manualTime'] = true;
rejects(fn()=>AS_Tulkki_Data::manifest($bad), 'RT ei ole aikarivi.');
$bad = $manifest; $bad['routes'][0]['sections'][0]['entries'][1]['voided'] = true;
rejects(fn()=>AS_Tulkki_Data::submission($body,$bad), 'Mitätöityä asemaa ei merkitä puuttuvaksi.');
$with_class=$manifest; $with_class['pairs'][0]['className']='E';
$with_class=AS_Tulkki_Data::manifest($with_class);
check($with_class['pairs'][0]['className']==='E','Luokka välittyy puhelimelle.');
check(AS_Tulkki_Data::void_only($manifest,$with_class),'Luokan lisäys sallitaan aiempiin tulkintoihin.');
$wrong_route=$with_class; $wrong_route['pairs'][0]['routeId']='other';
check(!AS_Tulkki_Data::void_only($with_class,$wrong_route),'Luokkatieto ei salli radan vaihtoa.');
echo "$checks tarkistusta läpäisty.\n";
$corrected=$manifest;
$corrected['routes'][0]['sections'][0]['entries']=array_values(array_filter($corrected['routes'][0]['sections'][0]['entries'],static fn($e)=>$e['id']!=='e2'));
$corrected['routes'][0]['sections'][0]['entries'][]=['id'=>'e-new','label'=>'09','kind'=>'rt','manualTime'=>null,'voided'=>false];
check(AS_Tulkki_Data::compatible_row_change($manifest,$corrected),'RT-korjaus säilyttää aika-asemat ja jaksot.');
$migrated=AS_Tulkki_Data::submission(AS_Tulkki_Data::project_submission($body,$corrected),$corrected);
check(!in_array('e2',$migrated['sections'][0]['missingEntryIds'],true),'Poistettu RT poistuu nykyisistä puutteista.');
check(!in_array('e-new',$migrated['sections'][0]['missingEntryIds'],true),'Uutta RT:tä ei merkitä puuttuvaksi.');
check($migrated['sections'][0]['interpreted']===true,'Tulkattu-tila säilyy.');
$bad_clock=$corrected;foreach($bad_clock['routes'][0]['sections'][0]['entries'] as &$e){if($e['id']==='e3'){$e['label']='AT9';}}unset($e);
check(!AS_Tulkki_Data::compatible_row_change($corrected,$bad_clock),'Aikamerkintää ei kohdisteta muuttuneeseen asemaan.');
echo "Yhteensä $checks tarkistusta läpäisty.\n";
$with_ula=$manifest;
$with_ula['routes'][0]['sections'][0]['entries'][]=['id'=>'new-ula','label'=>'ULA3','kind'=>'ula','manualTime'=>true,'voided'=>false];
check(AS_Tulkki_Data::compatible_row_change($manifest,$with_ula),'ULA lisätään JAT:n jälkeen julkaistuun riviin.');
$pending=AS_Tulkki_Data::submission(AS_Tulkki_Data::project_submission($body,$with_ula),$with_ula,true);
check($pending['sections'][0]['pendingTimeIds']===['new-ula'] && $pending['sections'][0]['interpreted'],'Vanha tulkinta säilyy, uusi ULA-aika on täydennettävä.');
check(!in_array('new-ula',$pending['sections'][0]['missingEntryIds'],true),'ULA ei muutu puuttuvaksi asemaksi.');
rejects(fn()=>AS_Tulkki_Data::submission($body,$with_ula),'Uusi tulkkaus vaatii ULA-ajan tai puuttumismerkinnän.');
$completed=$body;$completed['sections'][0]['times']['new-ula']='12:12:00';
check(AS_Tulkki_Data::submission($completed,$with_ula)['sections'][0]['pendingTimeIds']===[],'Täydennetty ULA-aika valmistuu.');
echo "Yhteensä $checks tarkistusta läpäisty.\n";
