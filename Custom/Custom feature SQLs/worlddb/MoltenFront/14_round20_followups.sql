-- =====================================================================
-- Molten Front -- 14  Round-20 follow-ups to the 13_ base-phase import
-- ---------------------------------------------------------------------
-- Post-apply boot log. 13_ did what it set out to do (all 7 dailies valid, 135
-- spawns placed, Thrall's scene loading, 52 inert warnings gone), but importing
-- 14 creature templates pulled their Cata data in with them and surfaced three
-- follow-ons. Two are the documented "next wave" pattern; ONE IS A REGRESSION
-- THIS SET INTRODUCED and is fixed here.
--
-- ###########################################################################
-- 1. REGRESSION -- new client-freeze risk from 13_
-- ###########################################################################
--     Creature (Entry: 3653107) has a non-existing VehicleId (1633).
--     This *WILL* cause the client to freeze!
--
-- 3653107 "Smothervine" is one of the four summon/credit templates 13_ cloned so
-- quest 29139 "Aggressive Growth" could resolve. It carries VehicleId 1633, which
-- existed in neither the server table nor the client Vehicle.dbc (that file caps
-- at ID 1651 with 449 records). 13_ should have checked the VehicleId of every
-- template it imported -- it did not, so it traded one freeze class for another.
--
-- Fixed the RIGHT way rather than by zeroing, because unlike the Castle Nathria
-- vehicles (vestigial data no script touched -- see CastleNathria/27_) this one is
-- live: Smothervine carries npcflag 16777216 (SPELLCLICK), i.e. players click it
-- to mount/interact, which is exactly what the vehicle is for.
--
-- The row is the REAL Cata 4.3.4 Vehicle.dbc 1633, read out of
-- enUS/locale-enUS.MPQ (NOT the wow-update archives) -- 1564 records, 40 fields,
-- recordSize 160, byte-identical schema to 3.3.5:
--     Flags = 1073741824, TurnSpeed = PitchSpeed = PI, PitchMin/Max = 0,
--     MouseLookOffsetPitch = 0.7854, CameraFadeDistScalarMin/Max = 1.0 / 1.5
-- SeatID_1 is set to **8976**, not Cata's own 9916, for the same reason
-- MoltenFront/10_ did it for Vehicle 1631: Cata's VehicleSeat.dbc is 66 fields /
-- recsize 264 against this client's 58 / 232, so importing a seat verbatim would
-- ship a half-mapped row -- precisely the thing that crashes the client. 8976 is
-- present and known-good on both sides (verified in Server/data/dbc and the CSV).
--
-- The CLIENT side is already deployed: Vehicle.csv now carries 1633 (cloned from
-- the verified 1631 row, ID + Flags patched), Vehicle.dbc recompiled to 450
-- records and packed into BOTH patch-4.MPQ and enGB/patch-enGB-3.MPQ + synced.
--
-- ###########################################################################
-- 2. Two SmartAI action params still holding RAW Cata creature ids
-- ###########################################################################
--     SmartAIMgr: Entry 3653112 Event 8 Action 33 uses non-existent Creature entry 53112
--     SmartAIMgr: Entry 3675180 Event 0 Action 12 uses non-existent Creature entry 53107
-- Same defect class as the quest objectives (116_) and Thrall's TEXT_OVER (144_):
-- the import copies action params across un-offset. Action 33 is KILLED_MONSTER
-- (the Magma Worm crediting its own kill) and action 12 is SUMMON_CREATURE
-- (Wondi's Bunny summoning the Smothervine), so both are functional, not cosmetic:
-- as written the worm gives no credit and the bunny summons nothing. Both targets
-- exist as clones -- 3653112 and 3653107 were created by 13_.
--
-- ###########################################################################
-- 3. NOT here: the nine missing spells that wave also surfaced
-- ###########################################################################
-- Handled in HyjalCata/147_spell_dbc_round20.sql (8 straight Cata downports +
-- 101174 as an effect-only orphan). Applying that file also clears the two
-- remaining "has SmartAI enabled but no SmartAI entries" warnings (3652135 and
-- 3675180) -- they DO have rows; every row was being discarded over those spells.
--
-- Idempotent; guarded on the exact current values. Needs a worldserver restart.
-- =====================================================================

-- ---- 1. Vehicle 1633 (server side; client already deployed) ----------------
DELETE FROM `vehicle_dbc` WHERE `ID` = 1633;

INSERT INTO `vehicle_dbc`
    (`ID`,`Flags`,`TurnSpeed`,`PitchSpeed`,`PitchMin`,`PitchMax`,
     `SeatID_1`,`SeatID_2`,`SeatID_3`,`SeatID_4`,`SeatID_5`,`SeatID_6`,`SeatID_7`,`SeatID_8`,
     `MouseLookOffsetPitch`,`CameraFadeDistScalarMin`,`CameraFadeDistScalarMax`,`CameraPitchOffset`)
VALUES
    (1633, 1073741824, 3.14159274, 3.14159274, 0, 0,
     8976, 0, 0, 0, 0, 0, 0, 0,
     0.785398, 1, 1.5, 0);

-- ---- 2. offset the two raw creature ids onto their clones -------------------
-- action 33 = KILLED_MONSTER (Subterranean Magma Worm crediting its own kill)
UPDATE `smart_scripts` s
SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3653112
  AND s.`action_type` = 33 AND s.`action_param1` = 53112
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = 3653112);

-- action 12 = SUMMON_CREATURE (Wondi's Bunny summoning the Smothervine)
UPDATE `smart_scripts` s
SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3675180
  AND s.`action_type` = 12 AND s.`action_param1` = 53107
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = 3653107);

-- ---------------------------------------------------------------------
-- LESSON worth carrying forward: any pass that clones creature_template rows must
-- also check the VehicleId it copies. A cloned template can drag in a VehicleId
-- whose DBC row only exists in the source client, and the core escalates that to
-- "WILL cause the client to freeze". Cheap guard for the next import:
--   SELECT ct.entry, ct.VehicleId FROM creature_template ct
--   WHERE ct.VehicleId > 0
--     AND NOT EXISTS (SELECT 1 FROM vehicle_dbc v WHERE v.ID = ct.VehicleId);
-- (remembering that `vehicle_dbc` holds only CUSTOM additions -- cross-check the
--  actual Vehicle.dbc file too, exactly as with spell_dbc.)
-- ---------------------------------------------------------------------
