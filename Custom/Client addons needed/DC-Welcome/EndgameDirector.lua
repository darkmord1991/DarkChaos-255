--[[
    DC-Welcome EndgameDirector.lua
    Central endgame overview for keys, vault, seasonal tasks,
    hotspot timers, rare spawns, world boss windows, HLBG,
    group-finder opportunities, and wishlist targets.
]]

local addonName = "DC-Welcome"
DCWelcome = DCWelcome or {}

local Director = DCWelcome.EndgameDirector or {}
DCWelcome.EndgameDirector = Director

local HEADER_HEIGHT = 74
local CARD_HEIGHT = 118
local CARD_SPACING = 10
local CARD_INSET = 10
local REFRESH_INTERVAL = 1
local VAULT_THRESHOLDS = { 1, 4, 8 }

local function CreateBackground(parent, layer, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture(r, g, b, a or 1)
    return tex
end

local function CreateFontString(parent, layer, fontObject)
    return parent:CreateFontString(nil, layer or "OVERLAY",
        fontObject or "GameFontHighlight")
end

local function CountEntries(tbl)
    if type(tbl) ~= "table" then
        return 0
    end

    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function SafeNumber(value, fallback)
    local num = tonumber(value)
    if num ~= nil then
        return num
    end

    return fallback or 0
end

local function SafeText(value, fallback)
    local text = tostring(value or "")
    if text == "" or text == "nil" then
        return fallback or "Unknown"
    end

    return text
end

local function Truncate(text, limit)
    text = SafeText(text, "")
    limit = tonumber(limit) or 40
    if string.len(text) <= limit then
        return text
    end

    return string.sub(text, 1, limit - 3) .. "..."
end

local function FormatDuration(seconds)
    seconds = math.max(0, SafeNumber(seconds, 0))

    if seconds < 60 then
        return string.format("%ds", seconds)
    end

    if seconds < 3600 then
        return string.format("%dm", math.floor(seconds / 60))
    end

    if seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        if minutes > 0 then
            return string.format("%dh %dm", hours, minutes)
        end

        return string.format("%dh", hours)
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    if hours > 0 then
        return string.format("%dd %dh", days, hours)
    end

    return string.format("%dd", days)
end

local function FormatEpochRemaining(epoch)
    epoch = SafeNumber(epoch, 0)
    if epoch <= 0 then
        return "Unknown"
    end

    local remaining = epoch - time()
    if remaining <= 0 then
        return "Expired"
    end

    return FormatDuration(remaining)
end

local function JoinLines(lines)
    return table.concat(lines or {}, "\n")
end

local function HideWelcomePanel()
    if DCWelcome and DCWelcome.HideWelcome then
        DCWelcome:HideWelcome()
    end
end

local function PrintMessage(msg)
    if DCWelcome and DCWelcome.Print then
        DCWelcome.Print(msg)
    end
end

local function OpenAddonsHub()
    if DCWelcome and DCWelcome.ShowWelcomeTab then
        DCWelcome:ShowWelcomeTab("addons")
        return
    end

    if DCWelcome and DCWelcome.ShowWelcome then
        DCWelcome:ShowWelcome(true)
    end
end

local function OpenWelcomeTab(tabId)
    if not tabId then
        return
    end

    if DCWelcome and DCWelcome.ShowWelcomeTab then
        DCWelcome:ShowWelcomeTab(tabId)
    elseif DCWelcome and DCWelcome.ShowWelcome then
        DCWelcome:ShowWelcome(true)
    end
end

local function DispatchSlash(name, msg)
    if SlashCmdList and SlashCmdList[name] then
        HideWelcomePanel()
        SlashCmdList[name](msg or "")
        return true
    end

    return false
end

local function ToggleSeasonTracker()
    if DCWelcome and DCWelcome.Seasons and
        DCWelcome.Seasons.ToggleProgressTracker then
        HideWelcomePanel()
        DCWelcome.Seasons:ToggleProgressTracker()
        return true
    end

    if DispatchSlash("DCSEASONS", "") then
        return true
    end

    PrintMessage("Season tracker is not available.")
    return false
end

local function OpenLeaderboards(categoryId, subcategoryId)
    HideWelcomePanel()

    if DCWelcome and DCWelcome.OpenLeaderboards then
        return DCWelcome:OpenLeaderboards(categoryId, subcategoryId)
    end

    PrintMessage("Leaderboards addon not available.")
    return false
end

local function OpenGroupFinder()
    local mythic = rawget(_G, "DCMythicPlusHUD")

    if mythic and mythic.GroupFinder and mythic.GroupFinder.Toggle then
        HideWelcomePanel()
        mythic.GroupFinder:Toggle()
        return true
    end

    if DispatchSlash("DCGF", "") then
        return true
    end

    PrintMessage("Mythic+ Group Finder is not available.")
    return false
end

local function OpenMythicHud()
    if DispatchSlash("DCM", "") then
        return true
    end

    PrintMessage("Mythic+ HUD is not available.")
    return false
end

local function OpenGreatVault()
    local mythic = rawget(_G, "DCMythicPlusHUD")
    if mythic and mythic.GreatVault and mythic.GreatVault.Toggle then
        HideWelcomePanel()
        mythic.GreatVault:Toggle()
        return true
    end

    if DispatchSlash("DCM", "vault") then
        return true
    end

    PrintMessage("Great Vault UI is not available.")
    return false
end

local function OpenHotspotList()
    if DispatchSlash("DCHOTSPOT", "") then
        return true
    end

    PrintMessage("Hotspot tools are not available.")
    return false
end

local function OpenHotspotOptions()
    if DispatchSlash("DCHOTSPOT", "options") then
        return true
    end

    PrintMessage("Map Upgrades options are not available.")
    return false
end

local function ToggleInfoBar()
    if DispatchSlash("DCINFOBAR", "toggle") then
        return true
    end

    local infoBar = rawget(_G, "DCInfoBar")
    if infoBar and infoBar.bar then
        infoBar.bar:SetShown(not infoBar.bar:IsShown())
        return true
    end

    PrintMessage("Info Bar is not available.")
    return false
end

local function OpenHLBG()
    if DispatchSlash("HLBGSHOW", "") then
        return true
    end

    PrintMessage("Hinterland BG addon is not available.")
    return false
end

local function OpenHLBGLeaderboards()
    local hlbg = rawget(_G, "HLBG")
    if hlbg and hlbg.OpenLeaderboards then
        HideWelcomePanel()
        hlbg:OpenLeaderboards()
        return true
    end

    return OpenLeaderboards("hlbg")
end

local function OpenCollections()
    local collection = rawget(_G, "DCCollection")

    if collection and collection.Show then
        HideWelcomePanel()
        collection:Show()
        return true
    end

    if collection and collection.Toggle then
        HideWelcomePanel()
        collection:Toggle()
        return true
    end

    if DispatchSlash("DCCOLLECTION", "") then
        return true
    end

    PrintMessage("DC-Collection is not available.")
    return false
end

local function OpenWishlist()
    local collection = rawget(_G, "DCCollection")

    if collection and collection.ShowWishlist then
        HideWelcomePanel()
        collection:ShowWishlist()
        return true
    end

    return OpenCollections()
end

local function RequestFreshData()
    if DCWelcome and DCWelcome.RequestProgressData then
        DCWelcome:RequestProgressData()
    end

    if DCWelcome and DCWelcome.RequestServerInfo then
        DCWelcome:RequestServerInfo()
    end

    local collection = rawget(_G, "DCCollection")
    if collection and collection.RequestWishlist then
        pcall(function() collection:RequestWishlist() end)
    end
    if collection and collection.RequestStats then
        pcall(function() collection:RequestStats() end)
    end
end

local function GetProgress()
    if DCWelcome and DCWelcome.GetProgress then
        return DCWelcome:GetProgress() or {}
    end

    return {}
end

local function GetSeasonInfo()
    local infoBar = rawget(_G, "DCInfoBar")
    if infoBar and infoBar.serverData and infoBar.serverData.season then
        return infoBar.serverData.season
    end

    return {}
end

local function GetAffixNames()
    local infoBar = rawget(_G, "DCInfoBar")
    if infoBar and infoBar.serverData and infoBar.serverData.affixes and
        type(infoBar.serverData.affixes.names) == "table" then
        local names = {}
        for _, name in ipairs(infoBar.serverData.affixes.names) do
            if name and name ~= "" then
                table.insert(names, tostring(name))
            end
        end
        if #names > 0 then
            return table.concat(names, " / ")
        end
    end

    local mythicDb = rawget(_G, "DCMythicPlusHUDDB")
    if mythicDb and mythicDb.cache and type(mythicDb.cache.affixes) == "table" then
        local names = {}
        for _, affix in ipairs(mythicDb.cache.affixes) do
            if type(affix) == "table" then
                table.insert(names,
                    tostring(affix.name or affix.label or affix.spellName or affix.id))
            elseif type(affix) == "string" then
                table.insert(names, affix)
            end
        end
        if #names > 0 then
            return table.concat(names, " / ")
        end
    end

    return nil
end

local function GetMapUpgradesDB()
    local db = rawget(_G, "DCMapupgradesDB")
    if type(db) == "table" and (
        type(db.cache) == "table" or
        (type(db.entities) == "table" and type(db.entities.list) == "table") or
        type(db.entityStatus) == "table") then
        return db
    end

    db = rawget(_G, "DCHotspotDB")
    if type(db) == "table" then
        return db
    end

    return nil
end

local function BuildHotspotEntries()
    local db = GetMapUpgradesDB()
    if not db or type(db.cache) ~= "table" then
        return nil
    end

    local nowEpoch = time()
    local entries = {}
    for id, data in pairs(db.cache) do
        if type(data) == "table" and SafeNumber(data.expireEpoch, 0) > nowEpoch then
            table.insert(entries, {
                id = id,
                zone = SafeText(data.zone or data.name, "Hotspot"),
                bonus = SafeNumber(data.bonus, 0),
                remaining = data.expireEpoch - nowEpoch,
            })
        end
    end

    table.sort(entries, function(a, b)
        if a.remaining == b.remaining then
            return tostring(a.zone) < tostring(b.zone)
        end

        return a.remaining < b.remaining
    end)

    return entries
end

local function BuildRareEntries()
    local db = GetMapUpgradesDB()
    if not db or type(db.entities) ~= "table" or type(db.entities.list) ~= "table" then
        return nil
    end

    local statusDb = type(db.entityStatus) == "table" and db.entityStatus or {}
    local nowEpoch = time()
    local entries = {}

    for _, entity in ipairs(db.entities.list) do
        if type(entity) == "table" and entity.kind == "rare" then
            local id = tonumber(entity.id) or entity.id
            local status = type(statusDb[id]) == "table" and statusDb[id] or {}
            table.insert(entries, {
                name = SafeText(entity.name, "Rare"),
                zone = SafeText(entity.zone or entity.mapName, "Unknown zone"),
                activeUntil = SafeNumber(status.activeUntil, 0),
                lastKilled = SafeNumber(status.lastKilled, 0),
                isActive = SafeNumber(status.activeUntil, 0) > nowEpoch,
            })
        end
    end

    table.sort(entries, function(a, b)
        if a.isActive ~= b.isActive then
            return a.isActive
        end

        if a.isActive and b.isActive then
            return a.activeUntil < b.activeUntil
        end

        if a.lastKilled ~= b.lastKilled then
            return a.lastKilled > b.lastKilled
        end

        return a.name < b.name
    end)

    return entries
end

local function BuildWorldBossEntries()
    local infoBar = rawget(_G, "DCInfoBar")
    local entries = {}

    if infoBar and infoBar.serverData and
        type(infoBar.serverData.worldBosses) == "table" then
        for _, boss in ipairs(infoBar.serverData.worldBosses) do
            if type(boss) == "table" then
                local status = string.lower(SafeText(
                    boss.status or boss.state, "unknown"))
                local hp = tonumber(boss.hp)
                table.insert(entries, {
                    name = SafeText(boss.name, "World Boss"),
                    zone = SafeText(boss.zone, "Unknown zone"),
                    status = status,
                    spawnIn = SafeNumber(
                        boss.spawnIn or boss.timeRemaining or boss.remaining, 0),
                    hp = hp,
                    active = status == "active" or (hp ~= nil and hp > 0),
                })
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.active ~= b.active then
            return a.active
        end

        if a.spawnIn ~= b.spawnIn then
            return a.spawnIn < b.spawnIn
        end

        return a.name < b.name
    end)

    return entries
end

local function BuildKeystoneData()
    local progress = GetProgress()
    local infoBar = rawget(_G, "DCInfoBar")
    local keystone = {}

    if infoBar and infoBar.serverData and infoBar.serverData.keystone then
        keystone = infoBar.serverData.keystone
    end

    local keysThisWeek = SafeNumber(progress.keysThisWeek, 0)
    local vaultSlots = SafeNumber(progress.weeklyVaultProgress, 0)
    if vaultSlots <= 0 then
        for _, threshold in ipairs(VAULT_THRESHOLDS) do
            if keysThisWeek >= threshold then
                vaultSlots = vaultSlots + 1
            end
        end
    end

    local nextThreshold, keysNeeded
    for _, threshold in ipairs(VAULT_THRESHOLDS) do
        if keysThisWeek < threshold then
            nextThreshold = threshold
            keysNeeded = threshold - keysThisWeek
            break
        end
    end

    return {
        keystone = keystone,
        keysThisWeek = keysThisWeek,
        vaultSlots = vaultSlots,
        nextThreshold = nextThreshold,
        keysNeeded = keysNeeded,
        rating = progress.mythicRating,
        affixes = GetAffixNames(),
    }
end

local function BuildHLBGData()
    local hlbg = rawget(_G, "HLBG")
    if not hlbg then
        return nil
    end

    local resources = rawget(_G, "RES")
    return {
        state = SafeText(hlbg.BattleState, "UNKNOWN"),
        inQueue = hlbg.IsInQueue and true or false,
        queuePosition = SafeNumber(hlbg.QueuePosition, 0),
        queueTotal = SafeNumber(hlbg.QueueTotal, 0),
        waitSeconds = SafeNumber(hlbg.EstimatedWaitSeconds, 0),
        allianceQueued = SafeNumber(hlbg.AllianceQueued, 0),
        hordeQueued = SafeNumber(hlbg.HordeQueued, 0),
        minPlayers = SafeNumber(hlbg.MinPlayersToStart, 0),
        affixText = SafeText(hlbg._affixText, "No affix synced"),
        timeLeft = SafeNumber((resources and resources.DURATION) or hlbg._timeLeft, 0),
    }
end

local function GetCandidateCount(source, names)
    if type(source) ~= "table" then
        return 0
    end

    for _, name in ipairs(names or {}) do
        local value = source[name]
        if type(value) == "table" then
            return CountEntries(value)
        end
    end

    return 0
end

local function BuildGroupFinderData()
    local mythic = rawget(_G, "DCMythicPlusHUD")
    local finder = mythic and mythic.GroupFinder or nil
    local keystoneData = BuildKeystoneData()

    return {
        hasAddon = finder ~= nil or (SlashCmdList and SlashCmdList["DCGF"] ~= nil),
        hasKey = keystoneData.keystone and
            (keystoneData.keystone.hasKey or SafeNumber(
                keystoneData.keystone.level, 0) > 0),
        keyLevel = keystoneData.keystone and
            SafeNumber(keystoneData.keystone.level, 0) or 0,
        keyName = keystoneData.keystone and SafeText(
            keystoneData.keystone.dungeonAbbrev or
            keystoneData.keystone.dungeonName, "Mythic+") or "Mythic+",
        scheduled = GetCandidateCount(finder, {
            "scheduledEvents", "ScheduledEvents", "events"
        }),
        applications = GetCandidateCount(finder, {
            "myApplications", "applications", "MyApplications"
        }),
        liveRuns = GetCandidateCount(finder, {
            "liveRuns", "LiveRuns", "spectatorRuns", "runs"
        }),
        listings = GetCandidateCount(finder, {
            "mythicGroups", "groups", "groupResults", "worldGroups"
        }),
    }
end

local function BuildWishlistData()
    local collection = rawget(_G, "DCCollection")
    if not collection then
        return nil
    end

    local owned, total = 0, 0
    if collection.GetTotalCount then
        owned, total = collection:GetTotalCount()
    end

    return {
        collection = collection,
        wishlist = type(collection.wishlist) == "table" and collection.wishlist or {},
        recent = type(collection.recentAdditions) == "table" and
            collection.recentAdditions or {},
        owned = owned,
        total = total,
        tokens = SafeNumber(collection.currency and collection.currency.tokens, 0),
        emblems = SafeNumber(collection.currency and collection.currency.emblems, 0),
    }
end

local function GetWishlistDisplayName(collection, wish)
    if type(wish) ~= "table" then
        return "Unknown target"
    end

    local collectionType = wish.type or wish.collection_type or "unknown"
    local itemId = wish.itemId or wish.entryId or wish.item_id
    local def

    if collection and collection.GetDefinition and itemId then
        def = collection:GetDefinition(collectionType, itemId)
    end

    local name = SafeText((def and def.name) or wish.name,
        itemId and ("#" .. tostring(itemId)) or "Unknown target")
    return string.format("%s | %s", Truncate(name, 36), SafeText(collectionType,
        "target"))
end

local function CreateActionButton(parent)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:Hide()
    button.action = nil

    button:SetScript("OnClick", function(self)
        if type(self.action) == "function" then
            self.action()
        end
    end)

    return button
end

local function SetActionButton(button, config)
    if not button then
        return
    end

    if type(config) ~= "table" or type(config.onClick) ~= "function" then
        button.action = nil
        button:Hide()
        return
    end

    button:SetText(config.text or "Open")
    button.action = config.onClick

    if config.enabled == false then
        button:Disable()
        button:SetAlpha(0.45)
    else
        button:Enable()
        button:SetAlpha(1)
    end

    button:Show()
end

local function CreateDashboardCard(parent, width, accentColor)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, CARD_HEIGHT)

    card.bg = CreateBackground(card, "BACKGROUND", 0.07, 0.08, 0.11, 0.92)

    local accent = card:CreateTexture(nil, "BORDER")
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetTexture(accentColor[1], accentColor[2], accentColor[3], 1)
    card.accent = accent

    local headerLine = card:CreateTexture(nil, "BORDER")
    headerLine:SetPoint("TOPLEFT", 8, -1)
    headerLine:SetPoint("TOPRIGHT", -8, -1)
    headerLine:SetHeight(1)
    headerLine:SetTexture(1, 1, 1, 0.08)

    local title = CreateFontString(card, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetWidth(width - 28)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 0.82, 0)
    card.title = title

    local body = CreateFontString(card, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 14, -30)
    body:SetWidth(width - 28)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    card.body = body

    card.secondaryButton = CreateActionButton(card)
    card.secondaryButton:SetPoint("BOTTOMRIGHT", -124, 10)

    card.primaryButton = CreateActionButton(card)
    card.primaryButton:SetPoint("BOTTOMRIGHT", -10, 10)

    function card:SetCardData(data)
        self.title:SetText(data.title or "")
        self.body:SetText(JoinLines(data.lines))
        SetActionButton(self.primaryButton, data.primary)
        SetActionButton(self.secondaryButton, data.secondary)
    end

    return card
end

local function BuildVaultSummary(data)
    if data.nextThreshold and data.keysNeeded then
        return string.format(
            "Next unlock: |cff00ff00%d more|r run%s for the %d-key vault tier.",
            data.keysNeeded,
            data.keysNeeded == 1 and "" or "s",
            data.nextThreshold)
    end

    return "All vault tiers unlocked for this reset."
end

local function BuildDirectorCue()
    local keys = BuildKeystoneData()
    local season = GetSeasonInfo()
    local hotspots = BuildHotspotEntries() or {}
    local bosses = BuildWorldBossEntries() or {}
    local hlbg = BuildHLBGData()

    if keys.keysNeeded and keys.keysNeeded > 0 then
        return string.format(
            "Director Cue: finish %d more key%s to advance your weekly vault.",
            keys.keysNeeded,
            keys.keysNeeded == 1 and "" or "s")
    end

    if SafeNumber(season.weeklyCap, 0) > 0 and
        SafeNumber(season.weeklyTokens, 0) < SafeNumber(season.weeklyCap, 0) then
        return string.format(
            "Director Cue: %d weekly season token%s still fit before reset.",
            math.max(0, season.weeklyCap - season.weeklyTokens),
            math.max(0, season.weeklyCap - season.weeklyTokens) == 1 and
                "" or "s")
    end

    if #hotspots > 0 then
        return string.format(
            "Director Cue: hotspot farming is live in %s for %s.",
            hotspots[1].zone,
            FormatDuration(hotspots[1].remaining))
    end

    if #bosses > 0 then
        local boss = bosses[1]
        if boss.active then
            return string.format(
                "Director Cue: %s is active in %s right now.",
                boss.name,
                boss.zone)
        end

        return string.format(
            "Director Cue: %s opens in %s.",
            boss.name,
            FormatDuration(boss.spawnIn))
    end

    if hlbg and hlbg.inQueue then
        return string.format(
            "Director Cue: stay queued for HLBG, estimated wait %s.",
            FormatDuration(hlbg.waitSeconds))
    end

    return "Director Cue: use this tab as the weekly handoff for keys, " ..
        "spawns, PvP, group finding, and target hunting."
end

local function BuildKeysCard()
    local data = BuildKeystoneData()
    local keystone = data.keystone or {}
    local hasKey = keystone.hasKey or SafeNumber(keystone.level, 0) > 0
    local keyName = SafeText(keystone.dungeonAbbrev or keystone.dungeonName,
        "No key synced")

    local lines = {
        string.format(
            "Key: %s | Rating: |cff00ff00%s|r",
            hasKey and ("|cffffaa33+" .. SafeNumber(keystone.level, 0) ..
                "|r " .. Truncate(keyName, 20)) or "No keystone detected",
            SafeText(data.rating, "---")),
        string.format(
            "Weekly keys: |cff00ff00%d|r | Vault slots: |cffffff00%d/3|r",
            data.keysThisWeek,
            data.vaultSlots),
        BuildVaultSummary(data),
        data.affixes and ("Affixes: " .. Truncate(data.affixes, 56)) or
            "Affixes: open Mythic+ or Info Bar once to cache this week's set.",
    }

    return {
        title = "Keys & Vault",
        lines = lines,
        primary = {
            text = "Group Finder",
            onClick = OpenGroupFinder,
            enabled = (SlashCmdList and SlashCmdList["DCGF"] ~= nil) or
                (rawget(_G, "DCMythicPlusHUD") and
                rawget(_G, "DCMythicPlusHUD").GroupFinder ~= nil),
        },
        secondary = {
            text = "Great Vault",
            onClick = OpenGreatVault,
            enabled = (SlashCmdList and SlashCmdList["DCM"] ~= nil) or
                (rawget(_G, "DCMythicPlusHUD") and
                rawget(_G, "DCMythicPlusHUD").GreatVault ~= nil),
        },
    }
end

local function BuildSeasonCard()
    local season = GetSeasonInfo()
    local progress = GetProgress()
    local seasonName = SafeText(
        season.name or (DCWelcome.GetCurrentSeason and
        (DCWelcome:GetCurrentSeason() or {}).name),
        "Unknown season")

    local lines = {
        string.format(
            "%s | Rank: |cff00ff00%s|r | Points: |cffffff00%s|r",
            Truncate(seasonName, 22),
            SafeText(progress.seasonRank, "Unranked"),
            SafeText(progress.seasonPoints, "0")),
        string.format(
            "Weekly tokens: |cff00ff00%d/%d|r | Essence: |cff00ccff%d/%d|r",
            SafeNumber(season.weeklyTokens, 0),
            SafeNumber(season.weeklyCap, 0),
            SafeNumber(season.weeklyEssence, 0),
            SafeNumber(season.essenceCap, 0)),
        string.format(
            "Weekly reset: |cffffff00%s|r | Season end: |cffffff00%s|r",
            SafeNumber(season.weeklyReset, 0) > 0 and
                FormatDuration(season.weeklyReset) or "Unknown",
            SafeNumber(season.endsIn, 0) > 0 and
                FormatDuration(season.endsIn) or "Unknown"),
        "Tracker, leaderboards, and vault pacing all anchor off this reset.",
    }

    return {
        title = "Seasonal Tasks",
        lines = lines,
        primary = {
            text = "Tracker",
            onClick = ToggleSeasonTracker,
            enabled = true,
        },
        secondary = {
            text = "Boards",
            onClick = function() OpenLeaderboards("seasons") end,
            enabled = true,
        },
    }
end

local function BuildHotspotCard()
    local hotspots = BuildHotspotEntries()
    if not hotspots then
        return {
            title = "Hotspot Timers",
            lines = {
                "DC-Mapupgrades is not loaded, so hotspot windows are unavailable.",
                "Install the addon from the Addons tab to surface live zone timers.",
                "Hotspots sync from cached server snapshots and zone-change refreshes.",
                "Once loaded, this card shows the earliest-expiring farm windows.",
            },
            primary = {
                text = "Addons Hub",
                onClick = OpenAddonsHub,
                enabled = true,
            },
        }
    end

    local lines = {}
    for index = 1, math.min(3, #hotspots) do
        local entry = hotspots[index]
        local bonusText = entry.bonus > 0 and ("+" .. entry.bonus .. "%") or "+XP"
        table.insert(lines, string.format(
            "%s | %s | %s left",
            Truncate(entry.zone, 24),
            bonusText,
            FormatDuration(entry.remaining)))
    end

    if #lines == 0 then
        lines = {
            "No active hotspots are cached right now.",
            "Map Upgrades fills this cache on login, zone change, and world sync.",
            "Open the hotspot list if you want to force a visual check in-game.",
            "The next active rotation appears here once the cache is refreshed.",
        }
    elseif #hotspots > 3 then
        table.insert(lines,
            string.format("%d more hotspot window%s are active.",
            #hotspots - 3,
            (#hotspots - 3) == 1 and "" or "s"))
    else
        table.insert(lines,
            "Hotspots are cached from the live world snapshot while the addon is active.")
    end

    return {
        title = "Hotspot Timers",
        lines = lines,
        primary = {
            text = "Hotspots",
            onClick = OpenHotspotList,
            enabled = (SlashCmdList and SlashCmdList["DCHOTSPOT"] ~= nil),
        },
        secondary = {
            text = "Options",
            onClick = OpenHotspotOptions,
            enabled = (SlashCmdList and SlashCmdList["DCHOTSPOT"] ~= nil),
        },
    }
end

local function BuildWorldCard()
    local bosses = BuildWorldBossEntries() or {}
    local rares = BuildRareEntries() or {}
    local hasWorldSource = (#bosses > 0) or (#rares > 0)

    if not hasWorldSource then
        return {
            title = "Boss Windows & Rares",
            lines = {
                "No world boss or rare cache is available yet.",
                "DC-InfoBar provides spawn windows, while Map Upgrades tracks rare states.",
                "Install both if you want this tab to surface active windows automatically.",
                "Once synced, this card prioritizes active bosses and fresh rare sightings.",
            },
            primary = {
                text = "Addons Hub",
                onClick = OpenAddonsHub,
                enabled = true,
            },
        }
    end

    local lines = {}
    local lineCount = 0

    for index = 1, math.min(2, #bosses) do
        local boss = bosses[index]
        lineCount = lineCount + 1
        if boss.active then
            local hpText = boss.hp and string.format(" | HP %d%%", boss.hp) or ""
            table.insert(lines, string.format(
                "Boss: %s | Active in %s%s",
                Truncate(boss.name, 18),
                Truncate(boss.zone, 16),
                hpText))
        else
            table.insert(lines, string.format(
                "Boss: %s | %s in %s",
                Truncate(boss.name, 18),
                boss.status == "spawning" and "Spawn" or "Window",
                FormatDuration(boss.spawnIn)))
        end
    end

    for index = 1, math.min(2, #rares) do
        if lineCount >= 4 then
            break
        end

        local rare = rares[index]
        lineCount = lineCount + 1
        if rare.isActive then
            table.insert(lines, string.format(
                "Rare: %s | Active in %s for %s",
                Truncate(rare.name, 18),
                Truncate(rare.zone, 14),
                FormatEpochRemaining(rare.activeUntil)))
        elseif rare.lastKilled > 0 then
            table.insert(lines, string.format(
                "Rare: %s | Last killed %s ago",
                Truncate(rare.name, 18),
                FormatDuration(time() - rare.lastKilled)))
        else
            table.insert(lines, string.format(
                "Rare: %s | No live state cached yet",
                Truncate(rare.name, 18)))
        end
    end

    while #lines < 4 do
        table.insert(lines,
            "World cache stays freshest when DC-InfoBar and Map Upgrades are running.")
    end

    return {
        title = "Boss Windows & Rares",
        lines = lines,
        primary = {
            text = "Hotspots",
            onClick = OpenHotspotList,
            enabled = (SlashCmdList and SlashCmdList["DCHOTSPOT"] ~= nil),
        },
        secondary = {
            text = "Info Bar",
            onClick = ToggleInfoBar,
            enabled = (SlashCmdList and SlashCmdList["DCINFOBAR"] ~= nil) or
                (rawget(_G, "DCInfoBar") and rawget(_G, "DCInfoBar").bar ~= nil),
        },
    }
end

local function BuildHLBGCard()
    local data = BuildHLBGData()
    if not data then
        return {
            title = "HLBG Status",
            lines = {
                "DC-HinterlandBG is not loaded, so queue and match status are hidden.",
                "Install it from the Addons tab to surface queue pressure and live match data.",
                "When installed, this card shows queue length, affixes, and match time left.",
                "Use it to spot PvP windows without leaving the welcome hub.",
            },
            primary = {
                text = "Addons Hub",
                onClick = OpenAddonsHub,
                enabled = true,
            },
        }
    end

    local stateText = data.state
    if data.inQueue then
        stateText = "QUEUED"
    end

    local lines = {
        string.format(
            "State: |cffffff00%s|r | Queue: |cff00ff00%d/%d|r",
            stateText,
            data.queuePosition,
            data.queueTotal),
        string.format(
            "Wait: %s | Alliance/Horde queued: %d/%d",
            data.waitSeconds > 0 and FormatDuration(data.waitSeconds) or "Instant",
            data.allianceQueued,
            data.hordeQueued),
        string.format(
            "Min to start: %d | Match clock: %s",
            data.minPlayers,
            data.timeLeft > 0 and FormatDuration(data.timeLeft) or "Idle"),
        "Affix: " .. Truncate(data.affixText, 54),
    }

    return {
        title = "HLBG Status",
        lines = lines,
        primary = {
            text = "Open HLBG",
            onClick = OpenHLBG,
            enabled = (SlashCmdList and SlashCmdList["HLBGSHOW"] ~= nil),
        },
        secondary = {
            text = "Boards",
            onClick = OpenHLBGLeaderboards,
            enabled = true,
        },
    }
end

local function BuildGroupFinderCard()
    local data = BuildGroupFinderData()
    if not data.hasAddon then
        return {
            title = "Group Finder Opportunities",
            lines = {
                "Mythic+ Group Finder is not loaded, so live listing context is unavailable.",
                "Install the Mythic+ suite from the Addons tab to browse runs and schedule groups.",
                "Once loaded, this card highlights listing, application, and live-run context.",
                "It pairs best with a synced keystone and weekly affix snapshot.",
            },
            primary = {
                text = "Addons Hub",
                onClick = OpenAddonsHub,
                enabled = true,
            },
        }
    end

    local lines = {
        data.hasKey and string.format(
            "Your key is ready: build around |cffffaa33+%d|r %s.",
            data.keyLevel,
            Truncate(data.keyName, 20)) or
            "No keystone is synced yet. Browse other listings or world groups.",
        string.format(
            "Listings: |cff00ff00%d|r | Live runs: |cff00ccff%d|r",
            data.listings,
            data.liveRuns),
        string.format(
            "Scheduled events: |cffffff00%d|r | My applications: |cffffff00%d|r",
            data.scheduled,
            data.applications),
        "Open the browser for Mythic, raid, quest, world, and spectate opportunities.",
    }

    return {
        title = "Group Finder Opportunities",
        lines = lines,
        primary = {
            text = "Open Finder",
            onClick = OpenGroupFinder,
            enabled = true,
        },
        secondary = {
            text = "Mythic HUD",
            onClick = OpenMythicHud,
            enabled = (SlashCmdList and SlashCmdList["DCM"] ~= nil),
        },
    }
end

local function BuildWishlistCard()
    local data = BuildWishlistData()
    if not data then
        return {
            title = "Wishlist Targets",
            lines = {
                "DC-Collection is not loaded, so wishlist targets are unavailable.",
                "Install it from the Addons tab to track mounts, pets, heirlooms, titles, and transmog.",
                "Once loaded, this card surfaces your account-wide target list in the welcome hub.",
                "Recent unlocks and collection progress also feed back into this section.",
            },
            primary = {
                text = "Addons Hub",
                onClick = OpenAddonsHub,
                enabled = true,
            },
        }
    end

    local lines = {
        string.format(
            "Collection progress: |cff00ff00%d/%d|r | Tokens: |cffffff00%d|r | Emblems: |cffffff00%d|r",
            data.owned,
            data.total,
            data.tokens,
            data.emblems),
    }

    if #data.wishlist == 0 then
        table.insert(lines,
            "No wishlist targets yet. Add items from DC-Collection and they will appear here.")
    else
        for index = 1, math.min(3, #data.wishlist) do
            table.insert(lines,
                GetWishlistDisplayName(data.collection, data.wishlist[index]))
        end
    end

    if #lines < 4 then
        if #data.recent > 0 then
            table.insert(lines,
                string.format("Recent unlocks cached: %d", #data.recent))
        else
            table.insert(lines,
                "Wishlist alerts and zone hints continue to run inside DC-Collection.")
        end
    end

    while #lines < 4 do
        table.insert(lines,
            "Use the wishlist UI to turn long-term farm goals into a short review loop.")
    end

    return {
        title = "Wishlist Targets",
        lines = lines,
        primary = {
            text = "Wishlist",
            onClick = OpenWishlist,
            enabled = true,
        },
        secondary = {
            text = "Collections",
            onClick = OpenCollections,
            enabled = true,
        },
    }
end

function Director:Refresh(forceNetwork)
    if forceNetwork then
        RequestFreshData()
    end

    if not self.scrollChild or not self.cards then
        return
    end

    self.cueText:SetText(BuildDirectorCue())

    self.cards.keys:SetCardData(BuildKeysCard())
    self.cards.season:SetCardData(BuildSeasonCard())
    self.cards.hotspots:SetCardData(BuildHotspotCard())
    self.cards.world:SetCardData(BuildWorldCard())
    self.cards.hlbg:SetCardData(BuildHLBGCard())
    self.cards.groupfinder:SetCardData(BuildGroupFinderCard())
    self.cards.wishlist:SetCardData(BuildWishlistCard())
end

function DCWelcome:RefreshEndgameDirector(forceNetwork)
    Director:Refresh(forceNetwork)
end

function DCWelcome:PopulateEndgameDirectorPanel(scrollChild)
    if not scrollChild or scrollChild._endgameDirectorBuilt then
        if scrollChild then
            Director.scrollChild = scrollChild
            Director:Refresh(false)
        end
        return
    end

    scrollChild._endgameDirectorBuilt = true
    Director.scrollChild = scrollChild

    local width = math.max(520, SafeNumber(scrollChild:GetWidth(), 0) - 20)
    local yOffset = -10

    local header = CreateFrame("Frame", nil, scrollChild)
    header:SetSize(width, HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", CARD_INSET, yOffset)
    Director.header = header

    local title = CreateFontString(header, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetWidth(width - 110)
    title:SetJustifyH("LEFT")
    title:SetText("|cffffd700Endgame Director|r")

    local subtitle = CreateFontString(header, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetWidth(width - 110)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(
        "One pass over keys, resets, world windows, PvP pressure, and wishlist goals.")

    local cueText = CreateFontString(header, "OVERLAY", "GameFontHighlightSmall")
    cueText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
    cueText:SetWidth(width - 110)
    cueText:SetJustifyH("LEFT")
    cueText:SetText("Director Cue: loading live endgame context...")
    Director.cueText = cueText

    local refreshButton = CreateFrame("Button", nil, header,
        "UIPanelButtonTemplate")
    refreshButton:SetSize(96, 24)
    refreshButton:SetPoint("TOPRIGHT", 0, -2)
    refreshButton:SetText("Refresh")
    refreshButton:SetScript("OnClick", function()
        Director:Refresh(true)
    end)

    yOffset = yOffset - HEADER_HEIGHT - CARD_SPACING

    Director.cards = {
        keys = CreateDashboardCard(scrollChild, width, { 1.0, 0.56, 0.10 }),
        season = CreateDashboardCard(scrollChild, width, { 1.0, 0.82, 0.00 }),
        hotspots = CreateDashboardCard(scrollChild, width, { 0.10, 0.74, 1.00 }),
        world = CreateDashboardCard(scrollChild, width, { 0.85, 0.25, 0.20 }),
        hlbg = CreateDashboardCard(scrollChild, width, { 0.90, 0.12, 0.12 }),
        groupfinder = CreateDashboardCard(scrollChild, width, { 0.48, 0.78, 1.00 }),
        wishlist = CreateDashboardCard(scrollChild, width, { 0.20, 0.82, 0.36 }),
    }

    local order = {
        Director.cards.keys,
        Director.cards.season,
        Director.cards.hotspots,
        Director.cards.world,
        Director.cards.hlbg,
        Director.cards.groupfinder,
        Director.cards.wishlist,
    }

    for _, card in ipairs(order) do
        card:SetPoint("TOPLEFT", CARD_INSET, yOffset)
        yOffset = yOffset - CARD_HEIGHT - CARD_SPACING
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
    scrollChild._endgameElapsed = 0
    scrollChild:SetScript("OnShow", function()
        Director:Refresh(false)
    end)
    scrollChild:SetScript("OnUpdate", function(self, elapsed)
        self._endgameElapsed = (self._endgameElapsed or 0) + elapsed
        if self._endgameElapsed >= REFRESH_INTERVAL then
            self._endgameElapsed = 0
            Director:Refresh(false)
        end
    end)

    Director:Refresh(true)
end