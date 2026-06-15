# Verkkis V2

Verkkis on pieni komentorivillä asuva ohjelma, joka hakee Verkkokauppa.comin Outlet-tuotteet. Ohjelmalla voit tehdä hakuja, tallentaa hakuja, merkata tuotteita suosikeiksi, tarkastella tuotteen hintahistoriaa yms.

Hakutoiminto käyttää ns. fuzzy searchia. Haussa-listaus hakee tarkalla tallennetulla hakusanalla - muuten hakutuloslistasta tulisi valtavan pitkä epärelevantteine tuotteineen. Jos haluat seurata tiettyä tuotetta Outletissa, tallenna hakusanaksi tarkka tuotteen nimi.

Huom! Tein tämän projektin opetellakseni Ruby-ohjelmointia, ja siltä se kieltämättä näyttääkin. Käyttö täysin omalla vastuulla. Tuskin se sentään sytyttää tietokonettasi tuleen, vaikka en lupaakaan mitään. Lisäksi tätä on paranneltu käyttämällä tekoälyä - kääk!

## Asennus

Bundlerilla (suositeltu):

```shell
bundle install
```

Tai suoraan:

```shell
gem install curses launchy
```

## Käyttäminen

```shell
bundle exec ruby verkkis.rb
# tai ilman bundleria
ruby verkkis.rb
````

## Lisää alias .bashrc, .zshrc tms.

```shell
alias verkkis="ruby [POLKU]/verkkis.rb"
```
