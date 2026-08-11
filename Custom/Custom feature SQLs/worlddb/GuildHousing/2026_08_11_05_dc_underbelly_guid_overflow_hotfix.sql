-- =============================================================================
-- HOTFIX: "Creature spawn id overflow!! Can't continue, shutting down server."
-- =============================================================================
-- My fault, in 2026_08_11_04_dc_legion_dalaran_underbelly.sql: I allocated the
-- Underbelly spawn guids from 16800000, but creature SPAWN IDS are capped at
-- 0xFFFFFF = 16777215. ObjectMgr::GenerateCreatureSpawnId() (ObjectMgr.cpp:7667)
-- seeds _creatureSpawnId from MAX(guid)+1 and hard-stops the server the moment
-- anything asks for a new spawn id -- which the Outdoor PvP system does at boot,
-- hence the shutdown right after "Starting Outdoor PvP System".
--
-- Highest legitimate guid in use is 16700002, so this moves the Underbelly block
-- down to 16710000+, which is empty and comfortably under the cap. No content is
-- lost -- the rows are only renumbered.
--
-- Apply this, then start the worldserver. Nothing client-side is involved.
-- =============================================================================

-- Move the block down by exactly 90,000: 16800000..16800218 -> 16710000..16710218
UPDATE `creature`
SET `guid` = `guid` - 90000
WHERE `guid` BETWEEN 16800000 AND 16800218;

-- Safety net: if anything else ever lands above the cap, this makes the overflow
-- visible instead of fatal. Should return 0 rows.
SELECT `guid`, `id`, `map` FROM `creature` WHERE `guid` > 16777214;
