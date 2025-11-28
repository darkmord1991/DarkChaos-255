# Profession Overhaul System

**Priority:** S3 - Medium Priority  
**Effort:** High (3-4 weeks)  
**Impact:** High  
**Base:** Custom C++/Eluna with existing profession framework

---

## Overview

A Profession Overhaul modernizes WotLK's crafting system for funserver gameplay. This includes: meaningful crafted gear at endgame, profession-exclusive perks, custom recipes, streamlined leveling, and integration with existing DarkChaos systems (Item Upgrades, Seasonal rewards).

---

## Why It Fits DarkChaos-255

### Current Profession Problems
- Professions become irrelevant at max level
- Crafted gear quickly outclassed
- Profession bonuses (shoulder enchants, etc.) trivial at 255
- No crafting sink for endgame players
- Gathering becomes pointless

### Solutions This Provides
- Endgame crafting relevance
- Profession-exclusive benefits
- Material sinks for economy
- Seasonal crafting integration
- Alt profession value

### Synergies
| System | Integration |
|--------|-------------|
| **Item Upgrade** | Craft upgrade materials |
| **Mythic+** | Craft M+ consumables |
| **Seasonal** | Season-exclusive recipes |
| **HLBG** | Craft PvP consumables |

---

## Feature Highlights

### Core Features

1. **Endgame Recipes**
   - Gear equivalent to raid drops
   - Custom set bonuses
   - Upgrade-compatible items
   - Transmogrification-worthy appearances

2. **Profession Perks (Reworked)**
   - Scaled for level 255
   - Unique abilities per profession
   - Combat and utility benefits
   - Exclusive enchants/gems

3. **Specializations**
   - Choose focus areas
   - Unlock special recipes
   - Craft efficiency bonuses
   - Unique titles

4. **Daily/Weekly Crafting**
   - Cooldown recipes (valuable)
   - Daily quest materials
   - Weekly profession quests
   - Seasonal exclusive crafts

5. **Material Overhaul**
   - New gathering nodes
   - Material conversion
   - Salvaging system
   - Quality tiers

---

## Profession-Specific Features

### Gathering Professions

#### Mining
| Feature | Description |
|---------|-------------|
| Titanium Veins+ | New ore nodes in high-level areas |
| Gem Finding | Chance to find rare gems while mining |
| Smelting Mastery | Create enhanced bars |
| Combat Buff | +500 Stamina at max skill |

#### Herbalism
| Feature | Description |
|---------|-------------|
| Corrupted Herbs | New herbs for M+ flasks |
| Lifeblood Rework | Major heal + HoT + Haste |
| Herb Detection | Find rare spawns |
| Combat Buff | Nature resistance, HoT |

#### Skinning
| Feature | Description |
|---------|-------------|
| Mythic Hides | Skinnable from M+ creatures |
| Arctic Fur+ | Enhanced rare leathers |
| Crit Bonus | +5% crit chance at max skill |
| Combat Buff | Bleed damage bonus |

### Crafting Professions

#### Blacksmithing
| Feature | Description |
|---------|-------------|
| Socket Creation | Add sockets to any gear |
| Titansteel Rework | Enhanced crafted weapons |
| Sharpening Stones+ | Combat-relevant whetstones |
| Armor Patches | Reduce durability loss |
| **Special**: Indestructible weapons (no durability) |

#### Leatherworking
| Feature | Description |
|---------|-------------|
| Leg Armor Rework | Scaled for 255 stats |
| Mythic Leather Sets | Endgame crafted gear |
| Drums of Battle+ | Enhanced raid cooldown |
| **Special**: Mount speed leg enchant |

#### Tailoring
| Feature | Description |
|---------|-------------|
| Flying Carpet+ | Custom carpet mounts |
| Spell Thread Rework | Competitive with raids |
| Bag Crafting+ | 36-slot bags |
| **Special**: Cloak enchant: Glider |

#### Engineering
| Feature | Description |
|---------|-------------|
| Tinker System | Gadget slots on gear |
| Rocket Boots+ | No explosion chance |
| Teleporters | New destinations |
| Combat Pets | Engineering companions |
| **Special**: Permanent nitro boosts |

#### Jewelcrafting
| Feature | Description |
|---------|-------------|
| Mythic Gems | Superior gem quality |
| JC-Only Gems | Enhanced personal gems |
| Prismatic Sockets | Any color gem |
| **Special**: Gem that grants extra abilities |

#### Enchanting
| Feature | Description |
|---------|-------------|
| Enchant Scrolls | Tradeable enchants |
| Ring Enchants+ | Scaled for 255 |
| Disenchanting+ | Salvage M+ gear |
| **Special**: Self-enchant: Magic resistance |

#### Inscription
| Feature | Description |
|---------|-------------|
| Glyphs Rework | Meaningful choices |
| Darkmoon Cards+ | Competitive trinkets |
| Contracts | Bonus rep from kills |
| **Special**: Hearthstone cooldown reduction |

#### Alchemy
| Feature | Description |
|---------|-------------|
| Mythic Flasks | Enhanced for M+ |
| Transmutation Rework | Material conversion |
| Cauldrons | Raid flasks |
| **Special**: Flask duration doubled |

---

## Technical Implementation

### Database Schema

```sql
-- Custom profession recipes
CREATE TABLE dc_profession_recipes (
    recipe_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    profession_id INT UNSIGNED,  -- Skill ID
    recipe_name VARCHAR(100),
    skill_required INT UNSIGNED,
    result_item_id INT UNSIGNED,
    result_count INT DEFAULT 1,
    
    -- Materials (JSON for flexibility)
    materials JSON,  -- [{"item_id": 123, "count": 5}, ...]
    
    -- Cooldown
    cooldown_seconds INT DEFAULT 0,
    cooldown_category INT DEFAULT 0,  -- Shared cooldown group
    
    -- Availability
    is_specialization TINYINT DEFAULT 0,
    specialization_id INT NULL,
    season_id INT NULL,  -- Only available during season
    
    -- Discovery
    is_discovered TINYINT DEFAULT 0,
    discovery_chance FLOAT DEFAULT 0,
    
    is_active TINYINT DEFAULT 1
);

-- Player profession data
CREATE TABLE dc_player_professions (
    player_guid INT UNSIGNED,
    profession_id INT UNSIGNED,
    specialization_id INT NULL,
    daily_cooldowns_used INT DEFAULT 0,
    weekly_quests_completed INT DEFAULT 0,
    total_items_crafted INT DEFAULT 0,
    
    PRIMARY KEY (player_guid, profession_id)
);

-- Profession specializations
CREATE TABLE dc_profession_specializations (
    spec_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    profession_id INT UNSIGNED,
    spec_name VARCHAR(50),
    spec_description TEXT,
    required_skill INT DEFAULT 450,
    bonus_stats JSON,  -- {"crit_craft": 0.1, "extra_procs": 0.2}
    exclusive_recipes JSON  -- [recipe_ids]
);

-- Profession perks (combat bonuses)
CREATE TABLE dc_profession_perks (
    perk_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    profession_id INT UNSIGNED,
    skill_threshold INT UNSIGNED,  -- Skill level to unlock
    perk_type ENUM('stat', 'ability', 'passive'),
    perk_data JSON,
    description TEXT
);

-- Custom materials
CREATE TABLE dc_custom_materials (
    material_id INT UNSIGNED PRIMARY KEY,  -- Item entry ID
    material_name VARCHAR(100),
    source_type ENUM('node', 'mob', 'salvage', 'craft', 'vendor'),
    source_id INT UNSIGNED,  -- Node ID, creature entry, etc.
    quality_tier TINYINT DEFAULT 1,
    is_seasonal TINYINT DEFAULT 0
);

-- Sample specializations
INSERT INTO dc_profession_specializations VALUES
(1, 164, 'Weaponsmith', 'Specialize in weapon crafting', 450, 
 '{"weapon_crit": 0.1, "extra_sockets_weapon": 1}', '[50001, 50002, 50003]'),
(2, 164, 'Armorsmith', 'Specialize in armor crafting', 450,
 '{"armor_stats_bonus": 0.1, "durability_bonus": 0.5}', '[50011, 50012, 50013]'),
(3, 165, 'Dragonscale', 'Work with dragonscale leather', 450,
 '{"mail_specialization": true, "resist_bonus": 50}', '[50021, 50022]'),
(4, 165, 'Elemental', 'Elemental leather crafting', 450,
 '{"leather_stats_bonus": 0.15}', '[50031, 50032]');

-- Sample perks
INSERT INTO dc_profession_perks VALUES
(1, 164, 450, 'stat', '{"stamina": 500}', '+500 Stamina'),
(2, 164, 450, 'ability', '{"spell_id": 50001}', 'Forge Armor: Repair on demand'),
(3, 165, 450, 'stat', '{"crit": 100}', '+100 Critical Strike Rating'),
(4, 171, 450, 'passive', '{"flask_duration_mult": 2.0}', 'Flasks last twice as long'),
(5, 755, 450, 'passive', '{"jc_gem_bonus": true}', 'Access to JC-only gems'),
(6, 202, 450, 'ability', '{"spell_id": 50002}', 'Nitro Boosts (permanent)');
```

### Eluna Implementation

```lua
-- Profession Manager
local ProfessionManager = {}

-- Apply profession perks on login
local function OnLogin(event, player)
    ProfessionManager.ApplyPerks(player)
end
RegisterPlayerEvent(3, OnLogin)

function ProfessionManager.ApplyPerks(player)
    local guid = player:GetGUIDLow()
    
    -- Check each profession
    for _, skillId in ipairs({164, 165, 171, 186, 197, 202, 333, 393, 755, 773}) do
        local skillValue = player:GetSkillValue(skillId)
        if skillValue > 0 then
            local perks = ProfessionManager.GetPerksForSkill(skillId, skillValue)
            for _, perk in ipairs(perks) do
                ProfessionManager.ApplyPerk(player, perk)
            end
        end
    end
end

function ProfessionManager.ApplyPerk(player, perk)
    local data = perk.perk_data
    
    if perk.perk_type == "stat" then
        -- Apply stat aura (persistent buff)
        if data.stamina then
            player:CastSpell(player, SPELL_STAM_BONUS, true)
        end
        if data.crit then
            player:CastSpell(player, SPELL_CRIT_BONUS, true)
        end
        
    elseif perk.perk_type == "ability" then
        -- Teach spell if not known
        if data.spell_id and not player:HasSpell(data.spell_id) then
            player:LearnSpell(data.spell_id)
        end
        
    elseif perk.perk_type == "passive" then
        -- Store passive data for later checks
        player:SetData("profession_passive_" .. perk.perk_id, true)
    end
end

-- Flask duration hook (for alchemy passive)
local function OnAuraApply(event, player, spell)
    -- Check if it's a flask
    if ProfessionManager.IsFlask(spell:GetEntry()) then
        if player:GetData("profession_passive_alchemy_duration") then
            -- Double flask duration
            local aura = player:GetAura(spell:GetEntry())
            if aura then
                aura:SetDuration(aura:GetDuration() * 2)
            end
        end
    end
end

-- Custom crafting handler
function ProfessionManager.CraftItem(player, recipeId)
    local recipe = ProfessionManager.GetRecipe(recipeId)
    if not recipe then
        player:SendBroadcastMessage("Invalid recipe.")
        return false
    end
    
    -- Check skill
    local skillValue = player:GetSkillValue(recipe.profession_id)
    if skillValue < recipe.skill_required then
        player:SendBroadcastMessage("Skill too low.")
        return false
    end
    
    -- Check materials
    for _, mat in ipairs(recipe.materials) do
        if player:GetItemCount(mat.item_id) < mat.count then
            player:SendBroadcastMessage("Missing materials.")
            return false
        end
    end
    
    -- Check cooldown
    if recipe.cooldown_seconds > 0 then
        local lastCraft = player:GetData("cooldown_" .. recipeId)
        if lastCraft and os.time() - lastCraft < recipe.cooldown_seconds then
            local remaining = recipe.cooldown_seconds - (os.time() - lastCraft)
            player:SendBroadcastMessage("Cooldown: " .. remaining .. " seconds remaining.")
            return false
        end
    end
    
    -- Check specialization
    if recipe.is_specialization then
        local spec = ProfessionManager.GetPlayerSpec(player, recipe.profession_id)
        if spec ~= recipe.specialization_id then
            player:SendBroadcastMessage("Wrong specialization for this recipe.")
            return false
        end
    end
    
    -- Consume materials
    for _, mat in ipairs(recipe.materials) do
        player:RemoveItem(mat.item_id, mat.count)
    end
    
    -- Apply cooldown
    if recipe.cooldown_seconds > 0 then
        player:SetData("cooldown_" .. recipeId, os.time())
    end
    
    -- Calculate quantity (with specialization bonus)
    local quantity = recipe.result_count
    local spec = ProfessionManager.GetPlayerSpec(player, recipe.profession_id)
    if spec then
        local specData = ProfessionManager.GetSpecData(spec)
        if specData.extra_procs then
            if math.random() < specData.extra_procs then
                quantity = quantity + 1
                player:SendBroadcastMessage("|cff00ff00Specialization Bonus: +1 crafted!|r")
            end
        end
    end
    
    -- Give item
    player:AddItem(recipe.result_item_id, quantity)
    player:SendBroadcastMessage("Crafted: " .. GetItemLink(recipe.result_item_id) .. " x" .. quantity)
    
    -- Update stats
    ProfessionManager.UpdateCraftStats(player, recipe.profession_id)
    
    return true
end
```

### Sample Custom Recipes

```sql
-- Blacksmithing endgame recipes
INSERT INTO dc_profession_recipes 
(profession_id, recipe_name, skill_required, result_item_id, result_count, materials) VALUES
(164, 'Titanforged Battleaxe', 450, 60001, 1, 
 '[{"item_id": 36913, "count": 20}, {"item_id": 41163, "count": 10}, {"item_id": 60050, "count": 5}]'),
(164, 'Shadowsteel Chestplate', 450, 60002, 1,
 '[{"item_id": 36913, "count": 30}, {"item_id": 60051, "count": 8}]'),
(164, 'Socket Buckle (Epic)', 450, 60003, 1,
 '[{"item_id": 36913, "count": 10}, {"item_id": 36916, "count": 5}]');

-- Alchemy M+ flasks
INSERT INTO dc_profession_recipes VALUES
(5, 171, 'Flask of Endless Power', 450, 60101, 1,
 '[{"item_id": 36907, "count": 10}, {"item_id": 36908, "count": 10}, {"item_id": 60052, "count": 1}]',
 86400, 1, 0, NULL, NULL, 0, 0, 1);

-- Jewelcrafting special gems
INSERT INTO dc_profession_recipes VALUES
(6, 755, 'Prismatic Titanium Gem', 450, 60201, 1,
 '[{"item_id": 36925, "count": 3}, {"item_id": 36931, "count": 1}]',
 0, 0, 0, NULL, NULL, 0, 0, 1);
```

---

## Implementation Phases

### Phase 1 (Week 1): Core Framework
- [ ] Database schema
- [ ] Profession perk system
- [ ] Specialization choices
- [ ] Basic stat bonuses

### Phase 2 (Week 2): Custom Recipes
- [ ] Design endgame crafted gear
- [ ] Implement custom recipes
- [ ] Material design
- [ ] Cooldown system

### Phase 3 (Week 3): Perks & Abilities
- [ ] Profession-specific abilities
- [ ] Combat bonuses
- [ ] Passive effects
- [ ] Engineering tinkers

### Phase 4 (Week 4): Polish & Integration
- [ ] Seasonal recipe integration
- [ ] Item Upgrade material crafting
- [ ] Daily/weekly quests
- [ ] UI elements (if any)

---

## Integration with Existing Systems

### Item Upgrade Materials
```sql
-- Crafted upgrade materials
INSERT INTO dc_profession_recipes VALUES
(100, 164, 'Upgrade Essence (Weapon)', 450, 70001, 1,
 '[{"item_id": 36913, "count": 50}]', 86400, 10, 0, NULL, NULL, 0, 0, 1),
(101, 165, 'Upgrade Essence (Armor)', 450, 70002, 1,
 '[{"item_id": 38425, "count": 30}]', 86400, 10, 0, NULL, NULL, 0, 0, 1);
```

### Mythic+ Consumables
```sql
-- M+ specific consumables
INSERT INTO dc_profession_recipes VALUES
(200, 171, 'Flask of the Challenger', 450, 70101, 1,
 '[{"item_id": 36907, "count": 5}, {"item_id": 70050, "count": 1}]',
 0, 0, 0, NULL, NULL, 0, 0, 1);  -- M+ drop material
```

---

## Success Metrics

- Profession adoption rates
- Crafted item usage
- Material economy health
- Player engagement with crafting

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Economy disruption | Careful material costs |
| OP profession perks | Thorough testing, balance passes |
| Complexity overload | Phased rollout, clear documentation |
| Existing recipes break | Preserve vanilla recipes, add new |

---

**Recommendation:** Start with profession perks (stat bonuses) as they require minimal new content. Then add specializations and custom recipes. Save complex abilities for later phases.
