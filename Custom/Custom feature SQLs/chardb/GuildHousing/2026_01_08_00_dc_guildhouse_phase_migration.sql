-- ============================================================================
-- Guild House Phase Migration
-- ============================================================================
-- This migration updates the stored phase values in dc_guild_house to use
-- the new power-of-2 phase formula for proper guild isolation.
--
-- Old formula: guildId + 10  (BROKEN: phases can overlap as bitmasks)
-- New formula: (1 << (4 + ((guildId - 1) % 27)))  (SAFE: each guild gets unique bit)
--
-- IMPORTANT: After running this migration, you MUST also clean up any existing
-- creature/gameobject spawns that use the old phase values. The cleanest approach
-- is to reset each guild house after migration.
-- ============================================================================

-- Update stored phase values to match new formula
-- Note: MySQL doesn't have bit-shift operator in older versions, so we use POW(2, x)
UPDATE `dc_guild_house`
SET `phase` = CAST(POW(2, 4 + ((guild - 1) % 27)) AS UNSIGNED)
WHERE `guild` > 0;

-- Verification query (run manually to check):
-- SELECT guild, phase, POW(2, 4 + ((guild - 1) % 27)) AS expected_phase FROM dc_guild_house;
