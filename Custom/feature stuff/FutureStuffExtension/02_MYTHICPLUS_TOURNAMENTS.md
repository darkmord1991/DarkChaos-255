# Mythic+ Tournament & Competitive Mode

**Priority:** A-Tier  
**Effort:** High (3-4 weeks)  
**Impact:** High  
**Target System:** `src/server/scripts/DC/MythicPlus/`

---

## Overview

Add competitive M+ features: scheduled tournaments, realm-first tracking, and organized guild competitions. Extends existing `MythicPlusRunManager` infrastructure.

---

## Current System Gaps

From `MythicPlusRunManager.h` analysis:
- No tournament registration/scheduling
- No realm-first tracking
- No guild competition support
- No prize distribution system
- Run history exists but lacks competitive scoring

---

## Tournament System Design

### Tournament Types
| Type | Description | Duration |
|------|-------------|----------|
| **Weekly Challenge** | Highest key + fastest time | 1 week |
| **Monthly Championship** | Aggregate scoring across dungeons | 1 month |
| **Seasonal Finals** | Top teams compete for prizes | End of season |
| **Dungeon Spotlight** | Single dungeon focus | 3 days |

### Tournament Structure
```
Tournament
├── Registration Phase (24-48 hours)
├── Competition Phase (variable)
│   ├── Qualification Runs
│   ├── Bracket Stages (optional)
│   └── Finals
└── Award Phase (automatic)
```

---

## Database Schema

```sql
-- Tournament definitions
CREATE TABLE dc_mythic_tournaments (
    tournament_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    tournament_name VARCHAR(100) NOT NULL,
    tournament_type ENUM('weekly', 'monthly', 'seasonal', 'spotlight') NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    dungeon_id INT UNSIGNED DEFAULT 0,  -- 0 = all dungeons
    min_keystone_level TINYINT UNSIGNED DEFAULT 15,
    registration_start TIMESTAMP NOT NULL,
    registration_end TIMESTAMP NOT NULL,
    competition_start TIMESTAMP NOT NULL,
    competition_end TIMESTAMP NOT NULL,
    status ENUM('upcoming', 'registration', 'active', 'completed', 'cancelled') DEFAULT 'upcoming',
    team_size TINYINT UNSIGNED DEFAULT 5,
    max_teams INT UNSIGNED DEFAULT 100,
    prize_pool TEXT,  -- JSON prize definitions
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Team registrations
CREATE TABLE dc_mythic_tournament_teams (
    team_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    tournament_id INT UNSIGNED NOT NULL,
    team_name VARCHAR(50) NOT NULL,
    guild_id INT UNSIGNED DEFAULT 0,
    captain_guid INT UNSIGNED NOT NULL,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    disqualified BOOLEAN DEFAULT FALSE,
    disqualification_reason TEXT,
    UNIQUE KEY (tournament_id, team_name),
    FOREIGN KEY (tournament_id) REFERENCES dc_mythic_tournaments(tournament_id)
);

-- Team members
CREATE TABLE dc_mythic_tournament_team_members (
    team_id INT UNSIGNED NOT NULL,
    player_guid INT UNSIGNED NOT NULL,
    role ENUM('captain', 'member', 'substitute') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (team_id, player_guid),
    FOREIGN KEY (team_id) REFERENCES dc_mythic_tournament_teams(team_id)
);

-- Tournament runs (competition entries)
CREATE TABLE dc_mythic_tournament_runs (
    run_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    tournament_id INT UNSIGNED NOT NULL,
    team_id INT UNSIGNED NOT NULL,
    dungeon_map_id INT UNSIGNED NOT NULL,
    keystone_level TINYINT UNSIGNED NOT NULL,
    completion_time INT UNSIGNED NOT NULL,  -- milliseconds
    deaths TINYINT UNSIGNED DEFAULT 0,
    affixes TEXT,  -- JSON array of active affixes
    score INT UNSIGNED NOT NULL,
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (tournament_id) REFERENCES dc_mythic_tournaments(tournament_id),
    FOREIGN KEY (team_id) REFERENCES dc_mythic_tournament_teams(team_id),
    KEY idx_tournament_score (tournament_id, score DESC)
);

-- Tournament standings (computed/cached)
CREATE TABLE dc_mythic_tournament_standings (
    tournament_id INT UNSIGNED NOT NULL,
    team_id INT UNSIGNED NOT NULL,
    rank_position INT UNSIGNED NOT NULL,
    total_score BIGINT UNSIGNED DEFAULT 0,
    best_run_id BIGINT UNSIGNED,
    runs_completed INT UNSIGNED DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tournament_id, team_id),
    KEY idx_tournament_rank (tournament_id, rank_position)
);

-- Prizes awarded
CREATE TABLE dc_mythic_tournament_prizes (
    prize_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    tournament_id INT UNSIGNED NOT NULL,
    team_id INT UNSIGNED NOT NULL,
    rank_achieved INT UNSIGNED NOT NULL,
    prize_type ENUM('item', 'title', 'mount', 'currency', 'achievement') NOT NULL,
    prize_entry INT UNSIGNED NOT NULL,  -- item_template.entry, title_id, spell_id, etc.
    prize_count INT UNSIGNED DEFAULT 1,
    awarded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    claimed BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (tournament_id) REFERENCES dc_mythic_tournaments(tournament_id)
);
```

---

## Tournament Manager Implementation

```cpp
class MythicTournamentManager
{
public:
    static MythicTournamentManager* instance();

    // Tournament lifecycle
    bool CreateTournament(const TournamentDefinition& def);
    bool StartRegistration(uint32 tournamentId);
    bool StartCompetition(uint32 tournamentId);
    bool EndTournament(uint32 tournamentId);
    bool CancelTournament(uint32 tournamentId, const std::string& reason);

    // Team management
    bool RegisterTeam(uint32 tournamentId, const std::string& teamName, 
                      ObjectGuid::LowType captainGuid, uint32 guildId = 0);
    bool AddTeamMember(uint32 teamId, ObjectGuid::LowType playerGuid, TeamRole role);
    bool RemoveTeamMember(uint32 teamId, ObjectGuid::LowType playerGuid);
    bool DisqualifyTeam(uint32 teamId, const std::string& reason);

    // Run recording
    bool RecordTournamentRun(uint32 tournamentId, uint32 teamId, 
                             const MythicPlusRunManager::InstanceState& state);
    uint32 CalculateRunScore(const MythicPlusRunManager::InstanceState& state);

    // Standings
    void UpdateStandings(uint32 tournamentId);
    std::vector<TournamentStanding> GetStandings(uint32 tournamentId, uint32 limit = 100);
    TournamentStanding* GetTeamStanding(uint32 tournamentId, uint32 teamId);

    // Prizes
    bool DistributePrizes(uint32 tournamentId);
    bool ClaimPrize(ObjectGuid::LowType playerGuid, uint32 prizeId);

    // Queries
    Tournament* GetTournament(uint32 tournamentId);
    std::vector<Tournament*> GetActiveTournaments();
    std::vector<Tournament*> GetUpcomingTournaments();
    Team* GetTeamByPlayer(uint32 tournamentId, ObjectGuid::LowType playerGuid);
    bool IsPlayerRegistered(uint32 tournamentId, ObjectGuid::LowType playerGuid);

    // Scheduled tasks
    void ProcessTournamentTransitions();  // Called by WorldScript::OnUpdate

private:
    MythicTournamentManager() = default;
    
    void LoadTournaments();
    void AnnounceRegistrationOpen(uint32 tournamentId);
    void AnnounceCompetitionStart(uint32 tournamentId);
    void AnnounceWinners(uint32 tournamentId);
    
    std::unordered_map<uint32, std::unique_ptr<Tournament>> _tournaments;
    std::unordered_map<uint32, std::unique_ptr<Team>> _teams;
};

#define sMythicTournament MythicTournamentManager::instance()
```

### Score Calculation
```cpp
uint32 MythicTournamentManager::CalculateRunScore(const MythicPlusRunManager::InstanceState& state)
{
    // Base score from keystone level
    uint32 baseScore = state.keystoneLevel * 10000;
    
    // Time bonus (par time varies by dungeon)
    uint32 parTime = GetDungeonParTime(state.mapId, state.keystoneLevel);
    uint32 actualTime = state.completedAt - state.startedAt;
    
    float timeRatio = static_cast<float>(parTime) / static_cast<float>(actualTime);
    uint32 timeBonus = static_cast<uint32>(baseScore * 0.3f * std::min(timeRatio, 1.5f));
    
    // Death penalty
    uint32 deathPenalty = state.deaths * 500;
    
    // Affix complexity bonus
    uint32 affixBonus = state.activeAffixes.size() * 1000;
    
    // +3 upgrade bonus (all 3 chests)
    uint32 upgradeBonus = 0;
    if (timeRatio >= 1.4f) upgradeBonus = 5000;  // +3
    else if (timeRatio >= 1.2f) upgradeBonus = 3000;  // +2
    else if (timeRatio >= 1.0f) upgradeBonus = 1000;  // +1
    
    return baseScore + timeBonus + affixBonus + upgradeBonus - deathPenalty;
}
```

---

## Realm-First Tracking

### Realm-First Categories
| Category | Description | Reward |
|----------|-------------|--------|
| Dungeon +20 | First to complete each dungeon at +20 | Title + Achievement |
| Dungeon +25 | First to complete each dungeon at +25 | Title + Mount |
| Season Champion | Highest aggregate score | Title + Cosmetics |

### Implementation
```cpp
class RealmFirstTracker
{
public:
    struct RealmFirst
    {
        uint32 category;
        uint32 dungeonMapId;
        uint8 keystoneLevel;
        uint32 achievingTeamId;
        ObjectGuid::LowType achievingPlayerGuid;
        time_t achievedAt;
        bool announced;
    };

    bool CheckRealmFirst(const MythicPlusRunManager::InstanceState& state)
    {
        uint32 category = GetRealmFirstCategory(state.mapId, state.keystoneLevel);
        if (!category)
            return false;

        // Check if already claimed
        if (IsRealmFirstClaimed(category, state.mapId))
            return false;

        // Record realm first
        RecordRealmFirst(category, state);
        AnnounceRealmFirst(category, state);
        GrantRealmFirstRewards(category, state);
        
        return true;
    }

    void AnnounceRealmFirst(uint32 category, const MythicPlusRunManager::InstanceState& state)
    {
        std::string dungeonName = GetDungeonName(state.mapId);
        std::string achiever = GetTeamDisplayName(state);
        
        std::ostringstream msg;
        msg << "|cFFFFD700[Realm First!]|r " << achiever 
            << " has achieved |cFF00FF00Realm First: " << dungeonName 
            << " +" << static_cast<int>(state.keystoneLevel) << "|r!";
        
        sWorld->SendServerMessage(SERVER_MSG_STRING, msg.str());
        
        // Discord webhook notification (if configured)
        SendDiscordNotification(category, state);
    }

private:
    std::unordered_map<uint64, RealmFirst> _realmFirsts;  // category+mapId -> RealmFirst
};
```

---

## Guild Competition

### Guild Leaderboard
```sql
-- Guild M+ aggregate stats
CREATE TABLE dc_mythic_guild_standings (
    guild_id INT UNSIGNED NOT NULL,
    season_id INT UNSIGNED NOT NULL,
    total_runs INT UNSIGNED DEFAULT 0,
    total_score BIGINT UNSIGNED DEFAULT 0,
    highest_key_completed TINYINT UNSIGNED DEFAULT 0,
    unique_participants INT UNSIGNED DEFAULT 0,
    rank_position INT UNSIGNED DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (guild_id, season_id),
    KEY idx_season_rank (season_id, rank_position)
);

-- Weekly guild competition
CREATE TABLE dc_mythic_guild_weekly (
    guild_id INT UNSIGNED NOT NULL,
    week_start TIMESTAMP NOT NULL,
    runs_completed INT UNSIGNED DEFAULT 0,
    aggregate_score BIGINT UNSIGNED DEFAULT 0,
    bonus_earned FLOAT DEFAULT 0,  -- XP/rep/token bonus multiplier
    PRIMARY KEY (guild_id, week_start)
);
```

### Guild Bonuses
| Rank | Weekly Bonus |
|------|--------------|
| 1st | +25% tokens, guild achievement |
| 2nd-3rd | +15% tokens |
| 4th-10th | +10% tokens |
| Top 25% | +5% tokens |

---

## Commands

### Player Commands
| Command | Description |
|---------|-------------|
| `.mythic tournament list` | Show active/upcoming tournaments |
| `.mythic tournament info <id>` | Tournament details |
| `.mythic tournament register <id> <teamName>` | Register team |
| `.mythic tournament invite <player>` | Invite to team |
| `.mythic tournament standings <id>` | View standings |
| `.mythic realmfirst` | Show unclaimed realm firsts |
| `.mythic guild` | Guild M+ standings |

### Admin Commands
| Command | Description |
|---------|-------------|
| `.mythic tournament create` | Create tournament |
| `.mythic tournament start <id>` | Force start |
| `.mythic tournament end <id>` | Force end |
| `.mythic tournament disqualify <teamId> <reason>` | Disqualify team |
| `.mythic tournament prizes <id>` | Distribute prizes |

---

## AIO Addon Integration

### Tournament UI
```lua
-- MythicTournament.lua
local TournamentFrame = AIO.AddAddon()

function TournamentFrame:Init()
    self.frame = CreateFrame("Frame", "DCMythicTournament", UIParent)
    self.frame:SetSize(600, 500)
    self.frame:SetPoint("CENTER")
    
    -- Tournament list
    self:CreateTournamentList()
    
    -- Team management
    self:CreateTeamPanel()
    
    -- Standings display
    self:CreateStandingsPanel()
    
    -- Realm first tracker
    self:CreateRealmFirstPanel()
end

function TournamentFrame:OnTournamentData(data)
    self.tournamentList:Clear()
    
    for _, tournament in ipairs(data.tournaments) do
        local entry = self.tournamentList:AddEntry()
        entry.name:SetText(tournament.name)
        entry.status:SetText(GetStatusColor(tournament.status) .. tournament.status)
        entry.teams:SetText(tournament.teamCount .. "/" .. tournament.maxTeams)
        entry.prize:SetText(tournament.prizePreview)
        entry.tournamentId = tournament.id
    end
end

function TournamentFrame:OnStandingsUpdate(data)
    self.standingsPanel:Clear()
    
    for rank, standing in ipairs(data.standings) do
        local row = self.standingsPanel:AddRow()
        row.rank:SetText("#" .. rank)
        row.team:SetText(standing.teamName)
        row.score:SetText(FormatScore(standing.totalScore))
        row.runs:SetText(standing.runsCompleted)
        row.best:SetText("+" .. standing.bestKey)
    end
end
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Schema | 2 days | Database tables, initial data |
| Manager | 1 week | TournamentManager implementation |
| Integration | 4 days | Hook into MythicPlusRunManager |
| RealmFirst | 3 days | Tracking and announcement |
| GuildComp | 3 days | Guild standings and bonuses |
| Commands | 2 days | Player and admin commands |
| UI | 1 week | AIO addon tournament interface |
| Testing | 1 week | End-to-end tournament flow |
| **Total** | **~4 weeks** | |

---

## Future Enhancements

1. **Bracket System** - Single/double elimination for finals
2. **Spectator Mode** - Watch live tournament runs
3. **Replay System** - Record and replay notable runs
4. **VOD Integration** - Link tournament runs to streams
5. **Qualifier System** - Multi-stage seasonal qualifiers
