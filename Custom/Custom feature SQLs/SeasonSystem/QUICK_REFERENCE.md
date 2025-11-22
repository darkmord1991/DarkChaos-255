# Season System Quick Reference - Phase 1

## Reward Values At-A-Glance

### Daily Activities
| Activity | Tokens | Essence | Notes |
|----------|--------|---------|-------|
| Daily Dungeon Quest | 50 | 25 | 4 available per day (700101-700104) |
| Dungeon Boss Kill | 10 | 0 | Any WotLK heroic boss |
| Event Boss Kill | 75 | 40 | Ahune, Coren, Horseman |

### Weekly Activities
| Activity | Tokens | Essence | Notes |
|----------|--------|---------|-------|
| Weekly Dungeon Quest | 150 | 75 | Complete 5 dungeons (placeholder ID 700201) |
| Weekly Raid Quest | 200 | 100 | Kill raid bosses (placeholder ID 700301) |

### World Bosses (Split Among Group)
| Boss | Tokens | Essence | Location |
|------|--------|---------|----------|
| Azuregos | 150 | 75 | Azshara |
| Doomlord Kazzak (BC) | 150 | 75 | Hellfire Peninsula |
| Lord Kazzak (Vanilla) | 150 | 75 | Blasted Lands |
| Ysondre | 150 | 75 | Feralas (Nightmare Dragon) |
| Lethon | 150 | 75 | Hinterlands (Nightmare Dragon) |
| Emeriss | 150 | 75 | Duskwood (Nightmare Dragon) |
| Taerar | 150 | 75 | Ashenvale (Nightmare Dragon) |

### Raid Bosses (Naxxramas 25)
| Boss | Tokens | Essence | Quarter |
|------|--------|---------|---------|
| Anub'Rekhan | 30 | 15 | Arachnid |
| Faerlina | 30 | 15 | Arachnid |
| Maexxna | 30 | 15 | Arachnid |
| Noth | 30 | 15 | Plague |
| Heigan | 30 | 15 | Plague |
| Loatheb | 30 | 15 | Plague |
| Razuvious | 30 | 15 | Military |
| Gothik | 30 | 15 | Military |
| Four Horsemen | 40 | 20 | Military (each) |
| Patchwerk | 30 | 15 | Construct |
| Grobbulus | 30 | 15 | Construct |
| Gluth | 30 | 15 | Construct |
| Thaddius | 30 | 15 | Construct |
| Sapphiron | 40 | 20 | Frostwyrm |
| Kel'Thuzad | 50 | 25 | Frostwyrm |

---

## Achievement Requirements

### Token Milestones
| Achievement | ID | Requirement | Reward |
|-------------|-----|-------------|--------|
| Seasonal Novice | 11000 | 1,000 tokens | 10 points |
| Seasonal Champion | 11001 | 5,000 tokens | Title: "\<Name\> the Seasonal" |
| Seasonal Legend | 11002 | 10,000 tokens | Title: "Seasonal Legend \<Name\>" |

### World Boss Kills
| Achievement | ID | Requirement | Reward |
|-------------|-----|-------------|--------|
| World Boss Hunter | 11010 | 10 world boss kills | 15 points |
| World Boss Slayer | 11011 | 25 world boss kills | 25 points |
| World Boss Vanquisher | 11012 | 50 world boss kills | Title: "\<Name\>, Bane of Tyrants" |

### Quest Completion
| Achievement | ID | Requirement | Reward |
|-------------|-----|-------------|--------|
| Quest Master | 11020 | 100 seasonal quests | 15 points |
| Quest Legend | 11021 | 250 seasonal quests | 25 points |
| Quest God | 11022 | 500 seasonal quests | Title: "\<Name\> the Unwavering" |

### Special Boss Achievements
| Achievement | ID | Requirement | Reward |
|-------------|-----|-------------|--------|
| Nightmare Slayer I | 11050 | Defeat all 4 Dragons | 25 points |
| Nightmare Slayer II | 11051 | Defeat each dragon 10x | Title: "\<Name\>, Scourge of Nightmares" |
| Azuregos Hunter | 11060 | Kill Azuregos 10x | 15 points |
| Kazzak's Bane | 11061 | Kill Kazzak 10x | 15 points |

### Meta Achievement
| Achievement | ID | Requirement | Reward |
|-------------|-----|-------------|--------|
| Season 1 Legend | 11082 | Complete ALL seasonal achievements | Title: "Season 1 Legend \<Name\>" |

---

## Configuration Files

### Eluna Script Location
```
Custom/Eluna scripts/SeasonalRewards.lua
```

### SQL Data Location
```
Custom/Custom feature SQLs/worlddb/SeasonSystem/01_POPULATE_SEASON_1_REWARDS.sql
```

### DBC Files Location
```
Custom/CSV DBC/SEASONAL_ACHIEVEMENTS.csv
Custom/CSV DBC/SEASONAL_TITLES.csv
```

---

## Admin Commands (Not Yet Implemented - Phase 2)

### Planned Commands
```
.season reload                    -- Reload reward cache without restart
.season stats <player>            -- View player's seasonal stats
.season setseason <id>            -- Change active season
.season award <player> <amount>   -- Manually award tokens/essence
.season reset <player>            -- Reset player's seasonal progress
```

---

## Database Queries

### Check Player Stats
```sql
SELECT * FROM dc_player_seasonal_stats 
WHERE player_guid = <player_guid> AND season_id = 1;
```

### View Recent Transactions
```sql
SELECT * FROM dc_reward_transactions 
WHERE player_guid = <player_guid> AND season_id = 1
ORDER BY transaction_timestamp DESC 
LIMIT 20;
```

### Top Token Earners
```sql
SELECT player_guid, total_tokens_earned 
FROM dc_player_seasonal_stats 
WHERE season_id = 1 
ORDER BY total_tokens_earned DESC 
LIMIT 10;
```

### Most Popular Reward Source
```sql
SELECT source_type, source_id, COUNT(*) AS times_claimed, SUM(tokens_awarded) AS total_tokens
FROM dc_reward_transactions
WHERE season_id = 1
GROUP BY source_type, source_id
ORDER BY total_tokens DESC
LIMIT 10;
```

---

## Troubleshooting Checklist

- [ ] SQL scripts executed successfully
- [ ] Eluna script loaded (check server console)
- [ ] DBC files rebuilt and copied to server
- [ ] Custom token items created (or placeholder items configured)
- [ ] Seasonal vendor spawned (optional)
- [ ] Cache refreshing every 5 minutes
- [ ] Quest rewards triggering on completion
- [ ] World boss rewards splitting in groups
- [ ] Transactions logging to database
- [ ] Achievements appearing in-game

---

## Token Economy Planning

### Daily Maximum (Per Player)
- 4 Daily Quests: **200 tokens + 100 essence**
- 30 Dungeon Bosses: **300 tokens** (3 heroic runs)
- 1 World Boss: **15-150 tokens** (depends on group size)
- **TOTAL:** ~500-650 tokens/day

### Weekly Maximum (Per Player)
- Daily totals × 7: **3,500-4,550 tokens**
- 1 Weekly Dungeon: **150 tokens + 75 essence**
- 1 Weekly Raid: **200 tokens + 100 essence**
- Full Naxx 25: **550 tokens + 275 essence**
- **TOTAL:** ~4,400-5,450 tokens/week

### Seasonal Progression (12 Weeks)
- Casual (50% participation): **26,400 tokens** (5.5 weeks to "Seasonal Champion")
- Active (100% participation): **52,800 tokens** (2 weeks to "Seasonal Legend")

---

## NPC IDs Reference

### Seasonal System NPCs
| Entry | Name | Location | Purpose |
|-------|------|----------|---------|
| 100050 | Vault Curator Lyra | Mythic+ Hub | Great Vault Keeper |
| 100051 | Seasonal Quartermaster | Mythic+ Hub | Token Vendor |
| 99001 | Mythic Steward Alendra | Mythic+ Hub | Dungeon Teleporter |

### World Boss Entries
| Entry | Name | Respawn | Location |
|-------|------|---------|----------|
| 6109 | Azuregos | 2-3 days | Azshara |
| 18728 | Doomlord Kazzak (BC) | Daily | Hellfire Peninsula |
| 12397 | Lord Kazzak (Vanilla) | 4 days | Blasted Lands |
| 14887 | Ysondre | 5 days | Feralas |
| 14888 | Lethon | 5 days | Hinterlands |
| 14889 | Emeriss | 5 days | Duskwood |
| 14890 | Taerar | 5 days | Ashenvale |

### Event Boss Entries
| Entry | Name | Event | Respawn |
|-------|------|-------|---------|
| 25740 | Ahune | Midsummer | Daily (event only) |
| 23872 | Coren Direbrew | Brewfest | Daily (event only) |
| 23682 | Headless Horseman | Hallow's End | Daily (event only) |
| 16011 | Apothecary Hummel | Love is in the Air | Daily (event only) |

---

## File Changelog

**Last Updated:** Phase 1 Release  
**Next Update:** Phase 2 (Client Integration)

**Quick Links:**
- [Full Implementation Summary](PHASE_1_IMPLEMENTATION_SUMMARY.md)
- [Original Design Document](SEASON_SYSTEM_DESIGN.md)
- [Database Schema](dc_seasonal_rewards.sql)
