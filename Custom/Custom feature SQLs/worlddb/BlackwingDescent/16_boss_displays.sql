-- BWD boss creature_model_info (base bounding_radius/combat_reach; AC scales both by the model scale).
-- Display ids keep the Cata ids that creature_template_model already references (no repoint).
-- 7 M2s baked from K:\Cata in the asset pipeline (see PORT_NOTES); Finkle 33716 reuses the stock gnome.
-- Values are Cata-CMD-derived (CollisionWidth/Height); the M2 bake refines them.

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (32569,32679,32684,32685,32687,32688,32716,33186,33308,33716,34547);
INSERT INTO `creature_model_info` (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`) VALUES
    (32569, 0.6111, 1.5, 2, 0, 0),  -- Onyxia
    (32679, 0.6111, 1.5, 2, 0, 0),  -- Magmaw
    (32684, 0.6112, 1.5, 2, 0, 0),  -- Toxitron
    (32685, 0.6112, 1.5, 2, 0, 0),  -- Magmatron
    (32687, 0.6112, 1.5, 2, 0, 0),  -- Arcanotron
    (32688, 0.6112, 1.5, 2, 0, 0),  -- Electron
    (32716, 0.6111, 1.5, 2, 0, 0),  -- Nefarian
    (33186, 0.6112, 1.5, 2, 0, 0),  -- Maloriak
    (33308, 0.6112, 1.5, 2, 0, 0),  -- Chimaeron
    (33716, 0.6944, 1.5, 2, 0, 0),  -- Finkle
    (34547, 0.6111, 1.5, 2, 0, 0);  -- Atramedes

-- Heroic Atramedes (43407) shipped Cata display 399 (a placeholder); use the real Atramedes display.
UPDATE `creature_template_model` SET `CreatureDisplayID` = 34547 WHERE `CreatureID` = 43407 AND `CreatureDisplayID` = 399;
