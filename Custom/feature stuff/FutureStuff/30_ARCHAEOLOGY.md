# Archaeology / Relic Discovery System

**Priority:** C5 (Fun Project)  
**Effort:** Medium (3-4 weeks)  
**Impact:** Medium  
**Base:** Custom System (No Cataclysm dependency)

---

## Overview

A custom archaeology-style exploration system where players discover ancient relics, artifacts, and secrets throughout Azeroth. Unlike Cataclysm's archaeology, this is a treasure-hunting adventure system focused on exploration and discovery.

---

## Why It Fits DarkChaos-255

### Design Goals
| Goal | Implementation |
|------|----------------|
| Exploration reward | Discover dig sites |
| Alt-friendly | Account-wide progress |
| Collection appeal | Rare artifacts |
| Lore immersion | Story fragments |

### Integration Points
| System | Integration |
|--------|-------------|
| **Seasons** | Season-exclusive artifacts |
| **Collections** | Relic collection tab |
| **Achievements** | Discovery achievements |
| **Item Upgrades** | Artifact materials |
| **Custom Zones** | Zone-specific relics |

---

## Core Mechanics

### Discovery System
1. **Dig Sites** spawn in zones based on level
2. Players use **Survey** ability to locate relics
3. Relics are **solved** by collecting fragments
4. Completed artifacts grant **rewards** and **lore**

### Survey Mechanic
- 30 second cooldown ability
- Shows direction to nearest relic
- Distance indicator (Hot/Warm/Cold)
- 5 surveys to locate a relic

### Fragment Collection
- Each artifact needs 50-200 fragments
- Fragments specific to civilization types
- Bonus fragments from rare nodes

---

## Civilizations & Artifacts

### Civilization Types
| Civilization | Zones | Fragment Color |
|--------------|-------|----------------|
| Titan | Storm Peaks, Ulduar | Gold |
| Vrykul | Howling Fjord, Icecrown | Blue |
| Troll | Zul'Drak, Grizzly Hills | Green |
| Nerubian | Dragonblight, Azjol-Nerub | Purple |
| Night Elf | Crystalsong, Ashenvale | Silver |
| Dwarven | Northrend, Eastern Kingdoms | Bronze |

### Artifact Tiers
| Tier | Fragments | Reward Type |
|------|-----------|-------------|
| Common | 50 | Vendor gold, lore |
| Uncommon | 100 | Toys, vanity items |
| Rare | 150 | Mounts, pets |
| Epic | 200 | Weapons, unique items |
| Legendary | 300 | One-of-a-kind rewards |

---

## Database Schema

```sql
-- Civilization definitions
CREATE TABLE dc_archaeology_civs (
    civ_id INT UNSIGNED PRIMARY KEY,
    civ_name VARCHAR(50) NOT NULL,
    fragment_item INT UNSIGNED NOT NULL, -- Item ID for fragments
    color_code VARCHAR(10) DEFAULT 'ffffff',
    required_level TINYINT UNSIGNED DEFAULT 1
);

-- Dig site definitions
CREATE TABLE dc_archaeology_sites (
    site_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    civ_id INT UNSIGNED NOT NULL,
    zone_id INT UNSIGNED NOT NULL,
    site_name VARCHAR(100) NOT NULL,
    center_x FLOAT NOT NULL,
    center_y FLOAT NOT NULL,
    center_z FLOAT NOT NULL,
    radius FLOAT DEFAULT 50.0,
    min_level TINYINT UNSIGNED DEFAULT 1,
    max_nodes TINYINT UNSIGNED DEFAULT 6,
    respawn_hours INT UNSIGNED DEFAULT 24,
    FOREIGN KEY (civ_id) REFERENCES dc_archaeology_civs(civ_id)
);

-- Artifact definitions
CREATE TABLE dc_archaeology_artifacts (
    artifact_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    civ_id INT UNSIGNED NOT NULL,
    artifact_name VARCHAR(100) NOT NULL,
    artifact_tier ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') NOT NULL,
    fragments_needed INT UNSIGNED NOT NULL,
    reward_type ENUM('item', 'mount', 'pet', 'toy', 'title', 'achievement') NOT NULL,
    reward_entry INT UNSIGNED NOT NULL,
    lore_text TEXT,
    flavor_text TEXT,
    model_id INT UNSIGNED DEFAULT 0,
    is_seasonal BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (civ_id) REFERENCES dc_archaeology_civs(civ_id)
);

-- Player progress
CREATE TABLE dc_archaeology_player (
    player_guid BIGINT UNSIGNED NOT NULL,
    civ_id INT UNSIGNED NOT NULL,
    fragments_collected INT UNSIGNED DEFAULT 0,
    artifacts_completed INT UNSIGNED DEFAULT 0,
    current_artifact INT UNSIGNED DEFAULT 0,
    current_progress INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (player_guid, civ_id),
    FOREIGN KEY (civ_id) REFERENCES dc_archaeology_civs(civ_id)
);

-- Player discovered artifacts
CREATE TABLE dc_archaeology_discoveries (
    discovery_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_guid BIGINT UNSIGNED NOT NULL,
    artifact_id INT UNSIGNED NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    season_id INT UNSIGNED DEFAULT 0,
    UNIQUE KEY unique_discovery (player_guid, artifact_id),
    FOREIGN KEY (artifact_id) REFERENCES dc_archaeology_artifacts(artifact_id)
);

-- Active dig sites per player
CREATE TABLE dc_archaeology_active_sites (
    player_guid BIGINT UNSIGNED NOT NULL,
    site_id INT UNSIGNED NOT NULL,
    nodes_remaining TINYINT UNSIGNED DEFAULT 6,
    activated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_guid, site_id),
    FOREIGN KEY (site_id) REFERENCES dc_archaeology_sites(site_id)
);

-- Populate civilizations
INSERT INTO dc_archaeology_civs VALUES
(1, 'Titan', 900100, 'ffd700', 170),
(2, 'Vrykul', 900101, '1e90ff', 150),
(3, 'Troll', 900102, '32cd32', 100),
(4, 'Nerubian', 900103, '9932cc', 120),
(5, 'Night Elf', 900104, 'c0c0c0', 80),
(6, 'Dwarven', 900105, 'cd7f32', 60);

-- Sample artifacts
INSERT INTO dc_archaeology_artifacts (civ_id, artifact_name, artifact_tier, fragments_needed, reward_type, reward_entry, lore_text) VALUES
(1, 'Disc of the Makers', 'legendary', 300, 'mount', 900200, 'An ancient disc used by the Titans to survey Azeroth...'),
(1, 'Keeper\'s Blessing Stone', 'rare', 150, 'toy', 900201, 'When activated, grants a temporary blessing of the Titans.'),
(2, 'Vrykul Warhorn', 'uncommon', 100, 'toy', 900202, 'A massive horn that echoes across the frozen north.'),
(3, 'Zandalari Idol', 'rare', 150, 'pet', 900203, 'A miniature idol that seems to have a mind of its own.'),
(4, 'Nerubian Husk Fragment', 'common', 50, 'item', 900204, 'A piece of ancient nerubian carapace.'),
(5, 'Moonwell Shard', 'epic', 200, 'item', 900205, 'Contains residual lunar magic.');
```

---

## Implementation

### Survey System
```cpp
class dc_archaeology_survey : public SpellScript
{
    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetCaster()->ToPlayer();
        if (!player)
            return;

        // Find nearest active dig site
        auto site = sArchaeologyMgr->GetNearestDigSite(player);
        if (!site)
        {
            player->GetSession()->SendNotification("No dig sites nearby.");
            return;
        }

        // Calculate direction and distance
        float distance = player->GetDistance2d(site->centerX, site->centerY);
        float angle = player->GetAngle(site->centerX, site->centerY);

        // Spawn indicator based on distance
        if (distance < 10.0f)
        {
            // HOT - Spawn dig spot
            SpawnDigSpot(player, site);
            player->GetSession()->SendNotification("|cffff0000HOT! Dig here!|r");
        }
        else if (distance < 30.0f)
        {
            // WARM - Yellow indicator
            SpawnSurveyIndicator(player, angle, SURVEY_WARM);
            player->GetSession()->SendNotification("|cffffff00Warm - Getting closer!|r");
        }
        else
        {
            // COLD - Red indicator
            SpawnSurveyIndicator(player, angle, SURVEY_COLD);
            player->GetSession()->SendNotification("|cff00ff00Cold - Keep searching.|r");
        }
    }

    void SpawnSurveyIndicator(Player* player, float angle, uint32 type)
    {
        // Spawn survey telescope pointing in direction
        float x, y, z;
        player->GetClosePoint(x, y, z, 2.0f, angle);
        
        // Visual indicator (telescope or flag)
        uint32 goEntry = type == SURVEY_WARM ? GO_SURVEY_YELLOW : GO_SURVEY_RED;
        player->SummonGameObject(goEntry, x, y, z, angle, 0, 0, 0, 0, 10);
    }

    void SpawnDigSpot(Player* player, DigSiteData* site)
    {
        // Spawn the actual dig spot
        float x = site->centerX + frand(-5.0f, 5.0f);
        float y = site->centerY + frand(-5.0f, 5.0f);
        float z = player->GetMapHeight(x, y, player->GetPositionZ());
        
        if (auto* go = player->SummonGameObject(GO_DIG_SPOT, x, y, z, 0, 0, 0, 0, 0, 30))
        {
            // Store site reference for looting
            go->SetOwnerGUID(player->GetGUID());
            go->AI()->SetData(DATA_SITE_ID, site->siteId);
        }
    }
};
```

### Fragment Collection
```cpp
class dc_archaeology_dig_spot : public GameObjectScript
{
public:
    dc_archaeology_dig_spot() : GameObjectScript("dc_archaeology_dig_spot") { }

    bool OnGossipHello(Player* player, GameObject* go) override
    {
        if (go->GetOwnerGUID() != player->GetGUID())
        {
            player->GetSession()->SendNotification("This isn't your dig spot!");
            return true;
        }

        uint32 siteId = go->AI()->GetData(DATA_SITE_ID);
        auto site = sArchaeologyMgr->GetSite(siteId);
        if (!site)
            return true;

        // Award fragments
        uint32 baseFragments = urand(3, 6);
        uint32 bonusFragments = 0;
        
        // Chance for bonus
        if (roll_chance_f(15.0f))
        {
            bonusFragments = urand(2, 4);
            player->GetSession()->SendNotification("|cffffd700Rare find! Bonus fragments!|r");
        }

        uint32 totalFragments = baseFragments + bonusFragments;
        uint32 fragmentItem = GetFragmentItemForCiv(site->civId);
        
        player->AddItem(fragmentItem, totalFragments);
        player->GetSession()->SendNotification("You collected %u %s fragments.", totalFragments, GetCivName(site->civId).c_str());

        // Update progress
        sArchaeologyMgr->AddFragments(player->GetGUID(), site->civId, totalFragments);

        // Check for artifact completion
        sArchaeologyMgr->CheckArtifactProgress(player);

        // Reduce nodes at site
        sArchaeologyMgr->UseNode(player->GetGUID(), siteId);

        // Despawn dig spot
        go->Delete();

        return true;
    }
};
```

### Artifact Solving
```cpp
class dc_archaeology_solve : public PlayerScript
{
public:
    dc_archaeology_solve() : PlayerScript("dc_archaeology_solve") { }

    void OnSolveArtifact(Player* player, uint32 civId)
    {
        auto progress = sArchaeologyMgr->GetPlayerProgress(player->GetGUID(), civId);
        auto artifact = sArchaeologyMgr->GetCurrentArtifact(player->GetGUID(), civId);
        
        if (!artifact || progress->currentProgress < artifact->fragmentsNeeded)
            return;

        // Consume fragments
        uint32 fragmentItem = GetFragmentItemForCiv(civId);
        player->DestroyItemCount(fragmentItem, artifact->fragmentsNeeded, true);

        // Grant reward
        switch (artifact->rewardType)
        {
            case REWARD_ITEM:
                player->AddItem(artifact->rewardEntry, 1);
                break;
            case REWARD_MOUNT:
                player->LearnSpell(artifact->rewardEntry, false);
                break;
            case REWARD_PET:
                player->LearnSpell(artifact->rewardEntry, false);
                break;
            case REWARD_TOY:
                player->AddItem(artifact->rewardEntry, 1);
                break;
            case REWARD_TITLE:
                player->SetTitle(sCharTitlesStore.LookupEntry(artifact->rewardEntry));
                break;
        }

        // Record discovery
        sArchaeologyMgr->RecordDiscovery(player->GetGUID(), artifact->artifactId);

        // Announce rare finds
        if (artifact->tier >= TIER_RARE)
        {
            sWorld->SendWorldText(LANG_ARCHAEOLOGY_DISCOVERY, 
                player->GetName().c_str(), artifact->artifactName.c_str());
        }

        // Display lore
        SendLoreWindow(player, artifact);

        // Start next artifact
        sArchaeologyMgr->StartNextArtifact(player->GetGUID(), civId);
    }
};
```

---

## AIO Addon Interface

```lua
-- ArchaeologyFrame.lua
local ArchFrame = AIO.AddAddon()

function ArchFrame:Init()
    self.frame = CreateFrame("Frame", "DCArchFrame", UIParent)
    self.frame:SetSize(500, 400)
    self.frame:SetPoint("CENTER")
    
    -- Tabs for each civilization
    self:CreateCivTabs()
    
    -- Current artifact display
    self:CreateArtifactDisplay()
    
    -- Progress bars
    self:CreateProgressBars()
    
    -- Solve button
    self:CreateSolveButton()
    
    -- Discovery log
    self:CreateDiscoveryLog()
end

function ArchFrame:CreateArtifactDisplay()
    self.artifactFrame = CreateFrame("Frame", nil, self.frame)
    self.artifactFrame:SetSize(200, 200)
    self.artifactFrame:SetPoint("TOPLEFT", 20, -60)
    
    -- 3D model
    self.model = CreateFrame("PlayerModel", nil, self.artifactFrame)
    self.model:SetSize(150, 150)
    self.model:SetPoint("CENTER")
    
    -- Name
    self.artifactName = self.artifactFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.artifactName:SetPoint("BOTTOM", 0, 10)
    
    -- Tier indicator
    self.tierText = self.artifactFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.tierText:SetPoint("TOP", self.artifactName, "BOTTOM", 0, -5)
end

function ArchFrame:CreateProgressBars()
    self.progressBars = {}
    
    for i = 1, 6 do
        local bar = CreateFrame("StatusBar", nil, self.frame)
        bar:SetSize(200, 20)
        bar:SetPoint("TOPLEFT", 250, -60 - (i-1) * 30)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetMinMaxValues(0, 100)
        
        bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bar.text:SetPoint("CENTER")
        
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetColorTexture(0.1, 0.1, 0.1)
        
        self.progressBars[i] = bar
    end
end

function ArchFrame:UpdateProgress(data)
    for i, civ in ipairs(data.civilizations) do
        local bar = self.progressBars[i]
        if bar then
            bar:SetMinMaxValues(0, civ.needed)
            bar:SetValue(civ.current)
            bar.text:SetText(civ.name .. ": " .. civ.current .. "/" .. civ.needed)
            
            -- Color by tier
            local color = GetTierColor(civ.tier)
            bar:SetStatusBarColor(color.r, color.g, color.b)
        end
    end
    
    -- Update artifact display
    if data.currentArtifact then
        self.artifactName:SetText(data.currentArtifact.name)
        self.tierText:SetText(GetTierText(data.currentArtifact.tier))
        if data.currentArtifact.model > 0 then
            self.model:SetModel(data.currentArtifact.model)
        end
    end
end
```

---

## Commands

| Command | Description |
|---------|-------------|
| `.arch survey` | Use survey ability |
| `.arch progress` | View current progress |
| `.arch solve [civ]` | Solve current artifact |
| `.arch log` | View discovery history |
| `.arch sites` | Show active dig sites |

---

## Seasonal Integration

### Season-Exclusive Artifacts
- Each season adds 1-2 exclusive artifacts per civilization
- Time-limited availability
- Unique cosmetic rewards

### Example Season Artifacts
| Season | Civilization | Artifact | Reward |
|--------|--------------|----------|--------|
| 1 | Titan | First Watcher's Eye | Pet |
| 1 | Vrykul | Storm King's Chalice | Toy |
| 2 | Troll | Loa's Blessing | Title |
| 2 | Nerubian | Aqir Husk | Mount |

---

## Timeline

| Phase | Duration |
|-------|----------|
| Database design | 2 days |
| Core systems | 5 days |
| Survey mechanic | 3 days |
| Fragment/Solve | 3 days |
| Dig site spawns | 2 days |
| AIO addon | 4 days |
| Content (artifacts) | 3 days |
| Testing | 3 days |
| **Total** | **~3.5 weeks** |

---

## Future Enhancements

1. **Rare Dig Sites** - Spawn unique sites randomly
2. **Archaeology Profession** - Skill levels unlock more sites
3. **Trading** - Trade fragments (not artifacts)
4. **Group Digs** - Multiplayer excavations
5. **Artifact Display** - Housing integration
