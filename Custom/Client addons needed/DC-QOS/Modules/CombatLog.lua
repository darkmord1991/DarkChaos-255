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
            barSpacing = 1,       -- pixels between rows
            barFontSize = 0,      -- 0 = derive from barHeight
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
            reportCount = 10,     -- lines posted by /dccombat report
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

-- GUID -> last seen name for anything that took part in an event, so
-- breakdowns keyed by GUID (damage sources, healers) can show a name.
local guidNames = {}
local guidNameCount = 0
local GUID_NAME_CAP = 4000

-- Class tokens survive fight resets so a member that walked out of range
-- keeps their bar colour.
local classCache = {}

-- Drill-down view: nil, or { guid = <row guid>, name = <row name> }
local detailView = nil

-- ============================================================
-- Group / roster helpers (3.3.5a has no IsInRaid / IsInGroup)
-- ============================================================
local function GetRaidMemberCount()
    if type(GetNumRaidMembers) == "function" then
        return GetNumRaidMembers() or 0
    end
    if type(IsInRaid) == "function" and IsInRaid() and type(GetNumGroupMembers) == "function" then
        return GetNumGroupMembers() or 0
    end
    return 0
end

local function GetPartyMemberCount()
    if type(GetNumPartyMembers) == "function" then
        return GetNumPartyMembers() or 0
    end
    if type(GetNumSubgroupMembers) == "function" then
        return GetNumSubgroupMembers() or 0
    end
    return 0
end

local function InRaid()
    return GetRaidMemberCount() > 0
end

local function InGroup()
    return InRaid() or GetPartyMemberCount() > 0
end

-- GUID -> unit token cache. Rebuilt lazily after a roster event instead of
-- scanning 45 unit tokens on every combat-log event.
local unitByGUID = {}
local nameToGUID = {}
local rosterDirty = true

local function AddRosterUnit(unit)
    if not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid then return end
    unitByGUID[guid] = unit
    local name = UnitName(unit)
    if name then
        nameToGUID[name] = guid
    end
end

local function RefreshRosterCache()
    wipe(unitByGUID)
    wipe(nameToGUID)
    AddRosterUnit("player")
    AddRosterUnit("pet")
    if InRaid() then
        for i = 1, GetRaidMemberCount() do
            AddRosterUnit("raid" .. i)
            AddRosterUnit("raid" .. i .. "pet")
        end
    else
        for i = 1, GetPartyMemberCount() do
            AddRosterUnit("party" .. i)
            AddRosterUnit("party" .. i .. "pet")
        end
    end
    rosterDirty = false
end

local function MarkRosterDirty()
    rosterDirty = true
end

local function FindGroupUnitByGUID(guid)
    if not guid then return nil end
    if rosterDirty then
        RefreshRosterCache()
    end
    local unit = unitByGUID[guid]
    if unit and UnitGUID(unit) ~= guid then
        RefreshRosterCache()
        unit = unitByGUID[guid]
    end
    return unit
end

local function FindGroupGUIDByName(name)
    if not name then return nil end
    if rosterDirty then
        RefreshRosterCache()
    end
    return nameToGUID[name]
end

local function ResolveClass(guid)
    if not guid then return nil end
    local class = classCache[guid]
    if class then return class end
    local unit = FindGroupUnitByGUID(guid)
    if unit and UnitIsPlayer(unit) then
        local _, token = UnitClass(unit)
        if token then
            classCache[guid] = token
            return token
        end
    end
    return nil
end

local function RememberName(guid, name)
    if not guid or not name or guidNames[guid] then return end
    if guidNameCount >= GUID_NAME_CAP then
        wipe(guidNames)
        guidNameCount = 0
    end
    guidNames[guid] = name
    guidNameCount = guidNameCount + 1
end

local function NameForGUID(guid)
    if not guid then return nil end
    local unit = FindGroupUnitByGUID(guid)
    if unit then
        local name = UnitName(unit)
        if name then return name end
    end
    return guidNames[guid]
end

-- ============================================================
-- GUID helpers (3.3.5a "0x" + 16 hex digits; retail dashed form tolerated)
-- ============================================================
local function GetGUIDUnitType(guid)
    if type(guid) ~= "string" or #guid ~= 18 or guid:sub(1, 2) ~= "0x" then
        return nil
    end
    local high = tonumber(guid:sub(3, 5), 16)
    if not high then return nil end
    return bit.band(high, 0x00F)
end

local function GetCreatureIdFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    local unitType = GetGUIDUnitType(guid)
    if unitType then
        -- 3 = creature, 4 = pet, 5 = vehicle: bits 24..47 carry the entry
        if unitType == 3 or unitType == 4 or unitType == 5 then
            return tonumber(guid:sub(7, 12), 16)
        end
        return nil
    end
    return tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$"))
end

-- Guardians (totems, mirror images, army ghouls) have no unit token, but the
-- unit tooltip still names the owner ("Bob's Minion").
local petScanTooltip = nil
local function ScanPetOwnerName(petGUID)
    if not petGUID then return nil end
    if not petScanTooltip then
        petScanTooltip = CreateFrame("GameTooltip", "DCQoS_CombatPetScan", UIParent, "GameTooltipTemplate")
    end
    petScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    petScanTooltip:ClearLines()
    local ok = pcall(petScanTooltip.SetHyperlink, petScanTooltip, "unit:" .. petGUID)
    if not ok then return nil end
    for i = 2, 3 do
        local line = _G["DCQoS_CombatPetScanTextLeft" .. i]
        if type(line) == "table" and line.GetText then
            local text = line:GetText()
            if text then
                local owner = text:match("^(.-)'s ") or text:match("^(.-)'s$")
                if owner and owner ~= "" then
                    return owner
                end
            end
        end
    end
    return nil
end


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

-- Add death log entry. `entry` is stored as-is (with timestamp/health added),
-- so callers build one table per event instead of two.
local function AddDeathLogEntry(targetGUID, eventType, entry)
    if not targetGUID or not entry then return end

    local settings = addon.settings and addon.settings.combatLog
    local targetData = playerData[targetGUID]
    if not targetData then return end

    if eventType == "damage" and settings and settings.deathRecapMinDamage
        and (entry.amount or 0) < settings.deathRecapMinDamage then
        return
    end

    local health, healthMax = 0, 0
    local unit = FindGroupUnitByGUID(targetGUID)
    if unit then
        health = UnitHealth(unit) or 0
        healthMax = UnitHealthMax(unit) or 0
    end

    entry.timestamp = GetTime() - combatStartTime
    entry.eventType = eventType  -- "damage", "heal", "buff", "debuff"
    entry.health = health
    entry.healthMax = healthMax
    entry.healthPct = healthMax > 0 and (health / healthMax * 100) or 0

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

addon.FormatNumber = FormatNumber
CombatLog.FormatNumber = FormatNumber

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

CombatLog.GetCombatTime = GetCombatTime

local function GetClassColor(classToken)
    local color = CLASS_COLORS[classToken]
    if color then
        return color.r, color.g, color.b
    end
    return 0.5, 0.5, 0.5
end


-- ============================================================
-- Per-spell tracking (file scope: no closure per combat-log event)
-- ============================================================
local function NewSpellEntry(spellName, school)
    return {
        name = spellName or "Unknown",
        school = school,
        damage = 0,
        healing = 0,
        overheal = 0,
        absorbAmount = 0,   -- damage this (shield) spell absorbed for others
        hits = 0,
        crits = 0,
        glancing = 0,
        crushing = 0,
        -- Crit tracking
        critDamage = 0,
        critMin = nil,
        critMax = nil,
        -- Normal hit tracking
        normalHits = 0,
        normalDamage = 0,
        normalMin = nil,
        normalMax = nil,
        -- Miss tracking (counts keyed like MISS_TYPES)
        misses = 0,
        dodges = 0,
        parries = 0,
        blocks = 0,
        resists = 0,
        absorbs = 0,
        -- Advanced
        absorbed = 0,       -- damage of this spell soaked by the target's shields
        overkill = 0,
    }
end

local function TrackSpell(data, spellId, spellName, amount, isCrit, isHealing, isGlancing, missType, absorbed, overkill, school, isCrushing, overheal)
    local settings = addon.settings.combatLog
    if not data.spells then data.spells = {} end
    spellId = spellId or 0

    local keepSchool = settings.trackDamageBySchool ~= false
    local spell = data.spells[spellId]
    if not spell then
        spell = NewSpellEntry(spellName, keepSchool and school or nil)
        data.spells[spellId] = spell
    elseif keepSchool and school and not spell.school then
        spell.school = school
    end

    if missType then
        local key = MISS_TYPES[missType]
        if key and settings.trackMisses ~= false then
            spell[key] = (spell[key] or 0) + 1
        end
        return
    end

    amount = amount or 0
    spell.hits = spell.hits + 1
    if absorbed and absorbed > 0 then
        spell.absorbed = spell.absorbed + absorbed
    end
    if overkill and overkill > 0 and settings.trackOverkill ~= false then
        spell.overkill = spell.overkill + overkill
    end

    if isHealing then
        spell.healing = spell.healing + amount
        if overheal and overheal > 0 then
            spell.overheal = (spell.overheal or 0) + overheal
        end
        if isCrit then
            spell.crits = spell.crits + 1
        end
        return
    end

    spell.damage = spell.damage + amount
    local details = settings.trackCritDetails ~= false
    if isCrit then
        spell.crits = spell.crits + 1
        if details then
            spell.critDamage = spell.critDamage + amount
            if not spell.critMin or amount < spell.critMin then spell.critMin = amount end
            if not spell.critMax or amount > spell.critMax then spell.critMax = amount end
        end
    elseif isGlancing then
        spell.glancing = spell.glancing + 1
    elseif isCrushing then
        spell.crushing = (spell.crushing or 0) + 1
    else
        spell.normalHits = spell.normalHits + 1
        if details then
            spell.normalDamage = spell.normalDamage + amount
            if not spell.normalMin or amount < spell.normalMin then spell.normalMin = amount end
            if not spell.normalMax or amount > spell.normalMax then spell.normalMax = amount end
        end
    end
end

-- ============================================================
-- Absorb shields. 3.3.5a has no SPELL_ABSORBED event, so the absorbed amount
-- reported on a damage event is credited to the newest known shield on the
-- victim (Recount/Skada approach for Wrath).
-- ============================================================
local function RegisterShield(destGUID, spellId, sourceGUID, sourceName)
    if not destGUID or not spellId or not sourceGUID then return end
    local shields = activeShields[destGUID]
    if not shields then
        shields = {}
        activeShields[destGUID] = shields
    end
    local shield = shields[spellId]
    if not shield then
        shield = {}
        shields[spellId] = shield
    end
    shield.sourceGUID = sourceGUID
    shield.sourceName = sourceName
    shield.applied = GetTime()
end

local function RemoveShield(destGUID, spellId)
    local shields = activeShields[destGUID]
    if shields then
        shields[spellId] = nil
    end
end

local function CreditAbsorb(destGUID, absorbed)
    if not absorbed or absorbed <= 0 then return end
    local shields = activeShields[destGUID]
    if not shields then return end

    local bestId, best = nil, nil
    for spellId, shield in pairs(shields) do
        if not best or shield.applied > best.applied then
            bestId, best = spellId, shield
        end
    end
    if not best then return end

    local data = GetPlayerData(best.sourceGUID, best.sourceName)
    if not data then return end

    data.absorbs = (data.absorbs or 0) + absorbed
    data.absorbsBySpell[bestId] = (data.absorbsBySpell[bestId] or 0) + absorbed

    local info = ABSORB_SPELLS[bestId]
    local spell = data.spells[bestId]
    if not spell then
        local spellName = (info and info.name) or GetSpellInfo(bestId) or "Absorb"
        spell = NewSpellEntry(spellName, info and info.school or 0x02)
        data.spells[bestId] = spell
    end
    spell.absorbAmount = (spell.absorbAmount or 0) + absorbed
end

-- ============================================================
-- Player Data Management
-- ============================================================
GetPlayerData = function(guid, name, flags)
    if not guid then return nil end
    
    if not playerData[guid] then
        local classToken = ResolveClass(guid)
        if not classToken and name and UnitName("player") == name then
            local _, token = UnitClass("player")
            classToken = token
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
    elseif name and playerData[guid].name == "Unknown" then
        playerData[guid].name = name
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
end

-- ============================================================
-- Buff/Debuff Tracking Functions
-- ============================================================

local function TrackBuff(targetGUID, spellId, spellName, auraType, isRefresh)
    if not targetGUID or not spellId then return end

    local dataTable = (auraType == "BUFF") and buffData or debuffData

    if not dataTable[targetGUID] then
        dataTable[targetGUID] = {}
    end

    local buff = dataTable[targetGUID][spellId]
    if not buff then
        buff = {
            name = spellName,
            applications = 0,
            uptime = 0,
            lastApplied = 0,
        }
        dataTable[targetGUID][spellId] = buff
    elseif isRefresh and buff.lastApplied > 0 then
        -- Still up: a refresh is not a new application.
        return
    end

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
        local creatureId = GetCreatureIdFromGUID(guid)
        
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


local function TrackEnemyDamage(destGUID, destName, sourceKey, sourceLabel, amount)
    local enemy = GetEnemyData(destGUID, destName)
    if not enemy then return nil end
    enemy.damageTaken = enemy.damageTaken + amount
    if sourceKey then
        local src = enemy.damageSources[sourceKey]
        if not src then
            src = { name = sourceLabel or "Unknown", amount = 0 }
            enemy.damageSources[sourceKey] = src
        end
        src.amount = src.amount + amount
    end
    return enemy
end

local function TrackEnemyHealing(sourceGUID, sourceName, amount)
    if not amount or amount <= 0 then return end
    local enemy = GetEnemyData(sourceGUID, sourceName)
    if enemy then
        enemy.healingDone = enemy.healingDone + amount
    end
end

-- ============================================================
-- Pet Tracking Functions
-- ============================================================

local function ResolvePetOwner(petGUID, petFlags)
    if not petGUID then return nil end
    local cached = petOwners[petGUID]
    if cached ~= nil then
        return cached or nil
    end

    local ownerGUID = nil
    if petFlags and bit.band(petFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 then
        ownerGUID = playerGUID or UnitGUID("player")
    end

    if not ownerGUID then
        local unit = FindGroupUnitByGUID(petGUID)
        if unit and unit:find("pet") then
            local ownerUnit = unit:gsub("pet$", "")
            if ownerUnit == "" then ownerUnit = "player" end
            ownerGUID = UnitGUID(ownerUnit)
        end
    end

    if not ownerGUID then
        local ownerName = ScanPetOwnerName(petGUID)
        if ownerName then
            ownerGUID = FindGroupGUIDByName(ownerName)
        end
    end

    -- Negative results are cached too (false), so a guardian we cannot
    -- attribute costs one tooltip scan per fight instead of one per event.
    petOwners[petGUID] = ownerGUID or false
    return ownerGUID
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

    -- Amortized trim: let the array grow past the limit by some slack, then do a
    -- single compaction pass instead of a per-event table.remove(1) memmove.
    local count = #currentTimeline
    local slack = math.floor(limit * 0.25)
    if slack < 256 then
        slack = 256
    end
    if count > limit + slack then
        local excess = count - limit
        for i = 1, limit do
            currentTimeline[i] = currentTimeline[i + excess]
        end
        for i = limit + 1, count do
            currentTimeline[i] = nil
        end
    end
end

local SEGMENT_TOTAL_KEYS = {
    "damage", "totalDamage", "overkill", "usefulDamage", "healing", "totalHealing", "overhealing",
    "damageTaken", "absorbs", "deaths", "killingBlows", "interrupts", "dispels", "ccDone", "ccTaken",
    "ccBreaks", "resurrects", "casts", "activeTime", "manaGain", "rageGain", "energyGain", "runicGain",
    "dodges", "parries", "misses", "blocks", "resists", "avoidance", "friendlyDamage", "potionsUsed",
    "healthstonesUsed", "petDamage", "petHealing",
}

local function CopyTable(src)
    local out = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            out[k] = CopyTable(v)
        else
            out[k] = v
        end
    end
    return out
end

local function GetTopEnemy(source)
    local best = nil
    for _, enemy in pairs(source or enemyData) do
        if (enemy.damageTaken or 0) > 0 and (not best or enemy.damageTaken > best.damageTaken) then
            best = enemy
        end
    end
    return best
end

local function SaveSegment()
    local settings = addon.settings.combatLog

    local duration = GetCombatTime()
    if duration < 5 then return end  -- Don't save short fights

    local players = 0
    for _ in pairs(playerData) do players = players + 1 end
    if players == 0 then return end

    segmentCounter = segmentCounter + 1

    -- Name the fight after whatever took the most damage (Skada style).
    local label = string.format("Fight %d", segmentCounter)
    local topEnemy = GetTopEnemy(enemyData)
    if topEnemy and topEnemy.name and topEnemy.name ~= "Unknown" then
        label = string.format("%d. %s", segmentCounter, topEnemy.name)
    end

    local segment = {
        id = segmentCounter,
        name = label,
        startTime = combatStartTime,
        endTime = (combatEndTime and combatEndTime > 0) and combatEndTime or GetTime(),
        duration = duration,
        data = CopyTable(playerData),
        enemies = CopyTable(enemyData),
        timeline = currentTimeline,
        totals = { players = players },
    }

    local totals = segment.totals
    for _, key in ipairs(SEGMENT_TOTAL_KEYS) do
        totals[key] = 0
    end
    for _, entry in pairs(segment.data) do
        for _, key in ipairs(SEGMENT_TOTAL_KEYS) do
            totals[key] = totals[key] + (entry[key] or 0)
        end
    end

    table.insert(segments, 1, segment)
    currentTimeline = {}

    -- Trim old segments
    local keep = tonumber(settings.keepSegments) or 5
    if keep < 1 then keep = 1 end
    while #segments > keep do
        table.remove(segments)
    end

    -- A displayed history segment moved down one slot.
    if activeSegment and activeSegment > 0 then
        activeSegment = activeSegment + 1
        if activeSegment > #segments then
            activeSegment = nil
        end
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

-- Scratch array reused across UpdateFrame calls (10x/s). Safe because the
-- returned array and its row tables are consumed synchronously by
-- UpdateFrame and never retained (bars copy the scalars they need).
local sortedScratch = {}

local MODE_VALUE_KEY = {
    damage = "damage",
    healing = "healing",
    damageTaken = "damageTaken",
    absorbs = "absorbs",
    overkill = "overkill",
    usefulDamage = "usefulDamage",
    killingBlows = "killingBlows",
    interrupts = "interrupts",
    dispels = "dispels",
    deaths = "deaths",
    cc = "ccDone",
    ccTaken = "ccTaken",
    ccBreaks = "ccBreaks",
    friendlyFire = "friendlyDamage",
    activity = "activeTime",
    casts = "casts",
    resurrects = "resurrects",
    avoidance = "avoidance",
}

local MODE_VALUE_FUNC = {
    power = function(d)
        return (d.manaGain or 0) + (d.rageGain or 0) + (d.energyGain or 0) + (d.runicGain or 0)
    end,
    consumables = function(d)
        return (d.potionsUsed or 0) + (d.healthstonesUsed or 0)
    end,
    absorbsHealing = function(d)
        return (d.healing or 0) + (d.absorbs or 0)
    end,
}

-- Modes whose rows are enemies instead of group members
local ENEMY_MODES = {
    enemyDamageTaken = "damageTaken",
    enemyHealing = "healingDone",
}

-- Modes that offer a click-through breakdown
local DETAIL_MODES = {
    damage = true,
    overkill = true,
    healing = true,
    absorbsHealing = true,
    absorbs = true,
    damageTaken = true,
    deaths = true,
    cc = true,
    enemyDamageTaken = true,
}

-- Modes whose value is an amount worth showing as a share of the total
local SHARE_MODES = {
    damage = true,
    healing = true,
    absorbsHealing = true,
    absorbs = true,
    damageTaken = true,
    overkill = true,
    usefulDamage = true,
    enemyDamageTaken = true,
    enemyHealing = true,
    friendlyFire = true,
}

local SCHOOL_NAMES = {
    [0x01] = "Physical", [0x02] = "Holy", [0x04] = "Fire", [0x08] = "Nature",
    [0x10] = "Frost", [0x20] = "Shadow", [0x40] = "Arcane",
}
local SCHOOL_COLORS = {
    [0x01] = { 1.00, 1.00, 0.00 }, [0x02] = { 1.00, 0.90, 0.50 }, [0x04] = { 1.00, 0.50, 0.00 },
    [0x08] = { 0.30, 1.00, 0.30 }, [0x10] = { 0.50, 1.00, 1.00 }, [0x20] = { 0.50, 0.50, 1.00 },
    [0x40] = { 1.00, 0.50, 1.00 },
}
CombatLog.SCHOOL_COLORS = SCHOOL_COLORS
CombatLog.SCHOOL_NAMES = SCHOOL_NAMES

local function GetSchoolColor(school)
    local c = school and SCHOOL_COLORS[school]
    if c then return c[1], c[2], c[3] end
    return 0.8, 0.8, 0.8
end

local function GetActiveSegment()
    if activeSegment and segments[activeSegment] then
        return segments[activeSegment]
    end
    return nil
end

local function GetActiveDataSource()
    local seg = GetActiveSegment()
    if seg then
        return seg.data, seg.enemies or {}
    end
    return playerData, enemyData
end

-- Duration the displayed numbers refer to: the segment's, or the live timer.
local function GetActiveDuration()
    local seg = GetActiveSegment()
    if seg then
        return seg.duration or 0
    end
    return GetCombatTime()
end
CombatLog.GetActiveDuration = GetActiveDuration

local function SpellNameForId(spellId, fallback)
    if spellId == 0 then return "Melee" end
    if spellId == -1 then return "Environment" end
    local name = spellId and GetSpellInfo(spellId)
    return name or fallback or ("Spell " .. tostring(spellId))
end

local function SortByValue(a, b)
    return a.value > b.value
end

local function ClearScratch(sorted, n)
    for i = #sorted, n + 1, -1 do
        sorted[i] = nil
    end
end

local function PushRow(sorted, n, guid, name, class, value)
    n = n + 1
    local row = sorted[n]
    if not row then
        row = {}
        sorted[n] = row
    end
    row.guid = guid
    row.name = name or "Unknown"
    row.class = class
    row.value = value
    row.spell = nil
    row.entry = nil
    row.spellId = nil
    row.school = nil
    row.isEnemy = nil
    row.subtitle = nil
    return n
end

local function GetSortedData(mode)
    local sorted = sortedScratch
    local players, enemies = GetActiveDataSource()
    local n = 0

    local enemyKey = ENEMY_MODES[mode]
    if enemyKey then
        for guid, enemy in pairs(enemies) do
            local value = enemy[enemyKey] or 0
            if value > 0 then
                n = PushRow(sorted, n, guid, enemy.name, nil, value)
                sorted[n].isEnemy = true
            end
        end
        ClearScratch(sorted, n)
        table.sort(sorted, SortByValue)
        return sorted
    end

    local valueKey = MODE_VALUE_KEY[mode]
    local valueFunc = MODE_VALUE_FUNC[mode]
    if not valueKey and not valueFunc then
        valueKey = "damage"
    end

    for guid, data in pairs(players) do
        local value
        if valueFunc then
            value = valueFunc(data)
        else
            value = data[valueKey] or 0
        end
        if value > 0 then
            n = PushRow(sorted, n, guid, data.name, data.class, value)
        end
    end
    ClearScratch(sorted, n)
    table.sort(sorted, SortByValue)
    return sorted
end

-- Rows for the drill-down view of one player (or enemy) in the given mode.
local function GetDetailSortedData(mode, guid)
    local sorted = sortedScratch
    local players, enemies = GetActiveDataSource()
    local n = 0

    if mode == "enemyDamageTaken" then
        local enemy = enemies[guid]
        if enemy and enemy.damageSources then
            for key, src in pairs(enemy.damageSources) do
                if (src.amount or 0) > 0 then
                    local pdata = players[key]
                    n = PushRow(sorted, n, key, src.name, pdata and pdata.class or nil, src.amount)
                end
            end
        end
        ClearScratch(sorted, n)
        table.sort(sorted, SortByValue)
        return sorted
    end

    local data = players[guid]
    if not data then
        ClearScratch(sorted, 0)
        return sorted
    end

    if mode == "damage" or mode == "overkill" then
        for spellId, spell in pairs(data.spells or {}) do
            local value = (mode == "overkill") and (spell.overkill or 0) or (spell.damage or 0)
            if value > 0 then
                n = PushRow(sorted, n, spellId, spell.name, data.class, value)
                sorted[n].spell = spell
                sorted[n].spellId = spellId
                sorted[n].school = spell.school
            end
        end
    elseif mode == "healing" or mode == "absorbsHealing" or mode == "absorbs" then
        for spellId, spell in pairs(data.spells or {}) do
            local value = 0
            if mode ~= "absorbs" then value = value + (spell.healing or 0) end
            if mode ~= "healing" then value = value + (spell.absorbAmount or 0) end
            if value > 0 then
                n = PushRow(sorted, n, spellId, spell.name, data.class, value)
                sorted[n].spell = spell
                sorted[n].spellId = spellId
                sorted[n].school = spell.school
            end
        end
    elseif mode == "damageTaken" then
        for spellId, taken in pairs(data.damageTakenBySpell or {}) do
            if (taken.amount or 0) > 0 then
                n = PushRow(sorted, n, spellId, taken.name or SpellNameForId(spellId), data.class, taken.amount)
                sorted[n].spellId = spellId
                sorted[n].school = taken.school
                sorted[n].subtitle = string.format("%d hits", taken.hits or 0)
            end
        end
    elseif mode == "cc" then
        for spellId, count in pairs(data.ccSpells or {}) do
            if count > 0 then
                n = PushRow(sorted, n, spellId, SpellNameForId(spellId), data.class, count)
                sorted[n].spellId = spellId
            end
        end
    elseif mode == "deaths" then
        local entries = CombatLog.GetDeathLogEntries(data, true)
        for _, entry in ipairs(entries) do
            if entry.eventType == "damage" and (entry.amount or 0) > 0 then
                local label = string.format("%s: %s", entry.sourceName or "Unknown",
                    entry.spellName or SpellNameForId(entry.spellId))
                n = PushRow(sorted, n, nil, label, data.class, entry.amount)
                sorted[n].entry = entry
                sorted[n].school = entry.school
            end
        end
        -- Chronological (newest first); do not sort by amount.
        ClearScratch(sorted, n)
        return sorted
    end

    ClearScratch(sorted, n)
    table.sort(sorted, SortByValue)
    return sorted
end

local function GetThreatSortedData()
    local sorted = {}
    if not UnitExists("target") then
        return sorted
    end

    local units = {}
    if InRaid() then
        for i = 1, GetRaidMemberCount() do
            units[#units + 1] = "raid" .. i
        end
    else
        units[#units + 1] = "player"
        for i = 1, GetPartyMemberCount() do
            units[#units + 1] = "party" .. i
        end
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

    table.sort(sorted, SortByValue)
    return sorted
end

-- ============================================================
-- Tooltips
-- ============================================================
local function AddTooltipStat(label, value, r, g, b)
    GameTooltip:AddDoubleLine(label, value, r or 0.8, g or 0.8, b or 0.8, 1, 1, 1)
end

local function ShowDetailTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.detailName or "", 1, 1, 1)

    local spell = self.detailSpell
    local entry = self.detailEntry
    local duration = GetActiveDuration()

    if spell then
        if spell.school and SCHOOL_NAMES[spell.school] then
            local r, g, b = GetSchoolColor(spell.school)
            GameTooltip:AddLine(SCHOOL_NAMES[spell.school], r, g, b)
        end
        GameTooltip:AddLine(" ")

        local hits = spell.hits or 0
        if (spell.damage or 0) > 0 then
            AddTooltipStat("Damage:", FormatNumber(spell.damage))
            if duration > 0 then
                AddTooltipStat("Per second:", FormatNumber(spell.damage / duration))
            end
        end
        if (spell.healing or 0) > 0 then
            AddTooltipStat("Healing:", FormatNumber(spell.healing), 0.2, 1, 0.2)
            local overheal = spell.overheal or 0
            if overheal > 0 then
                AddTooltipStat("Overheal:", string.format("%s (%.0f%%)", FormatNumber(overheal),
                    overheal / (spell.healing + overheal) * 100), 0.2, 1, 0.2)
            end
        end
        if (spell.absorbAmount or 0) > 0 then
            AddTooltipStat("Absorbed:", FormatNumber(spell.absorbAmount), 0.7, 0.7, 1)
        end
        if hits > 0 then
            AddTooltipStat("Hits:", tostring(hits))
            local crits = spell.crits or 0
            AddTooltipStat("Crits:", string.format("%d (%.0f%%)", crits, crits / hits * 100))
            AddTooltipStat("Average:", FormatNumber(((spell.damage or 0) + (spell.healing or 0)) / hits))
            if spell.normalMin and spell.normalMax then
                AddTooltipStat("Normal hit:", string.format("%s - %s", FormatNumber(spell.normalMin), FormatNumber(spell.normalMax)))
            end
            if spell.critMin and spell.critMax then
                AddTooltipStat("Crit hit:", string.format("%s - %s", FormatNumber(spell.critMin), FormatNumber(spell.critMax)))
            end
            if (spell.glancing or 0) > 0 then AddTooltipStat("Glancing:", tostring(spell.glancing)) end
            if (spell.crushing or 0) > 0 then AddTooltipStat("Crushing:", tostring(spell.crushing)) end
        end

        local missed = (spell.misses or 0) + (spell.dodges or 0) + (spell.parries or 0)
            + (spell.blocks or 0) + (spell.resists or 0) + (spell.absorbs or 0)
        if missed > 0 then
            AddTooltipStat("Missed:", string.format("%d (miss %d, dodge %d, parry %d, block %d, resist %d, absorb %d)",
                missed, spell.misses or 0, spell.dodges or 0, spell.parries or 0,
                spell.blocks or 0, spell.resists or 0, spell.absorbs or 0))
        end
        if (spell.overkill or 0) > 0 then AddTooltipStat("Overkill:", FormatNumber(spell.overkill), 1, 0.4, 0.4) end
        if (spell.absorbed or 0) > 0 then AddTooltipStat("Soaked by shields:", FormatNumber(spell.absorbed)) end

    elseif entry then
        GameTooltip:AddLine(string.format("%.1fs into the fight", entry.timestamp or 0), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        AddTooltipStat("Amount:", FormatNumber(entry.amount or 0), 1, 0.4, 0.4)
        if entry.healthMax and entry.healthMax > 0 then
            AddTooltipStat("Health after:", string.format("%s / %s (%.0f%%)", FormatNumber(entry.health or 0),
                FormatNumber(entry.healthMax), entry.healthPct or 0))
        end
        if (entry.overkill or 0) > 0 then AddTooltipStat("Overkill:", FormatNumber(entry.overkill), 1, 0.4, 0.4) end
        if (entry.absorbed or 0) > 0 then AddTooltipStat("Absorbed:", FormatNumber(entry.absorbed), 0.7, 0.7, 1) end
        if (entry.resisted or 0) > 0 then AddTooltipStat("Resisted:", FormatNumber(entry.resisted)) end
        if (entry.blocked or 0) > 0 then AddTooltipStat("Blocked:", FormatNumber(entry.blocked)) end
        if entry.critical then GameTooltip:AddLine("Critical hit", 1, 0.3, 0.3) end

    elseif self.detailSubtitle then
        GameTooltip:AddLine(self.detailSubtitle, 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: back to overview", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function ShowEnemyTooltip(self)
    local enemy = self.enemy
    if not enemy then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(enemy.name or "Unknown", 1, 0.4, 0.4)
    if enemy.creatureId then
        GameTooltip:AddLine("Creature " .. tostring(enemy.creatureId), 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(" ")
    AddTooltipStat("Damage taken:", FormatNumber(enemy.damageTaken or 0))
    if (enemy.healingDone or 0) > 0 then
        AddTooltipStat("Healing done:", FormatNumber(enemy.healingDone), 0.2, 1, 0.2)
    end

    if enemy.damageSources then
        local sources = {}
        for _, src in pairs(enemy.damageSources) do
            if (src.amount or 0) > 0 then
                sources[#sources + 1] = src
            end
        end
        table.sort(sources, function(a, b) return a.amount > b.amount end)
        if #sources > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Top sources", 1, 0.82, 0)
            local total = enemy.damageTaken or 0
            for i = 1, math.min(10, #sources) do
                local src = sources[i]
                local share = total > 0 and (src.amount / total * 100) or 0
                GameTooltip:AddDoubleLine(src.name, string.format("%s (%.0f%%)", FormatNumber(src.amount), share),
                    1, 1, 1, 0.8, 0.8, 0.8)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: damage sources", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function ShowTooltip(self)
    if self.detailName then
        ShowDetailTooltip(self)
        return
    end
    if self.enemy then
        ShowEnemyTooltip(self)
        return
    end

    local data = self.data
    if not data then return end

    if CombatLog.ShowEnhancedTooltip and CombatLog.ShowEnhancedTooltip(self) then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(data.name, 1, 1, 1)
    GameTooltip:AddLine(" ")

    if data.spells then
        local sortedSpells = {}
        for _, spell in pairs(data.spells) do
            local amount = (spell.damage or 0) + (spell.healing or 0) + (spell.absorbAmount or 0)
            if amount > 0 then
                table.insert(sortedSpells, { name = spell.name, amount = amount, hits = spell.hits or 0, crits = spell.crits or 0 })
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

-- Layout constants (frame units, before the window scale is applied).
-- Every child is anchored inside the backdrop insets so nothing can hang
-- over the border no matter how the window is resized.
local FRAME_INSET = 3            -- backdrop inset, children stay inside it
local FRAME_PAD = 5              -- gap between the border and the bar column
local TITLE_HEIGHT = 22
local TOTALS_HEIGHT = 13
local FOOTER_HEIGHT = 18
local CONTENT_GAP = 2            -- breathing room above the first / below the last bar
local DEFAULT_BAR_HEIGHT = 18
local DEFAULT_BAR_SPACING = 1
local MIN_FRAME_WIDTH = 180
local MIN_FRAME_HEIGHT = 100
local MAX_FRAME_WIDTH = 600
local MAX_FRAME_HEIGHT = 700
local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local ACCENT_R, ACCENT_G, ACCENT_B = 1.0, 0.8, 0.0

local function GetBarMetrics(settings)
    local barHeight = tonumber(settings.barHeight) or DEFAULT_BAR_HEIGHT
    if barHeight < 10 then barHeight = 10 elseif barHeight > 40 then barHeight = 40 end
    local spacing = tonumber(settings.barSpacing) or DEFAULT_BAR_SPACING
    if spacing < 0 then spacing = 0 elseif spacing > 10 then spacing = 10 end
    local fontSize = tonumber(settings.barFontSize) or 0
    if fontSize <= 0 then
        fontSize = math.max(8, math.min(14, math.floor(barHeight * 0.6)))
    end
    return barHeight, spacing, fontSize
end

local function ApplyBarFont(fontString, fontSize)
    if not fontString then return end
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fontString:SetFont(font, fontSize, "")
    fontString:SetShadowColor(0, 0, 0, 0.9)
    fontString:SetShadowOffset(1, -1)
end

-- Force a font string to a single line so an over-long text truncates with
-- "..." instead of wrapping onto (and out of) the row below.
local function SetSingleLine(fontString)
    if not fontString then return end
    if fontString.SetWordWrap then fontString:SetWordWrap(false) end
    if fontString.SetNonSpaceWrap then fontString:SetNonSpaceWrap(false) end
end

local function CreateBar(parent, index)
    local settings = addon.settings.combatLog
    local barHeight, barSpacing, fontSize = GetBarMetrics(settings)

    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(barHeight)
    -- Left/right anchored: the bar follows the window width by itself.
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", FRAME_PAD,
        -(FRAME_INSET + TITLE_HEIGHT + CONTENT_GAP + (index - 1) * (barHeight + barSpacing)))
    bar:SetPoint("RIGHT", parent, "RIGHT", -FRAME_PAD, 0)
    -- Fill lives in BORDER so the sheen (ARTWORK) and text (OVERLAY) stack on top of it deterministically.
    bar:SetStatusBarTexture(FLAT_TEXTURE, "BORDER")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(FLAT_TEXTURE)
    bg:SetVertexColor(0, 0, 0, 0.35)
    bar.bg = bg

    -- Soft vertical sheen over the filled part so flat class colours do not
    -- read as plain rectangles.
    local fill = bar:GetStatusBarTexture()
    if fill then
        local sheen = bar:CreateTexture(nil, "ARTWORK")
        sheen:SetAllPoints(fill)
        sheen:SetTexture(FLAT_TEXTURE)
        if sheen.SetGradientAlpha then
            sheen:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.25, 1, 1, 1, 0.15)
        else
            sheen:SetVertexColor(1, 1, 1, 0.08)
        end
        bar.sheen = sheen
    end

    local hover = bar:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetTexture(FLAT_TEXTURE)
    hover:SetVertexColor(1, 1, 1, 0.1)

    local rank = bar:CreateFontString(nil, "OVERLAY")
    ApplyBarFont(rank, fontSize)
    rank:SetPoint("LEFT", bar, "LEFT", 3, 0)
    rank:SetWidth(fontSize * 1.6)
    rank:SetJustifyH("LEFT")
    rank:SetTextColor(0.85, 0.85, 0.85)
    rank:SetText(index .. ".")
    bar.rank = rank

    local value = bar:CreateFontString(nil, "OVERLAY")
    ApplyBarFont(value, fontSize)
    value:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    value:SetJustifyH("RIGHT")
    SetSingleLine(value)
    bar.valueText = value

    -- The name is boxed between the rank and the value, so it truncates
    -- instead of running underneath the number.
    local name = bar:CreateFontString(nil, "OVERLAY")
    ApplyBarFont(name, fontSize)
    name:SetPoint("LEFT", rank, "RIGHT", 2, 0)
    name:SetPoint("RIGHT", value, "LEFT", -4, 0)
    name:SetJustifyH("LEFT")
    SetSingleLine(name)
    bar.nameText = name

    bar.lastHeight = barHeight
    bar.lastFontSize = fontSize

    bar:SetScript("OnEnter", ShowTooltip)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    bar:SetScript("OnMouseUp", function(self, button)
        CombatLog.OnBarClick(self, button)
    end)
    bar:EnableMouse(true)
    bar:Hide()
    return bar
end

-- Borderless text button used for the footer (mode tabs, reset).
local function CreateFlatButton(parent, text, tooltip, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(FOOTER_HEIGHT - 2)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text)
    label:SetTextColor(0.75, 0.75, 0.75)
    btn.label = label

    local textWidth = (label.GetStringWidth and label:GetStringWidth()) or 24
    btn:SetWidth(math.max(24, math.floor(textWidth + 10)))

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(FLAT_TEXTURE)
    hl:SetVertexColor(1, 1, 1, 0.08)

    local underline = btn:CreateTexture(nil, "ARTWORK")
    underline:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 3, 1)
    underline:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 1)
    underline:SetHeight(1)
    underline:SetTexture(FLAT_TEXTURE)
    underline:SetVertexColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
    underline:Hide()
    btn.underline = underline

    btn:SetScript("OnClick", onClick)
    if tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
    end
    return btn
end

local function SetFlatButtonActive(btn, active)
    if not btn or not btn.label then return end
    if active then
        btn.label:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)
        btn.underline:Show()
    else
        btn.label:SetTextColor(0.75, 0.75, 0.75)
        btn.underline:Hide()
    end
end

local function ClampFrameSize(width, height)
    width = tonumber(width) or 200
    height = tonumber(height) or 250
    if width < MIN_FRAME_WIDTH then width = MIN_FRAME_WIDTH elseif width > MAX_FRAME_WIDTH then width = MAX_FRAME_WIDTH end
    if height < MIN_FRAME_HEIGHT then height = MIN_FRAME_HEIGHT elseif height > MAX_FRAME_HEIGHT then height = MAX_FRAME_HEIGHT end
    return width, height
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
    local width, height = ClampFrameSize(settings.frameWidth, settings.frameHeight)

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
    combatFrame:SetMinResize(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT)
    combatFrame:SetMaxResize(MAX_FRAME_WIDTH, MAX_FRAME_HEIGHT)

    -- Restore saved position or use default
    if settings.x and settings.y then
        RestorePosition(combatFrame, settings)
    else
        combatFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 150)
        SavePosition(combatFrame, settings)
    end

    -- Background: flat dark panel with the stock tooltip edge
    combatFrame:SetBackdrop({
        bgFile = FLAT_TEXTURE,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = FRAME_INSET, right = FRAME_INSET, top = FRAME_INSET, bottom = FRAME_INSET },
    })
    combatFrame:SetBackdropColor(0.04, 0.04, 0.05, 0.85)
    combatFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

    -- ---------------------------------------------------------------
    -- Title bar: [accent] title ........ timer [menu] [close]
    -- ---------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, combatFrame)
    titleBar:SetPoint("TOPLEFT", combatFrame, "TOPLEFT", FRAME_INSET, -FRAME_INSET)
    titleBar:SetPoint("TOPRIGHT", combatFrame, "TOPRIGHT", -FRAME_INSET, -FRAME_INSET)
    titleBar:SetHeight(TITLE_HEIGHT)
    titleBar:EnableMouse(true)
    combatFrame.titleBar = titleBar

    local titleBand = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBand:SetAllPoints()
    titleBand:SetTexture(FLAT_TEXTURE)
    titleBand:SetVertexColor(1, 1, 1, 0.05)

    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 1, -4)
    titleAccent:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 1, 4)
    titleAccent:SetWidth(2)
    titleAccent:SetTexture(FLAT_TEXTURE)
    titleAccent:SetVertexColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
    combatFrame.titleAccent = titleAccent

    local titleDivider = titleBar:CreateTexture(nil, "ARTWORK")
    titleDivider:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 2, 0)
    titleDivider:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", -2, 0)
    titleDivider:SetHeight(1)
    titleDivider:SetTexture(FLAT_TEXTURE)
    titleDivider:SetVertexColor(1, 1, 1, 0.12)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", 3, 0)
    closeBtn:SetScript("OnClick", function()
        CombatLog.HideFrame()
    end)

    -- Menu button (drop-down arrow)
    local menuBtn = CreateFrame("Button", nil, titleBar)
    menuBtn:SetSize(16, 16)
    menuBtn:SetPoint("RIGHT", closeBtn, "LEFT", 1, 0)
    menuBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    menuBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    menuBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    menuBtn:SetScript("OnClick", function(self)
        CombatLog.OpenMenu(self)
    end)
    menuBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Menu")
        GameTooltip:AddLine("Segments, modes, totals display, lock", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    menuBtn:SetScript("OnLeave", GameTooltip_Hide)
    combatFrame.menuBtn = menuBtn

    -- Combat timer
    local timerText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("RIGHT", menuBtn, "LEFT", -4, 0)
    timerText:SetJustifyH("RIGHT")
    timerText:SetTextColor(0.8, 0.8, 0.8)
    timerText:SetText("0:00")
    combatFrame.timerText = timerText

    -- Title: boxed between the accent strip and the timer so a long mode /
    -- segment name truncates instead of running under the buttons.
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetPoint("RIGHT", timerText, "LEFT", -6, 0)
    title:SetHeight(12)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("MIDDLE")
    SetSingleLine(title)
    title:SetText("|cffFFCC00DC|r Combat")
    combatFrame.title = title

    -- Totals line (optional), full width under the title bar
    local totalsText = combatFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalsText:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", FRAME_PAD - FRAME_INSET, -1)
    totalsText:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -(FRAME_PAD - FRAME_INSET), -1)
    totalsText:SetHeight(TOTALS_HEIGHT - 2)
    totalsText:SetJustifyH("LEFT")
    totalsText:SetJustifyV("MIDDLE")
    totalsText:SetTextColor(0.7, 0.7, 0.7)
    SetSingleLine(totalsText)
    totalsText:SetText("")
    totalsText:Hide()
    combatFrame.totalsText = totalsText

    -- Create bar frames
    for i = 1, 15 do
        barFrames[i] = CreateBar(combatFrame, i)
    end

    -- ---------------------------------------------------------------
    -- Footer: [Dmg][Heal][Taken] ............ [Reset] [grip]
    -- ---------------------------------------------------------------
    local bottomBar = CreateFrame("Frame", nil, combatFrame)
    bottomBar:SetPoint("BOTTOMLEFT", combatFrame, "BOTTOMLEFT", FRAME_INSET, FRAME_INSET)
    bottomBar:SetPoint("BOTTOMRIGHT", combatFrame, "BOTTOMRIGHT", -FRAME_INSET, FRAME_INSET)
    bottomBar:SetHeight(FOOTER_HEIGHT)
    combatFrame.bottomBar = bottomBar

    local footerDivider = bottomBar:CreateTexture(nil, "ARTWORK")
    footerDivider:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 2, 0)
    footerDivider:SetPoint("TOPRIGHT", bottomBar, "TOPRIGHT", -2, 0)
    footerDivider:SetHeight(1)
    footerDivider:SetTexture(FLAT_TEXTURE)
    footerDivider:SetVertexColor(1, 1, 1, 0.12)

    local tabs = {}
    local function AddModeTab(modeKey, text, tooltip)
        local btn = CreateFlatButton(bottomBar, text, tooltip, function()
            addon:SetSetting("combatLog.meterMode", modeKey)
            CombatLog.UpdateFrame()
        end)
        btn.mode = modeKey
        local prev = tabs[#tabs]
        if prev then
            btn:SetPoint("LEFT", prev, "RIGHT", 0, 0)
        else
            btn:SetPoint("LEFT", bottomBar, "LEFT", 2, -1)
        end
        tabs[#tabs + 1] = btn
        return btn
    end
    AddModeTab("damage", "Dmg", "Damage Done")
    AddModeTab("healing", "Heal", "Healing Done")
    AddModeTab("damageTaken", "Taken", "Damage Taken")
    combatFrame.modeTabs = tabs

    -- Personal DPS / HPS, in the free footer space between the tabs and Reset
    local personalText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    personalText:SetPoint("LEFT", tabs[#tabs], "RIGHT", 8, 0)
    personalText:SetPoint("RIGHT", bottomBar, "RIGHT", -64, 0)
    personalText:SetHeight(12)
    personalText:SetJustifyH("RIGHT")
    personalText:SetTextColor(0.7, 0.7, 0.7)
    SetSingleLine(personalText)
    personalText:SetText("")
    combatFrame.personalText = personalText

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, combatFrame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", combatFrame, "BOTTOMRIGHT", -FRAME_INSET, FRAME_INSET)
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
            settings.frameWidth, settings.frameHeight = ClampFrameSize(combatFrame:GetWidth(), combatFrame:GetHeight())
            combatFrame:SetSize(settings.frameWidth, settings.frameHeight)
            SavePosition(combatFrame, settings)
            CombatLog.UpdateFrame()
        end
    end)

    local resetBtn = CreateFlatButton(bottomBar, "Reset", "Reset current stats", function()
        ResetPlayerData()
        CombatLog.UpdateFrame()
    end)
    resetBtn:SetPoint("RIGHT", bottomBar, "RIGHT", -18, -1)
    combatFrame.resetBtn = resetBtn

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

local MODE_NAMES = {
    damage = "Damage",
    healing = "Healing",
    absorbsHealing = "Healing + Absorbs",
    absorbs = "Absorbs",
    damageTaken = "Damage Taken",
    overkill = "Overkill",
    usefulDamage = "Useful Damage",
    enemyDamageTaken = "Enemy Damage Taken",
    enemyHealing = "Enemy Healing",
    threat = "Threat",
    interrupts = "Interrupts",
    dispels = "Dispels",
    cc = "CC Done",
    ccTaken = "CC Taken",
    ccBreaks = "CC Breaks",
    deaths = "Deaths",
    killingBlows = "Killing Blows",
    friendlyFire = "Friendly Fire",
    activity = "Activity",
    casts = "Casts",
    power = "Power Gains",
    consumables = "Consumables",
    resurrects = "Resurrects",
    avoidance = "Avoidance",
}
CombatLog.MODE_NAMES = MODE_NAMES

-- Menu order (grouped)
local MODE_MENU = {
    { "damage", "healing", "absorbsHealing", "absorbs", "damageTaken", "overkill", "usefulDamage" },
    { "enemyDamageTaken", "enemyHealing", "threat" },
    { "interrupts", "dispels", "cc", "ccTaken", "ccBreaks", "deaths", "killingBlows", "friendlyFire" },
    { "activity", "casts", "power", "consumables", "resurrects", "avoidance" },
}

local function GetSegmentLabel()
    local seg = GetActiveSegment()
    if seg then
        return seg.name or ("Fight " .. tostring(seg.id or activeSegment))
    end
    return "Current"
end

local function FormatRowValue(mode, value, duration, share)
    local perSec = (duration and duration > 0) and (value / duration) or 0
    local shareText = share and string.format(", %.0f%%", share) or ""
    if mode == "damage" or mode == "healing" or mode == "absorbsHealing" or mode == "absorbs"
        or mode == "overkill" or mode == "usefulDamage" or mode == "enemyDamageTaken" or mode == "enemyHealing" then
        return string.format("%s (%s%s)", FormatNumber(value), FormatNumber(perSec), shareText)
    elseif mode == "damageTaken" or mode == "friendlyFire" then
        return string.format("%s (%s/s%s)", FormatNumber(value), FormatNumber(perSec), shareText)
    elseif mode == "activity" then
        local pct = (duration and duration > 0) and (value / duration * 100) or 0
        if pct > 100 then pct = 100 end
        return string.format("%s (%.0f%%)", FormatTime(value), pct)
    elseif mode == "threat" then
        return string.format("%.1f%%", value)
    elseif mode == "power" then
        return FormatNumber(value)
    else
        return string.format("%d", value)
    end
end

function CombatLog.ApplyWindowSettings()
    if not combatFrame then return end
    local settings = addon.settings.combatLog

    local scale = tonumber(settings.scale) or 1.0
    if scale < 0.5 then scale = 0.5 elseif scale > 3.0 then scale = 3.0 end
    settings.scale = scale

    local alpha = tonumber(settings.frameAlpha) or 0.9
    if alpha < 0.1 then alpha = 0.1 elseif alpha > 1.0 then alpha = 1.0 end
    settings.frameAlpha = alpha

    combatFrame:SetAlpha(alpha)
    if settings.x and settings.y then
        -- Re-anchoring keeps the window centred where it was after a scale change.
        RestorePosition(combatFrame, settings)
    else
        combatFrame:SetScale(scale)
    end
    CombatLog.UpdateFrame()
end

function CombatLog.IsInDetailView()
    return detailView ~= nil
end

function CombatLog.ExitDetailView()
    if detailView then
        detailView = nil
        CombatLog.UpdateFrame()
    end
end

function CombatLog.OnBarClick(bar, button)
    local settings = addon.settings.combatLog
    if button == "RightButton" then
        if detailView then
            detailView = nil
            GameTooltip_Hide()
            CombatLog.UpdateFrame()
        else
            CombatLog.OpenMenu("cursor")
        end
        return
    end
    if button ~= "LeftButton" then return end

    if detailView then
        detailView = nil
    elseif settings.showSpellBreakdown ~= false and bar.rowGuid and DETAIL_MODES[settings.meterMode or "damage"] then
        detailView = { guid = bar.rowGuid, name = bar.rowName }
    else
        return
    end
    GameTooltip_Hide()
    CombatLog.UpdateFrame()
end

function CombatLog.UpdateFrame()
    if not combatFrame then return end

    local settings = addon.settings.combatLog
    local mode = settings.meterMode or "damage"
    local duration = GetActiveDuration()
    local players, enemies = GetActiveDataSource()

    -- Leave the drill-down when its owner is not in the displayed data any more
    -- (segment switched, stats reset) or the mode has no breakdown.
    if detailView then
        if not DETAIL_MODES[mode] or not (players[detailView.guid] or enemies[detailView.guid]) then
            detailView = nil
        end
    end

    -- Timer
    if combatFrame.timerText then
        local timerStr = (settings.showCombatTimer == false) and "" or FormatTime(duration)
        if combatFrame.lastTimer ~= timerStr then
            combatFrame.timerText:SetText(timerStr)
            combatFrame.lastTimer = timerStr
        end
    end

    -- Title
    local modeName = MODE_NAMES[mode] or "Combat"
    local titleText
    if detailView then
        titleText = string.format("|cffFFCC00<|r %s: %s", detailView.name or "?", modeName)
    else
        titleText = string.format("|cffFFCC00DC|r %s (%s)", modeName, GetSegmentLabel())
    end
    if settings.totalsDisplay == "title" then
        local totals = GetActiveTotals()
        titleText = titleText .. string.format("  D:%s H:%s",
            FormatNumber((totals and totals.damage) or 0), FormatNumber((totals and totals.healing) or 0))
    end
    if combatFrame.title and combatFrame.lastTitle ~= titleText then
        combatFrame.title:SetText(titleText)
        combatFrame.lastTitle = titleText
    end

    -- Totals line (under the title bar)
    if combatFrame.totalsText then
        if settings.totalsDisplay == "line" then
            local totals, totalsDuration = GetActiveTotals()
            local text = FormatTotalsSummary(totals, totalsDuration)
            if combatFrame.lastTotals ~= text then
                combatFrame.totalsText:SetText(text)
                combatFrame.lastTotals = text
            end
            combatFrame.totalsText:Show()
        else
            combatFrame.totalsText:Hide()
        end
    end

    -- Personal DPS / HPS in the footer
    if combatFrame.personalText then
        local text = ""
        if settings.showPersonalDPS or settings.showPersonalHPS then
            local me = playerGUID and players[playerGUID]
            if me and duration > 0 then
                local parts = {}
                if settings.showPersonalDPS then
                    parts[#parts + 1] = FormatNumber((me.damage or 0) / duration) .. " DPS"
                end
                if settings.showPersonalHPS then
                    parts[#parts + 1] = FormatNumber((me.healing or 0) / duration) .. " HPS"
                end
                text = table.concat(parts, "  ")
            end
        end
        if combatFrame.lastPersonal ~= text then
            combatFrame.personalText:SetText(text)
            combatFrame.lastPersonal = text
        end
    end

    -- Footer tab highlight (only when the mode changed)
    if combatFrame.modeTabs and combatFrame.lastMode ~= mode then
        for _, tab in ipairs(combatFrame.modeTabs) do
            SetFlatButtonActive(tab, tab.mode == mode)
        end
        combatFrame.lastMode = mode
    end

    -- Rows
    local sorted
    if mode == "threat" then
        sorted = GetThreatSortedData()
    elseif detailView then
        sorted = GetDetailSortedData(mode, detailView.guid)
    else
        sorted = GetSortedData(mode)
    end

    local maxValue, totalValue = 0, 0
    for _, row in ipairs(sorted) do
        if row.value > maxValue then maxValue = row.value end
        totalValue = totalValue + row.value
    end
    local showShare = totalValue > 0 and SHARE_MODES[mode]

    -- Update bars. The bar column is the space between the title bar (plus
    -- optional totals line) and the footer; only rows that fit entirely inside
    -- that space are shown so nothing ever runs under the footer.
    local maxBars = math.min(settings.maxBars or 10, #barFrames)
    local barHeight, barSpacing, fontSize = GetBarMetrics(settings)
    local totalsShown = (settings.totalsDisplay == "line")
    local contentTop = FRAME_INSET + TITLE_HEIGHT + CONTENT_GAP + (totalsShown and TOTALS_HEIGHT or 0)
    local contentBottom = FRAME_INSET + FOOTER_HEIGHT + CONTENT_GAP
    local visibleHeight = (combatFrame:GetHeight() or 0) - contentTop - contentBottom
    local barsToShow = 0
    if visibleHeight >= barHeight then
        barsToShow = math.floor((visibleHeight + barSpacing) / (barHeight + barSpacing))
    end
    if barsToShow > maxBars then barsToShow = maxBars end

    for i = 1, #barFrames do
        local bar = barFrames[i]

        if i <= barsToShow and sorted[i] then
            local row = sorted[i]
            local percent = maxValue > 0 and (row.value / maxValue * 100) or 0

            -- Geometry (only when changed - this runs 10x/s)
            if bar.lastHeight ~= barHeight or bar.lastFontSize ~= fontSize then
                bar:SetHeight(barHeight)
                ApplyBarFont(bar.rank, fontSize)
                ApplyBarFont(bar.nameText, fontSize)
                ApplyBarFont(bar.valueText, fontSize)
                bar.rank:SetWidth(fontSize * 1.6)
                bar.lastHeight = barHeight
                bar.lastFontSize = fontSize
            end
            local barY = -(contentTop + (i - 1) * (barHeight + barSpacing))
            if bar.lastY ~= barY then
                bar:SetPoint("TOPLEFT", combatFrame, "TOPLEFT", FRAME_PAD, barY)
                bar.lastY = barY
            end

            -- Colour: enemies red, spell rows by school, players by class
            local r, g, b
            if row.isEnemy then
                r, g, b = 0.75, 0.25, 0.25
            elseif detailView and row.school then
                r, g, b = GetSchoolColor(row.school)
            else
                r, g, b = GetClassColor(row.class)
            end
            if bar.lastR ~= r or bar.lastG ~= g or bar.lastB ~= b then
                bar:SetStatusBarColor(r, g, b, 0.85)
                bar.lastR, bar.lastG, bar.lastB = r, g, b
            end

            -- Values
            bar:SetValue(percent)
            if bar.lastRank ~= i then
                bar.rank:SetText(i .. ".")
                bar.lastRank = i
            end
            if bar.lastName ~= row.name then
                bar.nameText:SetText(row.name)
                bar.lastName = row.name
            end

            local share = showShare and (row.value / totalValue * 100) or nil
            local valueStr = FormatRowValue(mode, row.value, duration, share)
            if bar.lastValueStr ~= valueStr then
                bar.valueText:SetText(valueStr)
                bar.lastValueStr = valueStr
            end

            -- Payload for click / tooltip (scalars and stable references only:
            -- the row table itself is scratch and reused next tick)
            bar.rowGuid = row.guid
            bar.rowName = row.name
            if detailView then
                bar.data = nil
                bar.enemy = nil
                bar.detailName = row.name
                bar.detailSpell = row.spell
                bar.detailEntry = row.entry
                bar.detailSubtitle = row.subtitle
            elseif row.isEnemy then
                bar.data = nil
                bar.enemy = enemies[row.guid]
                bar.detailName = nil
                bar.detailSpell = nil
                bar.detailEntry = nil
                bar.detailSubtitle = nil
            else
                bar.data = row.guid and players[row.guid] or nil
                bar.enemy = nil
                bar.detailName = nil
                bar.detailSpell = nil
                bar.detailEntry = nil
                bar.detailSubtitle = nil
            end
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

        -- Dim the border and accent to show the locked state
        combatFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        if combatFrame.titleAccent then
            combatFrame.titleAccent:SetVertexColor(0.6, 0.6, 0.6, 0.6)
        end
    else
        -- Enable dragging and resizing
        combatFrame:SetMovable(true)
        combatFrame:EnableMouse(true)
        if titleBar then titleBar:EnableMouse(true) end
        if resizeGrip then resizeGrip:Show() end

        -- Restore normal border
        combatFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        if combatFrame.titleAccent then
            combatFrame.titleAccent:SetVertexColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
        end
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

    if CombatLog.ShowDeathRecap and CombatLog.ShowDeathRecap(data) then
        return
    end

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
            local hp = entry.hp or entry.health
            local maxhp = entry.maxhp or entry.healthMax
            local hpPercent = entry.hpPercent or entry.healthPct
            local hpText = ""
            if hp and maxhp and maxhp > 0 then
                hpText = string.format(" [HP: %d/%d - %.1f%%]", hp, maxhp, hpPercent or (hp / maxhp * 100))
            end
            local extraText = ""
            if entry.overkill and entry.overkill > 0 then
                extraText = extraText .. string.format(" |cffff0000Overkill: %s|r", FormatNumber(entry.overkill))
            end
            if entry.absorbed and entry.absorbed > 0 then
                extraText = extraText .. string.format(" |cff00ff00Absorbed: %s|r", FormatNumber(entry.absorbed))
            end
            local sourceText = entry.sourceName or entry.source or "Unknown"
            local spellText = entry.spellName or entry.spell
            if (not spellText or spellText == "") and entry.spellId and entry.spellId > 0 then
                spellText = GetSpellInfo(entry.spellId)
            end
            if not spellText or spellText == "" then
                if entry.eventType == "damage" and entry.spellId == 0 then
                    spellText = "Melee"
                else
                    spellText = "Unknown"
                end
            end
            print(string.format("  |cffff6600%s|r from %s (%s)%s%s", 
                FormatNumber(entry.amount), 
                sourceText, 
                spellText,
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

-- ============================================================
-- Chat summaries and reports
-- ============================================================
local function GetReportLines(mode, count)
    local sorted
    if mode == "threat" then
        sorted = GetThreatSortedData()
    elseif detailView then
        sorted = GetDetailSortedData(mode, detailView.guid)
    else
        sorted = GetSortedData(mode)
    end

    local duration = GetActiveDuration()
    local totalValue = 0
    for _, row in ipairs(sorted) do
        totalValue = totalValue + row.value
    end

    local lines = {}
    lines[1] = string.format("DC Combat - %s%s (%s, %s)",
        detailView and (tostring(detailView.name) .. ": ") or "",
        MODE_NAMES[mode] or mode, GetSegmentLabel(), FormatTime(duration))
    for i = 1, math.min(count, #sorted) do
        local row = sorted[i]
        local share = (totalValue > 0 and SHARE_MODES[mode]) and (row.value / totalValue * 100) or nil
        lines[#lines + 1] = string.format("%d. %s  %s", i, row.name or "?", FormatRowValue(mode, row.value, duration, share))
    end
    return lines
end

local function PrintSummary(mode, count)
    local lines = GetReportLines(mode, count or 15)
    addon:Print("=== " .. lines[1] .. " ===", true)
    if #lines == 1 then
        print("  Nothing recorded.")
        return
    end
    for i = 2, #lines do
        print("  " .. lines[i])
    end
end

local REPORT_CHANNELS = {
    say = "SAY", yell = "YELL", party = "PARTY", raid = "RAID", guild = "GUILD",
    officer = "OFFICER", bg = "BATTLEGROUND", battleground = "BATTLEGROUND", whisper = "WHISPER",
}

-- Send the displayed ranking to a chat channel.
function CombatLog.Report(channel, count, target)
    local settings = addon.settings.combatLog
    local chatType = REPORT_CHANNELS[string.lower(tostring(channel or "party"))]
    if not chatType then
        addon:Print("Unknown report channel: " .. tostring(channel) .. " (say, party, raid, guild, officer, bg, whisper <name>)", true)
        return false
    end
    if chatType == "WHISPER" and (not target or target == "") then
        addon:Print("Usage: /dccombat report whisper <name> [lines]", true)
        return false
    end
    if (chatType == "PARTY" or chatType == "RAID") and not InGroup() then
        addon:Print("You are not in a group.", true)
        return false
    end
    if chatType == "RAID" and not InRaid() then
        chatType = "PARTY"
    end

    count = tonumber(count) or tonumber(settings.reportCount) or 10
    if count < 1 then count = 1 elseif count > 25 then count = 25 end

    local lines = GetReportLines(settings.meterMode or "damage", count)
    if #lines == 1 then
        addon:Print("Nothing to report.", true)
        return false
    end
    for _, line in ipairs(lines) do
        -- Chat cannot carry colour codes.
        local plain = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        SendChatMessage(plain, chatType, nil, target)
    end
    return true
end

-- Buff / debuff uptime for one group member (default: you)
local function ShowBuffUptime(targetName, debuffs)
    local guid = playerGUID
    local label = playerName
    if targetName and targetName ~= "" then
        guid = FindGroupGUIDByName(targetName)
        if not guid then
            for g, data in pairs(playerData) do
                if data.name and string.lower(data.name) == string.lower(targetName) then
                    guid = g
                    break
                end
            end
        end
        label = targetName
    end

    local source = debuffs and debuffData or buffData
    local auras = guid and source[guid]
    local duration = GetCombatTime()
    addon:Print(string.format("=== %s uptime: %s (%s) ===", debuffs and "Debuff" or "Buff", tostring(label), FormatTime(duration)), true)
    if not auras or duration <= 0 then
        print("  Nothing recorded.")
        return
    end

    local now = GetTime()
    local rows = {}
    for spellId, aura in pairs(auras) do
        local uptime = aura.uptime or 0
        if aura.lastApplied and aura.lastApplied > 0 then
            uptime = uptime + (inCombat and (now - aura.lastApplied) or math.max(0, combatEndTime - aura.lastApplied))
        end
        if uptime > duration then uptime = duration end
        rows[#rows + 1] = { name = aura.name or SpellNameForId(spellId), uptime = uptime, applications = aura.applications or 0 }
    end
    table.sort(rows, function(a, b) return a.uptime > b.uptime end)
    for i = 1, math.min(15, #rows) do
        local row = rows[i]
        print(string.format("  %d. %s - %.0f%% (%s, %d applications)", i, row.name, row.uptime / duration * 100, FormatTime(row.uptime), row.applications))
    end
end

-- ============================================================
-- Window menu
-- ============================================================
local function ModeMenuEntry(modeKey)
    return {
        text = MODE_NAMES[modeKey] or modeKey,
        func = function()
            addon:SetSetting("combatLog.meterMode", modeKey)
            CombatLog.UpdateFrame()
        end,
        checked = function() return (addon.settings.combatLog.meterMode or "damage") == modeKey end,
    }
end

function CombatLog.OpenMenu(anchor)
    local settings = addon.settings.combatLog

    local function SetTotalsDisplay(mode)
        addon:SetSetting("combatLog.totalsDisplay", mode)
        CombatLog.UpdateFrame()
    end

    local totalsDisplay = settings.totalsDisplay or "line"

    -- Segments submenu
    local currentText = "Current Fight"
    if totalsDisplay == "menu" then
        local damage, healing = 0, 0
        for _, data in pairs(playerData) do
            damage = damage + (data.damage or 0)
            healing = healing + (data.healing or 0)
        end
        currentText = string.format("Current Fight  D:%s H:%s", FormatNumber(damage), FormatNumber(healing))
    end
    local segmentMenu = {
        { text = currentText, func = function() SelectSegment(0) end, checked = function() return activeSegment == nil end },
    }
    for i, seg in ipairs(segments) do
        local segLabel = seg.name or ("Fight " .. tostring(seg.id or i))
        local segText = string.format("%s (%s)", segLabel, FormatTime(seg.duration))
        if totalsDisplay == "menu" and seg.totals then
            segText = string.format("%s (%s)  D:%s H:%s", segLabel, FormatTime(seg.duration),
                FormatNumber(seg.totals.damage or 0), FormatNumber(seg.totals.healing or 0))
        end
        table.insert(segmentMenu, {
            text = segText,
            func = function() SelectSegment(i) end,
            checked = function() return activeSegment == i end,
        })
    end

    -- Modes submenu (grouped)
    local modeMenu = {}
    for groupIndex, group in ipairs(MODE_MENU) do
        if groupIndex > 1 then
            table.insert(modeMenu, { text = " ", isTitle = true, notCheckable = true })
        end
        for _, modeKey in ipairs(group) do
            table.insert(modeMenu, ModeMenuEntry(modeKey))
        end
    end

    -- Report submenu
    local reportMenu = {}
    for _, ch in ipairs({ { "Party", "party" }, { "Raid", "raid" }, { "Say", "say" }, { "Guild", "guild" },
        { "Officer", "officer" }, { "Battleground", "bg" } }) do
        local key = ch[2]
        table.insert(reportMenu, { text = ch[1], func = function() CombatLog.Report(key) end, notCheckable = true })
    end
    table.insert(reportMenu, { text = "Chat frame (only you)", func = function()
        PrintSummary(settings.meterMode or "damage", settings.reportCount or 10)
    end, notCheckable = true })

    local totalsMenu = {
        { text = "Off", func = function() SetTotalsDisplay("off") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "off" end },
        { text = "Small Line", func = function() SetTotalsDisplay("line") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "line" end },
        { text = "Title Bar", func = function() SetTotalsDisplay("title") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "title" end },
        { text = "Segment Menu", func = function() SetTotalsDisplay("menu") end, checked = function() return (addon.settings.combatLog.totalsDisplay or "line") == "menu" end },
    }

    local menu = {
        { text = "|cffFFCC00DC Combat Menu|r", isTitle = true, notCheckable = true },
        { text = "Modes", hasArrow = true, menuList = modeMenu, notCheckable = true },
        { text = "Segments", hasArrow = true, menuList = segmentMenu, notCheckable = true },
        { text = "Report to...", hasArrow = true, menuList = reportMenu, notCheckable = true },
        { text = "Totals Display", hasArrow = true, menuList = totalsMenu, notCheckable = true },
    }
    if detailView then
        table.insert(menu, { text = "Back to overview", func = function() CombatLog.ExitDetailView() end, notCheckable = true })
    end
    table.insert(menu, { text = " ", isTitle = true, notCheckable = true })
    table.insert(menu, { text = "Reset Stats", func = function()
        ResetPlayerData()
        detailView = nil
        SelectSegment(0)
        addon:Print("Combat stats reset.", true)
    end, notCheckable = true })
    table.insert(menu, { text = settings.locked and "Unlock Window" or "Lock Window", func = function()
        CombatLog.ToggleLock()
    end, notCheckable = true })
    table.insert(menu, { text = "Hide Window", func = function()
        CombatLog.HideFrame()
    end, notCheckable = true })
    table.insert(menu, { text = "Close Menu", func = function() end, notCheckable = true })

    -- Ensure menu frame exists
    if not CombatLog.menuFrame then
        CombatLog.menuFrame = CreateFrame("Frame", "DCQoS_CombatLogMenu", UIParent, "UIDropDownMenuTemplate")
    end

    -- Show the menu
    EasyMenu(menu, CombatLog.menuFrame, anchor or "cursor", 0, 0, "MENU")
end

-- ============================================================
-- Combat Log Event Handler (3.3.5a compatible)
-- ============================================================
local eventFrame = CreateFrame("Frame")

local GROUP_MASK = COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID
local PET_MASK = COMBATLOG_OBJECT_TYPE_PET + COMBATLOG_OBJECT_TYPE_GUARDIAN
local REACTION_HOSTILE = (type(COMBATLOG_OBJECT_REACTION_HOSTILE) == "number") and COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040
local REACTION_NEUTRAL = (type(COMBATLOG_OBJECT_REACTION_NEUTRAL) == "number") and COMBATLOG_OBJECT_REACTION_NEUTRAL or 0x00000020
local ENEMY_MASK = REACTION_HOSTILE + REACTION_NEUTRAL

local DAMAGE_EVENTS = {
    SWING_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
    DAMAGE_SHIELD = true, DAMAGE_SPLIT = true, SPELL_BUILDING_DAMAGE = true,
}
local HEAL_EVENTS = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }
local MISS_EVENTS = {
    SWING_MISSED = true, SPELL_MISSED = true, RANGE_MISSED = true, SPELL_PERIODIC_MISSED = true,
    DAMAGE_SHIELD_MISSED = true,
}
local ENERGIZE_EVENTS = { SPELL_ENERGIZE = true, SPELL_PERIODIC_ENERGIZE = true }
local TIMELINE_AURA_EVENTS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true }

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

-- An incoming attack that did not land (victim side)
local function RecordAvoidance(destData, missType)
    local key = MISS_TYPES[missType]
    if not key then return end
    EnsureAvoidanceTable(destData)
    destData.avoidance = (destData.avoidance or 0) + 1
    if missType == "ABSORB" then
        destData.avoidanceTable.absorbs = (destData.avoidanceTable.absorbs or 0) + 1
    else
        destData[key] = (destData[key] or 0) + 1
        destData.avoidanceTable[key] = (destData.avoidanceTable[key] or 0) + 1
    end
end

local function RecordMitigation(destData, blocked, resisted, absorbed)
    EnsureAvoidanceTable(destData)
    local t = destData.avoidanceTable
    if blocked > 0 then
        destData.blockAmount = (destData.blockAmount or 0) + blocked
        t.blockedAmount = t.blockedAmount + blocked
    end
    if resisted > 0 then
        destData.resistAmount = (destData.resistAmount or 0) + resisted
        t.resistedAmount = t.resistedAmount + resisted
    end
    if absorbed > 0 then
        destData.absorbedAmount = (destData.absorbedAmount or 0) + absorbed
        t.absorbedAmount = t.absorbedAmount + absorbed
        t.absorbed = t.absorbed + 1
    end
end

local function RecordDamageTaken(settings, destData, destGUID, sourceGUID, sourceName, spellId, spellName, school,
    amount, overkill, resisted, blocked, absorbed, critical, glancing)
    destData.damageTaken = destData.damageTaken + amount

    if settings.trackDamageTakenBySpell ~= false then
        local bySpell = destData.damageTakenBySpell[spellId]
        if not bySpell then
            bySpell = { amount = 0, hits = 0, name = spellName, school = school }
            destData.damageTakenBySpell[spellId] = bySpell
        end
        bySpell.amount = bySpell.amount + amount
        bySpell.hits = bySpell.hits + 1
    end
    if settings.trackDamageTakenBySource ~= false and sourceGUID then
        destData.damageTakenFrom[sourceGUID] = (destData.damageTakenFrom[sourceGUID] or 0) + amount
    end
    if settings.trackMitigation ~= false then
        RecordMitigation(destData, blocked, resisted, absorbed)
    end
    if settings.trackAbsorbs ~= false and absorbed > 0 then
        CreditAbsorb(destGUID, absorbed)
    end
    if settings.deathRecap ~= false then
        AddDeathLogEntry(destGUID, "damage", {
            sourceGUID = sourceGUID,
            sourceName = sourceName,
            spellName = spellName,
            spellId = spellId,
            amount = amount,
            overkill = overkill,
            absorbed = absorbed,
            resisted = resisted,
            blocked = blocked,
            critical = critical,
            glancing = glancing,
            school = school,
        })
    end
end

local function AnnounceDeath(data, name)
    local entries = CombatLog.GetDeathLogEntries(data, true)
    local last = nil
    for _, entry in ipairs(entries) do
        if entry.eventType == "damage" then
            last = entry
            break
        end
    end
    local text
    if last then
        text = string.format("|cffff4040%s died|r - %s (%s) for %s", tostring(name),
            last.sourceName or "Unknown", last.spellName or SpellNameForId(last.spellId), FormatNumber(last.amount or 0))
    else
        text = string.format("|cffff4040%s died|r", tostring(name))
    end
    addon:Print(text, true)
end

local function AutoShowOnCombatStart(settings)
    if not settings.showMeter then return end
    if settings.autoShowInCombat ~= false then
        -- Explicitly requested: bring the window back even if it was closed.
        if not combatFrame then
            CreateCombatFrame()
        end
        combatFrame:Show()
    elseif not settings.hidden then
        CombatLog.ShowFrame()
    end
end

local function StartFight(settings, now)
    inCombat = true
    combatStartTime = now
    ResetPlayerData()
    activeSegment = nil
    detailView = nil
    AutoShowOnCombatStart(settings)
end

local function OnCombatLogEvent(timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
    local settings = addon.settings.combatLog
    if not playerGUID then playerGUID = UnitGUID("player") end -- Safety check
    sourceFlags = sourceFlags or 0
    destFlags = destFlags or 0

    local trackGroup = settings.trackGroup ~= false
    local sourceInGroup = (sourceGUID ~= nil and sourceGUID == playerGUID)
        or bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0
        or (trackGroup and bit.band(sourceFlags, GROUP_MASK) > 0)
    local destInGroup = (destGUID ~= nil and destGUID == playerGUID)
        or bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0
        or (trackGroup and bit.band(destFlags, GROUP_MASK) > 0)

    if not sourceInGroup and not destInGroup then
        -- Only one thing of interest happens entirely outside the group: an
        -- enemy we are already fighting healing itself or an ally.
        if settings.trackEnemyHealing ~= false and inCombat and HEAL_EVENTS[event]
            and bit.band(sourceFlags, ENEMY_MASK) > 0 and enemyData[sourceGUID] then
            local amount, overheal = select(4, ...), select(5, ...)
            TrackEnemyHealing(sourceGUID, sourceName, (amount or 0) - (overheal or 0))
        end
        return
    end

    local sourceIsPet = bit.band(sourceFlags, PET_MASK) > 0
    local destIsPet = bit.band(destFlags, PET_MASK) > 0
    local sourceIsEnemy = (not sourceInGroup) and bit.band(sourceFlags, ENEMY_MASK) > 0
    local destIsEnemy = (not destInGroup) and bit.band(destFlags, ENEMY_MASK) > 0
    RememberName(sourceGUID, sourceName)
    RememberName(destGUID, destName)

    local arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19 = ...

    -- Smart combat start: hostile damage in either direction while the client
    -- has not flagged combat yet (pets pulling, first hit before REGEN_DISABLED).
    -- Decided before anything is recorded so the triggering hit is kept.
    -- Heals, buffs and energize ticks never start a fight, so the last fight
    -- stays on screen until the next pull.
    if not inCombat and DAMAGE_EVENTS[event] and ((sourceInGroup and destIsEnemy) or (destInGroup and sourceIsEnemy)) then
        local now = GetTime()
        if (now - combatEndTime) > 3 then
            StartFight(settings, now)
            addon:Debug("Smart Combat Start triggered")
        end
    end

    -- Timeline capture (group-related events only)
    if settings.trackTimeline and inCombat then
        local tSpellId, tSpellName, tAmount, tOverkill, tAbsorbed, tSchool
        if event == "SWING_DAMAGE" then
            tAmount, tOverkill, tSchool, tAbsorbed = arg9 or 0, arg10 or 0, arg11 or 0, arg14 or 0
        elseif DAMAGE_EVENTS[event] then
            tSpellId, tSpellName, tSchool, tAmount, tOverkill, tAbsorbed = arg9, arg10, arg11 or 0, arg12 or 0, arg13 or 0, arg16 or 0
        elseif HEAL_EVENTS[event] then
            tSpellId, tSpellName, tAmount, tOverkill, tAbsorbed = arg9, arg10, arg12 or 0, 0, arg14 or 0
        elseif MISS_EVENTS[event] or ENERGIZE_EVENTS[event] or TIMELINE_AURA_EVENTS[event] then
            tSpellId, tSpellName = arg9, arg10
            if ENERGIZE_EVENTS[event] then tAmount = arg12 or 0 end
        end
        RecordTimelineEvent(timestamp, event, sourceGUID, sourceName, destGUID, destName,
            tSpellId, tSpellName, tAmount, tOverkill, tAbsorbed, tSchool)
    end

    -- Pet -> owner attribution
    local ownerGUID, ownerData, petStats = nil, nil, nil
    if sourceInGroup and sourceIsPet then
        ownerGUID = ResolvePetOwner(sourceGUID, sourceFlags)
        if ownerGUID then
            ownerData = GetPlayerData(ownerGUID, NameForGUID(ownerGUID))
            if ownerData and (settings.trackPetDamage ~= false or settings.trackPetHealing ~= false) then
                petStats = ownerData.pets[sourceGUID]
                if not petStats then
                    petStats = { name = sourceName or "Pet", damage = 0, healing = 0 }
                    ownerData.pets[sourceGUID] = petStats
                end
            end
        end
    end

    local sourceData = nil
    if sourceInGroup then
        sourceData = ownerData or GetPlayerData(sourceGUID, sourceName, sourceFlags)
    end
    -- Pets and guardians of the group are not rows of their own on the
    -- receiving side (their damage taken / deaths would pollute the meter).
    local destData = nil
    if destInGroup and not destIsPet then
        destData = GetPlayerData(destGUID, destName, destFlags)
    end

    -- ------------------------------------------------------------
    -- Damage
    -- ------------------------------------------------------------
    if DAMAGE_EVENTS[event] then
        local spellId, spellName, school, amount, overkill, resisted, blocked, absorbed, critical, glancing, crushing
        if event == "SWING_DAMAGE" then
            spellId, spellName = 0, "Melee"
            amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing =
                arg9 or 0, arg10 or 0, arg11 or 1, arg12 or 0, arg13 or 0, arg14 or 0, arg15, arg16, arg17
        else
            spellId, spellName, school = arg9 or 0, arg10, arg11 or 0
            amount, overkill, resisted, blocked, absorbed, critical, glancing, crushing =
                arg12 or 0, arg13 or 0, arg14 or 0, arg15 or 0, arg16 or 0, arg17, arg18, arg19
        end

        if sourceData and not IGNORED_DAMAGE_SPELLS[spellId] then
            if destInGroup then
                -- Hitting an ally (or yourself) is friendly fire, never damage done.
                if settings.trackFriendlyFire ~= false and sourceGUID ~= destGUID and not destIsPet and amount > 0 then
                    sourceData.friendlyDamage = (sourceData.friendlyDamage or 0) + amount
                end
            else
                local creatureId = GetCreatureIdFromGUID(destGUID)
                if not (creatureId and IGNORED_CREATURES[creatureId]) then
                    sourceData.damage = sourceData.damage + amount
                    sourceData.totalDamage = (sourceData.totalDamage or 0) + amount + absorbed
                    if overkill > 0 and settings.trackOverkill ~= false then
                        sourceData.overkill = (sourceData.overkill or 0) + overkill
                    end
                    if petStats and settings.trackPetDamage ~= false then
                        petStats.damage = petStats.damage + amount
                        sourceData.petDamage = (sourceData.petDamage or 0) + amount
                    end
                    TrackSpell(sourceData, spellId, spellName, amount, critical, false, glancing, nil, absorbed, overkill, school, crushing)
                    if settings.trackActivity ~= false and not PASSIVE_SPELLS[spellId] then
                        UpdateActivity(sourceData)
                    end
                    if settings.trackEnemies ~= false and destIsEnemy and amount > 0 then
                        local enemy = TrackEnemyDamage(destGUID, destName, ownerGUID or sourceGUID, sourceData.name, amount)
                        if enemy and enemy.isImportant and settings.trackUsefulDamage ~= false then
                            sourceData.usefulDamage = (sourceData.usefulDamage or 0) + amount
                        end
                    end
                end
            end
        end

        if destData then
            RecordDamageTaken(settings, destData, destGUID, sourceGUID, sourceName, spellId, spellName, school,
                amount, overkill, resisted, blocked, absorbed, critical, glancing)
        end

    elseif event == "ENVIRONMENTAL_DAMAGE" then
        if destData then
            -- environmentalType, amount, overkill, school, resisted, blocked, absorbed, critical, glancing
            local envType = arg9 or "Environment"
            RecordDamageTaken(settings, destData, destGUID, nil, envType, -1, envType, arg12 or 0,
                arg10 or 0, arg11 or 0, arg13 or 0, arg14 or 0, arg15 or 0, arg16, arg17)
        end

    -- ------------------------------------------------------------
    -- Misses
    -- ------------------------------------------------------------
    elseif MISS_EVENTS[event] then
        local spellId, spellName, missType
        if event == "SWING_MISSED" then
            spellId, spellName, missType = 0, "Melee", arg9
        else
            spellId, spellName, missType = arg9 or 0, arg10, arg12
        end
        if MISS_TYPES[missType] then
            if sourceData and not destInGroup then
                -- Per-spell only: the player-level dodge/parry/miss counters
                -- belong to the victim side (avoidance).
                TrackSpell(sourceData, spellId, spellName, 0, false, false, false, missType, 0, 0, nil)
            end
            if destData and settings.trackAvoidance ~= false then
                RecordAvoidance(destData, missType)
            end
        end

    -- ------------------------------------------------------------
    -- Healing
    -- ------------------------------------------------------------
    elseif HEAL_EVENTS[event] then
        local spellId, spellName, school, amount, overheal, absorbed, critical = arg9 or 0, arg10, arg11, arg12 or 0, arg13 or 0, arg14 or 0, arg15
        local effective = amount - overheal
        if effective < 0 then effective = 0 end

        if sourceData and not IGNORED_HEALING_SPELLS[spellId] then
            sourceData.healing = sourceData.healing + effective
            sourceData.totalHealing = (sourceData.totalHealing or 0) + amount
            if settings.trackOverhealing ~= false then
                sourceData.overhealing = (sourceData.overhealing or 0) + overheal
            end
            if petStats and settings.trackPetHealing ~= false then
                petStats.healing = petStats.healing + effective
                sourceData.petHealing = (sourceData.petHealing or 0) + effective
            end
            if settings.trackHealingBySpell ~= false then
                TrackSpell(sourceData, spellId, spellName, effective, critical, true, false, nil, absorbed, 0, school, false, overheal)
            end
            if settings.trackActivity ~= false and effective > 0 and not PASSIVE_SPELLS[spellId] then
                UpdateActivity(sourceData)
            end
        end

        if destData and settings.trackHealingTaken ~= false then
            if sourceGUID then
                destData.healingTakenFrom[sourceGUID] = (destData.healingTakenFrom[sourceGUID] or 0) + effective
            end
            destData.healingTaken = (destData.healingTaken or 0) + effective
            if settings.deathRecap ~= false and effective > 0 then
                AddDeathLogEntry(destGUID, "heal", {
                    sourceGUID = sourceGUID,
                    sourceName = sourceName,
                    spellName = spellName,
                    spellId = spellId,
                    amount = effective,
                })
            end
        end

    -- ------------------------------------------------------------
    -- Interrupts / dispels
    -- ------------------------------------------------------------
    elseif event == "SPELL_INTERRUPT" then
        if sourceData and settings.trackInterrupts ~= false then
            sourceData.interrupts = (sourceData.interrupts or 0) + 1
            if sourceGUID == playerGUID and settings.announceInterrupts then
                -- spellId, spellName, school, extraSpellId, extraSpellName, extraSchool
                local channel = settings.interruptChannel or "SAY"
                if channel == "RAID" and not InRaid() then channel = "PARTY" end
                if channel == "PARTY" and not InGroup() then channel = "SAY" end
                SendChatMessage(string.format("Interrupted %s's %s!", destName or "Unknown", arg13 or "Unknown"), channel)
            end
        end

    elseif event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
        if sourceData and settings.trackDispels ~= false then
            sourceData.dispels = (sourceData.dispels or 0) + 1
        end

    -- ------------------------------------------------------------
    -- Auras
    -- ------------------------------------------------------------
    elseif event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
        local spellId, spellName, auraType = arg9 or 0, arg10, arg12
        local isBuff = (auraType == "BUFF")
        local fresh = (event == "SPELL_AURA_APPLIED")

        if fresh and sourceData and settings.trackCrowdControl ~= false and CC_SPELLS[spellId] and not destInGroup then
            sourceData.ccDone = (sourceData.ccDone or 0) + 1
            sourceData.ccSpells[spellId] = (sourceData.ccSpells[spellId] or 0) + 1
        end

        if destData then
            if fresh and settings.trackCCTaken ~= false and CC_SPELLS[spellId] and not sourceInGroup then
                destData.ccTaken = (destData.ccTaken or 0) + 1
            end
            if fresh and settings.deathRecap ~= false and settings.deathRecapShowBuffs ~= false then
                AddDeathLogEntry(destGUID, isBuff and "buff" or "debuff", {
                    sourceGUID = sourceGUID,
                    sourceName = sourceName,
                    spellName = spellName,
                    spellId = spellId,
                })
            end
            if event ~= "SPELL_AURA_APPLIED_DOSE"
                and ((isBuff and settings.trackBuffs ~= false) or (not isBuff and settings.trackDebuffs ~= false)) then
                TrackBuff(destGUID, spellId, spellName, auraType, not fresh)
            end
            if isBuff and sourceInGroup and settings.trackAbsorbs ~= false and ABSORB_SPELLS[spellId] then
                RegisterShield(destGUID, spellId, ownerGUID or sourceGUID, (ownerData and ownerData.name) or sourceName)
            end
        end

    elseif event == "SPELL_AURA_REMOVED" then
        local spellId, auraType = arg9 or 0, arg12
        if destInGroup and not destIsPet then
            RemoveBuff(destGUID, spellId, auraType)
            if ABSORB_SPELLS[spellId] then
                RemoveShield(destGUID, spellId)
            end
        end

    elseif event == "SPELL_AURA_BROKEN" or event == "SPELL_AURA_BROKEN_SPELL" then
        -- arg9 = the aura that broke; the source is whoever broke it
        if sourceData and settings.trackCCBreaks ~= false and CC_SPELLS[arg9] and not destInGroup then
            sourceData.ccBreaks = (sourceData.ccBreaks or 0) + 1
        end

    -- ------------------------------------------------------------
    -- Casts / consumables / resurrects / power
    -- ------------------------------------------------------------
    elseif event == "SPELL_CAST_SUCCESS" then
        if sourceData then
            local spellId = arg9 or 0
            if settings.trackCasts ~= false then
                sourceData.casts = (sourceData.casts or 0) + 1
            end
            local kind = CONSUMABLE_SPELLS[spellId]
            if kind and settings.trackPotions ~= false then
                if kind == "potion" then
                    sourceData.potionsUsed = (sourceData.potionsUsed or 0) + 1
                elseif kind == "healthstone" then
                    sourceData.healthstonesUsed = (sourceData.healthstonesUsed or 0) + 1
                end
            end
        end

    elseif event == "SPELL_RESURRECT" then
        if sourceData and settings.trackResurrects ~= false then
            sourceData.resurrects = (sourceData.resurrects or 0) + 1
        end

    elseif ENERGIZE_EVENTS[event] then
        if sourceData and settings.trackPowerGains ~= false then
            local amount, powerType = arg12 or 0, arg13
            if powerType == POWER_TYPE_MANA then
                sourceData.manaGain = (sourceData.manaGain or 0) + amount
            elseif powerType == POWER_TYPE_RAGE then
                sourceData.rageGain = (sourceData.rageGain or 0) + amount
            elseif powerType == POWER_TYPE_ENERGY or powerType == POWER_TYPE_FOCUS then
                sourceData.energyGain = (sourceData.energyGain or 0) + amount
            elseif powerType == POWER_TYPE_RUNIC then
                sourceData.runicGain = (sourceData.runicGain or 0) + amount
            end
        end

    -- ------------------------------------------------------------
    -- Kills / deaths
    -- ------------------------------------------------------------
    elseif event == "PARTY_KILL" then
        if sourceData and settings.trackKillingBlows ~= false and sourceGUID ~= destGUID then
            sourceData.killingBlows = (sourceData.killingBlows or 0) + 1
        end

    elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        -- The player's own death is counted on PLAYER_DEAD (which also opens the recap).
        if destData and destGUID ~= playerGUID then
            destData.deaths = (destData.deaths or 0) + 1
            if settings.announceDeaths then
                AnnounceDeath(destData, destName)
            end
        end

    -- Forward compatibility: clients that do emit SPELL_ABSORBED
    elseif event == "SPELL_ABSORBED" then
        if destData and settings.trackAbsorbs ~= false then
            local absorbSourceGUID, absorbSourceName, absorbAmount
            if type(arg12) == "string" then
                absorbSourceGUID, absorbSourceName, absorbAmount = arg12, arg13, arg17 or 0
            else
                absorbSourceGUID, absorbSourceName, absorbAmount = arg9, arg10, arg14 or 0
            end
            if absorbSourceGUID and absorbAmount > 0 then
                local data = GetPlayerData(absorbSourceGUID, absorbSourceName)
                if data then
                    data.absorbs = (data.absorbs or 0) + absorbAmount
                end
            end
        end
    end
end

local ROSTER_EVENTS = {
    PARTY_MEMBERS_CHANGED = true,
    RAID_ROSTER_UPDATE = true,
    UNIT_PET = true,
    PLAYER_ENTERING_WORLD = true,
}

local function OnCombatEvent(self, event, ...)
    local settings = addon.settings.combatLog

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if settings.enabled then
            OnCombatLogEvent(...)
        end
        return
    end

    if ROSTER_EVENTS[event] then
        MarkRosterDirty()
        if event == "PLAYER_ENTERING_WORLD" then
            playerGUID = UnitGUID("player")
            playerName = UnitName("player")
        end
        -- Members seen before they were in range get their class colour now.
        for guid, data in pairs(playerData) do
            if not data.class then
                data.class = ResolveClass(guid)
            end
        end
        return
    end

    if not settings.enabled then return end

    if event == "PLAYER_REGEN_DISABLED" then
        local now = GetTime()
        if inCombat and (now - combatStartTime) > 5 then
            -- A smart start that never turned into real combat: close it out
            -- as its own segment instead of silently discarding it.
            inCombat = false
            combatEndTime = now
            SaveSegment()
        end
        if not inCombat then
            StartFight(settings, now)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        combatEndTime = GetTime()
        SaveSegment()
        CombatLog.UpdateFrame()
    elseif event == "PLAYER_DEAD" then
        local data = GetPlayerData(playerGUID, playerName)
        if data then
            data.deaths = (data.deaths or 0) + 1
            if settings.announceDeaths then
                AnnounceDeath(data, playerName)
            end
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

        -- Chat summary aliases -> meter modes
        local SUMMARY_COMMANDS = {
            dispels = "dispels", absorbs = "absorbs", activity = "activity", uptime = "activity",
            kb = "killingBlows", killingblows = "killingBlows", cc = "cc", crowdcontrol = "cc",
            power = "power", mana = "power", ff = "friendlyFire", friendlyfire = "friendlyFire",
            consumables = "consumables", potions = "consumables", interrupts = "interrupts",
            deaths = "deaths", taken = "damageTaken", enemies = "enemyDamageTaken", casts = "casts",
        }

        -- NOTE: /dcc is reserved by DC-Collection. Do not claim it here.
        SLASH_DCCOMBAT1 = "/dccombat"
        SLASH_DCCOMBAT2 = "/dcqoscombat"
        SlashCmdList["DCCOMBAT"] = function(msg)
            msg = tostring(msg or "")
            msg = msg:match("^%s*(.-)%s*$")
            local lower = string.lower(msg)
            local cmd, rest = lower:match("^(%S+)%s*(.*)$")
            cmd = cmd or ""
            rest = rest or ""

            if cmd == "" or cmd == "toggle" then
                if combatFrame and combatFrame:IsShown() then
                    CombatLog.HideFrame()
                else
                    CombatLog.ShowFrame()
                end
            elseif cmd == "show" then
                CombatLog.ShowFrame()
            elseif cmd == "hide" then
                CombatLog.HideFrame()
            elseif cmd == "reset" then
                ResetPlayerData()
                detailView = nil
                SelectSegment(0)
                addon:Print("Combat stats reset.", true)
            elseif cmd == "death" then
                ShowDeathRecap()
            elseif cmd == "damage" or cmd == "d" then
                addon:SetSetting("combatLog.meterMode", "damage")
                CombatLog.UpdateFrame()
                addon:Print("Mode: Damage Done", true)
            elseif cmd == "healing" or cmd == "h" then
                addon:SetSetting("combatLog.meterMode", "healing")
                CombatLog.UpdateFrame()
                addon:Print("Mode: Healing Done", true)
            elseif cmd == "mode" then
                local wanted = nil
                for key, label in pairs(MODE_NAMES) do
                    if string.lower(key) == rest or string.lower(label) == rest then
                        wanted = key
                        break
                    end
                end
                if wanted then
                    addon:SetSetting("combatLog.meterMode", wanted)
                    CombatLog.UpdateFrame()
                    addon:Print("Mode: " .. MODE_NAMES[wanted], true)
                else
                    addon:Print("Unknown mode. Available:", true)
                    local keys = {}
                    for key in pairs(MODE_NAMES) do keys[#keys + 1] = key end
                    table.sort(keys)
                    print("  " .. table.concat(keys, ", "))
                end
            elseif cmd == "spells" or cmd == "s" then
                -- Preserve the typed case of a player name
                local target = msg:match("^%S+%s+(.+)$")
                ShowSpellBreakdown(target)
            elseif cmd == "buffs" or cmd == "debuffs" then
                local target = msg:match("^%S+%s+(.+)$")
                ShowBuffUptime(target, cmd == "debuffs")
            elseif cmd == "report" then
                local channel, a, b = rest:match("^(%S*)%s*(%S*)%s*(%S*)$")
                channel = (channel and channel ~= "") and channel or "party"
                if channel == "whisper" then
                    local target = msg:match("^%S+%s+%S+%s+(%S+)")
                    CombatLog.Report("whisper", tonumber(b), target)
                else
                    CombatLog.Report(channel, tonumber(a))
                end
            elseif cmd == "segments" then
                addon:Print("Segments:", true)
                print("  0. Current fight")
                for i, seg in ipairs(segments) do
                    print(string.format("  %d. %s (%s)", i, seg.name or ("Fight " .. tostring(seg.id)), FormatTime(seg.duration)))
                end
            elseif cmd == "segment" then
                local index = tonumber(rest)
                if index and (index == 0 or segments[index]) then
                    SelectSegment(index)
                else
                    addon:Print("Usage: /dccombat segment <number> (see /dccombat segments)", true)
                end
            elseif cmd == "back" then
                CombatLog.ExitDetailView()
            elseif SUMMARY_COMMANDS[cmd] then
                PrintSummary(SUMMARY_COMMANDS[cmd], tonumber(rest))
            elseif cmd == "lock" then
                CombatLog.ToggleLock()
            elseif cmd == "help" then
                addon:Print("Combat Log Commands:", true)
                print("  |cffffd700/dccombat|r - Toggle display")
                print("  |cffffd700/dccombat show/hide|r - Show/hide window")
                print("  |cffffd700/dccombat lock|r - Lock/unlock window position")
                print("  |cffffd700/dccombat d|r / |cffffd700h|r - Damage / healing mode")
                print("  |cffffd700/dccombat mode <name>|r - Any mode (damageTaken, absorbs, deaths, ...)")
                print("  |cffffd700/dccombat report [say|party|raid|guild|officer|bg] [lines]|r - Post the ranking to chat")
                print("  |cffffd700/dccombat report whisper <player> [lines]|r - Whisper the ranking")
                print("  |cffffd700/dccombat segments|r / |cffffd700segment <n>|r - List / select a fight")
                print("  |cffffd700/dccombat s|r / |cffffd700spells <name>|r - Spell breakdown (chat)")
                print("  |cffffd700/dccombat buffs [name]|r / |cffffd700debuffs [name]|r - Aura uptime")
                print("  |cffffd700/dccombat dispels|absorbs|activity|kb|cc|power|ff|consumables|interrupts|deaths|taken|enemies|casts|r - Chat summaries")
                print("  |cffffd700/dccombat back|r - Leave the spell breakdown view")
                print("  |cffffd700/dccombat reset|r - Reset stats")
                print("  |cffffd700/dccombat death|r - Show death recap")
                print("  Window: left-click a bar for its breakdown, right-click for the menu.")
            else
                addon:Print("Unknown command. Try /dccombat help", true)
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
    eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
    eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_PET")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", OnCombatEvent)
    MarkRosterDirty()

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

-- Accessors for other modules / tests
function CombatLog.GetSegments()
    return segments
end

function CombatLog.GetNameForGUID(guid)
    return NameForGUID(guid)
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

    local timerCb = addon:CreateCheckbox(parent)
    timerCb:SetPoint("TOPLEFT", 16, yOffset)
    timerCb.Text:SetText("Show combat timer in the title bar")
    timerCb:SetChecked(settings.showCombatTimer ~= false)
    timerCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showCombatTimer", self:GetChecked() and true or false)
        CombatLog.UpdateFrame()
    end)
    yOffset = yOffset - 25

    local dpsCb = addon:CreateCheckbox(parent)
    dpsCb:SetPoint("TOPLEFT", 16, yOffset)
    dpsCb.Text:SetText("Show your DPS in the footer")
    dpsCb:SetChecked(settings.showPersonalDPS)
    dpsCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showPersonalDPS", self:GetChecked() and true or false)
        CombatLog.UpdateFrame()
    end)
    yOffset = yOffset - 25

    local hpsCb = addon:CreateCheckbox(parent)
    hpsCb:SetPoint("TOPLEFT", 16, yOffset)
    hpsCb.Text:SetText("Show your HPS in the footer")
    hpsCb:SetChecked(settings.showPersonalHPS)
    hpsCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showPersonalHPS", self:GetChecked() and true or false)
        CombatLog.UpdateFrame()
    end)
    yOffset = yOffset - 25

    local drillCb = addon:CreateCheckbox(parent)
    drillCb:SetPoint("TOPLEFT", 16, yOffset)
    drillCb.Text:SetText("Left-click a bar to open its spell breakdown")
    drillCb:SetChecked(settings.showSpellBreakdown ~= false)
    drillCb:SetScript("OnClick", function(self)
        addon:SetSetting("combatLog.showSpellBreakdown", self:GetChecked() and true or false)
        if not self:GetChecked() then
            CombatLog.ExitDetailView()
        end
    end)
    yOffset = yOffset - 30

    local function AddSlider(name, label, minV, maxV, step, value, onChange, format)
        local slider = addon:CreateSlider(parent, name)
        slider:SetPoint("TOPLEFT", 20, yOffset - 10)
        slider:SetWidth(220)
        slider:SetMinMaxValues(minV, maxV)
        slider:SetValueStep(step)
        slider.Text:SetText(label)
        slider.Low:SetText(format and format(minV) or tostring(minV))
        slider.High:SetText(format and format(maxV) or tostring(maxV))
        slider:SetValue(value)
        slider:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v / step + 0.5) * step
            if self.Value then
                self.Value:SetText(format and format(v) or tostring(v))
            end
            onChange(v)
        end)
        yOffset = yOffset - 50
        return slider
    end

    AddSlider("DCQoS_CombatBarHeightSlider", "Bar height", 10, 40, 1, settings.barHeight or 18, function(v)
        if settings.barHeight ~= v then
            addon:SetSetting("combatLog.barHeight", v)
            CombatLog.UpdateFrame()
        end
    end)

    AddSlider("DCQoS_CombatMaxBarsSlider", "Maximum bars", 1, 15, 1, settings.maxBars or 10, function(v)
        if settings.maxBars ~= v then
            addon:SetSetting("combatLog.maxBars", v)
            CombatLog.UpdateFrame()
        end
    end)

    AddSlider("DCQoS_CombatScaleSlider", "Window scale", 50, 200, 5, math.floor((settings.scale or 1) * 100 + 0.5), function(v)
        local scale = v / 100
        if math.abs((settings.scale or 1) - scale) > 0.001 then
            addon:SetSetting("combatLog.scale", scale)
            CombatLog.ApplyWindowSettings()
        end
    end, function(v) return v .. "%" end)

    AddSlider("DCQoS_CombatAlphaSlider", "Window opacity", 10, 100, 5, math.floor((settings.frameAlpha or 0.9) * 100 + 0.5), function(v)
        local alpha = v / 100
        if math.abs((settings.frameAlpha or 0.9) - alpha) > 0.001 then
            addon:SetSetting("combatLog.frameAlpha", alpha)
            CombatLog.ApplyWindowSettings()
        end
    end, function(v) return v .. "%" end)

    AddSlider("DCQoS_CombatReportLinesSlider", "Report lines", 1, 25, 1, settings.reportCount or 10, function(v)
        if settings.reportCount ~= v then
            addon:SetSetting("combatLog.reportCount", v)
        end
    end)

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

    yOffset = yOffset - 10
    
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
