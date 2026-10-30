-- Isles of Giants: weapons in hand. An addon row with bytes2 = 0 leaves a creature at sheath state unarmed, because the core
-- only sets the melee default when there is no addon row. The Mists of Pandaria Zandalari model has no back or hip
-- attachment, so a sheathed weapon does not show at all and these spawns would stand empty-handed.
UPDATE `creature_template_addon` SET `bytes2` = 1 WHERE `entry` IN (400270, 400271, 400272, 400275, 400276, 400326, 400327, 400328, 400329, 400330, 400331, 400332, 400333, 400334, 400336, 400337, 400338);
UPDATE `creature_addon` SET `bytes2` = 1 WHERE `guid` IN (9000258, 9000299, 9000416, 9000418, 9000424, 9000425, 9000426, 9000427, 9001621);
