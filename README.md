# King of the Pirates 🏴‍☠️🌴

Et tropisk piratspill for Roblox, inspirert av Sea of Thieves. Seil, grav opp skatter, kjemp mot
skjelettpirater og plyndre andre spillere – og bli den rikeste piraten på serveren for å bli kronet
**King of the Pirates**.

Spillfila er **`KingOfThePirates.rbxl`** (bygd fra din opprinnelige `brandnewgame.rbxl`, som ligger i `place/base.rbxl`).

## Slik prøver du spillet

1. Last ned `KingOfThePirates.rbxl` og åpne den i **Roblox Studio**.
2. Trykk **Play**. Øyene genereres når serveren starter (Kingshaven først, resten av havet etter
   noen sekunder) – det er derfor du ser en lasteskjerm.
3. For at gull/skip/kart skal **lagres**: publiser spillet og slå på
   *Game Settings → Security → Enable Studio Access to API Services*. Uten dette fungerer alt,
   men ingenting lagres.

### Se øyene mens du redigerer i Studio (valgfritt)
Terrenget lages av et script, så i redigeringsmodus ser du bare bygningene og palmene. Vil du "bake"
terrenget inn i plassen, lim dette inn i **Command Bar** i Studio, vent ~20 sekunder og lagre:

```lua
require(game.ServerScriptService.Services.TerrainGenerator).Generate(true)
```

Serveren hopper da over genereringen (den sjekker versjonsnummeret på Terrain).

## Hva som er med (kjernen av spillet)

| Del | Hva du kan gjøre |
| --- | --- |
| **Kingshaven** (hovedøya) | Trygg havn uten PvP. Skipsbygger, Merchant, Armory, Tavern, Trading Post, gullstatue av kongen, fyrtårn, brygger. |
| **Skip** | Sloop (gratis), Brigantine (3 500 g), Galleon (10 000 g). Kjøp og sjøsett hos Shipwright. |
| **Seiling** | Ror (én spiller om gangen), seil, anker, vind som påvirker farten, skip som duver på bølgene, skip som går på grunn. |
| **Kanoner** | Bemann en kanon, sikt med musa, skyt. Treff lager hull i dekket som må repareres – ellers synker skipet. |
| **Skatter** | Kjøp skattekart (4 nivåer), finn X-en på øya, grav med spaden, bær kista tilbake og selg den. Kister skyller også i land på strendene. |
| **Plyndring** | Kister på dekket ditt seiler med deg – og kan stjeles. Dreper du en som bærer en kiste, mister de den. Sunkne skip slipper lasten sin. |
| **Fiender** | Skjelettpirater på øyene (flere om natta), og vakter rundt nyutgravde skatter. |
| **Handel** | Kjøp/selg våpen, kart og skatter. Bytt gull, våpen og kart med andre spillere (kun i Kingshaven). |
| **Crew** | Inviter spillere til crewet ditt: dere kan ikke skade hverandre og gjenoppstår på crewets skip. |
| **Verden** | 15 øyer (tropiske, flate, steinete, et atoll), turkis vann, dag/natt, skyer, Future-lys, bloom, solstråler og fargekorrigering for tropisk stemning. |

## Kontroller

| Tast | Handling |
| --- | --- |
| **E** | Snakk med butikker, ta roret, bemann kanon, plukk opp kiste, reparer hull |
| **A / D** (ved roret) | Vri rattet (det blir stående som i Sea of Thieves) – **C** sentrerer |
| **W / S** (ved roret) | Senk / hev seilene |
| **Mus + klikk** (ved kanon) | Sikt og skyt |
| **Space / F** | Gå fra roret eller kanonen |
| **G** | Slipp kista du bærer |
| **M** | Sjøkart | 
| **P** | Pirater: crew og handel |
| **H** | Hjelp |

Mobil: det er knapper på skjermen for ror, kanon og å slippe kister.

## Prosjektstruktur

```
place/base.rbxl            Den opprinnelige plassen din (Baseplate-malen)
KingOfThePirates.rbxl      Det ferdige spillet (generert)
src/                       Alle scripts (Rojo-filnavn: .server.luau / .client.luau / .luau)
  ReplicatedFirst/         Lasteskjerm
  ReplicatedStorage/Shared Config (priser, skip, våpen...), WorldData (øyer), Heightmap, Noise, Util, Net
  ServerScriptService/     Main + Services (Ship, Treasure, Carry, Combat, Enemy, Shop, Trade, Crew, Data, ...)
  StarterPlayer/...        Client + Controllers (HUD, butikker, kart, ror, kanon, effekter ...)
build/                     Lune-script som bygger .rbxl-fila (skip, bygninger, palmer, lys, verktøy ...)
```

Det meste som er lurt å justere ligger i `src/ReplicatedStorage/Shared/Config.luau` (priser, skipsfart,
skade, kisteverdier) og `WorldData.luau` (øyer, plassering).

### Bygge fila på nytt
Endrer du noe i `src/` eller `build/`, bygg `.rbxl` på nytt med [Lune](https://github.com/lune-org/lune) (v0.10.5):

```sh
lune run build/build.luau
```

## Neste steg (ikke laget ennå)
- Sjømonstre (f.eks. en Kraken) – havet og skipene er klare for det: `ShipService.Damage` tar imot skade
  fra hva som helst, og `WorldData` har plass til nye områder.
- Flere skipskosmetikker (seilfarger, flagg), lyder/musikk, flere oppdrag.
