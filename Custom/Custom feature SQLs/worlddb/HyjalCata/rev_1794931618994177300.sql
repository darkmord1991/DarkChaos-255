-- DarkChaos: Fiery Minion is the add a Twilight Scorchlord summons in Hyjal (map 750). Its template still has
-- the modifiers of a level 81 creature (health 2.61816, damage 2.90793), but it is summoned at its summoner's
-- level 116, where they give it 165,779 health: 3.4 times a normal mob there, a 39 second kill in every fight
-- with a Scorchlord. The Cataclysm source gives it 0.35 of a normal mob's health and the same damage modifier
-- as its neighbours. It now takes 0.35 of the level 116 value its warrior-class neighbours use (0.770888) and
-- their damage modifier, which is 17,072 health at level 116.
UPDATE `creature_template` SET `HealthModifier` = 0.269811, `DamageModifier` = 1.16406 WHERE `entry` = 3641501;
