/*
 * Mythic+ Keystone Pedestal GameObject
 * GameObject that players interact with to start a Mythic+ run
 * Players must have the appropriate keystone item in inventory
 * Item is consumed when used, run is activated
 * Entry: 300200
 */

-- ============================================================
-- GAMEOBJECT TEMPLATE: Mythic+ Keystone Pedestal
-- ============================================================

DELETE FROM gameobject_template WHERE entry = 300200;
INSERT INTO gameobject_template (entry, `type`, displayId, name, IconName, castBarCaption, unk1, 
    size, Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, 
    Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19, Data20, Data21, Data22, Data23, 
    AIName, ScriptName, VerifiedBuild)
VALUES (300200, 24, 9367, 'Mythic+ Keystone Pedestal', '', '', '', 1.0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 
    'go_mythic_plus_font_of_power', 0);

-- ============================================================
-- PLACEMENT NOTES
-- ============================================================

/*
 * To place keystones pedestals in dungeons:
 * 1. Use admin command: .gobject add 300200 <x> <y> <z> [map]
 * 2. Example: .gobject add 300200 1234.5 5678.9 12.3 1481  (Siege of Boralus)
 * 
 * The pedestal script (go_mythic_plus_font_of_power) handles:
 * - Item consumption from player inventory
 * - Run activation and initialization
 * - Keystone timer and difficulty scaling
 * 
 * Suggested Placement Locations:
 * - Dungeon entrance
 * - Summoning stone area
 * - Near dungeon portal/exit
 */
