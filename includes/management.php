<?php
defined('ABSPATH') || exit;

/** AS2026 hoitaa kilpailun luonnin ja yhteyden hallinnan. WordPress todentaa ylläpitäjän. */
final class AS_Tulkki_Management {
    private static function table(string $name): string {
        global $wpdb; return $wpdb->prefix . 'as_tulkki_' . $name;
    }
    private static function error(string $message, int $status = 400): WP_Error {
        return new WP_Error('as_tulkki_error', $message, ['status'=>$status]);
    }
    private static function check($result): void {
        if ($result === false) { throw new RuntimeException('Tietokantatoiminto epäonnistui.'); }
    }
    private static function body($request): array {
        if (strlen($request->get_body()) > 2 * 1024 * 1024) { throw new InvalidArgumentException('Pyyntö on liian suuri.'); }
        return AS_Tulkki_Data::object($request->get_json_params());
    }
    private static function credentials(array $body): array {
        $code = $body['joinCode'] ?? null; $key = $body['key'] ?? null;
        // AS2026 muodostaa ja tallentaa nämä ennen lähetystä. Palvelin säilyttää vain tiivisteet.
        if (!is_string($code) || !preg_match('/^[A-F0-9]{12}$/D', $code) ||
            !is_string($key) || !preg_match('/^[a-f0-9]{48}$/D', $key)) {
            throw new InvalidArgumentException('Virheellinen AS2026:n muodostama liittymiskoodi tai yhteysavain.');
        }
        return ['join_hash'=>hash('sha256', $code), 'key_hash'=>hash('sha256', $key)];
    }
    public static function permission($request) {
        $transport = AS_Tulkki_Yhteys::transport($request);
        if (is_wp_error($transport)) { return $transport; }
        if (!is_user_logged_in()) { return self::error('Yhdistä AS2026 WordPressin sovellussalasanalla.', 401); }
        if (!current_user_can('manage_options')) { return self::error('Yhteyden hallinta vaatii WordPressin ylläpitäjän oikeudet.', 403); }
        return true;
    }
    public static function routes(): void {
        foreach ([
            ['/management/competitions','POST','create'],
            ['/management/competitions','GET','listing'],
            ['/management/competitions/(?P<id>[1-9][0-9]*)/connection','PUT','connection'],
            ['/management/competitions/(?P<id>[1-9][0-9]*)/credentials','PUT','rotate'],
        ] as [$path,$method,$callback]) {
            register_rest_route('as-tulkki/v1', $path, ['methods'=>$method,
                'permission_callback'=>[self::class,'permission'], 'callback'=>[self::class,$callback]]);
        }
    }
    private static function public_row(array $row): array {
        return ['id'=>(int)$row['id'], 'name'=>$row['name'], 'active'=>(bool)$row['active'], 'revision'=>(int)$row['revision']];
    }
    public static function listing($request) {
        global $wpdb;
        $after = $request->get_param('after') ?? '0';
        if (!is_scalar($after) || !preg_match('/^[0-9]{1,18}$/D', (string)$after)) { return self::error('Virheellinen kohdistin.'); }
        $rows = $wpdb->get_results($wpdb->prepare('SELECT id,name,active,revision FROM ' . self::table('competitions') .
            ' WHERE id>%d ORDER BY id ASC LIMIT 101', (int)$after), ARRAY_A);
        if ($wpdb->last_error) { return self::error('Kilpailujen nouto epäonnistui.', 500); }
        $more = count($rows) > 100; $rows = array_slice($rows, 0, 100);
        return ['competitions'=>array_map([self::class,'public_row'], $rows),
            'nextCursor'=>$rows ? (int)end($rows)['id'] : (int)$after, 'hasMore'=>$more];
    }
    public static function create($request) {
        global $wpdb;
        try {
            $body = self::body($request);
            $provision = AS_Tulkki_Data::id($body['requestId'] ?? null);
            $name = trim(AS_Tulkki_Data::text($body['name'] ?? null, 160));
            if (!$name) { throw new InvalidArgumentException('Kilpailun nimi puuttuu.'); }
            $credentials = self::credentials($body);
            self::check($wpdb->query('START TRANSACTION'));
            // Unique-avain sarjoittaa myös samanaikaiset ensimmäiset lähetykset.
            self::check($wpdb->query($wpdb->prepare('INSERT INTO ' . self::table('competitions') .
                ' (provision_id,name,join_hash,key_hash,created_at) VALUES (%s,%s,%s,%s,%s)
                ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)', $provision, $name,
                $credentials['join_hash'], $credentials['key_hash'], gmdate('Y-m-d H:i:s'))));
            $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::table('competitions') . ' WHERE provision_id=%s FOR UPDATE', $provision), ARRAY_A);
            if ($wpdb->last_error) { throw new RuntimeException('Kilpailun lukeminen epäonnistui.'); }
            if (!$row || $row['name'] !== $name || !hash_equals($row['join_hash'], $credentials['join_hash']) ||
                !hash_equals($row['key_hash'], $credentials['key_hash'])) {
                $wpdb->query('ROLLBACK');
                return self::error('Luontitunniste tai liittymiskoodi on jo käytössä eri tiedoilla. Muodosta uusi koodi tarvittaessa.', 409);
            }
            self::check($wpdb->query('COMMIT'));
            return new WP_REST_Response(self::public_row($row), 200);
        } catch (InvalidArgumentException $e) { $wpdb->query('ROLLBACK'); return self::error($e->getMessage()); }
        catch (Throwable $e) { $wpdb->query('ROLLBACK'); return self::error('Kilpailun luonti epäonnistui. Uusi sama pyyntö samoilla tunnuksilla.', 500); }
    }
    private static function locked($request): ?array {
        global $wpdb;
        $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . self::table('competitions') . ' WHERE id=%d FOR UPDATE', (int)$request['id']), ARRAY_A);
        if ($wpdb->last_error) { throw new RuntimeException('Kilpailun lukeminen epäonnistui.'); }
        return $row;
    }
    /** Ei togglea: saman pyynnön uusinta ei koskaan avaa suljettua yhteyttä. */
    public static function connection($request) {
        global $wpdb;
        try {
            $body = self::body($request); $changes = [];
            if (array_key_exists('active', $body)) { $changes['active'] = (int)AS_Tulkki_Data::flag($body['active']); }
            if (array_key_exists('name', $body)) {
                $changes['name'] = trim(AS_Tulkki_Data::text($body['name'], 160));
                if (!$changes['name']) { throw new InvalidArgumentException('Kilpailun nimi puuttuu.'); }
            }
            if (!$changes) { throw new InvalidArgumentException('Yhteystila tai kilpailun nimi puuttuu.'); }
            self::check($wpdb->query('START TRANSACTION')); $row = self::locked($request);
            if (!$row) { $wpdb->query('ROLLBACK'); return self::error('Kilpailua ei löydy.', 404); }
            if (isset($changes['active']) && $changes['active'] !== (int)$row['active']) {
                $changes['generation'] = (int)$row['generation'] + 1;
                self::check($wpdb->delete(self::table('sessions'), ['competition_id'=>$row['id']]));
            }
            self::check($wpdb->update(self::table('competitions'), $changes, ['id'=>$row['id']]));
            self::check($wpdb->query('COMMIT'));
            return self::public_row(array_merge($row, $changes));
        } catch (InvalidArgumentException $e) { $wpdb->query('ROLLBACK'); return self::error($e->getMessage()); }
        catch (Throwable $e) { $wpdb->query('ROLLBACK'); return self::error('Yhteystilan tallennus epäonnistui.', 500); }
    }
    public static function rotate($request) {
        global $wpdb;
        try {
            $credentials = self::credentials(self::body($request));
            self::check($wpdb->query('START TRANSACTION')); $row = self::locked($request);
            if (!$row) { $wpdb->query('ROLLBACK'); return self::error('Kilpailua ei löydy.', 404); }
            if (!hash_equals($row['join_hash'], $credentials['join_hash']) || !hash_equals($row['key_hash'], $credentials['key_hash'])) {
                $collision = $wpdb->get_var($wpdb->prepare('SELECT id FROM ' . self::table('competitions') .
                    ' WHERE join_hash=%s AND id<>%d', $credentials['join_hash'], $row['id']));
                if ($wpdb->last_error) { throw new RuntimeException('Liittymiskoodin tarkistus epäonnistui.'); }
                if ($collision) { $wpdb->query('ROLLBACK'); return self::error('Liittymiskoodi on jo käytössä.', 409); }
                self::check($wpdb->update(self::table('competitions'), $credentials + ['generation'=>(int)$row['generation']+1], ['id'=>$row['id']]));
                self::check($wpdb->delete(self::table('sessions'), ['competition_id'=>$row['id']]));
            }
            self::check($wpdb->query('COMMIT')); return self::public_row($row);
        } catch (InvalidArgumentException $e) { $wpdb->query('ROLLBACK'); return self::error($e->getMessage()); }
        catch (Throwable $e) { $wpdb->query('ROLLBACK'); return self::error('Tunnusten vaihto epäonnistui. Uusi pyyntö samoilla tunnuksilla.', 500); }
    }
}
