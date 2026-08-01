-- ---------------------------------------------------------------------------
-- 194  Map 750 -- give the Hyjal flight network its own taxi mount
-- ---------------------------------------------------------------------------
-- All 17 map-750 taxi nodes fly the stock `Riding Hippogryph` (creature 3837,
-- display 1936 -> Creature\Hippogryph\Hippogryph.mdx). That is the plain
-- CREATURE hippogryph -- the vanilla Darnassus bird, no saddle, no armor -- and
-- it is the same model both factions get on every node in the zone.
--
-- This adds a dedicated taxi mount flying the Legion Val'sharah Hippogryph
-- (display 502052 -> Creature\hippogryph2\hippogryph2mount.m2, texture set
-- hippogryph2valshara / hippogryph2valsharasaddle). Val'sharah is Legion's
-- druid zone, so it reads as an upgrade of the flavour map 750 already has
-- rather than an import from somewhere unrelated -- and it is still a
-- hippogryph, which is what the Hyjal network flies today.
--
-- WHY A NEW TEMPLATE INSTEAD OF POINTING AT 3462107
-- Entry 3462107 ("Val'sharah Hippogryph", subname "Custom Mount Model") already
-- carries display 502052, and TaxiNodes could point straight at it -- the taxi
-- code only ever reads a display off the template:
--     ObjectMgr.cpp GetTaxiMountDisplayId()
--         mount_entry = node->MountCreatureID[teamId == TEAM_ALLIANCE ? 1 : 0];
--         mount_info  = GetCreatureTemplate(mount_entry);
--         model       = mount_info->GetRandomValidModel();
-- But 3462107 is owned by the Collection mount pipeline, which regenerates that
-- ID range. If it is ever renumbered the flight network silently loses its
-- mount and every node falls back to a display-less template. 800200 is in a
-- range nothing else claims, so the taxi network owns its own row.
--
-- CLIENT ASSETS -- all verified present in Data\patch-F.MPQ:
--     Creature\hippogryph2\hippogryph2mount.m2
--     Creature\hippogryph2\hippogryph2mount00.skin
--     Creature\hippogryph2\hippogryph2valshara.blp
--     Creature\hippogryph2\hippogryph2valsharasaddle.blp
--
-- THE OTHER HALF OF THIS CHANGE lives in the DBC, not here. TaxiNodes.csv is
-- GENERATED, so the mount is set in the generator and the CSV is regenerated:
--     Custom/Documentation/scripts/gen_taxi.py
--         HYJAL_HIPPO = 800200                       (new constant)
--         NODEMAP rows for map 750: HIPPO -> HYJAL_HIPPO
--     -> regenerate Custom/CSV DBC/TaxiNodes.csv, recompile to
--        Custom/DBCs/TaxiNodes.dbc, deploy to the server data/dbc.
-- TaxiNodes.MountCreatureID is server-side only (ObjectMgr reads it from the
-- server's DBC), so the client patch does NOT have to ship the new TaxiNodes --
-- but the client DOES need patch-F for the model, which it already has.
--
-- Both MountCreatureID slots get 800200: map 750 is a neutral Guardians-of-
-- Hyjal zone and the existing nodes already gave both factions the same bird.
-- ---------------------------------------------------------------------------

-- The mount template. Mirrors 3837's shape (type 1 beast, no npcflag, friendly
-- faction 35) -- a taxi mount is never spawned, targeted or attacked, so
-- nothing here matters beyond entry + a valid model.
DELETE FROM `creature_template` WHERE `entry` = 800200;
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`,
     `unit_class`, `unit_flags`, `type`, `type_flags`, `RegenHealth`,
     `MovementType`, `AIName`, `ScriptName`, `VerifiedBuild`)
VALUES
    (800200, 'Riding Hippogryph', 'Hyjal', 80, 80, 35, 0,
     1, 0, 1, 0, 1,
     0, '', '', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 800200;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
     `VerifiedBuild`)
VALUES
    (800200, 0, 502052, 1, 1, 0);
