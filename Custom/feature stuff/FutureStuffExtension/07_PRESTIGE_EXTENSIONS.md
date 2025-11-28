# Prestige System Extensions

**Priority:** A-Tier  
**Effort:** Medium (2 weeks)  
**Impact:** High  
**Target System:** `src/server/scripts/DC/Prestige/`

---

## Current System Analysis

Based on `dc_prestige_api.h`:
- Basic prestige level system exists
- Stat bonuses applied per prestige level
- Level requirements for prestige
- Core hooks in place

---

## Proposed Extensions

### 1. Prestige Talents

A talent tree system that unlocks as players prestige higher.

```sql
-- Talent definitions
CREATE TABLE dc_prestige_talents (
    talent_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    talent_name VARCHAR(100) NOT NULL,
    talent_description TEXT,
    talent_icon INT UNSIGNED NOT NULL,  -- Icon spell ID for display
    tier TINYINT UNSIGNED NOT NULL,     -- Tier 1-5
    position TINYINT UNSIGNED NOT NULL, -- Position in tier (1-4)
    max_ranks TINYINT UNSIGNED DEFAULT 3,
    prestige_required TINYINT UNSIGNED NOT NULL,  -- Min prestige to unlock tier
    prerequisite_id INT UNSIGNED DEFAULT 0,  -- Must have this talent first
    is_exclusive_group TINYINT UNSIGNED DEFAULT 0  -- Can only pick one from group
);

-- Talent effects per rank
CREATE TABLE dc_prestige_talent_effects (
    effect_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    talent_id INT UNSIGNED NOT NULL,
    rank TINYINT UNSIGNED NOT NULL,
    effect_type ENUM('stat', 'aura', 'spell', 'cooldown_reduction', 'resource', 'proc') NOT NULL,
    effect_value FLOAT NOT NULL,
    effect_param INT UNSIGNED DEFAULT 0,  -- Stat type, spell ID, etc.
    FOREIGN KEY (talent_id) REFERENCES dc_prestige_talents(talent_id)
);

-- Player talent selections
CREATE TABLE dc_prestige_player_talents (
    player_guid INT UNSIGNED NOT NULL,
    talent_id INT UNSIGNED NOT NULL,
    current_rank TINYINT UNSIGNED DEFAULT 1,
    PRIMARY KEY (player_guid, talent_id),
    FOREIGN KEY (talent_id) REFERENCES dc_prestige_talents(talent_id)
);
```

#### Sample Talent Trees

**Power Tree:**
```sql
INSERT INTO dc_prestige_talents (talent_name, talent_description, tier, position, prestige_required) VALUES
('Empowered Strikes', '+2/4/6% damage to all attacks', 1, 1, 1),
('Vital Force', '+3/6/9% max health', 1, 2, 1),
('Mana Efficiency', '+5/10/15% mana regeneration', 1, 3, 1),
('Swift Recovery', '+2/4/6% healing received', 1, 4, 1),

('Critical Mastery', '+3/6/9% critical strike chance', 2, 1, 3),
('Armor Penetration', '+5/10/15 armor penetration', 2, 2, 3),
('Spell Haste', '+2/4/6% spell haste', 2, 3, 3),
('Resilience', '+3/6/9% damage reduction from players', 2, 4, 3),

('Killing Spree', 'Killing an enemy grants +5% damage for 10s, stacking', 3, 1, 5),
('Last Stand', 'Below 20% health, gain +15% damage', 3, 2, 5),
('Execute Mastery', '+10/20/30% damage to targets below 20% health', 3, 3, 5);
```

**Utility Tree:**
```sql
INSERT INTO dc_prestige_talents (talent_name, talent_description, tier, position, prestige_required) VALUES
('Fast Traveler', '+5/10/15% movement speed', 1, 1, 1),
('Gathering Expert', '+10/20/30% gathering speed', 1, 2, 1),
('Reputation Boost', '+5/10/15% reputation gains', 1, 3, 1),
('Experience Wisdom', '+2/4/6% experience gains', 1, 4, 1),

('Hearthstone Master', '-5/10/15 minute hearthstone cooldown', 2, 1, 3),
('Mount Speed', '+5/10% mounted speed', 2, 2, 3),
('Bag Space', '+2/4/6 extra bag slots (virtual)', 2, 3, 3);
```

---

### 2. Prestige Challenges

Special challenges that require high prestige to attempt.

```sql
CREATE TABLE dc_prestige_challenges (
    challenge_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    challenge_name VARCHAR(100) NOT NULL,
    challenge_type ENUM('solo', 'group', 'raid', 'timed', 'survival') NOT NULL,
    prestige_required TINYINT UNSIGNED NOT NULL,
    difficulty ENUM('normal', 'hard', 'nightmare') NOT NULL,
    instance_id INT UNSIGNED DEFAULT 0,  -- Map ID for instanced challenges
    time_limit_seconds INT UNSIGNED DEFAULT 0,  -- 0 = no limit
    description TEXT,
    reward_type ENUM('currency', 'item', 'title', 'cosmetic', 'talent_point') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1,
    weekly_lockout BOOLEAN DEFAULT TRUE,
    attempts_per_week TINYINT UNSIGNED DEFAULT 0  -- 0 = unlimited
);

CREATE TABLE dc_prestige_challenge_progress (
    player_guid INT UNSIGNED NOT NULL,
    challenge_id INT UNSIGNED NOT NULL,
    best_time_seconds INT UNSIGNED DEFAULT 0,
    completions INT UNSIGNED DEFAULT 0,
    last_attempt TIMESTAMP NULL,
    weekly_completions TINYINT UNSIGNED DEFAULT 0,
    weekly_reset TIMESTAMP NULL,
    PRIMARY KEY (player_guid, challenge_id)
);
```

#### Challenge Types

**Solo Challenges:**
- "Gauntlet of Pain" - Survive waves of increasingly difficult mobs
- "Speed Demon" - Complete dungeon solo in time limit
- "Glass Cannon" - Kill boss with 1 HP

**Group Challenges:**
- "Synchronized" - Party must deal equal damage
- "No Deaths" - Complete dungeon with zero deaths
- "Undergeared" - Complete with item level restrictions

---

### 3. Prestige Cosmetics

Visual rewards unlocked at prestige milestones.

```sql
CREATE TABLE dc_prestige_cosmetics (
    cosmetic_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    prestige_required TINYINT UNSIGNED NOT NULL,
    cosmetic_type ENUM('aura', 'title', 'portrait_frame', 'chat_icon', 'name_color', 'ground_effect') NOT NULL,
    cosmetic_name VARCHAR(100) NOT NULL,
    cosmetic_value VARCHAR(255) NOT NULL,  -- Spell ID, title text, color hex, etc.
    description TEXT,
    is_exclusive BOOLEAN DEFAULT FALSE  -- Can only equip one of this type
);

CREATE TABLE dc_prestige_player_cosmetics (
    player_guid INT UNSIGNED NOT NULL,
    cosmetic_id INT UNSIGNED NOT NULL,
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_equipped BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (player_guid, cosmetic_id)
);
```

#### Cosmetic Examples

| Prestige | Cosmetic | Description |
|----------|----------|-------------|
| 1 | Bronze Aura | Subtle bronze glow |
| 3 | Silver Aura | Brighter silver particles |
| 5 | Title: "Veteran" | Display title |
| 7 | Gold Aura | Striking gold effect |
| 10 | Title: "Elite" | Elite title |
| 10 | Name Color: Blue | Blue name in chat |
| 15 | Ground Effect | Footsteps leave trails |
| 20 | Title: "Legend" | Legendary title |
| 20 | Prismatic Aura | Shifting rainbow effect |

---

### 4. Prestige Milestones

Major achievements at key prestige levels.

```cpp
struct PrestigeMilestone
{
    uint8 prestige;
    std::string rewardType;
    uint32 rewardEntry;
    std::string description;
    bool claimRequired;  // Player must manually claim
};

std::vector<PrestigeMilestone> MILESTONES = {
    { 1, "talent_points", 1, "Unlock Prestige Talents", false },
    { 3, "challenge", 1, "Unlock Prestige Challenges", false },
    { 5, "mount", 100000, "Prestige Charger Mount", true },
    { 10, "title", 1, "Title: The Prestigious", true },
    { 10, "stat_boost", 500, "+500 to all stats permanently", false },
    { 15, "pet", 100001, "Prestige Companion Pet", true },
    { 20, "transmog_set", 1, "Full Prestige Armor Set", true },
    { 25, "custom_spell", 1, "Unique Prestige Ability", true },
};
```

---

### 5. Alt Synergy System

Account-wide benefits based on total prestige across characters.

```sql
CREATE TABLE dc_prestige_account (
    account_id INT UNSIGNED PRIMARY KEY,
    total_prestige_earned INT UNSIGNED DEFAULT 0,  -- Sum of all characters
    highest_prestige TINYINT UNSIGNED DEFAULT 0,   -- Highest single character
    alt_bonus_unlocked TINYINT UNSIGNED DEFAULT 0, -- Current alt bonus tier
    last_calculated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dc_prestige_alt_bonuses (
    tier TINYINT UNSIGNED PRIMARY KEY,
    total_prestige_required INT UNSIGNED NOT NULL,
    xp_boost_percent FLOAT DEFAULT 0,
    reputation_boost_percent FLOAT DEFAULT 0,
    drop_rate_boost_percent FLOAT DEFAULT 0,
    free_talent_points TINYINT UNSIGNED DEFAULT 0
);

INSERT INTO dc_prestige_alt_bonuses VALUES
(1, 5, 10, 5, 0, 1),
(2, 15, 20, 10, 5, 2),
(3, 30, 35, 15, 10, 3),
(4, 50, 50, 20, 15, 5),
(5, 100, 75, 30, 25, 8);
```

```cpp
class PrestigeAltSynergy
{
public:
    static void RecalculateAccountBonus(uint32 accountId)
    {
        // Sum prestige across all characters
        auto result = CharacterDatabase.Query(
            "SELECT SUM(prestige_level), MAX(prestige_level) "
            "FROM dc_character_prestige WHERE account_id = {}",
            accountId);
        
        uint32 totalPrestige = result->Fetch()[0].Get<uint32>();
        uint8 highestPrestige = result->Fetch()[1].Get<uint8>();
        
        // Determine tier
        uint8 tier = 0;
        for (auto& bonus : sPrestigeAltBonuses)
        {
            if (totalPrestige >= bonus.required)
                tier = bonus.tier;
        }
        
        // Update account
        CharacterDatabase.Execute(
            "REPLACE INTO dc_prestige_account VALUES ({}, {}, {}, {}, NOW())",
            accountId, totalPrestige, highestPrestige, tier);
    }
    
    static PrestigeAltBonus GetAccountBonus(uint32 accountId)
    {
        auto result = CharacterDatabase.Query(
            "SELECT alt_bonus_unlocked FROM dc_prestige_account WHERE account_id = {}",
            accountId);
        
        if (!result)
            return {};
        
        uint8 tier = result->Fetch()[0].Get<uint8>();
        return sPrestigeAltBonuses[tier];
    }
};
```

---

### 6. Prestige Manager Enhancements

```cpp
class PrestigeManager
{
public:
    static PrestigeManager* instance();

    // Existing functionality
    uint8 GetPrestige(ObjectGuid::LowType playerGuid);
    bool SetPrestige(ObjectGuid::LowType playerGuid, uint8 prestige);
    
    // New: Talent System
    uint8 GetAvailableTalentPoints(ObjectGuid::LowType playerGuid);
    uint8 GetSpentTalentPoints(ObjectGuid::LowType playerGuid);
    bool LearnTalent(ObjectGuid::LowType playerGuid, uint32 talentId);
    bool UnlearnTalent(ObjectGuid::LowType playerGuid, uint32 talentId);
    bool ResetTalents(ObjectGuid::LowType playerGuid, bool refund = true);
    std::vector<PlayerTalent> GetPlayerTalents(ObjectGuid::LowType playerGuid);
    void ApplyTalentEffects(Player* player);
    
    // New: Challenges
    bool CanAttemptChallenge(ObjectGuid::LowType playerGuid, uint32 challengeId);
    bool StartChallenge(ObjectGuid::LowType playerGuid, uint32 challengeId);
    void CompleteChallenge(ObjectGuid::LowType playerGuid, uint32 challengeId, uint32 timeSeconds);
    void FailChallenge(ObjectGuid::LowType playerGuid, uint32 challengeId);
    
    // New: Cosmetics
    std::vector<PrestigeCosmetic> GetUnlockedCosmetics(ObjectGuid::LowType playerGuid);
    bool EquipCosmetic(ObjectGuid::LowType playerGuid, uint32 cosmeticId);
    bool UnequipCosmetic(ObjectGuid::LowType playerGuid, uint32 cosmeticId);
    void ApplyEquippedCosmetics(Player* player);
    
    // New: Alt Synergy
    PrestigeAltBonus GetAltBonus(uint32 accountId);
    void RecalculateAltBonus(uint32 accountId);
    
    // Events
    void OnPrestigeUp(Player* player, uint8 oldPrestige, uint8 newPrestige);
    void OnLogin(Player* player);

private:
    void CheckMilestones(Player* player, uint8 prestige);
    void GrantMilestoneReward(Player* player, const PrestigeMilestone& milestone);
    
    std::unordered_map<uint32, PrestigeTalent> _talents;
    std::unordered_map<uint32, PrestigeChallenge> _challenges;
    std::unordered_map<uint32, PrestigeCosmetic> _cosmetics;
};

#define sPrestige PrestigeManager::instance()
```

---

### 7. Talent Application

```cpp
void PrestigeManager::ApplyTalentEffects(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    auto talents = GetPlayerTalents(guid);
    
    for (const auto& pt : talents)
    {
        const auto& talent = _talents[pt.talentId];
        
        for (const auto& effect : talent.effects)
        {
            if (effect.rank > pt.currentRank)
                continue;
            
            switch (effect.type)
            {
                case EFFECT_STAT:
                    ApplyStatBonus(player, effect.param, effect.value);
                    break;
                    
                case EFFECT_AURA:
                    player->AddAura(effect.param, player);
                    break;
                    
                case EFFECT_SPELL:
                    player->learnSpell(effect.param);
                    break;
                    
                case EFFECT_COOLDOWN_REDUCTION:
                    // Applied via spell script
                    break;
                    
                case EFFECT_RESOURCE:
                    ApplyResourceBonus(player, effect.param, effect.value);
                    break;
                    
                case EFFECT_PROC:
                    RegisterProcEffect(player, effect.param, effect.value);
                    break;
            }
        }
    }
}

void PrestigeManager::ApplyStatBonus(Player* player, uint32 statType, float value)
{
    // Using custom aura approach for dynamic stats
    int32 bonus = static_cast<int32>(value);
    
    switch (statType)
    {
        case STAT_STRENGTH:
        case STAT_AGILITY:
        case STAT_STAMINA:
        case STAT_INTELLECT:
        case STAT_SPIRIT:
            player->HandleStatModifier(UnitMods(UNIT_MOD_STAT_START + statType), 
                TOTAL_VALUE, float(bonus), true);
            break;
    }
}
```

---

## AIO Addon Interface

```lua
-- PrestigeTalents.lua
local TalentFrame = AIO.AddAddon()

function TalentFrame:Init()
    self.frame = CreateFrame("Frame", "DCPrestigeTalents", UIParent)
    self.frame:SetSize(500, 400)
    self.frame:SetPoint("CENTER")
    
    -- Create talent tree
    self:CreateTalentTree()
    
    -- Point counter
    self.pointsText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.pointsText:SetPoint("TOP", 0, -10)
    
    -- Reset button
    self.resetBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    self.resetBtn:SetSize(100, 25)
    self.resetBtn:SetPoint("BOTTOM", 0, 10)
    self.resetBtn:SetText("Reset Talents")
end

function TalentFrame:CreateTalentTree()
    self.talents = {}
    
    -- 5 tiers, 4 positions each
    for tier = 1, 5 do
        for pos = 1, 4 do
            local btn = CreateFrame("Button", nil, self.frame)
            btn:SetSize(50, 50)
            btn:SetPoint("TOPLEFT", 50 + (pos-1)*100, -50 - (tier-1)*70)
            
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints()
            
            btn.border = btn:CreateTexture(nil, "OVERLAY")
            btn.border:SetPoint("CENTER")
            btn.border:SetSize(54, 54)
            btn.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            
            btn.rank = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.rank:SetPoint("BOTTOMRIGHT", -2, 2)
            
            btn.tier = tier
            btn.pos = pos
            
            btn:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    TalentFrame:LearnTalent(self.talentId)
                elseif button == "RightButton" then
                    TalentFrame:UnlearnTalent(self.talentId)
                end
            end)
            
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                TalentFrame:ShowTalentTooltip(self.talentId)
            end)
            
            self.talents[tier .. "_" .. pos] = btn
        end
    end
end

function TalentFrame:Update(data)
    self.pointsText:SetText("Talent Points: " .. data.available .. " / " .. data.total)
    
    for _, talent in ipairs(data.talents) do
        local btn = self.talents[talent.tier .. "_" .. talent.position]
        if btn then
            btn.talentId = talent.id
            btn.icon:SetTexture(talent.icon)
            btn.rank:SetText(talent.currentRank .. "/" .. talent.maxRanks)
            
            -- Color based on state
            if talent.currentRank > 0 then
                btn.icon:SetDesaturated(false)
                btn.border:SetVertexColor(1, 0.8, 0)  -- Gold for learned
            elseif talent.canLearn then
                btn.icon:SetDesaturated(false)
                btn.border:SetVertexColor(0.2, 1, 0.2)  -- Green for available
            else
                btn.icon:SetDesaturated(true)
                btn.border:SetVertexColor(0.5, 0.5, 0.5)  -- Gray for locked
            end
        end
    end
end
```

---

## GM Commands

```cpp
// .prestige talent add <player> <talent_id> [rank]
// .prestige talent remove <player> <talent_id>
// .prestige talent reset <player>
// .prestige talent list <player>
// .prestige challenge start <player> <challenge_id>
// .prestige challenge complete <player> <challenge_id> <time>
// .prestige cosmetic give <player> <cosmetic_id>
// .prestige cosmetic equip <player> <cosmetic_id>
// .prestige recalc <account_id>
```

---

## Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Schema | 2 days | Tables, indexes, sample data |
| Talents | 4 days | Learning, effects, application |
| Challenges | 3 days | Start, complete, rewards |
| Cosmetics | 2 days | Unlock, equip, visual application |
| Alt Synergy | 2 days | Account calculation, bonuses |
| UI | 3 days | Talent tree addon interface |
| Testing | 2 days | Full system testing |
| **Total** | **~2.5 weeks** | |

---

## Integration Points

- **ItemUpgrades**: Prestige talents affect upgrade costs
- **Mythic+**: Prestige challenges include M+ runs
- **Seasons**: Cosmetics available seasonally
- **Hotspots**: Prestige affects hotspot XP bonuses
