-- Hyjal Frontier - extended quest chains and quest loot items
--
-- Adds 12 new quests (6 Alliance / 6 Horde) in three two-quest chains per
-- faction.  Each chain investigates a different layer of the zone's threat,
-- rewards a weapon or trinket from the 07b catalog, and introduces lore
-- items that drop from the relevant hostile mobs.
--
-- Quest IDs  : 81235-81242 (Alliance), 81250-81257 (Horde)
-- Quest items: 400448-400452, 400455 (class=12, lootable from zone mobs)
-- Weapon rewards come from 07b entries already in item_template.
-- Trinket rewards come from 07b entries already in item_template.
--
-- Quest → reward → lore summary:
--  Alliance chain A "The Remnant Command"  (req 80-86, Foothills)
--    81235  Bone and Ash           kills + quest crest drop → T1 trinket reward
--    81236  Dead Man's Orders      folio drop               → T1 weapon reward
--    81237  Report to the Keeper   delivery                 → XP + coin
--  Alliance chain B "The Price of Green Fire" (req 95-100, Scorched Groves)
--    81238  Ash Won't Hold         seedpod drop             → T2 trinket reward
--    81239  Demons at the Root     kills                    → T2 weapon reward
--    81240  Carry the Seed North   delivery                 → Emberwood Sap tokens
--  Alliance chain C "What the Summit Keeps" (req 110-115, Summit/Nordrassil)
--    81241  Stone Wings, Cold Eyes kills + shard drop       → T3 trinket reward
--    81242  The Elune-Touched Memory shard turn-in          → T3 weapon reward
--
--  Horde chain A "Blood on Ancient Ground" (req 80-86, Foothills)
--    81250  No Peace for the Dead  kills + crest drop       → T1 trinket reward
--    81251  The Necromancer's Map  folio drop               → T1 weapon reward
--    81252  Report to Zorok        delivery                 → XP + coin
--  Horde chain B "Felblight" (req 95-100, Scorched Groves)
--    81253  Stalk the Stalkers     kills + seedpod drop     → T2 trinket reward
--    81254  The Guard's Last Trick crystal drop             → T2 weapon reward
--    81255  Deliver to Gromtar     delivery                 → Emberwood Sap tokens
--  Horde chain C "The Summit Speaks" (req 110-115, Summit/Nordrassil)
--    81256  Silence the Sky        kills + shard drop       → T3 trinket reward
--    81257  The Root-Bound Memory  colossus drop            → T3 weapon reward

-- =============================================================================
-- Quest items (class=12, lootable from zone mobs)
-- =============================================================================
DELETE FROM `item_template` WHERE `entry` IN (400448, 400449, 400450, 400451, 400452, 400455);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,
     `Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,
     `InventoryType`,`AllowableClass`,`AllowableRace`,
     `maxcount`,`stackable`,`bonding`,`description`,`VerifiedBuild`)
VALUES
(400448, 12, 0, -1, 'Scourge Battle Crest', 54562,
    1, 0, 0, 1, 0, 0, 0, -1, -1, 0, 20, 4,
    'A rusted battle crest still carried by Scourge remnants in the Foothills.', 0),
(400449, 12, 0, -1, 'Necromancer''s Field Folio', 58834,
    1, 0, 0, 1, 0, 0, 0, -1, -1, 0, 5, 4,
    'A folded field record recovered from a Blightbone Necromancer. Contains patrol routes and command sigils.', 0),
(400450, 12, 0, -1, 'Fel-Scorched Seedpod', 24689,
    1, 0, 0, 1, 0, 0, 0, -1, -1, 0, 20, 4,
    'A Hyjal seedpod partially corrupted by felfire. The druids can still purify it.', 0),
(400451, 12, 0, -1, 'Shadow Shard', 37755,
    1, 0, 0, 1, 0, 0, 0, -1, -1, 0, 10, 4,
    'A crystallised fragment of shadow-memory carried by a Crypt Fiend. It still hums with the echoes of Hyjal''s darkest hour.', 0),
(400452, 12, 0, -1, 'Demonic Focusing Crystal', 37755,
    1, 0, 0, 1, 0, 0, 0, -1, -1, 0, 20, 4,
    'A shard of demonic crystal removed from an Infernal Siegebreaker. It is warm to the touch and smells of sulfur.', 0),
(400455, 12, 0, -1, 'Root-Bound Memory', 37755,
    1, 0, 0, 1, 0, 0, 0, -1, -1, 0, 10, 4,
    'A node of corrupted bark torn from a Rootbound Colossus. Archdruid Rhydel says the memory of the tree is still inside.', 0);

UPDATE `item_template` SET `material`=-1 WHERE `entry` IN (400448, 400449, 400450, 400451, 400452, 400455);

-- Item.csv entries for quest items (client display - no model needed for bag icons)
-- (These entries are appended to Item.csv by a separate DBC step; the displayid
-- values above reference verified ItemDisplayInfo entries.)

-- =============================================================================
-- Quest item loot (added to existing creature_loot_template entries)
-- =============================================================================
-- Scourge Battle Crest from Charred Ghouls (quest 81235 / 81250) - 55% drop rate
DELETE FROM `creature_loot_template` WHERE `Entry`=830040 AND `Item`=400448;
INSERT INTO `creature_loot_template` VALUES (830040,400448,0,55,1,1,0,1,1,'Scourge Battle Crest quest item');

-- Necromancer''s Folio from Blightbone Necromancers (quest 81236 / 81251) - 60%
DELETE FROM `creature_loot_template` WHERE `Entry`=830042 AND `Item`=400449;
INSERT INTO `creature_loot_template` VALUES (830042,400449,0,60,1,1,0,1,1,'Necromancer Folio quest item');

-- Fel-Scorched Seedpod from Felfire Stalkers (quest 81238 / 81253) - 50%
DELETE FROM `creature_loot_template` WHERE `Entry`=830050 AND `Item`=400450;
INSERT INTO `creature_loot_template` VALUES (830050,400450,0,50,1,1,0,1,1,'Fel Seedpod quest item');

-- Demonic Crystal from Infernal Siegebreakers (quest 81254) - 55%
DELETE FROM `creature_loot_template` WHERE `Entry`=830052 AND `Item`=400452;
INSERT INTO `creature_loot_template` VALUES (830052,400452,0,55,1,1,0,1,1,'Demonic Crystal quest item');

-- Shadow Shard from Shadow Crypt Fiends (quest 81241 / 81256) - 55%
DELETE FROM `creature_loot_template` WHERE `Entry`=830061 AND `Item`=400451;
INSERT INTO `creature_loot_template` VALUES (830061,400451,0,55,1,1,0,1,1,'Shadow Shard quest item');

-- Root-Bound Memory from Rootbound Colossi (quest 81257) - 60%
DELETE FROM `creature_loot_template` WHERE `Entry`=830097 AND `Item`=400455;
INSERT INTO `creature_loot_template` VALUES (830097,400455,0,60,1,1,0,1,1,'Root-Bound Memory quest item');

-- =============================================================================
-- Quest templates
-- =============================================================================
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 81235 AND 81257;
DELETE FROM `creature_questender`   WHERE `quest` BETWEEN 81235 AND 81257;
DELETE FROM `quest_request_items`   WHERE `ID`    BETWEEN 81235 AND 81257;
DELETE FROM `quest_offer_reward`    WHERE `ID`    BETWEEN 81235 AND 81257;
DELETE FROM `quest_template_addon`  WHERE `ID`    BETWEEN 81235 AND 81257;
DELETE FROM `quest_template`        WHERE `ID`    BETWEEN 81235 AND 81257;

INSERT INTO `quest_template`
    (`ID`,`QuestType`,`QuestLevel`,`MinLevel`,`QuestSortID`,
     `QuestInfoID`,`RewardXPDifficulty`,`RewardMoney`,`AllowableRaces`,
     `LogTitle`,`LogDescription`,`QuestDescription`,`AreaDescription`,
     `QuestCompletionLog`,
     `RequiredNpcOrGo1`,`RequiredNpcOrGoCount1`,
     `RequiredNpcOrGo2`,`RequiredNpcOrGoCount2`,
     `RequiredItemId1`,`RequiredItemCount1`,
     `RewardChoiceItemID1`,`RewardChoiceItemQuantity1`,
     `RewardChoiceItemID2`,`RewardChoiceItemQuantity2`,
     `RewardChoiceItemID3`,`RewardChoiceItemQuantity3`,
     `RewardChoiceItemID4`,`RewardChoiceItemQuantity4`,
     `RewardChoiceItemID5`,`RewardChoiceItemQuantity5`,
     `ObjectiveText1`,`ObjectiveText2`,`VerifiedBuild`)
VALUES
-- ─────────────────────────────────────────────────────────────────────────────
-- ALLIANCE CHAIN A: The Remnant Command
-- ─────────────────────────────────────────────────────────────────────────────
(81235, 2, 80, 80, 6100, 0, 5, 0, 1101,
 'A: Bone and Ash',
 'Commander Elowen wants proof that the Scourge presence in the Foothills is organised, not just residual drift.',
 'The dead here carry their battle crests from the Third War. They kept them because someone told them to. Kill a patrol of Charred Ghouls and bring me eight of those crests. I want to see exactly whose mark they bear.',
 'Foothills patrol routes south of Jaina''s Encampment.',
 'The crests are old, but the command sigils on them are not. Someone reactivated them recently.',
 830040, 8, 0, 0, 400448, 8,
 400884, 1, 400885, 1, 400886, 1, 400887, 1, 400888, 1,
 'Charred Ghouls slain', 'Scourge Battle Crests collected', 0),

(81236, 2, 84, 80, 6100, 0, 5, 0, 1101,
 'A: Dead Man''s Orders',
 'The battle crests from the Charred Ghouls confirm that an independent command structure is directing the Foothills Scourge.',
 'Those necromancers you have been cutting through are not freelancers. They carry field folios — written routing orders that let them operate without the Lich King''s direct will. Get five of those folios before they burn them.',
 'Blightbone Necromancer patrol circuits through the Foothills ash line.',
 'The folios spell it out. Someone established a ghost command before the Lich King fell and left it running.',
 830042, 8, 0, 0, 400449, 5,
 400824, 1, 400826, 1, 400827, 1, 400829, 1, 400831, 1,
 'Blightbone Necromancers slain', 'Necromancer''s Field Folios collected', 0),

(81237, 2, 86, 84, 6100, 0, 4, 50000, 1101,
 'A: Report to the Keeper',
 'Bring the Necromancer''s Field Folios to Keeper Elunor in the Scorched Groves.',
 'Keeper Elunor understands the old command structures of Archimonde''s invasion better than anyone alive. She needs to read these before we push further into the zone. Find her in the Scorched Groves.',
 'Scorched Groves field post, northeast ridge.',
 'Elunor has the information. The real threat is deeper than the Foothills.',
 830032, 1, 0, 0, 0, 0,
 0,0, 0,0, 0,0, 0,0, 0,0,
 'Report to Keeper Elunor', '', 0),

-- ─────────────────────────────────────────────────────────────────────────────
-- ALLIANCE CHAIN B: The Price of Green Fire
-- ─────────────────────────────────────────────────────────────────────────────
(81238, 2, 95, 93, 6100, 0, 6, 0, 1101,
 'A: Ash Won''t Hold',
 'Keeper Elunor needs Hyjal seedpods recovered from the demon-afflicted stalkers before they are lost to the fire.',
 'Felfire Stalkers spread fel-taint through every grove they pass through. As they move, they scatter seedpods from the trees they ignite. Those seeds are still viable if we can recover them before the fel energy fully corrupts them. Bring me ten.',
 'Scorched Groves, between the fel patrol lines.',
 'Ten seeds. A small start, but Nordrassil grew from one.',
 830050, 10, 0, 0, 400450, 10,
 400890, 1, 400891, 1, 400892, 1, 400893, 1, 400894, 1,
 'Felfire Stalkers slain', 'Fel-Scorched Seedpods collected', 0),

(81239, 2, 98, 95, 6100, 0, 6, 0, 1101,
 'A: Demons at the Root',
 'The felfire is sustained by Searing Doomguard patrols forming an anchor chain through the Scorched Groves.',
 'Take away the demons and the felfire loses its focus. The Searing Doomguards are the anchor — they keep the flames tied to the ley lines running under the grove. Destroy five of their patrols. After that, the fire will burn itself out.',
 'Scorched Groves demon patrol route.',
 'The anchor chain is broken. The grove can start to breathe again.',
 830051, 5, 0, 0, 0, 0,
 400839, 1, 400840, 1, 400842, 1, 400844, 1, 400845, 1,
 'Searing Doomguards slain', '', 0),

(81240, 2, 100, 98, 6100, 0, 4, 0, 1101,
 'A: Carry the Seed North',
 'Deliver the Fel-Scorched Seedpods to Warden Starfall at the Summit.',
 'The druid circle at the Summit has a purification ritual ready. They have been waiting for viable seeds to work with. Take the seedpods north before the fel taint finishes what the fire started.',
 'The Summit, Warden Starfall''s position.',
 'Starfall receives the seeds. The ritual begins.',
 830033, 1, 0, 0, 400450, 10,
 0,0, 0,0, 0,0, 0,0, 0,0,
 'Deliver seeds to Warden Starfall', '', 0),

-- ─────────────────────────────────────────────────────────────────────────────
-- ALLIANCE CHAIN C: What the Summit Keeps
-- ─────────────────────────────────────────────────────────────────────────────
(81241, 2, 110, 108, 6100, 0, 7, 0, 1101,
 'A: Stone Wings, Cold Eyes',
 'Warden Starfall asks for the silence of the gargoyle watch-posts and the recovery of shadow-shards from the Crypt Fiends.',
 'Hyjal''s watchtower gargoyles were carved as guardian spirits. What turned them I cannot say — but they no longer guard us. Cut down eight of them and take five shadow-shards from the Crypt Fiends below the ridge. Those shards carry memory. I want to know what they remember.',
 'The Summit ridge-line and the crypt approaches below.',
 'The sky is quiet. The shards are in your hands now.',
 830060, 8, 830061, 5, 400451, 5,
 400896, 1, 400897, 1, 400898, 1, 400899, 1, 400900, 1,
 'Summit Gargoyles slain', 'Shadow Shards collected', 0),

(81242, 2, 115, 110, 6100, 0, 7, 0, 1101,
 'A: The Elune-Touched Memory',
 'Archdruid Rhydel can read the shadow-shards recovered from the Crypt Fiends. Bring them to him at Nordrassil.',
 'Elune''s light can draw the truth out of those shadow-shards — but only if the reading is done at Nordrassil''s roots where her moonwell is still clean. Bring the shards to Archdruid Rhydel. He will know what to do.',
 'Nordrassil Roots, Archdruid Rhydel''s position.',
 'The shards show what Nordrassil endured. And what still watches from below.',
 830034, 1, 0, 0, 400451, 5,
 400854, 1, 400855, 1, 400856, 1, 400857, 1, 400858, 1,
 'Deliver Shadow Shards to Archdruid Rhydel', '', 0),

-- ─────────────────────────────────────────────────────────────────────────────
-- HORDE CHAIN A: Blood on Ancient Ground
-- ─────────────────────────────────────────────────────────────────────────────
(81250, 2, 80, 80, 6100, 0, 5, 0, 690,
 'H: No Peace for the Dead',
 'Warmaster Kargra orders you to demonstrate the scale of the Scourge threat in the Foothills.',
 'The dead walk here in numbers that should not be possible without direction. Prove the scale to me. Kill eight Charred Ghouls, silence four of the Banshees, and bring back eight of the battle crests the ghouls still carry. I want evidence, not stories.',
 'Foothills patrol lines south and east of Thrall''s Vanguard.',
 'The crests carry old war-markings. Someone lit the fire under them again.',
 830040, 8, 830041, 4, 400448, 8,
 400884, 1, 400885, 1, 400886, 1, 400887, 1, 400888, 1,
 'Charred Ghouls and Ashen Banshees slain', 'Scourge Battle Crests collected', 0),

(81251, 2, 84, 80, 6100, 0, 5, 0, 690,
 'H: The Necromancer''s Map',
 'The Blightbone Necromancers carry field maps showing command routes that should not exist.',
 'I have watched those necromancers during lulls in the fighting. They reference something between rituals — a map or a folio. That is a command document. Rip five of them from the necromancers and bring them here. I want to know what orders they are still following.',
 'Blightbone Necromancer positions in the Foothills ash belt.',
 'Five folios, five sets of orders. The command cell is larger than we thought.',
 830042, 8, 0, 0, 400449, 5,
 400824, 1, 400826, 1, 400827, 1, 400829, 1, 400831, 1,
 'Blightbone Necromancers slain', 'Necromancer''s Field Folios collected', 0),

(81252, 2, 86, 84, 6100, 0, 4, 50000, 690,
 'H: Report to Zorok',
 'Bring the Necromancer''s Field Folios to Spiritcaller Zorok in the Scorched Groves.',
 'Spiritcaller Zorok can read spirit-traces in those command documents. He will know whether the orders came from a living hand or a dead one. Get to the Groves before he moves his position.',
 'Scorched Groves, Spiritcaller Zorok''s field circle.',
 'Zorok reads the spirit-trace. The hand behind the orders is still active.',
 830037, 1, 0, 0, 0, 0,
 0,0, 0,0, 0,0, 0,0, 0,0,
 'Report to Spiritcaller Zorok', '', 0),

-- ─────────────────────────────────────────────────────────────────────────────
-- HORDE CHAIN B: Felblight
-- ─────────────────────────────────────────────────────────────────────────────
(81253, 2, 95, 93, 6100, 0, 6, 0, 690,
 'H: Stalk the Stalkers',
 'Scout Mavak has identified the Felfire Stalkers as the primary vector spreading fel-taint into the Scorched Groves.',
 'Those demon dogs move ahead of the main force and seed the ground with felfire. Without them the advance stalls. Kill ten and recover the seedpods they scatter. Mavak says the pods are still viable and the earthmenders want them. I say kill the demons. Both things can be true.',
 'Scorched Groves, along the demon patrol corridors.',
 'Ten stalkers down, pods in hand.',
 830050, 10, 0, 0, 400450, 10,
 400890, 1, 400891, 1, 400892, 1, 400893, 1, 400894, 1,
 'Felfire Stalkers slain', 'Fel-Scorched Seedpods collected', 0),

(81254, 2, 98, 95, 6100, 0, 6, 0, 690,
 'H: The Guard''s Last Trick',
 'Infernal Siegebreakers carry demonic focusing crystals that sustain the felfire even after the stalker patrols are broken.',
 'Every infernal you see has a focusing crystal slotted into its core. Those crystals are what keep the felfire anchored to the ley lines after we cut down the stalker patrols. Destroy five siegebreakers and pull five crystals from their shattered husks. Without them, the fire dies on its own.',
 'Scorched Groves infernal positions.',
 'Five crystals. The fel anchor is gone.',
 830052, 5, 0, 0, 400452, 5,
 400839, 1, 400840, 1, 400842, 1, 400844, 1, 400845, 1,
 'Infernal Siegebreakers slain', 'Demonic Crystals collected', 0),

(81255, 2, 100, 98, 6100, 0, 4, 0, 690,
 'H: Deliver to Gromtar',
 'Deliver the Demonic Focusing Crystals to Battlelord Gromtar at the Summit.',
 'Gromtar''s artificers can reverse-engineer those crystals into ward-breakers. Get them north before the demons realise what we took from their infernals.',
 'The Summit, Battlelord Gromtar''s warband position.',
 'Gromtar''s artificers receive the crystals. New tools for the summit push.',
 830038, 1, 0, 0, 400452, 5,
 0,0, 0,0, 0,0, 0,0, 0,0,
 'Deliver crystals to Battlelord Gromtar', '', 0),

-- ─────────────────────────────────────────────────────────────────────────────
-- HORDE CHAIN C: The Summit Speaks
-- ─────────────────────────────────────────────────────────────────────────────
(81256, 2, 110, 108, 6100, 0, 7, 0, 690,
 'H: Silence the Sky',
 'Battlelord Gromtar orders the gargoyle watchtowers cleared and the Crypt Fiend shadow-shards recovered.',
 'The summit gargoyles sit on every commanding height in this zone. Whatever turned them is using them to watch us. Bring them down — all eight of the ridge-line sentinels. And those Crypt Fiends below them carry shadow-shards from the Third War. Five shards. Bring me five. Earthwarden Toran says they hold memory. I say they hold intelligence.',
 'The Summit ridge-line and the crypt approaches.',
 'The sky belongs to us again. Briefly.',
 830060, 8, 830061, 5, 400451, 5,
 400896, 1, 400897, 1, 400898, 1, 400899, 1, 400900, 1,
 'Summit Gargoyles slain', 'Shadow Shards collected', 0),

(81257, 2, 115, 110, 6100, 0, 7, 0, 690,
 'H: The Root-Bound Memory',
 'Earthwarden Toran wants Root-Bound Memories recovered from the Rootbound Colossi and brought to Nordrassil.',
 'The Rootbound Colossi trapped in the lower roots are carrying fragments of Nordrassil''s memory — nodes of bark pulled into the corruption when the tree was first attacked in the Third War. Earthwarden Toran says those nodes contain warnings. Get six of them and take them to him at Nordrassil''s edge.',
 'Nordrassil lower roots.',
 'The memories are delivered. Toran listens to the tree. The tree has a great deal to say.',
 830097, 12, 0, 0, 400455, 6,
 400854, 1, 400855, 1, 400856, 1, 400857, 1, 400858, 1,
 'Rootbound Colossi slain', 'Root-Bound Memories collected', 0);

-- =============================================================================
-- Quest addon chains
-- =============================================================================
INSERT INTO `quest_template_addon`
    (`ID`,`PrevQuestID`,`NextQuestID`,`SpecialFlags`)
VALUES
-- Alliance chains
(81235, 0,     81236, 0),(81236, 81235, 81237, 0),(81237, 81236, 0,     0),
(81238, 0,     81239, 0),(81239, 81238, 81240, 0),(81240, 81239, 0,     0),
(81241, 0,     81242, 0),(81242, 81241, 0,     0),
-- Horde chains
(81250, 0,     81251, 0),(81251, 81250, 81252, 0),(81252, 81251, 0,     0),
(81253, 0,     81254, 0),(81254, 81253, 81255, 0),(81255, 81254, 0,     0),
(81256, 0,     81257, 0),(81257, 81256, 0,     0);

-- =============================================================================
-- Quest request items (in-progress text shown at the giver while incomplete)
-- =============================================================================
INSERT INTO `quest_request_items`
    (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`)
VALUES
(81235, 6, 0, 'Eight crests. Every ghoul carries one.', 0),
(81236, 6, 0, 'Those folios are field orders. Do not lose them.', 0),
(81237, 6, 0, 'Keeper Elunor is in the Scorched Groves. She is expecting someone.', 0),
(81238, 6, 0, 'Ten seedpods. The stalkers scatter them as they burn.', 0),
(81239, 6, 0, 'Five doomguard patrols. Each one anchors a felfire line.', 0),
(81240, 6, 0, 'Starfall is at the summit ridge. She has been waiting for these.', 0),
(81241, 6, 0, 'Eight gargoyles, five shards. The ridge must be cleared.', 0),
(81242, 6, 0, 'Archdruid Rhydel is at Nordrassil''s edge. He will do the reading.', 0),
(81250, 6, 0, 'Crests and ghouls. Both need dealing with.', 0),
(81251, 6, 0, 'The necromancers carry field maps. I want them.', 0),
(81252, 6, 0, 'Zorok is in the Groves. He reads spirit-traces in documents.', 0),
(81253, 6, 0, 'Ten stalkers. The seedpods come with them.', 0),
(81254, 6, 0, 'Five siegebreakers, five crystals. Smash them and take what''s inside.', 0),
(81255, 6, 0, 'Gromtar is at the Summit. His artificers need those crystals now.', 0),
(81256, 6, 0, 'Eight gargoyles off the ridge-line. Five shards from the crypt fiends.', 0),
(81257, 6, 0, 'Twelve colossi, six memories. Toran is waiting at Nordrassil''s edge.', 0);

-- =============================================================================
-- Quest offer reward (completion reward text)
-- =============================================================================
INSERT INTO `quest_offer_reward`
    (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,
     `EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,
     `RewardText`,`VerifiedBuild`)
VALUES
(81235,0,0,0,0,0,0,0,0,'These crests have been reissued. Someone remobilised the Scourge long after the war ended. That is alarming.',0),
(81236,0,0,0,0,0,0,0,0,'Independent command orders, active and updated within the last month. The threat here is more organised than we feared.',0),
(81237,0,0,0,0,0,0,0,0,'I have read the folios. The chain of command leads somewhere deeper in the zone. We will follow it.',0),
(81238,0,0,0,0,0,0,0,0,'Ten seeds from a burning grove. The fact that any survived is already a small miracle.',0),
(81239,0,0,0,0,0,0,0,0,'The felfire is fading. You cut the anchor and gave the grove a chance. Now we have to keep it.',0),
(81240,0,0,0,0,0,0,0,0,'The seeds are here. The ritual can begin. Nordrassil will know that someone is still fighting for it.',0),
(81241,0,0,0,0,0,0,0,0,'The ridge is quiet. The shards are cold now — the memory is locked inside them, waiting to be read.',0),
(81242,0,0,0,0,0,0,0,0,'The reading is done. The shards showed the fall and the sealing. And something that was not sealed properly.',0),
(81250,0,0,0,0,0,0,0,0,'Eight crests, all reissued. The Scourge here have a commander and a purpose. Find them both.',0),
(81251,0,0,0,0,0,0,0,0,'Command orders written in a hand that matches no known Lich King scribe. Someone else is running this cell.',0),
(81252,0,0,0,0,0,0,0,0,'Zorok says the spirit-trace on these documents comes from something still living. That narrows the hunt.',0),
(81253,0,0,0,0,0,0,0,0,'Ten down. The grove will fight its own fires now. Bring those pods north.',0),
(81254,0,0,0,0,0,0,0,0,'Five crystals out of five infernals. The fel anchor is gone. The fire will lose its grip.',0),
(81255,0,0,0,0,0,0,0,0,'Gromtar''s artificers are already working. Those crystals will crack demon wards before the week is out.',0),
(81256,0,0,0,0,0,0,0,0,'The sky belongs to us. Now the shards. Toran will know what to do with them.',0),
(81257,0,0,0,0,0,0,0,0,'The memories are delivered. Nordrassil spoke plainly to Toran. A sealed evil below the roots was never properly finished. It ends now.',0);

-- =============================================================================
-- Quest starters and enders
-- =============================================================================
INSERT INTO `creature_queststarter` (`id`,`quest`) VALUES
-- Alliance chains (offered by quest givers + both factions share some chains)
(830030, 81235),(830031, 81236),(830031, 81237),
(830031, 81238),(830032, 81239),(830032, 81240),
(830033, 81241),(830034, 81242),
-- Horde chains
(830035, 81250),(830036, 81251),(830037, 81252),
(830037, 81253),(830037, 81254),(830038, 81255),
(830038, 81256),(830039, 81257);

INSERT INTO `creature_questender` (`id`,`quest`) VALUES
-- Alliance
(830031, 81235),(830031, 81236),(830032, 81237),
(830032, 81238),(830033, 81239),(830033, 81240),
(830034, 81241),(830034, 81242),
-- Horde
(830036, 81250),(830037, 81251),(830037, 81252),
(830037, 81253),(830038, 81254),(830038, 81255),
(830039, 81256),(830039, 81257);
