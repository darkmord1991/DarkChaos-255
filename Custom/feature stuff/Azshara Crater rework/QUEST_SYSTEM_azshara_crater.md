# Azshara Crater - Quest System Design

> [!NOTE]
> Quests do NOT unlock zones/dungeons. Uses existing heirloom gameobjects as special features.

## Quest NPC Templates

### Zone Quest Givers (Zones 4-8)

| Zone | NPC Name | Entry ID | Model | Location |
|------|----------|----------|-------|----------|
| **Zone 4** | Wavemaster Kol'gar | 300030 | Troll Shaman | Central River |
| **Zone 5** | Demonologist Vex'ara | 300040 | Blood Elf Warlock | The Cliffs |
| **Zone 6** | Felsworn Kael'thos | 300050 | Blood Elf Paladin | The Fel Pit |
| **Zone 7** | Dragonbinder Seryth | 300060 | Draenei Mage | Wyrmrest |
| **Zone 8** | Archmage Thadeus | 300070 | Human Mage | The Temple |

### Dungeon Quest Givers (Stationed outside entrances)

| Dungeon | NPC Name | Entry ID | Model | Target |
|---------|----------|----------|-------|--------|
| **D1** | Magister Idona | 300081 | High Elf | Ruins of Zin-Azshari |
| **D2** | Elder Brownpaw | 300082 | Furbolg | Timbermaw Deep |
| **D3** | Prospector Khazgorm | 300083 | Dwarf | Spitelash Depths |
| **D4** | Slayer Vorith | 300084 | Blood Elf DH | The Fel Pit |
| **D5** | Priestess Lunara | 300085 | Night Elf Priest | Temple of Elune |
| **D6** | Image of Arcanigos | 300086 | Human (Blue Dragon) | Sanctum of Highborne |

---

## Quest Examples by Zone

## Quest Examples by Zone

### Zone 1: Valormok Rim (Level 1-10)
*   **Quest Givers:** Scout Thalindra (300001), Warden Stonebrook (300002)
1.  **"Welcome to Crater"**: Speak with Scout Thalindra.
2.  **"Wildlife Survey"**: Kill 6 Boars and 6 Wolves.
3.  **"Bear Bounty"**: Kill 8 Bears.
4.  **"Strange Energies"**: Kill 8 Timberlings.
5.  **"Web of Danger"**: Kill 10 Webwood Lurkers (Spiders).
6.  **"Ancient's Lair"**: Defeat 12 Timberlings (Boss Placeholder).
7.  **"Pelt Collection"**: Collect 8 Light Hides.
8.  **"Murloc Menace"**: Kill 10 Murloc Foragers.
9.  **"Report to North"**: Travel to Zone 2.

### Zone 2: Northern Ruins (Level 10-20)
*   **Quest Givers:** Arcanist Melia (300010), Spirit of Kelvenar (300011)
1.  **"Haunted Grounds"**: Kill 10 Dreadbone Skeletons.
2.  **"Spectral Samples"**: Kill 8 Voidwalkers.
3.  **"Ancient Relics"**: Destroy 8 Harvest Golems.
4.  **"Commune with Spirit"**: Speak with Spirit of Kelvenar.
5.  **"The Wailing Noble"**: Defeat 12 Skeletal Warriors.
6.  **"Varo'then's Journal"**: Retrieve Journal from ruins.
7.  **"Dust to Dust"**: Collect 10 Gold Dust.
8.  **"Elemental Imbalance"**: Defeat 8 Corrupt Water Spirits.
9.  **"Into the Slopes"**: Travel to Zone 3.

### Zone 3: Timbermaw Slopes (Level 20-30)
*   **Quest Givers:** Pathfinder Gor'nash (300020)
1.  **"Proving Strength"**: Kill 10 Haldarr Satyrs.
2.  **"Satyr Horns"**: Collect 10 Satyr Horns.
3.  **"Smash the Totems"**: Destroy 5 Thistlefur Totems.
4.  **"Elder's Request"**: Kill 10 Thistlefur Shamans.
5.  **"Source of Corruption"**: Kill 15 Thistlefur Avengers.
6.  **"Cleansing Ritual"**: Defeat 20 Thistlefurs (Mass Kill).
7.  **"Furbolg Beads"**: Collect 10 Gnoll War Beads.
8.  **"Crocolisk Crisis"**: Hunt 6 Giant Wetlands Crocolisks.
9.  **"The River Awaits"**: Return to Zone 1 (Thalindra).

### Zone 4: Central River (Level 30-40)
*   **Giver:** Wavemaster Kol'gar (300030)
1.  **"Strashaz Threat"**: Kill 12 Strashaz Warriors.
2.  **"Drysnap Shells"**: Collect 10 Shells from Drysnap Pincers.
3.  **"Rock Elementals"**: Kill 8 Lesser Rock Elementals.
4.  **"Hydra Scales"**: Kill 6 Strashaz Hydras.
5.  **"Bounty: Prince Nazjak"**: Kill Prince Nazjak (Rare).
6.  **"River Pollution"**: Cleanse 8 polluted spots.
7.  **"Crab Meat"**: Collect 10 Crab Meat.
8.  **"Syndicate Threat"**: Kill 8 Syndicate Prowlers and 8 Syndicate Conjurors.
9.  **"Bounty: Molok the Crusher"**: Kill Molok the Crusher (Rare).
10. **"The Western Cliffs"**: Report to Vex'ara.

*   **Secondary Giver:** Engineer Whizzbang (300031)
1.  **"High-Explosive Research"**: Kill 6 Cliff Breakers.
2.  **"Stop the Screaming"**: Kill 8 Spitelash Sirens.
3.  **"Survey Data Recovery"**: Collect 8 Survey Data (from Ruins).

### Zone 5: The Cliffs (Level 40-50)
*   **Giver:** Demonologist Vex'ara (300040)
1.  **"Timbermaw Encroachment"**: Kill 10 Timbermaw Warriors and 8 Timbermaw Watchers.
2.  **"Spirits of the Highborne"**: Kill 8 Highborne Apparitions and 8 Highborne Lichlings.
3.  **"Cleansing the Temple"**: Kill 8 Spitelash Sirens and 8 Spitelash Myrmidons.
4.  **"Bounty: Ragepaw"**: Kill Ragepaw (Rare Furbolg).
5.  **"Bounty: Varo'then"**: Kill Varo'then's Ghost (Rare Ghost).
6.  **"The Water Beast"**: Kill Scalebeard (Rare Turtle).
7.  **"Cliff Feathers"**: Collect 10 Hippogryph Feathers.
8.  **"Into Haldarr Territory"**: Report to Kael'thos.

*   **Secondary Giver:** Earthcaller Ryga (300041)
1.  **"Restoring Balance"**: Kill 8 Felpaw Ravagers.
2.  **"Carrion Feeders"**: Kill 8 Carrion Vultures.
3.  **"Bounty: Magronos"**: Kill Magronos the Unyielding (Rare).

### Zone 6: The Fel Pit (Level 50-60)
*   **Giver:** Felsworn Kael'thos (300050)
1.  **"Legashi Cull"**: Kill 12 Legashi Satyrs.
2.  **"Infernal Cores"**: Collect 8 Entropic Cores.
3.  **"Doomguard Commander"**: Kill 4 Doomguard Commanders.
4.  **"Bounty: Gatekeeper Karlindos"**: Kill Gatekeeper Karlindos (Rare).
5.  **"Portal Sabotage"**: Sabotage 3 Legion Portals.
6.  **"Fel Armaments"**: Collect 10 Fel Weapons.
7.  **"Dragon Coast"**: Report to Seryth.

*   **Secondary Giver:** Vindicator Boros (300051)
1.  **"Sentry Destruction"**: Kill 5 Infernal Sentries.
2.  **"Hunting the Hunters"**: Kill 3 Dreadlords.
3.  **"Portal Keepers"**: Kill 5 Legashi Hellcallers.

### Zone 7: Wyrmrest (Level 60-70)
*   **Giver:** Dragonbinder Seryth (300060)
1.  **"Phase Hunter Menace"**: Kill 12 Phase Hunters.
2.  **"Mana Surge"**: Destroy 10 Mana Surges.
3.  **"Netherwing Presence"**: Kill 6 Netherwing Drakes.
4.  **"Bounty: General Colbatann"**: Kill General Colbatann (Rare).
5.  **"Dragon Egg Hunt"**: Destroy 8 Blue Dragon Eggs.
6.  **"Cultist Orders"**: Collect 6 Wyrmcult Orders.
7.  **"The Temple Approach"**: Report to Thadeus.

*   **Secondary Giver:** Ambassador Caelestrasz (300061)
1.  **"Naga Surveyors"**: Kill 10 Naga Explorers.
2.  **"Corrupted Beasts"**: Kill 8 Unstable Dragonhawks.
3.  **"Fanatical Devotion"**: Kill 8 Wyrmcult Zealots.

### Zone 8: The Temple (Level 70-80)
*   **Giver:** Archmage Thadeus (300070)
1.  **"Skeletal Army"**: Kill 12 Skeletal Craftsmen.
2.  **"Faceless Horror"**: Kill 8 Faceless Lurkers.
3.  **"Forgotten Captains"**: Kill 4 Forgotten Captains.
4.  **"Bounty: Antilos"**: Slay Antilos (Rare).
5.  **"Temple Artifacts"**: Collect 10 Ancient Artifacts.
6.  **"Ghostly Essence"**: Collect 8 Phantom Essence.

*   **Secondary Giver:** Nexus-Prince Haramad (300071)
1.  **"Weapons of the Dead"**: Kill 8 Skeletal Smiths.
2.  **"Guardian Malfunction"**: Kill 6 Temple Guardians.
3.  **"Spectral Servants"**: Kill 10 Phantom Valets.

### Mini-Dungeon Quests
1.  **D1: Ruins of Zin-Azshari (L25)**
    *   **"Ruins of Zin-Azshari"**: Kill Lady Sarevess (Boss).
    *   **"Targorr the Dread"**: Kill Targorr the Dread (Mini-Boss).
2.  **D2: Timbermaw Deep (L35)**
    *   **"Timbermaw Deep"**: Kill Death Speaker Jargba (Boss).
    *   **"Aggem Thorncurse"**: Kill Aggem Thorncurse (Mini-Boss).
    *   **"The Mosshide Menace"**: Kill 8 Mosshide Brutes & 8 Mosshide Mystics.
3.  **D3: Spitelash Depths (L40-50)** - Dark Iron Invasion Theme
    *   **"The Pyromancer"**: Kill Pyromancer Loregrain (Boss).
    *   **"Ambassador of Flame"**: Slay Ambassador Flamelash (Rare Elite).
    *   **"Faulty Engineering"**: Destroy the Faulty War Golem (Mini-Boss).
    *   **"The Iron Legion"**: Kill 10 Dark Iron Watchmen & 10 Dark Iron Geologists.
4.  **D4: The Searing Pit (L50-60)** - Blackrock/Razorfen Theme
    *   **Quest Giver:** Slayer Vorith (300084)
    *   **"Warlord of the Pit"**: Kill Ghok Bashguud (Boss).
    *   **"The Dark Iron General"**: Defeat General Angerforge (Mini-Boss).
    *   **"Ambassador's End"**: Slay Ambassador Flamelash (Rare Elite).
    *   **"Terrors from the Deep"**: Defeat Hydrospawn (Water Boss).
    *   **"Blackrock Incursion"**: Kill 12 Blackrock Soldiers & Slayers.
    *   **"Spirestone Menace"**: Kill 10 Spirestone Ogres (Mystics/Lords).
    *   **"Beasts of the Pit"**: Kill 10 Giant Ember Worgs & Tar Creepers.

5.  **D5: Temple of Elune (L60-70)** - Night Elf/Arcane Theme
    *   **Quest Giver:** Priestess Lunara (300085)
    *   **"Temple of Elune"**: Defeat Priestess Delrissa (Boss).
    *   **"The Twilight Threat"**: Slay Twilight Lord Kelris (Rare).
    *   **"Arcane Corruption"**: Defeat Arcane Torrent (Rare).
    *   **"High Priestess Arlokk"**: Defeat High Priestess Arlokk (Mini-Boss).
    *   **"Highborne Corruption"**: Slay 8 Highborne Lichlings & 8 Highborne Summoners.
    *   **"Moonkin Madness"**: Slay 10 Moonkin Oracles & 5 Moonkin Matriarchs.
    *   **"Eldreth Incursion"**: Slay 8 Eldreth Sorcerers & 6 Eldreth Seethers.
6.  **D6: Sanctum of the Highborne (L75-80)** - Highborne/Arcane Theme
    *   **Quest Giver:** Image of Arcanigos (300086)
    *   **"Sanctum of the Highborne"**: Defeat Cyanigosa (Boss).
    *   **"Magister Kalendris"**: Defeat Magister Kalendris (Mini-Boss).
    *   **"The Forgotten Ones"**: Slay 10 Forgotten Ones.
    *   **"Arcane Sentinels"**: Destroy 10 Arcane Sentinels.
    *   **"Wretched Infestation"**: Slay 12 Wretched Ghouls & 8 Wretched Belchers.
    *   **"Highborne Spirits"**: Banish 10 Highborne Apparitions & 8 Ancient Highborne Spirits.
    *   **"Faceless Horror"**: Slay 6 Faceless Lurkers.

---

## Technical Notes
*   **Schemas**: Adhere strictly to `world schema.sql`.
    *   `creature_template`: No `modelid` columns used.
    *   `creature_template_model`: Used for assigning models.
    *   `quest_template`: Standard WotLK structure.
*   **Rewards**: Quests reward XP, Money, and custom tokens (300311, 300312).
