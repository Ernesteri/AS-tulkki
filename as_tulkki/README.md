> Lähteen tilanne: tämä Flutter-projekti vastaa paikallista 0.7.1-kehitysversiota. Repositorion app/-hakemistossa on erikseen päivitetty 0.7.2-selainversio (ULA minuuteissa ja suorat muut virhepisteet). Näitä 0.7.2-muutoksia ei ole tässä Dart-lähteessä. Älä korvaa nykyistä app/-hakemistoa tämän lähteen käännöksellä ennen muutosten sovittamista.

# AS tulkki 0.7 – selainversio ja Android-lähde

Flutter/Dart-sovellus autosuunnistuksen paperikorttien tulkkaukseen. Selainversio liittyy WordPressin AS tulkki -lisäosaan 0.7.1 tai uudempaan liittymiskoodilla ja tarkastajan nimellä. Android-lähde käyttää samaa rajapintaa; tässä työvaiheessa toimitetaan selainversio ilman APK:ta.

## Käyttö

Puhelimella avataan https://autosuunnistus.net/as-tulkki/ lisäosan päivittämisen jälkeen. Syötä sivuston osoite, AS2026:n näyttämä liittymiskoodi ja tarkastajan nimi. Sovellus lataa kilpailuparit ja niiden omat radat, jaksot, kilvet sekä ajan syöttötavat.

Parille voi tulkata yhden jakson tai Koko kilpailu -näkymän kaikki jaksot. Merkitse puuttuvat asemien esiintymät ja syötä vaaditut ajat. Samalla jaksolla toistuvat numerot ovat erillisiä esiintymiä. Aikakentän nimi on Aika myös maalissa. Koko kilpailun vahvistus tarkistaa kaikki jaksot ennen ensimmäistäkään valmista merkintää.

Luonnokset tallentuvat selaimeen automaattisesti. Vasta Valmis muodostaa palvelimelle lähetettävän tilannekuvan. Lähetys saa satunnaisen requestId:n, ja se tallennetaan paikalliseen jonoon ennen verkkopyyntöä. Yhteyskatkossa sama pyyntö uusitaan samalla sisällöllä. Kuittaus poistaa lähetyksen jonosta; puuttuva kuittaus ei merkitse lähetystä onnistuneeksi. Paikallisen tallennuksen virhe estää verkkolähetyksen. Uusintaa kokeillaan 10 sekunnin välein ja Yritä uudelleen -painikkeella.

Kilpailun vaihtaminen säilyttää aiemmat paikalliset luonnokset erillisessä arkistossa. Esimerkkikilpailu on paikallinen eikä sen tietoja lähetetä verkkoon. Aiempi schema 1 -demotallennus avautuu edelleen; uusi tallennus käyttää schema 2:ta.

Lähettämättömien tulkintojen aikana ei vaihdeta eri kilpailuun tai tarkastajaan. Istunnon vanhennuttua pilvipainikkeesta voi liittyä uudelleen samaan kilpailuun samalla nimellä. Palvelimen istunto on voimassa 7 vuorokautta. Selaimen sivustotietojen tyhjentäminen poistaa paikalliset luonnokset, arkistot ja lähetysjonon. Sovellus noutaa palvelimen tulkinnat liittyessä ja 10 sekunnin välein. Avoimia tai paikallisesti muokattuja jaksoja ja lähetysjonossa olevia tietoja ei korvata. Viimeisin palvelimelle tallennettu jakso jää palvelimella voimaan.

AS2026 julkaisee kilpailutiedot. AS2026 vastaanottaa tulkinnat, siirtää kirjaukset laskentaan ja näyttää ne tuloksissa. Lopputulosten hyväksyntä ja tulostus ovat kilpailukohtaisesti käsin tehtäviä tai automaattisia. Pisteitä ei lasketa puhelimessa.

Parilistassa voi rajata kilpailijat luokan mukaan. Luokka julkaistaan AS2026:sta. Parin Muutoshistoria näyttää tällä versiolla vastaanotetut tallennukset tarkastajineen; myös korvaantuneet kirjaukset säilyvät. Huomautuskenttiä ei ole. Alareunassa näkyvät viimeisin onnistunut yhteys ja lähetysjonon määrä.

Ajantasaiset käyttöohjeet: ../outputs/AS2026-luokat-ja-automaattitulokset.md. Myöhemmäksi siirretyt kokeet: ../outputs/AS2026-jatkokehitys.md.

Oikean rivin kilpikorjaukset säilyttävät tulkatut jaksot ja kellot. Poistetut kilvet poistuvat nykyisistä puutteista, uudet eivät ole automaattisesti puuttuvia. Tulkkaa uudelleen avaa aiemmat kirjaukset korjattaviksi. Korvaamisen käyttöohje: ../outputs/AS2026-oikean-rivin-korjaaminen.md.

ULA voidaan lisätä julkaistuun riviin JAT:n jälkeen (0.7.1). Uusi vaadittu aika näkyy täydennettävänä ilman puuttumismerkintää. Vanha lähetysjono säilyttää tarvittaessa alkuperäisen pohjaversion. Ohje: ../outputs/AS2026-ULA-lisaaminen.md.

## Paikallinen selainkokeilu

Valmis web-paketti on build/web. Käynnistä node tool/serve_web.mjs ja avaa http://127.0.0.1:18765/. Palvelin kuuntelee vain tätä konetta. WordPress-pakettiin kopioidaan sama sovellus sekä tarvittavat paikalliset CanvasKit-tiedostot. Suhteellinen base-href mahdollistaa lisäosan alikansion.

Tässä kehitysympäristössä selain-JavaScript on käännetty Flutterin dart2js-työkalulla ja yhdistetty aiemmin valmisteltuihin web-resursseihin. Tavallinen käännöskomento on flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --no-tree-shake-icons. Lähteen web/flutter_bootstrap.js ei ota service workeria käyttöön.

## Tarkistukset

- dart analyze lib: ei huomautuksia.
- dart run tool/check_domain.dart: 15 sääntötarkistusta.
- dart run tool/check_remote.dart: 21 API- ja verkkotietomallin tarkistusta.
- Headless Chrome: liittyminen oikeanmuotoiseen testikilpailuun, esimerkkien säilyminen erillään, ratakohtaiset jaksot, toistuvat kilvet, aikavalinnat, koko kilpailun lähetys, verkkokatko, sivun päivitys, identtinen uusintalähetys sekä paikallisen tallennuksen virhe ja palautuminen.
- Sama selainkoe toistettu lisäosan alikansiosta pakatuilla resursseilla. Esimerkkikilpailun koko kilpailun työnkulku tarkistettu erikseen 390 × 844 -näkymässä.

Selainkokeet käyttävät erillisiä selainprofiileja ja synteettistä rajapintaa. Ne eivät lähetä tietoja käyttäjän oikeaan verkkokilpailuun. Käyttäjän liittymiskoodi syötetään sovellukseen paikallisesti.