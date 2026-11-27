# Giant Isles NPC List

## Neutral NPCs (Faction 35 - Primal Wardens / Zandalari Friendly)

### Main Hub / Warden's Landing
*   **Elder Zul'jin** (400200) - Zandalari Expedition Leader
*   **Rokhan the Beast Tamer** (400202) - Zandalari Beast Master
*   **Scout Zan'do** (400203) - Zandalari Scout
*   **Trader Zal'aman** (400210) - Zandalari Supplies
*   **Zandalari Expedition Guard** (400220) - Guard
*   **Spirit of the Primal** (400300) - Quest Giver
*   **Bartender Zul'tik** (400310) - Innkeeper
*   **Windwalker Ta'zo** (400311) - Flight Master
*   **Ku'ma** (401110) - The Bone Collector (Vendor)
*   **Safari Trainer Rex** (401111) - Dinosaur Taming Trainer
*   **Professor Ironpaw** (401112) - Archaeology Trainer
*   **Primal Quartermaster** (401113) - Reputation Rewards
*   **Stable Master Thornhide** (401114) - Stable Master
*   **Banker Goldtusk** (401115) - Banker
*   **Flight Master Skywing** (401116) - Flight Master
*   **Flight Master Windsoar** (401117) - Flight Master
*   **Primal Guardian** (401008) - Guard (Level 81 Elite)
*   **Ancient Primal Guardian** (401009) - Guard (Level 82 Elite)
*   **Commander Stonewall** (401200) - Expedition Commander (Quest Giver)
*   **Dr. Zira Fossildigger** (401201) - Lead Archaeologist (Quest Giver)
*   **Huntmaster Grimtusk** (401202) - Beast Tracker (Quest Giver)
*   **Sage Primalwisdom** (401203) - Lore Keeper (Quest Giver)
*   **Raptor Handler Ka'zak** (401210) - Daily Quest Giver
*   **Bone Collector Maz'gor** (401211) - Daily Quest Giver
*   **Scout Shadowtooth** (401212) - Daily Quest Giver
*   **Oondasta Tracker Grull** (401220) - World Boss Hunter
*   **Thok Pursuer Raz'jin** (401221) - World Boss Hunter
*   **Storm Chaser Volta** (401222) - World Boss Hunter
*   **Captain Harlan** (400320) - Coastal Defense (Quest Giver)

### Nice's Nice Beach — Fishing Area
*   **Angler Rolo** (401118) - Fishing Supplies (vendor: bait, basic tackle)
*   **Grak'zar** (401119) - Ancient Cook (fish-to-food exchange, ScriptName: `npc_giant_isles_primal_cook`)
*   **Angler Tideborn** (401120) - Fishing Trainer (teaches/upgrades Fishing skill)
*   **Tide-Watcher Mazu** (401121) - Fishing Daily Quest Giver (daily quests: catch specific fish, use fishing holes)
*   **Bait Keeper Ruk'lo** (401122) - Fishing Bait & Tackle Vendor (specialty bait items)
*   **Primal Fisher** (401123) - Ambient Angler (flavor, 3–4 spawns along beach; non-interactive)

### Nice's Nice Beach — Neutral PvP-Blocking Guards
> These guards patrol the fishing area and enforce a sanctuary-like no-PvP zone.
> Faction **84** (Friendly to all / Peacekeeper) so neither Horde nor Alliance can be attacked.
> `unit_flags` must include `UNIT_FLAG_NON_ATTACKABLE` (256) for players.
> `flags_extra` must include the guard flag (2) so they retaliate against flagged attackers.
> The **area flag** for Nice's Nice Beach (area 5017) should additionally be set to
> `AREA_FLAG_SANCTUARY` in AreaTable.dbc to fully prevent PvP flagging in the zone.

*   **Tideguard Sentinel** (401010) - Neutral Fishing Area Guard (Level 81 Elite, faction 84, patrols beach)
*   **Tideguard Warden** (401011) - Neutral Fishing Area Guard (Level 80, faction 84, stationary posts)
*   **Primal Peacekeeper** (401012) - Neutral Senior Guard (Level 82 Elite, faction 84, enforces no-PvP, near Angler Rolo)

## Horde NPCs (Faction 29 - Orgrimmar)
*   **Bozzle** (401105) - Goblin Expedition Leader
*   **Grizzek Fizzlecrank** (401106) - Repairs
*   **Zasha** (401107) - General Goods
*   **Flight Master Krag** (401108) - Flight Master
*   **Innkeeper Grok** (401109) - Innkeeper
*   **Beast Hunter** (401004) - Guard (Level 80)
*   **Beast Hunter Veteran** (401005) - Guard (Level 81 Elite)
*   **Beast Hunter Trapper** (401006) - Guard (Level 80)
*   **Beast Hunter Warlord** (401007) - Guard (Level 82 Elite)

## Alliance NPCs (Faction 12 - Stormwind)
*   **Beeble Cogsworth** (401100) - Gnome Expedition Leader
*   **Tinker Sprocketwrench** (401101) - Repairs
*   **Emily Stormwind** (401102) - General Goods
*   **Flight Master Aldric** (401103) - Flight Master
*   **Innkeeper Molly** (401104) - Innkeeper
*   **Primal Warden** (401000) - Guard (Level 80)
*   **Primal Warden Sergeant** (401001) - Guard (Level 81 Elite)
*   **Primal Warden Marksman** (401002) - Guard (Level 80)
*   **Primal Warden Captain** (401003) - Guard (Level 82 Elite)

## Normal Enemies (Rank 0)
*   **Chaos Devilsaur** (400000) - Level 80
*   **Primal Stegodon** (400003) - Level 80
*   **Elder Stegodon** (400004) - Level 80
*   **Chaos Raptor** (400007) - Level 80
*   **Chaos Raptor Runner** (400008) - Level 80
*   **Chaos Raptor Hunter** (400009) - Level 80
*   **Fledgling Chaos Pterrordax** (400011) - Level 80
*   **Chaos Pterrordax** (400012) - Level 80
*   **Young Primal Diemetradon** (400014) - Level 80
*   **Primal Diemetradon** (400015) - Level 80
*   **Primal Troll Warrior** (400250) - Level 80
*   **Primal Troll Shadowcaster** (400251) - Level 80

## Elites & Rares (Rank 1/2)
*   **Ironhide Chaos Devilsaur** (400001) - Level 81 Elite
*   **Tyrant Chaos Devilsaur** (400002) - Level 81 Elite
*   **Armored Stegodon** (400005) - Level 81 Elite
*   **Ancient Stegodon** (400006) - Level 81 Elite
*   **Venomhide Chaos Raptor** (400010) - Level 81 Elite
*   **Frenzied Chaos Pterrordax** (400013) - Level 81 Elite
*   **Elder Primal Diemetradon** (400016) - Level 81 Elite
*   **Primal Direhorn** (400050) - Rare Elite (Static Spawn)
*   **Chaos Rex** (400051) - Rare Elite (Static Spawn)
*   **Ancient Primordial** (400052) - Rare Elite (Static Spawn)
*   **Savage Stegodon Matriarch** (400053) - Rare Elite (Static Spawn)
*   **Alpha Chaos Raptor** (400054) - Rare Elite (Static Spawn)
*   **Bonecrusher** (400055) - Random Rare Spawn
*   **Gorespine the Impaler** (400056) - Random Rare Spawn
*   **Venomfang** (400057) - Random Rare Spawn
*   **Skyscreamer** (400058) - Random Rare Spawn
*   **Gul'rok the Cursed** (400059) - Random Rare Spawn
*   **Primal Troll Berserker** (400252) - Level 81 Elite
*   **Primal Troll Witch Doctor** (400253) - Level 81 Elite
*   **Primal Troll Headhunter** (400254) - Level 81 Elite
*   **Warlord Gha'tul** (400260) - Level 82 Elite (Mini-Boss)

## Bosses (Rank 3 - World Bosses)
*   **Oondasta** (400100) - King of Dinosaurs
*   **Thok the Bloodthirsty** (400101) - Primal Hunter
*   **Nalak the Storm Lord** (400102) - Ancient Thunder Lizard

## Boss Trash Mobs
*   **Young Oondasta** (400400) - Spawn of Oondasta
*   **Frenzied Pack Raptor** (400401) - Thok's Brood
*   **Storm Spark** (400402) - Lightning Elemental (Nalak Add)
*   **Static Cloud** (400403) - Nalak's Essence

## Temple of Atal'Hakkar (entries 400500–400525)
*See `temple_atal_hakkar_clone.sql` for full templates, quests, items, and loot.*

### Trash (Rank 0, Level 80)
*   **Awakened Atal'ai Warrior** (400500) — melee (copy of 5256)
*   **Awakened Atal'ai Witch Doctor** (400501) — caster (copy of 5259)
*   **Risen Atal'ai Priest** (400502) — undead caster elite (copy of 5273)
*   **Atal'ai Boneguard** (400503) — undead warrior (copy of 5267)
*   **Atal'ai Soulflayer** (400504) — elite rogue type (copy of 5270)
*   **Hakkar's Devotee** (400505) — shadow caster (copy of 5263)

### The Four Bloodseekers (Rank 1, Level 81 Elite — quest 82001 objectives)
*   **Zul'kar the Flayer** (400510) — warrior (based on Gasher 5713)
*   **Seer Mazra** (400511) — shadow caster (based on Hukku 5715)
*   **Bone Weaver Zolo** (400512) — necromancer (based on Zul'Lor 5716)
*   **Soul Raker Mijan** (400513) — rogue type (based on Mijan 5717)

### Bosses
*   **Atal'alarion the Eternal** (400520) — Rank 2, Level 82 (copy of 8580)
*   **Jammal'an the Eternal** (400521) — Rank 2, Level 83 (copy of 5710)
*   **Reawakened Avatar of Hakkar** (400522) — Rank 3, Level 83 World Boss (copy of 8443)
*   **Ancient Shade of Eranikus** (400523) — Rank 2, Level 82 Dragon (copy of 5709)

### Quest NPCs
*   **Scholar Zal'ira** (400525) — Zandalari Historian (Quest Giver, faction 35, quests 82000–82005, neutral)
*   **Sentinel Liriel** (400526) — Alliance Warden (Quest Giver, faction 12, quests 82010/82011/82014, Alliance only)
*   **Shadow Priest Mokra** (400527) — Horde Shadow Agent (Quest Giver, faction 29, quests 82012/82013/82015, Horde only)

## Water NPCs
*   **Primal Threshadon** (400060) - Level 80 Elite
*   **Primal Crocodile** (400061) - Level 80
*   **Abyssal Sea Serpent** (400062) - Level 81 Elite

## Invaders (Zandalari Invasion Event)
*   **Invasion Warning Horn** (400325) - Trigger NPC
*   **Zandalari Invader** (400326) - Wave 1
*   **Zandalari Scout** (400327) - Wave 1
*   **Zandalari Spearman** (400328) - Wave 1
*   **Zandalari Warrior** (400329) - Wave 2
*   **Zandalari Berserker** (400330) - Wave 2
*   **Zandalari Shadow Hunter** (400331) - Wave 2
*   **Zandalari Blood Guard** (400332) - Wave 3 Elite
*   **Zandalari Witch Doctor** (400333) - Wave 3 Elite
*   **Zandalari Beast Tamer** (400334) - Wave 3 Elite
*   **Zandalari War Raptor** (400335) - Wave 3 Add
*   **Warlord Zul'mar** (400336) - Invasion Commander (Boss)
*   **Zandalari Honor Guard** (400337) - Boss Guard (Elite)

## Defenders
*   **Coastal Cannon** (400321) - Vehicle
*   **Zandalari Scout Ship** (400324) - Enemy Ship (Target)

## The Blood Tide (entries 400580-400599)
*Created by `data/sql/updates/pending_db_world/rev_1793385646011983500.sql`. Positions live in `dc_giant_isles_invasion_data.h`.*

*   **Zandalari Dinomancer** (400580) - Static camps and The Binding
*   **War-God Dokah** (400581) - Flagship boss; killing him lowers the foothold
*   **Zandalari War Engine** (400582) / **Engine Crewman** (400583) - Iron Rain
*   **Binding Pylon** (400584) / **Bound Primal Behemoth** (400585) - The Binding
*   **Zandalari Beastmaster** (400586) / **Stampeding Direhorn** (400587) - The Stampede
*   **Zandalari Sky-Caller** (400588) - Sky Raid
*   **Elder Zul'jin** (400589) - Battle form, joins the warlord stage
*   **Captive Beast Hunter** (400590) - Caged at Slimer Bay and the bunkers
*   **Scouting markers** (400591-400593) - Invisible credit for Smoke on the Horizon
*   **Expedition Medic** (400594) - Heals the line
*   **Impact Marker** (400595) - Invisible, drops fire
*   **Rogue Tyrant** (400596) - Hostile to both sides
*   **Kill credits** (400597-400599) - War Standard, war plan, engine sabotage
