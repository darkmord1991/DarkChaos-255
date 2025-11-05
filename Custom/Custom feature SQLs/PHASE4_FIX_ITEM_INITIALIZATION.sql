-- ====================================================================
-- Phase 4 Fix: Initialize Item Upgrade System Properly
-- ====================================================================

USE acore_chars;

-- ====================================================================
-- PROBLEM DIAGNOSIS
-- ====================================================================
/*
ISSUE: NPC "View Upgradeable Items" shows nothing, buttons don't respond

ROOT CAUSE:
The C++ code's CanUpgradeItem() function returns FALSE for items
that don't exist in dc_player_item_upgrades table yet.

EXPECTED BEHAVIOR:
- New items (never upgraded) should appear as "Upgrade Level: 0/15"
- First upgrade creates the database row

CURRENT BEHAVIOR:
- C++ checks if item exists in dc_player_item_upgrades
- No row = CanUpgrade returns FALSE
- Item never shows in NPC list

SOLUTIONS:
1. SQL Fix: Pre-create rows for all equipped items (this script)
2. C++ Fix: Modify CanUpgradeItem() to return TRUE for valid equipped items even if no DB row
*/

-- ====================================================================
-- PART 1: Grant Starting Currency (from PHASE4_INITIALIZE_CURRENCY.sql)
-- ====================================================================

INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season)
SELECT 
    guid AS player_guid,
    'upgrade_token' AS currency_type,
    1000 AS amount,
    1 AS season
FROM characters
ON DUPLICATE KEY UPDATE 
    amount = amount + 1000;

INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season)
SELECT 
    guid AS player_guid,
    'artifact_essence' AS currency_type,
    500 AS amount,
    1 AS season
FROM characters
ON DUPLICATE KEY UPDATE 
    amount = amount + 500;

-- ====================================================================
-- PART 2: Initialize Item Upgrade Rows for ALL Equipped Items
-- ====================================================================

/*
This creates rows in dc_player_item_upgrades for every equipped item
that players currently have. This allows them to appear in the
"View Upgradeable Items" list immediately.

Assumptions:
- Items in EQUIPMENT slots (0-18) are upgradeable
- Initial tier_id = 1 (Leveling tier) for all items
- Can be adjusted per item quality/source later
*/

INSERT INTO dc_player_item_upgrades 
    (item_guid, player_guid, tier_id, upgrade_level, tokens_invested, essence_invested, stat_multiplier, season, first_upgraded_at)
SELECT 
    ii.guid AS item_guid,
    ii.owner_guid AS player_guid,
    1 AS tier_id,  -- Default to Tier 1 (Leveling)
    0 AS upgrade_level,  -- Not upgraded yet
    0 AS tokens_invested,
    0 AS essence_invested,
    1.0 AS stat_multiplier,  -- Base stats (no bonus)
    1 AS season,
    NULL AS first_upgraded_at  -- NULL = never upgraded
FROM item_instance ii
JOIN character_inventory ci ON ci.item = ii.guid
WHERE ci.slot BETWEEN 0 AND 18  -- Equipment slots only (not bags/bank)
  AND ii.guid NOT IN (SELECT item_guid FROM dc_player_item_upgrades)  -- Don't duplicate existing rows
ON DUPLICATE KEY UPDATE item_guid = item_guid;  -- No-op if row exists

-- ====================================================================
-- PART 3: Verification Queries
-- ====================================================================

-- Show total items initialized
SELECT 
    'Items Initialized' AS status,
    COUNT(*) AS total_items,
    COUNT(DISTINCT player_guid) AS total_players
FROM dc_player_item_upgrades
WHERE upgrade_level = 0;

-- Show items by player (sample)
SELECT 
    c.name AS character_name,
    COUNT(piu.item_guid) AS upgradeable_items,
    SUM(CASE WHEN piu.upgrade_level > 0 THEN 1 ELSE 0 END) AS upgraded_items,
    SUM(CASE WHEN piu.upgrade_level = 0 THEN 1 ELSE 0 END) AS pending_items
FROM dc_player_item_upgrades piu
JOIN characters c ON c.guid = piu.player_guid
GROUP BY c.name
ORDER BY upgradeable_items DESC
LIMIT 20;

-- Show currency balances
SELECT 
    c.name AS character_name,
    SUM(CASE WHEN put.currency_type = 'upgrade_token' THEN put.amount ELSE 0 END) AS tokens,
    SUM(CASE WHEN put.currency_type = 'artifact_essence' THEN put.amount ELSE 0 END) AS essence
FROM dc_player_upgrade_tokens put
JOIN characters c ON c.guid = put.player_guid
GROUP BY c.name
ORDER BY c.name
LIMIT 20;

-- ====================================================================
-- SUCCESS MESSAGE
-- ====================================================================

SELECT 
    '✓ Item Upgrade System Initialized!' AS status,
    'All equipped items are now ready to upgrade' AS message,
    'Talk to NPC 190003 and click "View Upgradeable Items"' AS next_step,
    'You should now see your equipped gear listed' AS expected_result;

-- ====================================================================
-- POST-DEPLOYMENT: Testing Instructions
-- ====================================================================

/*
IN-GAME TESTING:

1. Talk to NPC 190003 (Item Upgrader)
2. Click "View Upgradeable Items"
3. **SHOULD NOW SEE:** List of equipped items (armor, weapons, trinkets)
4. Click an item name
5. **SHOULD SEE:**
   ===== Item Name =====
   Upgrade Level: 0/15 (New)
   Stat Bonus: +0%
   Total Investment: 0 Essence, 0 Tokens
   
   Next Upgrade Cost:
   Essence: 0
   Tokens: 50 (example)
   
   ✓ You can afford this upgrade!
   [PERFORM UPGRADE]

6. Click "PERFORM UPGRADE"
7. **SHOULD HAPPEN:**
   - Currency deducted (check NPC 190002 - Artifact Curator, essence should decrease)
   - Item stats increase
   - Database updated

TROUBLESHOOTING:

If still no items show:
- Check if character has equipped items (.listitem 0 command)
- Verify items are in slots 0-18 (equipment, not bags)
- Check dc_player_item_upgrades table has rows for your character
- Restart worldserver if code changes were made

If buttons don't respond:
- Check worldserver.log for errors
- Verify ItemUpgrade scripts are registered (grep "ItemUpgrade" worldserver.log)
- Ensure server was rebuilt after C++ changes

If currency shows 0:
- Check dc_player_upgrade_tokens table
- Verify currency_type = 'upgrade_token' or 'artifact_essence'
- Re-run Part 1 of this script
*/
