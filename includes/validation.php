<?php
/** Rajapinnan tietomalli. Ei WordPress-riippuvuuksia: testattavissa PHP CLI:llä. */
final class AS_Tulkki_Data {
    public static function compatible_row_change(array $old,array $new): bool {
        foreach ($old['pairs'] as $i=>&$pair) { if(isset($new['pairs'][$i]['className'])){$pair['className']=$new['pairs'][$i]['className'];} } unset($pair);
        foreach($old['routes'] as $ri=>&$route){foreach($route['sections'] as $si=>&$section){
            $next=$new['routes'][$ri]['sections'][$si]['entries']??null;if(!is_array($next)){return false;}
            $clocks=static fn($ee)=>array_values(array_filter($ee,static fn($e)=>self::clock($e['kind'])));
            $old_clocks=$clocks($section['entries']);$ids=array_column($old_clocks,'id');
            $retained=array_values(array_filter($clocks($next),static fn($e)=>$e['kind']!=='ula'||in_array($e['id'],$ids,true)));
            if($old_clocks!==$retained){return false;}
            foreach($next as $i=>$e){if($e['kind']==='ula' && !in_array($e['id'],$ids,true) && ($i===0 || $next[$i-1]['kind']!=='jat' || ($next[$i+1]['kind']??null)==='ula')){return false;}}
            foreach($section['entries'] as $entry){
                $same=null;foreach($next as $e){if($e['id']===$entry['id']){$same=$e;break;}}
                if($entry['voided'] && (!$same || !$same['voided'])){return false;}
                if($same && ($same['kind']!==$entry['kind'] || $same['label']!==$entry['label'])){return false;}
            }
            $section['entries']=$next;
        }unset($section);}unset($route);
        return $old===$new;
    }
    public static function project_submission(array $input,array $manifest): array {
        $sections=[];foreach($manifest['routes'] as $r){foreach($r['sections'] as $s){$sections[$r['id']][$s['id']]=$s;}}
        $number=self::integer($input['pairNumber']??null,1,999999);
        $route=null;foreach($manifest['pairs'] as $p){if($p['number']===$number){$route=$p['routeId'];break;}}
        foreach(self::items($input['sections']??null,200) as $i=>$s){
            $s=self::object($s);$sid=self::id($s['id']??null);
            $missing=array_map([self::class,'id'],self::items($s['missingEntryIds']??[],1000));
            $current=$sections[$route][$sid]??null;if(!$current){continue;}
            $active=[];foreach($current['entries'] as $e){if(!$e['voided']){$active[$e['id']]=true;}}
            $input['sections'][$i]['missingEntryIds']=array_values(array_filter($missing,static fn($id)=>isset($active[$id])));
        }
        return self::without_voided($input,$manifest);
    }
    public static function labels(array $manifest,?array $sections=null): array {
        $wanted=[];foreach($sections??[] as $s){foreach(array_merge($s['missingEntryIds']??[],array_keys((array)($s['times']??[]))) as $id){$wanted[$id]=true;}}
        $labels=[];foreach($manifest['routes'] as $r){foreach($r['sections'] as $s){foreach($s['entries'] as $i=>$e){if($sections===null || isset($wanted[$e['id']])){$labels[$e['id']]=$e['label'].' (rivi '.($i+1).')';}}}}return $labels;
    }
    public static function voids_preserved(array $old, array $new): bool {
        $remaining=[];
        foreach ($new['routes'] as $r) { foreach ($r['sections'] as $s) { foreach ($s['entries'] as $e) { if ($e['voided']) { $remaining[$e['id']]=true; } } } }
        foreach ($old['routes'] as $r) { foreach ($r['sections'] as $s) { foreach ($s['entries'] as $e) { if ($e['voided'] && !isset($remaining[$e['id']])) { return false; } } } }
        return true;
    }
    public static function void_only(array $old, array $new): bool {
        foreach ($old['pairs'] as $i => &$pair) {
            if (array_key_exists('className', $new['pairs'][$i] ?? [])) {
                $pair['className'] = $new['pairs'][$i]['className'];
            }
        }
        unset($pair);
        foreach ($old['routes'] as $ri => &$route) {
            foreach ($route['sections'] as $si => &$section) {
                foreach ($section['entries'] as $ei => &$entry) {
                    $next = $new['routes'][$ri]['sections'][$si]['entries'][$ei] ?? null;
                    if (!$next) { return false; }
                    if ($entry['voided'] !== $next['voided']) {
                        if ($entry['voided'] || !$next['voided'] || !in_array($entry['kind'], ['rt','mrt','leima','jrt'], true)) { return false; }
                        $entry['voided'] = true;
                    }
                }
                unset($entry);
            }
            unset($section);
        }
        unset($route);
        return $old === $new;
    }
    public static function without_voided(array $input, array $manifest): array {
        if (!isset($input['sections']) || !is_array($input['sections'])) { return $input; }
        $voids = [];
        foreach ($manifest['routes'] as $route) {
            foreach ($route['sections'] as $section) {
                foreach ($section['entries'] as $entry) { if ($entry['voided']) { $voids[$entry['id']] = true; } }
            }
        }
        foreach ($input['sections'] as &$section) {
            if (!is_array($section)) { continue; }
            if (isset($section['missingEntryIds']) && is_array($section['missingEntryIds'])) {
                $section['missingEntryIds'] = array_values(array_filter($section['missingEntryIds'], static fn($id) => !is_string($id) || !isset($voids[$id])));
            }
            if (isset($section['times']) && (is_array($section['times']) || $section['times'] instanceof stdClass)) {
                $section['times'] = array_diff_key((array)$section['times'], $voids);
            }
        }
        unset($section);
        return $input;
    }
    public static function object($value): array {
        if (!is_array($value) || array_is_list($value)) {
            throw new InvalidArgumentException('Odotettiin JSON-oliota.');
        }
        return $value;
    }
    public static function text($value, int $max = 120): string {
        if (!is_string($value) || strlen($value) > $max || preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', $value)) {
            throw new InvalidArgumentException('Virheellinen teksti.');
        }
        return $value;
    }
    public static function id($value): string {
        $value = self::text($value, 80);
        if (!preg_match('/^[A-Za-z0-9_-]{1,80}$/D', $value)) {
            throw new InvalidArgumentException('Virheellinen pysyvä tunniste.');
        }
        return $value;
    }
    public static function integer($value, int $min, int $max): int {
        if (!is_int($value) || $value < $min || $value > $max) {
            throw new InvalidArgumentException('Virheellinen kokonaisluku.');
        }
        return $value;
    }
    public static function flag($value): bool {
        if (!is_bool($value)) {
            throw new InvalidArgumentException('Odotettiin totuusarvoa.');
        }
        return $value;
    }
    public static function items($value, int $max): array {
        if (!is_array($value) || !array_is_list($value) || count($value) > $max) {
            throw new InvalidArgumentException('Virheellinen luettelo tai liikaa rivejä.');
        }
        return $value;
    }
    public static function manifest($input): array {
        $input = self::object($input);
        $routes = []; $route_ids = []; $entry_ids = [];
        foreach (self::items($input['routes'] ?? null, 200) as $route) {
            $route = self::object($route);
            $rid = self::id($route['id'] ?? null);
            if (isset($route_ids[$rid])) { throw new InvalidArgumentException('Rata toistuu.'); }
            $route_ids[$rid] = true;
            $sections = []; $section_ids = [];
            foreach (self::items($route['sections'] ?? null, 200) as $section) {
                $section = self::object($section);
                $sid = self::id($section['id'] ?? null);
                if (isset($section_ids[$sid])) { throw new InvalidArgumentException('Jakso toistuu.'); }
                $section_ids[$sid] = true;
                $entries = [];
                foreach (self::items($section['entries'] ?? null, 1000) as $entry) {
                    $entry = self::object($entry);
                    $id = self::id($entry['id'] ?? null);
                    if (isset($entry_ids[$id])) { throw new InvalidArgumentException('Aseman tunniste toistuu.'); }
                    $entry_ids[$id] = true;
                    $kind = $entry['kind'] ?? null;
                    if (!in_array($kind, ['rt','mrt','leima','jrt','at','jat','ula','maali'], true)) {
                        throw new InvalidArgumentException('Tuntematon asemalaji.');
                    }
                    $manual = $entry['manualTime'] ?? null;
                    if ($manual !== null) { self::flag($manual); }
                    if ($manual !== null && !self::clock($kind)) {
                        throw new InvalidArgumentException('Ajan syöttötapa kuuluu vain aikariville.');
                    }
                    $entries[] = ['id'=>$id, 'label'=>self::text($entry['label'] ?? null, 40),
                        'kind'=>$kind, 'manualTime'=>$manual,
                        'voided'=>self::flag($entry['voided'] ?? false)];
                }
                if (!$entries) { throw new InvalidArgumentException('Jaksolla ei ole asemia.'); }
                $sections[] = ['id'=>$sid, 'name'=>self::text($section['name'] ?? null), 'entries'=>$entries];
            }
            if (!$sections) { throw new InvalidArgumentException('Radalla ei ole jaksoja.'); }
            $routes[] = ['id'=>$rid, 'name'=>self::text($route['name'] ?? null), 'sections'=>$sections];
        }
        $pairs = []; $numbers = [];
        foreach (self::items($input['pairs'] ?? null, 5000) as $pair) {
            $pair = self::object($pair);
            $number = self::integer($pair['number'] ?? null, 1, 999999);
            $route = self::id($pair['routeId'] ?? null);
            if (isset($numbers[$number]) || !isset($route_ids[$route])) {
                throw new InvalidArgumentException('Kilpailunumero toistuu tai parin rata puuttuu.');
            }
            $numbers[$number] = true;
            $pairs[] = ['number'=>$number, 'driver'=>self::text($pair['driver'] ?? null),
                'navigator'=>self::text($pair['navigator'] ?? null), 'routeId'=>$route,
                'emit'=>self::flag($pair['emit'] ?? null)];
            if (isset($pair['className'])) {
                $pairs[array_key_last($pairs)]['className'] = self::text($pair['className']);
            }
        }
        if (!$routes || !$pairs) { throw new InvalidArgumentException('Radat tai kilpailuparit puuttuvat.'); }
        return ['routes'=>$routes, 'pairs'=>$pairs];
    }
    public static function clock(string $kind): bool {
        return in_array($kind, ['at','jat','ula','maali'], true);
    }
    /** Kaikki jaksot validoidaan ennen tietokantakirjoituksia. */
    public static function submission($input, array $manifest,bool $allow_pending=false): array {
        $input = self::object($input);
        $number = self::integer($input['pairNumber'] ?? null, 1, 999999);
        $pair = null; $route = null;
        foreach ($manifest['pairs'] as $p) { if ($p['number'] === $number) { $pair = $p; break; } }
        if (!$pair) { throw new InvalidArgumentException('Kilpailuparia ei löydy.'); }
        foreach ($manifest['routes'] as $r) { if ($r['id'] === $pair['routeId']) { $route = $r; break; } }
        $sections = []; $seen = [];
        foreach (self::items($input['sections'] ?? null, 200) as $raw) {
            $raw = self::object($raw);
            $sid = self::id($raw['id'] ?? null); $section = null;
            foreach ($route['sections'] as $s) { if ($s['id'] === $sid) { $section = $s; break; } }
            if (!$section || isset($seen[$sid])) { throw new InvalidArgumentException('Tuntematon tai toistuva jakso.'); }
            $seen[$sid] = true;
            $missing = self::items($raw['missingEntryIds'] ?? null, 1000);
            $missing_set = [];
            foreach ($missing as $id) {
                self::id($id);
                if (isset($missing_set[$id])) { throw new InvalidArgumentException('Puuttuva asema toistuu.'); }
                $missing_set[$id] = true;
            }
            $times = $raw['times'] ?? null;
            // Tyhjä JSON-olio dekoodautuu PHP:ssä tyhjäksi taulukoksi.
            if (!is_array($times) || ($times && array_is_list($times))) {
                throw new InvalidArgumentException('Ajat annetaan asematunnisteen mukaan.');
            }
            $known = []; $signs = 0; $clocks = 0;$pending=[];
            foreach ($section['entries'] as $entry) {
                $id = $entry['id']; $known[$id] = true;
                $absent = isset($missing_set[$id]);
                $time = $times[$id] ?? null;
                if ($entry['voided'] && ($absent || $time !== null)) {
                    throw new InvalidArgumentException('Mitätöityä asemaa ei kirjata. Päivitä kilpailutiedot.');
                }
                if ($entry['voided']) { continue; }
                $clock = self::clock($entry['kind']);
                if ($time !== null && (!$clock || $absent || !is_string($time) ||
                    !preg_match('/^(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$/D', $time))) {
                    throw new InvalidArgumentException('Virheellinen aika tai aika puuttuvalle asemalle.');
                }
                $manual = $clock && ($entry['manualTime'] ??
                    (in_array($entry['kind'], ['at','jat'], true) || !$pair['emit']));
                if ($time !== null && !$manual) { throw new InvalidArgumentException('Asemalla ei käytetä ajan syöttöä käsin.'); }
                if ($manual && !$absent && $time === null) {
                    if($allow_pending && $entry['kind']==='ula'){$pending[]=$id;}
                    else{throw new InvalidArgumentException('Täydennä ajat tai merkitse ne puuttuviksi.');}
                }
                if ($absent) { if ($clock) { $clocks++; } else { $signs++; } }
            }
            foreach (array_merge(array_keys($missing_set), array_keys($times)) as $id) {
                if (!isset($known[$id])) { throw new InvalidArgumentException('Tuntematon aseman tunniste.'); }
            }
            foreach ($times as $time) { if ($time === null) { throw new InvalidArgumentException('Aika ei saa olla null.'); } }
            $sections[] = ['id'=>$sid, 'missingEntryIds'=>$missing, 'times'=>(object)$times,
                'note'=>self::text($raw['note'] ?? '', 4000),
                'otherErrors'=>self::integer($raw['otherErrors'] ?? 0, 0, 10000),
                'missingSigns'=>$signs, 'missingTimes'=>$clocks, 'interpreted'=>true,'pendingTimeIds'=>$pending];
        }
        if (!$sections) { throw new InvalidArgumentException('Valitse vähintään yksi jakso.'); }
        return ['pairNumber'=>$number, 'sections'=>$sections];
    }
}
