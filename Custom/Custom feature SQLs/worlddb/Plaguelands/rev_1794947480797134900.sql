-- DarkChaos: 42 range-triggered casts of creatures on map 751 had the range copied into the repeat fields
-- (`event_param3` / `event_param4` = 0-5, 0-10, 8-20 ... milliseconds), so the creature repeated the cast with
-- no cooldown for as long as its target stood in range: Shock from the Thundering Exile, Encasing Webs from
-- the Plains Creepers, Frost Nova, Deafening Screech, Intimidating Roar. The Thundering Exile cost a level
-- 145 character 4% of its health per second, four times its neighbours. The range itself is in
-- `event_param5` / `event_param6` and stays as it is. 28 cooldowns come from the stock creature's row for the
-- same spell; the 14 marked 'no source' had none and take 12-18 seconds, the middle of the recovered ones.
-- Vile Fin Tidehunter, spell 78542
UPDATE `smart_scripts` SET `event_param3` = 16000, `event_param4` = 19000
WHERE `source_type` = 0 AND `entryorguid` = 4101768 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 78542;
-- Skitterweb Striker, spell 87081
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 14000
WHERE `source_type` = 0 AND `entryorguid` = 4101780 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 87081;
-- High Executor Darthalia, spell 9080
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 15000
WHERE `source_type` = 0 AND `entryorguid` = 4102215 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 9080;
-- High Executor Darthalia, spell 15496
UPDATE `smart_scripts` SET `event_param3` = 9000, `event_param4` = 12000
WHERE `source_type` = 0 AND `entryorguid` = 4102215 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 15496;
-- Giant Yeti, spell 3131
UPDATE `smart_scripts` SET `event_param3` = 10800, `event_param4` = 20500
WHERE `source_type` = 0 AND `entryorguid` = 4102251 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 3131;
-- Maggarrak, spell 5568
UPDATE `smart_scripts` SET `event_param3` = 5900, `event_param4` = 28500
WHERE `source_type` = 0 AND `entryorguid` = 4102258 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 5568;
-- Dun Garok Mountaineer, spell 13953
UPDATE `smart_scripts` SET `event_param3` = 9000, `event_param4` = 15000
WHERE `source_type` = 0 AND `entryorguid` = 4102344 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 13953;
-- Daggerspine Screamer, spell 3589
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 16000
WHERE `source_type` = 0 AND `entryorguid` = 4102370 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 3589;
-- Crushridge Plunderer, spell 15496
UPDATE `smart_scripts` SET `event_param3` = 7900, `event_param4` = 16200
WHERE `source_type` = 0 AND `entryorguid` = 4102416 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 15496;
-- Skhowl, spell 16508, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4102452 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 16508;
-- Plains Creeper, spell 4962
UPDATE `smart_scripts` SET `event_param3` = 16000, `event_param4` = 39700
WHERE `source_type` = 0 AND `entryorguid` = 4102563 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 4962;
-- Giant Plains Creeper, spell 4962
UPDATE `smart_scripts` SET `event_param3` = 19000, `event_param4` = 38400
WHERE `source_type` = 0 AND `entryorguid` = 4102565 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 4962;
-- Boulderfist Brute, spell 84709, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4102566 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 84709;
-- Boulderfist Magus, spell 11831, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4102567 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 11831;
-- Hammerfall Guardian, spell 12169, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4102621 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 12169;
-- Vilebranch Headhunter, spell 7357
UPDATE `smart_scripts` SET `event_param3` = 15000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4102641 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 7357;
-- Thundering Exile, spell 11824
UPDATE `smart_scripts` SET `event_param3` = 18900, `event_param4` = 25400
WHERE `source_type` = 0 AND `entryorguid` = 4102762 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 11824;
-- Or'Kalar, spell 92072, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4102773 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 92072;
-- Or'Kalar, spell 84709, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4102773 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 84709;
-- Vilebranch Warrior, spell 11976
UPDATE `smart_scripts` SET `event_param3` = 5000, `event_param4` = 9000
WHERE `source_type` = 0 AND `entryorguid` = 4104465 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 11976;
-- Wildhammer Sentry, spell 8078
UPDATE `smart_scripts` SET `event_param3` = 18000, `event_param4` = 22000
WHERE `source_type` = 0 AND `entryorguid` = 4107865 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 8078;
-- Wildhammer Sentry, spell 11971
UPDATE `smart_scripts` SET `event_param3` = 9000, `event_param4` = 12000
WHERE `source_type` = 0 AND `entryorguid` = 4107865 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 11971;
-- Deathguard Elite, spell 9080, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4107980 AND `id` = 3 AND `event_type` = 9 AND `action_param1` = 9080;
-- Old Cliff Jumper, spell 3604
UPDATE `smart_scripts` SET `event_param3` = 20000, `event_param4` = 25000
WHERE `source_type` = 0 AND `entryorguid` = 4108211 AND `id` = 4 AND `event_type` = 9 AND `action_param1` = 3604;
-- Grimungous, spell 11876
UPDATE `smart_scripts` SET `event_param3` = 14000, `event_param4` = 15000
WHERE `source_type` = 0 AND `entryorguid` = 4108215 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 11876;
-- Gorefang, spell 13443
UPDATE `smart_scripts` SET `event_param3` = 13000, `event_param4` = 15500
WHERE `source_type` = 0 AND `entryorguid` = 4112431 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 13443;
-- Krethis the Shadowspinner, spell 12023
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 14500
WHERE `source_type` = 0 AND `entryorguid` = 4112433 AND `id` = 3 AND `event_type` = 9 AND `action_param1` = 12023;
-- Gan'dranda, spell 9080
UPDATE `smart_scripts` SET `event_param3` = 7000, `event_param4` = 16000
WHERE `source_type` = 0 AND `entryorguid` = 4142609 AND `id` = 3 AND `event_type` = 9 AND `action_param1` = 9080;
-- Thornar Thunderclash, spell 81140
UPDATE `smart_scripts` SET `event_param3` = 15000, `event_param4` = 15500
WHERE `source_type` = 0 AND `entryorguid` = 4142610 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 81140;
-- Bloodfang Scavenger, spell 78509, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4144547 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 78509;
-- Bloodfang Scavenger, spell 78509, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4144549 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 78509;
-- Dark Ranger, spell 22910
UPDATE `smart_scripts` SET `event_param3` = 66000, `event_param4` = 67000
WHERE `source_type` = 0 AND `entryorguid` = 4144632 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 22910;
-- Arcane Remnant, spell 22938, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4145728 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 22938;
-- Inconspicuous Bear, spell 87187
UPDATE `smart_scripts` SET `event_param3` = 15000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4145750 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 87187;
-- Abomination, spell 50335
UPDATE `smart_scripts` SET `event_param3` = 17000, `event_param4` = 19000
WHERE `source_type` = 0 AND `entryorguid` = 4146058 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 50335;
-- Vile Fin Tidehunter, spell 78542
UPDATE `smart_scripts` SET `event_param3` = 16000, `event_param4` = 19000
WHERE `source_type` = 0 AND `entryorguid` = 4146574 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 78542;
-- Nightlash, spell 3485
UPDATE `smart_scripts` SET `event_param3` = 17000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4146981 AND `id` = 1 AND `event_type` = 9 AND `action_param1` = 3485;
-- Aquarius the Unbound, spell 79850
UPDATE `smart_scripts` SET `event_param3` = 13600, `event_param4` = 14500
WHERE `source_type` = 0 AND `entryorguid` = 4147009 AND `id` = 2 AND `event_type` = 9 AND `action_param1` = 79850;
-- Yetimus the Yeti Lord, spell 88533, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4147484 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 88533;
-- Magistrate Burnside, spell 11969, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4147790 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 11969;
-- Stormpike Ram Rider, spell 15284, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4148483 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 15284;
-- SI:7 Operative, spell 79851, no source
UPDATE `smart_scripts` SET `event_param3` = 12000, `event_param4` = 18000
WHERE `source_type` = 0 AND `entryorguid` = 4148741 AND `id` = 0 AND `event_type` = 9 AND `action_param1` = 79851;
