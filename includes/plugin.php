<?php
defined('ABSPATH') || exit;

final class AS_Tulkki_Yhteys {
    private const VERSION = '3';
    private const NS = 'as-tulkki/v1';
    private static function table(string $name): string {
        global $wpdb;
        return $wpdb->prefix . 'as_tulkki_' . $name;
    }
    public static function install(): void {
        global $wpdb;
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        $collate = $wpdb->get_charset_collate();
        $schemas = [
            'competitions' => "id bigint unsigned NOT NULL AUTO_INCREMENT,
                provision_id varchar(80) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
                name varchar(190) NOT NULL,
                join_hash varchar(64) NOT NULL,
                key_hash varchar(64) NOT NULL,
                generation bigint unsigned NOT NULL DEFAULT 1,
                active tinyint NOT NULL DEFAULT 1,
                revision bigint unsigned NOT NULL DEFAULT 0,
                manifest longtext NULL,
                manifest_history longtext NULL,
                minimum_revision bigint unsigned NOT NULL DEFAULT 0,
                created_at datetime NOT NULL,
                PRIMARY KEY  (id),
                UNIQUE KEY provision_id (provision_id),
                UNIQUE KEY join_hash (join_hash)",
            'sessions' => "id bigint unsigned NOT NULL AUTO_INCREMENT,
                competition_id bigint unsigned NOT NULL,
                token_hash varchar(64) NOT NULL,
                reviewer varchar(190) NOT NULL,
                generation bigint unsigned NOT NULL,
                expires_at datetime NOT NULL,
                PRIMARY KEY  (id),
                UNIQUE KEY token_hash (token_hash),
                KEY competition_id (competition_id)",
            'events' => "id bigint unsigned NOT NULL AUTO_INCREMENT,
                competition_id bigint unsigned NOT NULL,
                request_id varchar(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
                request_hash varchar(64) NOT NULL,
                payload longtext NOT NULL,
                created_at datetime NOT NULL,
                PRIMARY KEY  (id),
                UNIQUE KEY request_once (competition_id,request_id),
                KEY competition_cursor (competition_id,id)",
            'results' => "id bigint unsigned NOT NULL AUTO_INCREMENT,
                competition_id bigint unsigned NOT NULL,
                pair_number bigint unsigned NOT NULL,
                section_id varchar(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
                event_id bigint unsigned NOT NULL,
                payload longtext NOT NULL,
                PRIMARY KEY  (id),
                UNIQUE KEY latest_section (competition_id,pair_number,section_id)",
        ];
        foreach ($schemas as $name => $columns) {
            dbDelta('CREATE TABLE ' . self::table($name) . " ($columns) ENGINE=InnoDB $collate;");
        }
        // Älä merkitse asennusta onnistuneeksi, jos taulu tai transaktiotuki puuttuu.
        foreach (array_keys($schemas) as $name) {
            $table = self::table($name);
            $engine = $wpdb->get_var($wpdb->prepare(
                'SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s', $table));
            if (strtolower((string)$engine) !== 'innodb') {
                wp_die(esc_html('AS tulkki: tietokantataulujen luonti epäonnistui tai InnoDB puuttuu.'));
            }
        }
        $columns=$wpdb->get_col('SHOW COLUMNS FROM '.self::table('competitions'),0);
        if($wpdb->last_error || array_diff(['manifest_history','minimum_revision'],$columns?:[])){
            wp_die(esc_html('AS tulkki: tietokannan päivitys ei onnistunut. Kilpailutiedot säilyvät; tarkista tietokannan ALTER-oikeudet ja aktivoi lisäosa uudelleen.'));
        }
        update_option('as_tulkki_schema', self::VERSION, false);
    }
    public static function boot(): void {
        if (get_option('as_tulkki_schema') !== self::VERSION) { self::install(); }
        add_action('template_redirect', [self::class, 'app_redirect'], 0);
        add_action('rest_api_init', [self::class, 'routes']);
        add_filter('rest_allowed_cors_headers', static function ($headers) {
            return array_unique(array_merge($headers, ['X-AS-Token', 'X-AS-Key']));
        });
        add_filter('rest_post_dispatch', static function ($response, $server, $request) {
            if (str_starts_with($request->get_route(), '/' . self::NS . '/')) {
                $response->header('Cache-Control', 'no-store, private');
            }
            return $response;
        }, 10, 3);
    }
    /** Julkinen selainkäyttöliittymä. Kilpailutiedot vaativat edelleen liittymiskoodin. */
    public static function app_redirect(): void {
        $path = wp_parse_url(wp_unslash($_SERVER['REQUEST_URI'] ?? ''), PHP_URL_PATH);
        $expected = wp_parse_url(home_url('/as-tulkki/'), PHP_URL_PATH);
        if (!is_string($path) || !is_string($expected) || rtrim($path, '/') !== rtrim($expected, '/')) { return; }
        if (!is_file(dirname(AS_TULKKI_PLUGIN_FILE) . '/app/index.html')) { return; }
        nocache_headers();
        wp_safe_redirect(plugins_url('app/index.php', AS_TULKKI_PLUGIN_FILE), 302);
        exit;
    }
    private static function error(string $message, int $status = 400): WP_Error {
        return new WP_Error('as_tulkki_error', $message, ['status'=>$status]);
    }
    private static function secret(): string { return bin2hex(random_bytes(24)); }
    private static function digest(string $text): string { return hash('sha256', $text); }
    private static function now(): string { return gmdate('Y-m-d H:i:s'); }
    private static function check($result): void {
        if ($result === false) { throw new RuntimeException('Tietokantakirjoitus epäonnistui.'); }
    }
    private static function begin(): void {
        global $wpdb;
        self::check($wpdb->query('START TRANSACTION'));
    }
    private static function commit(): void {
        global $wpdb;
        self::check($wpdb->query('COMMIT'));
    }
    private static function rollback(): void { global $wpdb; $wpdb->query('ROLLBACK'); }
    private static function body($request): array {
        if (strlen($request->get_body()) > 2 * 1024 * 1024) {
            throw new InvalidArgumentException('Pyyntö on liian suuri (enintään 2 Mt).');
        }
        return AS_Tulkki_Data::object($request->get_json_params());
    }
    public static function routes(): void {
        AS_Tulkki_Management::routes();
        register_rest_route(self::NS, '/join', ['methods'=>'POST', 'permission_callback'=>[self::class,'transport'], 'callback'=>[self::class,'join']]);
        $base = '/competitions/(?P<id>[1-9][0-9]*)';
        foreach ([
            [$base, 'GET', 'read', 'download'],
            [$base . '/manifest', 'PUT', 'owner', 'upload'],
            [$base . '/interpretations', 'POST', 'read', 'submit'],
            [$base . '/interpretations', 'GET', 'read', 'changes'],
        ] as [$path,$methods,$permission,$callback]) {
            register_rest_route(self::NS, $path, ['methods'=>$methods,
                'permission_callback'=>[self::class,$permission], 'callback'=>[self::class,$callback]]);
        }
    }
    public static function transport($request) {
        if (!is_ssl() && wp_get_environment_type() !== 'local') {
            return self::error('Yhteys vaatii HTTPS:n.', 403);
        }
        if (get_option('as_tulkki_schema') !== self::VERSION) {
            return self::error('Aktivoi AS tulkki -lisäosa uudelleen tietokannan alustamiseksi.', 503);
        }
        return true;
    }
    /** Avaimia ei koskaan hyväksytä URL-parametreista. */
    private static function identity($request, bool $owner_only = false) {
        global $wpdb;
        $secure = self::transport($request);
        if (is_wp_error($secure)) { return $secure; }
        $id = (int)$request['id'];
        $competition = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::table('competitions') . ' WHERE id=%d AND active=1', $id), ARRAY_A);
        if (!$competition) { return self::error('Kilpailua ei löydy tai yhteys on suljettu.', 404); }
        $key = $request->get_header('x-as-key');
        if (is_string($key) && strlen($key) === 48 && hash_equals($competition['key_hash'], self::digest($key))) {
            return ['competition'=>$competition, 'reviewer'=>'AS2026', 'owner'=>true];
        }
        if (!$owner_only) {
            $token = $request->get_header('x-as-token');
            if (is_string($token) && strlen($token) === 48) {
                $session = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::table('sessions') .
                    ' WHERE competition_id=%d AND token_hash=%s AND generation=%d AND expires_at>%s',
                    $id, self::digest($token), $competition['generation'], self::now()), ARRAY_A);
                if ($session) { return ['competition'=>$competition, 'reviewer'=>$session['reviewer'], 'owner'=>false]; }
            }
        }
        return self::error('Virheellinen tai vanhentunut yhteysavain.', 401);
    }
    public static function owner($request) {
        $identity = self::identity($request, true);
        return is_wp_error($identity) ? $identity : true;
    }
    public static function read($request) {
        $identity = self::identity($request);
        return is_wp_error($identity) ? $identity : true;
    }
    public static function join($request) {
        global $wpdb;
        // IP ei tule asiakkaan vapaasti määritettävästä X-Forwarded-For-otsakkeesta.
        $bucket = 'as_tulkki_join_' . hash_hmac('sha256', $_SERVER['REMOTE_ADDR'] ?? 'unknown', wp_salt('auth'));
        $attempts = (int)get_transient($bucket);
        if ($attempts >= 30) { return self::error('Liikaa liittymisyrityksiä. Odota minuutti.', 429); }
        set_transient($bucket, $attempts + 1, MINUTE_IN_SECONDS);
        try {
            $body = self::body($request);
            $code = strtoupper(trim(AS_Tulkki_Data::text($body['code'] ?? null, 32)));
            $reviewer = trim(AS_Tulkki_Data::text($body['name'] ?? null, 120));
            if (!$reviewer) { throw new InvalidArgumentException('Kirjoita tarkistajan nimi.'); }
            self::begin();
            $competition = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::table('competitions') .
                ' WHERE join_hash=%s AND active=1 FOR UPDATE', self::digest($code)), ARRAY_A);
            if (!$competition) { self::rollback(); return self::error('Liittymiskoodi ei kelpaa.', 401); }
            $token = self::secret(); $expires = gmdate('Y-m-d H:i:s', time() + 7 * DAY_IN_SECONDS);
            self::check($wpdb->query($wpdb->prepare('DELETE FROM ' . self::table('sessions') .
                ' WHERE competition_id=%d AND expires_at<=%s', $competition['id'], self::now())));
            self::check($wpdb->insert(self::table('sessions'), ['competition_id'=>$competition['id'],
                'token_hash'=>self::digest($token), 'reviewer'=>$reviewer,
                'generation'=>$competition['generation'], 'expires_at'=>$expires]));
            self::commit();
            return new WP_REST_Response(['competitionId'=>(int)$competition['id'], 'name'=>$competition['name'],
                'token'=>$token, 'expiresAt'=>str_replace(' ', 'T', $expires) . 'Z'], 201);
        } catch (InvalidArgumentException $e) { self::rollback(); return self::error($e->getMessage()); }
        catch (Throwable $e) { self::rollback(); return self::error('Liittyminen epäonnistui.', 500); }
    }
    public static function download($request) {
        $identity = self::identity($request);
        if (is_wp_error($identity)) { return $identity; }
        $c = $identity['competition'];
        return ['id'=>(int)$c['id'], 'name'=>$c['name'], 'revision'=>(int)$c['revision'],
            'manifest'=>$c['manifest'] ? json_decode($c['manifest'], true) : null];
    }
    /** Uudelleentarkistus lukon jälkeen sulkee avainten vaihdon ja kirjoituksen välisen kilpailutilanteen. */
    private static function locked_identity($request, bool $owner = false) {
        global $wpdb;
        $locked = $wpdb->get_row($wpdb->prepare('SELECT id FROM ' . self::table('competitions') . ' WHERE id=%d FOR UPDATE', (int)$request['id']));
        if (!$locked || $wpdb->last_error) { throw new RuntimeException('Kilpailun lukeminen epäonnistui.'); }
        return self::identity($request, $owner);
    }
    public static function upload($request) {
        global $wpdb;
        try {
            $body = self::body($request);
            $base = AS_Tulkki_Data::integer($body['baseRevision'] ?? null, 0, PHP_INT_MAX);
            $manifest = AS_Tulkki_Data::manifest($body['manifest'] ?? null);
            self::begin(); $identity = self::locked_identity($request, true);
            if (is_wp_error($identity)) { self::rollback(); return $identity; }
            $c = $identity['competition']; $json = wp_json_encode($manifest);
            // Identtisen lähetyksen uusinta onnistuu myös kuittauksen kadottua.
            if ($json === $c['manifest']) { self::commit(); return ['revision'=>(int)$c['revision']]; }
            if ($base !== (int)$c['revision']) { self::rollback(); return self::error('Kilpailutiedot ovat muuttuneet. Nouda ne uudelleen.', 409); }
            if ($c['manifest'] && !AS_Tulkki_Data::voids_preserved(json_decode($c['manifest'], true), $manifest)) {
                self::rollback(); return self::error('Mitätöityä kilpeä ei voi palauttaa käyttöön tai poistaa historiasta.', 409);
            }
            $count = $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . self::table('events') . ' WHERE competition_id=%d', $c['id']));
            if ($wpdb->last_error) { throw new RuntimeException('Tulkintojen tarkistus epäonnistui.'); }
            $old_manifest=$c['manifest']?json_decode($c['manifest'],true):null;
            $compatible=$old_manifest && AS_Tulkki_Data::compatible_row_change($old_manifest,$manifest);
            if ((int)$count > 0 && !$compatible) {
                self::rollback();
                return self::error('Tulkkausten alettua voidaan korjata kilpiä. Aika-asemien, jaksojen tai kilpailuparien rakennetta ei voi vaihtaa.', 409);
            }
            $revision = (int)$c['revision'] + 1;
            $history=json_decode($c['manifest_history']??'{}',true)?:[];
            if($old_manifest){$history[(string)$c['revision']]=$old_manifest;}
            $history[(string)$revision]=$manifest;
            $minimum=$compatible?max(1,(int)($c['minimum_revision']??0)?: (int)$c['revision']):$revision;
            self::check($wpdb->update(self::table('competitions'), ['revision'=>$revision,'manifest'=>$json,'manifest_history'=>wp_json_encode($history),'minimum_revision'=>$minimum], ['id'=>$c['id']]));
            self::commit(); return ['revision'=>$revision];
        } catch (InvalidArgumentException $e) { self::rollback(); return self::error($e->getMessage()); }
        catch (Throwable $e) { self::rollback(); return self::error('Kilpailutietojen tallennus epäonnistui.', 500); }
    }
    public static function submit($request) {
        global $wpdb;
        try {
            $body = self::body($request);
            $request_id = AS_Tulkki_Data::id($body['requestId'] ?? null);
            $revision = AS_Tulkki_Data::integer($body['revision'] ?? null, 1, PHP_INT_MAX);
            // Tiiviste samasta JSON-pyynnöstä; uusintalähetys säilyttää alkuperäisen sisällön.
            $hash = self::digest(wp_json_encode($body));
            self::begin(); $identity = self::locked_identity($request);
            if (is_wp_error($identity)) { self::rollback(); return $identity; }
            $c = $identity['competition'];
            $old = $wpdb->get_row($wpdb->prepare('SELECT id, request_hash FROM ' . self::table('events') .
                ' WHERE competition_id=%d AND request_id=%s', $c['id'], $request_id), ARRAY_A);
            if ($wpdb->last_error) { throw new RuntimeException('Uusintalähetyksen tarkistus epäonnistui.'); }
            if ($old) {
                self::commit();
                return hash_equals($old['request_hash'], $hash) ? ['eventId'=>(int)$old['id'], 'replayed'=>true] :
                    self::error('Samaa requestId-tunnistetta käytettiin eri sisältöön.', 409);
            }
            $first_revision = $wpdb->get_var($wpdb->prepare('SELECT MIN(CAST(JSON_UNQUOTE(JSON_EXTRACT(payload, %s)) AS UNSIGNED)) FROM ' . self::table('events') . ' WHERE competition_id=%d', '$.revision', $c['id']));
            $minimum=(int)($c['minimum_revision']??0);
            if (!$c['manifest'] || $revision > (int)$c['revision'] || ($minimum>0 && $revision<$minimum) || ($minimum===0 && $revision !== (int)$c['revision'] && (!$first_revision || $revision < (int)$first_revision))) {
                self::rollback(); return self::error('Päivitä kilpailutiedot ennen lähettämistä.', 409);
            }
            $manifest = json_decode($c['manifest'], true);
            $versions=json_decode($c['manifest_history']??'{}',true)?:[];
            if($revision!==(int)$c['revision']){
                $source=$versions[$revision]??(reset($versions)?:$manifest);
                AS_Tulkki_Data::submission(AS_Tulkki_Data::without_voided($body,$source),$source);
            }
            $data = AS_Tulkki_Data::submission($revision===(int)$c['revision']?AS_Tulkki_Data::without_voided($body,$manifest):AS_Tulkki_Data::project_submission($body,$manifest), $manifest,$revision!==(int)$c['revision']);
            $data['originalSections'] = $body['sections'];
            $versions=json_decode($c['manifest_history']??'{}',true)?:[];
            $data['originalLabels']=(object)AS_Tulkki_Data::labels($versions[$revision]??(reset($versions)?:$manifest),$body['sections']);
            $data['sourceRevision']=$revision;
            $data['reviewer'] = $identity['reviewer'];
            $data['savedAt'] = gmdate('Y-m-d\TH:i:s\Z');
            $data['revision'] = (int)$c['revision'];
            self::check($wpdb->insert(self::table('events'), ['competition_id'=>$c['id'],
                'request_id'=>$request_id, 'request_hash'=>$hash, 'payload'=>wp_json_encode($data), 'created_at'=>self::now()]));
            $event = (int)$wpdb->insert_id;
            foreach ($data['sections'] as $section) {
                $payload = $section + ['reviewer'=>$data['reviewer'], 'savedAt'=>$data['savedAt'], 'revision'=>$revision];
                self::check($wpdb->query($wpdb->prepare('INSERT INTO ' . self::table('results') .
                    ' (competition_id,pair_number,section_id,event_id,payload) VALUES (%d,%d,%s,%d,%s)
                    ON DUPLICATE KEY UPDATE event_id=VALUES(event_id),payload=VALUES(payload)',
                    $c['id'], $data['pairNumber'], $section['id'], $event, wp_json_encode($payload))));
            }
            self::commit();
            return new WP_REST_Response(['eventId'=>$event,'replayed'=>false], 201);
        } catch (InvalidArgumentException $e) { self::rollback(); return self::error($e->getMessage()); }
        catch (Throwable $e) { self::rollback(); return self::error('Tulkinnan tallennus epäonnistui. Lähetyksen voi uusia samalla requestId:llä.', 500); }
    }
    public static function changes($request) {
        global $wpdb;
        $identity = self::identity($request);
        if (is_wp_error($identity)) { return $identity; }
        $after = $request->get_param('after') ?? '0';
        if (!is_scalar($after) || !preg_match('/^[0-9]{1,18}$/D', (string)$after)) { return self::error('Virheellinen after-kohdistin.'); }
        $rows = $wpdb->get_results($wpdb->prepare('SELECT id,payload FROM ' . self::table('events') .
            ' WHERE competition_id=%d AND id>%d ORDER BY id ASC LIMIT 101', (int)$request['id'], (int)$after), ARRAY_A);
        if ($wpdb->last_error) { return self::error('Tulkintojen nouto epäonnistui.', 500); }
        $more = count($rows) > 100; $rows = array_slice($rows, 0, 100); $events = []; $cursor = (int)$after;
        $c = $identity['competition']; $manifest = json_decode($c['manifest'], true);
        foreach ($rows as $row) {
            $cursor = (int)$row['id']; $original = json_decode($row['payload'], true);
            $normalized = AS_Tulkki_Data::submission(AS_Tulkki_Data::project_submission($original, $manifest), $manifest,true);
            if ($identity['owner'] && $request->get_header('x-as-other-penalty-points') !== '1'
                && array_filter($normalized['sections'], static fn($s) => isset($s['otherPenaltyPoints']))) {
                return self::error('Tulkinta sisältää suoria virhepisteitä. Päivitä AS2026 versioon 0.7.8 tai uudempaan.', 409);
            }
            $versions=json_decode($c['manifest_history']??'{}',true)?:[];
            $labels=$original['originalLabels']??AS_Tulkki_Data::labels($versions[$original['sourceRevision']??$original['revision']]??(reset($versions)?:$manifest),$original['originalSections']??$original['sections']);
            $events[] = ['eventId'=>$cursor,'revision'=>(int)$c['revision'],'reviewer'=>$original['reviewer'],'savedAt'=>$original['savedAt'],'originalSections'=>$original['originalSections']??$original['sections'],'originalLabels'=>(object)$labels] + $normalized;
        }
        return ['events'=>$events,'nextCursor'=>$cursor,'hasMore'=>$more,'revision'=>(int)$c['revision'],'manifest'=>$manifest];
    }
}
