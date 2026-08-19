-- 80_spellclick_repair.sql -- map 750/751 downports, DB step 19.
--
-- Cleans up the rest of the spell-click damage found while fixing the Horde Haulers
-- (see 79_hauler_transport.sql for the mechanism).
--
-- RECAP OF THE MECHANISM
-- `npcflag` bit 16777216 (0x01000000) is UNIT_NPC_FLAG_SPELLCLICK
-- (UnitDefines.h:346), NOT PLAYER_VEHICLE (0x02000000, :347).
-- ObjectMgr::LoadNPCSpellClickSpells (ObjectMgr.cpp:8606-8612) SKIPS any
-- npc_spellclick_spells row whose spell does not exist, and then (:8631-8637) strips
-- the SPELLCLICK flag from any template left with no surviving row. A stripped flag
-- never reaches the client, so there is no cursor and no interaction at all.
--
-- Two distinct failure shapes came out of that:
--   * map 751 -- the import copied NO spellclick rows at all, so the flag is stripped
--     for every template that carries it. 79_ fixed the two Haulers; four props remain.
--   * map 750 -- the rows DID import, but five of their spells are Cata-only and
--     absent from this client, so those rows are rejected at load.
--
-- 46598 "Ride Vehicle Hardcoded" is the safe substitute ONLY where the creature has a
-- real VehicleId: SpellAuraEffects' HandleAuraControlVehicle bails on
-- !target->IsVehicle(), so pointing a non-vehicle at 46598 produces a click that
-- looks alive and does nothing -- worse than no click. Every substitution below is
-- gated on VehicleId != 0, verified against Vehicle.dbc.

-- ---------------------------------------------------------------------------
-- 1. map 750: substitute 46598 where the creature IS a vehicle
--
--    3636437 Rocketway Rat  VehicleId 519 (present in Vehicle.dbc), 7 spawns,
--            only row was spell 68726 -> rejected -> flag stripped -> unrideable.
--    3640250 Treetop        VehicleId 734 (present), 0 spawns today, same story.
-- ---------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` IN (3636437, 3640250);

INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(3636437, 46598, 1, 0),
(3640250, 46598, 1, 0);

-- ---------------------------------------------------------------------------
-- 2. map 750: drop the 8 redundant Flame Protection Rune rows for spell 97885.
--
--    Entries 3652884-3652890 and 3653887 each carry TWO rows: 97773 (exists here)
--    and 97885 (does not). The 97773 row keeps the flag alive, so these NPCs already
--    work -- the 97885 rows only produce a rejected-row error line per boot.
--    Removing them is cosmetic, not behavioural.
-- ---------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells`
WHERE `npc_entry` IN (3652884, 3652885, 3652886, 3652887, 3652888, 3652889, 3652890, 3653887)
  AND `spell_id` = 97885;

-- ---------------------------------------------------------------------------
-- 3. map 751: clear the dead SPELLCLICK flag on four props.
--
--    4138933 Briny Sea Cucumber   (38 spawns) needs Cata spell 73123
--    4144776 Sharpbeak            ( 1 spawn ) needs Cata spell 94120
--    4153517 Squirming Slime Mold (43 spawns) needs Cata spell 99325
--    4153526 Brightwater Snail    (34 spawns) needs Cata spell 99356
--
--    None of those spells exist here, and none of these creatures has a VehicleId,
--    so 46598 is NOT a valid substitute (see the header). The core already strips
--    this flag at every boot; clearing it in the DB changes no behaviour, it just
--    makes the table agree with reality and removes four error lines per start.
--
--    These are Cata cooking-daily gather nodes plus one quest bird. The three
--    gatherables carry SmartAI that despawns the node on click -- WITHOUT the real
--    spell a click would consume the node and grant nothing, which is worse than an
--    inert prop, so leaving them unclickable is the correct interim state.
--
--    TO RESTORE LATER: re-set npcflag to 16777216 and add the matching
--    npc_spellclick_spells row, once the spell is genuinely downported. That means
--    reassembling it from the Cata client, where Spell.dbc is 48 fields split across
--    SpellEffect/SpellMisc/etc versus our 234-field single table -- and watch for the
--    effect-id >= 165 boot abort while doing it.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
SET `npcflag` = `npcflag` & ~16777216
WHERE `entry` IN (4138933, 4144776, 4153517, 4153526)
  AND (`npcflag` & 16777216);

-- ---------------------------------------------------------------------------
-- NOT FIXED HERE -- these need a real spell downport, no safe substitute exists
--
--   3639619 Twilight Recruit    (8 spawns, VehicleId 0) needs spell 90102
--   3652177 Child of Tortolla   (0 spawns, VehicleId 0) needs spell 96504
--
-- Both keep their SPELLCLICK flag and their rejected row, so both still log at boot.
-- Left alone deliberately: clearing the flag would hide a genuine content gap on a
-- creature that has live spawns, and 46598 would be a dead click.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'rocketway rat / treetop now on 46598 (want 2)' AS what, COUNT(*) AS n
FROM `npc_spellclick_spells` WHERE `npc_entry` IN (3636437, 3640250) AND `spell_id` = 46598
UNION ALL SELECT 'redundant 97885 rows left (want 0)', COUNT(*)
FROM `npc_spellclick_spells` WHERE `spell_id` = 97885
UNION ALL SELECT 'flame runes still clickable via 97773 (want 8)', COUNT(*)
FROM `npc_spellclick_spells` WHERE `spell_id` = 97773
UNION ALL SELECT 'map-751 props still flagged (want 0)', COUNT(*)
FROM `creature_template` WHERE `entry` IN (4138933,4144776,4153517,4153526) AND (`npcflag` & 16777216)
UNION ALL SELECT 'haulers still flagged, from 79_ (want 2)', COUNT(*)
FROM `creature_template` WHERE `entry` IN (4144731,4144764) AND (`npcflag` & 16777216);

-- Every template that will STILL log "has UNIT_NPC_FLAG_SPELLCLICK but no data".
-- Expect exactly the two documented above (3639619, 3652177) once 79_ and 80_ are in.
SELECT t.`entry`, t.`name`, t.`VehicleId`,
       (SELECT COUNT(*) FROM `creature` c WHERE c.`id` = t.`entry`) AS spawns
FROM `creature_template` t
WHERE (t.`npcflag` & 16777216)
  AND NOT EXISTS (SELECT 1 FROM `npc_spellclick_spells` s WHERE s.`npc_entry` = t.`entry`)
ORDER BY t.`entry`;
