-- ====================================================================
-- DarkChaos Item Upgrade System - Phase 4 Complete Deployment
-- 
-- This file executes ALL required SQL for Phase 4B/C/D functionality
-- Run this on BOTH world and character databases as indicated
-- 
-- Date: November 5, 2025
-- ====================================================================

-- ====================================================================
-- PART 1: WORLD DATABASE (acore_world)
-- Execute on: acore_world database
-- ====================================================================

USE acore_world;

-- 1. Create/Update NPC creature templates
SOURCE worlddb/ItemUpgrades/dc_npc_creature_templates.sql;

-- 2. Spawn NPCs in world
SOURCE worlddb/ItemUpgrades/dc_npc_spawns.sql;

-- Verify NPCs are created
SELECT entry, name, subname, ScriptName 
FROM creature_template 
WHERE entry IN (190001, 190002, 190003);

-- Verify NPC spawns
SELECT guid, id1, map, position_x, position_y, position_z 
FROM creature 
WHERE guid BETWEEN 450001 AND 450005;

-- ====================================================================
-- PART 2: CHARACTER DATABASE (acore_characters)
-- Execute on: acore_characters database
-- ====================================================================

USE acore_characters;

-- 1. Create all Phase 4B/C/D tables
SOURCE chardb/ItemUpgrades/dc_item_upgrade_phase4bcd_characters.sql;

-- Verify all tables are created
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    CREATE_TIME
FROM 
    INFORMATION_SCHEMA.TABLES
WHERE 
    TABLE_SCHEMA = 'acore_characters' 
    AND TABLE_NAME LIKE 'dc_%'
ORDER BY 
    TABLE_NAME;

-- ====================================================================
-- DEPLOYMENT VERIFICATION
-- ====================================================================

-- Check if all Phase 4 tables exist
SELECT 
    CASE 
        WHEN COUNT(*) >= 23 THEN 'SUCCESS: All Phase 4 tables created'
        ELSE CONCAT('WARNING: Only ', COUNT(*), ' tables created (expected 23+)')
    END AS deployment_status
FROM 
    INFORMATION_SCHEMA.TABLES
WHERE 
    TABLE_SCHEMA = 'acore_characters' 
    AND TABLE_NAME LIKE 'dc_%';

-- ====================================================================
-- POST-DEPLOYMENT NOTES
-- ====================================================================

/*
After running this SQL file:

1. REBUILD THE SERVER:
   ./acore.sh compiler build

2. RESTART WORLDSERVER

3. TEST COMMANDS IN-GAME:
   .upgradeprog mastery       - View artifact mastery status
   .upgradeprog testset       - GM: Test mastery levels
   .upgradeprog weekcap       - View weekly spending caps
   .upgradeprog unlocktier    - GM: Unlock tiers
   .upgradeprog tiercap       - GM: Modify tier caps

4. TEST NPCs:
   - NPC 190001 (Item Upgrade Vendor) - Stormwind/Orgrimmar
   - NPC 190002 (Artifact Curator) - Shattrath
   - NPC 190003 (Item Upgrader) - Stormwind/Orgrimmar

5. NPCs SHOULD NOW HAVE ACTIVE GOSSIP MENUS with:
   - Item Upgrade Vendor: Token exchange, upgrade viewing
   - Artifact Curator: Artifact collection, discovery info
   - Item Upgrader: Item upgrade interface

If NPCs still show "coming in Phase 4B":
   - Verify server was rebuilt AFTER adding all scripts to dc_script_loader.cpp
   - Check worldserver.log for script registration errors
   - Verify database tables exist with above queries
*/
