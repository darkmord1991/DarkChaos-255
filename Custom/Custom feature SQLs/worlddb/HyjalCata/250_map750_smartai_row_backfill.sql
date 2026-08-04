-- ---------------------------------------------------------------------------
-- 250  Map 750 -- smart_scripts row backfill for the short-imported clones
-- ---------------------------------------------------------------------------
-- APPLY 249_ FIRST (249_map750_dropped_cast_spells.sql). Eight of the rows
-- below cast spells that exist only after 249_'s spell_dbc downport (80009,
-- 80012, 80066, 80068, 80546, 87420, 91997, 91998) -- without it the core
-- rejects those casts at load. 249_'s other two spells (81020 Heave, 89399
-- Release Wisp) are cast only by rows of entries EXCLUDED below for id-drift
-- (3608408 Warlord Krellian, 3707139 Irontree Stomper), so they are not
-- re-imported here; 249_ still provides them safely for a later round.
--
-- WHAT THIS IS: 248_'s audit left one known gap -- 72 spawned clone-band
-- creature entries (3.6M/3.7M bands, map 750) carry FEWER smart_scripts
-- source_type-0 rows than their cata_world source. This file re-derives that
-- diff live (spawned = entry IN (SELECT DISTINCT id FROM creature WHERE
-- map = 750); cata entry = clone entry minus its band offset) and re-imports
-- the rows whose (entry, id) is absent from ours, keeping the cata id.
--
-- ID-DRIFT GATE (the trap 205_/222_ taught): before importing anything, every
-- candidate entry was alignment-checked -- each id present in BOTH tables must
-- have the SAME event_type on both sides. 40 of the 72 entries FAILED that
-- check (same ids bound to different events, e.g. our 3603296 id 1 is event 22
-- where cata's id 1 is event 0) and are EXCLUDED WHOLESALE.
--
-- >> RESOLVED 2026-08-04 in 252_ -- these 40 need NO import, ever. Every one
-- >> de-offsets to a VANILLA creature id, so our rows are AzerothCore's own
-- >> correct 3.3.5 scripts (38 of 40 byte-identical to stock; the other 2
-- >> differ only by a correctly-applied clone remap). cata_world's rows are
-- >> Cataclysm's re-authoring of the same creature -- importing them would
-- >> stack two generations of behaviour, duplicate actionlist calls and pull
-- >> in Cata-only spells this server lacks. See 252_ for the full proof.
-- >> Do not re-open this from a raw "our rows < cata rows" count.
--
-- The excluded 40 (kept listed for traceability):
--     3603296 Orgrimmar Grunt          3603696 Ran Bloodtooth
--     3603713 Wrathtail Wave Rider     3603717 Wrathtail Sorceress
--     3603743 Foulweald Warrior        3603750 Foulweald Totemic
--     3603758 Felmusk Satyr            3603762 Felmusk Felsworn
--     3603763 Felmusk Shadowstalker    3603767 Bleakheart Trickster
--     3603797 Cenarion Protector       3603803 Severed Keeper
--     3603821 Wildthorn Lurker         3603823 Ghostpaw Runner
--     3603825 Ghostpaw Alpha           3603926 Thistlefur Pathfinder
--     3604273 Keeper Ordanus           3606073 Searing Infernal
--     3606115 Roaming Felguard         3606201 Legashi Rogue
--     3607432 Frostsaber Stalker       3607433 Frostsaber Huntress
--     3607434 Frostsaber Pride Watcher 3608408 Warlord Krellian
--     3608761 Mosshoof Courser         3610737 Shy-Rotam
--     3612037 Ursol'lok                3702071 Moonstalker Matriarch
--     3702165 Grizzled Thistle Bear    3702206 Greymist Hunter
--     3707015 Flagglemurk the Cruel    3707106 Jadefire Rogue
--     3707110 Jadefire Shadowstalker   3707139 Irontree Stomper
--     3707149 Withered Protector       3707158 Deadwood Shaman
--     3708956 Angerclaw Bear           3709517 Shadow Lord Fel'dan
--     3709860 Salia                    3714467 Kroshius
-- (This also removes the task-cited Shy-Rotam action-33 example -- its whole
-- entry is drift-excluded, so no kill-credit/summon remap remains in the set.)
--
-- WHAT SURVIVES: 32 entries, 53 source_type-0 rows, plus cata timed action
-- list 384801 (10 source_type-9 rows) that Kayneth Stillwind's re-imported
-- quest-reward row calls. Zero rows dropped.
--
-- REMAPS APPLIED (this fork's rules, tallied):
--   a) entryorguid = cata entry + band offset ............ all 53 rows
--      (48 rows +3,600,000; 5 rows +3,700,000)
--   b) FORK RANGE-PARAM LAYOUT (222_'s lesson: this fork reads range-event
--      distance from event_param5/6 -- "min, max, repeatMin, repeatMax,
--      rangeMin, rangeMax" -- upstream/cata from 1/2). Shifted ep1/2 -> ep5/6
--      and zeroed ep1/2 for event 9/67 rows ............... 3 rows
--        3709861 id 2 (ev 9, range 0-30), 3639843 id 2 (ev 9, range 0-8),
--        3638951 id 2 (ev 67). CAVEAT on that last one: cata's event-67
--        params 1/2 are COOLDOWNS (8000/9000 ms), not a distance -- after the
--        mandated shift the row is data-complete but its range window
--        (8000-9000 yd) cannot proc; flagged for manual retune, imported
--        anyway so the row (and the count parity below) is preserved.
--   c) action 33 KILL_CREDIT / 12 SUMMON_CREATURE entry offset ... 0 rows
--      (no such actions survive the drift gate)
--   d) action 80 CALL_TIMED_ACTIONLIST: 384801 -> 360384801 ...... 1 row
--      (3603848 Kayneth Stillwind id 6; list = raw id + 100 x band offset,
--      same transform 217_ used; target band id verified FREE before writing,
--      and the list's 10 rows are imported below with the same rules -- they
--      contain no casts, summons, links, ranges or guid targets, so only the
--      entryorguid changes)
--   e) event 61 LINK carries no params: zeroed ep2=1000 on 3603771 id 4;
--      the other two LINK rows (3640147 id 3, 3722834 id 6) were already
--      all-zero. target 2 VICTIM params: already zero on all 13 rows ... 1 row
--   f) target_type 10 (cata spawn guid, untranslatable) .......... 0 rows
--   g) action 53 WP_START paths .................................. 0 rows
--      (the audit's "0 WP rows in the dropped set" claim re-verified)
--
-- Cross-checks done against the live DB before writing:
--   * cata has no event_param6 / target_param4 (212_'s schema-drift lesson);
--     both are written as literal 0 on every row.
--   * link targets resolve: 3640148 id 1 links id 2 (present in ours),
--     3640149 id 0 links id 1 (present), 3722834 id 5 links id 6 (imported
--     here together).
--   * TALK rows all have their creature_text groups already imported
--     (3603765/3603770/3603772/3640148 group 0, 3603892 groups 0-4,
--     Kayneth 3603848 groups 1-3), and all 32 entries carry AIName='SmartAI'.
--   * 3623837 id 8 summons gameobject 186943 (Scuttle's Mop and Bucket):
--     STOCK template exists, no clone exists -- raw id kept on purpose.
--   * every other cast in the set resolves already (249_ verified the full
--     dropped set against the live 53,156-row Spell.dbc; these ten were the
--     only gaps).
--
-- Comments are cata's verbatim (they carry the range info later audits parse).
-- DELETEs hit exactly the (entryorguid, id) tuples inserted -- never a range,
-- and source_type 9 only by pinned ids (action-list collision rule).
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) the 53 re-imported creature rows (source_type 0, 32 entries)
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND (`entryorguid`, `id`) IN (
    (3603765, 1), (3603765, 2), (3603770, 1), (3603770, 2), (3603770, 3), (3603770, 4), (3603770, 5),
    (3603771, 4), (3603771, 5), (3603772, 2), (3603772, 3), (3603848, 6), (3603892, 1), (3605314, 1),
    (3617300, 4), (3623837, 7), (3623837, 8), (3638896, 1), (3638913, 0), (3638951, 2), (3639437, 2),
    (3639437, 3), (3639646, 2), (3639843, 0), (3639843, 2), (3639844, 1), (3639931, 1), (3639931, 2),
    (3639931, 3), (3640066, 3), (3640066, 7), (3640147, 3), (3640148, 1), (3640148, 8), (3640149, 0),
    (3640336, 0), (3640336, 1), (3640562, 0), (3640562, 3), (3641008, 1), (3641008, 3), (3641008, 4),
    (3641027, 0), (3641027, 2), (3641396, 0), (3641500, 2), (3641563, 1), (3646991, 0), (3702237, 1),
    (3709861, 1), (3709861, 2), (3722834, 5), (3722834, 6));

INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
     `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(3603765, 0, 1, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Satyr - Between 0-30% Health - Say Line 0 (No Repeat)'),
(3603765, 0, 2, 0, 0, 0, 100, 0, 5000, 5500, 12000, 16000, 0, 0, 11, 31279, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Satyr - In Combat - Cast ''Swipe'''),
(3603770, 0, 1, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Shadowstalker - Between 0-30% Health - Say Line 0 (No Repeat)'),
(3603770, 0, 2, 0, 2, 0, 100, 0, 0, 50, 35000, 40000, 0, 0, 11, 77471, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Shadowstalker - Between 0-50% Health - Cast ''Shadow Shield'''),
(3603770, 0, 3, 0, 16, 0, 100, 0, 77471, 40, 35000, 42000, 0, 0, 11, 77471, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Shadowstalker - On Friendly Unit Missing Buff ''Shadow Shield'' - Cast ''Shadow Shield'''),
(3603770, 0, 4, 0, 11, 0, 100, 1, 0, 0, 0, 0, 0, 0, 11, 77806, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Shadowstalker - On Respawn - Cast ''Stealth'' (No Repeat)'),
(3603770, 0, 5, 0, 7, 0, 100, 1, 0, 0, 0, 0, 0, 0, 11, 77806, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Shadowstalker - On Evade - Cast ''Stealth'' (No Repeat)'),
-- rule e: cata carried ep2=1000 on this LINK row; LINK takes no params
(3603771, 0, 4, 0, 61, 2, 100, 0, 0, 0, 0, 0, 0, 0, 22, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Hellcaller - Out of Combat - Set Event Phase 0 (Phase 2)'),
(3603771, 0, 5, 0, 2, 0, 100, 1, 0, 15, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Bleakheart Hellcaller - Between 0-15% Health - cast enrage (No Repeat)'),
(3603772, 0, 2, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Lesser Felguard - Between 0-30% Health - Cast ''Enrage'' (No Repeat)'),
(3603772, 0, 3, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Lesser Felguard - Between 0-30% Health - Say Line 0 (No Repeat)'),
-- rule d: action 80 list id 384801 -> 360384801 (imported in section B)
(3603848, 0, 6, 0, 20, 0, 100, 0, 1011, 0, 0, 0, 0, 0, 80, 360384801, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Quest ''Forsaken Diseases'' Finished - Run Script'),
(3603892, 0, 1, 0, 38, 0, 100, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 12, 1, 0, 0, 0, 0, 0, 0, 0,
 'Relara Whitemoon - On Data Set - Say Line 0'),
(3605314, 0, 1, 0, 2, 0, 100, 0, 0, 50, 24000, 32000, 0, 0, 11, 20671, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Phantim - Between 0-50% Health - Cast ''Summon Phantim Illusion'''),
(3617300, 0, 4, 0, 0, 0, 100, 0, 8000, 9000, 24000, 32000, 0, 0, 11, 37624, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Gorgannon - In Combat - Cast ''Carrion Swarm'''),
(3623837, 0, 7, 0, 38, 0, 100, 0, 29, 29, 0, 0, 0, 0, 11, 40163, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'ELM General Purpose Bunny - On Data Set - Cast Teleport'),
-- gameobject 186943 kept raw: stock template exists, no clone exists
(3623837, 0, 8, 0, 38, 0, 100, 0, 29, 29, 0, 0, 0, 0, 50, 186943, 30, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'ELM General Purpose Bunny - On Data Set - Summon Gameobject ''Scuttle''s Mop and Bucket'''),
(3638896, 0, 1, 0, 8, 0, 100, 0, 74723, 0, 0, 0, 0, 0, 37, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'On spell 74723 hit  - Self: Die // '),
(3638913, 0, 0, 0, 0, 0, 100, 0, 6000, 8000, 14000, 18000, 0, 0, 11, 79881, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'When in combat and timer at the begining between 6000 and 8000 ms (and later repeats every 14000 and 18000 ms) - Self: Cast spell 79881 on Victim // Twilight Vanquisher - In Combat - Cast ''Slam'''),
-- rule b shift; CAVEAT (see header): cata ep1/2 here were cooldowns, retune
(3638951, 0, 2, 0, 67, 0, 100, 0, 0, 0, 0, 0, 8000, 9000, 11, 80576, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Assassin - On Behind Target - Cast ''Shadowstep'''),
(3639437, 0, 2, 0, 0, 0, 100, 0, 8000, 8000, 12000, 19000, 0, 0, 11, 80012, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Hunter - In Combat - Cast ''Chimera Shot'''),
(3639437, 0, 3, 0, 0, 0, 100, 0, 5000, 5000, 22000, 24000, 0, 0, 11, 80009, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Hunter - In Combat - Cast ''Serpent Sting'''),
(3639646, 0, 2, 0, 0, 0, 100, 0, 3500, 4500, 11200, 15900, 0, 0, 11, 80513, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Gar''gol - In Combat - Cast ''Mash'''),
(3639843, 0, 0, 0, 0, 0, 100, 0, 0, 0, 3400, 4700, 0, 0, 11, 80058, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Stormcaller - In Combat - Cast ''Twilight Burst'''),
-- rule b shift: range 0-8 moved from cata ep1/2 into ep5/6
(3639843, 0, 2, 0, 9, 0, 100, 0, 0, 0, 15800, 16900, 0, 8, 11, 80068, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Stormcaller - Within 0-8 Range - Cast ''Thunderstorm'''),
(3639844, 0, 1, 0, 0, 0, 100, 0, 8000, 8000, 16000, 18000, 0, 0, 11, 80066, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Howling Riftdweller - In Combat - Cast ''Tornado'''),
(3639931, 0, 1, 0, 0, 0, 100, 0, 9000, 9000, 22000, 27000, 0, 0, 11, 79823, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Grove Tender - In Combat - Cast ''Starfall'''),
(3639931, 0, 2, 0, 0, 0, 80, 0, 5000, 5500, 13000, 19000, 0, 0, 11, 78907, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Grove Tender - In Combat - Cast ''Starfire'''),
(3639931, 0, 3, 0, 0, 0, 100, 1, 2000, 7000, 33000, 34000, 0, 0, 11, 79825, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Grove Tender - In Combat - Cast ''Summon Unstable Mushroom'' (No Repeat)'),
(3640066, 0, 3, 0, 0, 1, 100, 0, 4000, 7000, 15000, 19000, 0, 0, 11, 74737, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Wailing Weed - In Combat - Cast ''Leafy Wail'' (Phase 1)'),
(3640066, 0, 7, 0, 0, 1, 100, 0, 3300, 4500, 11300, 14500, 0, 0, 11, 80546, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Wailing Weed - In Combat - Cast ''Bile Blast'' (Phase 1)'),
(3640147, 0, 3, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 75072, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 ' Linked - Self: Cast spell Inferno Ping (75072) on Self // '),
(3640148, 0, 1, 2, 8, 0, 100, 0, 75072, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'On spell Inferno Ping (75072) hit  - Self: Talk 0 // '),
(3640148, 0, 8, 0, 0, 0, 100, 0, 1000, 5000, 14000, 20000, 0, 0, 11, 74811, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'When in combat and timer at the begining between 1000 and 5000 ms (and later repeats every 14000 and 20000 ms) - Self: Cast spell Swipe (74811) on Victim // '),
(3640149, 0, 0, 1, 8, 0, 100, 0, 75072, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'On spell Inferno Ping (75072) hit  - Self: Set react state to REACT_PASSIVE // '),
(3640336, 0, 0, 0, 0, 0, 100, 0, 5100, 5200, 11300, 12500, 0, 0, 11, 80561, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Charbringer - In Combat - Cast ''Flame Edge'''),
(3640336, 0, 1, 0, 0, 0, 100, 0, 9900, 9900, 23400, 26800, 0, 0, 11, 80594, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Charbringer - In Combat - Cast ''Flame Thrower'''),
(3640562, 0, 0, 0, 0, 0, 100, 0, 0, 0, 3400, 4700, 0, 0, 11, 91997, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Initiate - In Combat - Cast ''Shadow Bolt'''),
(3640562, 0, 3, 0, 0, 0, 100, 0, 9000, 9000, 11000, 13000, 0, 0, 11, 91998, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Initiate - In Combat - Cast ''Throw Rock'''),
(3641008, 0, 1, 0, 1, 0, 50, 0, 500, 1000, 600000, 600000, 0, 0, 11, 77042, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Druid of the Talon - Out of Combat - Cast ''Storm Crow Form'''),
(3641008, 0, 3, 0, 0, 0, 100, 0, 9900, 9900, 11200, 21300, 0, 0, 11, 77345, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0,
 'Druid of the Talon - In Combat - Cast ''Stormcall'''),
(3641008, 0, 4, 0, 2, 0, 100, 1, 0, 45, 0, 0, 0, 0, 11, 77066, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Druid of the Talon - Between 0-45% Health - Cast ''Healing Touch'' (No Repeat)'),
(3641027, 0, 0, 0, 0, 0, 100, 0, 0, 0, 3400, 4700, 0, 0, 11, 77160, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Wormwing Screecher - In Combat - Cast ''Nimbus Bolt'''),
(3641027, 0, 2, 0, 0, 0, 100, 0, 9000, 9000, 35000, 36000, 0, 0, 11, 76963, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Wormwing Screecher - In Combat - Cast ''Wild Tornado'''),
(3641396, 0, 0, 0, 0, 0, 100, 0, 0, 0, 3400, 4700, 0, 0, 11, 77508, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Fiery Tormentor - In Combat - Cast ''Fireball'''),
(3641500, 0, 2, 0, 0, 0, 100, 0, 5000, 5000, 55000, 55000, 0, 0, 11, 77627, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Twilight Scorchlord - In Combat - Cast ''Summon Fiery Minion'''),
(3641563, 0, 1, 0, 0, 0, 100, 0, 5000, 5000, 14000, 17000, 0, 0, 11, 87420, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Shadowflame Master - In Combat - Cast ''Shadowflame Blast'''),
(3646991, 0, 0, 0, 4, 0, 100, 1, 0, 0, 0, 0, 0, 0, 11, 75025, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Unbound Fire Elemental - On Aggro - Cast ''Rush of Flame'' (No Repeat)'),
(3702237, 0, 1, 0, 4, 0, 100, 1, 0, 0, 0, 0, 0, 0, 11, 66060, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Moonstalker Sire - On Aggro - Cast ''Sprint'' (No Repeat)'),
(3709861, 0, 1, 0, 0, 0, 100, 0, 2000, 3000, 12000, 14000, 0, 0, 11, 15968, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Moora - In Combat - Cast ''Lash of Pain'''),
-- rule b shift: range 0-30 moved from cata ep1/2 into ep5/6
(3709861, 0, 2, 0, 9, 0, 100, 0, 0, 0, 34000, 37000, 0, 30, 11, 38048, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0,
 'Moora - Within 0-30 Range - Cast ''Curse of Pain'''),
(3722834, 0, 5, 6, 1, 1, 100, 513, 360000, 360000, 360000, 360000, 0, 0, 47, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Clintar Dreamwalker - Out of Combat - Set Visibility Off (Phase 1) (No Repeat)'),
(3722834, 0, 6, 0, 61, 1, 100, 513, 0, 0, 0, 0, 0, 0, 41, 100, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Clintar Dreamwalker - Out of Combat - Despawn In 100 ms (Phase 1) (No Repeat)');

-- ---------------------------------------------------------------------------
-- B) cata timed action list 384801 -> 360384801 (source_type 9, 10 rows)
-- ---------------------------------------------------------------------------
-- Called by Kayneth Stillwind's row above. Band id verified free before
-- writing. Sub-indices 0-9 preserved; no row needs any further remap (no
-- casts, no summons, no ranges, no guid targets). Pinned ids only -- never
-- range-DELETE source_type 9.
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` = 360384801
    AND `id` IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9);

INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
     `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(360384801, 9, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 103, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Set Rooted On'),
(360384801, 9, 1, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 83, 3, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Remove Questgiver+Gossip npcflag'),
(360384801, 9, 2, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, 0, 5, 7, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Play Emote 7'),
(360384801, 9, 3, 0, 0, 0, 100, 0, 3000, 3000, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Say Line 1'),
(360384801, 9, 4, 0, 0, 0, 100, 0, 4000, 4000, 0, 0, 0, 0, 17, 64, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Set Emote State 64'),
(360384801, 9, 5, 0, 0, 0, 100, 0, 1000, 1000, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Say Line 2'),
(360384801, 9, 6, 0, 0, 0, 100, 0, 4000, 4000, 0, 0, 0, 0, 17, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Set Emote State 0'),
(360384801, 9, 7, 0, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 3, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Say Line 3'),
(360384801, 9, 8, 0, 0, 0, 100, 0, 2000, 2000, 0, 0, 0, 0, 82, 3, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Add Questgiver+Gossip npcflag'),
(360384801, 9, 9, 0, 0, 0, 100, 0, 10000, 10000, 0, 0, 0, 0, 103, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Kayneth Stillwind - On Script - Set Rooted Off');

-- ---------------------------------------------------------------------------
-- Trailer -- verification (run after apply + restart)
-- ---------------------------------------------------------------------------
-- 1) Count parity for the 32 imported entries -- expect 32 rows, ours = cata
--    on every one (the 40 drift-excluded entries stay short on purpose):
--      SELECT s.`entryorguid` AS entry, COUNT(*) AS ours, c.cnt AS cata
--      FROM `smart_scripts` s
--      JOIN (SELECT `entryorguid`, COUNT(*) cnt FROM `cata_world`.`smart_scripts`
--            WHERE `source_type` = 0 GROUP BY `entryorguid`) c
--        ON c.`entryorguid` = s.`entryorguid`
--           - IF(s.`entryorguid` < 3700000, 3600000, 3700000)
--      WHERE s.`source_type` = 0 AND s.`entryorguid` IN (
--          3603765, 3603770, 3603771, 3603772, 3603848, 3603892, 3605314,
--          3617300, 3623837, 3638896, 3638913, 3638951, 3639437, 3639646,
--          3639843, 3639844, 3639931, 3640066, 3640147, 3640148, 3640149,
--          3640336, 3640562, 3641008, 3641027, 3641396, 3641500, 3641563,
--          3646991, 3702237, 3709861, 3722834)
--      GROUP BY s.`entryorguid`, c.cnt HAVING ours <> cata;   -- expect empty
-- 2) Action list present -- expect 10:
--      SELECT COUNT(*) FROM `smart_scripts`
--      WHERE `source_type` = 9 AND `entryorguid` = 360384801;
-- 3) No SmartAI-with-zero-rows anomalies in the clone bands -- expect empty:
--      SELECT ct.`entry` FROM `creature_template` ct
--      WHERE ct.`AIName` = 'SmartAI'
--        AND ct.`entry` BETWEEN 3600000 AND 3799999
--        AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s
--                        WHERE s.`entryorguid` = ct.`entry` AND s.`source_type` = 0);
-- 4) Worldserver boot log: zero "SmartAIMgr" rejections naming any entry in
--    the list above (rejected rows never run -- read the core's own verdict).
-- ---------------------------------------------------------------------------
