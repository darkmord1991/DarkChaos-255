-- Castle Nathria (map 2296) -- loot supplement from retail journal data (12).
-- The SL source dumps had NO loot rows for 4 of the 10 encounters (Huntsman Altimor,
-- Hungering Destroyer, Sun King's Salvation, Lady Inerva Darkvein) -- confirmed source gap,
-- not a transcode error. This file fills those from retail JournalEncounterItem (12.0.7,
-- instance 1190), filtered to the 72 already-downported gear items (SL borrowed-power items
-- excluded). Same GroupId=1 / chance-summing-to-~100 convention as 10_loot.sql.
--
-- Sun King's Salvation has no lootable boss corpse in retail (you SAVE Kael'thas); its loot
-- comes from the 'Cache of the Sun King' chest (GO 357752, statically spawned for now, lootId
-- Data1=357752 already wired in 06). When the C++ instance script is ported it should despawn
-- the chest until the encounter completes. The 'Spoils of Sin' chest (357751) is left without
-- loot (no journal encounter maps to it; don't invent).
--
-- Apply to acore_world.

-- ---------------------------------------------------------------------------
-- creature_loot_template (corpse loot: Altimor, Hungering Destroyer, Inerva)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` IN (165066,164261,165521);
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (165066, 182995, 0, 16.67, 0, 1, 1, 1, 1, 'Huntsman Altimor - Spell-Woven Tourniquet'),
    (165066, 183040, 0, 16.67, 0, 1, 1, 1, 1, 'Huntsman Altimor - Charm of Eternal Winter'),
    (165066, 182988, 0, 16.67, 0, 1, 1, 1, 1, 'Huntsman Altimor - Master Huntsman''s Bandolier'),
    (165066, 183018, 0, 16.67, 0, 1, 1, 1, 1, 'Huntsman Altimor - Hellhound Cuffs'),
    (165066, 182996, 0, 16.67, 0, 1, 1, 1, 1, 'Huntsman Altimor - Grim Pursuant''s Maille'),
    (165066, 184017, 0, 16.67, 0, 1, 1, 1, 1, 'Huntsman Altimor - Bargast''s Leash'),
    (164261, 183028, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Cinch of Infinite Tightness'),
    (164261, 183009, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Miasma-Lacquered Jerkin'),
    (164261, 183000, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Consumptive Chainmail Carapace'),
    (164261, 183001, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Helm of Insatiable Appetite'),
    (164261, 183024, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Volatile Shadestitch Legguards'),
    (164261, 182992, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Endlessly Gluttonous Greaves'),
    (164261, 182994, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Epaulettes of Overwhelming Force'),
    (164261, 184023, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Gluttonous Spike'),
    (164261, 184022, 0, 11.11, 0, 1, 1, 1, 1, 'Hungering Destroyer - Consumptive Infusion'),
    (165521, 183021, 0, 16.67, 0, 1, 1, 1, 1, 'Lady Inerva Darkvein - Confidant''s Favored Cap'),
    (165521, 183037, 0, 16.67, 0, 1, 1, 1, 1, 'Lady Inerva Darkvein - Ritualist''s Treasured Ring'),
    (165521, 183026, 0, 16.67, 0, 1, 1, 1, 1, 'Lady Inerva Darkvein - Gloves of Phantom Shadows'),
    (165521, 182985, 0, 16.67, 0, 1, 1, 1, 1, 'Lady Inerva Darkvein - Memento-Laden Cuisses'),
    (165521, 183015, 0, 16.67, 0, 1, 1, 1, 1, 'Lady Inerva Darkvein - Binding of Warped Desires'),
    (165521, 184025, 0, 16.67, 0, 1, 1, 1, 1, 'Lady Inerva Darkvein - Memory of Past Sins');

-- ---------------------------------------------------------------------------
-- gameobject_loot_template (Cache of the Sun King, lootId 357752)
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (357752);
INSERT INTO `gameobject_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (357752, 183007, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - Bleakwing Assassin''s Grips'),
    (357752, 183025, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - Stoic Guardsman''s Belt'),
    (357752, 182986, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - High Torturer''s Smock'),
    (357752, 183033, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - Mantle of Manifest Sins'),
    (357752, 182977, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - Bangles of Errant Pride'),
    (357752, 184019, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - Soul Igniter'),
    (357752, 184018, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - Splintered Heart of Al''ar'),
    (357752, 184020, 0, 12.5, 0, 1, 1, 1, 1, 'Cache of the Sun King - Tuft of Smoldering Plumage');
