-- Fix for Heirloom Cache Gameobjects - Add missing gameobject_template_addon entries
-- Without these entries, the gameobjects won't be interactive/lootable

-- Add gameobject_template_addon entries for all heirloom caches
DELETE FROM `gameobject_template_addon` WHERE `entry` BETWEEN 1991001 AND 1991033;
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`) VALUES
(1991001, 0, 0, 0, 0), -- Heirloom Weapon Cache - Fury
(1991002, 0, 0, 0, 0), -- Heirloom Weapon Cache - Precision
(1991003, 0, 0, 0, 0), -- Heirloom Weapon Cache - Titan
(1991004, 0, 0, 0, 0), -- Heirloom Weapon Cache - Assassin
(1991005, 0, 0, 0, 0), -- Heirloom Weapon Cache - Lethality
(1991006, 0, 0, 0, 0), -- Heirloom Weapon Cache - Evasion
(1991007, 0, 0, 0, 0), -- Heirloom Weapon Cache - Sorcery
(1991008, 0, 0, 0, 0), -- Heirloom Weapon Cache - Arcane Power
(1991009, 0, 0, 0, 0), -- Heirloom Weapon Cache - Protection
(1991010, 0, 0, 0, 0), -- Heirloom Helm Cache - DPS Plate
(1991011, 0, 0, 0, 0), -- Heirloom Helm Cache - Physical Plate
(1991012, 0, 0, 0, 0), -- Heirloom Helm Cache - Tank Plate
(1991013, 0, 0, 0, 0), -- Heirloom Helm Cache - DPS Mail
(1991014, 0, 0, 0, 0), -- Heirloom Helm Cache - Physical Mail
(1991015, 0, 0, 0, 0), -- Heirloom Helm Cache - Tank Mail
(1991016, 0, 0, 0, 0), -- Heirloom Helm Cache - Leather Caster
(1991017, 0, 0, 0, 0), -- Heirloom Helm Cache - Leather Haste
(1991018, 0, 0, 0, 0), -- Heirloom Helm Cache - Cloth Caster
(1991019, 0, 0, 0, 0), -- Heirloom Chest Cache - DPS
(1991020, 0, 0, 0, 0), -- Heirloom Chest Cache - Physical
(1991021, 0, 0, 0, 0), -- Heirloom Chest Cache - Caster
(1991022, 0, 0, 0, 0), -- Heirloom Legs Cache - Tank
(1991023, 0, 0, 0, 0), -- Heirloom Legs Cache - Evasion
(1991024, 0, 0, 0, 0), -- Heirloom Legs Cache - Haste
(1991025, 0, 0, 0, 0), -- Heirloom Shoulders Cache - DPS (MISSING GAMEOBJECT TEMPLATE!)
(1991026, 0, 0, 0, 0), -- Heirloom Shoulders Cache - Physical
(1991027, 0, 0, 0, 0), -- Heirloom Shoulders Cache - Caster
(1991028, 0, 0, 0, 0), -- Heirloom Waist Cache - Physical
(1991029, 0, 0, 0, 0), -- Heirloom Waist Cache - DPS
(1991030, 0, 0, 0, 0), -- Heirloom Waist Cache - Caster
(1991031, 0, 0, 0, 0), -- Heirloom Feet Cache - Physical
(1991032, 0, 0, 0, 0), -- Heirloom Hands Cache - Tank
(1991033, 0, 0, 0, 0); -- Heirloom Wrists Cache - Haste

-- Add missing gameobject_template for entry 1991025 (referenced in loot table but missing from gameobject_template)
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) 
VALUES (1991025, 3, 7507, 'Heirloom Shoulders Cache - DPS', '', 'Opening', '', 1, 0, 1991025, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 12340);

-- Note: After applying this SQL, you need to:
-- 1. Reload the worldserver (.server reload gameobject_template OR restart worldserver)
-- 2. Respawn any existing gameobjects (.gobject reload <guid> OR .gobject delete + spawn again)
-- 3. If using NPC/script to spawn these, make sure the spawn code is correct
