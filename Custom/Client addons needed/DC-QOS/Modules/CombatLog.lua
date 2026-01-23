-- ============================================================
-- DC-QoS: CombatLog Module
-- ============================================================
-- Combat statistics with party/raid tracking
-- Now includes: DPS bars, segment history, threat meter
-- For full raid analysis, use Skada: github.com/bkader/Skada-WoTLK
-- ============================================================

local addon = DCQOS

local GetPlayerData

-- ============================================================
-- Module Configuration
-- ============================================================
local CombatLog = {
    displayName = "Combat Log",
    settingKey = "combatLog",
    icon = "Interface\\Icons\\Ability_DualWield",
    defaults = {
        combatLog = {
            enabled = true,
            -- Display Mode
            showMeter = true,
            -- If the window was hidden (e.g. via the close button), still auto-show it when combat starts.
            autoShowInCombat = true,
            meterMode = "damage", -- damage, healing, damageTaken, threat, dispels, interrupts, cc, etc.
            showBars = true,
            maxBars = 10,
            barHeight = 18,
            -- Personal Stats
            showPersonalDPS = true,
            showPersonalHPS = false,
            -- Group Tracking
            trackGroup = true,
            -- Spell Breakdown
            showSpellBreakdown = true,
            maxSpells = 5,
            -- Death Recap (ENHANCED)
            deathRecap = true,
            deathRecapCount = 15,  -- Increased from 5 to 15
            deathRecapMinDamage = 0,  -- Minimum damage to show in recap (0 = all)
            deathRecapShowBuffs = true,  -- Show buff/debuff state in recap
            announceDeaths = false,  -- Announce deaths to chat
            alternativeDeathDisplay = false,  -- Each death as separate bar
            -- Interrupts
            trackInterrupts = true,
            announceInterrupts = false,
            interruptChannel = "SAY",
            -- Advanced Metrics (Skada-level)
            trackDispels = true,
            trackAbsorbs = true,
            trackOverkill = true,
            trackMisses = true,
            trackCritDetails = true,
            trackActivity = true,
            trackPowerGains = true,
            trackKillingBlows = true,
            trackCrowdControl = true,
            trackCCTaken = true,  -- Track CC received
            trackCCBreaks = true,  -- Track CC breaks
            trackFriendlyFire = true,
            trackPotions = true,
            trackResurrects = true,
            -- New: Avoidance & Mitigation
            trackAvoidance = true,  -- Dodge, Parry, Miss counts
            trackMitigation = true,  -- Block amount, Resist amount, Absorb amount
            -- New: Enemy Tracking
            trackEnemies = true,  -- Track enemy damage taken
            trackEnemyHealing = true,  -- Track enemy healing done
            trackUsefulDamage = true,  -- Track damage on important targets
            -- New: Pet Tracking
            trackPetDamage = true,  -- Separate pet damage from owner
            trackPetHealing = true,  -- Separate pet healing from owner
            -- New: Buff/Debuff Tracking
            trackBuffs = true,  -- Track buff applications and uptime
            trackDebuffs = true,  -- Track debuff applications and uptime
            trackBuffUptime = true,  -- Calculate uptime percentages
            -- New: Healing Details
            trackHealingBySpell = true,  -- Detailed healing spell breakdown
            trackHealingTaken = true,  -- Track who healed whom
            trackOverhealing = true,  -- Track overheal amounts
            -- New: Damage Details
            trackDamageBySchool = true,  -- Track damage by magic school
            trackDamageTakenBySpell = true,  -- Track damage taken per spell
            trackDamageTakenBySource = true,  -- Track damage taken per source
            -- New: Cast Tracking
            trackCasts = true,  -- Track spell cast counts
            -- Advanced Tooltips
            showSchoolColors = true,  -- Color damage by school in tooltips
            showGlancingCrushing = true,  -- Show glancing/crushing hits
            showMitigationInTooltip = true,  -- Show absorbed/blocked/resisted in tooltips
            -- Segments
            keepSegments = 5,
            -- Timeline capture
            trackTimeline = true,
            timelineMaxEvents = 1500,
            -- Position (Skada-style)
            x = nil,              -- Center X relative to screen center
            y = nil,              -- Center Y relative to screen center
            scale = 1.0,          -- Window scale
            frameWidth = 200,
            frameHeight = 250,
            frameAlpha = 0.9,
            hidden = false,       -- Window visibility state
            locked = false,       -- Lock window position
            -- Combat Timer
            showCombatTimer = true,
            -- Totals display: "off", "line", "title", "menu"
            totalsDisplay = "line",
        },
    },
}

-- Merge defaults
for k, v in pairs(CombatLog.defaults) do
    if addon.defaults[k] == nil then
        addon.defaults[k] = v
    else
        for k2, v2 in pairs(v) do
            if addon.defaults[k][k2] == nil then
                addon.defaults[k][k2] = v2
            end
        end
    end
end

-- ============================================================
-- State Variables
-- ============================================================
local combatFrame = nil
local inCombat = false
local combatStartTime = 0
local combatEndTime = 0

-- Player data storage: playerData[guid] = { name, class, damage, healing, damageTaken }
local playerData = {}
local playerGUID = nil
local playerName = nil

-- Buff/Debuff tracking: buffData[targetGUID][spellId] = { name, applications, uptime, lastApplied }
local buffData = {}
local debuffData = {}

-- Enemy tracking: enemyData[guid] = { name, damageTaken, damageSpells, damageSources }
local enemyData = {}

-- Pet tracking: petOwners[petGUID] = ownerGUID
local petOwners = {}

-- Active shields tracking: shields[targetGUID][spellId] = { amount, applied, lastUpdate }
local activeShields = {}

-- Healing taken tracking: healingTaken[targetGUID][sourceGUID] = amount
local healingTaken = {}

-- Segments (fight history)
local segments = {}
local activeSegment = nil -- nil or 0 = current fight, >0 = segment index
local segmentCounter = 0
local currentTimeline = {}

-- Death recap (ENHANCED)
local MAX_DEATH_LOG = 15

local function GetDeathLogLimit()
    local settings = addon.settings and addon.settings.combatLog
    local limit = settings and settings.deathRecapCount or MAX_DEATH_LOG
    if limit < 5 then
        limit = 5
    end
    return limit
end

local function ExtractDeathLogEntries(ring, newestFirst)
    local entries = {}
    if not ring or ring.size == 0 then
        return entries
    end

    local size = ring.size or 0
    local limit = ring.limit or size
    if size == 0 or limit == 0 then
        return entries
    end

    if newestFirst then
        for i = 0, size - 1 do
            local idx = ((ring.head - i - 1) % limit) + 1
            local entry = ring._ring[idx]
            if entry then
                table.insert(entries, entry)
            end
        end
    else
        for i = size - 1, 0, -1 do
            local idx = ((ring.head - i - 1) % limit) + 1
            local entry = ring._ring[idx]
            if entry then
                table.insert(entries, entry)
            end
        end
    end

    return entries
end

local function InitDeathLogBuffer(data)
    local limit = GetDeathLogLimit()
    if not data.deathLog or not data.deathLog._ring then
        data.deathLog = {
            _ring = {},
            head = 0,
            size = 0,
            limit = limit,
        }
        return
    end

    if data.deathLog.limit ~= limit then
        local entries = ExtractDeathLogEntries(data.deathLog, true)
        data.deathLog._ring = {}
        data.deathLog.head = 0
        data.deathLog.size = 0
        data.deathLog.limit = limit
        for i = #entries, 1, -1 do
            local entry = entries[i]
            data.deathLog.head = (data.deathLog.head % limit) + 1
            data.deathLog._ring[data.deathLog.head] = entry
            data.deathLog.size = math.min(data.deathLog.size + 1, limit)
        end
    end
end

local function AppendDeathLogEntry(data, entry)
    if not data then return end
    InitDeathLogBuffer(data)

    local ring = data.deathLog
    local limit = ring.limit or GetDeathLogLimit()
    ring.head = (ring.head % limit) + 1
    ring._ring[ring.head] = entry
    ring.size = math.min((ring.size or 0) + 1, limit)
end

-- Add death log entry with enhanced details
local function AddDeathLogEntry(targetGUID, eventType, data)
    if not targetGUID then return end

    local settings = addon.settings and addon.settings.combatLog
    local targetData = GetPlayerData(targetGUID)
    if not targetData then return end

    if eventType == "damage" and settings and settings.deathRecapMinDamage and data and data.amount then
        if data.amount < settings.deathRecapMinDamage then
            return
        end
    end
    
    local timestamp = GetTime() - combatStartTime
    local health = 0
    local healthMax = 0
    
    -- Try to get health info
    local unit = nil
    if UnitGUID("player") == targetGUID then
        unit = "player"
    else
        for i = 1, 4 do
            if UnitGUID("party"..i) == targetGUID then
                unit = "party"..i
                break
            end
        end
        if not unit then
            for i = 1, 40 do
                if UnitGUID("raid"..i) == targetGUID then
                    unit = "raid"..i
                    break
                end
            end
        end
    end
    
    if unit and UnitExists(unit) then
        health = UnitHealth(unit)
        healthMax = UnitHealthMax(unit)
    end
    
    local entry = {
        timestamp = timestamp,
        eventType = eventType,  -- "damage", "heal", "buff", "debuff", "death"
        health = health,
        healthMax = healthMax,
        healthPct = healthMax > 0 and (health / healthMax * 100) or 0,
    }
    
    -- Copy event-specific data
    for k, v in pairs(data or {}) do
        entry[k] = v
    end
    
    AppendDeathLogEntry(targetData, entry)
end

-- Miss types mapping
local MISS_TYPES = {
    ABSORB = "absorbs",
    BLOCK = "blocks",
    DEFLECT = "deflects",
    DODGE = "dodges",
    EVADE = "evades",
    IMMUNE = "immunes",
    MISS = "misses",
    PARRY = "parries",
    REFLECT = "reflects",
    RESIST = "resists",
}

-- Common CC spells (extendable list)
local CC_SPELLS = {
    -- Stuns
    [408] = true,     -- Kidney Shot
    [1833] = true,    -- Cheap Shot
    [2094] = true,    -- Blind
    [5211] = true,    -- Bash
    [8983] = true,    -- Bash (Bear)
    [12809] = true,   -- Concussion Blow
    [19577] = true,   -- Intimidation
    [20066] = true,   -- Repentance
    [20170] = true,   -- Stun (Seal of Justice)
    [22570] = true,   -- Maim
    [24394] = true,   -- Intimidation
    [44572] = true,   -- Deep Freeze
    [46968] = true,   -- Shockwave
    [47481] = true,   -- Gnaw (Ghoul)
    [49012] = true,   -- Spell Lock (Felhunter)
    [49802] = true,   -- Maim
    [49803] = true,   -- Pounce
    -- Fears
    [5782] = true,    -- Fear
    [6215] = true,    -- Fear (Felhunter)
    [5484] = true,    -- Howl of Terror
    [8122] = true,    -- Psychic Scream
    -- Polymorphs
    [118] = true,     -- Polymorph
    [12824] = true,   -- Polymorph
    [12825] = true,   -- Polymorph
    [28271] = true,   -- Polymorph: Turtle
    [28272] = true,   -- Polymorph: Pig
    [61305] = true,   -- Polymorph: Black Cat
    [61721] = true,   -- Polymorph: Rabbit
    [61780] = true,   -- Polymorph: Turkey
    -- Cyclone, Roots, etc.
    [339] = true,     -- Entangling Roots
    [33786] = true,   -- Cyclone
    [53308] = true,   -- Entangling Roots (Nature's Grasp)
    -- Silences
    [18469] = true,   -- Counterspell - Silenced
    [15487] = true,   -- Silence
    [34490] = true,   -- Silencing Shot
}

-- Power type constants
local POWER_TYPE_MANA = 0
local POWER_TYPE_RAGE = 1
local POWER_TYPE_FOCUS = 2
local POWER_TYPE_ENERGY = 3
local POWER_TYPE_RUNIC = 6

-- ============================================================
-- FILTERING SYSTEM (Skada-style)
-- ============================================================

-- Ignored spells (don't count for damage/healing)
local IGNORED_DAMAGE_SPELLS = {
    [55711] = true,  -- Heart of the Crusader
    [28059] = true,  -- Positive Charge
    [28084] = true,  -- Negative Charge
    [52212] = true,  -- Death and Decay (friendly fire)
}

local IGNORED_HEALING_SPELLS = {
    [15290] = true,  -- Vampiric Embrace
    [20267] = true,  -- Judgment of Light
    [23881] = true,  -- Bloodthirst
    [50475] = true,  -- Blood Presence
    [52042] = true,  -- Healing Stream Totem
}

local IGNORED_ABSORB_SPELLS = {}

-- Passive spells (excluded from activity time calculations)
local PASSIVE_SPELLS = {
    [54149] = true,  -- Infusion
    [61257] = true,  -- Idol of the Ravenous Beast
    [34074] = true,  -- Aspect of the Viper
}

-- Ignored creatures (training dummies, etc.)
local IGNORED_CREATURES = {
    [31144] = true,  -- Trainee
    [31146] = true,  -- Raider's Training Dummy
    [32666] = true,  -- Argent Lightwell
    [32667] = true,  -- Argent Priest
    [46647] = true,  -- Effigy of the Frigid Air
}

-- Important targets for "Useful Damage" tracking
local IMPORTANT_TARGETS = {
    -- ICC
    [36899] = "Oozes",        -- Volatile Ooze
    [37697] = "Oozes",        -- Little Ooze
    [36627] = "Valkyrs",      -- Valkyr Shadowguard
    [37970] = "Princes",      -- Prince Valanar
    [37972] = "Princes",      -- Prince Taldaram
    [37973] = "Princes",      -- Prince Keleseth
    [39863] = "Boss",         -- Halion
    [40142] = "Halion",       -- Halion (Twilight)
    -- Ulduar
    [33432] = "Adds",         -- Leviathan Turret
    [33572] = "Adds",         -- Mechanolift
}

-- Environmental damage types
local ENVIRONMENTAL_DAMAGE = {
    FALLING = "Falling",
    DROWNING = "Drowning",
    FATIGUE = "Fatigue",
    FIRE = "Fire",
    LAVA = "Lava",
    SLIME = "Slime",
}

-- Combat Log Flags (Safety fallbacks)
local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local COMBATLOG_OBJECT_AFFILIATION_PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x00000002
local COMBATLOG_OBJECT_AFFILIATION_RAID = COMBATLOG_OBJECT_AFFILIATION_RAID or 0x00000004
local COMBATLOG_OBJECT_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET or 0x00001000
local COMBATLOG_OBJECT_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000

-- Potion/healthstone spell IDs
local CONSUMABLE_SPELLS = {
    -- Health potions
    [28495] = "potion",   -- Super Healing Potion
    [17534] = "potion",   -- Major Healing Potion
    [17535] = "potion",   -- Major Mana Potion
    [43185] = "potion",   -- Runic Healing Potion
    [43186] = "potion",   -- Runic Mana Potion
    -- Healthstones
    [6262] = "healthstone",   -- Healthstone
    [23468] = "healthstone",  -- Master Healthstone
    [43523] = "healthstone",  -- Conjured Mana Biscuit
}

-- ============================================================
-- ABSORB SHIELD MECHANICS (Skada-style)
-- ============================================================

-- Known absorb spells with calculations
local ABSORB_SPELLS = {
    -- Priest
    [17] = {name = "Power Word: Shield", school = 0x02},
    [47753] = {name = "Divine Aegis", school = 0x02},
    -- Paladin
    [58597] = {name = "Sacred Shield", school = 0x02},
    -- Death Knight
    [48707] = {name = "Anti-Magic Shell", school = 0x02},
    [51052] = {name = "Anti-Magic Zone", school = 0x02},
    -- Mage
    [11426] = {name = "Ice Barrier", school = 0x10},
    [43039] = {name = "Ice Barrier", school = 0x10},
    -- Warlock
    [7812] = {name = "Sacrifice", school = 0x02},
    [25228] = {name = "Soul Link", school = 0x02},
    -- Druid
    [62606] = {name = "Savage Defense", school = 0x01},
    -- Items
    [23506] = {name = "Aura of Protection", school = 0x02},
    [21956] = {name = "Mark of Resolution", school = 0x02},
}

-- Passive shields
local PASSIVE_SHIELDS = {
    [31230] = true,  -- Cheat Death
    [49497] = true,  -- Spell Deflection
    [52286] = true,  -- Will of the Necropolis
    [66233] = true,  -- Ardent Defender
}

-- Zone modifiers for absorb calculations
local zoneModifier = 1
local function UpdateZoneModifier()
    if UnitInBattleground("player") then
        zoneModifier = 1.17  -- BG buff
    elseif IsActiveBattlefieldArena() then
        zoneModifier = 0.9   -- Arena nerf
    else
        zoneModifier = 1
    end
end

-- Class colors
local CLASS_COLORS = RAID_CLASS_COLORS or {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94 },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
}

-- ============================================================
-- Utility Functions
-- ============================================================

-- Save/Restore frame position (from Skada-style implementation)
local function SavePosition(frame, db)
    if not frame or not frame.GetCenter or not db then return end
    
    local x, y = frame:GetCenter()
    if not x or not y then return end
    
    local scale = frame:GetEffectiveScale()
    local uscale = UIParent:GetScale()
    
    -- Save relative to screen center (Skada's method)
    db.x = ((x * scale) - (GetScreenWidth() * uscale) * 0.5) / uscale
    db.y = ((y * scale) - (GetScreenHeight() * uscale) * 0.5) / uscale
    db.scale = math.floor(frame:GetScale() * 100) * 0.01
end

local function RestorePosition(frame, db)
    if not frame or not frame.SetPoint or not db then return end
    
    local scale = frame:GetEffectiveScale()
    local uscale = UIParent:GetScale()
    local x = (db.x or 0) * uscale / scale
    local y = (db.y or 0) * uscale / scale
    
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    frame:SetScale(db.scale or 1)
end

local function EnsureOnScreen(frame, db)
    if not frame or not frame.GetLeft or not UIParent then return end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if not left or not right or not top or not bottom or not sw or not sh then return end

    -- If entirely off-screen, reset to a sane center position.
    if right < 0 or left > sw or top < 0 or bottom > sh then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 150)
        SavePosition(frame, db)
    end
end

local function FormatNumber(num)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "0:00" end
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), math.floor(seconds % 60))
    elseif seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    else
        return string.format("%ds", math.floor(seconds))
    end
end

-- Forward declaration: GetActiveTotals() is defined before GetCombatTime().
-- Without this, Lua will resolve GetCombatTime as a global at call time.
local GetCombatTime

local function GetActiveTotals()
    if activeSegment and segments[activeSegment] and segments[activeSegment].totals then
        return segments[activeSegment].totals, segments[activeSegment].duration or 0
    end

    local totals = { damage = 0, healing = 0, absorbs = 0, damageTaken = 0 }
    for _, data in pairs(playerData) do
        totals.damage = totals.damage + (data.damage or 0)
        totals.healing = totals.healing + (data.healing or 0)
        totals.absorbs = totals.absorbs + (data.absorbs or 0)
        totals.damageTaken = totals.damageTaken + (data.damageTaken or 0)
    end

    return totals, GetCombatTime()
end

local function FormatTotalsSummary(totals, duration)
    if not totals then return "" end
    local dps = (duration and duration > 0) and (totals.damage or 0) / duration or 0
    local hps = (duration and duration > 0) and (totals.healing or 0) / duration or 0
    return string.format(
        "D: %s (%s/s)  H: %s (%s/s)  DT: %s  A: %s",
        FormatNumber(totals.damage or 0),
        FormatNumber(dps),
        FormatNumber(totals.healing or 0),
        FormatNumber(hps),
        FormatNumber(totals.damageTaken or 0),
        FormatNumber(totals.absorbs or 0)
    )
end

GetCombatTime = function()
    if inCombat then
        return GetTime() - combatStartTime
    elseif combatEndTime > 0 and combatStartTime > 0 then
        return combatEndTime - combatStartTime
    end
    return 0
end

local function GetClassColor(classToken)
    local color = CLASS_COLORS[classToken]
    if color then
        return color.r, color.g, color.b
    end
    return 0.5, 0.5, 0.5
end

-- ============================================================
-- Player Data Management
-- ============================================================
GetPlayerData = function(guid, name, flags)
    if not guid then return nil end
    
    if not playerData[guid] then
        -- Determine class from flags or unit lookup
        local classToken = nil
        
        -- Try to find unit and get class
        if name then
            if UnitName("player") == name then
                _, classToken = UnitClass("player")
            else
                for i = 1, 4 do
                    if UnitName("party" .. i) == name then
                        _, classToken = UnitClass("party" .. i)
                        break
                    end
                end
                if not classToken then
                    for i = 1, 40 do
                        if UnitName("raid" .. i) == name then
                            _, classToken = UnitClass("raid" .. i)
                            break
                        end
                    end
                end
            end
        end
        
        playerData[guid] = {
            name = name or "Unknown",
            class = classToken,
            -- Damage tracking
            damage = 0,
            overkill = 0,
            totalDamage = 0,  -- damage + absorbed
            usefulDamage = 0,  -- damage on important targets
            -- Healing tracking
            healing = 0,
            overhealing = 0,
            totalHealing = 0,
            healingBySpell = {},  -- [spellId] = {amount, overheal, hits}
            healingTakenFrom = {},  -- [sourceGUID] = amount
            healingTaken = 0,
            -- Defense tracking
            damageTaken = 0,
            damageTakenBySpell = {},  -- [spellId] = {amount, hits}
            damageTakenFrom = {},  -- [sourceGUID] = amount
            absorbs = 0,
            absorbsBySpell = {},  -- [spellId] = amount
            -- Avoidance & Mitigation
            dodges = 0,
            parries = 0,
            misses = 0,
            blocks = 0,
            resists = 0,
            blockAmount = 0,  -- total damage blocked
            resistAmount = 0,  -- total damage resisted
            absorbedAmount = 0,  -- total damage absorbed
            avoidance = 0,  -- total avoided hits
            avoidanceTable = {
                dodges = 0,
                parries = 0,
                misses = 0,
                blocks = 0,
                resists = 0,
                absorbs = 0,
                absorbed = 0,
                blockedAmount = 0,
                resistedAmount = 0,
                absorbedAmount = 0,
            },
            -- Combat events
            deaths = 0,
            killingBlows = 0,
            interrupts = 0,
            dispels = 0,
            ccDone = 0,
            ccTaken = 0,
            ccBreaks = 0,  -- breaking CC on others
            resurrects = 0,
            casts = 0,
            -- Activity tracking
            activeTime = 0,
            lastActive = 0,
            -- Power gains (mana, rage, runic, energy)
            manaGain = 0,
            rageGain = 0,
            runicGain = 0,
            energyGain = 0,
            -- Friendly fire
            friendlyDamage = 0,
            -- Item usage
            potionsUsed = 0,
            healthstonesUsed = 0,
            -- Pet damage
            petDamage = 0,
            petHealing = 0,
            pets = {},  -- [petGUID] = {name, damage, healing}
            -- Spell breakdown: spells[spellId] = { name, damage, healing, hits, crits, min, max, etc }
            spells = {},
            -- CC spells used
            ccSpells = {},
            -- Buffs/Debuffs applied
            buffsApplied = {},  -- [spellId] = count
            debuffsApplied = {},  -- [spellId] = count
            -- Death log entries (ENHANCED)
            deathLog = {
                _ring = {},
                head = 0,
                size = 0,
                limit = GetDeathLogLimit(),
            },
        }
    end
    
    return playerData[guid]
end

local function ResetPlayerData()
    wipe(playerData)
    wipe(buffData)
    wipe(debuffData)
    wipe(enemyData)
    wipe(petOwners)
    wipe(activeShields)
    wipe(healingTaken)
    currentTimeline = {}
    combatStartTime = GetTime()
    combatEndTime = 0
    UpdateZoneModifier()
end

-- ============================================================
-- Buff/Debuff Tracking Functions
-- ============================================================

local function TrackBuff(targetGUID, spellId, spellName, auraType)
    if not targetGUID or not spellId then return end
    
    local dataTable = (auraType == "BUFF") and buffData or debuffData
    
    if not dataTable[targetGUID] then
        dataTable[targetGUID] = {}
    end
    
    if not dataTable[targetGUID][spellId] then
        dataTable[targetGUID][spellId] = {
            name = spellName,
            applications = 0,
            uptime = 0,
            lastApplied = 0,
        }
    end
    
    local buff = dataTable[targetGUID][spellId]
    buff.applications = buff.applications + 1
    buff.lastApplied = GetTime()
end

local function RemoveBuff(targetGUID, spellId, auraType)
    if not targetGUID or not spellId then return end
    
    local dataTable = (auraType == "BUFF") and buffData or debuffData
    
    if dataTable[targetGUID] and dataTable[targetGUID][spellId] then
        local buff = dataTable[targetGUID][spellId]
        if buff.lastApplied > 0 then
            buff.uptime = buff.uptime + (GetTime() - buff.lastApplied)
            buff.lastApplied = 0
        end
    end
end

-- ============================================================
-- Enemy Tracking Functions
-- ============================================================

local function GetEnemyData(guid, name)
    if not guid then return nil end
    
    if not enemyData[guid] then
        -- Extract creature ID from GUID
        local creatureId = tonumber(guid:match("-(%d+)-%x+$"))
        
        enemyData[guid] = {
            name = name or "Unknown",
            creatureId = creatureId,
            damageTaken = 0,
            usefulDamage = 0,  -- if this is an important target
            damageSpells = {},  -- [spellId] = {damage, hits}
            damageSources = {},  -- [sourceGUID] = damage
            healingDone = 0,
            healingSpells = {},
            isImportant = IMPORTANT_TARGETS[creatureId] ~= nil,
            importantType = IMPORTANT_TARGETS[creatureId],
        }
    end
    
    return enemyData[guid]
end

-- ============================================================
-- Pet Tracking Functions
-- ============================================================

local function RegisterPet(petGUID, ownerGUID)
    if petGUID and ownerGUID then
        petOwners[petGUID] = ownerGUID
    end
end

local function GetPetOwner(petGUID)
    return petOwners[petGUID]
end

local function ResolvePetOwner(petGUID)
    if not petGUID then return nil end
    local cached = GetPetOwner(petGUID)
    if cached then return cached end

    local units = {"pet"}
    if IsInRaid() then
        for i = 1, 40 do
            units[#units + 1] = "raid" .. i .. "pet"
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            units[#units + 1] = "party" .. i .. "pet"
        end
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid == petGUID then
                local ownerUnit = unit:gsub("pet", "")
                local ownerGUID = UnitGUID(ownerUnit)
                if ownerGUID then
                    RegisterPet(petGUID, ownerGUID)
                    return ownerGUID
                end
            end
        end
    end

    return nil
end

-- ============================================================
-- Timeline Capture
-- ============================================================

local function RecordTimelineEvent(timestamp, event, sourceGUID, sourceName, destGUID, destName, spellId, spellName, amount, overkill, absorbed, school)
    local settings = addon.settings and addon.settings.combatLog
    if not settings or not settings.trackTimeline then return end
    if not inCombat then return end

    local limit = settings.timelineMaxEvents or 1500
    if limit < 200 then
        limit = 200
    end

    local elapsed = (combatStartTime and combatStartTime > 0) and (timestamp - combatStartTime) or 0
    table.insert(currentTimeline, {
        t = elapsed,
        event = event,
        sourceGUID = sourceGUID,
        sourceName = sourceName,
        destGUID = destGUID,
        destName = destName,
        spellId = spellId,
        spellName = spellName,
        amount = amount,
        overkill = overkill,
        absorbed = absorbed,
        school = school,
    })

    while #currentTimeline > limit do
        table.remove(currentTimeline, 1)
    end
end

local function SaveSegment()
    local settings = addon.settings.combatLog
    
    if GetCombatTime() < 5 then return end  -- Don't save short fights
    
    segmentCounter = segmentCounter + 1
    local segment = {
        id = segmentCounter,
        name = string.format("Fight %d", segmentCounter),
        startTime = combatStartTime,
        endTime = combatEndTime or GetTime(),
        duration = GetCombatTime(),
        data = {},
        timeline = currentTimeline,
        totals = {
            players = 0,
            damage = 0,
            totalDamage = 0,
            overkill = 0,
            healing = 0,
            totalHealing = 0,
            overhealing = 0,
            damageTaken = 0,
            absorbs = 0,
            deaths = 0,
            killingBlows = 0,
            interrupts = 0,
            dispels = 0,
            ccDone = 0,
            resurrects = 0,
            activeTime = 0,
            manaGain = 0,
            rageGain = 0,
            energyGain = 0,
            runicGain = 0,
            dodges = 0,
            parries = 0,
            misses = 0,
            blocks = 0,
            resists = 0,
            friendlyDamage = 0,
            potionsUsed = 0,
            healthstonesUsed = 0,
        },
    }
    
    -- Copy player data
    for guid, data in pairs(playerData) do
        local spellsCopy = {}
        if data.spells then
            for spellId, spell in pairs(data.spells) do
                spellsCopy[spellId] = {
                    name = spell.name,
                    damage = spell.damage or 0,
                    healing = spell.healing or 0,
                    hits = spell.hits or 0,
                    crits = spell.crits or 0,
                    glancing = spell.glancing or 0,
                    critDamage = spell.critDamage or 0,
                    critMin = spell.critMin,
                    critMax = spell.critMax,
                    normalHits = spell.normalHits or 0,
                    normalDamage = spell.normalDamage or 0,
                    normalMin = spell.normalMin,
                    normalMax = spell.normalMax,
                    misses = spell.misses or 0,
                    dodges = spell.dodges or 0,
                    parries = spell.parries or 0,
                    blocks = spell.blocks or 0,
                    resists = spell.resists or 0,
                    absorbed = spell.absorbed or 0,
                    overkill = spell.overkill or 0,
                }
            end
        end

        local ccSpellsCopy = {}
        if data.ccSpells then
            for spellId, count in pairs(data.ccSpells) do
                ccSpellsCopy[spellId] = count
            end
        end

        local avoidanceCopy = nil
        if data.avoidanceTable then
            avoidanceCopy = {}
            for k, v in pairs(data.avoidanceTable) do
                avoidanceCopy[k] = v
            end
        end

        local petsCopy = nil
        if data.pets then
            petsCopy = {}
            for petGuid, petData in pairs(data.pets) do
                petsCopy[petGuid] = {
                    name = petData.name,
                    damage = petData.damage or 0,
                    healing = petData.healing or 0,
                }
            end
        end

        segment.data[guid] = {
            name = data.name,
            class = data.class,
            damage = data.damage or 0,
            totalDamage = data.totalDamage or 0,
            overkill = data.overkill or 0,
            healing = data.healing or 0,
            totalHealing = data.totalHealing or 0,
            overhealing = data.overhealing or 0,
            damageTaken = data.damageTaken or 0,
            absorbs = data.absorbs or 0,
            deaths = data.deaths or 0,
            killingBlows = data.killingBlows or 0,
            interrupts = data.interrupts or 0,
            dispels = data.dispels or 0,
            ccDone = data.ccDone or 0,
            resurrects = data.resurrects or 0,
            activeTime = data.activeTime or 0,
            manaGain = data.manaGain or 0,
            rageGain = data.rageGain or 0,
            energyGain = data.energyGain or 0,
            runicGain = data.runicGain or 0,
            dodges = data.dodges or 0,
            parries = data.parries or 0,
            misses = data.misses or 0,
            blocks = data.blocks or 0,
            resists = data.resists or 0,
            friendlyDamage = data.friendlyDamage or 0,
            potionsUsed = data.potionsUsed or 0,
            healthstonesUsed = data.healthstonesUsed or 0,
            petDamage = data.petDamage or 0,
            petHealing = data.petHealing or 0,
            pets = petsCopy or {},
            avoidanceTable = avoidanceCopy,
            spells = spellsCopy,
            ccSpells = ccSpellsCopy,
        }

        local entry = segment.data[guid]
        local totals = segment.totals
        totals.players = totals.players + 1
        totals.damage = totals.damage + (entry.damage or 0)
        totals.totalDamage = totals.totalDamage + (entry.totalDamage or 0)
        totals.overkill = totals.overkill + (entry.overkill or 0)
        totals.healing = totals.healing + (entry.healing or 0)
        totals.totalHealing = totals.totalHealing + (entry.totalHealing or 0)
        totals.overhealing = totals.overhealing + (entry.overhealing or 0)
        totals.damageTaken = totals.damageTaken + (entry.damageTaken or 0)
        totals.absorbs = totals.absorbs + (entry.absorbs or 0)
        totals.deaths = totals.deaths + (entry.deaths or 0)
        totals.killingBlows = totals.killingBlows + (entry.killingBlows or 0)
        totals.interrupts = totals.interrupts + (entry.interrupts or 0)
        totals.dispels = totals.dispels + (entry.dispels or 0)
        totals.ccDone = totals.ccDone + (entry.ccDone or 0)
        totals.resurrects = totals.resurrects + (entry.resurrects or 0)
        totals.activeTime = totals.activeTime + (entry.activeTime or 0)
        totals.manaGain = totals.manaGain + (entry.manaGain or 0)
        totals.rageGain = totals.rageGain + (entry.rageGain or 0)
        totals.energyGain = totals.energyGain + (entry.energyGain or 0)
        totals.runicGain = totals.runicGain + (entry.runicGain or 0)
        totals.dodges = totals.dodges + (entry.dodges or 0)
        totals.parries = totals.parries + (entry.parries or 0)
        totals.misses = totals.misses + (entry.misses or 0)
        totals.blocks = totals.blocks + (entry.blocks or 0)
        totals.resists = totals.resists + (entry.resists or 0)
        totals.friendlyDamage = totals.friendlyDamage + (entry.friendlyDamage or 0)
        totals.potionsUsed = totals.potionsUsed + (entry.potionsUsed or 0)
        totals.healthstonesUsed = totals.healthstonesUsed + (entry.healthstonesUsed or 0)
    end
    
    table.insert(segments, 1, segment)

    currentTimeline = {}
    
    -- Trim old segments
    while #segments > settings.keepSegments do
        table.remove(segments)
    end
end

-- ============================================================
-- Sorted Data for Display
-- ============================================================
local function SelectSegment(index)
    if not index or index == 0 then
        activeSegment = nil
    else
        if segments[index] then
            activeSegment = index
        end
    end
    CombatLog.UpdateFrame()
end

local function GetSortedData(mode)
    local sorted = {}
    local valueKey = "damage"
    
    -- Determine data source
    local dataSource = playerData
    if activeSegment and segments[activeSegment] then
        dataSource = segments[activeSegment].data
    end
    
    if mode == "healing" then valueKey = "healing"
    elseif mode == "damageTaken" then valueKey = "damageTaken"
    elseif mode == "dispels" then valueKey = "dispels"
    elseif mode == "interrupts" then valueKey = "interrupts"
    elseif mode == "deaths" then valueKey = "deaths"
    elseif mode == "cc" then valueKey = "ccDone"
    elseif mode == "friendlyFire" then valueKey = "friendlyDamage"
    elseif mode == "absorbs" then valueKey = "absorbs"
    elseif mode == "overkill" then valueKey = "overkill"
    elseif mode == "killingBlows" then valueKey = "killingBlows"
    elseif mode == "activity" then valueKey = "activeTime"
    elseif mode == "power" then valueKey = "powerTotal"
    elseif mode == "consumables" then valueKey = "consumablesTotal"
    end

    
    if not dataSource then return sorted end

    for guid, data in pairs(dataSource) do
        local value = nil

        if valueKey == "powerTotal" then
            value = (data.manaGain or 0) + (data.rageGain or 0) + (data.energyGain or 0) + (data.runicGain or 0)
        elseif valueKey == "consumablesTotal" then
            value = (data.potionsUsed or 0) + (data.healthstonesUsed or 0)
        else
            value = data[valueKey]
        end

        if value and value > 0 then
            table.insert(sorted, {
                guid = guid,
                name = data.name,
                class = data.class,
                value = value,
            })
        end
    end
    
    table.sort(sorted, function(a, b) return a.value > b.value end)
    
    return sorted
end

local function GetThreatSortedData()
    local sorted = {}
    if not UnitExists("target") then
        return sorted
    end

    local units = {}
    if IsInRaid() then
        for i = 1, 40 do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for i = 1, 4 do
            units[#units + 1] = "party" .. i
        end
    else
        units[#units + 1] = "player"
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local isTanking, _, threatPct, _, threatValue = UnitDetailedThreatSituation(unit, "target")
            if threatPct and threatPct > 0 then
                local name = UnitName(unit)
                local guid = UnitGUID(unit)
                local _, class = UnitClass(unit)
                table.insert(sorted, {
                    guid = guid,
                    name = name or unit,
                    class = class,
                    value = threatPct,
                    threatValue = threatValue,
                    isTanking = isTanking,
                })
            end
        end
    end

    table.sort(sorted, function(a, b) return a.value > b.value end)
    return sorted
end



local function ShowTooltip(self)
    local data = self.data
    if not data then return end
    
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(data.name, 1, 1, 1)
    GameTooltip:AddLine(" ")
    
    if data.spells then
        local sortedSpells = {}
        for id, spell in pairs(data.spells) do
            local amount = spell.damage + spell.healing
            if amount > 0 then
                table.insert(sortedSpells, { name = spell.name, amount = amount, hits = spell.hits, crits = spell.crits })
            end
        end
        table.sort(sortedSpells, function(a, b) return a.amount > b.amount end)
        
        for i = 1, math.min(10, #sortedSpells) do
            local spell = sortedSpells[i]
            local critRate = spell.hits > 0 and (spell.crits / spell.hits * 100) or 0
            GameTooltip:AddDoubleLine(
                spell.name,
                string.format("%s (%.0f%% crit)", FormatNumber(spell.amount), critRate),
                1, 1, 1, 0.8, 0.8, 0.8
            )
        end
    else
        GameTooltip:AddLine("No spell details available", 0.7, 0.7, 0.7)
    end
    
    GameTooltip:Show()
end

-- ============================================================
-- Combat Frame with Bars
-- ============================================================
local barFrames = {}

local function CreateBar(parent, index)
    local settings = addon.settings.combatLog
    local barHeight = settings.barHeight or 18
    
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(parent:GetWidth() - 10, barHeight)
    bar:SetPoint("TOPLEFT", 5, -30 - ((index - 1) * (barHeight + 2)))
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)
    
    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    bar.bg = bg
    
    -- Rank number
    local rank = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank:SetPoint("LEFT", 2, 0)
    rank:SetText(index .. ".")
    rank:SetWidth(16)
    bar.rank = rank
    
    -- Name text
    local name = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", 20, 0)
    name:SetJustifyH("LEFT")
    name:SetWidth(bar:GetWidth() - 80)
    bar.nameText = name
    
    -- Value text
    local value = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    value:SetPoint("RIGHT", -2, 0)
    value:SetJustifyH("RIGHT")
    bar.valueText = value
    
    bar:SetScript("OnEnter", ShowTooltip)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    bar:EnableMouse(true)
    bar:Hide()
    return bar
end

local function CreateCombatFrame()
    if combatFrame then return combatFrame end
    
    local settings = addon.settings.combatLog

    -- Migrate legacy position settings (older DC-QOS versions)
    if (settings.x == nil or settings.y == nil) and (settings.frameX ~= nil or settings.frameY ~= nil) then
        combatFrame = CreateFrame("Frame", nil, UIParent)
        combatFrame:SetPoint("CENTER", UIParent, "CENTER", settings.frameX or 300, settings.frameY or 150)
        SavePosition(combatFrame, settings)
        combatFrame:Hide()
        combatFrame = nil
        settings.frameX, settings.frameY = nil, nil
    end
    if settings.scale == nil and settings.frameScale ~= nil then
        settings.scale = settings.frameScale
        settings.frameScale = nil
    end
    local width = tonumber(settings.frameWidth) or 200
    local height = tonumber(settings.frameHeight) or 250
    if width < 150 then width = 200 end
    if height < 100 then height = 250 end

    local scale = tonumber(settings.scale) or 1.0
    if scale < 0.5 or scale > 3.0 then
        scale = 1.0
    end

    local alpha = tonumber(settings.frameAlpha) or 0.9
    if alpha < 0.1 or alpha > 1.0 then
        alpha = 0.9
    end

    settings.frameWidth = width
    settings.frameHeight = height
    settings.scale = scale
    settings.frameAlpha = alpha
    
    combatFrame = CreateFrame("Frame", "DCQoS_CombatLogFrame", UIParent)
    combatFrame:SetSize(width, height)
    combatFrame:SetScale(scale)
    combatFrame:SetAlpha(alpha)

    if combatFrame.SetFrameStrata then
        combatFrame:SetFrameStrata("DIALOG")
    end
    if combatFrame.SetToplevel then
        combatFrame:SetToplevel(true)
    end
    combatFrame:SetMovable(true)
    combatFrame:EnableMouse(true)
    combatFrame:SetClampedToScreen(true)
    combatFrame:RegisterForDrag("LeftButton")
    combatFrame:SetResizable(true)
    combatFrame:SetMinResize(150, 100)
    combatFrame:SetMaxResize(400, 500)
    
    -- Restore saved position or use default
    if settings.x and settings.y then
        RestorePosition(combatFrame, settings)
    else
        combatFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 150)
        SavePosition(combatFrame, settings)
    end
    
    -- Background
    combatFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    combatFrame:SetBackdropColor(0, 0, 0, 0.8)
    combatFrame:SetBackdropBorderColor(0.3, 0.3, 0.3)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, combatFrame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(24)
    titleBar:EnableMouse(true)
    combatFrame.titleBar = titleBar  -- Store reference
    
    -- Title
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("|cffFFCC00DC|r Combat")
    combatFrame.title = title
    
    -- Timer text (RIGHT relative to Close Button)
    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function()
        CombatLog.HideFrame()
    end)

    -- Timer text (RIGHT relative to Close Button)
    local timerText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    timerText:SetText("0:00")
    combatFrame.timerText = timerText

    -- Totals line (small), anchored under the timer area
    local totalsText = combatFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalsText:SetPoint("TOPRIGHT", timerText, "BOTTOMRIGHT", 0, -2)
    totalsText:SetJustifyH("RIGHT")
    totalsText:SetText("")
    totalsText:Hide()
    combatFrame.totalsText = totalsText

    -- Menu Button (Left of Timer)
    local menuBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    menuBtn:SetSize(25, 16)
    menuBtn:SetPoint("RIGHT", timerText, "LEFT", -10, 0)
    menuBtn:SetText("M")
    menuBtn:SetScript("OnClick", function(self)
        CombatLog.OpenMenu(self)
    end)
    menuBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Open Menu")
        GameTooltip:Show()
    end)
    menuBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Healing Button (Left of Menu)
    local healBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    healBtn:SetSize(25, 16)
    healBtn:SetPoint("RIGHT", menuBtn, "LEFT", -2, 0)
    healBtn:SetText("H")
    healBtn:SetScript("OnClick", function()
        addon:SetSetting("combatLog.meterMode", "healing")
        CombatLog.UpdateFrame()
    end)
    healBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Healing Done")
        GameTooltip:Show()
    end)
    healBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Damage Button (Left of Healing)
    local dmgBtn = CreateFrame("Button", nil, titleBar, "UIPanelButtonTemplate")
    dmgBtn:SetSize(25, 16)
    dmgBtn:SetPoint("RIGHT", healBtn, "LEFT", -2, 0)
    dmgBtn:SetText("D")
    dmgBtn:SetScript("OnClick", function()
        addon:SetSetting("combatLog.meterMode", "damage")
        CombatLog.UpdateFrame()
    end)
    dmgBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Damage Done")
        GameTooltip:Show()
    end)
    dmgBtn:SetScript("OnLeave", GameTooltip_Hide)
    
    -- Create bar frames
    for i = 1, 15 do
        barFrames[i] = CreateBar(combatFrame, i)
    end
    
    -- Bottom bar with stats
    local bottomBar = CreateFrame("Frame", nil, combatFrame)
    bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomBar:SetHeight(20)
    
    local resetBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    resetBtn:SetSize(50, 18)
    resetBtn:SetPoint("BOTTOMLEFT", 5, 2)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        ResetPlayerData()
        CombatLog.UpdateFrame()
    end)
    
    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, combatFrame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    combatFrame.resizeGrip = resizeGrip  -- Store reference
    resizeGrip:SetScript("OnMouseDown", function()
        if not settings.locked then
            combatFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        if not settings.locked then
            combatFrame:StopMovingOrSizing()
            local settings = addon.settings.combatLog
            settings.frameWidth = combatFrame:GetWidth()
            settings.frameHeight = combatFrame:GetHeight()
            SavePosition(combatFrame, settings)
            CombatLog.UpdateFrame()
        end
    end)
    
    -- Dragging
    titleBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not settings.locked then
            combatFrame:StartMoving()
        end
    end)
    titleBar:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not settings.locked then
            combatFrame:StopMovingOrSizing()
            local settings = addon.settings.combatLog
            SavePosition(combatFrame, settings)
        elseif button == "RightButton" then
            CombatLog.OpenMenu("cursor")
        end
    end)
    
    -- Update timer
    combatFrame:SetScript("OnUpdate", function(self, elapsed)
        self.updateElapsed = (self.updateElapsed or 0) + elapsed
        if self.updateElapsed >= 0.1 then
            self.updateElapsed = 0
            CombatLog.UpdateFrame()
        end
    end)
    
    -- Apply lock state
    CombatLog.UpdateLockState()
    
    if settings.hidden then
        combatFrame:Hide()
    else
        combatFrame:Show()
    end
    
    return combatFrame
end

function CombatLog.UpdateFrame()
    if not combatFrame then return end
    
    local settings = addon.settings.combatLog
    local combatTime = GetCombatTime()
    
    -- Update timer
    if combatFrame.timerText then
        combatFrame.timerText:SetText(FormatTime(combatTime))
    end
    
    -- Get sorted data and update title
    local mode = settings.meterMode or "damage"
    local modeNames = {
        damage = "Damage",
        healing = "Healing",
        damageTaken = "Damage Taken",
        dispels = "Dispels",
        interrupts = "Interrupts",
        deaths = "Deaths",
        cc = "CC Done",
        friendlyFire = "Friendly Fire"
    }
    
    local titleText = "|cffFFCC00DC|r " .. (modeNames[mode] or "Combat")
    
    if activeSegment and segments[activeSegment] then
        local seg = segments[activeSegment]
        titleText = titleText .. string.format(" (%s)", seg.name or ("Fight " .. tostring(seg.id or activeSegment)))
    else
        titleText = titleText .. " (Current)"
    end
    
    if combatFrame.title then
        if settings.totalsDisplay == "title" then
            local totals = GetActiveTotals()
            local short = string.format(
                "D:%s H:%s A:%s",
                FormatNumber((totals and totals.damage) or 0),
                FormatNumber((totals and totals.healing) or 0),
                FormatNumber((totals and totals.absorbs) or 0)
            )
            combatFrame.title:SetText(titleText .. "  " .. short)
        else
            combatFrame.title:SetText(titleText)
        end
    end

    -- Totals line (under timer)
    if combatFrame.totalsText then
        if settings.totalsDisplay == "line" then
            local totals, duration = GetActiveTotals()
            combatFrame.totalsText:SetText(FormatTotalsSummary(totals, duration))
            combatFrame.totalsText:Show()
        else
            combatFrame.totalsText:Hide()
        end
    end

    local sorted = {}
    local dataSource = playerData
    if activeSegment and segments[activeSegment] then
        dataSource = segments[activeSegment].data
    end
    if mode == "threat" then
        sorted = GetThreatSortedData()
    else
        sorted = GetSortedData(mode)
    end
    
    -- Find max value for bar scaling
    local maxValue = 0
    for _, data in ipairs(sorted) do
        if data.value > maxValue then maxValue = data.value end
    end
    
    -- Update bars
    local maxBars = math.min(settings.maxBars or 10, #barFrames)
    local barHeight = settings.barHeight or 18
    local extraTop = (settings.totalsDisplay == "line") and 14 or 0
    local topOffset = 28 + extraTop
    local visibleHeight = combatFrame:GetHeight() - (50 + extraTop)  -- Title + bottom bar (+ totals line)
    local barsToShow = math.min(math.floor(visibleHeight / (barHeight + 2)), maxBars)
    
    for i = 1, #barFrames do
        local bar = barFrames[i]
        
        if i <= barsToShow and sorted[i] then
            local data = sorted[i]
            local percent = maxValue > 0 and (data.value / maxValue * 100) or 0
            local perSec = combatTime > 0 and (data.value / combatTime) or 0
            
            -- Size and position
            bar:SetSize(combatFrame:GetWidth() - 10, barHeight)
            bar:SetPoint("TOPLEFT", 5, -topOffset - ((i - 1) * (barHeight + 2)))
            
            -- Color
            local r, g, b = GetClassColor(data.class)
            bar:SetStatusBarColor(r, g, b, 0.8)
            
            -- Values
            bar:SetValue(percent)
            bar.rank:SetText(i .. ".")
            bar.nameText:SetText(data.name)
            
            if mode == "damage" or mode == "healing" then
                bar.valueText:SetText(string.format("%s (%s)", FormatNumber(data.value), FormatNumber(perSec)))
            elseif mode == "damageTaken" then
                bar.valueText:SetText(string.format("%s (%s/s)", FormatNumber(data.value), FormatNumber(perSec)))
            elseif mode == "activity" then
                bar.valueText:SetText(FormatTime(data.value))
            elseif mode == "threat" then
                bar.valueText:SetText(string.format("%.1f%%", data.value))
            elseif mode == "consumables" then
                bar.valueText:SetText(string.format("%d", data.value))
            elseif mode == "killingBlows" or mode == "dispels" or mode == "interrupts" or mode == "deaths" or mode == "cc" then
                bar.valueText:SetText(string.format("%d", data.value))
            else
                bar.valueText:SetText(FormatNumber(data.value))
            end
            
            -- Store data for tooltip
            bar.data = dataSource and dataSource[data.guid] or playerData[data.guid]
            bar:Show()
        else
            bar:Hide()
        end
    end
end

function CombatLog.ShowFrame()
    addon:SetSetting("combatLog.hidden", false)
    if not combatFrame then
        CreateCombatFrame()
    end

    local settings = addon.settings.combatLog
    if combatFrame.SetFrameStrata then
        combatFrame:SetFrameStrata("DIALOG")
    end
    if combatFrame.SetToplevel then
        combatFrame:SetToplevel(true)
    end
    combatFrame:Show()
    if combatFrame.Raise then combatFrame:Raise() end
    EnsureOnScreen(combatFrame, settings)
end

function CombatLog.HideFrame()
    addon:SetSetting("combatLog.hidden", true)
    if combatFrame then
        combatFrame:Hide()
    end
end

-- Lock/unlock the window to prevent dragging and resizing
function CombatLog.ToggleLock()
    local settings = addon.settings.combatLog
    settings.locked = not settings.locked
    
    if combatFrame then
        CombatLog.UpdateLockState()
    end
    
    addon:Print(settings.locked and "Combat window locked" or "Combat window unlocked", true)
end

function CombatLog.UpdateLockState()
    if not combatFrame then return end
    
    local settings = addon.settings.combatLog
    local titleBar = combatFrame.titleBar
    local resizeGrip = combatFrame.resizeGrip
    
    if settings.locked then
        -- Disable dragging and resizing
        combatFrame:SetMovable(false)
        combatFrame:EnableMouse(false)
        if titleBar then titleBar:EnableMouse(false) end
        if resizeGrip then resizeGrip:Hide() end
        
        -- Update border to show locked state
        combatFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
    else
        -- Enable dragging and resizing
        combatFrame:SetMovable(true)
        combatFrame:EnableMouse(true)
        if titleBar then titleBar:EnableMouse(true) end
        if resizeGrip then resizeGrip:Show() end
        
        -- Restore normal border
        combatFrame:SetBackdropBorderColor(0.3, 0.3, 0.3)
    end
end

-- ============================================================
-- Death Recap
-- ============================================================
function CombatLog.GetDeathLogEntries(data, newestFirst)
    if not data then return {} end
    InitDeathLogBuffer(data)
    return ExtractDeathLogEntries(data.deathLog, newestFirst ~= false)
end

local function ShowDeathRecap()
    local settings = addon.settings.combatLog
    if not settings.deathRecap then return end

    local data = GetPlayerData(playerGUID, playerName)
    local entries = CombatLog.GetDeathLogEntries(data, false)
    if #entries == 0 then
        addon:Print("No damage recorded before death.", true)
        return
    end
    
    addon:Print("=== Death Recap ===", true)
    
    local count = math.min(settings.deathRecapCount, #entries)
    for i = #entries - count + 1, #entries do
        local entry = entries[i]
        if entry then
            local hpText = ""
            if entry.hp and entry.maxhp then
                hpText = string.format(" [HP: %d/%d - %.1f%%]", entry.hp, entry.maxhp, entry.hpPercent or 0)
            end
            local extraText = ""
            if entry.overkill and entry.overkill > 0 then
                extraText = extraText .. string.format(" |cffff0000Overkill: %s|r", FormatNumber(entry.overkill))
            end
            if entry.absorbed and entry.absorbed > 0 then
                extraText = extraText .. string.format(" |cff00ff00Absorbed: %s|r", FormatNumber(entry.absorbed))
            end
            print(string.format("  |cffff6600%s|r from %s (%s)%s%s", 
                FormatNumber(entry.amount), 
                entry.source, 
                entry.spell,
                hpText,
                extraText))
        end
    end
end

-- ============================================================
-- Spell Breakdown Display
-- ============================================================
local function ShowSpellBreakdown(playerNameOrGuid)
    local settings = addon.settings.combatLog
    local targetData = nil
    local targetName = nil
    
    -- Find player data
    if not playerNameOrGuid or playerNameOrGuid == "" then
        -- Default to current player
        targetData = playerData[playerGUID]
        targetName = playerName
    else
        for guid, data in pairs(playerData) do
            if data.name == playerNameOrGuid or guid == playerNameOrGuid then
                targetData = data
                targetName = data.name
                break
            end
        end
    end
    
    if not targetData or not targetData.spells then
        addon:Print("No spell data available.", true)
        return
    end
    
    -- Sort spells by damage/healing
    local mode = settings.meterMode or "damage"
    local sorted = {}
    
    for spellId, spell in pairs(targetData.spells) do
        local value = mode == "healing" and spell.healing or spell.damage
        if value > 0 then
            table.insert(sorted, {
                id = spellId,
                name = spell.name,
                value = value,
                hits = spell.hits,
                crits = spell.crits,
            })
        end
    end
    
    table.sort(sorted, function(a, b) return a.value > b.value end)
    
    local combatTime = GetCombatTime()
    local totalValue = mode == "healing" and targetData.healing or targetData.damage
    
    addon:Print(string.format("=== Spell Breakdown: %s ===", targetName), true)
    
    local maxSpells = settings.maxSpells or 5
    for i = 1, math.min(maxSpells, #sorted) do
        local spell = sorted[i]
        local pct = totalValue > 0 and (spell.value / totalValue * 100) or 0
        local critPct = spell.hits > 0 and (spell.crits / spell.hits * 100) or 0
        local perSec = combatTime > 0 and (spell.value / combatTime) or 0
        
        print(string.format("  %d. |cffffd700%s|r - %s (%.1f%%) | %s/s | %d hits (%.0f%% crit)",
            i,
            spell.name,
            FormatNumber(spell.value),
            pct,
            FormatNumber(perSec),
            spell.hits,
            critPct
        ))
    end
end

-- Show dispels summary
local function ShowDispels()
    addon:Print("=== Dispel Summary ===", true)
    
    local sorted = {}
    for guid, data in pairs(playerData) do
        if data.dispels and data.dispels > 0 then
            table.insert(sorted, { name = data.name, dispels = data.dispels })
        end
    end
    
    table.sort(sorted, function(a, b) return a.dispels > b.dispels end)
    
    if #sorted == 0 then
        print("  No dispels recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %d dispels", i, entry.name, entry.dispels))
    end
end

function CombatLog.OpenMenu(anchor)
    local settings = addon.settings.combatLog

    local function SetTotalsDisplay(mode)
        addon:SetSetting("combatLog.totalsDisplay", mode)
        CombatLog.UpdateFrame()
    end

    local totalsDisplay = settings.totalsDisplay or "line"
    local currentText = "Current Fight"
    if totalsDisplay == "menu" then
        local totals = { damage = 0, healing = 0 }
        for _, data in pairs(playerData) do
            totals.damage = totals.damage + (data.damage or 0)
            totals.healing = totals.healing + (data.healing or 0)
        end
        currentText = string.format(
            "Current Fight  D:%s H:%s",
            FormatNumber(totals.damage),
            FormatNumber(totals.healing)
        )
    end

    local menu = {
        { text = "|cffFFCC00DC Combat Menu|r", isTitle = true, notCheckable = true },
        { text = "Reset Stats", func = function()
            ResetPlayerData()
            SelectSegment(0)
            CombatLog.UpdateFrame()
            addon:Print("Combat stats reset.", true)
        end, notCheckable = true },
        
        { text = "Segments", isTitle = true, notCheckable = true },
        { text = currentText, func = function() SelectSegment(0) end, checked = function() return activeSegment == nil end },
    }
    
    -- Add history segments
    for i, seg in ipairs(segments) do
        local segLabel = seg.name or ("Fight " .. tostring(seg.id or i))
        local segText = string.format("%s (%s)", segLabel, FormatTime(seg.duration))
        if totalsDisplay == "menu" and seg.totals then
            segText = string.format(
                "%s (%s)  D:%s H:%s",
                segLabel,
                FormatTime(seg.duration),
                FormatNumber(seg.totals.damage or 0),
                FormatNumber(seg.totals.healing or 0)
            )
        end
        table.insert(menu, {
            text = segText,
            func = function() SelectSegment(i) end,
            checked = function() return activeSegment == i end
        })
    end 
    
    local modes = {
        { text = "Modes", isTitle = true, notCheckable = true },
        { text = "Damage Done", func = function()
            addon:SetSetting("combatLog.meterMode", "damage")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "damage" end },
        { text = "Healing Done", func = function()
            addon:SetSetting("combatLog.meterMode", "healing")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "healing" end },
        { text = "Damage Taken", func = function()
            addon:SetSetting("combatLog.meterMode", "damageTaken")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "damageTaken" end },
        { text = "Dispels", func = function()
            addon:SetSetting("combatLog.meterMode", "dispels")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "dispels" end },
        { text = "Interrupts", func = function()
            addon:SetSetting("combatLog.meterMode", "interrupts")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "interrupts" end },
        { text = "Deaths", func = function()
            addon:SetSetting("combatLog.meterMode", "deaths")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "deaths" end },
        { text = "CC Done", func = function()
            addon:SetSetting("combatLog.meterMode", "cc")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "cc" end },
        { text = "Friendly Fire", func = function()
            addon:SetSetting("combatLog.meterMode", "friendlyFire")
            CombatLog.UpdateFrame()
        end, checked = function() return addon.settings.combatLog.meterMode == "friendlyFire" end },
        { text = " ", isTitle = true, notCheckable = true },
        { text = "Totals Display", isTitle = true, notCheckable = true },
        { text = "Off", func = function() SetTotalsDisplay("off") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "off" end },
        { text = "Small Line", func = function() SetTotalsDisplay("line") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "line" end },
        { text = "Title Bar", func = function() SetTotalsDisplay("title") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "title" end },
        { text = "Segment Menu", func = function() SetTotalsDisplay("menu") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "menu" end },
        { text = " ", isTitle = true, notCheckable = true },
        { text = settings.locked and "Unlock Window" or "Lock Window", func = function()
            CombatLog.ToggleLock()
        end, notCheckable = true },
        { text = "Hide Window", func = function()
            CombatLog.HideFrame()
        end, notCheckable = true },
        { text = "Close Menu", func = function() end, notCheckable = true },
    }
    
    for _, m in ipairs(modes) do table.insert(menu, m) end
            
    -- Ensure menu frame exists
    if not CombatLog.menuFrame then
        CombatLog.menuFrame = CreateFrame("Frame", "DCQoS_CombatLogMenu", UIParent, "UIDropDownMenuTemplate")
    end

    -- Show the menu
    EasyMenu(menu, CombatLog.menuFrame, anchor or "cursor", 0, 0, "MENU")
end

-- Show activity summary
local function ShowActivity()
    addon:Print("=== Activity Summary ===", true)
    
    local combatTime = GetCombatTime()
    if combatTime == 0 then
        print("  No combat time recorded.")
        return
    end
    
    local sorted = {}
    for guid, data in pairs(playerData) do
        if data.activeTime and data.activeTime > 0 then
            local activityPct = (data.activeTime / combatTime) * 100
            table.insert(sorted, { 
                name = data.name, 
                activeTime = data.activeTime,
                activityPct = activityPct
            })
        end
    end
    
    table.sort(sorted, function(a, b) return a.activeTime > b.activeTime end)
    
    if #sorted == 0 then
        print("  No activity recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %s (%.1f%%)", 
            i, entry.name, FormatTime(entry.activeTime), entry.activityPct))
    end
end

-- Show killing blows
local function ShowKillingBlows()
    addon:Print("=== Killing Blows ===", true)
    
    local sorted = {}
    for guid, data in pairs(playerData) do
        if data.killingBlows and data.killingBlows > 0 then
            table.insert(sorted, { name = data.name, kbs = data.killingBlows })
        end
    end
    
    table.sort(sorted, function(a, b) return a.kbs > b.kbs end)
    
    if #sorted == 0 then
        print("  No killing blows recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %d killing blows", i, entry.name, entry.kbs))
    end
end

-- Show CC summary
local function ShowCrowdControl()
    addon:Print("=== Crowd Control Summary ===", true)
    
    local sorted = {}
    for guid, data in pairs(playerData) do
        if data.ccDone and data.ccDone > 0 then
            table.insert(sorted, { name = data.name, cc = data.ccDone })
        end
    end
    
    table.sort(sorted, function(a, b) return a.cc > b.cc end)
    
    if #sorted == 0 then
        print("  No CC recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %d CC applications", i, entry.name, entry.cc))
    end
end

-- Show power gains
local function ShowPowerGains()
    addon:Print("=== Power Gains ===", true)
    
    for guid, data in pairs(playerData) do
        if data.manaGain > 0 or data.rageGain > 0 or data.energyGain > 0 or data.runicGain > 0 then
            print(string.format("|cffffd700%s|r:", data.name))
            if data.manaGain > 0 then
                print(string.format("  Mana: %s", FormatNumber(data.manaGain)))
            end
            if data.rageGain > 0 then
                print(string.format("  Rage: %s", FormatNumber(data.rageGain)))
            end
            if data.energyGain > 0 then
                print(string.format("  Energy: %s", FormatNumber(data.energyGain)))
            end
            if data.runicGain > 0 then
                print(string.format("  Runic Power: %s", FormatNumber(data.runicGain)))
            end
        end
    end
end

-- Show friendly fire
local function ShowFriendlyFire()
    addon:Print("=== Friendly Fire ===", true)
    
    local sorted = {}
    for guid, data in pairs(playerData) do
        if data.friendlyDamage and data.friendlyDamage > 0 then
            table.insert(sorted, { name = data.name, damage = data.friendlyDamage })
        end
    end
    
    table.sort(sorted, function(a, b) return a.damage > b.damage end)
    
    if #sorted == 0 then
        print("  No friendly fire recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %s damage to allies", 
            i, entry.name, FormatNumber(entry.damage)))
    end
end

-- Show consumables usage
local function ShowConsumables()
    addon:Print("=== Consumables Usage ===", true)
    
    for guid, data in pairs(playerData) do
        if (data.potionsUsed and data.potionsUsed > 0) or (data.healthstonesUsed and data.healthstonesUsed > 0) then
            print(string.format("|cffffd700%s|r:", data.name))
            if data.potionsUsed > 0 then
                print(string.format("  Potions: %d", data.potionsUsed))
            end
            if data.healthstonesUsed > 0 then
                print(string.format("  Healthstones: %d", data.healthstonesUsed))
            end
        end
    end
end

-- Show absorbs summary
local function ShowAbsorbs()
    addon:Print("=== Absorb Summary ===", true)
    
    local combatTime = GetCombatTime()
    local sorted = {}
    
    for guid, data in pairs(playerData) do
        if data.absorbs and data.absorbs > 0 then
            table.insert(sorted, { 
                name = data.name, 
                absorbs = data.absorbs,
                aps = combatTime > 0 and (data.absorbs / combatTime) or 0
            })
        end
    end
    
    table.sort(sorted, function(a, b) return a.absorbs > b.absorbs end)
    
    if #sorted == 0 then
        print("  No absorbs recorded.")
        return
    end
    
    for i, entry in ipairs(sorted) do
        print(string.format("  %d. %s - %s (%s/s)", 
            i, entry.name, FormatNumber(entry.absorbs), FormatNumber(entry.aps)))
    end
end

-- ============================================================
-- Combat Log Event Handler (3.3.5a compatible)
-- ============================================================
local eventFrame = CreateFrame("Frame")

local function FindGroupUnitByGUID(guid)
    if not guid then return nil end
    if UnitGUID("player") == guid then
        return "player"
    end
    for i = 1, 4 do
        if UnitGUID("party" .. i) == guid then
            return "party" .. i
        end
    end
    for i = 1, 40 do
        if UnitGUID("raid" .. i) == guid then
            return "raid" .. i
        end
    end
    return nil
end

local function EnsureAvoidanceTable(data)
    if not data.avoidanceTable then
        data.avoidanceTable = {
            dodges = 0,
            parries = 0,
            misses = 0,
            blocks = 0,
            resists = 0,
            absorbs = 0,
            absorbed = 0,
            blockedAmount = 0,
            resistedAmount = 0,
            absorbedAmount = 0,
        }
    end
end

local function UpdateActivity(data)
    local currentTime = GetTime()
    if not data.lastActive or data.lastActive == 0 then
        data.lastActive = currentTime
    else
        local delta = currentTime - data.lastActive
        if delta > 0 and delta < 10 then -- Allow gaps up to 10 seconds
            data.activeTime = (data.activeTime or 0) + delta
        end
        data.lastActive = currentTime
    end
end

local function OnCombatLogEvent(...)
    local settings = addon.settings.combatLog
    if not settings.enabled then return end
    
    local timestamp, event, sourceGUID, sourceName, sourceFlags, 
          destGUID, destName, destFlags = select(1, ...)
    
    -- DEBUG INFO
    -- if event:find("_DAMAGE") then
    --    print("DEBUG: Event="..event.." Source="..(sourceName or "nil").." flags="..(sourceFlags or "nil"))
    -- end
    
    local arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = select(9, ...)

    do
        local timelineSpellId = nil
        local timelineSpellName = nil
        local timelineAmount = nil
        local timelineOverkill = nil
        local timelineAbsorbed = nil
        local timelineSchool = nil

        if event == "SWING_DAMAGE" then
            timelineAmount = arg9 or 0
            timelineOverkill = arg10 or 0
            timelineSchool = arg11 or 0
            timelineAbsorbed = arg14 or 0
        elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
            timelineSpellId = arg9
            timelineSpellName = arg10
            timelineSchool = arg11 or 0
            timelineAmount = arg12 or 0
            timelineOverkill = arg13 or 0
            timelineAbsorbed = arg16 or 0
        elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
            timelineSpellId = arg9
            timelineSpellName = arg10
            timelineAmount = arg12 or 0
            timelineOverkill = 0
            timelineAbsorbed = arg14 or 0
        elseif event == "SPELL_MISSED" or event == "RANGE_MISSED" then
            timelineSpellId = arg9
            timelineSpellName = arg10
        elseif event == "SPELL_ENERGIZE" then
            timelineSpellId = arg9
            timelineSpellName = arg10
            timelineAmount = arg12 or 0
        elseif event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED" then
            timelineSpellId = arg9
            timelineSpellName = arg10
        end

        RecordTimelineEvent(timestamp, event, sourceGUID, sourceName, destGUID, destName, timelineSpellId, timelineSpellName, timelineAmount, timelineOverkill, timelineAbsorbed, timelineSchool)
    end
    
    -- Check if source is in our group
    if not playerGUID then playerGUID = UnitGUID("player") end -- Safety check
    
    local isGroupSource = sourceGUID == playerGUID
    if settings.trackGroup and not isGroupSource then
        if bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 or
           bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0 or
           bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0 or
           (bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET) > 0 and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0) or 
           (bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0 and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0) then
            isGroupSource = true
        end
    end

    -- Check if destination is in our group (used for friendly fire, smart combat start, etc.)
    local isGroupDest = destGUID == playerGUID
    if settings.trackGroup and not isGroupDest then
        if bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0 or
           bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0 or
           bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 then
            isGroupDest = true
        end
    end

    local isPetSource = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET) > 0 or bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0
    local ownerGUID = nil
    local ownerData = nil
    local petStats = nil

    if isPetSource and settings.trackGroup then
        ownerGUID = ResolvePetOwner(sourceGUID)
        if ownerGUID then
            local ownerUnit = FindGroupUnitByGUID(ownerGUID)
            local ownerName = ownerUnit and UnitName(ownerUnit) or nil
            ownerData = GetPlayerData(ownerGUID, ownerName)
            if ownerData and (settings.trackPetDamage or settings.trackPetHealing) then
                ownerData.pets = ownerData.pets or {}
                ownerData.pets[sourceGUID] = ownerData.pets[sourceGUID] or { name = sourceName or "Pet", damage = 0, healing = 0 }
                petStats = ownerData.pets[sourceGUID]
            end
        end
    end
    -- Helper to track spell breakdown with comprehensive stats
    local function TrackSpell(data, spellId, spellName, amount, isCrit, isHealing, isGlancing, missType, absorbed, overkill)
        if not data.spells then data.spells = {} end
        if not spellId then spellId = 0 end
        
        if not data.spells[spellId] then
            data.spells[spellId] = {
                name = spellName or "Unknown",
                damage = 0,
                healing = 0,
                hits = 0,
                crits = 0,
                glancing = 0,
                -- Crit tracking
                critDamage = 0,
                critMin = nil,
                critMax = nil,
                -- Normal hit tracking
                normalHits = 0,
                normalDamage = 0,
                normalMin = nil,
                normalMax = nil,
                -- Miss tracking
                misses = 0,
                dodges = 0,
                parries = 0,
                blocks = 0,
                resists = 0,
                -- Advanced
                absorbed = 0,
                overkill = 0,
            }
        end
        
        local spell = data.spells[spellId]
        
        -- Track miss types
        if missType and MISS_TYPES[missType] then
            spell[MISS_TYPES[missType]] = (spell[MISS_TYPES[missType]] or 0) + 1
            return  -- Don't count as hit
        end
        
        spell.hits = spell.hits + 1
        
        -- Track absorbed/overkill
        if absorbed and absorbed > 0 then
            spell.absorbed = spell.absorbed + absorbed
        end
        if overkill and overkill > 0 then
            spell.overkill = spell.overkill + overkill
        end
        
        if isHealing then
            spell.healing = spell.healing + (amount or 0)
        else
            spell.damage = spell.damage + (amount or 0)
            
            -- Track crit details
            if isCrit then
                spell.crits = spell.crits + 1
                spell.critDamage = spell.critDamage + amount
                if not spell.critMin or amount < spell.critMin then
                    spell.critMin = amount
                end
                if not spell.critMax or amount > spell.critMax then
                    spell.critMax = amount
                end
            elseif isGlancing then
                spell.glancing = spell.glancing + 1
            else
                -- Normal hit
                spell.normalHits = spell.normalHits + 1
                spell.normalDamage = spell.normalDamage + amount
                if not spell.normalMin or amount < spell.normalMin then
                    spell.normalMin = amount
                end
                if not spell.normalMax or amount > spell.normalMax then
                    spell.normalMax = amount
                end
            end
        end
    end
    
    -- Track damage/healing dealt
    if isGroupSource then
        local data = ownerData or GetPlayerData(sourceGUID, sourceName, sourceFlags)
        if data then
            UpdateActivity(data)
            
            if event == "SWING_DAMAGE" then
                local amount = arg9 or 0
                local overkill = arg10 or 0
                local school = arg11 or 0
                local resisted = arg12 or 0
                local blocked = arg13 or 0
                local absorbed = arg14 or 0
                local critical = arg15
                local glancing = arg16
                
                data.damage = data.damage + amount
                if petStats and settings.trackPetDamage then
                    petStats.damage = petStats.damage + amount
                    data.petDamage = (data.petDamage or 0) + amount
                end
                
                if overkill > 0 then data.overkill = data.overkill + overkill end
                if absorbed > 0 then data.totalDamage = data.totalDamage + amount + absorbed end
                
                TrackSpell(data, 0, "Melee", amount, critical, false, glancing, nil, absorbed, overkill)
                
            elseif event == "SWING_MISSED" then
                local missType = arg9
                local data = GetPlayerData(sourceGUID, sourceName, sourceFlags)
                if data and MISS_TYPES[missType] then
                    data[MISS_TYPES[missType]] = (data[MISS_TYPES[missType]] or 0) + 1
                    TrackSpell(data, 0, "Melee", 0, false, false, false, missType, 0, 0)
                end
                
            elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
                local spellId = arg9
                local spellName = arg10
                local school = arg11
                local amount = arg12 or 0
                local overkill = arg13 or 0
                local resisted = arg14 or 0
                local blocked = arg15 or 0
                local absorbed = arg16 or 0
                local critical = arg17
                local glancing = arg18
                
                data.damage = data.damage + amount
                if petStats and settings.trackPetDamage then
                    petStats.damage = petStats.damage + amount
                    data.petDamage = (data.petDamage or 0) + amount
                end

                if overkill > 0 then data.overkill = data.overkill + overkill end
                if absorbed > 0 then data.totalDamage = data.totalDamage + amount + absorbed end
                
                TrackSpell(data, spellId, spellName, amount, critical, false, glancing, nil, absorbed, overkill)
            
            elseif event == "SPELL_MISSED" or event == "RANGE_MISSED" then
                local spellId = arg9
                local spellName = arg10
                local missType = arg12
                if MISS_TYPES[missType] then
                    data[MISS_TYPES[missType]] = (data[MISS_TYPES[missType]] or 0) + 1
                    TrackSpell(data, spellId, spellName, 0, false, false, false, missType, 0, 0)
                end
                
            elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
                local spellId = arg9
                local spellName = arg10
                local amount = arg12 or 0
                local overheal = arg13 or 0
                local absorbed = arg14 or 0
                local critical = arg15
                local effectiveHeal = amount - overheal
                data.healing = data.healing + effectiveHeal
                if petStats and settings.trackPetHealing then
                    petStats.healing = petStats.healing + effectiveHeal
                    data.petHealing = (data.petHealing or 0) + effectiveHeal
                end
                data.overhealing = data.overhealing + overheal
                data.totalHealing = data.totalHealing + amount
                TrackSpell(data, spellId, spellName, effectiveHeal, critical, true, false, nil, absorbed, 0)
                
            elseif event == "SPELL_INTERRUPT" then
                data.interrupts = data.interrupts + 1
                
                if sourceGUID == playerGUID and settings.announceInterrupts then
                    local interruptedSpell = arg13 or "Unknown"
                    local msg = string.format("Interrupted %s's %s!", destName or "Unknown", interruptedSpell)
                    if settings.interruptChannel == "SAY" then
                        SendChatMessage(msg, "SAY")
                    elseif settings.interruptChannel == "PARTY" then
                        SendChatMessage(msg, "PARTY")
                    elseif settings.interruptChannel == "RAID" then
                        SendChatMessage(msg, "RAID")
                    end
                end
                
            elseif event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
                if settings.trackDispels then
                    data.dispels = data.dispels + 1
                end
                
            elseif event == "SPELL_AURA_APPLIED" then
                local spellId = arg9
                -- Track CC applications
                if settings.trackCrowdControl and CC_SPELLS[spellId] then
                    data.ccDone = data.ccDone + 1
                    data.ccSpells[spellId] = (data.ccSpells[spellId] or 0) + 1
                end
                
                -- Track consumable usage
                if CONSUMABLE_SPELLS[spellId] then
                    if CONSUMABLE_SPELLS[spellId] == "potion" then
                        data.potionsUsed = data.potionsUsed + 1
                    elseif CONSUMABLE_SPELLS[spellId] == "healthstone" then
                        data.healthstonesUsed = data.healthstonesUsed + 1
                    end
                end
                
            elseif event == "SPELL_RESURRECT" then
                if settings.trackResurrects then
                    data.resurrects = data.resurrects + 1
                end
                
            elseif event == "SPELL_ENERGIZE" then
                if settings.trackPowerGains then
                    local spellId = arg9
                    local amount = arg12 or 0
                    local powerType = arg13
                    
                    if powerType == POWER_TYPE_MANA then
                        data.manaGain = data.manaGain + amount
                    elseif powerType == POWER_TYPE_RAGE then
                        data.rageGain = data.rageGain + amount
                    elseif powerType == POWER_TYPE_ENERGY or powerType == POWER_TYPE_FOCUS then
                        data.energyGain = data.energyGain + amount
                    elseif powerType == POWER_TYPE_RUNIC then
                        data.runicGain = data.runicGain + amount
                    end
                end
            end
        end
    end

    -- Track damage taken, avoidance, mitigation, and death log for group members
    if isGroupDest then
        local destData = GetPlayerData(destGUID, destName, destFlags)
        if destData then
            UpdateActivity(destData)
            EnsureAvoidanceTable(destData)

            if event == "SWING_DAMAGE" then
                local amount = arg9 or 0
                local overkill = arg10 or 0
                local school = arg11 or 0
                local resisted = arg12 or 0
                local blocked = arg13 or 0
                local absorbed = arg14 or 0
                local critical = arg15
                local glancing = arg16

                destData.damageTaken = destData.damageTaken + amount
                destData.damageTakenBySpell[0] = destData.damageTakenBySpell[0] or { amount = 0, hits = 0 }
                destData.damageTakenBySpell[0].amount = destData.damageTakenBySpell[0].amount + amount
                destData.damageTakenBySpell[0].hits = destData.damageTakenBySpell[0].hits + 1

                destData.damageTakenFrom[sourceGUID] = (destData.damageTakenFrom[sourceGUID] or 0) + amount

                if settings.trackMitigation then
                    if blocked > 0 then
                        destData.blockAmount = destData.blockAmount + blocked
                        destData.avoidanceTable.blockedAmount = destData.avoidanceTable.blockedAmount + blocked
                    end
                    if resisted > 0 then
                        destData.resistAmount = destData.resistAmount + resisted
                        destData.avoidanceTable.resistedAmount = destData.avoidanceTable.resistedAmount + resisted
                    end
                    if absorbed > 0 then
                        destData.absorbedAmount = destData.absorbedAmount + absorbed
                        destData.avoidanceTable.absorbedAmount = destData.avoidanceTable.absorbedAmount + absorbed
                        destData.avoidanceTable.absorbed = destData.avoidanceTable.absorbed + 1
                    end
                end

                AddDeathLogEntry(destGUID, "damage", {
                    sourceName = sourceName,
                    spellName = "Melee",
                    spellId = 0,
                    amount = amount,
                    overkill = overkill,
                    absorbed = absorbed,
                    critical = critical,
                    glancing = glancing,
                    school = school,
                })

            elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
                local spellId = arg9
                local spellName = arg10
                local school = arg11
                local amount = arg12 or 0
                local overkill = arg13 or 0
                local resisted = arg14 or 0
                local blocked = arg15 or 0
                local absorbed = arg16 or 0
                local critical = arg17
                local glancing = arg18

                destData.damageTaken = destData.damageTaken + amount
                destData.damageTakenBySpell[spellId] = destData.damageTakenBySpell[spellId] or { amount = 0, hits = 0 }
                destData.damageTakenBySpell[spellId].amount = destData.damageTakenBySpell[spellId].amount + amount
                destData.damageTakenBySpell[spellId].hits = destData.damageTakenBySpell[spellId].hits + 1

                destData.damageTakenFrom[sourceGUID] = (destData.damageTakenFrom[sourceGUID] or 0) + amount

                if settings.trackMitigation then
                    if blocked > 0 then
                        destData.blockAmount = destData.blockAmount + blocked
                        destData.avoidanceTable.blockedAmount = destData.avoidanceTable.blockedAmount + blocked
                    end
                    if resisted > 0 then
                        destData.resistAmount = destData.resistAmount + resisted
                        destData.avoidanceTable.resistedAmount = destData.avoidanceTable.resistedAmount + resisted
                    end
                    if absorbed > 0 then
                        destData.absorbedAmount = destData.absorbedAmount + absorbed
                        destData.avoidanceTable.absorbedAmount = destData.avoidanceTable.absorbedAmount + absorbed
                        destData.avoidanceTable.absorbed = destData.avoidanceTable.absorbed + 1
                    end
                end

                AddDeathLogEntry(destGUID, "damage", {
                    sourceName = sourceName,
                    spellName = spellName,
                    spellId = spellId,
                    amount = amount,
                    overkill = overkill,
                    absorbed = absorbed,
                    critical = critical,
                    glancing = glancing,
                    school = school,
                })

            elseif event == "ENVIRONMENTAL_DAMAGE" then
                local envType = arg9 or "Environment"
                local amount = arg10 or 0
                destData.damageTaken = destData.damageTaken + amount
                destData.damageTakenBySpell[-1] = destData.damageTakenBySpell[-1] or { amount = 0, hits = 0 }
                destData.damageTakenBySpell[-1].amount = destData.damageTakenBySpell[-1].amount + amount
                destData.damageTakenBySpell[-1].hits = destData.damageTakenBySpell[-1].hits + 1

                AddDeathLogEntry(destGUID, "damage", {
                    sourceName = envType,
                    spellName = envType,
                    spellId = -1,
                    amount = amount,
                })

            elseif event == "SWING_MISSED" then
                local missType = arg9
                if settings.trackAvoidance and MISS_TYPES[missType] then
                    if missType ~= "ABSORB" then
                        destData[MISS_TYPES[missType]] = (destData[MISS_TYPES[missType]] or 0) + 1
                    end
                    destData.avoidance = destData.avoidance + 1
                    if missType == "ABSORB" then
                        destData.avoidanceTable.absorbs = (destData.avoidanceTable.absorbs or 0) + 1
                    else
                        destData.avoidanceTable[MISS_TYPES[missType]] = (destData.avoidanceTable[MISS_TYPES[missType]] or 0) + 1
                    end
                end

            elseif event == "SPELL_MISSED" or event == "RANGE_MISSED" then
                local missType = arg12
                if settings.trackAvoidance and MISS_TYPES[missType] then
                    if missType ~= "ABSORB" then
                        destData[MISS_TYPES[missType]] = (destData[MISS_TYPES[missType]] or 0) + 1
                    end
                    destData.avoidance = destData.avoidance + 1
                    if missType == "ABSORB" then
                        destData.avoidanceTable.absorbs = (destData.avoidanceTable.absorbs or 0) + 1
                    else
                        destData.avoidanceTable[MISS_TYPES[missType]] = (destData.avoidanceTable[MISS_TYPES[missType]] or 0) + 1
                    end
                end

            elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
                if settings.trackHealingTaken then
                    local spellId = arg9
                    local spellName = arg10
                    local amount = arg12 or 0
                    local overheal = arg13 or 0
                    local effectiveHeal = amount - overheal

                    destData.healingTakenFrom[sourceGUID] = (destData.healingTakenFrom[sourceGUID] or 0) + effectiveHeal
                    destData.healingTaken = (destData.healingTaken or 0) + effectiveHeal

                    AddDeathLogEntry(destGUID, "heal", {
                        sourceName = sourceName,
                        spellName = spellName,
                        spellId = spellId,
                        amount = effectiveHeal,
                    })
                end

            elseif event == "SPELL_AURA_APPLIED" and settings.deathRecapShowBuffs then
                local spellId = arg9
                local spellName = arg10
                local auraType = arg12
                if auraType == "BUFF" then
                    AddDeathLogEntry(destGUID, "buff", { spellName = spellName, spellId = spellId })
                else
                    AddDeathLogEntry(destGUID, "debuff", { spellName = spellName, spellId = spellId })
                end
            elseif event == "UNIT_DIED" then
                if destGUID ~= playerGUID then
                    destData.deaths = (destData.deaths or 0) + 1
                end
            end
        end
    end

    -- Track absorbs on group members (destination)
    if settings.trackAbsorbs then
        local isGroupDest = destGUID == playerGUID
        if settings.trackGroup and not isGroupDest then
            if bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0 or
               bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0 or
               (bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PET) > 0 and bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0) then
                isGroupDest = true
            end
        end
        
        if isGroupDest and event == "SPELL_ABSORBED" then
            -- Track absorb shields that absorbed damage
            local absorbSourceGUID = arg12
            local absorbSourceName = arg13
            local absorbAmount = arg17 or arg14 or 0
            
            if absorbSourceGUID then
                local data = GetPlayerData(absorbSourceGUID, absorbSourceName)
                if data then
                    data.absorbs = (data.absorbs or 0) + absorbAmount
                end
            end
        end
    end
    
    -- Track damage to friendlies (friendly fire)
    if settings.trackFriendlyFire and isGroupSource then
        if isGroupDest and sourceGUID ~= destGUID then
            local data = GetPlayerData(sourceGUID, sourceName, sourceFlags)
            if data then
                local amount = 0
                if event == "SWING_DAMAGE" then
                    amount = arg9 or 0
                elseif event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" then
                    amount = arg12 or 0
                end
                if amount > 0 then
                    data.friendlyDamage = data.friendlyDamage + amount
                end
            end
        end
    end
    
    -- Track killing blows
    if event == "PARTY_KILL" or event == "UNIT_DIED" then
        if settings.trackKillingBlows and isGroupSource and sourceGUID ~= destGUID then
            local data = GetPlayerData(sourceGUID, sourceName, sourceFlags)
            if data then
                data.killingBlows = data.killingBlows + 1
            end
        end
    end
    
    -- Smart Combat Start: If we deal damage/healing but aren't "in combat" yet
    if not inCombat and (isGroupSource or isGroupDest) then
        local currentTime = GetTime()
        -- If it's been > 3 seconds since last fight ended, assume new fight
        if (currentTime - combatEndTime) > 3 then
            inCombat = true
            combatStartTime = currentTime
            ResetPlayerData()
            
            if settings.showMeter and not settings.hidden then
                CombatLog.ShowFrame()
            end
            addon:Debug("Smart Combat Start triggered")
        end
    end

end

local function OnCombatEvent(self, event, ...)
    local settings = addon.settings.combatLog
    if not settings.enabled then return end
    
    if event == "PLAYER_REGEN_DISABLED" then
        -- Only start/reset if we didn't already start via Smart Start
        if not inCombat or (GetTime() - combatStartTime) > 5 then
            inCombat = true
            combatStartTime = GetTime()
            ResetPlayerData()
            
            if settings.showMeter then
                if settings.autoShowInCombat ~= false then
                    if not combatFrame then
                        CreateCombatFrame()
                    end
                    combatFrame:Show()
                elseif not settings.hidden then
                    CombatLog.ShowFrame()
                end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        combatEndTime = GetTime()
        SaveSegment()
        CombatLog.UpdateFrame()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent(...)
    elseif event == "PLAYER_DEAD" then
        local data = GetPlayerData(playerGUID, playerName)
        if data then
            data.deaths = (data.deaths or 0) + 1
        end
        ShowDeathRecap()
    end
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function CombatLog.OnInitialize()
    addon:Debug("CombatLog module initializing")
    playerGUID = UnitGUID("player")
    playerName = UnitName("player")

    -- Register slash commands even if the module is disabled.
    -- This lets players recover a hidden/off-screen window without needing the module enabled.
    if not CombatLog._slashRegistered then
        CombatLog._slashRegistered = true

        -- NOTE: /dcc is reserved by DC-Collection. Do not claim it here.
        SLASH_DCCOMBAT1 = "/dccombat"
        SLASH_DCCOMBAT2 = "/dcqoscombat"
        SlashCmdList["DCCOMBAT"] = function(msg)
            msg = tostring(msg or "")
            msg = msg:match("^%s*(.-)%s*$")
            msg = string.lower(msg)

            if msg == "" or msg == "toggle" then
                if combatFrame and combatFrame:IsShown() then
                    CombatLog.HideFrame()
                else
                    CombatLog.ShowFrame()
                end
            elseif msg == "show" then
                CombatLog.ShowFrame()
            elseif msg == "hide" then
                CombatLog.HideFrame()
            elseif msg == "reset" then
                ResetPlayerData()
                addon:Print("Combat stats reset.", true)
            elseif msg == "death" then
                ShowDeathRecap()
            elseif msg == "damage" or msg == "d" then
                addon:SetSetting("combatLog.meterMode", "damage")
                CombatLog.UpdateFrame()
                addon:Print("Mode: Damage Done", true)
            elseif msg == "healing" or msg == "h" then
                addon:SetSetting("combatLog.meterMode", "healing")
                CombatLog.UpdateFrame()
                addon:Print("Mode: Healing Done", true)
            elseif msg == "spells" or msg == "s" then
                ShowSpellBreakdown()
            elseif msg:match("^spells ") then
                local target = msg:match("^spells (.+)")
                ShowSpellBreakdown(target)
            elseif msg == "dispels" then
                ShowDispels()
            elseif msg == "absorbs" then
                ShowAbsorbs()
            elseif msg == "activity" or msg == "uptime" then
                ShowActivity()
            elseif msg == "kb" or msg == "killingblows" then
                ShowKillingBlows()
            elseif msg == "cc" or msg == "crowdcontrol" then
                ShowCrowdControl()
            elseif msg == "power" or msg == "mana" then
                ShowPowerGains()
            elseif msg == "ff" or msg == "friendlyfire" then
                ShowFriendlyFire()
            elseif msg == "consumables" or msg == "potions" then
                ShowConsumables()
            elseif msg == "lock" then
                CombatLog.ToggleLock()
            elseif msg == "help" then
                addon:Print("Combat Log Commands:", true)
                print("  |cffffd700/dccombat|r - Toggle display")
                print("  |cffffd700/dccombat show/hide|r - Show/hide window")
                print("  |cffffd700/dccombat lock|r - Lock/unlock window position")
                print("  |cffffd700/dccombat d|r - Damage mode")
                print("  |cffffd700/dccombat h|r - Healing mode")
                print("  |cffffd700/dccombat s|r - Spell breakdown (your spells)")
                print("  |cffffd700/dccombat spells <name>|r - Spell breakdown for player")
                print("  |cffffd700/dccombat dispels|r - Show dispel summary")
                print("  |cffffd700/dccombat absorbs|r - Show absorb summary")
                print("  |cffffd700/dccombat activity|r - Show activity/uptime")
                print("  |cffffd700/dccombat kb|r - Show killing blows")
                print("  |cffffd700/dccombat cc|r - Show crowd control")
                print("  |cffffd700/dccombat power|r - Show power gains")
                print("  |cffffd700/dccombat ff|r - Show friendly fire")
                print("  |cffffd700/dccombat consumables|r - Show potion/healthstone usage")
                print("  |cffffd700/dccombat reset|r - Reset stats")
                print("  |cffffd700/dccombat death|r - Show death recap")
            end
        end
    end
end

function CombatLog.OnEnable()
    addon:Debug("CombatLog module enabling")
    
    local settings = addon.settings.combatLog
    if not settings.enabled then return end
    
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:SetScript("OnEvent", OnCombatEvent)
    
    -- Initial visibility check
    if not settings.hidden then
        CombatLog.ShowFrame()
    end
    
    CreateCombatFrame()
end

function CombatLog.OnDisable()
    addon:Debug("CombatLog module disabling")
    eventFrame:UnregisterAllEvents()
    if combatFrame then
        combatFrame:Hide()
    end
end

-- ============================================================
-- Settings Panel
-- ============================================================
function CombatLog.CreateSettings(parent)
    local settings = addon.settings.combatLog
    
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Combat Log Settings")
    
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("DPS/HPS meter with group tracking. Use |cffffd700/dccombat|r to toggle, |cffffd700/dccombat d|r for damage, |cffffd700/dccombat h|r for healing.")
    
    local yOffset = -70
    
    -- Display Section
    local displayHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText("Display")
    yOffset = yOffset - 25
    
    local meterCb = addon:CreateCheckbox(parent)
    meterCb:SetPoint("TOPLEFT", 16, yOffset)
    meterCb.Text:SetText("Show damage meter during combat")
    meterCb:SetChecked(settings.showMeter)
    meterCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showMeter", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local autoShowCb = addon:CreateCheckbox(parent)
    autoShowCb:SetPoint("TOPLEFT", 16, yOffset)
    autoShowCb.Text:SetText("Auto-show window when combat starts")
    autoShowCb:SetChecked(settings.autoShowInCombat ~= false)
    autoShowCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.autoShowInCombat", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local showBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    showBtn:SetSize(140, 20)
    showBtn:SetPoint("TOPLEFT", 34, yOffset)
    showBtn:SetText("Show Window Now")
    showBtn:SetScript("OnClick", function()
        CombatLog.ShowFrame()
    end)

    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 20)
    resetBtn:SetPoint("LEFT", showBtn, "RIGHT", 10, 0)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        local db = addon.settings.combatLog
        db.x, db.y = nil, nil
        if not combatFrame then
            CreateCombatFrame()
        end
        combatFrame:ClearAllPoints()
        combatFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 150)
        SavePosition(combatFrame, db)
        combatFrame:Show()
    end)

    yOffset = yOffset - 30
    
    local groupCb = addon:CreateCheckbox(parent)
    groupCb:SetPoint("TOPLEFT", 16, yOffset)
    groupCb.Text:SetText("Track party/raid members")
    groupCb:SetChecked(settings.trackGroup)
    groupCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackGroup", self:GetChecked())
    end)
    yOffset = yOffset - 35

    local totalsHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    totalsHeader:SetPoint("TOPLEFT", 16, yOffset)
    totalsHeader:SetText("Totals")
    yOffset = yOffset - 25

    local totalsBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    totalsBtn:SetSize(220, 22)
    totalsBtn:SetPoint("TOPLEFT", 16, yOffset)

    local displayNames = {
        off = "Off",
        line = "Small Line",
        title = "Title Bar",
        menu = "Segment Menu",
    }
    local cycle = { "line", "title", "menu", "off" }

    local function RefreshTotalsBtn()
        local mode = addon.settings.combatLog.totalsDisplay or "line"
        totalsBtn:SetText("Totals: " .. (displayNames[mode] or "Small Line"))
    end

    totalsBtn:SetScript("OnClick", function()
        local current = addon.settings.combatLog.totalsDisplay or "line"
        local nextMode = "line"
        for i, v in ipairs(cycle) do
            if v == current then
                nextMode = cycle[i % #cycle + 1]
                break
            end
        end
        addon:SetSetting("combatLog.totalsDisplay", nextMode)
        RefreshTotalsBtn()
        CombatLog.UpdateFrame()
    end)

    RefreshTotalsBtn()
    yOffset = yOffset - 45
    
    -- Enhanced Tracking Section
    local trackingHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    trackingHeader:SetPoint("TOPLEFT", 16, yOffset)
    trackingHeader:SetText("Enhanced Tracking (Skada-level)")
    yOffset = yOffset - 25
    
    local avoidanceCb = addon:CreateCheckbox(parent)
    avoidanceCb:SetPoint("TOPLEFT", 16, yOffset)
    avoidanceCb.Text:SetText("Track avoidance & mitigation (dodge/parry/block/resist/absorb)")
    avoidanceCb:SetChecked(settings.trackAvoidance ~= false and settings.trackMitigation ~= false)
    avoidanceCb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        addon:SetSetting("combatLog.trackAvoidance", checked)
        addon:SetSetting("combatLog.trackMitigation", checked)
    end)
    yOffset = yOffset - 25
    
    local enemyCb = addon:CreateCheckbox(parent)
    enemyCb:SetPoint("TOPLEFT", 16, yOffset)
    enemyCb.Text:SetText("Track enemy damage/healing (boss mechanics)")
    enemyCb:SetChecked(settings.trackEnemies ~= false)
    enemyCb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        addon:SetSetting("combatLog.trackEnemies", checked)
        addon:SetSetting("combatLog.trackEnemyHealing", checked)
    end)
    yOffset = yOffset - 25
    
    local petCb = addon:CreateCheckbox(parent)
    petCb:SetPoint("TOPLEFT", 16, yOffset)
    petCb.Text:SetText("Track pet damage/healing separately")
    petCb:SetChecked(settings.trackPetDamage ~= false)
    petCb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        addon:SetSetting("combatLog.trackPetDamage", checked)
        addon:SetSetting("combatLog.trackPetHealing", checked)
    end)
    yOffset = yOffset - 25

    local timelineCb = addon:CreateCheckbox(parent)
    timelineCb:SetPoint("TOPLEFT", 16, yOffset)
    timelineCb.Text:SetText("Capture combat timeline events")
    timelineCb:SetChecked(settings.trackTimeline ~= false)
    timelineCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackTimeline", self:GetChecked())
    end)
    yOffset = yOffset - 25
    
    local buffCb = addon:CreateCheckbox(parent)
    buffCb:SetPoint("TOPLEFT", 16, yOffset)
    buffCb.Text:SetText("Track buff/debuff uptime & applications")
    buffCb:SetChecked(settings.trackBuffs ~= false and settings.trackDebuffs ~= false)
    buffCb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        addon:SetSetting("combatLog.trackBuffs", checked)
        addon:SetSetting("combatLog.trackDebuffs", checked)
        addon:SetSetting("combatLog.trackBuffUptime", checked)
    end)
    yOffset = yOffset - 25
    
    local healingDetailsCb = addon:CreateCheckbox(parent)
    healingDetailsCb:SetPoint("TOPLEFT", 16, yOffset)
    healingDetailsCb.Text:SetText("Detailed healing tracking (by spell, source, overheal)")
    healingDetailsCb:SetChecked(settings.trackHealingBySpell ~= false)
    healingDetailsCb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        addon:SetSetting("combatLog.trackHealingBySpell", checked)
        addon:SetSetting("combatLog.trackHealingTaken", checked)
        addon:SetSetting("combatLog.trackOverhealing", checked)
    end)
    yOffset = yOffset - 25
    
    local schoolCb = addon:CreateCheckbox(parent)
    schoolCb:SetPoint("TOPLEFT", 16, yOffset)
    schoolCb.Text:SetText("Show school colors in tooltips (Physical/Fire/Frost/etc)")
    schoolCb:SetChecked(settings.showSchoolColors ~= false)
    schoolCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showSchoolColors", self:GetChecked())
    end)
    yOffset = yOffset - 35

    -- Detail Metrics & Tooltips
    local detailHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detailHeader:SetPoint("TOPLEFT", 16, yOffset)
    detailHeader:SetText("Detail Metrics & Tooltips")
    yOffset = yOffset - 25

    local glancingCb = addon:CreateCheckbox(parent)
    glancingCb:SetPoint("TOPLEFT", 16, yOffset)
    glancingCb.Text:SetText("Show glancing/crushing hits in tooltips")
    glancingCb:SetChecked(settings.showGlancingCrushing ~= false)
    glancingCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showGlancingCrushing", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local mitigationTipCb = addon:CreateCheckbox(parent)
    mitigationTipCb:SetPoint("TOPLEFT", 16, yOffset)
    mitigationTipCb.Text:SetText("Show absorbed/blocked/resisted in tooltips")
    mitigationTipCb:SetChecked(settings.showMitigationInTooltip ~= false)
    mitigationTipCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showMitigationInTooltip", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local absorbsCb = addon:CreateCheckbox(parent)
    absorbsCb:SetPoint("TOPLEFT", 16, yOffset)
    absorbsCb.Text:SetText("Track absorbs")
    absorbsCb:SetChecked(settings.trackAbsorbs ~= false)
    absorbsCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackAbsorbs", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local overkillCb = addon:CreateCheckbox(parent)
    overkillCb:SetPoint("TOPLEFT", 16, yOffset)
    overkillCb.Text:SetText("Track overkill")
    overkillCb:SetChecked(settings.trackOverkill ~= false)
    overkillCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackOverkill", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local missCb = addon:CreateCheckbox(parent)
    missCb:SetPoint("TOPLEFT", 16, yOffset)
    missCb.Text:SetText("Track misses/dodges/parries")
    missCb:SetChecked(settings.trackMisses ~= false)
    missCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackMisses", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local critCb = addon:CreateCheckbox(parent)
    critCb:SetPoint("TOPLEFT", 16, yOffset)
    critCb.Text:SetText("Track critical hit details")
    critCb:SetChecked(settings.trackCritDetails ~= false)
    critCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackCritDetails", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local activityCb = addon:CreateCheckbox(parent)
    activityCb:SetPoint("TOPLEFT", 16, yOffset)
    activityCb.Text:SetText("Track activity/uptime")
    activityCb:SetChecked(settings.trackActivity ~= false)
    activityCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackActivity", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local powerCb = addon:CreateCheckbox(parent)
    powerCb:SetPoint("TOPLEFT", 16, yOffset)
    powerCb.Text:SetText("Track power gains")
    powerCb:SetChecked(settings.trackPowerGains ~= false)
    powerCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackPowerGains", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local kbCb = addon:CreateCheckbox(parent)
    kbCb:SetPoint("TOPLEFT", 16, yOffset)
    kbCb.Text:SetText("Track killing blows")
    kbCb:SetChecked(settings.trackKillingBlows ~= false)
    kbCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackKillingBlows", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local ccCb = addon:CreateCheckbox(parent)
    ccCb:SetPoint("TOPLEFT", 16, yOffset)
    ccCb.Text:SetText("Track crowd control")
    ccCb:SetChecked(settings.trackCrowdControl ~= false)
    ccCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackCrowdControl", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local ccTakenCb = addon:CreateCheckbox(parent)
    ccTakenCb:SetPoint("TOPLEFT", 16, yOffset)
    ccTakenCb.Text:SetText("Track crowd control received")
    ccTakenCb:SetChecked(settings.trackCCTaken ~= false)
    ccTakenCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackCCTaken", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local ccBreaksCb = addon:CreateCheckbox(parent)
    ccBreaksCb:SetPoint("TOPLEFT", 16, yOffset)
    ccBreaksCb.Text:SetText("Track crowd control breaks")
    ccBreaksCb:SetChecked(settings.trackCCBreaks ~= false)
    ccBreaksCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackCCBreaks", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local ffCb = addon:CreateCheckbox(parent)
    ffCb:SetPoint("TOPLEFT", 16, yOffset)
    ffCb.Text:SetText("Track friendly fire")
    ffCb:SetChecked(settings.trackFriendlyFire ~= false)
    ffCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackFriendlyFire", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local potionsCb = addon:CreateCheckbox(parent)
    potionsCb:SetPoint("TOPLEFT", 16, yOffset)
    potionsCb.Text:SetText("Track potions/consumables")
    potionsCb:SetChecked(settings.trackPotions ~= false)
    potionsCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackPotions", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local rezCb = addon:CreateCheckbox(parent)
    rezCb:SetPoint("TOPLEFT", 16, yOffset)
    rezCb.Text:SetText("Track resurrects")
    rezCb:SetChecked(settings.trackResurrects ~= false)
    rezCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackResurrects", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local dmgSchoolCb = addon:CreateCheckbox(parent)
    dmgSchoolCb:SetPoint("TOPLEFT", 16, yOffset)
    dmgSchoolCb.Text:SetText("Track damage by school")
    dmgSchoolCb:SetChecked(settings.trackDamageBySchool ~= false)
    dmgSchoolCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackDamageBySchool", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local dmgTakenSpellCb = addon:CreateCheckbox(parent)
    dmgTakenSpellCb:SetPoint("TOPLEFT", 16, yOffset)
    dmgTakenSpellCb.Text:SetText("Track damage taken per spell")
    dmgTakenSpellCb:SetChecked(settings.trackDamageTakenBySpell ~= false)
    dmgTakenSpellCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackDamageTakenBySpell", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local dmgTakenSourceCb = addon:CreateCheckbox(parent)
    dmgTakenSourceCb:SetPoint("TOPLEFT", 16, yOffset)
    dmgTakenSourceCb.Text:SetText("Track damage taken per source")
    dmgTakenSourceCb:SetChecked(settings.trackDamageTakenBySource ~= false)
    dmgTakenSourceCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackDamageTakenBySource", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local castsCb = addon:CreateCheckbox(parent)
    castsCb:SetPoint("TOPLEFT", 16, yOffset)
    castsCb.Text:SetText("Track spell casts")
    castsCb:SetChecked(settings.trackCasts ~= false)
    castsCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.trackCasts", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Death Recap Section
    local deathHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    deathHeader:SetPoint("TOPLEFT", 16, yOffset)
    deathHeader:SetText("Death Recap")
    yOffset = yOffset - 25
    
    local deathCb = addon:CreateCheckbox(parent)
    deathCb:SetPoint("TOPLEFT", 16, yOffset)
    deathCb.Text:SetText("Show death recap when you die")
    deathCb:SetChecked(settings.deathRecap)
    deathCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.deathRecap", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local recapCount = addon:CreateSlider(parent)
    recapCount:SetPoint("TOPLEFT", 20, yOffset - 10)
    recapCount:SetWidth(220)
    recapCount:SetMinMaxValues(5, 30)
    recapCount:SetValueStep(1)
    recapCount.Text:SetText("Recap entries")
    recapCount.Low:SetText("5")
    recapCount.High:SetText("30")
    recapCount:SetValue(settings.deathRecapCount or 15)
    recapCount:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        if self.Value then
            self.Value:SetText(v)
        end
        addon:SetSetting("combatLog.deathRecapCount", v)
    end)
    yOffset = yOffset - 50

    local recapMin = addon:CreateSlider(parent)
    recapMin:SetPoint("TOPLEFT", 20, yOffset - 10)
    recapMin:SetWidth(220)
    recapMin:SetMinMaxValues(0, 5000)
    recapMin:SetValueStep(50)
    recapMin.Text:SetText("Minimum damage")
    recapMin.Low:SetText("0")
    recapMin.High:SetText("5000")
    recapMin:SetValue(settings.deathRecapMinDamage or 0)
    recapMin:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value + 0.5)
        if self.Value then
            self.Value:SetText(v)
        end
        addon:SetSetting("combatLog.deathRecapMinDamage", v)
    end)
    yOffset = yOffset - 50

    local recapBuffsCb = addon:CreateCheckbox(parent)
    recapBuffsCb:SetPoint("TOPLEFT", 16, yOffset)
    recapBuffsCb.Text:SetText("Show buffs/debuffs in recap")
    recapBuffsCb:SetChecked(settings.deathRecapShowBuffs ~= false)
    recapBuffsCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.deathRecapShowBuffs", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local announceDeathCb = addon:CreateCheckbox(parent)
    announceDeathCb:SetPoint("TOPLEFT", 16, yOffset)
    announceDeathCb.Text:SetText("Announce deaths to chat")
    announceDeathCb:SetChecked(settings.announceDeaths)
    announceDeathCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.announceDeaths", self:GetChecked())
    end)
    yOffset = yOffset - 25

    local altDeathCb = addon:CreateCheckbox(parent)
    altDeathCb:SetPoint("TOPLEFT", 16, yOffset)
    altDeathCb.Text:SetText("Use separate bars per death")
    altDeathCb:SetChecked(settings.alternativeDeathDisplay)
    altDeathCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.alternativeDeathDisplay", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Interrupts Section
    local intHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    intHeader:SetPoint("TOPLEFT", 16, yOffset)
    intHeader:SetText("Interrupts")
    yOffset = yOffset - 25
    
    local intCb = addon:CreateCheckbox(parent)
    intCb:SetPoint("TOPLEFT", 16, yOffset)
    intCb.Text:SetText("Announce interrupts to chat")
    intCb:SetChecked(settings.announceInterrupts)
    intCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.announceInterrupts", self:GetChecked())
    end)
    
    return yOffset - 50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("CombatLog", CombatLog)
