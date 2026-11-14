# AS tulkki – tiedonsiirto 0.7.2

WordPress-lisäosa AS2026:n ja AS tulkin väliseen tiedonsiirtoon. Lisäosa käyttää WordPressin nykyistä MySQL-/MariaDB-tietokantaa omilla `as_tulkki_`-tauluillaan ja WordPressin määrittämällä tauluetuliitteellä. Muun autosuunnistussovelluksen tauluja ei muuteta.

**Kilpailut hallitaan AS2026:ssa. Lisäosalla ei ole omia hallintalomakkeita tai hallintavalikkoa. Pakettiin sisältyy AS tulkin selainversio. AS2026 lähettää kilpailutiedot, ja puhelinsovellus hakee ne sekä lähettää tulkinnat sivustolle. AS2026 vastaanottaa valmiit tulkinnat ja näyttää ne kilpailuparien tuloksissa.**

## Asennus ja päivitys

1. WordPress → Lisäosat → Lisää uusi lisäosa → Lataa lisäosa. Valitse `as-tulkki-yhteys-0.7.2.zip`.
2. Jos aiempi versio on asennettu, hyväksy sen korvaaminen uudella versiolla. Älä poista kilpailuaineistoa. Aktivoi lisäosa tarvittaessa.
3. Lisäosan omiin asetuksiin ei syötetä mitään. Aiempi AS tulkki -hallintavalikko poistuu; vanhat kilpailut ja tulkinnat säilyvät. Tietokantarakenne päivittyy automaattisesti.

Tarvitaan PHP 8.1+, WordPress 6.5+, HTTPS ja InnoDB. Verkkotason multisite-aktivointia ei tueta.

AS2026:n yhteysnäkymä hoitaa sivuston osoitteen, kilpailun luonnin, kilpailutiedot ja liittymiskoodin näyttämisen. AS2026:ssa voidaan avata ja sulkea puhelinyhteys sekä vaihtaa liittymiskoodi. Hallinta vaatii ylläpitäjän sovellussalasanan; toiminnot katkaisevat puhelinistunnot ja tarkastajat liittyvät uudelleen. Kilpailun tietoja ei syötetä kahteen paikkaan.

## Uutta versiossa 0.7.2

ULA-ajan voi antaa muodossa 1845 tai 18:45. Muut virhepisteet kirjataan 100 vp:n askelin. Käytä AS2026-versiota 0.7.8 tai uudempaa suorien pisteiden vastaanottoon.

## Versiossa 0.7.1 toteutettu

ULA voidaan lisätä JAT:n jälkeen julkaistuun riviin säilyttäen vanhat aika-asemat, jaksot ja kirjaukset. Puuttuva uusi käsin syötettävä ULA-aika ilmoitetaan muutossyötteen pendingTimeIds-luettelossa. Se ei ole puuttuva korttimerkintä eikä tuota virhepisteitä. Nykyversion uusi tulkkaus vaatii edelleen kaikki käsin syötettävät ajat tai todelliset puuttumismerkinnät. Vanhan version lähetys validoidaan alkuperäisellä rivillä ja sovitetaan nykyiseen; vain lisätty ULA-aika voi jäädä täydennettäväksi.

### Versiossa 0.7.0 toteutettu

AS2026:n korjattu oikea rivi voidaan julkaista tulkattuja jaksoja säilyttäen. Vanhaan esiintymään kohdistuvat puutteet ja kellot säilyvät; poistetut kilvet poistuvat nykyisistä puutteista. Uudet kilvet ovat oletuksena löytyneitä. Puhelimen Tulkkaa uudelleen -painikkeella voi tehdä uuden tarkastuksen. Alkuperäiset kirjaukset ja niiden nimet säilyvät historiassa. Tietokantarakenne päivittyy versioon 3 ja säilyttää aiemmat tapahtumat.

### Aiemmin toteutetut toiminnot

Kilpailuparin className on valinnainen luokan näyttönimi. AS2026 julkaisee sen, ja puhelimessa on luokkavalinta. Pelkkä luokkatiedon lisääminen tai muuttaminen sallitaan olemassa oleviin tulkintoihin; kilpailunumero, rata ja laskentaa ohjaavat tiedot säilyvät. Puhelin ja AS2026 näyttävät tällä versiolla vastaanotettujen tulkkausten historian. Alareunassa näkyvät yhteyden ajankohta ja jono. AS2026:n automaattinen hyväksyntä ja tulostus valitaan AS2026:n yhteysikkunasta, lisäosassa ei tarvita uusia asetuksia.

## Käyttö puhelimella

Avaa sivuston `/as-tulkki/`-osoite, esimerkiksi `https://autosuunnistus.net/as-tulkki/`. Linkki ohjaa mukana toimitettavaan Flutter-selainversioon. Syötä AS2026:n liittymiskoodi ja tarkastajan nimi ja valitse **Liity kilpailuun**. APK:ta tai WordPress-käyttäjätunnusta ei tarvita puhelimelle.

Sovellus käyttää oikeita kilpailupareja ja kunkin parin omaa rataa. Luonnokset tallentuvat vain laitteelle. Valmis-painike tallentaa koko lähetyksen paikallisesti ennen verkkopyyntöä. Verkkokatkon jälkeen sama lähetys tunnisteineen uusitaan; kuittaus poistaa sen jonosta. Jono säilyy sivun latauksen yli. Toiseen kilpailuun vaihtaessa paikalliset tiedot arkistoidaan erilleen, eikä esimerkkikilpailua lähetetä palvelimelle. Eri tarkistajan/kilpailun vaihtaminen estetään vain, jos tämän laitteen jonossa on vielä lähettämättömiä tulkintoja. Kilpailuparien yhteiskäyttöä ei lukita.

Selainistunto ja luonnokset ovat selaimen paikallisessa muistissa. Sivustotietojen tyhjentäminen poistaa myös lähettämättömät tiedot. Vanhentuneen istunnon voi uusia liittymällä samaan kilpailuun samalla tarkastajan nimellä pilvipainikkeen kautta. Palvelimella olevat tulkinnat säilyvät selaimen tiedoista riippumatta. Selainversio noutaa palvelimelle tallennetut tulkinnat liittyessä, sovelluksen avautuessa ja kymmenen sekunnin välein. Päivityksen voi tehdä myös kilpailuparilistan päivityspainikkeella. Keskeneräisiä paikallisia kirjauksia, lähetysjonossa olevia jaksoja tai avoimen tulkkausnäkymän tietoja ei korvata taustapäivityksessä. Viimeisin palvelimelle tallennettu jakso on palvelimen voimassa oleva tieto.

AS2026:n hallintayhteys todennetaan WordPressin ylläpitäjän **sovellussalasanalla** HTTPS:n yli. Se on WordPressin oma toiminto, eikä lisäosan asetus. AS2026 voi myöhemmin käyttää WordPressin `authorize-application.php`-hyväksyntävirtaa, jolloin käyttäjä hyväksyy yhteyden selaimessa. Tässä paketissa ei vielä ole työpöytäsovelluksen hyväksyntäikkunaa. Pelkkä sivuston osoite ei anna oikeutta luoda kilpailuja. Tavallista WordPress-kirjautumissalasanaa ei käytetä rajapintasalasanana.

Jos sivustolla on REST API:n estävä suojaus- tai välimuistiasetus, salli `/wp-json/as-tulkki/v1/` ja ohita sen välimuisti. Välityspalvelimen tulee välittää `Authorization`-, `X-AS-Key`- ja `X-AS-Token`-otsakkeet. HTTPS:n tulee näkyä WordPressille asti. `WP_ENVIRONMENT_TYPE=local` sallii HTTP:n ainoastaan paikalliseen kehitykseen.

Tarkistajat liittyvät kilpailuun koodilla ja nimellä. Kilpailuparien lukitusta ei ole. Viimeisin palvelimelle onnistuneesti tallennettu jakson tulkinta jää voimaan. Vanhan lähetyksen tekninen uusinta ei korvaa uudempaa korjausta.

## Rajapinta

### Kilpailun hallinta AS2026:sta

Hallintareitit vaativat WordPressin ylläpitäjän `manage_options`-oikeuden. AS2026 käyttää WordPressin omaa HTTPS Basic Auth -tunnistusta: käyttäjätunnus ja sovellussalasana. Kilpailun avain tai puhelinistunto ei kelpaa kilpailujen hallintaan. Sovellussalasanaa ei anneta puhelinsovellukseen.

| Menetelmä ja polku | Tarkoitus |
| --- | --- |
| `POST /management/competitions` | Luo kilpailun AS2026:n tiedoilla |
| `GET /management/competitions?after=0` | Nouda kilpailut, myös ennen päivitystä luodut; enintään 100 per sivu |
| `PUT /management/competitions/{id}/connection` | Aseta yhteystila ja/tai nimi |
| `PUT /management/competitions/{id}/credentials` | Vaihda liittymiskoodi ja kilpailun yhteysavain |

Luontipyynnön esimerkki (käytä oikeasti satunnaisesti muodostettuja arvoja):

```json
{
  "requestId": "create-uniikki-uuid",
  "name": "Kilpailun nimi AS2026:sta",
  "joinCode": "A12B34C56D78",
  "key": "0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

AS2026 muodostaa liittymiskoodin kryptografisesti satunnaisista 6 tavusta (12 isoa heksamerkkiä), avaimen 24 tavusta (48 pientä heksamerkkiä) ja uniikin luontitunnisteen. Se tallentaa ne paikallisesti **ennen** verkkopyyntöä. Näin saman luontipyynnön voi uusia kuittauksen kadottua ilman ylimääräistä kilpailua tai kadonneita tunnuksia. Palvelin säilyttää koodeista vain tiivisteet. Vastaus sisältää `id`, `name`, `active`, `revision`. Saman `requestId`:n käyttö eri tiedoilla tuottaa HTTP 409:n. Koodin törmäyksessä muodosta uusi koodi ja uusi luontitunniste.

Yhteystilan sisältö on esimerkiksi `{"active":false}` tai `{"active":true,"name":"Uusi nimi"}`. Tämä on tilan asetus, ei vaihtokytkin: sulkemispyynnön uusinta ei avaa yhteyttä. Todellinen tilamuutos katkaisee puhelinistunnot. Nimenmuutos ei vaihda kilpailutiedon versiota.

Tunnusten vaihdossa lähetetään uusi `joinCode` ja `key` samoin muotovaatimuksin kuin luonnissa. Samojen tunnusten uusintalähetys ei katkaise uudelleen liittyneitä puhelimia. Vanhan version kilpailun voi ottaa uudelleen hallintaan hakemalla sen ID:n hallintaluettelosta ja vaihtamalla tunnukset tästä rajapinnasta.

Hallintaluettelon vastaus sisältää `competitions`, `nextCursor`, `hasMore`. Tunnuksia ei palauteta. Kaikki sivuston WordPress-ylläpitäjät voivat hallita lisäosan kilpailuja.

### Kilpailukohtainen tiedonsiirto

Perusosoite on sivuston osoitteesta muodostettava osoite, tavallisesti `https://OMA-SIVUSTO/wp-json/as-tulkki/v1`.

Kaikissa JSON-pyynnöissä `Content-Type: application/json`. Enintään 2 Mt per pyyntö. Älä lähetä avaimia URL:ssä. Vastaukset eivät ole välimuistikelpoisia. Tunnuksia säilytetään palvelimella SHA-256-tiivisteinä.

| Menetelmä ja polku | Tunnistus | Tarkoitus |
| --- | --- | --- |
| `POST /join` | Liittymiskoodi pyynnön sisällössä | Luo 7 vuorokauden puhelinistunnon |
| `GET /competitions/{id}` | `X-AS-Key` tai `X-AS-Token` | Kilpailun nimi, tietoversio ja kilpailutiedot |
| `PUT /competitions/{id}/manifest` | `X-AS-Key` | AS2026 julkaisee radat, jaksot ja parit |
| `POST /competitions/{id}/interpretations` | `X-AS-Token` tai `X-AS-Key` | Valmiit jaksot, myös koko kilpailu yhdellä pyynnöllä |
| `GET /competitions/{id}/interpretations?after=0` | Kumpi tahansa avain | Tulkintojen muutossyöte |

Liittymisen sisältö:

```json
{"code":"HALLINNAN-LIITTYMISKOODI","name":"Tarkistaja"}
```

Vastaus: `competitionId`, `name`, `token`, `expiresAt`. Käytä saatua `token`-arvoa `X-AS-Token`-otsakkeessa. Älä käytä liittymiskoodia jokaisessa pyynnössä. Liittymisyrityksiä rajoitetaan IP-kohtaisesti (30/minuutti, suuntaa antava sovellustason rajoitus). Sama NAT-IP voi olla usean puhelimen käytössä.

### Kilpailutietojen julkaisu

Katso `examples/manifest.json`. Ensimmäisellä lähetyksellä `baseRevision: 0`; myöhemmin viimeksi noudettu versio. Palvelin palauttaa `revision`-arvon. Identtisen sisällön uusinta ei nosta versiota. Vanhentuneen pohjaversion muutospyyntö saa HTTP 409:n.

- Rata sisältää järjestetyt jaksot, jakso järjestetyt asemat. JAT:n jaksorajat muodostetaan AS2026:ssa.
- Jokaisella aseman esiintymällä on koko kilpailussa yksikäsitteinen pysyvä `id`. Käytä AS2026:n tallennettua `tunniste`-arvoa. Esimerkiksi kaksi saman jakson kilpeä 15 ovat kaksi eri esiintymää.
- Lajit ovat `rt`, `mrt`, `leima`, `jrt`, `at`, `jat`, `ula`, `maali`. AS2026:n enumit muunnetaan näihin arvoihin. Paperirivin L tarkoittaa leimaa.
- `manualTime: true/false` vastaa **Ajan syöttö käsin** -valintaa. Kentän puuttuessa/null AT ja JAT vaativat ajan, ULA ja M vaativat ajan ilman Emitiä. Ajan syöttötapaa voi asettaa vain aikariville.
- `voided: true` merkitsee mitätöityä asemaa. Ensimmäiseen julkaisuun voidaan sisällyttää jo mitätöidyt asemat.
- Parilla on `number`, `driver`, `navigator`, `routeId` ja `emit`.
- Tunnisteissa sallitaan ASCII-kirjaimet, numerot, `_` ja `-`, enintään 80 merkkiä; kirjainkoko on merkitsevä. Käytä mielellään kirjaimella alkavia tunnisteita.

**Oikean rivin muutokset:** RT/MRT/L/JRT-kilpiä voi lisätä, poistaa ja järjestää uudelleen saman jakson sisällä. Samoina säilyvien esiintymien tunnisteet säilytetään, poistettuja tunnisteita ei käytetä uudelleen. Numeron muutos tuottaa uuden tunnisteen. ULA voidaan lisätä välittömästi JAT:n jälkeen. Vanhojen aika-asemien tunnisteet ja järjestys, jaksorajat sekä parien reittikytkennät säilyvät tulkintojen alettua. Mitätöintiä ei voi perua. Muutossyöte palauttaa nykyiseen riviin sovitetut kirjaukset sekä originalSections- ja originalLabels-kentissä alkuperäisen historian. Yhteensopivalla versiovälillä vanhan rivin lähetysjono hyväksytään; rakenteellisen muutoksen ylittävä vanha lähetys hylätään.

### Valmiin tulkinnan tallennus

Katso `examples/interpretation.json`. `revision` on noudetun kilpailutiedon versio. `sections` voi sisältää yhden tai useamman saman parin jakson. Koko kilpailu lähetetään yhdellä pyynnöllä; jos yksikin jakso on virheellinen, mitään niistä ei tallenneta.

`missingEntryIds` sisältää puuttuvien asemien esiintymätunnisteet. `times` on olio `{ "aseman-id": "12:34:03" }`. Käytä tyhjänä `{}`. Puuttuvan aseman aikaa ei lähetetä. Myös automaattisen aikarivin merkinnän voi merkitä puuttuvaksi, mutta sille ei voi syöttää aikaa käsin. Mitätöityä asemaa ei lähetetä puuttuvana eikä sille kirjata aikaa.

Jokainen lähetetty jakso on **koko jakson korvaava valmis tulkinta**, ei yksittäisten kenttien päivitys. Pois jätetyt jaksot säilyvät. `otherErrors` on tarkistajan kirjaama muiden virheiden määrä, oletus 0. `otherPenaltyPoints` on 0–6000000 vp sadan pisteen askelin. Kun suorat pisteet annetaan, `otherErrors` on 0. Vastaanottava AS2026 ilmoittaa tuen otsakkeella `X-AS-Other-Penalty-Points: 1`. `note` on huomautus. Palvelin laskee erikseen `missingSigns`- ja `missingTimes`-määrät. Puuttuvat aikamerkinnät välitetään AS2026:lle, joka soveltaa pisteytyssääntöjä; asiakkaan ei pidä lisätä niitä uudelleen `otherErrors`-kenttään.

Jokaisella Valmis-painalluksen muodostamalla lähetyksellä on uusi, satunnainen `requestId` (esimerkiksi UUID). **Tallenna lähetys paikallisesti ennen verkkopyyntöä. Yhteyskatkossa lähetä sama sisältö samalla requestId:llä**, kunnes saat kuittauksen. Sama tunniste ja sisältö palauttaa alkuperäisen `eventId`:n eikä korvaa mahdollista uudempaa korjausta. Sama tunniste eri sisällöllä saa HTTP 409:n. Näin vanha verkkoyritys ei muutu uudeksi käyttäjän korjaukseksi.

Vastaus on `{"eventId":123,"replayed":false}` (HTTP 201) tai uusinnalle `replayed:true` (HTTP 200). Tarkistajan nimi tulee istunnosta. `savedAt` tulee palvelimelta. Keskeneräisiä luonnoksia ei lähetetä tähän rajapintaan.

### Muutosten nouto ja reaaliaikaisuus

AS2026 hakee muutoksia noin 15 sekuntia edellisen haun valmistumisesta. Puhelimen selainversio päivittää tiedot ja yrittää jonossa olevia lähetyksiä 10 sekunnin välein. Lisäosa ei tarvitse erillistä WebSocket-palvelinta. Verkkoyhteys ja palvelimen kuormitus vaikuttavat viiveeseen.

Vastaus sisältää `events`, `nextCursor`, `hasMore`. Alussa `after=0`. Tapahtumissa on `eventId`, `pairNumber`, `sections`, `reviewer`, `savedAt` ja `revision`. Enintään 100 tapahtumaa per sivu. Kun `hasMore=true`, hae seuraava sivu heti. **Tallenna kohdistin vasta, kun kaikki sivun tapahtumat on käsitelty onnistuneesti.** Käsittele tapahtumat numerojärjestyksessä ja korvaa kyseisen parin kyseiset jaksot kokonaan. Samalla tapahtumalla ei saa tuplata virhemääriä.

HTTP 400 tarkoittaa virheellistä tietoa, 401 vanhentunutta/virheellistä tunnusta, 403 HTTPS-vaatimusta, 404 suljettua/tuntematonta kilpailua, 409 versiota tai lähetyksen ristiriitaa, 429 liittymisen rajoitusta ja 500 palvelinvirhettä. Virhevastaukset käyttävät WordPressin `code`, `message`, `data.status`-rakennetta. Näytä `message` tavallisena tekstinä, ei HTML:nä. Älä lokita avaimia.

## Säilytys ja ylläpito

- Neljä omaa InnoDB-taulua: kilpailut, puhelinistunnot, tapahtumahistoria ja viimeisin tulkinta parin/jakson mukaan.
- AS2026:n yhteyden sulkeminen estää kaiken kilpailukohtaisen käytön ja katkaisee vanhat puhelinistunnot. Uudelleenavauksessa puhelimet liittyvät uudelleen. AS2026-avain säilyy.
- AS2026:n tunnusten vaihtaminen vaihtaa sekä liittymiskoodin että AS2026-avaimen ja katkaisee puhelinistunnot.
- Tiedot säilyvät deaktivoinnissa ja lisäosan poistossa, jotta kilpailuaineisto ei katoa vahingossa. Varmuuskopioi WordPress-tietokanta. Automaattista poisto-/säilytysaikaa ei ole.
- Tapahtumahistoria sisältää nimet, huomautukset, ajat ja aiemmat korjaukset. Sivuston ylläpitäjä vastaa aineiston säilytyksestä.
- Lisäosa ei laske tulospisteitä, muuta AS2026:n tuloksia eikä tulosta tuloslappuja. Näiden kytkentä tehdään AS2026:een erikseen.

## Testaus

Tietomallin testit: `php tests/validation.php`.

WordPress- ja InnoDB-integraatiotestit: `php tests/integration.php POLKU/wordpress`. Aja vain erillisessä, valmiiksi asennetussa paikallisessa testikannassa, jossa `WP_ENVIRONMENT_TYPE=local`, ylläpitäjän käyttäjä-ID on 1 ja PHP:n mysqli on käytössä. Testi luo lisäosan taulut sekä väliaikaisen kilpailun ja poistaa oman kilpailuaineistonsa lopuksi. Testi ei sovi tuotantosivustolle.

## Liittyminen QR-koodilla (0.4.0)
AS2026:n Kilvet → AS tulkki -ikkunassa näkyy julkaisemisen jälkeen Näytä liittymisen QR-koodi. Puhelimen kamera avaa selainversion ja esitäyttää sivuston sekä liittymiskoodin. Tarkastaja antaa nimensä ja painaa Liity kilpailuun. Päivitys korvaa vanhan lisäosan; kilpailutiedot säilyvät.








## Ajan syöttö
ULA-kenttään voi kirjoittaa 1845 tai 18:45. Muissa aikakentissä muodot ovat 180334 ja 18:03:34. Rajapinta käyttää muotoa hh:mm:ss. Kentästä poistuttaessa kelvollinen kuuden numeron aika muotoillaan kaksoispisteillä. Myös Valmis-painike toimii suoraan aktiivisesta viimeisestä aikakentästä. Keskeneräistä tai virheellistä aikaa ei hyväksytä.


## GitHub-repositorion sisältö

Tässä repositoriossa ovat WordPress-lisäosan PHP-lähdekoodi, testit, esimerkit ja valmis selainversio app/-hakemistossa. Flutter/Dart-lähdekoodiprojekti on as_tulkki/-hakemistossa. Se vastaa aiempaa 0.7.1-kehitysversiota; app/-hakemiston 0.7.2-muutokset on vielä sovitettava Dart-lähteeseen ennen selainversion uudelleenkääntämistä. Selainversion mukana toimitetut kolmannen osapuolen lisenssit säilytetään app/assets/NOTICES- ja app/licenses/-tiedostoissa.

Asennettaessa sijoita koko repositorion sisältö WordPressin wp-content/plugins/as-tulkki-yhteys/-hakemistoon ja aktivoi lisäosa. GitHubin Download ZIP -paketin voi myös purkaa ja nimetä ylähakemiston as-tulkki-yhteys-nimiseksi ennen siirtämistä.

## Flutter-lähdekoodin käyttö

Katso as_tulkki/README.md. Asenna Flutter SDK ja suorita as_tulkki-hakemistossa flutter pub get, flutter analyze ja flutter test. Paikalliset SDK-polut, välimuistit ja build/-hakemisto eivät kuulu versionhallintaan. WordPress-asennukseen tarvitaan vain lisäosa ja app/-hakemisto; Flutter-lähdekansiota ei tarvitse siirtää palvelimelle.
