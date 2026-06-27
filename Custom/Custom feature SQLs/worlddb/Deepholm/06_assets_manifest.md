# Deepholm Downport — Assets manifest (models + DBC rows to author)

Everything here is **client/DBC asset work**, not SQL — the spawn/template SQL keeps the retail
display/faction/vehicle/lock ids, so once these assets exist the creatures/GOs render and behave
correctly with no further DB change. "Missing" was computed precisely by diffing the Cata display
ids against the live `acore_dbc` mirror (`creaturedisplayinfo` 24,690 rows / `gameobjectdisplayinfo`
3,811 / `factiontemplate` 841 / `lock` 388 / `vehicle` 412) — not a threshold guess.

| Asset | Missing | Pipeline |
|---|---|---|
| Creature display models | **183** | retroport: db2-decode → wow.export → Wraith → CreatureModelData+CreatureDisplayInfo CSV → DBC → client patch |
| GameObject display models | **44** | `wxl-baker --deps` + GameObjectDisplayInfo CSV row |
| FactionTemplate.dbc rows | **24** | downport from Cata `factiontemplate.dbc` OR remap to a near-stock faction |
| Vehicle.dbc / VehicleSeat.dbc | **10** | downport referenced Vehicle + its seats |
| Lock.dbc | **7** | hand-add from Cata `lock.dbc` |
| SpellFocusObject.dbc | **3** | 1678/1680/1681 (1/3/4 are stock) |

## How to resolve a display id → model file (the bit the DB can't give you)

The model **file path** for a missing display lives only in the Cata/retail client DBCs (not in
`cata_world` or `acore_dbc`). For each display id below:

```
db2-decode CreatureDisplayInfo  ->  row.ModelID
db2-decode CreatureModelData    ->  row[ModelID].FileName / FileDataID   (the .m2 path)
wow.export  -> extract that .m2 + .skin + .blp
Wraith / M2I -> downport to 3.3.5 M2 (see Custom/Documentation/Custom model retroport pipeline)
CSV DBC -> CreatureModelData.csv (new ModelData id) + CreatureDisplayInfo.csv (KEEP the retail
           display id below) -> build DBC -> pack model into client patch under Creature\<folder>\
```
Keep the **retail display id** (the spawn/template SQL already references it) — only the internal
ModelData id is freshly allocated (DC 500xxx sequence). GO models follow the same idea with
`GameObjectDisplayInfo` (keep retail displayId).

> Priority: `used_by` = how many distinct creatures share the model. Do the high-`used_by` shared
> models and the named bosses (Therazane 32913, Xariona 32229, Abyssion 32230, Troggzor 33380,
> Aeosera 33443, Golgarok 37364, Feldspar 34275, Ma'haat 33483) first — they cover the most
> visible content. Single-use trash models can lag behind on placeholder displays.

## Creature display models to downport (183) — `display id | example creature | #creatures`

| display | example creature | # | | display | example creature | # |
|--:|---|--:|---|--:|---|--:|
| 33020 | Stormcaller Mylra | 5 | | 34012 | Twilight Binder | 2 |
| 33041 | Exhausted Earthguard Sentinel | 5 | | 34137 | Twilight Armsman | 2 |
| 33042 | Exhausted Earthguard Sentinel | 5 | | 34153 | Twilight Cryptomancer | 2 |
| 32932 | Stone Trogg Beast Tamer | 4 | | 34163 | Amthea | 2 |
| 32933 | Stone Trogg Ambusher | 4 | | 34254 | Opal Stonethrower | 2 |
| 33036 | Earthmender Norsala | 4 | | 36644 | Crystal Beetle | 2 |
| 33037 | Windspeaker Lorvarius | 4 | | 29322 | Captain Skullshatter | 1 |
| 33043 | Exhausted Earthguard Sentinel | 4 | | 31513 | Twilight Scalesister | 1 |
| 33046 | Stormcaller Jalara | 4 | | 32117 | Agate Mancrusher | 1 |
| 33048 | Tawn Winterbluff | 4 | | 32229 | Xariona | 1 |
| 33104 | Scalesworn Cultist | 4 | | 32230 | Abyssion | 1 |
| 33191 | Earthen Ring Shaman | 4 | | 32930 | Stone Trogg Reinforcement | 1 |
| 33193 | Earthen Ring Shaman | 4 | | 32963 | Initiate Goldmine | 1 |
| 32913 | Therazane | 3 | | 32965 | Rockslice Flayer | 1 |
| 32934 | Stone Trogg Berserker | 3 | | 33010 | Living Blood | 1 |
| 32957 | Earthcaller Yevaa | 3 | | 33044 | Exhausted Earthguard Sentinel | 1 |
| 33035 | Earthcaller Torunscar | 3 | | 33110 | Quartz Rockling | 1 |
| 33051 | Servant of Therazane | 3 | | 33118 | Twilight Priestess | 1 |
| 33052 | Servant of Therazane | 3 | | 33119 | Twilight Priestess | 1 |
| 33053 | Servant of Therazane | 3 | | 33123 | Twilight Priestess | 1 |
| 33356 | Mariahn the Soulcleanser | 3 | | 33124 | Twilight Priestess | 1 |
| 33422 | Terrath the Steady | 3 | | 33125 | Twilight Duskwarden | 1 |
| 33483 | Ma'haat the Indomitable | 3 | | 33126 | Twilight Duskwarden | 1 |
| 32927 | Petrified Stone Bat | 2 | | 33128 | Boldrich Stonerender | 1 |
| 32931 | Murkstone Trogg | 2 | | 33129 | Twilight Duskwarden | 1 |
| 33009 | Greater Quicksilver Ooze | 2 | | 33130 | Twilight Duskwarden | 1 |
| 33121 | High Priestess Lorthuna | 2 | | 33131 | Dragul Giantbutcher | 1 |
| 33127 | Twilight Desecrator | 2 | | 33134 | Zoltrik Drakebane | 1 |
| 33132 | Twilight Desecrator | 2 | | 33136 | Twilight Laborer | 1 |
| 33133 | Twilight Desecrator | 2 | | 33137 | Twilight Laborer | 1 |
| 33176 | Twilight Pyremaw | 2 | | 33138 | Twilight Laborer | 1 |
| 33189 | Maruut Stonebinder | 2 | | 33139 | Twilight Laborer | 1 |
| 33192 | Earthen Ring Shaman | 2 | | 33212 | Kor the Immovable | 1 |
| 33194 | Earthen Ring Shaman | 2 | | 33213 | Son of Kor | 1 |
| 33282 | Twilight Bloodshaper | 2 | | 33252 | Dormant Stonebound Elemental | 1 |
| 33289 | Needlerock Rider | 2 | | 33253 | Dormant Stonebound Elemental | 1 |
| 33320 | Crystalwing Stone Drake | 2 | | 33254 | Pebble | 1 |
| 33329 | Raging Crystal-walker | 2 | | 33266 | Boulder Platform | 1 |
| 33354 | Seer Kormo | 2 | | 33291 | Clay Mudaxle | 1 |
| 33482 | Boden the Imposing | 2 | | 33328 | Fungalmancer Glop | 1 |
| 33541 | Deactivated War Construct | 2 | | 33330 | Pulsing Geode | 1 |
| 33560 | Stone Drake | 2 | | 33339 | Energized Geode | 1 |
| 33637 | Giant Mushroom | 2 | | 33340 | Energized Geode | 1 |
| 33638 | Giant Mushroom | 2 | | 33353 | Doomshroom | 1 |
| 33639 | Giant Mushroom | 2 | | 33355 | Doomshroom | 1 |
| 33640 | Giant Mushroom | 2 | | 33380 | Troggzor the Earthinator | 1 |
| 33681 | Agate Mancrusher | 2 | | 33402 | Opalescent Guardian | 1 |
| 33682 | Agate Mancrusher | 2 | | 33403 | Opalescent Guardian | 1 |
| 33697 | Stonefather Oremantle | 2 | | 33404 | Stonescale Matriarch | 1 |
| 33729 | Seer Galekk | 2 | | 33443 | Aeosera | 1 |
| 33759 | Gorged Gyreworm | 2 | | 33591 | Fungal Terror | 1 |
| 33593 | Twilight Dragonspawn | 1 | | 34063 | Enslaved Miner | 1 |
| 33601 | Needlerock Mystic | 1 | | 34065 | Enslaved Miner | 1 |
| 33631 | Gorgonite | 1 | | 34087 | Explorer Mowi | 1 |
| 33647 | Ravenous Tunneler | 1 | | 34106 | Prospector Brewer | 1 |
| 33649 | Defaced Earthrager | 1 | | 34127 | Reliquary Jes'ca Darksun | 1 |
| 33680 | War Guardian | 1 | | 34131 | Examiner Rowe | 1 |
| 33692 | Elemental Overseer | 1 | | 34132 | Haethen Kaul | 1 |
| 33696 | Bouldergut | 1 | | 34138 | Twilight Armsman | 1 |
| 33760 | Colossal Gyreworm | 1 | | 34142 | Twilight Armsman | 1 |
| 33863 | Deep Spider | 1 | | 34149 | Twilight Armsman | 1 |
| 34011 | Twilight Binder | 1 | | 34150 | Twilight Cryptomancer | 1 |
| 34013 | Twilight Binder | 1 | | 34151 | Twilight Cryptomancer | 1 |
| 34014 | Twilight Binder | 1 | | 34152 | Twilight Cryptomancer | 1 |
| 34016 | Twilight Centurion | 1 | | 34264 | Emerald Colossus | 1 |
| 34017 | Twilight Centurion | 1 | | 34274 | Bound Water Elemental | 1 |
| 34018 | Twilight Centurion | 1 | | 34275 | Feldspar the Eternal | 1 |
| 34019 | Twilight Centurion | 1 | | 34317 | Boulder Platform | 1 |
| 34024 | Desecrated Earthrager | 1 | | 34320 | Porecite the Silent | 1 |
| 34036 | Twilight Heretic | 1 | | 34384 | Magdala Copperpick | 1 |
| 34037 | Twilight Heretic | 1 | | 34385 | Varx Hagglemore | 1 |
| 34038 | Twilight Heretic | 1 | | 34390 | Rixi "The Driller" Bombdigger | 1 |
| 34039 | Twilight Heretic | 1 | | 34391 | Dugsley Deepdelver | 1 |
| 34040 | Twilight Defiler | 1 | | 34392 | Beast-Handler Rustclamp | 1 |
| 34041 | Twilight Defiler | 1 | | 34393 | Mule Driver Ironshod | 1 |
| 34042 | Twilight Defiler | 1 | | 34395 | Caretaker Nuunwa | 1 |
| 34043 | Twilight Defiler | 1 | | 34426 | Hegrid Blazewing | 1 |
| 34427 | Earthmender Doros | 1 | | 35404 | Gyreworm | 1 |
| 34436 | Earthen Catapult | 1 | | 35488 | Jade Rager | 1 |
| 34548 | Bound Air Elemental | 1 | | 35489 | Jade Rager | 1 |
| 34947 | Bound Fire Elemental | 1 | | 35825 | Aggra | 1 |
| 35152 | Deep Spider | 1 | | 36178 | Falling Rubble Bunny | 1 |
| 35201 | Lodestone Elemental | 1 | | 36236 | Twilight Spider | 1 |
| 35202 | Jade Rager | 1 | | 36435 | Maziel | 1 |
| 35203 | D'lom the Collector | 1 | | 36603 | Emerald Shale Hatchling | 1 |
| 35204 | Ibdil the Mender | 1 | | 36604 | Amethyst Shale Hatchling | 1 |
| 36605 | Crimson Shale Hatchling | 1 | | 36613 | Crystal Beetle | 1 |
| 36634 | Deep Spider | 1 | | 36636 | Jadefang | 1 |
| 36648 | Topaz Shale Hatchling | 1 | | 36944 | Fungal Moth | 1 |
| 36952 | Fungal Moth | 1 | | 36953 | Fungal Moth | 1 |
| 36955 | Fungal Moth | 1 | | 37192 | Corestone of Patience | 1 |
| 37364 | Golgarok | 1 | | | | |

## GameObject display models to downport (44) — `displayId | example GO | #`

| displayId | example GO | # |
|--:|---|--:|
| 9432 | Brazier | 5 |
| 9145 | Cannoneer Sparkles | 4 |
| 9678 | Lost Isles Tree Fire 02 | 2 |
| 9721 | *(unnamed)* | 2 |
| 9815 | Gigantic Painite Cluster | 2 |
| 8757 | Excavation Banner Stand 02 | 1 |
| 9371 | Forge | 1 |
| 9510 | Abyssion Focus | 1 |
| 9652 | Anvil | 1 |
| 9681 | Blood Elf Lantern 01 | 1 |
| 9694 | Jade Crystal Cluster | 1 |
| 9715 | Chalky Crystal Formation | 1 |
| 9716 | Chalky Crystal Formation | 1 |
| 9722 | Thunder Stone | 1 |
| 9779 | The First Fragment of the World Pillar | 1 |
| 9781 | World Pillar Fragments | 1 |
| 9782 | World Pillar Fragment | 1 |
| 9783 | Restored World Pillar | 1 |
| 9784 | World Pillar Fragments | 1 |
| 9814 | *(unnamed)* | 1 |
| 9834 | Twilight Portal | 1 |
| 9840 | Blood Elf Square Crate 003 | 1 |
| 9842 | One-Time Decryption Engine | 1 |
| 9846 | Sprouting Crimson Mushroom | 1 |
| 9847 | Sprouting Crimson Mushroom | 1 |
| 9849 | Waygate Controller | 1 |
| 9855 | Trogg Crate | 1 |
| 9856 | Catapult Part | 1 |
| 9857 | Catapult Part | 1 |
| 9858 | Catapult Part | 1 |
| 9859 | Catapult Part | 1 |
| 9860 | Catapult Part | 1 |
| 9861 | Catapult Part | 1 |
| 9878 | Portal to Therazane's Throne | 1 |
| 9885 | Barrel | 1 |
| 10157 | Elementium Vein | 1 |
| 10158 | Rich Elementium Vein | 1 |
| 10159 | Obsidium Deposit | 1 |
| 10160 | Rich Obsidium Deposit | 1 |
| 10256 | Cinderbloom | 1 |
| 10266 | Heartblossom | 1 |
| 10283 | Deep Quartz Crystal Chunk | 1 |
| 10313 | Sturdy Treasure Chest | 1 |
| 10315 | Silken Treasure Chest | 1 |

> Many of these (veins, herbs, crystal clusters, catapult parts, braziers/forge/anvil) are generic
> world-prop M2s reused across Cata — bake them once and they cover a lot of Deepholm's set dressing.

## FactionTemplate.dbc — 24 missing
`2146, 2147, 2167, 2168, 2232, 2244, 2256, 2257, 2263, 2281, 2282, 2283, 2284, 2285, 2286, 2288, 2289, 2290, 2291, 2292, 2297, 2298, 2312, 2318`
Downport each from Cata `FactionTemplate.dbc` (and any new parent `Faction.dbc` rows), OR remap the
referencing creatures to a near-equivalent stock faction. Until present, those NPCs fall back to a
default faction (odd hostility) — cosmetic but worth doing for the hostile Twilight/stone-trogg mobs.

## Vehicle.dbc / VehicleSeat.dbc — 10 missing
`917, 934, 1009, 1062, 1087, 1088, 1247, 1248, 1249, 1543`
Needed by the 10 vehicle creature templates (rock-rides, catapults, drakes). Downport the Vehicle row
+ its VehicleSeat rows. Low priority — vehicle quests are P2/P3.

## Lock.dbc — 7 missing
`1852, 1861, 1863, 1864, 1865, 1866, 1932`
For locked doors/chests. Hand-add from Cata `lock.dbc`. Trivial.

## SpellFocusObject.dbc — 3 missing
`1678, 1680, 1681` (type-8 spell-focus GOs; ids 1/3/4 are stock). Trivial.
