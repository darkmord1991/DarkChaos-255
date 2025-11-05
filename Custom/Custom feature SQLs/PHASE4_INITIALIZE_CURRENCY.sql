-- ====================================================================
-- Phase 4 Currency System Initialization
-- Initialize player currency balances for testing
-- ====================================================================

USE acore_chars;

-- ====================================================================
-- IMPORTANT: Currency System Explanation
-- ====================================================================
/*
The Item Upgrade System uses a DATABASE-BACKED currency system, NOT item-based currency.

HOW IT WORKS:
1. Currencies are stored in `dc_player_upgrade_tokens` table
2. Players earn currency through gameplay (NOT by receiving items):
   - Quest completion: 10-40 tokens based on difficulty
   - Dungeon bosses: 25 tokens + 5 essence
   - Raid bosses: 50 tokens + 10 essence
   - PvP kills: 15 tokens (scaled by level)
   - Achievements: 50 essence each

3. NPCs query the database table to display currency balances
4. Upgrade costs are deducted from database, not inventory

WHAT ABOUT ITEMS 100999/109998?
- These items exist in item_template but are NOT used by the C++ code
- They were part of an earlier design that was replaced
- The C++ code NEVER checks inventory for these items
- Delete them or repurpose them - they don't affect the upgrade system

TESTING THE SYSTEM:
- Use this SQL script to manually add currency for testing
- OR earn currency naturally through gameplay
- OR use GM command `.upgradeprog testset` to set currency (if implemented)
*/

-- ====================================================================
-- Grant Starting Currency to ALL Players (for testing)
-- ====================================================================

-- Grant 1000 Upgrade Tokens to all existing characters (season 1)
INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season, last_update)
SELECT 
    guid AS player_guid,
    'upgrade_token' AS currency_type,
    1000 AS amount,
    1 AS season,
    UNIX_TIMESTAMP() AS last_update
FROM characters
ON DUPLICATE KEY UPDATE 
    amount = amount + 1000,
    last_update = UNIX_TIMESTAMP();

-- Grant 500 Artifact Essence to all existing characters (season 1)
INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season, last_update)
SELECT 
    guid AS player_guid,
    'artifact_essence' AS currency_type,
    500 AS amount,
    1 AS season,
    UNIX_TIMESTAMP() AS last_update
FROM characters
ON DUPLICATE KEY UPDATE 
    amount = amount + 500,
    last_update = UNIX_TIMESTAMP();

-- ====================================================================
-- Verify Currency Grants
-- ====================================================================

-- Check total currencies granted
SELECT 
    currency_type,
    COUNT(DISTINCT player_guid) AS players_with_currency,
    SUM(amount) AS total_currency,
    AVG(amount) AS avg_per_player,
    MIN(amount) AS min_balance,
    MAX(amount) AS max_balance
FROM dc_player_upgrade_tokens
WHERE season = 1
GROUP BY currency_type;

-- ====================================================================
-- Grant Currency to Specific Player (replace PLAYER_GUID)
-- ====================================================================

/*
-- Example: Grant currency to player with GUID 12345
INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season, last_update)
VALUES 
    (12345, 'upgrade_token', 1000, 1, UNIX_TIMESTAMP()),
    (12345, 'artifact_essence', 500, 1, UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE 
    amount = amount + VALUES(amount),
    last_update = UNIX_TIMESTAMP();
*/

-- ====================================================================
-- View Your Currency Balance (replace PLAYER_GUID)
-- ====================================================================

/*
-- Example: Check player 12345's currency
SELECT 
    p.currency_type,
    p.amount AS current_balance,
    p.weekly_earned,
    p.season,
    FROM_UNIXTIME(p.last_update) AS last_update_time,
    c.name AS character_name
FROM dc_player_upgrade_tokens p
JOIN characters c ON c.guid = p.player_guid
WHERE p.player_guid = 12345;
*/

-- ====================================================================
-- Reset All Currency (USE WITH CAUTION)
-- ====================================================================

-- Uncomment to delete ALL player currencies (for fresh testing)
-- DELETE FROM dc_player_upgrade_tokens WHERE season = 1;

-- ====================================================================
-- GM COMMANDS TO MANAGE CURRENCY
-- ====================================================================

/*
In-game GM commands (if Phase 4B progression system is active):

.upgradeprog testset <tokens> <essence> <mastery_rank>
  - Example: .upgradeprog testset 1000 500 5
  - Sets your currency and mastery level for testing

.upgradeprog mastery
  - View your current mastery progression and currency

.upgrademech reset
  - Reset ALL upgrade data (careful!)

EARNING CURRENCY NATURALLY:
- Complete quests (10-40 tokens based on difficulty)
- Kill dungeon bosses (25 tokens, 5 essence)
- Kill raid bosses (50 tokens, 10 essence)
- Kill players in PvP (15 tokens)
- Complete achievements (50 essence)

Weekly cap: 500 tokens per week (resets Monday 00:00 server time)
*/

-- ====================================================================
-- Post-Init Verification
-- ====================================================================

-- Show all players with currency
SELECT 
    c.name AS character_name,
    c.guid AS player_guid,
    c.level,
    p.currency_type,
    p.amount AS balance,
    p.weekly_earned,
    FROM_UNIXTIME(p.last_update) AS last_update
FROM dc_player_upgrade_tokens p
JOIN characters c ON c.guid = p.player_guid
WHERE p.season = 1
ORDER BY c.name, p.currency_type;

-- ====================================================================
-- SUCCESS MESSAGE
-- ====================================================================

SELECT 
    '✓ Currency initialization complete!' AS status,
    'All players have been granted starting currency' AS message,
    'Use NPC 190003 (Item Upgrader) to test upgrades' AS next_step,
    'Currency is stored in dc_player_upgrade_tokens, NOT items' AS important_note;
