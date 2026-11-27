# Giant Isles — Achievement Plan

WotLK 3.3.5a achievements are DBC-driven on the **client side**.
Implementing custom achievements requires:
1. Adding rows to `Achievement.dbc` and `AchievementCriteria.dbc` (binary client files).
2. Adding matching `achievement_criteria_data` rows to `acore_world` (server-side criteria checks).
3. Rebuilding the client DBC patch.

The entries below are reserved in the **10000–10099** block (verify this range is free in your DBC before applying).

---

## Category Suggestion

Use an existing `Achievement_Category.dbc` parent:  
- **81** = Dungeons & Raids (for temple achievements)  
- **97** = World Events (for zone meta)  
- Or create a custom category "Giant Isles" under the existing "World" parent.

---

## Planned Achievements

### Zone Exploration

| DBC ID | Name | Criteria | Points |
|--------|------|----------|--------|
| 10000 | **Footprints on the Giant Isles** | Discover all 4 zone sectors: Warden's Landing, Raptor Beaches, Direhorn Valley, Devilsaur Heights | 10 |

### Dinosaur Hunting

| DBC ID | Name | Criteria | Points |
|--------|------|----------|--------|
| 10001 | **Dino Hunter** | Kill 100 Chaos Raptors | 10 |
| 10002 | **Apex Predator** | Kill 50 Chaos Devilsaurs | 10 |
| 10003 | **Herd Buster** | Kill 50 Primal Stegodons | 10 |
| 10004 | **Sky Terror** | Kill 50 Chaos Pterrordax | 10 |

### Rare Hunting

| DBC ID | Name | Criteria | Points |
|--------|------|----------|--------|
| 10010 | **Rare Game** | Kill any 3 rare elite dinosaurs (400050–400059) | 10 |
| 10011 | **The Collector** | Kill all 10 rare elite spawn variants | 25 |
| 10012 | **Gul'rok's Head** | Kill Gul'rok the Cursed (400059) | 10 |

### World Bosses

| DBC ID | Name | Criteria | Points |
|--------|------|----------|--------|
| 10020 | **King Slayer** | Kill Oondasta (400100) | 25 |
| 10021 | **The Bloodthirsty** | Kill Thok the Bloodthirsty (400101) | 25 |
| 10022 | **Storm Breaker** | Kill Nalak the Storm Lord (400102) | 25 |
| 10023 | **Ruler of the Giant Isles** | Kill all 3 world bosses | 50 |

### Zandalari Invasion Event

| DBC ID | Name | Criteria | Points |
|--------|------|----------|--------|
| 10030 | **Wave Breaker** | Repel a Zandalari Invasion (complete all 4 waves) | 25 |
| 10031 | **War Commander** | Kill Warlord Zul'mar (400336) | 10 |

### Temple of Atal'Hakkar

| DBC ID | Name | Criteria | Points |
|--------|------|----------|--------|
| 10040 | **Temple Breaker** | Complete "The Sunken Temple Awakens" (quest 82000) | 10 |
| 10041 | **Blood Seeker** | Complete "The Four Bloodseekers" (quest 82001) — kill all 4 sub-bosses | 10 |
| 10042 | **The Prophet Falls** | Kill Jammal'an the Eternal (400521) | 10 |
| 10043 | **No Blood God Today** | Kill the Reawakened Avatar of Hakkar (400522) | 25 |
| 10044 | **Laid to Rest** | Kill the Ancient Shade of Eranikus (400523) | 10 |
| 10045 | **Temple Cleared** | Kill Atal'alarion the Eternal, Jammal'an the Eternal, and the Reawakened Avatar of Hakkar | 50 |

### Meta Achievement

| DBC ID | Name | Criteria | Points | Reward |
|--------|------|----------|--------|--------|
| 10050 | **Master of the Giant Isles** | Complete achievements 10000, 10011, 10023, 10030, 10045 | 50 | Title: "the Primal Hunter" |

---

## Server-Side Criteria Data

Once DBC IDs are assigned, add rows to `achievement_criteria_data` in `acore_world`.
Format: `(criteria_id, type, value1, value2, ScriptName, comment)`

Criteria types used:
- `0` = ACHIEVEMENT_CRITERIA_DATA_TYPE_NONE  
- `6` = ACHIEVEMENT_CRITERIA_DATA_TYPE_CREATURE_ENTRY (value1 = creature entry)  
- `9` = ACHIEVEMENT_CRITERIA_DATA_TYPE_QUEST_COMPLETE (value1 = quest ID)

---

## DBC Edit Notes

Tools: `MyDBCEditor`, `MPQEditor`, or direct binary editing via python struct scripts.

Each achievement row in `Achievement.dbc` needs:
```
ID, faction (-1=both), mapID (-1=any), parentAchievement, name, description,
categoryID, points, orderInCategory, flags, iconID, reward, minimumCriteria,
uiOrder
```

Each `AchievementCriteria.dbc` row needs:
```
ID, achievementID, type, assetID, quantity, startEvent, startAsset, failEvent,
failAsset, description, flags, timedCriteriaStartType, timedCriteriaAsset,
timeLimit, uiOrder
```

Types for kill criteria: `type = 0` (KILL_CREATURE), `assetID = creature_entry`, `quantity = kill_count`.
