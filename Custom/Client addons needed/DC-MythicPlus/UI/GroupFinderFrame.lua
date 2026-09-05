-- DC-MythicPlus/UI/GroupFinderFrame.lua
-- Main Group Finder window using the compact Blizzard LFG-style shell.

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.GroupFinder = namespace.GroupFinder or {}
local GF = namespace.GroupFinder

-- =====================================================================
-- Constants
-- =====================================================================

GF.FRAME_WIDTH = 563
GF.FRAME_HEIGHT = 512
GF.CATEGORY_CONFIG = {
    mythic = { category = "dungeon", listingType = 1, title = "Mythic+" },
    raid = { category = "raid", listingType = 2, title = "Raid" },
    pvp = { category = "pvp", listingType = 3, title = "PvP" },
    quest = { category = "quest", listingType = 5, title = "Questing" },
    other = { category = "other", listingType = 4, title = "Other" },
}

GF.COMPACT_OPTION_ORDER = {
    "dungeons", "mythic", "raid", "hlbg", "quest", "other", "live", "queues", "blizzardLFG", "blizzardPVP"
}

GF.PREMADE_CATEGORY_ORDER = {
    "quest", "mythic", "raid", "hlbg", "live", "queues", "other"
}

GF.COMPACT_OPTIONS = {
    dungeons = { label = "Specific Dungeons", title = "Dungeon Finder", typeText = "Specific Dungeons", actionText = "Find Group" },
    mythic = { label = "Mythic+", title = "Dungeon Finder", typeText = "Mythic+ Dungeons", actionText = "Find Group", create = true },
    raid = { label = "Raid Finder", title = "Raid Finder", typeText = "Specific Raids", actionText = "Find Group", create = true },
    quest = { label = "Questing", title = "Questing", typeText = "Questing Groups", actionText = "Find a Group", create = true },
    other = { label = "Custom", title = "Custom", typeText = "Custom Groups", actionText = "Find a Group", create = true },
    live = { label = "Live Runs", title = "Live Runs", typeText = "Spectatable Runs", actionText = "Refresh" },
    queues = { label = "My Queues", title = "My Queues", typeText = "Applications", actionText = "Refresh" },
    hlbg = { label = "Hinterland BG", title = "Battleground Finder", typeText = "Hinterland BG", actionText = "Join Queue" },
    blizzardLFG = { label = "Blizzard LFG", title = "Dungeon Finder", typeText = "Stock LFG/LFM", actionText = "Open" },
    blizzardPVP = { label = "Blizzard PvP", title = "PvP", typeText = "Battlegrounds", actionText = "Open" },
}

-- Type menu contents per left-nav section. The Dungeon Finder and Raid Finder
-- navs only offer their own content; Premade Groups keeps the full catalog.
GF.TYPE_MENU_BY_CONTEXT = {
    dungeon = { "dungeons", "mythic", "blizzardLFG" },
    raid = { "raid" },
    premade = {
        "mythic", "raid", "hlbg", "quest", "other", "live", "queues",
        "blizzardLFG", "blizzardPVP"
    },
}

-- Dungeon matchmaking difficulty (server Difficulty enum: 0/1/2 where 2 is
-- DUNGEON_DIFFICULTY_EPIC = Mythic on this core). The "Specific Dungeons"
-- type queues Normal/Heroic; the "Mythic+" type is locked to Mythic.
GF.DUNGEON_DIFFICULTY_LABELS = { [0] = "Normal", [1] = "Heroic", [2] = "Mythic" }
GF.queueDungeonDifficulty = 0

local LFG_ROLE_TEXTURE = "Interface\\LFGFrame\\LFGRole"
local LFG_PORTRAIT_TEXTURE = "Interface\\LFGFrame\\UI-LFG-PORTRAIT"

-- ---------------------------------------------------------------------------
-- LFG list icons (Interface\LFGFrame\lfgicon-<key>.blp), shipped in patch MPQ.
-- Blizzard's internal art keys do NOT always match the instance display name
-- (Utgarde Keep -> "utgarde", The Culling of Stratholme -> "oldstratholme",
-- Trial of the Champion -> "argentdungeon", Zul'Farrak -> "zulfarak"), so the
-- mapping is resolved explicitly by Map.dbc id. Several wings share one icon
-- (Hellfire 5-mans, Coilfang, Auchindoun, Tempest Keep, Caverns of Time).
-- ---------------------------------------------------------------------------
local LFG_ICON_PATH = "Interface\\LFGFrame\\lfgicon-"

local LFG_ICON_BY_MAP = {
    -- Classic dungeons
    [389] = "ragefirechasm", [43]  = "wailingcaverns",  [34]  = "stormwindstockades",
    [36]  = "deadmines",     [33]  = "shadowfangkeep",  [48]  = "blackfathomdeeps",
    [90]  = "gnomeregan",    [47]  = "razorfenkraul",   [189] = "scarletmonastery",
    [129] = "razorfendowns", [209] = "zulfarak",        [70]  = "uldaman",
    [109] = "sunkentemple",  [229] = "blackrockspire",  [230] = "blackrockdepths",
    [349] = "maraudon",      [289] = "scholomance",     [329] = "stratholme",
    [429] = "diremaul",
    -- Classic raids
    [409] = "moltencore",    [469] = "blackwinglair",   [309] = "zulgurub",
    [509] = "aqruins",       [531] = "aqtemple",
    -- TBC dungeons
    [540] = "hellfirecitadel5man", [542] = "hellfirecitadel5man", [543] = "hellfirecitadel5man",
    [545] = "coilfang",            [546] = "coilfang",            [547] = "coilfang",
    [552] = "tempestkeep",         [553] = "tempestkeep",         [554] = "tempestkeep",
    [555] = "auchindoun",          [556] = "auchindoun",          [557] = "auchindoun",
    [558] = "auchindoun",          [269] = "cavernsoftime",       [560] = "cavernsoftime",
    [585] = "magistersterrace",
    -- TBC raids
    [532] = "karazhan",            [534] = "hyjalpast",           [544] = "hellfirecitadelraid",
    [548] = "serpentshrinecavern", [550] = "tempestkeep",         [564] = "blacktemple",
    [565] = "gruulslair",          [568] = "zulaman",             [580] = "sunwell",
    -- WotLK dungeons
    [574] = "utgarde",          [575] = "utgardepinnacle",  [576] = "thenexus",
    [578] = "theoculus",        [595] = "oldstratholme",    [599] = "hallsofstone",
    [600] = "draktharon",       [601] = "azjolnerub",       [602] = "hallsoflightning",
    [604] = "gundrak",          [608] = "theviolethold",    [619] = "ahnkahet",
    [632] = "theforgeofsouls",  [650] = "argentdungeon",    [658] = "pitofsaron",
    [668] = "hallsofreflection",
    -- WotLK raids
    [249] = "onyxiaencounter",  [533] = "naxxramas",        [603] = "ulduarraid",
    [615] = "chamberofaspects", [616] = "malygos",          [624] = "vaultofarchavon",
    [631] = "icecrowncitadel",  [649] = "argentraid",       [724] = "chamberofaspects",
}

-- Derive a best-effort icon key from a display name for instances not in the
-- table above. Non-existent files are skipped safely by ApplyTextureCandidates.
local function NormalizeLFGKey(name)
    if type(name) ~= "string" then return nil end
    local key = name:lower():gsub("^the%s+", ""):gsub("[^a-z0-9]", "")
    if key == "" then return nil end
    return key
end

-- Build LFG list-icon candidates for an instance descriptor (mapId, name, or a
-- row table). isRaid selects the generic fallback; includeGeneric appends the
-- catch-all lfgicon-dungeon/raid. Reusable from any UI that wants these icons.
function namespace.ResolveLFGIconCandidates(descriptor, isRaid, includeGeneric)
    local out = {}
    local mapId, name
    if type(descriptor) == "number" then
        mapId = descriptor
    elseif type(descriptor) == "string" then
        name = descriptor
    elseif type(descriptor) == "table" then
        mapId = descriptor.mapId or descriptor.queueMapId or descriptor.dungeonId
        name = descriptor.dungeonName or descriptor.name
    end

    if mapId and LFG_ICON_BY_MAP[mapId] then
        table.insert(out, LFG_ICON_PATH .. LFG_ICON_BY_MAP[mapId])
    end
    local key = NormalizeLFGKey(name)
    if key then
        table.insert(out, LFG_ICON_PATH .. key)
    end
    if includeGeneric then
        table.insert(out, LFG_ICON_PATH .. (isRaid and "raid" or "dungeon"))
    end
    return out
end
local RETAIL_TEXTURE_ROOT = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Retail\\"
local RETAIL_BLUE_MENU_RING = RETAIL_TEXTURE_ROOT .. "bluemenuring_335.tga"
-- bluemenuring_335 = retail Interface/Common/BlueMenuRing (128x128); the ring
-- art occupies the {1..103, 1..104} region (atlas member "bluemenu-Ring").
local BLUEMENU_RING_COORDS = { 0.0078125, 0.804688, 0.0078125, 0.8125 }
-- The retail bluemenu-main atlas (256x1024). Texcoords below are the exact
-- regions from retail PVEFrame.xml/PVEFrame.lua (the _335 rip is a straight
-- copy of the retail file, so the coords apply verbatim).
local RETAIL_BLUEMENU_MAIN = RETAIL_TEXTURE_ROOT .. "bluemenu-main_335.tga"
local BLUEMENU_BG_COORDS = { 0.00390625, 0.82421875, 0.18554688, 0.58984375 }
local BLUEMENU_BUTTON_COORDS = {
    normal   = { 0.00390625, 0.87890625, 0.75195313, 0.83007813 },
    selected = { 0.00390625, 0.87890625, 0.59179688, 0.66992188 },
    disabled = { 0.00390625, 0.87890625, 0.67187500, 0.75000000 },
}
local BLUEMENU_CORNER_COORDS = {
    tl = { 0.00390625, 0.25390625, 0.00097656, 0.06347656 },
    tr = { 0.51953125, 0.76953125, 0.00097656, 0.06347656 },
    br = { 0.00390625, 0.25390625, 0.06542969, 0.12792969 },
    bl = { 0.26171875, 0.51171875, 0.00097656, 0.06347656 },
}

-- ---------------------------------------------------------------------------
-- Retail Group Finder art, repacked into ONE 1024x1024 sheet. The straight
-- 2048px rips of the retail atlas files CRASH the 3.3.5a client (its UI
-- texture decoder is only safe up to 1024px — every other addon texture on
-- this server respects that), so the members the addon uses were cropped out
-- of Interface/LFGFrame/GroupFinder + UILFGPrompts and shelf-packed. Rects
-- are PIXEL coords in the packed sheet: { left, right, top, bottom }.
-- (Repack script: scratchpad repack_gf_atlas.py; sources: retail 11.2.7
-- AtlasInfo.lua member coords.)
-- ---------------------------------------------------------------------------
local GF_ATLAS = RETAIL_TEXTURE_ROOT .. "dc_groupfinder_atlas_335.tga"
local GF_ATLAS_W, GF_ATLAS_H = 1024, 1024
local GF_ATLAS_RECTS = {
    ["background"] = { 2, 330, 2, 338 },
    ["button-arenas"] = { 296, 586, 646, 682 },
    ["button-battlegrounds"] = { 588, 878, 646, 682 },
    ["button-cover"] = { 2, 302, 598, 644 },
    ["button-cover-down"] = { 304, 604, 598, 644 },
    ["button-custom-pve"] = { 2, 292, 685, 721 },
    ["button-custom-pvp"] = { 294, 584, 685, 721 },
    ["button-dungeons"] = { 586, 876, 685, 721 },
    ["button-highlight"] = { 606, 898, 598, 635 },
    ["button-questing"] = { 2, 292, 723, 759 },
    ["button-raids"] = { 294, 584, 723, 759 },
    ["button-scenarios"] = { 586, 876, 723, 759 },
    ["button-select"] = { 2, 294, 646, 683 },
    ["divider"] = { 308, 676, 761, 765 },
    ["dps-micro"] = { 752, 813, 340, 401 },
    ["eye-highlight"] = { 664, 750, 340, 426 },
    ["healer-micro"] = { 815, 876, 340, 401 },
    ["highlightbar-blue"] = { 2, 306, 761, 793 },
    ["pendingmark"] = { 260, 460, 340, 540 },
    ["readymark"] = { 462, 662, 340, 540 },
    ["role-dps"] = { 332, 588, 2, 258 },
    ["role-healer"] = { 590, 846, 2, 258 },
    ["role-tank"] = { 2, 258, 340, 596 },
    ["tank-micro"] = { 878, 939, 340, 401 },
}

-- Apply an atlas member to a texture (path + texcoords).
local function SetGFAtlas(texture, key)
    if not texture then return false end
    local r = GF_ATLAS_RECTS[key]
    if not r then return false end
    texture:SetTexture(GF_ATLAS)
    texture:SetTexCoord(r[1] / GF_ATLAS_W, r[2] / GF_ATLAS_W,
        r[3] / GF_ATLAS_H, r[4] / GF_ATLAS_H)
    return texture:GetTexture() ~= nil
end
namespace.SetGFAtlas = SetGFAtlas

-- Inline |T...|t escape for an atlas member (for FontStrings, e.g. role
-- glyphs in list rows). Pixel-coord form of the texture escape.
local function GFAtlasEscape(key, size)
    local r = GF_ATLAS_RECTS[key]
    if not r then return "" end
    size = size or 14
    return string.format("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t",
        GF_ATLAS, size, size, GF_ATLAS_W, GF_ATLAS_H, r[1], r[2], r[3], r[4])
end
namespace.GFAtlasEscape = GFAtlasEscape

local RETAIL_LFG_ROLE_TEXTURES = {
    tank = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Tank.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Tank-Disabled.tga",
    },
    healer = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Healer.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Healer-Disabled.tga",
    },
    dps = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-DPS.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-DPS-Disabled.tga",
    },
    leader = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Leader.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Leader-Disabled.tga",
    },
}

local function SetTextureOrFallback(texture, primary, fallback)
    if not texture then return end

    local ok = texture:SetTexture(primary)
    if not ok and fallback then
        texture:SetTexture(fallback)
        return false
    end

    return ok and true or false
end

-- Apply the first candidate path that actually resolves to a real texture file.
-- Used for dungeon/raid thumbnails (teleporter art) which vary by dungeon.
local function ApplyTextureCandidates(texture, candidates, fallback)
    if not texture then return false end

    if type(candidates) == "table" then
        for _, path in ipairs(candidates) do
            texture:SetTexture(path)
            if texture:GetTexture() then
                return true
            end
        end
    end

    if fallback then
        texture:SetTexture(fallback)
        return texture:GetTexture() ~= nil
    end

    return false
end

-- Resolve thumbnail art for a group-finder list entry. Order of preference:
--   1. the shipped LFG list icon for the map (patch MPQ, lfgicon-<key>.blp)
--   2. a name-derived LFG icon (covers custom instances not in the table)
--   3. the teleporter art (large landscape shots) for anything still unmatched
--   4. the generic lfgicon-dungeon / lfgicon-raid catch-all
local function GetEntryDungeonArtCandidates(entry)
    if type(entry) ~= "table" then return nil end
    if type(_G.DCMythicPlusHUD) ~= "table" then return nil end

    local combined = {}
    local isRaid = (entry.queueCategory == 2) or entry.isRaid
        or (entry.queueSize ~= nil)

    -- 1 + 2: specific LFG icons (no generic yet, so teleporter art can win).
    if type(namespace.ResolveLFGIconCandidates) == "function" then
        for _, p in ipairs(namespace.ResolveLFGIconCandidates(entry, isRaid, false)) do
            table.insert(combined, p)
        end
    end

    -- 3: teleporter art.
    local resolver = _G.DCMythicPlusHUD.ResolveMythicPlusDungeonArtCandidates
    local descriptor = entry.mapId or entry.dungeonId or entry.dungeon
        or entry.dungeonName or entry.name
    if type(resolver) == "function" and descriptor then
        local art = resolver(descriptor)
        if type(art) == "table" then
            for _, p in ipairs(art) do table.insert(combined, p) end
        elseif type(art) == "string" then
            table.insert(combined, art)
        end
    end

    -- 4: generic per-category fallback.
    table.insert(combined, LFG_ICON_PATH .. (isRaid and "raid" or "dungeon"))

    if #combined == 0 then return nil end
    return combined
end

local function SetSolidTexture(texture, red, green, blue, alpha)
    if not texture then return end

    if texture.SetColorTexture then
        texture:SetColorTexture(red, green, blue, alpha)
    else
        texture:SetTexture(red, green, blue, alpha)
        texture:SetAlpha(alpha or 1)
    end
end

local function SetTextureSlice(texture, primary, coords, fallback)
    if not texture then return end

    SetTextureOrFallback(texture, primary, fallback)
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

-- Row background states, retail LFGList style: hover = blue highlight bar,
-- selected = gold select bar (distinct art per state, like retail).
local function SetRetailBlueMenuBackground(texture, state)
    if not texture then return end

    if state == "selected" then
        if not SetGFAtlas(texture, "button-select") then
            SetSolidTexture(texture, 0.32, 0.25, 0.10, 0.85)
        end
        texture:SetVertexColor(1, 1, 1, 1)
    elseif state == "hover" then
        if not SetGFAtlas(texture, "highlightbar-blue") then
            SetSolidTexture(texture, 0.20, 0.40, 0.60, 0.45)
        end
        texture:SetVertexColor(1, 1, 1, 0.9)
    elseif state == "disabled" then
        texture:SetTexCoord(0, 1, 0, 1)
        SetSolidTexture(texture, 0, 0, 0, 0.2)
        texture:SetVertexColor(1, 1, 1, 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
        SetSolidTexture(texture, 0, 0, 0, 0.35)
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

-- Shared click-feedback helper (3.3.5 PlaySound takes a sound name string).
local function PlayUISound(name)
    if PlaySound then
        pcall(PlaySound, name)
    end
end
namespace.PlayGFSound = PlayUISound

-- ---------------------------------------------------------------------------
-- Retail-styled action button factory: the stone "cover" button art from the
-- retail Group Finder atlas (normal / pushed / additive hover), replacing the
-- WotLK red UIPanelButtonTemplate. Uses the Button's native text support so
-- SetText/GetFontString keep working at every call site.
-- ---------------------------------------------------------------------------
local function CreateRetailActionButton(parent, width, height, label)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 110, height or 24)

    local normal = button:CreateTexture(nil, "BACKGROUND")
    normal:SetAllPoints()
    if not SetGFAtlas(normal, "button-cover") then
        SetSolidTexture(normal, 0.15, 0.13, 0.10, 0.9)
    end
    button:SetNormalTexture(normal)

    local pushed = button:CreateTexture(nil, "BACKGROUND")
    pushed:SetAllPoints()
    if not SetGFAtlas(pushed, "button-cover-down") then
        SetSolidTexture(pushed, 0.10, 0.09, 0.07, 0.9)
    end
    button:SetPushedTexture(pushed)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    SetGFAtlas(highlight, "button-highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.7)
    button:SetHighlightTexture(highlight)

    button:SetNormalFontObject(GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetDisabledFontObject(GameFontDisable)
    if label then
        button:SetText(label)
    end

    button:SetScript("OnMouseDown", function()
        PlayUISound("igMainMenuOptionCheckBoxOn")
    end)

    return button
end
namespace.CreateRetailButton = CreateRetailActionButton

-- Retail PVEFrame nav button states: the bluemenu-main art region swaps
-- between the normal (dark) and selected (blue glow) rows of the atlas;
-- hover is the same art additively blended (native HighlightTexture).
local function UpdateRetailNavButtonArt(button, state)
    if not button then return end

    local isSelected = state == "selected"

    if button.bg and button.bg.SetTexCoord then
        local coords = isSelected and BLUEMENU_BUTTON_COORDS.selected
            or BLUEMENU_BUTTON_COORDS.normal
        button.bg:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end

    if button.text then
        if isSelected then
            button.text:SetTextColor(1, 0.90, 0.24)
        else
            button.text:SetTextColor(1, 0.82, 0)
        end
    end
end

-- Standard self-contained WoW role badges (circular icons with their own
-- background). Using one clean texture per role avoids the layered "icon behind
-- icon" artifact that came from stacking a separate ring texture under the icon.
-- The retail role icons are individual 256x256 (power-of-two) textures with the
-- circular frame baked in and a separate disabled variant, so they load crisply
-- on 3.3.5a. Use the whole texture per role; no slicing/ring needed.
local function ApplyCompactRoleButtonArt(button, checked)
    if not button then return end

    local tex = RETAIL_LFG_ROLE_TEXTURES[button.role]

    if button.icon and tex then
        local ok = SetTextureOrFallback(button.icon,
            checked and tex.enabled or tex.disabled, LFG_ROLE_TEXTURE)
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
        if button.icon.SetDesaturated then
            button.icon:SetDesaturated(false)
        end
        button.icon:SetAlpha(1)
        if not ok then
            -- Fallback only: dim the shared role strip when unselected.
            button.icon:SetAlpha(checked and 1 or 0.6)
        end
    end

    -- Retail icons carry their own frame, so the extra gold ring is hidden.
    if button.ring then
        button.ring:Hide()
    end
end

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\DC\\Shared\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

local function HasCapabilityBit(mask, capability)
    mask = tonumber(mask) or 0
    capability = tonumber(capability) or 0
    if capability <= 0 then return false end

    if bit and bit.band then
        return bit.band(mask, capability) ~= 0
    end

    return (mask % (capability * 2)) >= capability
end

local function GetDCProtocol()
    return rawget(_G, "DCAddonProtocol")
end

local function CopyTableValues(source, target)
    target = target or {}
    if type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        target[key] = value
    end

    return target
end

-- =====================================================================
-- Print Helper
-- =====================================================================

local function Print(selfOrMsg, maybeMsg)
    local text = maybeMsg
    if text == nil then
        text = selfOrMsg
    end

    text = tostring(text or "")

    if GF.SetStatusMessage then
        GF:SetStatusMessage(text)
    end
end
GF.Print = Print

function GF:PrintImportant(msg)
    local text = tostring(msg or "")

    if self.SetStatusMessage then
        self:SetStatusMessage(text)
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffGroup Finder:|r " .. text)
    end
end

function GF:SetStatusMessage(msg)
    self._pendingStatusMessage = tostring(msg or "")

    if not self.mainFrame or not self.mainFrame.StatusText then
        return
    end

    self._statusMessageToken = (self._statusMessageToken or 0) + 1
    local token = self._statusMessageToken

    self.mainFrame.StatusText:SetText(self._pendingStatusMessage)

    if C_Timer and C_Timer.After then
        C_Timer.After(6, function()
            if GF._statusMessageToken == token and GF.mainFrame and GF.mainFrame.StatusText then
                GF.mainFrame.StatusText:SetText("")
            end
        end)
    end
end

local function GetClassRoleCaps()
    local _, classFilename = UnitClass("player")
    local canTank = classFilename == "WARRIOR" or classFilename == "DEATHKNIGHT"
        or classFilename == "PALADIN" or classFilename == "DRUID"
    local canHeal = classFilename == "PRIEST" or classFilename == "SHAMAN"
        or classFilename == "PALADIN" or classFilename == "DRUID"

    return canTank, canHeal, true
end

function GF:GetCompactRoleMask()
    local state = self.compactRoles or { dps = true }
    local roleMask = 0

    if state.tank then roleMask = roleMask + 1 end
    if state.healer then roleMask = roleMask + 2 end
    if state.dps then roleMask = roleMask + 4 end

    return roleMask
end

function GF:GetCompactRoleFilters()
    local state = self.compactRoles or { dps = true }
    return {
        role = self:GetCompactRoleMask(),
        tank = state.tank and 1 or 0,
        healer = state.healer and 1 or 0,
        dps = state.dps and 1 or 0,
        leader = state.leader and 1 or 0,
    }
end

function GF:UpdateCompactRoleButtons()
    local state = self.compactRoles or { dps = true }

    for role, button in pairs(self.compactRoleButtons or {}) do
        local checked = state[role] and true or false
        ApplyCompactRoleButtonArt(button, checked)
    end
end

function GF:GetCategoryConfig(kind)
    return self.CATEGORY_CONFIG[kind]
end

function GF:SearchCustomCategory(kind, filters)
    local config = self:GetCategoryConfig(kind)
    local DC = GetDCProtocol()
    if not config or not DC or not DC.GroupFinder or not DC.GroupFinder.Search then
        return false
    end

    local roleFilters = self:GetCompactRoleFilters()
    local payload = CopyTableValues(filters, {
        category = config.category,
        listingType = config.listingType,
        role = roleFilters.role,
        tank = roleFilters.tank,
        healer = roleFilters.healer,
        dps = roleFilters.dps,
        leader = roleFilters.leader,
    })
    DC.GroupFinder.Search(payload)
    return true
end

function GF:CreateCustomListing(kind, data)
    local config = self:GetCategoryConfig(kind)
    local DC = GetDCProtocol()
    if not config or not DC or not DC.GroupFinder or not DC.GroupFinder.CreateListing then
        return false
    end

    local payload = CopyTableValues(data, {
        category = config.category,
        listingType = config.listingType,
    })

    local roleFilters = self:GetCompactRoleFilters()
    payload.role = payload.role or roleFilters.role
    payload.roles = payload.roles or {
        tank = roleFilters.tank == 1,
        healer = roleFilters.healer == 1,
        dps = roleFilters.dps == 1,
        leader = roleFilters.leader == 1,
    }

    if not payload.dungeonName or payload.dungeonName == "" then
        payload.dungeonName = config.title
    end

    DC.GroupFinder.CreateListing(payload)
    return true
end

function GF:ToggleBlizzardLFG()
    self._allowStockLFG = true

    -- Prefer the saved originals: the live globals are our own redirects.
    if self._originalToggleLFDParentFrame then
        self._originalToggleLFDParentFrame()
        self._allowStockLFG = false
        return true
    end

    if self._originalToggleLFGParentFrame then
        self._originalToggleLFGParentFrame()
        self._allowStockLFG = false
        return true
    end

    if LFDParentFrame then
        if LFDParentFrame:IsShown() then
            HideUIPanel(LFDParentFrame)
        else
            ShowUIPanel(LFDParentFrame)
        end
        self._allowStockLFG = false
        return true
    end

    if ToggleLFDParentFrame then
        ToggleLFDParentFrame()
        self._allowStockLFG = false
        return true
    end

    self._allowStockLFG = false
    return false
end

function GF:ToggleBlizzardPVP()
    if PVPParentFrame then
        if PVPParentFrame:IsShown() then
            HideUIPanel(PVPParentFrame)
        else
            ShowUIPanel(PVPParentFrame)
        end
        return true
    end

    if TogglePVPFrame then
        TogglePVPFrame()
        return true
    end

    return false
end

function GF:JoinHinterlandQueue(joinAsGroup)
    local HLBG = rawget(_G, "HLBG")
    if HLBG and type(HLBG.TryJoinViaBlizzardQueue) == "function"
        and HLBG.TryJoinViaBlizzardQueue(joinAsGroup and true or false) then
        return true
    end

    if HLBG and type(HLBG.JoinQueue) == "function" then
        HLBG.JoinQueue()
        return true
    end

    -- DC-HinterlandBG not loaded: fall back to the protocol quick-queue.
    local DC = GetDCProtocol()
    if DC and DC.Hinterland and DC.Hinterland.QuickQueue then
        DC.Hinterland.QuickQueue()
        return true
    end

    return false
end

function GF:GetBlizzardSideStatus()
    local DC = GetDCProtocol()
    local capabilities = 0
    if DC and type(DC.GetClientCapabilities) == "function" then
        local ok, value = pcall(DC.GetClientCapabilities, DC)
        if ok then
            capabilities = tonumber(value) or 0
        end
    end

    local genericEnvelopeCap = DC and DC.Capability
        and DC.Capability.GENERIC_NATIVE_ENVELOPE or 0x00100000

    return {
        legacyLFG = type(GetLookingForGroup) == "function"
            and type(GetNumLFGResults) == "function",
        legacyLFM = type(SetLookingForMore) == "function"
            or type(ClearLookingForMore) == "function",
        pvpQueue = type(GetBattlegroundInfo) == "function"
            and type(JoinBattlefield) == "function",
        nativeEnvelope = HasCapabilityBit(capabilities, genericEnvelopeCap),
        hinterlandBG = rawget(_G, "HLBG") ~= nil,
    }
end

local function NormalizeCompactEntries(entries)
    if type(entries) == "string" then
        local DC = GetDCProtocol()
        if DC and type(DC.DecodeJSON) == "function" then
            entries = DC:DecodeJSON(entries)
        end
    end

    if type(entries) == "table" and type(entries.groups) == "string" then
        local DC = GetDCProtocol()
        if DC and type(DC.DecodeJSON) == "function" then
            entries.groups = DC:DecodeJSON(entries.groups)
        end
    end

    if type(entries) == "table" and type(entries.groups) == "table" then
        entries = entries.groups
    elseif type(entries) == "table" and type(entries.runs) == "table" then
        entries = entries.runs
    elseif type(entries) == "table" and type(entries.applications) == "table" then
        entries = entries.applications
    end

    if type(entries) ~= "table" then
        return {}
    end

    if entries[1] ~= nil then
        return entries
    end

    local normalized = {}
    for _, entry in pairs(entries) do
        if type(entry) == "table" then
            table.insert(normalized, entry)
        end
    end

    return normalized
end

local function CompactEntryName(entry, kind)
    if kind == "live" then
        return entry.dungeon or entry.dungeonName or entry.mapName
            or entry.name or "Live Run"
    end

    if kind == "queues" then
        return entry.dungeonName or entry.dungeon or entry.raid
            or entry.name or "Application"
    end

    return entry.dungeonName or entry.dungeon or entry.raid
        or entry.name or "Group Listing"
end

local function CompactEntryMeta(entry, kind)
    if kind == "live" then
        local timer = entry.timer or entry.elapsed or entry.time or ""
        local level = tonumber(entry.level or entry.keystoneLevel or entry.keyLevel or 0) or 0
        if level > 0 then
            return string.format("+%d  %s", level, tostring(timer))
        end
        return tostring(timer ~= "" and timer or "Spectatable")
    end

    if kind == "queues" then
        return entry.status or entry.difficultyName or "Pending"
    end

    local parts = {}
    local level = tonumber(entry.level or entry.keystoneLevel or entry.keyLevel or 0) or 0
    if level > 0 then
        table.insert(parts, "+" .. level)
    end
    if entry.difficultyName and entry.difficultyName ~= "" then
        table.insert(parts, entry.difficultyName)
    elseif entry.difficulty and tostring(entry.difficulty) ~= "" then
        table.insert(parts, tostring(entry.difficulty))
    end
    if entry.note and entry.note ~= "" then
        table.insert(parts, entry.note)
    end

    if #parts == 0 then
        return "Available"
    end

    return table.concat(parts, "  ")
end

function GF:CompactClearRows()
    if not self.compactScrollChild then return end

    self.compactRowPool = self.compactRowPool or {}
    for _, row in ipairs(self.compactRowPool) do
        row:Hide()
    end
end

-- Blizzlike "Specific Dungeons": the tick list is a set of map ids, and the
-- "Any Dungeon" row is the random queue, mutually exclusive with the rest
-- (picking Random clears the ticks, ticking a dungeon clears Random).
function GF:GetDungeonTicks()
    self.dungeonTicks = self.dungeonTicks or {}
    return self.dungeonTicks
end

function GF:ClearDungeonTicks()
    self.dungeonTicks = {}
end

function GF:CountDungeonTicks()
    local n = 0
    for _ in pairs(self:GetDungeonTicks()) do n = n + 1 end
    return n
end

function GF:IsDungeonTicked(mapId)
    return mapId and self:GetDungeonTicks()[mapId] == true
end

-- Returns the tick list as an array for the queue request; empty = random.
function GF:GetDungeonTickList()
    local list = {}
    for mapId in pairs(self:GetDungeonTicks()) do table.insert(list, mapId) end
    table.sort(list)
    return list
end

function GF:ToggleDungeonTick(entry)
    local mapId = tonumber(entry and entry.queueMapId) or 0
    local ticks = self:GetDungeonTicks()

    if mapId == 0 then
        -- The "Any Dungeon" row: selecting random drops every specific pick.
        self:ClearDungeonTicks()
    elseif ticks[mapId] then
        ticks[mapId] = nil
    else
        ticks[mapId] = true
    end
end

function GF:CompactSelectRow(row, entry)
    -- Locked rows (level requirement not met) are display-only, like retail.
    if entry and entry.locked then
        self:SetStatusMessage((entry.lockReason or "Not available yet")
            .. " - " .. (entry.dungeonName or entry.name or "this content") .. ".")
        return
    end

    -- Dungeon queue targets are checkboxes, not a single selection.
    local kind = self.compactSelectedKind or "mythic"
    if entry and entry.isQueueTarget and entry.queueCategory ~= 2
        and self.retailNavContext ~= "premade"
        and (kind == "dungeons" or kind == "mythic") then
        self:ToggleDungeonTick(entry)
        self.compactSelectedEntry = entry
        self:CompactRefreshTickMarks()
        self:UpdateCompactButtons()
        return
    end

    if self.compactSelectedRow and self.compactSelectedRow.bg then
        SetRetailBlueMenuBackground(self.compactSelectedRow.bg, "normal")
    end

    self.compactSelectedRow = row
    self.compactSelectedEntry = entry

    if row and row.bg then
        SetRetailBlueMenuBackground(row.bg, "selected")
    end

    self:UpdateCompactButtons()
end

-- Repaint every visible row's checkbox + selected bar from the tick set.
function GF:CompactRefreshTickMarks()
    if not self.compactRowPool then return end
    local anyTicked = self:CountDungeonTicks() > 0

    for _, row in ipairs(self.compactRowPool) do
        if row:IsShown() and row.check and row.entry and row.entry.isQueueTarget then
            local mapId = tonumber(row.entry.queueMapId) or 0
            local on
            if mapId == 0 then
                on = not anyTicked        -- Random is on when nothing specific is
            else
                on = self:IsDungeonTicked(mapId)
            end
            row.check:SetChecked(on)
            if row.bg then
                SetRetailBlueMenuBackground(row.bg, on and "selected" or "normal")
            end
        end
    end
end

function GF:CompactRenderRows(entries, emptyTitle, emptySubtext)
    if not self.compactScrollChild then return end

    entries = NormalizeCompactEntries(entries)
    self:CompactClearRows()
    self.compactSelectedRow = nil
    self.compactSelectedEntry = nil

    local scrollChild = self.compactScrollChild
    local kind = self.compactSelectedKind or "mythic"

    -- Persistent empty-state labels (created once, reused) so repeated renders
    -- don't stack new FontStrings on top of each other. FontStrings are regions,
    -- not children, so CompactClearRows() can't remove them.
    if not self.compactEmptyTitle then
        local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        empty:SetPoint("TOP", 0, -92)
        empty:SetTextColor(0.6, 0.6, 0.6)
        self.compactEmptyTitle = empty

        local sub = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        sub:SetPoint("TOP", empty, "BOTTOM", 0, -8)
        self.compactEmptySub = sub
    end

    if #entries == 0 then
        self.compactEmptyTitle:SetText(emptyTitle or "No groups found")
        self.compactEmptyTitle:Show()
        self.compactEmptySub:SetText(emptySubtext or "Choose a type and click Find Group.")
        self.compactEmptySub:Show()

        scrollChild:SetHeight(220)
        if self.compactResultsText then
            self.compactResultsText:SetText("Results: 0")
        end
        self:UpdateCompactButtons()
        return
    end

    -- Rows present: hide the empty-state labels.
    self.compactEmptyTitle:Hide()
    self.compactEmptySub:Hide()

    local yOffset = 0
    local rowHeight = 56
    local rowWidth = self.compactRowWidth or 312

    -- Dungeon/raid rows show the dungeon teleporter art as a thumbnail.
    local showThumb = (kind == "dungeons" or kind == "mythic" or kind == "raid")
    -- Dungeon queue rows gain a leading checkbox, so art and text shift right.
    local tickMode = (kind == "dungeons" or kind == "mythic")
        and self.retailNavContext ~= "premade"
    local checkInset = tickMode and 24 or 0
    local textInset = (showThumb and 62 or 10) + checkInset
    local textWidth = (showThumb and 110 or 162) - checkInset

    self.compactRowPool = self.compactRowPool or {}

    for i, entry in ipairs(entries) do
        local row = self.compactRowPool[i]
        if not row then
            row = CreateFrame("Button", nil, scrollChild)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetJustifyH("LEFT")

            row.leader = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.leader:SetJustifyH("LEFT")

            row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.meta:SetPoint("TOPRIGHT", -8, -8)
            row.meta:SetWidth(116)
            row.meta:SetJustifyH("RIGHT")

            row.roles = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.roles:SetPoint("BOTTOMRIGHT", -8, 7)

            row:SetScript("OnEnter", function(self)
                local entry = self.entry
                if self ~= GF.compactSelectedRow and self.bg and not (entry and entry.locked) then
                    SetRetailBlueMenuBackground(self.bg, "hover")
                end

                -- Retail shows the requirement on hover for anything locked.
                if entry and (entry.locked or entry.reqLevel or entry.reqItemLevel) then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(entry.dungeonName or entry.name or "", 1, 1, 1)
                    if entry.difficultyName and entry.difficultyName ~= "" then
                        GameTooltip:AddLine(entry.difficultyName, 0.7, 0.7, 0.7)
                    end
                    local reqLevel = tonumber(entry.reqLevel) or 0
                    if reqLevel > 0 then
                        local met = (UnitLevel("player") or 1) >= reqLevel
                        GameTooltip:AddLine("Requires level " .. reqLevel,
                            met and 0.1 or 1, met and 1 or 0.1, 0.1)
                    end
                    local reqIlvl = tonumber(entry.reqItemLevel) or 0
                    if reqIlvl > 0 then
                        GameTooltip:AddLine("Requires item level " .. reqIlvl, 0.7, 0.7, 0.7)
                    end
                    -- Server lock reason (attunement, deserter, gear...) when it
                    -- says more than the level line already did.
                    if entry.locked and entry.lockReason
                        and not entry.lockReason:find("^Requires level") then
                        GameTooltip:AddLine(entry.lockReason, 1, 0.1, 0.1)
                    end
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                if self ~= GF.compactSelectedRow and self.bg
                    and not (self.entry and self.entry.locked) then
                    SetRetailBlueMenuBackground(self.bg, "normal")
                end
                GameTooltip:Hide()
            end)
            row:SetScript("OnClick", function(self)
                if self.entry and self.entry.locked then
                    PlayUISound("igQuestFailed")
                else
                    PlayUISound("igMainMenuOptionCheckBoxOn")
                end
                GF:CompactSelectRow(self, self.entry)
            end)

            self.compactRowPool[i] = row
        end

        row:SetParent(scrollChild)
        row:ClearAllPoints()
        row:SetSize(rowWidth, rowHeight - 2)
        row:SetPoint("TOPLEFT", 4, -yOffset)
        row.entry = entry

        SetRetailBlueMenuBackground(row.bg, "normal")

        -- Queue-target dungeon rows carry a real checkbox (blizzlike LFD lets
        -- you tick several dungeons at once); everything else keeps the plain
        -- single-selection row.
        local isTickRow = entry.isQueueTarget and entry.queueCategory ~= 2
            and (kind == "dungeons" or kind == "mythic")
            and self.retailNavContext ~= "premade"
        if isTickRow then
            if not row.check then
                local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                check:SetSize(22, 22)
                check:SetPoint("LEFT", 2, 0)
                check:SetHitRectInsets(0, 0, 0, 0)
                row.check = check
            end
            row.check:Show()
            row.check:SetScript("OnClick", function()
                GF:CompactSelectRow(row, row.entry)
            end)
        elseif row.check then
            row.check:Hide()
            row.check:SetScript("OnClick", nil)
        end

        if showThumb then
            if not row.thumb then
                local thumb = row:CreateTexture(nil, "ARTWORK")
                thumb:SetSize(48, 48)
                thumb:SetPoint("LEFT", 6, 0)
                row.thumb = thumb
            end
            row.thumb:ClearAllPoints()
            row.thumb:SetPoint("LEFT", 6 + checkInset, 0)
            local candidates = GetEntryDungeonArtCandidates(entry)
            if not ApplyTextureCandidates(row.thumb, candidates,
                "Interface\\LFGFrame\\UI-LFG-DUNGEON-WAILINGCAVERNS") then
                row.thumb:SetTexture("Interface\\Icons\\Achievement_ChallengeMode_Gold")
            end
            -- crop the (often landscape) art to a square cell
            row.thumb:SetTexCoord(0, 1, 0, 1)
            row.thumb:Show()
        elseif row.thumb then
            row.thumb:Hide()
        end

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", textInset, -7)
        row.name:SetWidth(textWidth)
        row.name:SetText(CompactEntryName(entry, kind))

        row.leader:ClearAllPoints()
        row.leader:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
        row.leader:SetWidth(textWidth)
        row.leader:SetText(entry.leader or entry.leaderName or entry.owner or "")

        row.meta:SetText(CompactEntryMeta(entry, kind))

        -- Retail-style role glyphs (tank/healer/dps silhouettes) + open counts.
        row.roles:SetText(string.format("%s%s  %s%s  %s%s",
            GFAtlasEscape("tank-micro", 13),
            tostring(entry.needTank or entry.tanks or entry.tank or 0),
            GFAtlasEscape("healer-micro", 13),
            tostring(entry.needHealer or entry.healers or entry.healer or 0),
            GFAtlasEscape("dps-micro", 13),
            tostring(entry.needDps or entry.dps or 0)))

        -- Locked content reads greyed with a padlock over the thumbnail, the way
        -- retail renders a dungeon whose requirements you do not meet yet.
        if entry.locked then
            if not row.lock then
                local lock = row:CreateTexture(nil, "OVERLAY")
                lock:SetSize(20, 20)
                lock:SetPoint("BOTTOMLEFT", 4, 4)
                lock:SetTexture("Interface\\Buttons\\LockButton-Small")
                row.lock = lock
            end
            row.lock:Show()
            if row.thumb then
                row.thumb:SetVertexColor(0.35, 0.35, 0.35)
            end
            row.name:SetTextColor(0.5, 0.5, 0.5)
            row.leader:SetTextColor(0.4, 0.4, 0.4)
            row.leader:SetText(entry.lockReason or "Requirements not met")
            row.meta:SetTextColor(0.5, 0.5, 0.5)
            row.roles:SetTextColor(0.4, 0.4, 0.4)
        else
            if row.lock then row.lock:Hide() end
            if row.thumb then
                row.thumb:SetVertexColor(1, 1, 1)
            end
            row.name:SetTextColor(1, 0.82, 0)
            row.leader:SetTextColor(1, 1, 1)
            row.meta:SetTextColor(1, 1, 1)
            row.roles:SetTextColor(0.5, 0.5, 0.5)
        end

        row:Show()

        yOffset = yOffset + rowHeight
    end

    scrollChild:SetHeight(math.max(yOffset, 220))
    if self.compactResultsText then
        self.compactResultsText:SetText("Results: " .. #entries)
    end
    self:CompactRefreshTickMarks()
    self:UpdateCompactButtons()
end

function GF:UpdateCompactButtons()
    if not self.compactPrimaryButton then return end

    if self.hlbgPanelShown then
        local HLBG = rawget(_G, "HLBG")
        self.compactPrimaryButton:SetText(
            (HLBG and HLBG.IsInQueue) and "Leave Queue" or "Join Queue")
        if self.compactCreateButton then
            self.compactCreateButton:Hide()
        end
        return
    end

    if self.retailHomeShown then
        local selectedKind = self.premadeSelectedKind or "mythic"
        local homeOption = self.COMPACT_OPTIONS[selectedKind] or self.COMPACT_OPTIONS.mythic
        self.compactPrimaryButton:SetText("Find a Group")
        if self.compactCreateButton then
            if homeOption.create then
                self.compactCreateButton:SetText("Start a Group")
                self.compactCreateButton:Show()
            else
                self.compactCreateButton:Hide()
            end
        end
        return
    end

    local kind = self.compactSelectedKind or "mythic"
    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    local selected = self.compactSelectedEntry

    -- In the Dungeon/Raid Finder navs a selected row is the queue target, not
    -- a listing — the primary action queues, so it must not read "Apply".
    local finderQueueMode = self.retailNavContext ~= "premade"
        and (kind == "dungeons" or kind == "mythic" or kind == "raid")

    if finderQueueMode then
        if kind ~= "raid" then
            local n = self:CountDungeonTicks()
            if n == 0 then
                self.compactPrimaryButton:SetText("Find Random Group")
            elseif n == 1 then
                self.compactPrimaryButton:SetText("Find Group (1 dungeon)")
            else
                self.compactPrimaryButton:SetText(string.format("Find Group (%d dungeons)", n))
            end
        else
            self.compactPrimaryButton:SetText(option.actionText or "Find Group")
        end
    elseif selected and (kind == "mythic" or kind == "raid" or kind == "quest" or kind == "other") then
        self.compactPrimaryButton:SetText("Apply")
    elseif selected and kind == "live" then
        self.compactPrimaryButton:SetText("Spectate")
    else
        self.compactPrimaryButton:SetText(option.actionText or "Find Group")
    end

    if self.compactCreateButton then
        if option.create then
            self.compactCreateButton:SetText("Start a Group")
            self.compactCreateButton:Show()
        else
            self.compactCreateButton:Hide()
        end
    end
end

function GF:SetQueueDungeonDifficulty(difficulty)
    difficulty = tonumber(difficulty) or 0
    if difficulty < 0 or difficulty > 1 then
        difficulty = 0
    end
    self.queueDungeonDifficulty = difficulty

    if self.compactDiffButton then
        self.compactDiffButton:SetText(self.DUNGEON_DIFFICULTY_LABELS[difficulty] or "Normal")
    end

    -- Refresh the picker rows so their difficulty column matches.
    if self.compactMode and self.retailNavContext ~= "premade"
        and self.compactSelectedKind == "dungeons" then
        self:SelectCompactType("dungeons")
    end
end

function GF:CycleQueueDifficulty()
    self:SetQueueDungeonDifficulty(((self.queueDungeonDifficulty or 0) + 1) % 2)
end

function GF:SelectCompactType(kind)
    kind = kind or "mythic"
    if kind == "hlbg" then
        self:ShowHinterlandPanel()
        return
    end

    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    self.compactSelectedKind = kind
    self.compactSelectedEntry = nil
    self.retailHomeShown = false
    self.hlbgPanelShown = false

    if self.compactTypeMenu then
        self.compactTypeMenu:Hide()
    end
    if self.compactTypeMenuCatcher then
        self.compactTypeMenuCatcher:Hide()
    end

    if self.retailHomeFrame then
        self.retailHomeFrame:Hide()
    end
    if self.hlbgPanel then
        self.hlbgPanel:Hide()
    end
    if self.pvpPanel then
        self.pvpPanel:Hide()
    end
    if self.mythicPanel then
        self.mythicPanel:Hide()
    end
    if self.compactBrowserFrame then
        self.compactBrowserFrame:Show()
    end
    if self.compactListFrame then
        self.compactListFrame:Show()
    end

    -- The difficulty row only applies to the Specific Dungeons queue
    -- (Mythic+ is locked to Mythic difficulty).
    local showDifficulty = self.retailNavContext ~= "premade" and kind == "dungeons"
    if self.compactDiffButton then
        self.compactDiffButton:SetText(
            self.DUNGEON_DIFFICULTY_LABELS[self.queueDungeonDifficulty or 0] or "Normal")
        if showDifficulty then
            self.compactDiffButton:Show()
            self.compactDiffLabel:Show()
        else
            self.compactDiffButton:Hide()
            self.compactDiffLabel:Hide()
        end
    end
    if self.compactListFrame then
        self.compactListFrame:SetPoint("TOPLEFT", 6, showDifficulty and -152 or -116)
    end

    -- The Raid Finder has a single type, so the Type dropdown is pointless
    -- there; hide the whole row.
    local showTypeRow = not (self.retailNavContext ~= "premade" and kind == "raid")
    if self.compactTypeLabel then
        if showTypeRow then
            self.compactTypeLabel:Show()
        else
            self.compactTypeLabel:Hide()
        end
    end
    if self.compactTypeButton then
        if showTypeRow then
            self.compactTypeButton:Show()
        else
            self.compactTypeButton:Hide()
        end
    end
    if self.retailContentTitle then
        self.retailContentTitle:SetText(option.title or option.label or "Group Finder")
    end
    if self.SetRetailNavSelection then
        if self.retailNavContext == "premade" then
            self:SetRetailNavSelection("premade")
        elseif kind == "dungeons" or kind == "mythic" then
            self:SetRetailNavSelection("dungeon")
        elseif kind == "raid" then
            self:SetRetailNavSelection("raid")
        else
            self:SetRetailNavSelection("premade")
        end
    end
    if self.SetActiveBottomTab then
        self:SetActiveBottomTab("finder")
    end

    if self.mainFrame then
        -- Top window title stays the static frame name; the content panel title
        -- carries the per-category label (matches retail PVEFrame).
        self.mainFrame.TitleText:SetText("Group Finder")
    end
    if self.compactCategoryButton then
        self.compactCategoryButton:SetText(option.label or "Mythic+")
    end
    if self.compactTypeButtonText then
        self.compactTypeButtonText:SetText(option.typeText or option.label or "Specific Dungeons")
    end

    -- In Dungeon Finder / Raid Finder mode the list is a queue-target picker
    -- (pick one + Find Group, or for dungeons just Find Group = Any). The Premade
    -- Groups nav keeps the listing browse/apply flow.
    if self.retailNavContext ~= "premade"
        and (kind == "dungeons" or kind == "mythic" or kind == "raid")
        and self.GetQueueTargets then
        self:CompactRenderRows(self:GetQueueTargets(kind),
            kind == "raid" and "No raids available" or "No dungeons available",
            kind == "raid" and "Pick a raid, then click Find Group."
                or "Pick a dungeon (or none for Any), then click Find Group.")
        return
    end

    self:CompactRenderRows(self.compactData and self.compactData[kind] or {},
        kind == "queues" and "No active applications" or "No groups found",
        kind == "hlbg" and "Click Join Queue to enter Hinterland BG."
            or "Click Find Group to refresh this list.")
end

-- Lay out the type menu for the active nav section (Dungeon Finder and Raid
-- Finder only list their own content; Premade Groups gets the full catalog).
function GF:RebuildCompactTypeMenu()
    local menu = self.compactTypeMenu
    if not menu or not menu.items then return end

    local context
    if self.retailNavContext == "premade" then
        context = "premade"
    elseif (self.compactSelectedKind or "mythic") == "raid" then
        context = "raid"
    else
        context = "dungeon"
    end

    local kinds = self.TYPE_MENU_BY_CONTEXT[context] or self.COMPACT_OPTION_ORDER

    for _, item in pairs(menu.items) do
        item:Hide()
    end

    local menuY = -4
    for _, kind in ipairs(kinds) do
        local item = menu.items[kind]
        if item then
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", 7, menuY)
            item:Show()
            menuY = menuY - 22
        end
    end

    menu:SetHeight(-menuY + 8)
end

function GF:ToggleCompactTypeMenu()
    if not self.compactTypeMenu then return end

    if self.compactTypeMenu:IsShown() then
        self.compactTypeMenu:Hide()
        if self.compactTypeMenuCatcher then self.compactTypeMenuCatcher:Hide() end
    else
        self:RebuildCompactTypeMenu()
        if self.compactTypeMenuCatcher then self.compactTypeMenuCatcher:Show() end
        self.compactTypeMenu:Show()
        self.compactTypeMenu:Raise()
    end
end

function GF:CompactPrimaryAction()
    if self.retailHomeShown then
        self.retailNavContext = "premade"
        self:SelectCompactType(self.premadeSelectedKind or "mythic")
        self:CompactPrimaryAction()
        return
    end

    local kind = self.compactSelectedKind or "mythic"
    local selected = self.compactSelectedEntry

    -- Dungeon Finder / Raid Finder nav = LFG-style auto-matchmaking queue.
    -- A selected row is the queue target (raid/dungeon picker), not a listing.
    -- (The Premade Groups nav keeps the listing browse/apply flow below.)
    if self.retailNavContext ~= "premade"
        and (kind == "dungeons" or kind == "mythic" or kind == "raid")
        and self.QueueForCurrent then
        self:QueueForCurrent()
        return
    end

    if selected and (kind == "mythic" or kind == "raid" or kind == "quest" or kind == "other") then
        local listingId = selected.id or selected.listingId
        if listingId then
            self:ShowApplicationDialog(listingId, CompactEntryName(selected, kind))
        end
        return
    end

    if selected and kind == "live" then
        local runId = selected.runId or selected.id or selected.instanceId
        local DC = GetDCProtocol()
        if runId and DC and DC.GroupFinder and DC.GroupFinder.StartSpectate then
            DC.GroupFinder.StartSpectate(runId)
        end
        return
    end

    if kind == "hlbg" then
        local HLBG = rawget(_G, "HLBG")
        local leaving = HLBG and HLBG.IsInQueue
        local ok
        if leaving then
            ok = self:LeaveHinterlandQueue()
        else
            ok = self:JoinHinterlandQueue(false)
        end

        if not ok then
            self:SetStatusMessage("Hinterland BG queue helper is not available.")
        else
            -- Immediate feedback; the join/leave confirmation follows from the
            -- server (see UpdateHinterlandPanel state-change announcements).
            self:PrintImportant(leaving
                and "Hinterland BG: leave request sent."
                or "Hinterland BG: queue join requested...")
            self:ScheduleHinterlandStatusPolls()
        end

        if self.UpdateHinterlandPanel then
            self:UpdateHinterlandPanel()
        end
    elseif kind == "blizzardLFG" then
        self:ToggleBlizzardLFG()
    elseif kind == "blizzardPVP" then
        self:ToggleBlizzardPVP()
    elseif kind == "live" then
        local DC = GetDCProtocol()
        if DC and DC.GroupFinder and DC.GroupFinder.GetSpectateList then
            DC.GroupFinder.GetSpectateList()
        end
    elseif kind == "queues" then
        self:RefreshMyQueues()
    else
        self:SearchCustomCategory(kind)
    end
end

-- Set the chosen dungeon/raid on the create dialog (called from the dropdown).
function GF:SetCreateTarget(name, mapId)
    local dialog = self.compactCreateDialog
    if not dialog then return end
    dialog.targetName = name
    dialog.targetMapId = mapId or 0
    if dialog.targetDrop then
        UIDropDownMenu_SetText(dialog.targetDrop, name or "Select...")
    end
end

-- Dropdown init: dungeons and raids are both grouped by expansion (submenus
-- so the long lists never overflow the screen).
local CREATE_TARGET_ERAS = {
    [0] = "Classic", [1] = "The Burning Crusade", [2] = "Wrath of the Lich King"
}

local function AddCreateTargetEraHeaders(level)
    for eraId = 0, 2 do
        local info = UIDropDownMenu_CreateInfo()
        info.text = CREATE_TARGET_ERAS[eraId]
        info.value = eraId
        info.hasArrow = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end
end

local function InitCreateTargetDropdown(_, level)
    local dialog = GF.compactCreateDialog
    if not dialog then return end
    level = level or 1
    local kind = dialog.kind or "mythic"

    if kind == "raid" then
        if level == 1 then
            AddCreateTargetEraHeaders(level)
        elseif level == 2 then
            local eraId = UIDROPDOWNMENU_MENU_VALUE
            local catalog = (GF.GetRaidCatalog and GF:GetRaidCatalog()) or {}
            for _, r in ipairs(catalog) do
                if (tonumber(r.era) or 2) == eraId then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = r.name
                    info.notCheckable = true
                    info.func = function() GF:SetCreateTarget(r.name, r.mapId) end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
        return
    end

    -- Mythic+ listings only target the real seasonal M+ dungeons (the same
    -- set shown in the Seasonal Mythic+ panel), not the full Normal/Heroic
    -- catalog. The list is short, so it stays flat.
    local list = GF.GetSeasonalDungeonList and GF:GetSeasonalDungeonList()
    if not list then
        -- Request the server list and show a placeholder until it arrives
        -- (an empty menu rendered blank and "couldn't be selected").
        local DCproto = rawget(_G, "DCAddonProtocol")
        if DCproto and DCproto.GroupFinder and DCproto.GroupFinder.GetDungeonList then
            DCproto.GroupFinder.GetDungeonList()
        end
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Loading dungeons..."
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        return
    end
    for _, d in ipairs(list) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = d.name or ("Map " .. tostring(d.mapId))
        info.notCheckable = true
        info.func = function() GF:SetCreateTarget(d.name, d.mapId) end
        UIDropDownMenu_AddButton(info, level)
    end
end

function GF:ShowCompactCreateDialog(kind)
    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    if not option.create then return end

    if not self.compactCreateDialog then
        local frame = CreateFrame("Frame", "DCCompactGroupCreateDialog", UIParent)
        frame:SetSize(340, 250)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        frame.title = title

        -- Selector label ("Dungeon:" / "Raid:" / "Name:").
        local targetLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        targetLabel:SetPoint("TOPLEFT", 24, -52)
        targetLabel:SetText("Dungeon:")
        frame.targetLabel = targetLabel

        -- Dungeon/raid dropdown (used for mythic & raid).
        local targetDrop = CreateFrame("Frame", "DCCreateTargetDrop", frame, "UIDropDownMenuTemplate")
        targetDrop:SetPoint("TOPLEFT", 70, -48)
        UIDropDownMenu_SetWidth(targetDrop, 200)
        frame.targetDrop = targetDrop

        -- Free-text name (used for quest/other categories).
        local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        nameBox:SetSize(220, 20)
        nameBox:SetPoint("TOPLEFT", 90, -54)
        nameBox:SetAutoFocus(false)
        frame.nameBox = nameBox

        local levelLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelLabel:SetPoint("TOPLEFT", 24, -90)
        levelLabel:SetText("Key Level:")

        local levelBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        levelBox:SetSize(60, 20)
        levelBox:SetPoint("TOPLEFT", 100, -88)
        levelBox:SetAutoFocus(false)
        levelBox:SetNumeric(true)
        levelBox:SetText("0")
        frame.levelLabel = levelLabel
        frame.levelBox = levelBox

        local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noteLabel:SetPoint("TOPLEFT", 24, -120)
        noteLabel:SetText("Note:")

        -- Bordered multi-line note box.
        local noteFrame = CreateFrame("Frame", nil, frame)
        noteFrame:SetSize(290, 46)
        noteFrame:SetPoint("TOPLEFT", 24, -138)
        noteFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        noteFrame:SetBackdropColor(0.02, 0.03, 0.06, 0.95)
        noteFrame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

        local noteBox = CreateFrame("EditBox", nil, noteFrame)
        noteBox:SetPoint("TOPLEFT", 7, -6)
        noteBox:SetPoint("BOTTOMRIGHT", -7, 6)
        noteBox:SetMultiLine(true)
        noteBox:SetAutoFocus(false)
        noteBox:SetFontObject("ChatFontNormal")
        noteBox:SetMaxLetters(120)
        noteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        frame.noteBox = noteBox

        local createBtn = CreateRetailActionButton(frame, 100, 24, "Create")
        createBtn:SetPoint("BOTTOMLEFT", 42, 20)
        createBtn:SetScript("OnClick", function()
            local dialogKind = frame.kind or "mythic"
            local isRaid = dialogKind == "raid"
            local usesTarget = (dialogKind == "mythic" or dialogKind == "raid")

            local dungeonName
            local dungeonId = 0
            if usesTarget then
                dungeonName = frame.targetName
                dungeonId = frame.targetMapId or 0
                if not dungeonName then
                    GF:SetStatusMessage("Pick a " .. (isRaid and "raid" or "dungeon") .. " first.")
                    return
                end
            else
                dungeonName = frame.nameBox:GetText()
                if not dungeonName or dungeonName == "" then
                    dungeonName = option.label
                end
            end

            local payload = {
                dungeonName = dungeonName,
                dungeonId = dungeonId,
                keyLevel = tonumber(frame.levelBox:GetText()) or 0,
                needTank = isRaid and 2 or 1,
                needHealer = isRaid and 5 or 1,
                needDps = isRaid and 18 or 3,
                note = frame.noteBox:GetText() or "",
            }

            if GF:CreateCustomListing(dialogKind, payload) then
                frame:Hide()
                GF:SetStatusMessage("Creating listing...")
                C_Timer.After(0.5, function()
                    GF:SearchCustomCategory(dialogKind)
                end)
            end
        end)

        local cancelBtn = CreateRetailActionButton(frame, 100, 24, "Cancel")
        cancelBtn:SetPoint("BOTTOMRIGHT", -42, 20)
        cancelBtn:SetScript("OnClick", function() frame:Hide() end)

        self.compactCreateDialog = frame
    end

    local dialog = self.compactCreateDialog
    dialog.kind = kind
    dialog.targetName = nil
    dialog.targetMapId = 0
    dialog.title:SetText("Create " .. (option.label or "Group"))
    dialog.noteBox:SetText("")
    dialog.levelBox:SetText("0")

    local usesTarget = (kind == "mythic" or kind == "raid")
    if usesTarget then
        dialog.targetLabel:SetText(kind == "raid" and "Raid:" or "Dungeon:")
        dialog.targetLabel:Show()
        dialog.targetDrop:Show()
        dialog.nameBox:Hide()
        UIDropDownMenu_Initialize(dialog.targetDrop, InitCreateTargetDropdown)
        UIDropDownMenu_SetText(dialog.targetDrop, "Select a " .. (kind == "raid" and "raid" or "dungeon") .. "...")

        -- Pre-select the dungeon/raid the player already picked in the list,
        -- so the dialog doesn't ask for the same choice twice. Mythic+
        -- listings only target seasonal dungeons, so skip the prefill when
        -- the picked dungeon isn't part of the season.
        local selected = self.compactSelectedEntry
        if type(selected) == "table" then
            local selIsRaid = (selected.queueCategory == 2) or selected.isRaid or false
            if (kind == "raid") == (selIsRaid and true or false) then
                local name = selected.dungeonName or selected._name or selected.name
                local mapId = tonumber(selected.mapId or selected.queueMapId or 0) or 0
                local valid = name ~= nil and mapId > 0
                if valid and kind == "mythic" then
                    valid = false
                    local seasonal = self.GetSeasonalDungeonList
                        and self:GetSeasonalDungeonList()
                    for _, d in ipairs(seasonal or {}) do
                        if (tonumber(d.mapId) or 0) == mapId then
                            valid = true
                            break
                        end
                    end
                end
                if valid then
                    self:SetCreateTarget(name, mapId)
                end
            end
        end
    else
        dialog.targetLabel:SetText("Name:")
        dialog.targetLabel:Show()
        dialog.targetDrop:Hide()
        dialog.nameBox:Show()
        dialog.nameBox:SetText(option.label or "Group")
    end

    -- Key level only applies to Mythic+ dungeon listings.
    if kind == "mythic" then
        dialog.levelLabel:Show()
        dialog.levelBox:Show()
    else
        dialog.levelLabel:Hide()
        dialog.levelBox:Hide()
    end
    dialog:Show()
end

function GF:CompactPopulateGroups(groups, kind)
    kind = kind or self.compactSelectedKind or "mythic"
    groups = NormalizeCompactEntries(groups)
    self.compactData = self.compactData or {}
    self.compactData[kind] = groups

    if self.compactMode and self.compactSelectedKind == kind then
        self:CompactRenderRows(groups)
    end
end

function GF:CompactPopulateApplications(applications)
    applications = NormalizeCompactEntries(applications)
    self.compactData = self.compactData or {}
    self.compactData.queues = applications

    if self.compactMode and self.compactSelectedKind == "queues" then
        self:CompactRenderRows(applications, "No active applications", "Applications appear here after you apply.")
    end
end

function GF:CompactPopulateLiveRuns(runs)
    runs = NormalizeCompactEntries(runs)
    self.compactData = self.compactData or {}
    self.compactData.live = runs

    if self.compactMode and self.compactSelectedKind == "live" then
        self:CompactRenderRows(runs, "No live runs", "Click Refresh to request spectatable runs.")
    end
end

function GF:CreateCompactRoleButton(parent, role, xOffset, checked, tooltip, allowed)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(64, 60)
    button:SetPoint("TOPLEFT", xOffset, -2)
    button.role = role
    button.allowed = allowed ~= false

    -- Ring centred in the button so it sits cleanly inside the role bar.
    local ring = button:CreateTexture(nil, "BACKGROUND")
    ring:SetSize(48, 48)
    ring:SetPoint("CENTER", 0, 0)
    button.ring = ring

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(44, 44)
    icon:SetPoint("CENTER", ring, "CENTER", 0, 0)
    button.icon = icon

    ApplyCompactRoleButtonArt(button, checked)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(tooltip or role)
        if not self.allowed then
            GameTooltip:AddLine("Your class cannot fill this role.", 1, 0.3, 0.3, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self)
        -- A class that cannot tank/heal must not be able to toggle that role.
        if not self.allowed then return end
        GF.compactRoles = GF.compactRoles or { dps = true }
        GF.compactRoles[self.role] = not GF.compactRoles[self.role]
        PlayUISound(GF.compactRoles[self.role]
            and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        GF:UpdateCompactRoleButtons()
    end)

    self.compactRoleButtons = self.compactRoleButtons or {}
    self.compactRoleButtons[role] = button
end

function GF:SetRetailNavSelection(selection)
    self.retailNavSelection = selection

    for key, button in pairs(self.retailNavButtons or {}) do
        UpdateRetailNavButtonArt(button, key == selection and "selected" or "normal")
    end
end

function GF:RefreshRetailPremadeSelection()
    local selectedKind = self.premadeSelectedKind or "mythic"

    for kind, button in pairs(self.premadeCategoryButtons or {}) do
        local sel = (kind == selectedKind)
        if button.selectOverlay then
            if sel then
                button.selectOverlay:Show()
            else
                button.selectOverlay:Hide()
            end
        end
        if button.label then
            if sel then
                button.label:SetTextColor(1, 0.90, 0.24)
            else
                button.label:SetTextColor(1, 0.82, 0)
            end
        end
    end

    local option = self.COMPACT_OPTIONS[selectedKind] or self.COMPACT_OPTIONS.mythic
    if self.compactTypeButtonText then
        self.compactTypeButtonText:SetText(option.typeText or option.label)
    end

    self:UpdateCompactButtons()
end

function GF:ShowRetailPremadeHome(kind)
    self.retailNavContext = "premade"
    self.retailHomeShown = true
    self.hlbgPanelShown = false
    self.premadeSelectedKind = kind or self.premadeSelectedKind or "mythic"
    self.compactSelectedKind = self.premadeSelectedKind
    self.compactSelectedEntry = nil

    if self.compactTypeMenu then
        self.compactTypeMenu:Hide()
    end

    if self.compactBrowserFrame then
        self.compactBrowserFrame:Hide()
    end
    if self.compactListFrame then
        self.compactListFrame:Hide()
    end
    if self.hlbgPanel then
        self.hlbgPanel:Hide()
    end
    if self.pvpPanel then
        self.pvpPanel:Hide()
    end
    if self.mythicPanel then
        self.mythicPanel:Hide()
    end
    if self.retailHomeFrame then
        self.retailHomeFrame:Show()
    end
    if self.retailContentTitle then
        self.retailContentTitle:SetText("Premade Groups")
    end
    if self.mainFrame and self.mainFrame.TitleText then
        self.mainFrame.TitleText:SetText("Group Finder")
    end

    self:SetRetailNavSelection("premade")
    self:RefreshRetailPremadeSelection()
end

-- =====================================================================
-- Hinterland BG queue panel (left-nav section)
-- =====================================================================

function GF:RequestHinterlandStatus()
    local HLBG = rawget(_G, "HLBG")
    if HLBG and type(HLBG.RequestQueueStatus) == "function" then
        HLBG.RequestQueueStatus()
        return true
    end

    local DC = GetDCProtocol()
    if DC and DC.Hinterland and DC.Hinterland.GetStatus then
        DC.Hinterland.GetStatus()
        return true
    end

    return false
end

function GF:LeaveHinterlandQueue()
    local HLBG = rawget(_G, "HLBG")
    if HLBG and type(HLBG.LeaveQueue) == "function" then
        HLBG.LeaveQueue()
        return true
    end

    local DC = GetDCProtocol()
    if DC and DC.Hinterland and DC.Hinterland.LeaveQueue then
        DC.Hinterland.LeaveQueue()
        return true
    end

    return false
end

-- After a join/leave click, poll the queue status quickly so the panel and
-- announcements react within seconds instead of the 10s background refresh.
function GF:ScheduleHinterlandStatusPolls()
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(1, function() GF:RequestHinterlandStatus() end)
    C_Timer.After(3, function() GF:RequestHinterlandStatus() end)
end

-- Render the queue status from the shared HLBG state (kept current by the
-- DC-HinterlandBG addon via DC protocol + chat parsing).
function GF:UpdateHinterlandPanel()
    local HLBG = rawget(_G, "HLBG")

    -- Blizzard-style join/leave confirmation (chat + status + sound) whenever
    -- the queue state actually changes, no matter which path updated it.
    if HLBG then
        local inQueue = HLBG.IsInQueue and true or false
        if self._hlbgWasInQueue == nil then
            self._hlbgWasInQueue = inQueue
        elseif inQueue ~= self._hlbgWasInQueue then
            self._hlbgWasInQueue = inQueue
            self:PrintImportant(inQueue
                and "You have joined the Hinterland BG queue."
                or "You are no longer in the Hinterland BG queue.")
            if PlaySound then
                pcall(PlaySound, inQueue and "PVPENTERQUEUE" or "PVPLEAVEQUEUE")
            end
        end
    end

    local panel = self.hlbgPanel
    if not panel or not panel:IsShown() then return end
    if not HLBG then
        panel.status:SetText("|cffff4444The DC-HinterlandBG addon is not loaded.|r\n\n"
            .. "Queue status is unavailable; Join Queue will try the\n"
            .. "server protocol directly.")
        self:UpdateCompactButtons()
        return
    end

    local total = tonumber(HLBG.QueueTotal) or 0
    local alliance = tonumber(HLBG.AllianceQueued) or 0
    local horde = tonumber(HLBG.HordeQueued) or 0
    local minPlayers = tonumber(HLBG.MinPlayersToStart) or 10
    local state = tostring(HLBG.BattleState or "UNKNOWN")

    local stateDisplay = state
    if state == "WAITING" then
        stateDisplay = "|cFFAAAA00Waiting for players|r"
    elseif state == "WARMUP" then
        stateDisplay = "|cFF00FF00Warmup - Battle starting soon!|r"
    elseif state == "IN_PROGRESS" then
        stateDisplay = "|cFFFF0000Battle in progress|r"
    elseif state == "FINISHED" then
        stateDisplay = "|cFF98FB98Battle finished|r"
    end

    if HLBG.IsInQueue then
        local estWait = tonumber(HLBG.EstimatedWaitSeconds) or 0
        local estWaitDisplay = "Starting soon!"
        if estWait >= 60 then
            estWaitDisplay = string.format("%d min %d sec", math.floor(estWait / 60), estWait % 60)
        elseif estWait > 0 then
            estWaitDisplay = string.format("%d sec", estWait)
        end

        panel.status:SetText(string.format(
            "|cFF00FF00You are in the queue!|r\n\n"
            .. "|cFFFFD700Position:|r %d / %d\n"
            .. "|cFF00AAFFAlliance:|r %d  |cFFFF4444Horde:|r %d\n"
            .. "|cFFFFD700Est. Wait:|r %s\n"
            .. "|cFFFFD700Battle State:|r %s\n\n"
            .. "You will be teleported when the battle starts.",
            tonumber(HLBG.QueuePosition) or 0, total, alliance, horde,
            estWaitDisplay, stateDisplay))
    elseif total > 0 then
        local playersNeeded = math.max(0, minPlayers - total)
        local neededStr = playersNeeded > 0
            and string.format("|cFFFF4444Need %d more players|r", playersNeeded)
            or "|cFF00FF00Ready to start!|r"

        panel.status:SetText(string.format(
            "|cFFAAAAAANot in queue|r\n\n"
            .. "%d / %d player(s) queued\n"
            .. "|cFF00AAFFAlliance:|r %d  |cFFFF4444Horde:|r %d\n"
            .. "%s\n"
            .. "|cFFFFD700Battle State:|r %s\n\n"
            .. "Click Join Queue to participate in the next battle.",
            total, minPlayers, alliance, horde, neededStr, stateDisplay))
    else
        panel.status:SetText(string.format(
            "|cFFAAAAAANot in queue|r\n\n"
            .. "No players queued\n"
            .. "|cFFFFD700Battle State:|r %s\n\n"
            .. "Be the first to join!",
            stateDisplay))
    end

    self:UpdateCompactButtons()
end

function GF:ShowHinterlandPanel()
    self.retailNavContext = "hlbg"
    self.retailHomeShown = false
    self.hlbgPanelShown = true
    self.compactSelectedKind = "hlbg"
    self.compactSelectedEntry = nil

    if self.compactTypeMenu then
        self.compactTypeMenu:Hide()
    end
    if self.compactTypeMenuCatcher then
        self.compactTypeMenuCatcher:Hide()
    end
    if self.compactBrowserFrame then
        self.compactBrowserFrame:Hide()
    end
    if self.compactListFrame then
        self.compactListFrame:Hide()
    end
    if self.retailHomeFrame then
        self.retailHomeFrame:Hide()
    end
    if self.pvpPanel then
        self.pvpPanel:Hide()
    end
    if self.mythicPanel then
        self.mythicPanel:Hide()
    end

    -- Repaint the panel whenever the HLBG addon refreshes its own queue UI.
    local HLBG = rawget(_G, "HLBG")
    if HLBG and not self._hlbgQueueUiHooked
        and type(HLBG.UpdateQueueUI) == "function" then
        local original = HLBG.UpdateQueueUI
        HLBG.UpdateQueueUI = function(...)
            original(...)
            GF:UpdateHinterlandPanel()
        end
        self._hlbgQueueUiHooked = true
    end

    if self.hlbgPanel then
        self.hlbgPanel:Show()
    end
    if self.retailContentTitle then
        self.retailContentTitle:SetText("Hinterland BG")
    end
    if self.mainFrame and self.mainFrame.TitleText then
        self.mainFrame.TitleText:SetText("Group Finder")
    end

    self:SetRetailNavSelection("hlbg")
    if self.SetActiveBottomTab then
        self:SetActiveBottomTab("finder")
    end
    self:UpdateCompactButtons()
end

-- Retail PVEFrame nav button (GroupFinderGroupButtonTemplate): bluemenu-main
-- button art + gold ring with the category icon + large label. Selected state
-- swaps to the blue-glow art row; hover is the same art additively blended.
function GF:CreateRetailNavButton(parent, key, label, iconTexture, yOffset, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(160, 60)
    button:SetPoint("TOPLEFT", 10, yOffset)
    button.key = key

    -- Button background: the 224x80 bluemenu button art (normal row).
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(RETAIL_BLUEMENU_MAIN)
    local c = BLUEMENU_BUTTON_COORDS.normal
    bg:SetTexCoord(c[1], c[2], c[3], c[4])
    button.bg = bg

    -- Native hover: same art, additive (exactly retail's HighlightTexture).
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture(RETAIL_BLUEMENU_MAIN)
    highlight:SetTexCoord(c[1], c[2], c[3], c[4])
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.8)
    button:SetHighlightTexture(highlight)

    -- Gold ring on the left with the category icon inside (retail layout).
    local ring = button:CreateTexture(nil, "ARTWORK", nil, 2)
    ring:SetSize(56, 56)
    ring:SetPoint("LEFT", -4, 0)
    ring:SetTexture(RETAIL_BLUE_MENU_RING)
    ring:SetTexCoord(BLUEMENU_RING_COORDS[1], BLUEMENU_RING_COORDS[2],
        BLUEMENU_RING_COORDS[3], BLUEMENU_RING_COORDS[4])
    button.ring = ring

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetSize(40, 40)
    icon:SetPoint("CENTER", ring, "CENTER", 0, 0)
    SetTextureOrFallback(icon, iconTexture, "Interface\\Icons\\INV_Misc_QuestionMark")
    -- Trim the square icon edges so the corners stay behind the round ring.
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", ring, "RIGHT", 4, 0)
    text:SetWidth(104)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    text:SetTextColor(1, 0.82, 0)
    button.text = text

    UpdateRetailNavButtonArt(button, "normal")

    button:SetScript("OnClick", function(...)
        PlayUISound("igMainMenuOptionCheckBoxOn")
        onClick(...)
    end)

    self.retailNavButtons = self.retailNavButtons or {}
    self.retailNavButtons[key] = button
    return button
end

-- Category banner art for the Premade Groups home list (retail LFGList
-- category buttons: illustrated banner + stone cover + highlight/select art).
local PREMADE_CATEGORY_BANNERS = {
    quest = "button-questing",
    mythic = "button-dungeons",
    raid = "button-raids",
    hlbg = "button-battlegrounds",
    live = "button-scenarios",
    queues = "button-custom-pve",
    other = "button-custom-pvp",
}

function GF:CreateRetailPremadeCategoryButton(parent, kind, label, yOffset)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(math.max((parent:GetWidth() or 0) - 8, 282), 46)
    button:SetPoint("TOPLEFT", 0, yOffset)
    button.kind = kind

    -- Illustrated category banner (falls back to a plain dark row).
    local banner = button:CreateTexture(nil, "BACKGROUND")
    banner:SetAllPoints()
    if not SetGFAtlas(banner, PREMADE_CATEGORY_BANNERS[kind] or "button-custom-pve") then
        SetSolidTexture(banner, 0, 0, 0, 0.45)
    end
    button.banner = banner

    -- Stone frame cover over the banner (retail draws this on every row).
    local cover = button:CreateTexture(nil, "BORDER")
    cover:SetAllPoints()
    SetGFAtlas(cover, "button-cover")
    button.bg = cover

    -- Gold select bar overlay for the active category.
    local select = button:CreateTexture(nil, "ARTWORK")
    select:SetAllPoints()
    SetGFAtlas(select, "button-select")
    select:Hide()
    button.selectOverlay = select

    local labelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    labelText:SetPoint("LEFT", 18, 0)
    labelText:SetWidth(button:GetWidth() - 40)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)
    button.label = labelText

    -- Blue highlight bar on hover (retail LFGList row hover).
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    SetGFAtlas(highlight, "highlightbar-blue")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.65)
    button:SetHighlightTexture(highlight)

    button:SetScript("OnClick", function(self)
        PlayUISound("igMainMenuOptionCheckBoxOn")
        GF.premadeSelectedKind = self.kind
        GF:RefreshRetailPremadeSelection()
        GF:SelectCompactType(self.kind)
    end)

    self.premadeCategoryButtons = self.premadeCategoryButtons or {}
    self.premadeCategoryButtons[kind] = button
    return button
end

function GF:CreateCompactMainFrame()
    if self.mainFrame then return self.mainFrame end

    local frame = CreateFrame("Frame", "DCMythicPlusGroupFinderFrame", UIParent)
    frame:SetSize(self.FRAME_WIDTH, self.FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    -- Scale the whole window up a touch for readability (enlarges art + fonts
    -- uniformly without disturbing the internal layout).
    frame:SetScale(1.08)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    -- Standard DC addon look: FelLeather dark parchment + tint behind the gold
    -- dialog border (matches DC-Leaderboards et al.).
    ApplyLeaderboardsStyle(frame)

    -- Retail open/close feedback + keep the micro-menu eye state in sync
    -- (this window replaces the stock Dungeon Finder).
    frame:SetScript("OnShow", function()
        PlayUISound("igCharacterInfoOpen")
        if UpdateMicroButtons then UpdateMicroButtons() end
    end)
    frame:SetScript("OnHide", function()
        PlayUISound("igCharacterInfoClose")
        if UpdateMicroButtons then UpdateMicroButtons() end
    end)

    -- Title header band: retail drags by the header only, not the whole frame.
    -- Stops short of the top-right corner so it can't swallow the close
    -- button's clicks.
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", -44, -6)
    header:SetHeight(28)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Thin retail divider line under the header band.
    local headerDivider = frame:CreateTexture(nil, "ARTWORK")
    headerDivider:SetPoint("TOPLEFT", 14, -32)
    headerDivider:SetPoint("TOPRIGHT", -14, -32)
    headerDivider:SetHeight(3)
    if not SetGFAtlas(headerDivider, "divider") then
        SetSolidTexture(headerDivider, 0.35, 0.30, 0.20, 0.8)
    end

    -- Group Finder eye: golden atlas glow behind the stock WotLK LFR eye.
    -- (The old standalone eye .tga rips were non-power-of-two and never
    -- actually loaded on 3.3.5a — the atlas region does.)
    local portraitBackglow = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    portraitBackglow:SetSize(34, 34)
    portraitBackglow:SetPoint("TOPLEFT", 8, -3)
    if not SetGFAtlas(portraitBackglow, "eye-highlight") then
        SetTextureOrFallback(portraitBackglow, LFG_PORTRAIT_TEXTURE, nil)
    end
    portraitBackglow:SetVertexColor(1, 1, 1, 0.9)

    local portrait = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    portrait:SetSize(24, 24)
    portrait:SetPoint("CENTER", portraitBackglow, "CENTER", 0, 0)
    SetTextureOrFallback(portrait, LFG_PORTRAIT_TEXTURE,
        "Interface\\LFGFrame\\LFG-Eye")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Group Finder")
    title:SetTextColor(1, 0.82, 0)
    frame.TitleText = title

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    -- Keep the X above the drag header so it always receives its clicks.
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local navPanel = CreateFrame("Frame", nil, frame)
    -- Start below the title header band so the "Group Finder" title isn't covered.
    navPanel:SetPoint("TOPLEFT", 4, -34)
    navPanel:SetPoint("BOTTOMLEFT", 4, 14)
    navPanel:SetWidth(175)

    -- Retail PVEFrame left-nav: the big blue-black bluemenu panel with the
    -- filigree corner accents (no tooltip-border box).
    local navBg = navPanel:CreateTexture(nil, "BACKGROUND")
    navBg:SetAllPoints()
    navBg:SetTexture(RETAIL_BLUEMENU_MAIN)
    navBg:SetTexCoord(BLUEMENU_BG_COORDS[1], BLUEMENU_BG_COORDS[2],
        BLUEMENU_BG_COORDS[3], BLUEMENU_BG_COORDS[4])

    -- NOTE: no corner accent pieces — the corner regions in this bluemenu
    -- rip don't match the retail 11.2.7 XML coords (they sample the white
    -- glow blocks instead of the filigree art) and rendered as grey blobs.
    -- The plain blue panel matches the retail read fine without them.

    -- y-offsets within navPanel (starts at frame y=-24).
    -- Button 1 at -46 → absolute frame y=-70, matching retail TOPLEFT(10,-70).
    -- Each subsequent button: previous_top - 60(height) - 23(gap) = -129, -212.
    self:CreateRetailNavButton(navPanel, "dungeon", "Dungeon\nFinder",
        "Interface\\Icons\\INV_Helmet_08", -46, function()
        GF.retailNavContext = nil
        GF:SelectCompactType("dungeons")
    end)
    self:CreateRetailNavButton(navPanel, "raid", "Raid\nFinder",
        "Interface\\Icons\\Achievement_Boss_Kelthuzad_01", -129, function()
        GF.retailNavContext = nil
        GF:SelectCompactType("raid")
    end)
    self:CreateRetailNavButton(navPanel, "premade", "Premade\nGroups",
        "Interface\\Icons\\Achievement_General_StayClassy", -212, function()
        GF:ShowRetailPremadeHome(GF.premadeSelectedKind or "mythic")
    end)
    self:CreateRetailNavButton(navPanel, "hlbg", "Hinterland\nBG",
        "Interface\\Icons\\INV_BannerPVP_01", -295, function()
        GF:ShowHinterlandPanel()
    end)

    local contentPanel = CreateFrame("Frame", nil, frame)
    contentPanel:SetPoint("TOPLEFT", navPanel, "TOPRIGHT", 4, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", -4, 14)

    -- Retail Group Finder content background (grey stone panel from the
    -- retail atlas), replacing the tooltip-border box + flat fill.
    local contentBg = contentPanel:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    if not SetGFAtlas(contentBg, "background") then
        SetSolidTexture(contentBg, 0, 0, 0, 0.35)
    end

    -- The active category is already shown by the left nav button + selection
    -- bar, so retail doesn't repeat it as a content header. Keep the field (so
    -- SetText calls elsewhere stay safe) but hide it to avoid a redundant title.
    local contentTitle = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    contentTitle:SetPoint("TOPLEFT", 16, -16)
    contentTitle:SetText("")
    contentTitle:SetTextColor(1, 0.82, 0)
    contentTitle:Hide()
    self.retailContentTitle = contentTitle

    local browserFrame = CreateFrame("Frame", nil, contentPanel)
    browserFrame:SetPoint("TOPLEFT", 6, -14)
    browserFrame:SetPoint("BOTTOMRIGHT", -6, 68)
    self.compactBrowserFrame = browserFrame

    local rolePanel = CreateFrame("Frame", nil, browserFrame)
    rolePanel:SetPoint("TOPLEFT", 0, -4)
    rolePanel:SetPoint("TOPRIGHT", 0, -4)
    rolePanel:SetHeight(64)

    -- Subtle dark strip behind the role buttons (retail sets them straight on
    -- the panel background; the old warm-brown cover tint clashed with the
    -- grey retail art).
    local roleBg = rolePanel:CreateTexture(nil, "BACKGROUND")
    roleBg:SetPoint("TOPLEFT", 8, -2)
    roleBg:SetPoint("TOPRIGHT", -8, -2)
    roleBg:SetHeight(60)
    SetSolidTexture(roleBg, 0, 0, 0, 0.25)

    self.compactRoles = self.compactRoles or { dps = true }
    local canTank, canHeal = GetClassRoleCaps()
    -- Roles the player's class cannot fill must never be selected.
    if not canTank then self.compactRoles.tank = false end
    if not canHeal then self.compactRoles.healer = false end
    self.compactRoleButtons = {}
    -- 4 role rings spread across the ~264px content width (step 64, from x=8).
    self:CreateCompactRoleButton(rolePanel, "tank", 8, self.compactRoles.tank, "Tank", canTank)
    self:CreateCompactRoleButton(rolePanel, "healer", 72, self.compactRoles.healer, "Healer", canHeal)
    self:CreateCompactRoleButton(rolePanel, "dps", 136, self.compactRoles.dps, "Damage", true)
    self:CreateCompactRoleButton(rolePanel, "leader", 200, self.compactRoles.leader, "Leader", true)
    if not canTank and self.compactRoleButtons.tank then
        self.compactRoleButtons.tank:Disable()
        self.compactRoleButtons.tank:SetAlpha(0.45)
    end
    if not canHeal and self.compactRoleButtons.healer then
        self.compactRoleButtons.healer:Disable()
        self.compactRoleButtons.healer:SetAlpha(0.45)
    end
    self:UpdateCompactRoleButtons()

    local typeLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    typeLabel:SetPoint("TOPLEFT", rolePanel, "BOTTOMLEFT", 18, -10)
    typeLabel:SetText("Type:")
    typeLabel:SetTextColor(1, 0.82, 0)
    self.compactTypeLabel = typeLabel

    local typeButton = CreateRetailActionButton(browserFrame, 250, 28)
    typeButton:SetPoint("LEFT", typeLabel, "RIGHT", 10, 0)
    typeButton:SetScript("OnClick", function() GF:ToggleCompactTypeMenu() end)
    self.compactTypeButton = typeButton

    local typeText = typeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    typeText:SetPoint("CENTER", -8, 0)
    typeText:SetText("Specific Dungeons")
    self.compactTypeButtonText = typeText

    -- Real dropdown arrow texture (the stock scroll-down chevron), replacing
    -- the old ASCII "v" glyph.
    local arrow = typeButton:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(18, 18)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    -- Dungeon difficulty selector ("Specific Dungeons" only): the matchmaking
    -- queue supports Normal and Heroic here; Mythic runs through the Mythic+
    -- type instead. The label starts at the same x as "Type:" so the row
    -- stays inside the content panel.
    local diffLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    diffLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -16)
    diffLabel:SetText("Difficulty:")
    diffLabel:SetTextColor(1, 0.82, 0)
    self.compactDiffLabel = diffLabel

    local diffButton = CreateRetailActionButton(browserFrame, 140, 24)
    diffButton:SetPoint("LEFT", diffLabel, "RIGHT", 10, 0)
    diffButton:SetScript("OnClick", function() GF:CycleQueueDifficulty() end)
    diffButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Dungeon Difficulty", 1, 1, 1)
        GameTooltip:AddLine("Click to switch between Normal and Heroic.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    diffButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.compactDiffButton = diffButton

    -- Full-frame click-catcher that blocks background clicks/scroll while the
    -- type dropdown is open and closes it when clicking away (retail behaviour).
    local menuCatcher = CreateFrame("Button", nil, frame)
    menuCatcher:SetAllPoints(frame)
    menuCatcher:SetFrameStrata("DIALOG")
    menuCatcher:SetFrameLevel(frame:GetFrameLevel() + 25)
    menuCatcher:EnableMouse(true)
    menuCatcher:EnableMouseWheel(true)
    menuCatcher:SetScript("OnMouseWheel", function() end)
    menuCatcher:SetScript("OnClick", function() GF:ToggleCompactTypeMenu() end)
    menuCatcher:Hide()
    self.compactTypeMenuCatcher = menuCatcher

    local menu = CreateFrame("Frame", "DCCompactGroupFinderTypeMenu", contentPanel)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(frame:GetFrameLevel() + 30)
    menu:SetSize(220, 22 * #self.COMPACT_OPTION_ORDER + 8)
    menu:SetPoint("TOPRIGHT", typeButton, "BOTTOMRIGHT", 0, -2)
    -- Retail dropdown look: near-black panel with a thin dark edge.
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    if menu.SetBackdropColor then
        menu:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
    end
    if menu.SetBackdropBorderColor then
        menu:SetBackdropBorderColor(0.4, 0.4, 0.45, 0.9)
    end
    menu:Hide()
    self.compactTypeMenu = menu

    -- One reusable item per option; RebuildCompactTypeMenu positions the ones
    -- allowed in the active nav section each time the menu opens.
    menu.items = {}
    for _, kind in ipairs(self.COMPACT_OPTION_ORDER) do
        local option = self.COMPACT_OPTIONS[kind]
        local item = CreateFrame("Button", nil, menu)
        item:SetSize(206, 20)
        item:SetNormalFontObject("GameFontHighlightSmall")
        local itemHighlight = item:CreateTexture(nil, "HIGHLIGHT")
        itemHighlight:SetAllPoints()
        SetGFAtlas(itemHighlight, "highlightbar-blue")
        itemHighlight:SetBlendMode("ADD")
        itemHighlight:SetAlpha(0.7)
        item:SetHighlightTexture(itemHighlight)
        item:SetText(option.label)
        item:SetScript("OnClick", function()
            PlayUISound("UChatScrollButton")
            GF.compactTypeMenu:Hide()
            if GF.compactTypeMenuCatcher then GF.compactTypeMenuCatcher:Hide() end
            GF:SelectCompactType(kind)
        end)
        item:Hide()
        menu.items[kind] = item
    end

    local listFrame = CreateFrame("Frame", nil, browserFrame)
    listFrame:SetPoint("TOPLEFT", 6, -116)
    listFrame:SetPoint("BOTTOMRIGHT", -6, 0)
    self.compactListFrame = listFrame

    -- Recessed dark results inset (retail-style: dark area, no chunky border,
    -- separated from the filters above by a thin divider).
    local listBg = listFrame:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    SetSolidTexture(listBg, 0, 0, 0, 0.55)

    local listDivider = listFrame:CreateTexture(nil, "ARTWORK")
    listDivider:SetPoint("TOPLEFT", 2, 2)
    listDivider:SetPoint("TOPRIGHT", -2, 2)
    listDivider:SetHeight(3)
    if not SetGFAtlas(listDivider, "divider") then
        SetSolidTexture(listDivider, 0.35, 0.30, 0.20, 0.8)
    end

    local scroll = CreateFrame("ScrollFrame", "DCCompactGroupFinderScroll", listFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -18, 28)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(312, 220)
    scroll:SetScrollChild(child)
    self.compactScrollChild = child
    self.compactRowWidth = 308

    -- Thin retail-style scrollbar: hide the arrow buttons, slim the track to
    -- a 6px gutter with a minimal thumb.
    local scrollBar = _G["DCCompactGroupFinderScrollScrollBar"]
    if scrollBar then
        local up = _G["DCCompactGroupFinderScrollScrollBarScrollUpButton"]
        local down = _G["DCCompactGroupFinderScrollScrollBarScrollDownButton"]
        if up then up:SetAlpha(0); up:SetSize(1, 1); up:EnableMouse(false) end
        if down then down:SetAlpha(0); down:SetSize(1, 1); down:EnableMouse(false) end
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -4, -10)
        scrollBar:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 30)
        scrollBar:SetWidth(6)
        local thumb = scrollBar:GetThumbTexture()
        if thumb then
            thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
            thumb:SetVertexColor(0.55, 0.55, 0.60, 0.85)
            thumb:SetSize(6, 48)
        end
    end

    local results = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    results:SetPoint("BOTTOMLEFT", 10, 8)
    results:SetText("Results: 0")
    self.compactResultsText = results

    local homeFrame = CreateFrame("Frame", nil, contentPanel)
    homeFrame:SetPoint("TOPLEFT", 6, -14)
    homeFrame:SetPoint("BOTTOMRIGHT", -6, 64)
    homeFrame:Hide()
    self.retailHomeFrame = homeFrame
    if homeFrame.SetBackdropColor then
        homeFrame:SetBackdropColor(0, 0, 0, 0.08)
    end

    local homeBg = homeFrame:CreateTexture(nil, "BACKGROUND")
    homeBg:SetAllPoints()
    SetSolidTexture(homeBg, 0.04, 0.06, 0.13, 1)

    local categoryY = -6
    for _, kind in ipairs(self.PREMADE_CATEGORY_ORDER) do
        local option = self.COMPACT_OPTIONS[kind]
        if option then
            self:CreateRetailPremadeCategoryButton(homeFrame, kind, option.label, categoryY)
            categoryY = categoryY - 49
        end
    end

    -- Hinterland BG queue panel (mirrors the standalone DC-HinterlandBG
    -- Queue tab: live status text + join/leave through the HLBG helpers).
    local hlbgPanel = CreateFrame("Frame", nil, contentPanel)
    hlbgPanel:SetPoint("TOPLEFT", 6, -14)
    hlbgPanel:SetPoint("BOTTOMRIGHT", -6, 64)
    hlbgPanel:Hide()
    self.hlbgPanel = hlbgPanel

    local hlbgBg = hlbgPanel:CreateTexture(nil, "BACKGROUND")
    hlbgBg:SetAllPoints()
    SetSolidTexture(hlbgBg, 0, 0, 0, 0.45)

    local hlbgTitle = hlbgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hlbgTitle:SetPoint("TOP", 0, -16)
    hlbgTitle:SetText("Hinterland Battleground")
    hlbgTitle:SetTextColor(1, 0.82, 0)

    local hlbgStatus = hlbgPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hlbgStatus:SetPoint("TOP", hlbgTitle, "BOTTOM", 0, -20)
    hlbgStatus:SetWidth(310)
    hlbgStatus:SetJustifyH("CENTER")
    hlbgStatus:SetText("")
    hlbgPanel.status = hlbgStatus

    hlbgPanel:SetScript("OnShow", function(panel)
        panel._refreshAcc = 0
        GF:RequestHinterlandStatus()
        GF:UpdateHinterlandPanel()
    end)
    -- 10s auto-refresh while visible (same cadence as the standalone addon).
    hlbgPanel:SetScript("OnUpdate", function(panel, elapsed)
        panel._refreshAcc = (panel._refreshAcc or 0) + elapsed
        if panel._refreshAcc < 10 then return end
        panel._refreshAcc = 0
        GF:RequestHinterlandStatus()
    end)

    local primary = CreateRetailActionButton(contentPanel, 110, 26, "Find Group")
    primary:SetPoint("BOTTOMLEFT", 10, 12)
    primary:SetScript("OnClick", function() GF:CompactPrimaryAction() end)
    self.compactPrimaryButton = primary

    local create = CreateRetailActionButton(contentPanel, 116, 26, "Start Group")
    create:SetPoint("BOTTOM", 0, 12)
    create:SetScript("OnClick", function()
        GF:ShowCompactCreateDialog(GF.retailHomeShown and GF.premadeSelectedKind or GF.compactSelectedKind or "mythic")
    end)
    self.compactCreateButton = create

    local close = CreateRetailActionButton(contentPanel, 88, 26, "Close")
    close:SetPoint("BOTTOMRIGHT", -10, 12)
    close:SetScript("OnClick", function() frame:Hide() end)

    local statusText = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOM", 0, 52)
    statusText:SetWidth(340)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("")
    frame.StatusText = statusText

    self.mainFrame = frame
    self.compactMode = true
    self.compactData = self.compactData or {}
    self.compactCategoryButton = nil
    self:SelectCompactType("dungeons")

    -- Bottom tabs (retail PVEFrame style: Dungeon Finder | Battlegrounds | Mythic+)
    self:CreateBottomTabs(frame)

    tinsert(UISpecialFrames, "DCMythicPlusGroupFinderFrame")
    return frame
end

-- The real seasonal Mythic+ dungeon set (dc_mplus_dungeons): local DLL list
-- first, then the server-pushed list (GRPF 0x42). Returns nil when nothing is
-- cached yet. This is intentionally NOT the full Normal/Heroic queue catalog.
function GF:GetSeasonalDungeonList()
    local list
    if type(namespace.GetMythicPlusDungeonList) == "function" then
        list = namespace.GetMythicPlusDungeonList()
    end
    if type(list) == "table" and #list > 0 then
        return list
    end

    if type(self.serverDungeonList) == "table" and #self.serverDungeonList > 0 then
        return self.serverDungeonList
    end

    return nil
end

-- Best dungeon data available for the Mythic+ panel grid: the seasonal list,
-- falling back to queue catalog names. Returns nil when nothing is cached yet.
function GF:GetMythicPortalDungeons()
    local dungeons = self:GetSeasonalDungeonList()
    if dungeons then
        return dungeons
    end

    local catalog = self.queueCatalog and self.queueCatalog.dungeons
    if type(catalog) == "table" and #catalog > 0 then
        local out = {}
        for _, d in ipairs(catalog) do
            table.insert(out, { mapId = d.mapId, name = d.name })
        end
        return out
    end

    return nil
end

function GF:OpenMythicPlusPanel()
    -- Retail's Mythic+ tab opens the keystone/season panel. Our analogue is the
    -- Seasonal Portal (dungeon grid with art + timer + level + rating).
    local portal = namespace.SeasonalPortalUI
    if not (portal and type(portal.Show) == "function") then
        -- Fallback: keep the player in the group finder on the Mythic+ dungeon
        -- view and pull the live dungeon list so rows populate.
        self:SelectCompactType("mythic")
        local DC = GetDCProtocol()
        if DC and DC.GroupFinder and DC.GroupFinder.GetDungeonList then
            DC.GroupFinder.GetDungeonList()
        end
        return false
    end

    local dungeons = self:GetMythicPortalDungeons()
    local DC = GetDCProtocol()

    if dungeons and type(portal.Preview) == "function" then
        self._pendingMythicPortalSeed = nil
        local seasonId
        if DC and type(DC._serverContext) == "table" then
            seasonId = tonumber(DC._serverContext.seasonId)
        end
        portal:Preview({ dungeons = dungeons, difficulty = 3, seasonId = seasonId })
        if portal.frame and portal.frame.result then
            portal.frame.result:SetText("")
        end
    else
        -- Nothing cached yet: open the portal with a loading note and fill the
        -- grid when the server data arrives (UpdateDungeonList/OnQueueCatalog
        -- call TrySeedPendingMythicPortal).
        self._pendingMythicPortalSeed = true
        portal:Show()
        if portal.frame and portal.frame.result then
            portal.frame.result:SetText("Requesting dungeon list from the server...")
        end
        if DC and DC.GroupFinder and DC.GroupFinder.GetDungeonList then
            DC.GroupFinder.GetDungeonList()
        end
        if self.RequestQueueCatalog then
            self:RequestQueueCatalog()
        end
    end
    return true
end

-- Called when fresh server dungeon data lands while the portal waits for it.
function GF:TrySeedPendingMythicPortal()
    if not self._pendingMythicPortalSeed then return end

    local portal = namespace.SeasonalPortalUI
    if not (portal and portal.frame and portal.frame:IsShown()) then
        -- The portal was closed while waiting; drop the pending seed.
        self._pendingMythicPortalSeed = nil
        return
    end

    if self:GetMythicPortalDungeons() then
        self:OpenMythicPlusPanel()
    end
end

function GF:CreateBottomTabs(frame)
    -- Retail-style bottom tab names (Dungeons & Raids / Player vs Player / Mythic+).
    local TAB_DEFS = {
        { key = "finder",  label = "Dungeons & Raids", onClick = function()
            GF.retailNavContext = nil
            GF:SelectCompactType("dungeons")
        end },
        { key = "pvp",     label = "Player vs Player",  onClick = function()
            GF:ShowPvPPanel()
        end },
        { key = "mythic",  label = "Mythic+",        onClick = function()
            GF:ShowMythicPanel()
        end },
    }

    -- Real Blizzard folder tabs: CharacterFrameTabButtonTemplate is the stock
    -- 3.3.5 bottom-tab art (the retail-era name PanelTabButtonTemplate doesn't
    -- exist in this client, but this is the same visual).
    self.bottomTabs = {}
    self.bottomTabOrder = {}

    local previous
    for i, def in ipairs(TAB_DEFS) do
        local tab = CreateFrame("Button", "DCGroupFinderBottomTab" .. i, frame,
            "CharacterFrameTabButtonTemplate")
        tab.key = def.key
        tab:SetText(def.label)
        tab:SetID(i)

        if previous then
            tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", -14, 0)
        else
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 4)
        end
        previous = tab

        if PanelTemplates_TabResize then
            PanelTemplates_TabResize(tab, 0)
        end

        tab:SetScript("OnClick", function()
            PlayUISound("igCharacterInfoTab")
            def.onClick()
        end)

        self.bottomTabs[def.key] = tab
        table.insert(self.bottomTabOrder, tab)
    end

    self:SetActiveBottomTab("finder")
end

function GF:SetActiveBottomTab(activeKey)
    for key, tab in pairs(self.bottomTabs or {}) do
        local isActive = key == activeKey
        tab.isActive = isActive
        if isActive then
            if PanelTemplates_SelectTab then
                PanelTemplates_SelectTab(tab)
            end
        else
            if PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(tab)
            end
        end
    end
end

-- =====================================================================
-- In-frame PvP panel (bottom tab) — keeps the player inside the Group
-- Finder instead of bouncing them out to the stock PVPParentFrame.
-- =====================================================================

function GF:ShowPvPPanel()
    if not self.mainFrame then return end

    -- Hide the other content views.
    self.retailHomeShown = false
    self.hlbgPanelShown = false
    if self.compactTypeMenu then self.compactTypeMenu:Hide() end
    if self.compactTypeMenuCatcher then self.compactTypeMenuCatcher:Hide() end
    if self.compactBrowserFrame then self.compactBrowserFrame:Hide() end
    if self.compactListFrame then self.compactListFrame:Hide() end
    if self.retailHomeFrame then self.retailHomeFrame:Hide() end
    if self.hlbgPanel then self.hlbgPanel:Hide() end
    if self.mythicPanel then self.mythicPanel:Hide() end

    if not self.pvpPanel then
        local panel = CreateFrame("Frame", nil, self.pvpPanelParent or self.mainFrame)
        panel:SetPoint("TOPLEFT", self.compactBrowserFrame, "TOPLEFT", 0, 0)
        panel:SetPoint("BOTTOMRIGHT", self.compactBrowserFrame, "BOTTOMRIGHT", 0, 0)

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -10)
        title:SetText("Player vs Player")
        title:SetTextColor(1, 0.82, 0)

        local ROWS = {
            { label = "Hinterland BG", banner = "button-battlegrounds",
              onClick = function() GF:ShowHinterlandPanel() end },
            { label = "Battlegrounds", banner = "button-battlegrounds",
              onClick = function()
                  if not GF:ToggleBlizzardPVP() then
                      GF:SetStatusMessage("PvP frame is not available.")
                  end
              end },
            { label = "Arenas", banner = "button-arenas",
              onClick = function()
                  if not GF:ToggleBlizzardPVP() then
                      GF:SetStatusMessage("PvP frame is not available.")
                  end
              end },
        }

        local y = -44
        for _, def in ipairs(ROWS) do
            local row = CreateFrame("Button", nil, panel)
            row:SetSize(math.max((panel:GetWidth() or 0) - 12, 282), 46)
            row:SetPoint("TOPLEFT", 4, y)

            local banner = row:CreateTexture(nil, "BACKGROUND")
            banner:SetAllPoints()
            if not SetGFAtlas(banner, def.banner) then
                SetSolidTexture(banner, 0, 0, 0, 0.45)
            end

            local cover = row:CreateTexture(nil, "BORDER")
            cover:SetAllPoints()
            SetGFAtlas(cover, "button-cover")

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            label:SetPoint("LEFT", 18, 0)
            label:SetText(def.label)

            local highlight = row:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            SetGFAtlas(highlight, "highlightbar-blue")
            highlight:SetBlendMode("ADD")
            highlight:SetAlpha(0.65)
            row:SetHighlightTexture(highlight)

            row:SetScript("OnClick", function()
                PlayUISound("igMainMenuOptionCheckBoxOn")
                def.onClick()
            end)

            y = y - 50
        end

        self.pvpPanel = panel
    end

    self.pvpPanel:Show()
    if self.retailContentTitle then
        self.retailContentTitle:SetText("Player vs Player")
    end
    self:SetActiveBottomTab("pvp")
end

-- =====================================================================
-- In-frame Mythic+ panel (bottom tab) — keystone, weekly affixes, best
-- runs, and shortcuts to the M+ group browser and the Great Vault.
-- The Seasonal Portal (teleporter) frame stays a separate window: it is
-- opened by the Mythic+ teleporter NPC (SMSG_SEASONAL_PORTAL_OPEN) and is
-- intentionally NOT embedded here.
-- =====================================================================

function GF:ShowMythicPanel()
    if not self.mainFrame then return end

    -- Hide the other content views.
    self.retailHomeShown = false
    self.hlbgPanelShown = false
    if self.compactTypeMenu then self.compactTypeMenu:Hide() end
    if self.compactTypeMenuCatcher then self.compactTypeMenuCatcher:Hide() end
    if self.compactBrowserFrame then self.compactBrowserFrame:Hide() end
    if self.compactListFrame then self.compactListFrame:Hide() end
    if self.retailHomeFrame then self.retailHomeFrame:Hide() end
    if self.hlbgPanel then self.hlbgPanel:Hide() end
    if self.pvpPanel then self.pvpPanel:Hide() end

    if not self.mythicPanel then
        local panel = CreateFrame("Frame", nil, self.mainFrame)
        panel:SetPoint("TOPLEFT", self.compactBrowserFrame, "TOPLEFT", 0, 0)
        panel:SetPoint("BOTTOMRIGHT", self.compactBrowserFrame, "BOTTOMRIGHT", 0, 0)

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -8)
        title:SetText("Mythic+")
        title:SetTextColor(1, 0.82, 0)

        -- Keystone
        local keyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        keyLabel:SetPoint("TOPLEFT", 14, -36)
        keyLabel:SetText("Your Keystone:")
        keyLabel:SetTextColor(1, 0.82, 0)

        local keyValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        keyValue:SetPoint("LEFT", keyLabel, "RIGHT", 8, 0)
        keyValue:SetText("|cff888888Unknown|r")
        panel.keyValue = keyValue

        -- Weekly affixes
        local affixLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        affixLabel:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -10)
        affixLabel:SetText("This Week:")
        affixLabel:SetTextColor(1, 0.82, 0)

        local affixValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        affixValue:SetPoint("TOPLEFT", affixLabel, "RIGHT", 8, 5)
        affixValue:SetWidth(240)
        affixValue:SetJustifyH("LEFT")
        affixValue:SetText("|cff888888Requesting...|r")
        panel.affixValue = affixValue

        -- Best runs
        local divider = panel:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", 10, -96)
        divider:SetPoint("TOPRIGHT", -10, -96)
        divider:SetHeight(3)
        if not SetGFAtlas(divider, "divider") then
            SetSolidTexture(divider, 0.35, 0.30, 0.20, 0.8)
        end

        local runsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        runsLabel:SetPoint("TOPLEFT", 14, -106)
        runsLabel:SetText("Best Runs This Season")
        runsLabel:SetTextColor(1, 0.82, 0)

        panel.runLines = {}
        for i = 1, 8 do
            local line = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("TOPLEFT", 20, -106 - i * 18)
            line:SetWidth(320)
            line:SetJustifyH("LEFT")
            line:SetText("")
            panel.runLines[i] = line
        end

        -- Teleporter note (teleports stay on the Seasonal Portal NPC).
        local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("BOTTOM", 0, 42)
        note:SetWidth(330)
        note:SetJustifyH("CENTER")
        note:SetText("Dungeon teleports are available at the Mythic+ teleporter.")

        local browseBtn = CreateRetailActionButton(panel, 150, 26, "Browse M+ Groups")
        browseBtn:SetPoint("BOTTOMLEFT", 14, 8)
        browseBtn:SetScript("OnClick", function()
            GF.retailNavContext = "premade"
            GF.premadeSelectedKind = "mythic"
            GF:SelectCompactType("mythic")
            GF:SearchCustomCategory("mythic")
        end)

        local vaultBtn = CreateRetailActionButton(panel, 130, 26, "Great Vault")
        vaultBtn:SetPoint("BOTTOMRIGHT", -14, 8)
        vaultBtn:SetScript("OnClick", function()
            if namespace.RequestVaultInfo then
                namespace.RequestVaultInfo()
            end
            if namespace.GreatVault and namespace.GreatVault.Show then
                namespace.GreatVault:Show()
            end
        end)

        self.mythicPanel = panel
    end

    self.mythicPanel:Show()
    self:RefreshMythicPanel()
    if self.retailContentTitle then
        self.retailContentTitle:SetText("Mythic+")
    end
    self:SetActiveBottomTab("mythic")

    -- Pull fresh data (cheap requests; server change-gates the heavy parts).
    if namespace.RequestKeyInfo then namespace.RequestKeyInfo() end
    if namespace.RequestAffixes then namespace.RequestAffixes() end
    if namespace.RequestBestRuns then namespace.RequestBestRuns() end
end

-- Repaint the Mythic+ panel from the session caches (called by the Core.lua
-- MPLUS handlers whenever key info / affixes / best runs arrive).
function GF:RefreshMythicPanel()
    local panel = self.mythicPanel
    if not panel or not panel:IsShown() then return end

    -- Keystone (server truth first, inventory scan as fallback).
    local key = namespace.serverKeystone
    local invKey = namespace.inventoryKeystone
    local text = "|cff888888No keystone|r"
    if type(key) == "table" and key.hasKeystone then
        text = string.format("|cffff8000+%d %s|r%s",
            tonumber(key.keystoneLevel) or 0,
            tostring(key.keystoneDungeonName or "Unknown"),
            key.depleted and "  |cff888888(depleted)|r" or "")
    elseif type(invKey) == "table" and invKey.hasKey then
        text = string.format("|cffff8000+%d %s|r",
            tonumber(invKey.level) or 0,
            tostring(invKey.dungeonName or "Unknown"))
    end
    panel.keyValue:SetText(text)

    -- Affixes (session cache, falling back to the SavedVariables cache).
    local affixes = namespace.currentAffixes
    if (not affixes or #affixes == 0) and DCMythicPlusHUDDB
        and DCMythicPlusHUDDB.cache then
        affixes = DCMythicPlusHUDDB.cache.affixes
    end
    if type(affixes) == "table" and #affixes > 0 then
        local names = {}
        for _, affix in ipairs(affixes) do
            if type(affix) == "table" and affix.name then
                table.insert(names, affix.name)
            elseif type(affix) == "string" then
                table.insert(names, affix)
            end
        end
        panel.affixValue:SetText(table.concat(names, ", "))
    else
        panel.affixValue:SetText("|cff888888No affix data yet.|r")
    end

    -- Best runs.
    local runs = namespace.bestRuns
    for i, line in ipairs(panel.runLines) do
        local run = type(runs) == "table" and runs[i] or nil
        if type(run) == "table" then
            local name = run.dungeonName or ("Dungeon " .. tostring(run.dungeonId or "?"))
            local level = tonumber(run.level) or 0
            local secs = tonumber(run.time)
            local timeStr = secs
                and string.format("%d:%02d", math.floor(secs / 60), secs % 60)
                or "?"
            line:SetText(string.format("|cffff8000+%d|r  %s  |cff888888(%s)|r",
                level, name, timeStr))
        elseif i == 1 and (type(runs) ~= "table" or #runs == 0) then
            line:SetText("|cff888888No timed runs recorded yet this season.|r")
        else
            line:SetText("")
        end
    end
end

-- =====================================================================
-- Main Frame Creation
-- =====================================================================

function GF:CreateMainFrame()
    return self:CreateCompactMainFrame()
end

-- The old multi-tab system (CreateTabButtons/SelectTab + the Mythic/Raid/
-- World/LiveRuns/Scheduled tab panels) was unreachable: the compact retail
-- shell is always active and those panels parented to a contentFrame that was
-- never created. Removed; the tab files remain loaded only for their live
-- data providers (dungeon/raid catalogs, applicant panel, spectator HUD).

-- =====================================================================
-- Toggle & Visibility
-- =====================================================================

function GF:Toggle()
    if not self.mainFrame then
        self:CreateMainFrame()
    end

    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:SelectCompactType("dungeons")

        local DC = rawget(_G, "DCAddonProtocol")
        if DC and DC.GroupFinder and DC.GroupFinder.GetSystemInfo then
            DC.GroupFinder.GetSystemInfo()
        end
    end
end

function GF:Show()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    self.mainFrame:Show()
    self:SelectCompactType("dungeons")

    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetSystemInfo then
        DC.GroupFinder.GetSystemInfo()
    end
end

function GF:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

-- Make the DC Group Finder THE standard finder: every stock entry point —
-- the micro-menu eye button, the Dungeon Finder keybind (both run
-- ToggleLFDParentFrame on 3.3.5), the Raid Browser, the legacy LFG frame,
-- and any code that ShowUIPanel()s the stock frames directly — opens this
-- window instead. GF:ToggleBlizzardLFG() (the "Blizzard LFG" type option)
-- sets _allowStockLFG to bypass the redirect when the player explicitly
-- asks for the stock tool.
function GF:InstallBlizzardLFGReplacement()
    if self._blizzardLFGReplacementInstalled then return end

    local function OpenReplacement(kind)
        GF:Show()
        GF.retailNavContext = nil
        GF:SelectCompactType(kind or "dungeons")
        if UpdateMicroButtons then
            UpdateMicroButtons()
        end
    end

    -- 3.3.5 Dungeon Finder: micro button + TOGGLELFGPARENT keybind.
    if type(ToggleLFDParentFrame) == "function" then
        self._originalToggleLFDParentFrame = ToggleLFDParentFrame
        ToggleLFDParentFrame = function(...)
            if GF._allowStockLFG then
                return GF._originalToggleLFDParentFrame(...)
            end

            if GF.mainFrame and GF.mainFrame:IsShown() then
                GF:Hide()
                if UpdateMicroButtons then UpdateMicroButtons() end
            else
                if LFDParentFrame and LFDParentFrame:IsShown() then
                    HideUIPanel(LFDParentFrame)
                end
                OpenReplacement("dungeons")
            end
        end
    end

    -- 3.3.5 Raid Browser: route to our Raid Finder nav.
    if type(ToggleLFRParentFrame) == "function" then
        self._originalToggleLFRParentFrame = ToggleLFRParentFrame
        ToggleLFRParentFrame = function(...)
            if GF._allowStockLFG then
                return GF._originalToggleLFRParentFrame(...)
            end

            if GF.mainFrame and GF.mainFrame:IsShown() then
                GF:Hide()
                if UpdateMicroButtons then UpdateMicroButtons() end
            else
                if LFRParentFrame and LFRParentFrame:IsShown() then
                    HideUIPanel(LFRParentFrame)
                end
                OpenReplacement("raid")
            end
        end
    end

    -- Pre-3.3 legacy LFG window (kept for custom clients that still have it).
    if type(ToggleLFGParentFrame) == "function" then
        self._originalToggleLFGParentFrame = ToggleLFGParentFrame
        ToggleLFGParentFrame = function(tab)
            if GF._allowStockLFG then
                return GF._originalToggleLFGParentFrame(tab)
            end

            if GF.mainFrame and GF.mainFrame:IsShown() then
                GF:Hide()
                if UpdateMicroButtons then UpdateMicroButtons() end
            else
                if LFGParentFrame and LFGParentFrame:IsShown() then
                    HideUIPanel(LFGParentFrame)
                end
                OpenReplacement(tab == 2 and "other" or "dungeons")
            end
        end
    end

    -- Catch direct ShowUIPanel() paths on the stock frames.
    local function RedirectOnShow(frame)
        if frame and frame.HookScript then
            frame:HookScript("OnShow", function(f)
                if GF._allowStockLFG then return end
                f:Hide()
                OpenReplacement("dungeons")
            end)
        end
    end
    RedirectOnShow(LFDParentFrame)
    RedirectOnShow(LFGParentFrame)

    -- Keep the micro-menu eye lit while our window is open (the stock
    -- UpdateMicroButtons only checks LFDParentFrame).
    if type(hooksecurefunc) == "function" and LFDMicroButton then
        hooksecurefunc("UpdateMicroButtons", function()
            if GF.mainFrame and GF.mainFrame:IsShown() then
                LFDMicroButton:SetButtonState("PUSHED", 1)
            end
        end)
    end

    self._blizzardLFGReplacementInstalled = true
end

local replacementInstaller = CreateFrame("Frame")
replacementInstaller:RegisterEvent("PLAYER_LOGIN")
replacementInstaller:SetScript("OnEvent", function()
    GF:InstallBlizzardLFGReplacement()
end)
if type(ToggleLFDParentFrame) == "function"
    or type(ToggleLFGParentFrame) == "function" then
    GF:InstallBlizzardLFGReplacement()
end

-- (Legacy per-tab Show* functions removed with the dead tab system.)

function GF:RefreshMyQueues()
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetMyApplications then
        DC.GroupFinder.GetMyApplications()
    end
end

function GF:UpdateMyApplications(applications)
    if type(applications) ~= "table" then
        applications = {}
    elseif applications[1] == nil then
        local normalized = {}
        for _, entry in pairs(applications) do
            if type(entry) == "table" then
                table.insert(normalized, entry)
            end
        end
        applications = normalized
    end

    self.myApplications = applications
    self:CompactPopulateApplications(applications)
end

function GF:CancelMyApplication(listingId)
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.CancelApplication then
        DC.GroupFinder.CancelApplication(listingId)
    end
end

-- Application Dialog
function GF:ShowApplicationDialog(listingId, dungeonName)
    if not self.appDialog then
        local frame = CreateFrame("Frame", "DCGroupFinderAppDialog", UIParent)
        frame:SetSize(300, 250)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        
        -- Background
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        ApplyLeaderboardsStyle(frame)
        
        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Apply to Group")
        title:SetTextColor(1, 0.82, 0) -- Gold
        frame.title = title
        
        -- Role Checkboxes
        local tankCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleTank", frame, "UICheckButtonTemplate")
        tankCb:SetPoint("TOPLEFT", 40, -50)
        _G[tankCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t Tank")
        frame.tankCb = tankCb
        
        local healerCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleHealer", frame, "UICheckButtonTemplate")
        healerCb:SetPoint("TOPLEFT", 120, -50)
        _G[healerCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t Healer")
        frame.healerCb = healerCb
        
        local dpsCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleDPS", frame, "UICheckButtonTemplate")
        dpsCb:SetPoint("TOPLEFT", 200, -50)
        _G[dpsCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t Damage")
        frame.dpsCb = dpsCb
        
        -- Note EditBox
        local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noteLabel:SetPoint("TOPLEFT", 20, -90)
        noteLabel:SetText("Note (optional):")
        noteLabel:SetTextColor(1, 0.82, 0) -- Gold
        
        local noteBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        noteBox:SetSize(260, 20)
        noteBox:SetPoint("TOPLEFT", 25, -110)
        noteBox:SetAutoFocus(false)
        frame.noteBox = noteBox
        
        -- Buttons
        local applyBtn = CreateRetailActionButton(frame, 100, 25, "Apply")
        applyBtn:SetPoint("BOTTOMLEFT", 40, 20)
        applyBtn:SetScript("OnClick", function()
            local roleMask = 0
            if frame.tankCb:GetChecked() then roleMask = roleMask + 1 end
            if frame.healerCb:GetChecked() then roleMask = roleMask + 2 end
            if frame.dpsCb:GetChecked() then roleMask = roleMask + 4 end
            
            if roleMask == 0 then
                GF.Print("Please select at least one role.")
                return
            end
            
            local note = frame.noteBox:GetText()
            local DC = rawget(_G, "DCAddonProtocol")
            if DC and DC.GroupFinder then
                DC.GroupFinder.Apply(frame.listingId, roleMask, note)
            end
            frame:Hide()
        end)
        
        local cancelBtn = CreateRetailActionButton(frame, 100, 25, "Cancel")
        cancelBtn:SetPoint("BOTTOMRIGHT", -40, 20)
        cancelBtn:SetScript("OnClick", function() frame:Hide() end)

        self.appDialog = frame
    end
    
    -- Update role checkboxes based on class
    local _, classFilename = UnitClass("player")
    local canTank = false
    local canHeal = false
    local canDPS = true -- Everyone can DPS
    
    if classFilename == "WARRIOR" or classFilename == "DEATHKNIGHT" or classFilename == "PALADIN" or classFilename == "DRUID" then
        canTank = true
    end
    
    if classFilename == "PRIEST" or classFilename == "SHAMAN" or classFilename == "PALADIN" or classFilename == "DRUID" then
        canHeal = true
    end
    
    -- Configure checkboxes
    if canTank then
        self.appDialog.tankCb:Enable()
        self.appDialog.tankCb:SetAlpha(1)
    else
        self.appDialog.tankCb:Disable()
        self.appDialog.tankCb:SetChecked(false)
        self.appDialog.tankCb:SetAlpha(0.5)
    end
    
    if canHeal then
        self.appDialog.healerCb:Enable()
        self.appDialog.healerCb:SetAlpha(1)
    else
        self.appDialog.healerCb:Disable()
        self.appDialog.healerCb:SetChecked(false)
        self.appDialog.healerCb:SetAlpha(0.5)
    end
    
    local selectedRoles = self.compactRoles or { dps = true }
    self.appDialog.tankCb:SetChecked(canTank and selectedRoles.tank or false)
    self.appDialog.healerCb:SetChecked(canHeal and selectedRoles.healer or false)
    self.appDialog.dpsCb:SetChecked(selectedRoles.dps ~= false)

    if not self.appDialog.tankCb:GetChecked() and not self.appDialog.healerCb:GetChecked() and not self.appDialog.dpsCb:GetChecked() then
        if canTank then self.appDialog.tankCb:SetChecked(true)
        elseif canHeal then self.appDialog.healerCb:SetChecked(true)
        else self.appDialog.dpsCb:SetChecked(true) end
    end
    
    self.appDialog.listingId = listingId
    self.appDialog.title:SetText("Apply to " .. (dungeonName or "Group"))
    self.appDialog.noteBox:SetText("")
    self.appDialog:Show()
end

-- =====================================================================
-- Reward Display
-- =====================================================================

function GF:CreateRewardFrame()
    if self.rewardFrame then return end
    
    local frame = CreateFrame("Frame", nil, self.mainFrame)
    frame:SetSize(300, 30)
    frame:SetPoint("BOTTOMLEFT", 14, 10)
    frame:SetFrameLevel(self.mainFrame:GetFrameLevel() + 20)
    
    -- Label
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetText("Daily Reward:")
    label:SetTextColor(1, 0.82, 0) -- Gold
    frame.label = label
    
    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", label, "RIGHT", 5, 0)
    frame.icon = icon
    
    -- Count
    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    frame.count = count
    
    self.rewardFrame = frame
    self.rewardFrame:Hide() -- Hide until data received
end

function GF:UpdateSystemInfo(data)
    if not self.mainFrame then return end

    if self.compactMode then
        if data.rewardEnabled and self.mainFrame.StatusText then
            self.mainFrame.StatusText:SetText("Daily reward available")
        end
        return
    end

    if not self.rewardFrame then self:CreateRewardFrame() end
    
    if data.rewardEnabled then
        self.rewardFrame:Show()
        
        local text = ""
        local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        
        local rewardItemId = tonumber(data.rewardItemId) or 0
        local rewardItemCount = tonumber(data.rewardItemCount) or 1

        -- Prefer central Upgrade Token if server is still sending a placeholder (commonly 49426 = Emblem of Frost)
        local centralTokenId = (rawget(_G, "DCAddonProtocol") and rawget(_G, "DCAddonProtocol").TOKEN_ITEM_ID) or 0
        if centralTokenId > 0 and (rewardItemId == 0 or rewardItemId == 49426) then
            rewardItemId = centralTokenId
            rewardItemCount = 1
        end

        if rewardItemId > 0 then
            local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(rewardItemId)
            if itemIcon then
                iconTexture = itemIcon
            end
            text = (rewardItemCount or 1) .. "x " .. (itemName or "Item")
            
            -- If item info not cached, query it
            if not itemName then
                -- WotLK doesn't have Item:CreateFromItemID mixin usually, just rely on GetItemInfo returning nil first time
                -- We can try to query it again later or just show ID
                text = (rewardItemCount or 1) .. "x Item " .. rewardItemId
            end
        elseif (data.rewardCurrencyId or 0) > 0 then
            -- Currency handling
            local name, _, icon = GetCurrencyInfo(data.rewardCurrencyId)
            if icon then
                iconTexture = icon
            end
            text = (data.rewardCurrencyCount or 1) .. "x " .. (name or "Currency")
        end
        
        self.rewardFrame.icon:SetTexture(iconTexture)
        self.rewardFrame.count:SetText(text)
    else
        self.rewardFrame:Hide()
    end
end

Print("Group Finder UI module loaded")
