=== AS tulkki – tiedonsiirto ===
Requires at least: 6.5
Requires PHP: 8.1
Stable tag: 0.7.3
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

AS2026:n ja AS tulkin välinen kilpailukohtainen tiedonsiirtorajapinta.

== Description ==
Kilpailut ja liittymiskoodit hallitaan AS2026:ssa. Lisäosassa ei ole
syöttölomakkeita tai omaa hallintavalikkoa. AS2026:n hallintayhteys käyttää
WordPressin ylläpitäjän sovellussalasanaa HTTPS-yhteydellä.

Lisäosa tarjoaa kilpailutietojen julkaisun, valmiiden tulkintojen vastaanoton
ja kohdistimella luettavan muutossyötteen. Kilpailuparien lukitusta ei ole.
Käyttää WordPressin tietokantaa omilla InnoDB-tauluilla.

Selainversio sisältyy pakettiin ja avautuu osoitteesta /as-tulkki/.
AS2026 lähettää kilpailutiedot. Puhelin liittyy koodilla, lataa tiedot ja
lähettää valmiit tulkinnat sivustolle. AS2026 vastaanottaa tulkinnat ja liittää ne laskentaan. Lue README.md ennen koekäyttöä.

== Installation ==
Lataa ZIP WordPressin Lisäosat-valikossa ja aktivoi. Versiosta 0.1.0
päivittäessä korvaa aiempi lisäosa uudella. Kilpailutiedot säilyvät.
Lisäosan asetuksiin ei syötetä mitään.

== Changelog ==
= 0.7.3 =
Tyhjä valinnainen virhepistekenttä jätetään pois tulkintojen lähetyksestä
ja vanhoista muutossyötteen tapahtumista.

= 0.7.2 =
ULA:n tunti- ja minuuttisyöttö sekä muiden virhepisteiden 100 vp:n askel.
Suorat pisteet vastaanotetaan AS2026 0.7.8:lla tai uudemmalla.

= 0.7.1 =
ULA voidaan lisätä JAT:n jälkeen julkaistuun riviin. Vanhat ajat säilyvät,
uusi vaadittu ULA-aika täydennetään ilman automaattista puuttumismerkintää.

= 0.7.0 =
Oikean rivin kilpikorjaus säilyttäen tulkatut jaksot, kellot ja historia.
Uudelleentulkkaus painikkeesta. Muuttuneiden rivien synkronointi.

= 0.6.1 =
Kilpailuparit näytetään aina kilpailunumerojärjestyksessä luokkavalinnasta riippumatta.

= 0.6.0 =
Kilpailuparien luokkavalinta, vastaanotettujen tulkkausten muutoshistoria
ja yhteystila. Luokkatieto voidaan lisätä jo julkaistuun kilpailuun.

= 0.5.2 =
Huomautuskentät poistettu jakson ja koko kilpailun tulkkausnäkymistä.
Aiemmin tallennetut huomautukset säilyvät.

= 0.5.1 =
Puhelimen aikakenttiin voi syöttää ajan kuudella numerolla (180334).
Aika muotoillaan kentästä poistuttaessa muotoon 18:03:34 ja lähetetään
palvelimelle aina muodossa hh:mm:ss.

= 0.5.0 =
Yksittäisen RT-kilven pysyvä mitätöinti kilpailun aikana. Puhelin päivittää
oikean rivin ja säilyttää muut kirjaukset. Vanhan rivin tulkinnan voi lähettää
mitätöinnin jälkeen. Puhelimen taustapäivitys 10 sekuntia.

= 0.4.1 =
Puhelin hakee palvelimelta aiemmat tulkinnat ja päivittää tulkkaustilat
automaattisesti. Paikalliset luonnokset ja lähetysjono säilyvät.

= 0.4.0 =
Liittyminen AS2026:ssa näytettävällä QR-koodilla. Sivusto ja kilpailukoodi
esitäytetään; tarkastaja antaa nimensä ja vahvistaa liittymisen.

= 0.3.0 =
Puhelimella käytettävä AS tulkin selainversio. Liittyminen koodilla,
oikeat kilpailuparit ja radat sekä katkon yli säilyvä tulkintojen lähetysjono.

= 0.2.0 =
Kilpailun luonti, nimen ja yhteystilan muuttaminen sekä tunnusten vaihto
rajapinnan kautta AS2026:sta. Poistettu lisäosan hallintalomakkeet.

= 0.1.0 =
Ensimmäinen palvelinrajapinta. Kilpailutietojen muuttaminen ensimmäisen
tulkinnan jälkeen on estetty myös versiossa 0.2.0.









