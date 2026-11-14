<?php
/** Ajetaan vain erillisessä WordPress-testikannassa: php integration.php POLKU/wordpress */
if (PHP_SAPI !== 'cli' || empty($argv[1])) { exit(1); }
$_SERVER['HTTP_HOST'] = '127.0.0.1';
$_SERVER['SERVER_PROTOCOL'] = 'HTTP/1.1';
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
$_SERVER['REQUEST_METHOD'] = 'GET';
require rtrim($argv[1], '/\\') . '/wp-load.php';
require_once __DIR__ . '/../as-tulkki-yhteys.php';
AS_Tulkki_Yhteys::install();
AS_Tulkki_Yhteys::boot();
wp_set_current_user(1);
$checks = 0;
function check(bool $ok, string $name): void {
    global $checks; $checks++;
    if (!$ok) { throw new RuntimeException($name); }
}
function api(string $method, string $path, ?array $body = null, array $headers = []) {
    $r = new WP_REST_Request($method, '/as-tulkki/v1' . $path);
    if ($body !== null) { $r->set_header('Content-Type','application/json'); $r->set_body(json_encode($body)); }
    foreach ($headers as $key=>$value) { $r->set_header($key,$value); }
    return rest_do_request($r);
}
$provision = ['requestId'=>'create-' . bin2hex(random_bytes(8)), 'name'=>'Integraatiotesti',
    'joinCode'=>strtoupper(bin2hex(random_bytes(6))), 'key'=>bin2hex(random_bytes(24))];
$created = api('POST','/management/competitions',$provision);
check($created->get_status() === 200, 'AS2026 luo kilpailun rajapinnan kautta.');
$id = $created->get_data()['id']; $base = '/competitions/' . $id;
$manage = '/management/competitions/' . $id;
$codes = [1=>$provision['joinCode']]; $keys = [1=>$provision['key']];
$key = ['X-AS-Key'=>$provision['key']];
try {
    check(api('POST','/management/competitions',$provision)->get_data()['id'] === $id, 'Luontipyynnön uusinta ei luo toista kilpailua.');
    $different = $provision; $different['key'] = bin2hex(random_bytes(24));
    check(api('POST','/management/competitions',$different)->get_status() === 409, 'Samaa luontitunnistetta ei käytetä eri tiedoilla.');
    $different = $provision; $different['requestId'] .= '-new';
    check(api('POST','/management/competitions',$different)->get_status() === 409, 'Liittymiskoodin törmäys ei luo kilpailua.');
    $listing = api('GET','/management/competitions')->get_data();
    check(in_array($id, array_column($listing['competitions'], 'id'), true), 'AS2026 saa kilpailuluettelon.');
    check(!str_contains(json_encode($listing), $provision['key']), 'Hallinnan luettelo ei paljasta avaimia.');
    wp_set_current_user(0);
    check(api('POST','/management/competitions',$provision)->get_status() === 401, 'Anonyymi ei voi luoda kilpailua.');
    check(api('GET','/management/competitions')->get_status() === 401, 'Anonyymi ei saa hallinnan luetteloa.');
    $subscriber = wp_insert_user(['user_login'=>'as-tulkki-test-' . $id, 'user_pass'=>bin2hex(random_bytes(16)), 'role'=>'subscriber']);
    check(!is_wp_error($subscriber), 'Vähäisten oikeuksien testikäyttäjä luotu.');
    wp_set_current_user($subscriber);
    check(api('POST','/management/competitions',$provision)->get_status() === 403, 'Tavallinen WordPress-käyttäjä ei voi luoda kilpailua.');
    wp_set_current_user(0);
    check(api('GET',$base)->get_status() === 401, 'Anonyymi ei näe kilpailutietoja.');
    $query_key = new WP_REST_Request('GET', '/as-tulkki/v1' . $base);
    $query_key->set_param('key', $keys[1]);
    check(rest_do_request($query_key)->get_status() === 401, 'Avainta ei lueta URL:stä.');
    check(api('POST','/join',['code'=>'wrong','name'=>'Tarkistaja'])->get_status() === 401, 'Väärä liittymiskoodi hylätään.');
    $joined = api('POST','/join',['code'=>strtolower($codes[1]),'name'=>'Tarkistaja A']);
    check($joined->get_status() === 201, 'Koodilla ja nimellä liittyminen.');
    $token = ['X-AS-Token'=>$joined->get_data()['token']];
    $joined2 = api('POST','/join',['code'=>$codes[1],'name'=>'Tarkistaja B']);
    $token2 = ['X-AS-Token'=>$joined2->get_data()['token']];
    check(api('PUT',$manage.'/connection',['active'=>false],$token)->get_status() === 401, 'Puhelin ei voi sulkea kilpailua.');
    check(api('PUT',$manage.'/credentials',['joinCode'=>$codes[1],'key'=>$keys[1]],$key)->get_status() === 401, 'Kilpailuavain ei anna WordPressin ylläpito-oikeutta.');
    $manifest = json_decode(file_get_contents(__DIR__ . '/../examples/manifest.json'), true);
    $manifest['manifest']['routes'][0]['sections'][] = ['id'=>'j2','name'=>'Jakso 2',
        'entries'=>[['id'=>'j2-e1','label'=>'M','kind'=>'maali','manualTime'=>false]]];
    check(api('PUT',$base.'/manifest',$manifest,$token)->get_status() === 401, 'Puhelin ei muuta oikeaa riviä.');
    $uploaded = api('PUT',$base.'/manifest',$manifest,$key);
    check($uploaded->get_status() === 200 && $uploaded->get_data()['revision'] === 1, 'AS2026 lataa kilpailutiedot.');
    check(api('PUT',$base.'/manifest',$manifest,$key)->get_data()['revision'] === 1, 'Identtinen uusintalähetys ei muuta versiota.');
    $download = api('GET',$base,null,$token);
    check($download->get_data()['manifest']['routes'][0]['sections'][0]['entries'][1]['label'] === '15', 'Puhelin saa myös toistuvan kilven.');
    $submission = json_decode(file_get_contents(__DIR__ . '/../examples/interpretation.json'), true);
    $bad = $submission; $bad['revision'] = 99;
    check(api('POST',$base.'/interpretations',$bad,$token)->get_status() === 409, 'Vanhentunut kilpailuversio ei kirjoita.');
    $bad = $submission; $bad['sections'][0]['times'] = [];
    check(api('POST',$base.'/interpretations',$bad,$token)->get_status() === 400, 'Puuttuva pakollinen aika estää tallennuksen.');
    check(api('GET',$base.'/interpretations',null,$key)->get_data()['events'] === [], 'Hylätty lähetys ei luo tapahtumaa.');
    $whole = $submission; $whole['requestId'] = 'atomic-whole';
    $whole['sections'][] = ['id'=>'j2','missingEntryIds'=>[],'times'=>['j2-e1'=>'99:00:00']];
    check(api('POST',$base.'/interpretations',$whole,$token)->get_status() === 400, 'Koko kilpailun viimeisen jakson virhe estää kaikki jaksot.');
    check(api('GET',$base.'/interpretations',null,$key)->get_data()['events'] === [], 'Koko kilpailun osittaista tulkintaa ei syntynyt.');
    // Todellinen tietokantavirhe toisen jakson kirjoituksessa: tapahtuman ja ensimmäisenkin jakson on palauduttava.
    global $wpdb;
    $trigger = 'as_tulkki_test_fail_' . $id;
    check($wpdb->query('CREATE TRIGGER ' . $trigger . ' BEFORE INSERT ON ' . $wpdb->prefix .
        "as_tulkki_results FOR EACH ROW BEGIN IF NEW.section_id='j2' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='test failure'; END IF; END") !== false, 'Testin tietokantavirhe asetettu.');
    $whole['sections'][1]['times'] = [];
    $old_suppress = $wpdb->suppress_errors(true);
    try { $failed = api('POST',$base.'/interpretations',$whole,$token); }
    finally { $wpdb->suppress_errors($old_suppress); $wpdb->query('DROP TRIGGER IF EXISTS ' . $trigger); }
    check($failed->get_status() === 500, 'Tietokantavirhe ilmoitetaan tallentamatta.');
    check(api('GET',$base.'/interpretations',null,$key)->get_data()['events'] === [], 'Tietokantavirhe peruu myös tapahtuman.');
    check((int)$wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM '.$wpdb->prefix.'as_tulkki_results WHERE competition_id=%d',$id)) === 0, 'Tietokantavirhe peruu ensimmäisenkin jakson.');
    $saved = api('POST',$base.'/interpretations',$submission,$token);
    check($saved->get_status() === 201, 'Valmis tulkinta tallentuu.');
    $event1 = $saved->get_data()['eventId'];
    $correction = $submission; $correction['requestId'] = 'correction-002';
    $correction['sections'][0]['missingEntryIds'] = ['r1-e1'];
    check(api('POST',$base.'/interpretations',$correction,$token2)->get_status() === 201, 'Toinen tarkistaja saa korjata samaa paria ilman lukitusta.');
    $replay = api('POST',$base.'/interpretations',$submission,$token);
    check($replay->get_status() === 200 && $replay->get_data()['eventId'] === $event1 && $replay->get_data()['replayed'], 'Vanhan lähetyksen uusinta ei korvaa uudempaa korjausta.');
    $bad = $submission; $bad['sections'][0]['note'] = 'muutettu';
    check(api('POST',$base.'/interpretations',$bad,$token)->get_status() === 409, 'Samaa lähetyksen tunnistetta ei käytetä eri sisältöön.');
    $feed = api('GET',$base.'/interpretations',null,$key)->get_data();
    check(count($feed['events']) === 2 && $feed['events'][1]['reviewer'] === 'Tarkistaja B', 'Muutossyöte sisältää molemmat tulkinnat järjestyksessä.');
    check(api('GET',$base.'/interpretations',null,$token)->get_status() === 200, 'Myös puhelin voi synkronoida korjaukset.');
    $r = new WP_REST_Request('GET','/as-tulkki/v1'.$base.'/interpretations');
    $r->set_header('X-AS-Key',$keys[1]); $r->set_param('after',$feed['nextCursor']);
    check(rest_do_request($r)->get_data()['events'] === [], 'Kohdistin ei palauta jo kuitattuja tapahtumia.');
    global $wpdb;
    $latest = json_decode($wpdb->get_var($wpdb->prepare('SELECT payload FROM '.$wpdb->prefix.'as_tulkki_results WHERE competition_id=%d',$id)),true);
    check($latest['missingEntryIds'] === ['r1-e1'], 'Viimeisin tallennus on voimassa.');
    $changed = $manifest; $changed['baseRevision'] = 1; $changed['manifest']['pairs'][0]['driver'] = 'Uusi';
    check(api('PUT',$base.'/manifest',$changed,$key)->get_status() === 409, 'Oikeaa riviä ei vaihdeta tulkintojen alta tässä versiossa.');
    $voided = $manifest; $voided['baseRevision'] = 1;
    $voided['manifest']['routes'][0]['sections'][0]['entries'][0]['voided'] = true;
    $saved_void = api('PUT',$base.'/manifest',$voided,$key);
    check($saved_void->get_status() === 200 && $saved_void->get_data()['revision'] === 2, 'Yksittäinen RT-kilpi mitätöidään tulkintojen jälkeen.');
    check(api('PUT',$base.'/manifest',$voided,$key)->get_data()['revision'] === 2, 'Mitätöinnin uusinta on idempotentti.');
    $feed = api('GET',$base.'/interpretations',null,$token)->get_data();
    check($feed['revision'] === 2 && $feed['manifest']['routes'][0]['sections'][0]['entries'][0]['voided'], 'Puhelin saa uuden oikean rivin myös muutossyötteessä.');
    check($feed['events'][1]['sections'][0]['missingSigns'] === 0 && $feed['events'][1]['revision'] === 2, 'Vanha tulkinta normalisoidaan mitätöinnin jälkeen.');
    $original = json_decode($wpdb->get_var($wpdb->prepare('SELECT payload FROM '.$wpdb->prefix.'as_tulkki_events WHERE id=%d',$event1)),true);
    check($original['revision'] === 1, 'Alkuperäinen tapahtuma säilyy muuttumattomana.');
    $restore = $manifest; $restore['baseRevision'] = 2;
    check(api('PUT',$base.'/manifest',$restore,$key)->get_status() === 409, 'Mitätöityä kilpeä ei palauteta.');
    $old_phone = $submission; $old_phone['requestId'] = 'old-phone-after-void';
    $old_phone['sections'][0]['missingEntryIds'] = ['r1-e1','r1-e2'];
    check(api('POST',$base.'/interpretations',$old_phone,$token)->get_status() === 201, 'Avoinna ollut puhelintulkinta voidaan viimeistellä mitätöinnin jälkeen.');
    $feed = api('GET',$base.'/interpretations',null,$key)->get_data();
    check($feed['events'][2]['sections'][0]['missingEntryIds'] === ['r1-e2'] && $feed['events'][2]['sections'][0]['missingSigns'] === 1, 'Muut saman numeron esiintymät säilyvät.');
    $wpdb->update($wpdb->prefix.'as_tulkki_sessions',['expires_at'=>'2000-01-01 00:00:00'],['competition_id'=>$id]);
    check(api('GET',$base,null,$token)->get_status() === 401, 'Vanhentunut puhelinistunto ei kelpaa.');
    wp_set_current_user(1);
    check(api('PUT',$manage.'/connection',['active'=>false])->get_status() === 200, 'AS2026 sulkee yhteyden.');
    check(api('PUT',$manage.'/connection',['active'=>false])->get_data()['active'] === false, 'Sulkemispyynnön uusinta ei avaa yhteyttä.');
    wp_set_current_user(0);
    check(api('GET',$base,null,$key)->get_status() === 404, 'Suljettua kilpailua ei voi käyttää edes AS2026-avaimella.');
    check(api('POST','/join',['code'=>$codes[1],'name'=>'Tarkistaja'])->get_status() === 401, 'Suljettuun kilpailuun ei voi liittyä.');
    wp_set_current_user(1);
    api('PUT',$manage.'/connection',['active'=>true]);
    wp_set_current_user(0);
    check(api('GET',$base,null,$key)->get_status() === 200, 'Uudelleenavaus säilyttää AS2026-avaimen.');
    $fresh = api('POST','/join',['code'=>$codes[1],'name'=>'Tarkistaja']);
    check($fresh->get_status() === 201, 'Uudelleenavattuun kilpailuun voi liittyä.');
    $token = ['X-AS-Token'=>$fresh->get_data()['token']];
    wp_set_current_user(1);
    $new_credentials = ['joinCode'=>strtoupper(bin2hex(random_bytes(6))), 'key'=>bin2hex(random_bytes(24))];
    check(api('PUT',$manage.'/credentials',$new_credentials)->get_status() === 200, 'AS2026 vaihtaa tunnukset.');
    wp_set_current_user(0);
    check(api('GET',$base,null,$token)->get_status() === 401, 'Tunnusten vaihto mitätöi puhelinistunnon.');
    check(api('GET',$base,null,$key)->get_status() === 401, 'Vanha AS2026-avain ei kelpaa vaihdon jälkeen.');
    check(api('POST','/join',['code'=>$codes[1],'name'=>'Tarkistaja'])->get_status() === 401, 'Vanha liittymiskoodi ei kelpaa.');
    $new_session = api('POST','/join',['code'=>$new_credentials['joinCode'],'name'=>'Tarkistaja']);
    check($new_session->get_status() === 201, 'AS2026:n uusi liittymiskoodi toimii.');
    wp_set_current_user(1);
    api('PUT',$manage.'/credentials',$new_credentials);
    wp_set_current_user(0);
    check(api('GET',$base,null,['X-AS-Token'=>$new_session->get_data()['token']])->get_status() === 200, 'Tunnusten vaihdon uusintapyyntö ei katkaise uutta istuntoa.');
    wp_set_current_user(1);
    api('PUT',$manage.'/connection',['name'=>'Uusi nimi']);
    wp_set_current_user(0);
    check(api('GET',$base,null,['X-AS-Key'=>$new_credentials['key']])->get_data()['name'] === 'Uusi nimi', 'Kilpailun nimi päivitetään AS2026:sta.');
    $owner=['X-AS-Key'=>$new_credentials['key']];
    $corrected=$voided;$corrected['baseRevision']=2;
    $corrected['manifest']['routes'][0]['sections'][0]['entries']=array_values(array_filter($corrected['manifest']['routes'][0]['sections'][0]['entries'],static fn($e)=>$e['id']!=='r1-e2'));
    $corrected['manifest']['routes'][0]['sections'][0]['entries'][]=['id'=>'r1-new','label'=>'09','kind'=>'rt'];
    check(api('PUT',$base.'/manifest',$corrected,$owner)->get_data()['revision']===3,'RT-rivin korvaaminen säilyttää tehdyt tulkkaukset.');
    $feed=api('GET',$base.'/interpretations',null,$owner)->get_data();
    check($feed['events'][2]['sections'][0]['missingSigns']===0 && $feed['events'][2]['sections'][0]['interpreted'],'Poistettu RT poistuu puutteista, tulkattu-tila säilyy.');
    check(in_array('r1-e2',$feed['events'][2]['originalSections'][0]['missingEntryIds'],true),'Alkuperäinen puute säilyy historiassa.');
    check(str_contains($feed['events'][2]['originalLabels']['r1-e2'],'15'),'Poistetun kilven alkuperäinen nimi säilyy.');
    $stale=$old_phone;$stale['requestId']='old-phone-after-row-correction';
    check(api('POST',$base.'/interpretations',$stale,$owner)->get_status()===201,'Yhteensopivan vanhan rivin lähetysjono voidaan viimeistellä.');
    $bad_clock=$corrected;$bad_clock['baseRevision']=3;
    foreach($bad_clock['manifest']['routes'][0]['sections'][0]['entries'] as &$entry){if($entry['kind']==='at'){$entry['label']='AT9';}}unset($entry);
    check(api('PUT',$base.'/manifest',$bad_clock,$owner)->get_status()===409,'Aika-aseman muutos estetään tallennettujen tulkkausten alta.');
    $added_ula=$corrected;$added_ula['baseRevision']=3;
    foreach($added_ula['manifest']['routes'][0]['sections'][0]['entries'] as $i=>$entry){if($entry['kind']==='jat'){array_splice($added_ula['manifest']['routes'][0]['sections'][0]['entries'],$i+1,0,[['id'=>'new-ula','label'=>'ULA3','kind'=>'ula','manualTime'=>true]]);break;}}
    check(api('PUT',$base.'/manifest',$added_ula,$owner)->get_data()['revision']===4,'ULA lisätään julkaistuun kilpailuun JAT:n jälkeen.');
    $feed=api('GET',$base.'/interpretations',null,$owner)->get_data();
    check(end($feed['events'])['sections'][0]['pendingTimeIds']===['new-ula'],'Vanha tulkinta odottaa vain uuden ULA-ajan täydennystä.');
    $missing_ula=$stale;$missing_ula['requestId']='new-revision-without-ula';$missing_ula['revision']=4;$missing_ula['sections'][0]['missingEntryIds']=[];
    check(api('POST',$base.'/interpretations',$missing_ula,$owner)->get_status()===400,'Nykyversion uusi tulkkaus ei saa jättää ULA-aikaa avoimeksi.');
    $filled_ula=$missing_ula;$filled_ula['requestId']='filled-ula';$filled_ula['sections'][0]['times']['new-ula']='12:12:00';
    check(api('POST',$base.'/interpretations',$filled_ula,$owner)->get_status()===201,'Uusi ULA-aika voidaan täydentää.');
    echo "$checks WordPress/MariaDB-tarkistusta läpäisty.\n";
} finally {
    global $wpdb;
    $wpdb->query('DROP TRIGGER IF EXISTS as_tulkki_test_fail_' . $id);
    foreach (['results','events','sessions'] as $table) { $wpdb->delete($wpdb->prefix.'as_tulkki_'.$table,['competition_id'=>$id]); }
    $wpdb->delete($wpdb->prefix.'as_tulkki_competitions',['id'=>$id]);
    if (isset($subscriber) && !is_wp_error($subscriber)) {
        require_once ABSPATH . 'wp-admin/includes/user.php'; wp_delete_user($subscriber);
    }
}
