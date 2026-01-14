# Jadeforest Playerbase - Detailed Implementation Guide

**Document Type:** Design Specification  
**Zone:** Jade Forest (Map ID 870)  
**Purpose:** Peaceful hub for all levels

---

## 🗺️ Zone Map with Location Markers

![Map with Functional Labels](jadeforest_zone_guide_map.png)

### Location Overview (Map Reference)

```
                         N
                         ↑
    ┌─────────────────────────────────────────────────────────────┐
    │                                                              │
    │   🍯 HONEYDEW          ⚡ TERRACE OF         🌊 SRI-LA       │
    │   VILLAGE              TEN THUNDERS          VILLAGE        │
    │   (Professions)        (PvP Info)            (World Boss)   │
    │           ↘                ↓                ↙               │
    │               🏛️ TIAN MONASTERY                             │
    │               (Training Grounds)               🏝️ WINDWARD  │
    │                      ↓                          ISLE        │
    │   🦎 GROOKIN    🌸 DAWN'S BLOSSOM    🌳 ARBORETUM           │
    │   HILL          (Social Hub)         (Collections)          │
    │   (Mounts)            ↓                    ↓                │
    │                 💚 SERPENT'S      ⛩️ TEMPLE OF              │
    │                    HEART           JADE SERPENT              │
    │                    (Lore)          (Tutorial Hub)           │
    │                      ↓                                       │
    │         🍎 NECTARBREEZE                                      │
    │            ORCHARD                                           │
    │            (Seasonal)                                        │
    │                ↓                                             │
    │         🏠 PAW'DON          🐟 PEARLFIN                      │
    │            VILLAGE           VILLAGE                         │
    │ ═══════(ARRIVAL HUB)═══════ (Fishing)                       │
    │                ↓                   ↓                         │
    │                        🌙 MOONWATER                          │
    │                           RETREAT                            │
    │                        (Bank & AH)                          │
    └─────────────────────────────────────────────────────────────┘
                         ↓
                    (Coast/Docks)
```

---

## 👤 NPC Model Reference (WotLK DisplayIDs)

### Existing Custom NPCs (800020-800027)

| Entry ID | Name | DisplayID | Scale | Notes |
|----------|------|-----------|-------|-------|
| 800020 | Innkeeper Pandgrimble | **30414** | 2.5 | Pandaren Monk model |
| 800021 | Panda Bruiser (Guard) | **30414** | 2.0 | Pandaren Monk model |
| 800022-27 | Flightmasters | **7102/7103/7104** | 1.0 | Gryphon riding models |
| 800023 | Scarlet Gryphon | **25579** | 1.0 | Taxi vehicle |

### Recommended WotLK Models for New NPCs

#### Hub & Service NPCs (Pandaren Theme)
Use **DisplayID 30414** (Pandaren Monk) with scale variations for thematic consistency:

| NPC Role | Suggested DisplayID | Scale | Visual Style |
|----------|---------------------|-------|--------------|
| Teleporter Guards | 30414 | 1.8 | Pandaren standing guard |
| Tutorial NPCs | 30414 | 1.5 | Smaller, approachable |
| Event Coordinator | 30414 | 1.6 | Medium size |
| Lore NPCs | 30414 | 1.5 | Elderly appearance |

#### Alternative Humanoid Models (Variety)

| DisplayID | Model Description | Best For |
|-----------|-------------------|----------|
| **26714** | Dalaran Citizen Male | Human service NPCs |
| **26715** | Dalaran Citizen Female | Human vendors |
| **24353** | Kirin Tor Wizard | Magical tutorial NPCs |
| **27978** | Argent Crusade Male | Alliance-style guards |
| **27979** | Argent Crusade Female | Alliance-style vendors |
| **28213** | Wyrmrest Accord | Dragonkin themed NPCs |
| **26466** | Sons of Hodir Male | Large imposing NPCs |
| **29169** | Ebon Blade Knight | Dark/mysterious NPCs |

#### Trainer Models (Copy Existing Blizzard)

| NPC Type | Copy From Entry | DisplayID |
|----------|-----------------|-----------|
| Warrior Trainer | 914 | Use creature_template_model |
| Mage Trainer | 328 | Use creature_template_model |
| Priest Trainer | 376 | Use creature_template_model |
| Rogue Trainer | 918 | Use creature_template_model |
| Hunter Trainer | 987 | Use creature_template_model |
| Paladin Trainer | 928 | Use creature_template_model |
| Warlock Trainer | 988 | Use creature_template_model |
| Shaman Trainer | 986 | Use creature_template_model |
| Druid Trainer | 542 | Use creature_template_model |
| Death Knight Trainer | Use Ebon Blade | 29169 |

#### Profession Trainers (Copy Existing)

| Profession | Copy From Entry | Notes |
|------------|-----------------|-------|
| Blacksmithing | 514 | Smith Argus |
| Tailoring | 1103 | Eldrin |
| Herbalism | 812 | Alma Jainrose |
| Alchemy | 1215 | Alchemist Mallory |
| Skinning | 1292 | Maris Granger |

#### Vendor NPCs

| Vendor Type | Suggested DisplayID | Notes |
|-------------|---------------------|-------|
| General Goods | 30414 (Scale 1.4) | Pandaren vendor |
| Food/Drink | 30414 (Scale 1.3) | Pandaren cook |
| Mount Vendor | 26714 | Human stable master style |
| Seasonal Vendor | 30414 (Scale 1.6) | Changes seasonally |

#### Flightmaster Models (Internal Travel)

For internal zone flightmasters, continue using existing pattern:
- **DisplayIDs 7102, 7103, 7104** (Gryphon variants)
- Or use **Cloud Serpent** visual if available via spell effects

---

## 📖 Story Questlines

### Story 1: "Whispers of the Jade Serpent"
**Type:** Lore/Exploration Chain  
**Location:** Serpent's Heart → Temple of Jade Serpent  
**Length:** 6 quests

**Synopsis:** Players learn about the blessing that protects the forest and why this sanctuary remains safe while chaos spreads elsewhere.

| Quest # | Quest Name | NPC | Objective | Reward |
|---------|------------|-----|-----------|--------|
| 1 | "The Protected Forest" | Lorekeeper Mei | Listen to the story | 50g |
| 2 | "Echoes of Yu'lon" | Lorekeeper Mei | Visit Serpent's Heart | 50g + Lore item |
| 3 | "The Jade Blessing" | Spirit of Yu'lon | Find 4 Memory Stones | 100g |
| 4 | "Gathering the Ancients" | Spirit of Yu'lon | Visit Dawn's Blossom, Tian Monastery | 75g |
| 5 | "Heart of the Forest" | Elder Chi'wan | Return to Temple of Jade Serpent | 100g |
| 6 | "Guardian's Promise" | Elder Chi'wan | Complete the blessing ritual | 200g + Achievement |

**Achievement:** "Child of Yu'lon" - Completed the Jade Serpent storyline

---

### Story 2: "Welcome to Dark Chaos"
**Type:** Tutorial/System Introduction Chain  
**Location:** Paw'Don Village → All major locations  
**Length:** 10 quests

**Synopsis:** New players are guided through all DC systems by visiting each location.

| Quest # | Quest Name | System Taught | Location |
|---------|------------|---------------|----------|
| 1 | "New Beginnings" | Basic orientation | Paw'Don |
| 2 | "The Path Forward" | Zone navigation | Dawn's Blossom |
| 3 | "Unlimited Power" | Level 255 system | Temple |
| 4 | "Keys of Challenge" | Mythic+ basics | Temple |
| 5 | "Seasons of Fortune" | Seasonal content | Temple |
| 6 | "The Art of War" | Training & combat | Tian Monastery |
| 7 | "Forged in Fire" | Item upgrades | Temple |
| 8 | "Trials of Champions" | Hardcore modes | Temple |
| 9 | "Collecting Memories" | Collection system | Arboretum |
| 10 | "Champion of Chaos" | Final graduation | Paw'Don |

**Completion Rewards:**
- 500 Gold
- Title: "Newcomer"
- Starter Upgrade Token (T1)
- Jadeforest Tabard

---

### Story 3: "The Wanderer's Path"
**Type:** Exploration/Discovery Chain  
**Location:** All hidden locations  
**Length:** 5 quests (each discovering secrets)

| Quest # | Quest Name | Secret to Find | Hint Given |
|---------|------------|----------------|------------|
| 1 | "Hidden Waters" | Waterfall cave near Pearlfin | "Where water meets stone..." |
| 2 | "The Lost Scroll" | Hidden ledge at Tian Monastery | "Look to the mountain's edge..." |
| 3 | "Whispers in the Wind" | Secret garden at Windward Isle | "The islands hold ancient secrets..." |
| 4 | "The Merchant's Cache" | Hidden vendor at Grookin Hill | "Follow the path less traveled..." |
| 5 | "Master of Secrets" | Central secret at Serpent's Heart | "Where all paths converge..." |

**Completion Rewards:**
- Title: "Jade Explorer"
- Mount: "Viridian Cloud Serpent" (recolored flying mount)
- Achievement: "Secrets of the Jade Forest"

---

### Story 4: "Friendship Across Factions"
**Type:** Social/Community Chain  
**Location:** Dawn's Blossom  
**Length:** 4 quests (requires grouping)

| Quest # | Quest Name | Requirement |
|---------|------------|-------------|
| 1 | "Strength in Numbers" | Group with 2+ other players |
| 2 | "Trading Stories" | Use /say in Dawn's Blossom plaza |
| 3 | "The Training Match" | Duel another player (friendly) |
| 4 | "Bonds of Jade" | Return to event coordinator |

**Completion Rewards:**
- Social title: "Friend of the Forest"
- Cosmetic toy: "Jade Lantern" (summons decorative lantern)

---

### Story 5: "Legends of the Arena"
**Type:** PvP Introduction Chain  
**Location:** Terrace of Ten Thunders  
**Length:** 3 quests

| Quest # | Quest Name | Objective |
|---------|------------|-----------|
| 1 | "Warriors of the Storm" | Speak to Arena Master |
| 2 | "The Art of Combat" | View the arena leaderboard |
| 3 | "Ready for Battle" | Queue for any BG/Arena |

**Completion Rewards:**
- 100 Honor Points
- Information about DC PvP systems

---

## 🖥️ UI Requirements

### Required Addon Extensions (DC-QOS or Dedicated)

#### 1. Zone Welcome Panel
**Purpose:** First-time visitor introduction

```
┌─────────────────────────────────────────────────────────────┐
│  ⛩️ WELCOME TO JADEFOREST PLAYERBASE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Welcome, $PLAYER! This is the heart of Dark Chaos -       │
│  a peaceful sanctuary for all heroes.                       │
│                                                             │
│  Here you can:                                              │
│  • Learn about DC systems (Temple of Jade Serpent)          │
│  • Practice combat (Tian Monastery)                         │
│  • Manage your collection (The Arboretum)                   │
│  • Socialize and trade (Dawn's Blossom)                     │
│  • Travel to any zone (Paw'Don teleporters)                │
│                                                             │
│  [Don't show again]                          [Got it! ✓]   │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:** AIO addon message on zone entry (first time only)

---

#### 2. Tutorial Progress Tracker
**Purpose:** Track tutorial questline completion

```
┌─────────────────────────────────────────────────────────────┐
│  📚 WELCOME TUTORIAL                           [Hide]       │
├─────────────────────────────────────────────────────────────┤
│  Progress: ████████░░ 8/10                                  │
│                                                             │
│  ✓ New Beginnings           ✓ Keys of Challenge            │
│  ✓ The Path Forward         ✓ Seasons of Fortune           │
│  ✓ Unlimited Power          ✓ The Art of War               │
│  ✓ Forged in Fire           □ Trials of Champions          │
│  □ Collecting Memories      □ Champion of Chaos            │
│                                                             │
│  Next: Visit the Challenge Sage at the Temple              │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:** AIO addon with SavedVariables for progress

---

#### 3. Zone Map Annotations (DC-Mapupgrades)
**Purpose:** Show all important locations on world map

**Pin Types to Add:**

| Icon | Color | Label | Tooltip |
|------|-------|-------|---------|
| 🏠 | Blue | "Arrival Hub" | Teleporters, Innkeeper, Hearthstone |
| 🎓 | Gold | "Tutorial Hub" | Learn DC systems here |
| ⚔️ | Red | "Training" | Practice combat, test DPS |
| 🛒 | Green | "Marketplace" | Vendors, Bank, AH |
| 🎉 | Purple | "Events" | Social hub, seasonal events |
| 🐉 | Cyan | "Collections" | Mounts, pets, transmog |
| ⚡ | Yellow | "PvP Info" | Arena/BG information |
| 📖 | White | "Lore" | Story and history |

**Implementation:** Add to DC-Mapupgrades MapPins.lua for zone ID

---

#### 4. Location Tooltip Enhancement
**Purpose:** Rich tooltips when hovering map locations

```
┌──────────────────────────────────────┐
│ ⛩️ TEMPLE OF JADE SERPENT            │
├──────────────────────────────────────┤
│ Learn about Dark Chaos systems:      │
│ • Level 255 Progression              │
│ • Mythic+ Dungeons                   │
│ • Seasonal Content                   │
│ • Item Upgrades                      │
│ • Great Vault Access                 │
│                                      │
│ Tutorial NPCs: 8                     │
│ Great Vault: Available here          │
└──────────────────────────────────────┘
```

---

#### 5. Event Calendar Integration
**Purpose:** Show upcoming zone events

```
┌─────────────────────────────────────────────────────────────┐
│  📅 JADEFOREST EVENTS                          [This Week]  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SAT 19:00  Community Gathering     Dawn's Blossom          │
│  SUN 15:00  Fishing Derby           Pearlfin Village        │
│  WED 20:00  Trivia Night            Temple of Jade Serpent  │
│                                                             │
│  [View Full Calendar]                                       │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:** Server-synced event data via AIO

---

#### 6. Flightmaster Destination UI
**Purpose:** Clean UI for internal zone travel

```
┌─────────────────────────────────────────────────────────────┐
│  🦅 JADEFOREST FLIGHTPATHS                                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📍 Current: Paw'Don Village                                │
│                                                             │
│  DESTINATIONS:                                              │
│  [Dawn's Blossom]          ⏱️ 45s                           │
│  [Temple of Jade Serpent]  ⏱️ 1m 10s                        │
│  [Tian Monastery]          ⏱️ 1m 30s                        │
│  [Honeydew Village]        ⏱️ 2m 00s                        │
│  [Windward Isle]           ⏱️ 1m 45s                        │
│                                                             │
│  Tip: Use teleporters at Paw'Don for instant travel        │
│       to OTHER zones!                                       │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:** Custom gossip UI via AIO or standard gossip

---

#### 7. Teleporter Guard Interface
**Purpose:** Instant travel to external DC zones

```
┌─────────────────────────────────────────────────────────────┐
│  🌀 TELEPORTER GUARD - EXTERNAL TRAVEL                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Select Destination:                                        │
│                                                             │
│  ⚔️ [Azshara Crater]       Level 1-80 Zone                  │
│  🔥 [Mount Hyjal]          Level 80-130 Zone                │
│  💀 [Stratholme]           Level 130-160 Zone               │
│  🦖 [Giant Isles]          World Boss Zone                  │
│  🛒 [Shopping Mall]        Vendors & Gear                   │
│  ⚔️ [Arena Staging]        PvP Queue Area                   │
│                                                             │
│                                         [Cancel]            │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:** Gossip menu with teleport scripts

---

### Existing Addon Integration

| Addon | Integration Needed |
|-------|--------------------|
| **DC-Mapupgrades** | Add map pins for all Jadeforest locations |
| **DC-InfoBar** | (Optional) Show current zone events timer |
| **DC-QOS** | Welcome panel, tutorial tracker |
| **DC-GM** | Quick teleport commands for GMs |

---

## 🔧 Technical Implementation Notes

### Creature Entry ID Range
Reserve **800028 - 800100** for Jadeforest NPCs:

| Range | Purpose |
|-------|---------|
| 800028-800035 | Teleporter Guards |
| 800036-800050 | Tutorial/Service NPCs |
| 800051-800070 | Profession Trainers |
| 800071-800085 | Class Trainers |
| 800086-800095 | Vendors |
| 800096-800100 | Quest NPCs |

### Spawn Locations (Approximate Coordinates)
*Note: Exact coordinates need to be determined in-game*

| Location | Map ID | Approx Area |
|----------|--------|-------------|
| Paw'Don Village | 870 | Southern coast |
| Dawn's Blossom | 870 | Central village |
| Temple of Jade Serpent | 870 | Eastern temple |
| Tian Monastery | 870 | Northwestern mountains |

### Scripts Needed

| Script Name | Purpose |
|-------------|---------|
| `jadeforest_teleporter` | Teleport gossip handler |
| `jadeforest_flightmaster` | Internal flight paths |
| `jadeforest_tutorial_npc` | Tutorial dialogue handler |
| `jadeforest_event_npc` | Event information |

---

## 📊 Implementation Priority

### Phase 1 (Core - Week 1)
1. Paw'Don Village complete (arrival, teleporters)
2. Flightmaster network setup
3. Basic welcome UI (addon)

### Phase 2 (Services - Week 2)
1. Bank/AH (Moonwater)
2. Profession hub (Honeydew)
3. Training (Tian Monastery)

### Phase 3 (Content - Week 3-4)
1. Tutorial questline
2. Tutorial NPCs at Temple
3. Collection hub (Arboretum)

### Phase 4 (Stories - Week 5)
1. Lore questlines
2. Exploration secrets
3. Hidden vendor

### Phase 5 (Polish - Week 6)
1. Map pin integration
2. Event system
3. Achievement integration

---

*Implementation Guide for Dark Chaos Jadeforest Playerbase - January 2026*
 
 # #   P r e s e r v e d   I m p l e m e n t a t i o n   D a t a   ( C o d e   R e v e r t e d )  
  
 # # #   M a p   P i n s   D a t a   ( ` D C - M a p u p g r a d e s ` )  
 ` ` ` l u a  
 l o c a l   J A D E F O R E S T _ P I N S   =   {  
         {   x = 4 2 . 5 ,   y = 8 5 . 2 ,   n a m e = " P a w ' D o n   V i l l a g e " ,   d e s c = " A r r i v a l   &   T e l e p o r t e r s " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ I N V _ M i s c _ R u n e _ 0 6 " ,   t y p e = " H u b "   } ,  
         {   x = 5 5 . 1 ,   y = 4 5 . 3 ,   n a m e = " D a w n ' s   B l o s s o m " ,   d e s c = " S o c i a l   H u b " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ S p e l l _ H o l y _ P r a y e r O f H e a l i n g " ,   t y p e = " S o c i a l "   } ,  
         {   x = 6 5 . 2 ,   y = 5 5 . 4 ,   n a m e = " T e m p l e   o f   t h e   J a d e   S e r p e n t " ,   d e s c = " T u t o r i a l   H u b " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ I N V _ S c r o l l _ 0 6 " ,   t y p e = " T u t o r i a l "   } ,  
         {   x = 4 5 . 8 ,   y = 3 5 . 1 ,   n a m e = " T i a n   M o n a s t e r y " ,   d e s c = " T r a i n i n g   G r o u n d s " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ A b i l i t y _ W a r r i o r _ O f f e n s i v e S t a n c e " ,   t y p e = " T r a i n i n g "   } ,  
         {   x = 7 5 . 5 ,   y = 3 5 . 8 ,   n a m e = " T h e   A r b o r e t u m " ,   d e s c = " C o l l e c t i o n s " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ I N V _ P e t _ P a n d a C u b " ,   t y p e = " C o l l e c t i o n "   } ,  
         {   x = 2 5 . 4 ,   y = 2 5 . 6 ,   n a m e = " H o n e y d e w   V i l l a g e " ,   d e s c = " P r o f e s s i o n s " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ T r a d e _ E n g i n e e r i n g " ,   t y p e = " P r o f e s s i o n "   } ,  
         {   x = 4 8 . 2 ,   y = 1 5 . 9 ,   n a m e = " T e r r a c e   o f   T e n   T h u n d e r s " ,   d e s c = " P v P   I n f o " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ A c h i e v e m e n t _ P V P _ H _ 0 4 " ,   t y p e = " P v P "   } ,  
         {   x = 6 8 . 1 ,   y = 6 5 . 2 ,   n a m e = " P e a r l f i n   V i l l a g e " ,   d e s c = " F i s h i n g " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ T r a d e _ F i s h i n g " ,   t y p e = " R e l a x "   } ,  
         {   x = 8 5 . 3 ,   y = 7 5 . 4 ,   n a m e = " M o o n w a t e r   R e t r e a t " ,   d e s c = " B a n k   &   A u c t i o n " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ I N V _ M i s c _ C o i n _ 0 1 " ,   t y p e = " S e r v i c e "   } ,  
         {   x = 5 8 . 2 ,   y = 8 2 . 1 ,   n a m e = " G r o o k i n   H i l l " ,   d e s c = " M o u n t   D i s p l a y " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ A b i l i t y _ M o u n t _ R i d i n g H o r s e " ,   t y p e = " D i s p l a y "   } ,  
         {   x = 1 5 . 4 ,   y = 4 5 . 6 ,   n a m e = " W i n d w a r d   I s l e " ,   d e s c = " H i d d e n   E x p l o r a t i o n " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ I N V _ M i s c _ S p y g l a s s _ 0 2 " ,   t y p e = " E x p l o r a t i o n "   } ,  
         {   x = 9 0 . 1 ,   y = 4 5 . 2 ,   n a m e = " S r i - L a   V i l l a g e " ,   d e s c = " W o r l d   B o s s   P o r t a l " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ S p e l l _ S h a d o w _ D e a t h C o i l " ,   t y p e = " P o r t a l "   } ,  
         {   x = 3 2 . 1 ,   y = 6 5 . 4 ,   n a m e = " N e c t a r b r e e z e   O r c h a r d " ,   d e s c = " S e a s o n a l   E v e n t s " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ I N V _ H o l i d a y _ C h r i s t m a s _ P r e s e n t _ 0 1 " ,   t y p e = " E v e n t "   } ,  
         {   x = 4 5 . 6 ,   y = 5 5 . 2 ,   n a m e = " S e r p e n t ' s   H e a r t " ,   d e s c = " L o r e   H u b " ,   i c o n = " I n t e r f a c e \ \ I c o n s \ \ S p e l l _ H o l y _ M i n d V i s i o n " ,   t y p e = " L o r e "   }  
 }  
 ` ` `  
  
 # # #   E v e n t   S c h e d u l e   ( ` D C - I n f o B a r ` )  
 ` ` ` l u a  
 - -   D a y :   1 = S u n ,   2 = M o n   . . .   7 = S a t  
 l o c a l   S C H E D U L E   =   {  
         {   d a y = 1 ,   h o u r = 1 4 ,   m i n = 0 ,   n a m e = " S u n d a y   S o c i a l " ,   d u r = 6 0 ,   z o n e = " J a d e   F o r e s t "   } ,  
         {   d a y = 1 ,   h o u r = 2 0 ,   m i n = 0 ,   n a m e = " R a i d   A s s e m b l y " ,   d u r = 1 2 0 ,   z o n e = " J a d e   F o r e s t "   } ,  
         {   d a y = 3 ,   h o u r = 1 9 ,   m i n = 0 ,   n a m e = " M i d w e e k   P v P " ,   d u r = 6 0 ,   z o n e = " J a d e   F o r e s t "   } ,  
         {   d a y = 6 ,   h o u r = 2 1 ,   m i n = 0 ,   n a m e = " F r i d a y   N i g h t   P a r t y " ,   d u r = 1 8 0 ,   z o n e = " J a d e   F o r e s t "   } ,  
         {   d a y = 7 ,   h o u r = 1 6 ,   m i n = 0 ,   n a m e = " S a t u r d a y   P a r k o u r " ,   d u r = 6 0 ,   z o n e = " J a d e   F o r e s t "   } ,  
 }  
 ` ` `  
  
 # # #   W e l c o m e   P a n e l   T e x t   ( ` D C - W e l c o m e ` )  
 * * T i t l e * * :   " W e l c o m e   t o   J a d e f o r e s t ! "  
 * * D e s c r i p t i o n * * :    
 " T h i s   i s   t h e   n e w   m a i n   s o c i a l   h u b   f o r   D a r k   C h a o s .  
  
 H e r e   y o u   w i l l   f i n d :  
 -   P o r t a l s   t o   a l l   m a j o r   z o n e s  
 -   T r a i n i n g   D u m m i e s   &   V e n d o r s  
 -   S o c i a l   E v e n t s   &   G a t h e r i n g s  
 -   P a r k o u r   C h a l l e n g e s "  
 