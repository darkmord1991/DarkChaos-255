-- DC-MythicPlus/UI/GroupFinderFrame.lua
-- Main Group Finder window: retail PVEFrame layout (PortraitFrame chrome,
-- bluemenu nav, marble content inset) built from the client patch's
-- Interface\FrameGeneral art, with stock 3.3.5 dropdowns, buttons and tabs.

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.GroupFinder = namespace.GroupFinder or {}
local GF = namespace.GroupFinder

-- =====================================================================
-- Constants
-- =====================================================================

-- Retail PVEFrame is 563x428; this window is a size up so the picker shows
-- a dozen dungeons at once. FRAME_SCALE multiplies the whole window (art and
-- text alike) for players who want it larger still.
GF.FRAME_WIDTH = 620
GF.FRAME_HEIGHT = 500
GF.FRAME_SCALE = 1.0
GF.CATEGORY_CONFIG = {
    mythic = { category = "dungeon", listingType = 1, title = "Mythic+" },
    raid = { category = "raid", listingType = 2, title = "Raid" },
    pvp = { category = "pvp", listingType = 3, title = "PvP" },
    quest = { category = "quest", listingType = 5, title = "Questing" },
    other = { category = "other", listingType = 4, title = "Other" },
}

-- Live sessions (Mythic+ runs, Hinterland BG matches, duels) are not a type
-- here: they have their own bottom tab, Spectate (ShowSpectatePanel).
GF.COMPACT_OPTION_ORDER = {
    "dungeons", "mythic", "raid", "hlbg", "quest", "other", "queues"
}

GF.PREMADE_CATEGORY_ORDER = {
    "quest", "mythic", "raid", "hlbg", "queues", "other"
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
}

-- Type menu contents per left-nav section. The Dungeon Finder and Raid Finder
-- navs only offer their own content; Premade Groups keeps the full catalog.
-- (The stock Dungeon Finder / PvP windows are no longer offered here: this
-- window replaces the stock finder, and the PvP tab opens the stock PvP frame.)
GF.TYPE_MENU_BY_CONTEXT = {
    dungeon = { "dungeons", "mythic" },
    raid = { "raid" },
    premade = { "mythic", "raid", "hlbg", "quest", "other", "queues" },
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

-- ---------------------------------------------------------------------------
-- Retail PortraitFrame / InsetFrame chrome. The nine-slice art ships in the
-- DC client patch (Interface\FrameGeneral) and is the same set the
-- DC-CharacterFrame addon and the DC-Journal templates draw, so this window
-- reads as one family with the character panel. Piece coordinates are the
-- retail UIPanelTemplates.xml values.
-- ---------------------------------------------------------------------------
local TEX_FRAME   = "Interface\\FrameGeneral\\UI-Frame"
local TEX_FRAME_H = "Interface\\FrameGeneral\\_UI-Frame"
local TEX_FRAME_V = "Interface\\FrameGeneral\\!UI-Frame"
local TEX_ROCK    = "Interface\\FrameGeneral\\UI-Background-Rock"
local TEX_MARBLE  = "Interface\\FrameGeneral\\UI-Background-Marble"

-- UI-Frame pieces: { width, height, left, right, top, bottom }
local FRAME_PIECES = {
    Portrait       = { 78, 78, 0.0078125, 0.6171875, 0.0078125, 0.6171875 },
    TopCornerRight = { 33, 33, 0.6328125, 0.890625,  0.0078125, 0.265625 },
    BotCornerLeft  = { 14, 14, 0.0078125, 0.1171875, 0.6328125, 0.7421875 },
    BotCornerRight = { 11, 11, 0.1328125, 0.21875,   0.8984375, 0.984375 },
    InnerTopLeft   = { 6, 6, 0.6328125, 0.6796875, 0.546875, 0.59375 },
    InnerTopRight  = { 6, 6, 0.90625,   0.953125,  0.21875,  0.265625 },
    InnerBotLeft   = { 6, 6, 0.6953125, 0.7421875, 0.546875, 0.59375 },
    InnerBotRight  = { 6, 6, 0.7578125, 0.8046875, 0.546875, 0.59375 },
}
-- _UI-Frame horizontal tiles: { height, top, bottom }
local FRAME_TILES_H = {
    TitleTile      = { 28, 0.4375,    0.65625 },
    TopTileStreaks = { 37, 0.671875,  0.9609375 },
    Bot            = { 9,  0.203125,  0.2734375 },
    TitleTileBG    = { 18, 0.2890625, 0.421875 },
    InnerTopTile   = { 3,  0.0859375, 0.109375 },
    InnerBotTile   = { 3,  0.0078125, 0.03125 },
}
-- !UI-Frame vertical tiles: { width, left, right }
local FRAME_TILES_V = {
    LeftTile       = { 16, 0.359375, 0.609375 },
    RightTile      = { 10, 0.171875, 0.328125 },
    InnerLeftTile  = { 3,  0.09375,  0.140625 },
    InnerRightTile = { 3,  0.015625, 0.0625 },
}

-- Fixed-size atlas piece.
local function ChromeTex(parent, layer, file, piece, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    tex:SetWidth(piece[1])
    tex:SetHeight(piece[2])
    tex:SetTexCoord(piece[3], piece[4], piece[5], piece[6])
    return tex
end

-- Stretched strips. The 3.3.5 client cannot tile a Lua-created texture, so
-- thin lines stretch and patterned art is chained from 256px segments.
local function ChromeTexH(parent, layer, file, def, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    tex:SetHeight(def[1])
    tex:SetTexCoord(0, 1, def[2], def[3])
    return tex
end

local function ChromeTexV(parent, layer, file, def, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    tex:SetWidth(def[1])
    tex:SetTexCoord(def[2], def[3], 0, 1)
    return tex
end

-- Horizontal strip of `totalW` from 256px segments; the caller anchors segs[1].
local function ChromeStripH(parent, layer, file, def, totalW, sublevel)
    local segs, remaining, prev = {}, totalW, nil
    while remaining > 0 do
        local w = math.min(256, remaining)
        local tex = parent:CreateTexture(nil, layer, nil, sublevel)
        tex:SetTexture(file)
        tex:SetHeight(def[1])
        tex:SetWidth(w)
        tex:SetTexCoord(0, w / 256, def[2], def[3])
        if prev then
            tex:SetPoint("TOPLEFT", prev, "TOPRIGHT")
        end
        table.insert(segs, tex)
        prev = tex
        remaining = remaining - w
    end
    return segs
end

-- Vertical strip of `totalH` from 256px segments; the caller anchors segs[1].
local function ChromeStripV(parent, layer, file, def, totalH, sublevel)
    local segs, remaining, prev = {}, totalH, nil
    while remaining > 0 do
        local h = math.min(256, remaining)
        local tex = parent:CreateTexture(nil, layer, nil, sublevel)
        tex:SetTexture(file)
        tex:SetWidth(def[1])
        tex:SetHeight(h)
        tex:SetTexCoord(def[2], def[3], 0, h / 256)
        if prev then
            tex:SetPoint("TOP", prev, "BOTTOM")
        end
        table.insert(segs, tex)
        prev = tex
        remaining = remaining - h
    end
    return segs
end

-- Patterned fill of a fixed w x h area from 256px tiles whose texcoords stay
-- inside 0..1, anchored to `anchor`'s TOPLEFT at (x, y). A tiled backdrop
-- leaves the repeat to the sampler, and on this client only the first row of
-- tiles survives: past 256px the last texel row smears down in streaks.
local function ChromeTileFill(parent, layer, file, anchor, x, y, w, h)
    local tiles = {}
    for row = 0, math.ceil(h / 256) - 1 do
        local th = math.min(256, h - row * 256)
        for col = 0, math.ceil(w / 256) - 1 do
            local tw = math.min(256, w - col * 256)
            local tex = parent:CreateTexture(nil, layer)
            tex:SetTexture(file)
            tex:SetWidth(tw)
            tex:SetHeight(th)
            tex:SetTexCoord(0, tw / 256, 0, th / 256)
            tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", x + col * 256, y - row * 256)
            table.insert(tiles, tex)
        end
    end
    return tiles
end

-- Retail InsetFrameTemplate border: 6px corners joined by 3px tiles.
local function AddInsetBorder(frame, layer)
    layer = layer or "BORDER"
    local P, TH, TV = FRAME_PIECES, FRAME_TILES_H, FRAME_TILES_V
    local tl = ChromeTex(frame, layer, TEX_FRAME, P.InnerTopLeft)
    tl:SetPoint("TOPLEFT")
    local tr = ChromeTex(frame, layer, TEX_FRAME, P.InnerTopRight)
    tr:SetPoint("TOPRIGHT")
    local bl = ChromeTex(frame, layer, TEX_FRAME, P.InnerBotLeft)
    bl:SetPoint("BOTTOMLEFT", 0, -1)
    local br = ChromeTex(frame, layer, TEX_FRAME, P.InnerBotRight)
    br:SetPoint("BOTTOMRIGHT", 0, -1)
    local top = ChromeTexH(frame, layer, TEX_FRAME_H, TH.InnerTopTile)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
    local bot = ChromeTexH(frame, layer, TEX_FRAME_H, TH.InnerBotTile)
    bot:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT")
    bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left = ChromeTexV(frame, layer, TEX_FRAME_V, TV.InnerLeftTile)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
    local right = ChromeTexV(frame, layer, TEX_FRAME_V, TV.InnerRightTile)
    right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
end

-- Inset with the metal border, at an explicit frame level so the portrait
-- ring (OVERLAY on the parent) still draws over its corner. Its w x h marble
-- is painted on the window's paint canvas (see BuildPortraitChrome), not on
-- the inset: at the window's own level the rock would draw over it.
local function CreateInset(parent, level, canvas, w, h)
    local inset = CreateFrame("Frame", nil, parent)
    if level then
        inset:SetFrameLevel(level)
    end
    inset.bgTiles = ChromeTileFill(canvas, "BORDER", TEX_MARBLE, inset, 0, 0, w, h)
    AddInsetBorder(inset, "BORDER")
    return inset
end
namespace.CreateInsetFrame = CreateInset

-- The outer PortraitFrame art on a W x H frame: rock fill, title tile,
-- portrait ring, edge tiles and bottom corners. Returns the portrait texture
-- (60x60 inside the ring), the ring, and the paint canvas.
--
-- 3.3.5 has no texture sublevels (CreateTexture ignores the 4th argument),
-- so draw order comes from layers and frame levels only, and frames sharing
-- a level mix their layers in one batch. Every opaque fill therefore lives
-- on one canvas a level under the window, in layer order: rock BACKGROUND,
-- inset marble BORDER, tinted panels ARTWORK. The borders, the portrait and
-- the insets' metal edges at the window's level all draw over it.
local function BuildPortraitChrome(frame, W, H)
    local P, TH, TV = FRAME_PIECES, FRAME_TILES_H, FRAME_TILES_V
    local ringW, ringH = P.Portrait[1], P.Portrait[2]
    local topRightW, topRightH = P.TopCornerRight[1], P.TopCornerRight[2]
    local botLeftW, botLeftH = P.BotCornerLeft[1], P.BotCornerLeft[2]
    local botRightW, botRightH = P.BotCornerRight[1], P.BotCornerRight[2]

    local canvas = CreateFrame("Frame", nil, frame)
    canvas:SetAllPoints()
    canvas:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    ChromeTileFill(canvas, "BACKGROUND", TEX_ROCK, frame, 2, -21, W - 4, H - 23)

    local titleBg = ChromeStripH(frame, "BACKGROUND", TEX_FRAME_H, TH.TitleTileBG, W - 2 - 25)
    titleBg[1]:SetPoint("TOPLEFT", 2, -3)

    -- The portrait shares OVERLAY with the ring and is created first, so the
    -- ring's inner edge draws over it (retail: portrait at OVERLAY -1).
    local portrait = frame:CreateTexture(nil, "OVERLAY")
    portrait:SetSize(60, 60)
    portrait:SetPoint("TOPLEFT", -6, 7)

    local ring = ChromeTex(frame, "OVERLAY", TEX_FRAME, P.Portrait)
    ring:SetPoint("TOPLEFT", -14, 11)
    local topRight = ChromeTex(frame, "OVERLAY", TEX_FRAME, P.TopCornerRight)
    topRight:SetPoint("TOPRIGHT", 0, 1)
    local titleTile = ChromeStripH(frame, "OVERLAY", TEX_FRAME_H, TH.TitleTile,
        (W - topRightW) - (ringW - 14))
    titleTile[1]:SetPoint("TOPLEFT", ring, "TOPRIGHT", 0, -10)

    local streaks = ChromeStripH(frame, "BORDER", TEX_FRAME_H, TH.TopTileStreaks, W - 2)
    streaks[1]:SetPoint("TOPLEFT", 0, -21)
    local botLeft = ChromeTex(frame, "BORDER", TEX_FRAME, P.BotCornerLeft)
    botLeft:SetPoint("BOTTOMLEFT", -6, -5)
    local botRight = ChromeTex(frame, "BORDER", TEX_FRAME, P.BotCornerRight)
    botRight:SetPoint("BOTTOMRIGHT", 0, -5)
    local bottom = ChromeStripH(frame, "BORDER", TEX_FRAME_H, TH.Bot,
        (W - botRightW) - (botLeftW - 6))
    bottom[1]:SetPoint("BOTTOMLEFT", botLeft, "BOTTOMRIGHT")
    local left = ChromeStripV(frame, "BORDER", TEX_FRAME_V, TV.LeftTile,
        (H + 5 - botLeftH) - (ringH - 11))
    left[1]:SetPoint("TOPLEFT", ring, "BOTTOMLEFT", 8, 0)
    local right = ChromeStripV(frame, "BORDER", TEX_FRAME_V, TV.RightTile,
        (H + 5 - botRightH) - (topRightH - 1))
    right[1]:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT", 1, 0)

    return { ring = ring, portrait = portrait, canvas = canvas }
end
namespace.BuildPortraitChrome = BuildPortraitChrome

-- ---------------------------------------------------------------------------
-- Retail bluemenu nav art (Interface\Common\bluemenu-main + BlueMenuRing ship
-- in the DC client patch; the _335.tga copies in the addon are the fallback).
-- Texcoords are the retail PVEFrame.xml regions.
-- ---------------------------------------------------------------------------
local BLUEMENU_MAIN = "Interface\\Common\\bluemenu-main"
local BLUEMENU_RING = "Interface\\Common\\BlueMenuRing"
local RETAIL_BLUEMENU_MAIN = RETAIL_TEXTURE_ROOT .. "bluemenu-main_335.tga"
local RETAIL_BLUE_MENU_RING = RETAIL_TEXTURE_ROOT .. "bluemenuring_335.tga"
-- The ring art occupies {1..103, 1..104} of the 128x128 file (atlas member
-- "bluemenu-Ring").
local BLUEMENU_RING_COORDS = { 0.0078125, 0.804688, 0.0078125, 0.8125 }
local BLUEMENU_BG_COORDS = { 0.00390625, 0.82421875, 0.18554688, 0.58984375 }
local BLUEMENU_BUTTON_COORDS = {
    normal   = { 0.00390625, 0.87890625, 0.75195313, 0.83007813 },
    selected = { 0.00390625, 0.87890625, 0.59179688, 0.66992188 },
    disabled = { 0.00390625, 0.87890625, 0.67187500, 0.75000000 },
}

-- ---------------------------------------------------------------------------
-- Retail Group Finder art, repacked into ONE 1024x1024 sheet. The straight
-- 2048px rips of the retail atlas files CRASH the 3.3.5a client (its UI
-- texture decoder is only safe up to 1024px — every other addon texture on
-- this server respects that), so the members the addon uses were cropped out
-- of Interface/LFGFrame/GroupFinder + UILFGPrompts and shelf-packed. Rects
-- are PIXEL coords in the packed sheet: { left, right, top, bottom }.
-- (Repack script: Textures/repack_gf_atlas.py; sources: retail 11.2.7
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
-- Used for dungeon/raid art, which varies by instance.
local function ApplyTextureCandidates(texture, candidates, fallback)
    if not texture then return false end

    if type(candidates) == "table" then
        for _, path in ipairs(candidates) do
            texture:SetTexture(path)
            if texture:GetTexture() then
                return true
            end
        end
    elseif type(candidates) == "string" then
        texture:SetTexture(candidates)
        if texture:GetTexture() then
            return true
        end
    end

    if fallback then
        texture:SetTexture(fallback)
        return texture:GetTexture() ~= nil
    end

    return false
end
namespace.ApplyTextureCandidates = ApplyTextureCandidates

-- Resolve art for a group-finder entry (the ready-check dialog shows it next
-- to the instance name, the way the stock dialog shows its dungeon art).
-- Order of preference:
--   1. the shipped LFG list icon for the map (patch MPQ, lfgicon-<key>.blp)
--   2. a name-derived LFG icon (covers custom instances not in the table)
--   3. the teleporter art for anything still unmatched
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
namespace.ResolveGroupFinderEntryArt = GetEntryDungeonArtCandidates

local function SetSolidTexture(texture, red, green, blue, alpha)
    if not texture then return end

    if texture.SetColorTexture then
        texture:SetColorTexture(red, green, blue, alpha)
    else
        texture:SetTexture(red, green, blue, alpha)
        texture:SetAlpha(alpha or 1)
    end
end

-- Row background states, retail LFGList style: rows sit flat on the panel,
-- hover shows the blue highlight bar and a selected row the gold select bar.
local function SetRetailBlueMenuBackground(texture, state)
    if not texture then return end

    if state == "selected" then
        if not SetGFAtlas(texture, "button-select") then
            SetSolidTexture(texture, 0.32, 0.25, 0.10, 0.85)
        end
        texture:SetVertexColor(1, 1, 1, 1)
        texture:Show()
    elseif state == "hover" then
        if not SetGFAtlas(texture, "highlightbar-blue") then
            SetSolidTexture(texture, 0.20, 0.40, 0.60, 0.45)
        end
        texture:SetVertexColor(1, 1, 1, 0.9)
        texture:Show()
    else
        texture:Hide()
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
-- Action button factory: the standard Blizzard push button
-- (UIPanelButtonTemplate), sized by the caller. Kept under the old name so
-- the queue, spectate and dialog code share one factory. The retail "stone
-- cover" art it used to draw is a category-list cover, not a push button,
-- and read as a foreign element next to the stock buttons everywhere else.
-- ---------------------------------------------------------------------------
local function CreateRetailActionButton(parent, width, height, label)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, height or 22)
    if label then
        button:SetText(label)
    end
    -- Every caller installs its own OnClick, which replaces the template's
    -- click sound, so play it here.
    button:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            PlayUISound("igMainMenuOptionCheckBoxOn")
        end
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

-- Role buttons use the retail role icons: one clean 256x256 texture per
-- role with the circular frame baked in and a separate disabled variant, so
-- they load crisply on 3.3.5a with no ring layered underneath.
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

    if button.ring then
        button.ring:Hide()
    end
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
        -- LiveRunsTab.lua knows every spectatable system's entry shape.
        if GF.DescribeLiveEntry then
            return (GF.DescribeLiveEntry(entry))
        end
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
        if GF.DescribeLiveEntry then
            return (select(3, GF.DescribeLiveEntry(entry)))
        end
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

-- Repaint every visible tick-row checkbox from the tick set. Like the stock
-- Dungeon Finder list, a ticked dungeon shows only its checkbox (no bar).
function GF:CompactRefreshTickMarks()
    if not self.compactRowPool then return end
    local anyTicked = self:CountDungeonTicks() > 0

    for _, row in ipairs(self.compactRowPool) do
        if row:IsShown() and row.check and row.check:IsShown()
            and row.entry and row.entry.isQueueTarget then
            local mapId = tonumber(row.entry.queueMapId) or 0
            local on
            if mapId == 0 then
                on = not anyTicked        -- Random is on when nothing specific is
            else
                on = self:IsDungeonTicked(mapId)
            end
            row.check:SetChecked(on)
        end
    end
end

-- Row geometry. The finder pickers use the stock LFGSpecificChoiceTemplate
-- read (one 20px line: checkbox, name, level range); premade listings use the
-- retail LFGListSearchEntry read (two lines, 38px).
local EXPANSION_LABELS = {
    [0] = "Classic", [1] = "The Burning Crusade", [2] = "Wrath of the Lich King",
}
local PICKER_ROW_HEIGHT = 20
local LISTING_ROW_HEIGHT = 38
local HEADER_ROW_HEIGHT = 22

-- "70-80" / "80+" from the entry's level bracket, "" when unknown.
local function FormatLevelRange(entry)
    local lo = tonumber(entry.reqLevel) or 0
    local hi = tonumber(entry.maxLevel) or 0
    if lo <= 0 then return "" end
    if hi > lo then
        return string.format("%d-%d", lo, hi)
    end
    return string.format("%d+", lo)
end

local function CompactRowOnEnter(self)
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
        -- Server lock reason (attunement, deserter, gear...) when it says
        -- more than the level line already did.
        if entry.locked and entry.lockReason
            and not entry.lockReason:find("^Requires level") then
            GameTooltip:AddLine(entry.lockReason, 1, 0.1, 0.1, true)
        end
        GameTooltip:Show()
    end
end

local function CompactRowOnLeave(self)
    if self ~= GF.compactSelectedRow and self.bg
        and not (self.entry and self.entry.locked) then
        SetRetailBlueMenuBackground(self.bg, "normal")
    end
    GameTooltip:Hide()
end

local function CompactRowOnClick(self)
    if self.entry and self.entry.locked then
        PlayUISound("igQuestFailed")
    else
        PlayUISound("igMainMenuOptionCheckBoxOn")
    end
    GF:CompactSelectRow(self, self.entry)
end

function GF:CompactRenderRows(entries, emptyTitle, emptySubtext)
    if not self.compactScrollChild then return end

    entries = NormalizeCompactEntries(entries)
    self:CompactClearRows()
    self.compactSelectedRow = nil
    self.compactSelectedEntry = nil

    local scrollChild = self.compactScrollChild
    local kind = self.compactSelectedKind or "mythic"
    local rowWidth = self.compactRowWidth or 285

    -- Persistent empty-state labels (created once, reused) so repeated renders
    -- don't stack new FontStrings on top of each other. FontStrings are regions,
    -- not children, so CompactClearRows() can't remove them.
    if not self.compactEmptyTitle then
        local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("TOP", 0, -56)
        empty:SetTextColor(0.6, 0.6, 0.6)
        self.compactEmptyTitle = empty

        local sub = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("TOP", empty, "BOTTOM", 0, -6)
        sub:SetWidth(rowWidth - 20)
        sub:SetJustifyH("CENTER")
        self.compactEmptySub = sub
    end

    self.compactHeaderPool = self.compactHeaderPool or {}
    for _, header in ipairs(self.compactHeaderPool) do
        header:Hide()
    end

    if #entries == 0 then
        self.compactEmptyTitle:SetText(emptyTitle or "No groups found")
        self.compactEmptyTitle:Show()
        self.compactEmptySub:SetText(emptySubtext or "Choose a type and click Find Group.")
        self.compactEmptySub:Show()

        scrollChild:SetHeight(160)
        self:UpdateCompactButtons()
        return
    end

    -- Rows present: hide the empty-state labels.
    self.compactEmptyTitle:Hide()
    self.compactEmptySub:Hide()

    -- The Dungeon/Raid Finder navs show a queue-target picker: one compact
    -- line per dungeon (or raid size), grouped under expansion headers the way
    -- the retail list is. The Premade Groups nav lists player groups, two
    -- lines each.
    local pickerMode = self.retailNavContext ~= "premade"
        and (kind == "dungeons" or kind == "mythic" or kind == "raid")
    local tickMode = pickerMode and kind ~= "raid"
    local rowHeight = pickerMode and PICKER_ROW_HEIGHT or LISTING_ROW_HEIGHT

    self.compactRowPool = self.compactRowPool or {}

    local yOffset = 0
    local headerIndex = 0
    local lastExp

    for i, entry in ipairs(entries) do
        -- Expansion header whenever the group changes (entries arrive sorted).
        local exp = pickerMode and tonumber(entry._exp) or nil
        if exp ~= nil and exp ~= lastExp then
            headerIndex = headerIndex + 1
            local header = self.compactHeaderPool[headerIndex]
            if not header then
                header = CreateFrame("Frame", nil, scrollChild)
                header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                header.text:SetPoint("BOTTOMLEFT", 4, 4)
                header.line = header:CreateTexture(nil, "ARTWORK")
                header.line:SetPoint("BOTTOMLEFT", 2, 1)
                header.line:SetPoint("BOTTOMRIGHT", -2, 1)
                header.line:SetHeight(1)
                SetSolidTexture(header.line, 1, 0.82, 0, 0.35)
                self.compactHeaderPool[headerIndex] = header
            end
            header:ClearAllPoints()
            header:SetSize(rowWidth, HEADER_ROW_HEIGHT)
            header:SetPoint("TOPLEFT", 0, -yOffset)
            header.text:SetText(EXPANSION_LABELS[exp] or ("Expansion " .. tostring(exp)))
            header:Show()
            yOffset = yOffset + HEADER_ROW_HEIGHT
            lastExp = exp
        end

        local row = self.compactRowPool[i]
        if not row then
            row = CreateFrame("Button", nil, scrollChild)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetJustifyH("LEFT")

            row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.sub:SetJustifyH("LEFT")

            row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.meta:SetJustifyH("RIGHT")

            row.roles = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.roles:SetJustifyH("RIGHT")

            -- One line each: a wrapped lock reason or note would paint over
            -- the row below. Guarded, because 3.3.5's FontString lacks
            -- SetMaxLines and an unguarded missing method takes the whole row
            -- build with it.
            for _, fs in ipairs({ row.name, row.sub, row.meta }) do
                if fs.SetWordWrap then
                    fs:SetWordWrap(false)
                end
            end

            row:SetScript("OnEnter", CompactRowOnEnter)
            row:SetScript("OnLeave", CompactRowOnLeave)
            row:SetScript("OnClick", CompactRowOnClick)

            self.compactRowPool[i] = row
        end

        row:ClearAllPoints()
        row:SetSize(rowWidth, rowHeight - 2)
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row.entry = entry

        SetRetailBlueMenuBackground(row.bg, "normal")

        -- Dungeon queue rows carry a real checkbox (the stock Dungeon Finder
        -- lets you tick several dungeons at once); raids and listings are a
        -- single selection.
        local isTickRow = tickMode and entry.isQueueTarget and entry.queueCategory ~= 2
        if isTickRow then
            if not row.check then
                local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                check:SetSize(20, 20)
                check:SetPoint("LEFT", 0, 0)
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

        local name = CompactEntryName(entry, kind)

        if pickerMode then
            local textInset = isTickRow and 24 or 8
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", textInset, 0)
            row.name:SetWidth(rowWidth - textInset - 92)
            row.name:SetText(name)

            row.meta:ClearAllPoints()
            row.meta:SetPoint("RIGHT", -6, 0)
            row.meta:SetWidth(86)
            row.meta:SetFontObject(GameFontNormalSmall)
            if entry.queueCategory == 2 then
                row.meta:SetText(entry.difficultyName or "")
            else
                row.meta:SetText(FormatLevelRange(entry))
            end
            row.meta:Show()

            row.sub:Hide()
            row.roles:Hide()
        else
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", 8, -4)
            row.name:SetWidth(rowWidth - 8 - 112)
            row.name:SetText(name)

            row.meta:ClearAllPoints()
            row.meta:SetPoint("TOPRIGHT", -8, -5)
            row.meta:SetWidth(104)
            row.meta:SetFontObject(GameFontHighlightSmall)
            row.meta:SetText(CompactEntryMeta(entry, kind))
            row.meta:Show()

            -- Live rows describe the session (resources, duelists, run
            -- leader) and show who is watching instead of open role slots.
            local liveDetail, liveWatchers
            if kind == "live" and GF.DescribeLiveEntry then
                local _
                _, liveDetail, _, liveWatchers = GF.DescribeLiveEntry(entry)
            end

            row.sub:ClearAllPoints()
            row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
            row.sub:SetWidth(rowWidth - 8 - 112)
            row.sub:SetText(liveDetail or entry.leader or entry.leaderName or entry.owner or "")
            row.sub:Show()

            row.roles:ClearAllPoints()
            row.roles:SetPoint("BOTTOMRIGHT", -8, 4)
            if kind == "live" then
                row.roles:SetText(liveWatchers or "")
            else
                -- Retail-style role glyphs (tank/healer/dps) + open counts.
                row.roles:SetText(string.format("%s%s  %s%s  %s%s",
                    GFAtlasEscape("tank-micro", 13),
                    tostring(entry.needTank or entry.tanks or entry.tank or 0),
                    GFAtlasEscape("healer-micro", 13),
                    tostring(entry.needHealer or entry.healers or entry.healer or 0),
                    GFAtlasEscape("dps-micro", 13),
                    tostring(entry.needDps or entry.dps or 0)))
            end
            row.roles:Show()
        end

        -- Locked content reads greyed, the way the stock list greys a
        -- dungeon whose requirements you do not meet yet; the hover tooltip
        -- carries the reason.
        if entry.locked then
            row.name:SetTextColor(0.5, 0.5, 0.5)
            row.meta:SetTextColor(0.5, 0.5, 0.5)
            row.sub:SetTextColor(0.45, 0.45, 0.45)
            row.roles:SetTextColor(0.4, 0.4, 0.4)
            if not pickerMode then
                row.sub:SetText(entry.lockReason or "Requirements not met")
            end
        else
            row.name:SetTextColor(1, 0.82, 0)
            if pickerMode then
                row.meta:SetTextColor(1, 0.82, 0)
            else
                row.meta:SetTextColor(1, 1, 1)
            end
            row.sub:SetTextColor(0.8, 0.8, 0.8)
            row.roles:SetTextColor(0.6, 0.6, 0.6)
        end

        row:Show()

        yOffset = yOffset + rowHeight
    end

    scrollChild:SetHeight(math.max(yOffset, 1))
    self:CompactRefreshTickMarks()
    self:UpdateCompactButtons()
end

-- Place the action buttons in the strip under the content inset: one button
-- centred, or Find + Start side by side (retail LFGList layout).
local function LayoutActionButtons(self, primaryShown, createShown)
    local pane = self.contentPane
    local primary, create = self.compactPrimaryButton, self.compactCreateButton
    if not (pane and primary) then return end

    primary:ClearAllPoints()
    if primaryShown then
        primary:Show()
    else
        primary:Hide()
    end

    if create then
        create:ClearAllPoints()
        if createShown then
            create:Show()
        else
            create:Hide()
        end
    end

    local y = self.ACTION_BUTTON_BOTTOM or 8
    if primaryShown and createShown and create then
        primary:SetPoint("BOTTOMRIGHT", pane, "BOTTOM", -3, y)
        create:SetPoint("BOTTOMLEFT", pane, "BOTTOM", 3, y)
    elseif primaryShown then
        primary:SetPoint("BOTTOM", pane, "BOTTOM", 0, y)
    elseif createShown and create then
        create:SetPoint("BOTTOM", pane, "BOTTOM", 0, y)
    end
end

function GF:UpdateCompactButtons()
    if not self.compactPrimaryButton then return end
    local primary, create = self.compactPrimaryButton, self.compactCreateButton

    -- The PvP and Mythic+ panels carry their own buttons.
    if self.pvpPanelShown or self.mythicPanelShown then
        LayoutActionButtons(self, false, false)
        return
    end

    if self.spectatePanelShown then
        primary:SetText("Refresh")
        LayoutActionButtons(self, true, false)
        return
    end

    if self.hlbgPanelShown then
        local HLBG = rawget(_G, "HLBG")
        primary:SetText((HLBG and HLBG.IsInQueue) and "Leave Queue" or "Join Queue")
        LayoutActionButtons(self, true, false)
        return
    end

    if self.retailHomeShown then
        local selectedKind = self.premadeSelectedKind or "mythic"
        local homeOption = self.COMPACT_OPTIONS[selectedKind] or self.COMPACT_OPTIONS.mythic
        primary:SetText("Find a Group")
        if create then
            create:SetText("Start a Group")
        end
        LayoutActionButtons(self, true, homeOption.create and true or false)
        return
    end

    local kind = self.compactSelectedKind or "mythic"
    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    local selected = self.compactSelectedEntry

    -- In the Dungeon/Raid Finder navs a selected row is the queue target, not
    -- a listing: the primary action queues (never "Apply"), and there is no
    -- premade listing to start from here.
    local finderQueueMode = self.retailNavContext ~= "premade"
        and (kind == "dungeons" or kind == "mythic" or kind == "raid")

    if finderQueueMode then
        if kind ~= "raid" then
            local n = self:CountDungeonTicks()
            if n == 0 then
                primary:SetText("Find Random Group")
            elseif n == 1 then
                primary:SetText("Find Group (1 dungeon)")
            else
                primary:SetText(string.format("Find Group (%d dungeons)", n))
            end
        else
            primary:SetText(option.actionText or "Find Group")
        end
        LayoutActionButtons(self, true, false)
        return
    end

    if selected and (kind == "mythic" or kind == "raid" or kind == "quest" or kind == "other") then
        primary:SetText("Apply")
    elseif selected and kind == "live" then
        primary:SetText("Spectate")
    else
        primary:SetText(option.actionText or "Find Group")
    end

    if create then
        create:SetText("Start a Group")
    end
    LayoutActionButtons(self, true, option.create and true or false)
end

function GF:SetQueueDungeonDifficulty(difficulty)
    difficulty = tonumber(difficulty) or 0
    if difficulty < 0 or difficulty > 1 then
        difficulty = 0
    end
    self.queueDungeonDifficulty = difficulty

    if self.compactDiffDropdown and UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(self.compactDiffDropdown,
            self.DUNGEON_DIFFICULTY_LABELS[difficulty] or "Normal")
    end

    -- Refresh the picker rows so their level column matches.
    if self.compactMode and self.retailNavContext ~= "premade"
        and self.compactSelectedKind == "dungeons" then
        self:SelectCompactType("dungeons")
    end
end

-- Hide every content view and reset the view flags; each Show* entry point
-- calls this first so exactly one view is up.
function GF:HideContentViews()
    self.retailHomeShown = false
    self.hlbgPanelShown = false
    self.spectatePanelShown = false
    self.pvpPanelShown = false
    self.mythicPanelShown = false

    for _, key in ipairs({
        "compactBrowserFrame", "compactListFrame", "retailHomeFrame",
        "hlbgPanel", "pvpPanel", "mythicPanel", "spectatePanel",
    }) do
        local view = self[key]
        if view then
            view:Hide()
        end
    end

    if CloseDropDownMenus then
        CloseDropDownMenus()
    end
end

-- The attic line between the title streaks and the content inset names the
-- view (retail puts the character's level line there on the paperdoll).
function GF:SetContentTitle(text)
    if self.retailContentTitle then
        self.retailContentTitle:SetText(text or "")
    end
end

-- Stock UIDropDownMenu initialisers. The Type menu lists what the active nav
-- section offers (Dungeon Finder and Raid Finder only their own content; the
-- Premade Groups nav the full catalog); Difficulty is Normal / Heroic for the
-- Specific Dungeons queue.
local function InitTypeDropdown(_, level)
    local context
    if GF.retailNavContext == "premade" then
        context = "premade"
    elseif (GF.compactSelectedKind or "mythic") == "raid" then
        context = "raid"
    else
        context = "dungeon"
    end

    local kinds = GF.TYPE_MENU_BY_CONTEXT[context] or GF.COMPACT_OPTION_ORDER
    for _, kind in ipairs(kinds) do
        local option = GF.COMPACT_OPTIONS[kind]
        if option then
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = kind
            info.checked = (kind == GF.compactSelectedKind)
            info.func = function()
                PlayUISound("UChatScrollButton")
                GF:SelectCompactType(kind)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

local function InitDifficultyDropdown(_, level)
    for difficulty = 0, 1 do
        local info = UIDropDownMenu_CreateInfo()
        info.text = GF.DUNGEON_DIFFICULTY_LABELS[difficulty] or tostring(difficulty)
        info.value = difficulty
        info.checked = ((GF.queueDungeonDifficulty or 0) == difficulty)
        info.func = function()
            PlayUISound("UChatScrollButton")
            GF:SetQueueDungeonDifficulty(difficulty)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

function GF:SelectCompactType(kind)
    kind = kind or "mythic"
    if kind == "hlbg" then
        self:ShowHinterlandPanel()
        return
    end

    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    self:HideContentViews()
    self.compactSelectedKind = kind
    self.compactSelectedEntry = nil

    if self.compactBrowserFrame then
        self.compactBrowserFrame:Show()
    end
    if self.compactListFrame then
        self.compactListFrame:Show()
    end

    local finderMode = self.retailNavContext ~= "premade"
    -- The difficulty row only applies to the Specific Dungeons queue
    -- (Mythic+ is locked to Mythic difficulty), and the Raid Finder has a
    -- single type, so its Type row is pointless.
    local showDifficulty = finderMode and kind == "dungeons"
    local showTypeRow = not (finderMode and kind == "raid")

    if self.compactTypeDropdown then
        if UIDropDownMenu_SetText then
            -- Same string as the menu entry, like a stock dropdown.
            UIDropDownMenu_SetText(self.compactTypeDropdown,
                option.label or "Specific Dungeons")
        end
        if showTypeRow then
            self.compactTypeDropdown:Show()
            if self.compactTypeLabel then self.compactTypeLabel:Show() end
        else
            self.compactTypeDropdown:Hide()
            if self.compactTypeLabel then self.compactTypeLabel:Hide() end
        end
    end

    if self.compactDiffDropdown then
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(self.compactDiffDropdown,
                self.DUNGEON_DIFFICULTY_LABELS[self.queueDungeonDifficulty or 0] or "Normal")
        end
        if showDifficulty then
            self.compactDiffDropdown:Show()
            if self.compactDiffLabel then self.compactDiffLabel:Show() end
        else
            self.compactDiffDropdown:Hide()
            if self.compactDiffLabel then self.compactDiffLabel:Hide() end
        end
    end

    -- The list starts right under the last visible filter row.
    if self.compactListFrame and self.compactBrowserFrame then
        local top = self.LIST_TOP_BASE or 70
        local rowH = self.FILTER_ROW_HEIGHT or 28
        if showTypeRow then top = top + rowH end
        if showDifficulty then top = top + rowH end
        self.compactListFrame:SetPoint("TOPLEFT", self.compactBrowserFrame, "TOPLEFT", 8, -top)
    end
    self:UpdateRewardRow()

    if finderMode then
        self:SetContentTitle(option.title or option.label or "Group Finder")
    else
        self:SetContentTitle("Premade Groups")
    end

    if self.SetRetailNavSelection then
        if not finderMode then
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

    if self.mainFrame and self.mainFrame.TitleText then
        -- Top window title stays the static frame name; the attic line
        -- carries the per-view label (matches retail PVEFrame).
        self.mainFrame.TitleText:SetText("Group Finder")
    end

    -- In Dungeon Finder / Raid Finder mode the list is a queue-target picker
    -- (tick dungeons + Find Group, or none for Any). The Premade Groups nav
    -- keeps the listing browse/apply flow.
    if finderMode
        and (kind == "dungeons" or kind == "mythic" or kind == "raid")
        and self.GetQueueTargets then
        self:CompactRenderRows(self:GetQueueTargets(kind),
            kind == "raid" and "No raids available" or "No dungeons available",
            kind == "raid" and "Pick a raid, then click Find Group."
                or "Tick the dungeons you want, or none for Any, then click Find Group.")
        return
    end

    self:CompactRenderRows(self.compactData and self.compactData[kind] or {},
        kind == "queues" and "No active applications" or "No groups found",
        kind == "hlbg" and "Click Join Queue to enter Hinterland BG."
            or "Click Find a Group to refresh this list.")
end

function GF:CompactPrimaryAction()
    if self.spectatePanelShown then
        self:SetStatusMessage("Refreshing live sessions...")
        self:RequestSpectateList()
        return
    end

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
        local id = selected.id or selected.runId or selected.instanceId
        if self.RequestSpectate then
            self:RequestSpectate(id, selected.leader or selected.name, selected.system)
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
    local size = self.ROLE_BUTTON_SIZE or 48
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetPoint("TOPLEFT", xOffset, -(self.ROLE_BAR_TOP or 12))
    button.role = role
    button.allowed = allowed ~= false

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    button.icon = icon

    ApplyCompactRoleButtonArt(button, checked)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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
    if self.compactTypeDropdown and UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(self.compactTypeDropdown, option.label)
    end

    self:UpdateCompactButtons()
end

function GF:ShowRetailPremadeHome(kind)
    self:HideContentViews()
    self.retailNavContext = "premade"
    self.retailHomeShown = true
    self.premadeSelectedKind = kind or self.premadeSelectedKind or "mythic"
    self.compactSelectedKind = self.premadeSelectedKind
    self.compactSelectedEntry = nil

    if self.retailHomeFrame then
        self.retailHomeFrame:Show()
    end
    self:SetContentTitle("Premade Groups")
    if self.mainFrame and self.mainFrame.TitleText then
        self.mainFrame.TitleText:SetText("Group Finder")
    end

    self:SetRetailNavSelection("premade")
    self:RefreshRetailPremadeSelection()
    self:SetActiveBottomTab("finder")
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

function GF:IsSpectatingHinterland()
    return self._spectatorSessionActive and self._spectatorSystem == "hlbg"
end

function GF:ToggleHinterlandSpectate()
    if self:IsSpectatingHinterland() then
        if self.LeaveSpectate then
            self:LeaveSpectate()
        end
        return
    end

    if self.RequestSpectate then
        self:SetStatusMessage("Requesting to watch the Hinterland battleground...")
        self:RequestSpectate(0, nil, "hlbg")
    end
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

    if panel.watchButton then
        panel.watchButton:SetText(self:IsSpectatingHinterland() and "Stop Watching" or "Watch Live Match")
    end

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
    self:HideContentViews()
    self.retailNavContext = "hlbg"
    self.hlbgPanelShown = true
    self.compactSelectedKind = "hlbg"
    self.compactSelectedEntry = nil

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
    self:SetContentTitle("Hinterland Battleground")
    if self.mainFrame and self.mainFrame.TitleText then
        self.mainFrame.TitleText:SetText("Group Finder")
    end

    -- Hinterland BG is PvP content: the PvP tab lights up whichever nav
    -- button opened it.
    self:SetRetailNavSelection("hlbg")
    if self.SetActiveBottomTab then
        self:SetActiveBottomTab("pvp")
    end
    self:UpdateCompactButtons()
end

-- Retail PVEFrame nav button (GroupFinderGroupButtonTemplate, 203x60):
-- bluemenu-main button art + the gold ring with the category icon + large
-- label. Selected state swaps to the blue-glow art row; hover is the same
-- art additively blended. `iconTexture` may be a path or a list of candidate
-- paths (first one that loads wins).
function GF:CreateRetailNavButton(parent, key, label, iconTexture, yOffset, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(203, 60)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, yOffset)
    button.key = key

    -- Button background: the 224x80 bluemenu button art, centred (retail
    -- lets it bleed past the 203x60 hit rect).
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(224, 80)
    bg:SetPoint("CENTER")
    SetTextureOrFallback(bg, BLUEMENU_MAIN, RETAIL_BLUEMENU_MAIN)
    local c = BLUEMENU_BUTTON_COORDS.normal
    bg:SetTexCoord(c[1], c[2], c[3], c[4])
    button.bg = bg

    -- Native hover: same art, additive (exactly retail's HighlightTexture).
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(224, 80)
    highlight:SetPoint("CENTER")
    SetTextureOrFallback(highlight, BLUEMENU_MAIN, RETAIL_BLUEMENU_MAIN)
    highlight:SetTexCoord(c[1], c[2], c[3], c[4])
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.8)
    button:SetHighlightTexture(highlight)

    -- Gold ring on the left with the category icon inside (retail: 95x96
    -- ring at LEFT -12,-1; the icon sits under the ring so its square
    -- corners hide behind the metal band). Separate layers, because 3.3.5
    -- ignores texture sublevels.
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(95, 96)
    ring:SetPoint("LEFT", -12, -1)
    SetTextureOrFallback(ring, BLUEMENU_RING, RETAIL_BLUE_MENU_RING)
    ring:SetTexCoord(BLUEMENU_RING_COORDS[1], BLUEMENU_RING_COORDS[2],
        BLUEMENU_RING_COORDS[3], BLUEMENU_RING_COORDS[4])
    button.ring = ring

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(62, 62)
    icon:SetPoint("CENTER", ring, "CENTER", 0, 0)
    ApplyTextureCandidates(icon, iconTexture, "Interface\\Icons\\INV_Misc_QuestionMark")
    -- Zoom in a touch so the icon fills the ring's window.
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", ring, "RIGHT", 0, 0)
    text:SetWidth(106)
    text:SetJustifyH("LEFT")
    if text.SetSpacing then
        text:SetSpacing(2)
    end
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

-- Retail LFGListCategoryTemplate is 300x46; the banner list is centred in
-- the content inset by the caller.
function GF:CreateRetailPremadeCategoryButton(parent, kind, label, yOffset)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(300, 46)
    button:SetPoint("TOP", parent, "TOP", 0, yOffset)
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
    labelText:SetWidth(260)
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

-- Layout constants: retail PVEFrame geometry (563x428, a 217px nav inset on
-- the left, the content column from x=224 with its own inset and a button
-- strip under it). Exposed on GF so the view code shares one set of numbers.
GF.NAV_INSET_WIDTH = 217
GF.CONTENT_LEFT = 224
GF.CONTENT_INSET_TOP = 60
GF.CONTENT_INSET_BOTTOM = 34
GF.ACTION_BUTTON_BOTTOM = 8
GF.ROLE_BAR_TOP = 12
GF.ROLE_BUTTON_SIZE = 48
GF.ROLE_BUTTON_GAP = 28
GF.FILTER_TOP = 70
GF.FILTER_ROW_HEIGHT = 28
GF.LIST_TOP_BASE = 70
GF.LIST_BOTTOM = 30
GF.STATUS_BOTTOM = 10

function GF:CreateCompactMainFrame()
    if self.mainFrame then return self.mainFrame end

    local W, H = self.FRAME_WIDTH, self.FRAME_HEIGHT
    local frame = CreateFrame("Frame", "DCMythicPlusGroupFinderFrame", UIParent)
    frame:SetSize(W, H)
    frame:SetScale(self.FRAME_SCALE or 1)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:Hide()
    local level = frame:GetFrameLevel()

    -- Retail PortraitFrame chrome with the Dungeon Finder eye in the ring.
    -- The eye plays the stock LFG-Eye flipbook (the animation the minimap
    -- eye runs while queued) over a dark disc; the static portrait only
    -- stands in when the flipbook helper is unavailable. The disc is ARTWORK
    -- under the OVERLAY portrait: a sublevel would be ignored, and the disc,
    -- created last, covered the eye.
    local chrome = BuildPortraitChrome(frame, W, H)
    local canvas = chrome.canvas
    local portrait = chrome.portrait
    if namespace.SetLFGEyeFrame then
        local disc = frame:CreateTexture(nil, "ARTWORK")
        disc:SetSize(56, 56)
        disc:SetPoint("CENTER", portrait, "CENTER", 0, 0)
        SetTextureOrFallback(disc, "Interface\\Minimap\\UI-Minimap-Background",
            LFG_PORTRAIT_TEXTURE)
        disc:SetVertexColor(0.35, 0.35, 0.35)
        portrait:SetTexture(namespace.LFG_EYE_TEXTURE or "Interface\\LFGFrame\\LFG-Eye")
        namespace.SetLFGEyeFrame(portrait, 0)
        frame._eyeFrame = 0
        frame._eyeAcc = 0
    else
        SetTextureOrFallback(portrait, LFG_PORTRAIT_TEXTURE,
            "Interface\\LFGFrame\\LFG-Eye")
    end
    frame.Portrait = portrait

    frame:SetScript("OnUpdate", function(self_, elapsed)
        if not (self_._eyeFrame and namespace.SetLFGEyeFrame) then return end
        local step = namespace.LFG_EYE_FRAME_TIME or 0.05
        local frames = namespace.LFG_EYE_FRAMES or 29
        self_._eyeAcc = (self_._eyeAcc or 0) + elapsed
        local advanced = false
        while self_._eyeAcc >= step do
            self_._eyeAcc = self_._eyeAcc - step
            self_._eyeFrame = (self_._eyeFrame + 1) % frames
            advanced = true
        end
        if advanced then
            namespace.SetLFGEyeFrame(self_.Portrait, self_._eyeFrame)
        end
    end)

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

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
    title:SetText("Group Finder")
    frame.TitleText = title

    -- Retail drags by the title bar only; the strip stops short of the close
    -- button so it can't swallow its clicks.
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 60, 2)
    header:SetPoint("TOPRIGHT", -36, 2)
    header:SetHeight(26)
    header:SetFrameLevel(level + 4)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 4, 5)
    closeBtn:SetFrameLevel(level + 5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Left inset: the retail bluemenu nav (blue panel + four big buttons).
    local navInset = CreateInset(frame, level, canvas, self.NAV_INSET_WIDTH, H - 28)
    navInset:SetPoint("TOPLEFT", 4, -24)
    navInset:SetPoint("BOTTOMLEFT", 4, 4)
    navInset:SetWidth(self.NAV_INSET_WIDTH)
    self.navInset = navInset

    -- Retail draws this 209x399 in its 428-tall frame; the plain gradient
    -- panel stretches to whatever height the inset has. Painted on the
    -- canvas above the inset's marble.
    local navBg = canvas:CreateTexture(nil, "ARTWORK")
    navBg:SetSize(209, H - 29)
    navBg:SetPoint("TOPLEFT", navInset, "TOPLEFT", 3, 1)
    SetTextureOrFallback(navBg, BLUEMENU_MAIN, RETAIL_BLUEMENU_MAIN)
    navBg:SetTexCoord(BLUEMENU_BG_COORDS[1], BLUEMENU_BG_COORDS[2],
        BLUEMENU_BG_COORDS[3], BLUEMENU_BG_COORDS[4])

    -- Buttons on their own layer above the inset border. Retail places the
    -- first at frame (10,-70) and each next one 23px below the previous.
    local navButtons = CreateFrame("Frame", nil, navInset)
    navButtons:SetAllPoints()
    navButtons:SetFrameLevel(level + 1)
    self:CreateRetailNavButton(navButtons, "dungeon", "Dungeon\nFinder",
        "Interface\\Icons\\INV_Helmet_08", -46, function()
        GF.retailNavContext = nil
        GF:SelectCompactType("dungeons")
    end)
    self:CreateRetailNavButton(navButtons, "raid", "Raid\nFinder",
        { "Interface\\LFGFrame\\UI-LFR-PORTRAIT",
          "Interface\\Icons\\Achievement_Boss_Kelthuzad_01" }, -129, function()
        GF.retailNavContext = nil
        GF:SelectCompactType("raid")
    end)
    self:CreateRetailNavButton(navButtons, "premade", "Premade\nGroups",
        "Interface\\Icons\\Achievement_General_StayClassy", -212, function()
        GF:ShowRetailPremadeHome(GF.premadeSelectedKind or "mythic")
    end)
    self:CreateRetailNavButton(navButtons, "hlbg", "Hinterland\nBG",
        "Interface\\Icons\\INV_BannerPVP_01", -295, function()
        GF:ShowHinterlandPanel()
    end)

    -- Content column: attic title + marble inset + the button strip below.
    local contentPane = CreateFrame("Frame", nil, frame)
    contentPane:SetPoint("TOPLEFT", self.CONTENT_LEFT, 0)
    contentPane:SetPoint("BOTTOMRIGHT", 0, 0)
    contentPane:SetFrameLevel(level)
    self.contentPane = contentPane

    local contentInset = CreateInset(contentPane, level, canvas,
        W - self.CONTENT_LEFT - 10, H - self.CONTENT_INSET_TOP - self.CONTENT_INSET_BOTTOM)
    contentInset:SetPoint("TOPLEFT", 4, -self.CONTENT_INSET_TOP)
    contentInset:SetPoint("BOTTOMRIGHT", -6, self.CONTENT_INSET_BOTTOM)
    self.contentInset = contentInset

    -- Marble reads pale under white text; retail darkens its list areas the
    -- same way (the quest-paper art), so shade the whole inset a little.
    local shade = canvas:CreateTexture(nil, "ARTWORK")
    shade:SetAllPoints(contentInset)
    SetSolidTexture(shade, 0, 0, 0, 0.30)

    local contentTitle = contentPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    contentTitle:SetPoint("TOP", contentInset, "TOP", 0, 22)
    contentTitle:SetText("Dungeon Finder")
    self.retailContentTitle = contentTitle

    -- Every view lives one level above the inset so its border stays
    -- underneath, and the status line (level + 6) sits over all of them.
    local views = CreateFrame("Frame", nil, contentInset)
    views:SetAllPoints()
    views:SetFrameLevel(level + 1)
    self.contentViews = views

    -- Browser view: role buttons, Type / Difficulty filters, results list.
    local browserFrame = CreateFrame("Frame", nil, views)
    browserFrame:SetAllPoints()
    self.compactBrowserFrame = browserFrame

    self.compactRoles = self.compactRoles or { dps = true }
    local canTank, canHeal = GetClassRoleCaps()
    -- Roles the player's class cannot fill must never be selected.
    if not canTank then self.compactRoles.tank = false end
    if not canHeal then self.compactRoles.healer = false end
    self.compactRoleButtons = {}
    local insetWidth = W - self.CONTENT_LEFT - 4 - 6
    local roleSize, roleGap = self.ROLE_BUTTON_SIZE, self.ROLE_BUTTON_GAP
    local roleX = math.floor((insetWidth - (4 * roleSize + 3 * roleGap)) / 2)
    local roleStep = roleSize + roleGap
    self:CreateCompactRoleButton(browserFrame, "tank", roleX,
        self.compactRoles.tank, "Tank", canTank)
    self:CreateCompactRoleButton(browserFrame, "healer", roleX + roleStep,
        self.compactRoles.healer, "Healer", canHeal)
    self:CreateCompactRoleButton(browserFrame, "dps", roleX + roleStep * 2,
        self.compactRoles.dps, "Damage", true)
    self:CreateCompactRoleButton(browserFrame, "leader", roleX + roleStep * 3,
        self.compactRoles.leader, "Leader", true)
    if not canTank and self.compactRoleButtons.tank then
        self.compactRoleButtons.tank:Disable()
        self.compactRoleButtons.tank:SetAlpha(0.45)
    end
    if not canHeal and self.compactRoleButtons.healer then
        self.compactRoleButtons.healer:Disable()
        self.compactRoleButtons.healer:SetAlpha(0.45)
    end
    self:UpdateCompactRoleButtons()

    -- Stock dropdowns, like the 3.3.5 Dungeon Finder's "Choose your dungeon".
    local typeDropdown = CreateFrame("Frame", "DCGroupFinderTypeDropDown",
        browserFrame, "UIDropDownMenuTemplate")
    typeDropdown:SetPoint("TOPLEFT", 74, -(self.FILTER_TOP - 6))
    UIDropDownMenu_SetWidth(typeDropdown, 180)
    if UIDropDownMenu_JustifyText then
        UIDropDownMenu_JustifyText(typeDropdown, "LEFT")
    end
    UIDropDownMenu_Initialize(typeDropdown, InitTypeDropdown)
    UIDropDownMenu_SetText(typeDropdown, "Specific Dungeons")
    self.compactTypeDropdown = typeDropdown

    local typeLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("RIGHT", typeDropdown, "LEFT", 16, 3)
    typeLabel:SetText("Type:")
    self.compactTypeLabel = typeLabel

    -- Dungeon difficulty ("Specific Dungeons" only): the matchmaking queue
    -- supports Normal and Heroic here; Mythic runs through the Mythic+ type.
    local diffDropdown = CreateFrame("Frame", "DCGroupFinderDifficultyDropDown",
        browserFrame, "UIDropDownMenuTemplate")
    diffDropdown:SetPoint("TOPLEFT", 74, -(self.FILTER_TOP + self.FILTER_ROW_HEIGHT - 6))
    UIDropDownMenu_SetWidth(diffDropdown, 120)
    if UIDropDownMenu_JustifyText then
        UIDropDownMenu_JustifyText(diffDropdown, "LEFT")
    end
    UIDropDownMenu_Initialize(diffDropdown, InitDifficultyDropdown)
    UIDropDownMenu_SetText(diffDropdown,
        self.DUNGEON_DIFFICULTY_LABELS[self.queueDungeonDifficulty or 0] or "Normal")
    self.compactDiffDropdown = diffDropdown

    local diffLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffLabel:SetPoint("RIGHT", diffDropdown, "LEFT", 16, 3)
    diffLabel:SetText("Difficulty:")
    self.compactDiffLabel = diffLabel

    -- Results list: recessed a shade darker, stock scroll bar on the right.
    -- SelectCompactType moves its top edge under the visible filter rows.
    local listFrame = CreateFrame("Frame", nil, browserFrame)
    listFrame:SetPoint("TOPLEFT", browserFrame, "TOPLEFT", 8,
        -(self.LIST_TOP_BASE + self.FILTER_ROW_HEIGHT * 2))
    listFrame:SetPoint("BOTTOMRIGHT", browserFrame, "BOTTOMRIGHT", -8, self.LIST_BOTTOM)
    self.compactListFrame = listFrame

    local listBg = listFrame:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    SetSolidTexture(listBg, 0, 0, 0, 0.30)

    local scroll = CreateFrame("ScrollFrame", "DCCompactGroupFinderScroll",
        listFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", -24, 2)
    local rowWidth = insetWidth - 16 - 2 - 24 - 2
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(rowWidth, 100)
    scroll:SetScrollChild(child)
    self.compactScrollChild = child
    self.compactRowWidth = rowWidth

    -- Daily reward line under the list. UpdateRewardRow shows it in the
    -- Dungeon Finder queue views only, the way the stock finder shows the
    -- random-dungeon reward next to its list.
    local reward = CreateFrame("Frame", nil, browserFrame)
    reward:SetPoint("BOTTOMLEFT", 12, self.LIST_BOTTOM + 2)
    reward:SetPoint("BOTTOMRIGHT", -12, self.LIST_BOTTOM + 2)
    reward:SetHeight(20)
    reward:Hide()
    reward.label = reward:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reward.label:SetPoint("LEFT", 2, 0)
    reward.label:SetText("Daily Reward:")
    reward.icon = reward:CreateTexture(nil, "ARTWORK")
    reward.icon:SetSize(18, 18)
    reward.icon:SetPoint("LEFT", reward.label, "RIGHT", 6, 0)
    reward.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    reward.text = reward:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reward.text:SetPoint("LEFT", reward.icon, "RIGHT", 5, 0)
    reward.text:SetPoint("RIGHT", -2, 0)
    reward.text:SetJustifyH("LEFT")
    self.compactRewardRow = reward

    -- Premade Groups home: the category banner list, centred in the inset.
    local homeFrame = CreateFrame("Frame", nil, views)
    homeFrame:SetPoint("TOPLEFT", 0, -12)
    homeFrame:SetPoint("BOTTOMRIGHT", 0, self.LIST_BOTTOM)
    homeFrame:Hide()
    self.retailHomeFrame = homeFrame

    local categoryY = 0
    for _, kind in ipairs(self.PREMADE_CATEGORY_ORDER) do
        local option = self.COMPACT_OPTIONS[kind]
        if option then
            self:CreateRetailPremadeCategoryButton(homeFrame, kind, option.label, categoryY)
            categoryY = categoryY - 50
        end
    end

    -- Hinterland BG queue panel (mirrors the standalone DC-HinterlandBG
    -- Queue tab: live status text + join/leave through the HLBG helpers).
    local hlbgPanel = CreateFrame("Frame", nil, views)
    hlbgPanel:SetPoint("TOPLEFT", 6, -6)
    hlbgPanel:SetPoint("BOTTOMRIGHT", -6, self.LIST_BOTTOM)
    hlbgPanel:Hide()
    self.hlbgPanel = hlbgPanel

    local hlbgStatus = hlbgPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hlbgStatus:SetPoint("TOP", 0, -24)
    hlbgStatus:SetWidth(insetWidth - 40)
    hlbgStatus:SetJustifyH("CENTER")
    hlbgStatus:SetText("")
    hlbgPanel.status = hlbgStatus

    -- Watch the running match without joining it; toggles to Stop Watching
    -- while an HLBG spectator session is active (see UpdateHinterlandPanel).
    local hlbgWatch = CreateRetailActionButton(hlbgPanel, 150, 22, "Watch Live Match")
    hlbgWatch:SetPoint("BOTTOM", 0, 8)
    hlbgWatch:SetScript("OnClick", function() GF:ToggleHinterlandSpectate() end)
    hlbgPanel.watchButton = hlbgWatch

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

    -- Status line at the foot of the inset, above every view.
    local statusFrame = CreateFrame("Frame", nil, contentInset)
    statusFrame:SetPoint("BOTTOMLEFT", 6, 0)
    statusFrame:SetPoint("BOTTOMRIGHT", -6, 0)
    statusFrame:SetHeight(self.LIST_BOTTOM)
    statusFrame:SetFrameLevel(level + 6)
    local statusText = statusFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOM", 0, self.STATUS_BOTTOM)
    statusText:SetWidth(300)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("")
    frame.StatusText = statusText

    -- Action buttons in the strip under the inset (retail: Find Group
    -- centred; Find + Start side by side on the premade views).
    local primary = CreateRetailActionButton(contentPane, 150, 22, "Find Group")
    primary:SetPoint("BOTTOM", contentPane, "BOTTOM", 0, self.ACTION_BUTTON_BOTTOM)
    primary:SetScript("OnClick", function() GF:CompactPrimaryAction() end)
    self.compactPrimaryButton = primary

    local create = CreateRetailActionButton(contentPane, 135, 22, "Start a Group")
    create:Hide()
    create:SetScript("OnClick", function()
        GF:ShowCompactCreateDialog(GF.retailHomeShown and GF.premadeSelectedKind
            or GF.compactSelectedKind or "mythic")
    end)
    self.compactCreateButton = create

    self.mainFrame = frame
    self.compactMode = true
    self.compactData = self.compactData or {}

    -- Bottom tabs (retail PVEFrame style: Dungeons & Raids | Player vs
    -- Player | Mythic+ | Spectate).
    self:CreateBottomTabs(frame)
    self:SelectCompactType("dungeons")

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
    -- Retail-style bottom tab names (Dungeons & Raids / Player vs Player /
    -- Mythic+), plus Spectate for every watchable live session.
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
        { key = "spectate", label = "Spectate",      onClick = function()
            GF:ShowSpectatePanel()
        end },
    }

    -- Real Blizzard folder tabs: CharacterFrameTabButtonTemplate is the stock
    -- 3.3.5 bottom-tab art (the retail-era name PanelTabButtonTemplate doesn't
    -- exist in this client, but this is the same visual). Anchored where the
    -- character frame hangs its tabs under the retail chrome.
    self.bottomTabs = {}
    self.bottomTabOrder = {}

    local previous
    for i, def in ipairs(TAB_DEFS) do
        local tab = CreateFrame("Button", "DCGroupFinderBottomTab" .. i, frame,
            "CharacterFrameTabButtonTemplate")
        tab.key = def.key
        tab:SetText(def.label)
        tab:SetID(i)

        -- The active tab art rises 5px above the button, so the tab hangs
        -- 3px below the frame and sits one level under it: the frame's
        -- bottom border covers the overlap instead of the tab painting over
        -- the metal edge.
        tab:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
        if previous then
            tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", -16, 0)
        else
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, -3)
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

    self:HideContentViews()
    self.pvpPanelShown = true

    if not self.pvpPanel then
        local panel = CreateFrame("Frame", nil, self.contentViews or self.mainFrame)
        panel:SetAllPoints()

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

        -- Same 300x46 banner rows as the Premade Groups home.
        local y = -12
        for _, def in ipairs(ROWS) do
            local row = CreateFrame("Button", nil, panel)
            row:SetSize(300, 46)
            row:SetPoint("TOP", panel, "TOP", 0, y)

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

        local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("TOP", panel, "TOP", 0, y - 6)
        note:SetWidth(280)
        note:SetJustifyH("CENTER")
        note:SetText("Battlegrounds and Arenas open the standard PvP window.")

        self.pvpPanel = panel
    end

    self.pvpPanel:Show()
    self:SetContentTitle("Player vs Player")
    self:SetRetailNavSelection(nil)
    self:SetActiveBottomTab("pvp")
    self:UpdateCompactButtons()
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

    self:HideContentViews()
    self.mythicPanelShown = true

    if not self.mythicPanel then
        local panel = CreateFrame("Frame", nil, self.contentViews or self.mainFrame)
        panel:SetAllPoints()

        -- Keystone
        local keyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        keyLabel:SetPoint("TOPLEFT", 16, -16)
        keyLabel:SetText("Your Keystone:")

        local keyValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        keyValue:SetPoint("LEFT", keyLabel, "RIGHT", 8, 0)
        keyValue:SetText("|cff888888Unknown|r")
        panel.keyValue = keyValue

        -- Weekly affixes
        local affixLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        affixLabel:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -10)
        affixLabel:SetText("This Week:")

        local affixValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        affixValue:SetPoint("TOPLEFT", affixLabel, "TOPRIGHT", 8, 1)
        affixValue:SetWidth(210)
        affixValue:SetJustifyH("LEFT")
        affixValue:SetText("|cff888888Requesting...|r")
        panel.affixValue = affixValue

        -- Best runs
        local divider = panel:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", 12, -78)
        divider:SetPoint("TOPRIGHT", -12, -78)
        divider:SetHeight(3)
        if not SetGFAtlas(divider, "divider") then
            SetSolidTexture(divider, 0.35, 0.30, 0.20, 0.8)
        end

        local runsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        runsLabel:SetPoint("TOPLEFT", 16, -90)
        runsLabel:SetText("Best Runs This Season")

        panel.runLines = {}
        for i = 1, 8 do
            local line = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("TOPLEFT", 22, -92 - i * 17)
            line:SetWidth(290)
            line:SetJustifyH("LEFT")
            if line.SetWordWrap then
                line:SetWordWrap(false)
            end
            line:SetText("")
            panel.runLines[i] = line
        end

        -- Teleporter note (teleports stay on the Seasonal Portal NPC).
        local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        note:SetPoint("BOTTOM", 0, 64)
        note:SetWidth(300)
        note:SetJustifyH("CENTER")
        note:SetText("Dungeon teleports are available at the Mythic+ teleporter.")

        local browseBtn = CreateRetailActionButton(panel, 150, 22, "Browse M+ Groups")
        browseBtn:SetPoint("BOTTOMLEFT", 12, 36)
        browseBtn:SetScript("OnClick", function()
            GF.retailNavContext = "premade"
            GF.premadeSelectedKind = "mythic"
            GF:SelectCompactType("mythic")
            GF:SearchCustomCategory("mythic")
        end)

        local vaultBtn = CreateRetailActionButton(panel, 130, 22, "Great Vault")
        vaultBtn:SetPoint("BOTTOMRIGHT", -12, 36)
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
    self:SetContentTitle("Mythic+")
    self:SetRetailNavSelection(nil)
    self:SetActiveBottomTab("mythic")
    self:UpdateCompactButtons()

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
-- In-frame Spectate panel (bottom tab): every live session players can
-- watch - Mythic+ runs, Hinterland BG matches, phased duels - and the session
-- the player is watching now. The list comes from SMSG_SPECTATE_LIST through
-- LiveRunsTab.lua (GF.liveEntries, GF.DescribeLiveEntry, GF.FilterLiveEntries).
-- =====================================================================

-- "mplus" holds every dungeon run: keystone runs and the bots' Normal/Heroic
-- runs without a key, which the server lists alongside them.
local SPECTATE_FILTERS = {
    { key = "all",   label = "All" },
    { key = "mplus", label = "Dungeons" },
    { key = "hlbg",  label = "Hinterland" },
    { key = "duel",  label = "Duels" },
}

local SPECTATE_SYSTEM_TAGS = {
    mplus = "|cffff8000M+|r",
    hlbg = "|cff3fa9ffHLBG|r",
    duel = "|cffffd100Duel|r",
}

-- Row tag of a dungeon run without a keystone, by instance difficulty.
local SPECTATE_DIFFICULTY_TAGS = {
    [0] = "|cff1eff00NM|r",
    [1] = "|cff0070ddHC|r",
    [2] = "|cffa335eeM0|r",
}

local SPECTATE_ROW_HEIGHT = 40
local SPECTATE_REFRESH_SECONDS = 10

function GF:RequestSpectateList()
    local DC = GetDCProtocol()
    if DC and DC.GroupFinder and DC.GroupFinder.GetSpectateList then
        DC.GroupFinder.GetSpectateList()
        return true
    end
    return false
end

function GF:ShowSpectatePanel()
    if not self.mainFrame then return end

    self:HideContentViews()
    if not self.spectatePanel then
        self:CreateSpectatePanel()
    end

    self.spectatePanelShown = true
    self.spectatePanel:Show()
    self:SetContentTitle("Spectate")
    self:SetRetailNavSelection(nil)
    self:SetActiveBottomTab("spectate")
    self:RefreshSpectatePanel()
    self:UpdateCompactButtons()
end

function GF:CreateSpectatePanel()
    local panel = CreateFrame("Frame", nil, self.contentViews or self.mainFrame)
    panel:SetAllPoints()
    panel:Hide()

    local insetWidth = self.FRAME_WIDTH - self.CONTENT_LEFT - 10

    -- Active session strip: what the player is watching, with Leave.
    local session = CreateFrame("Frame", nil, panel)
    session:SetPoint("TOPLEFT", 8, -8)
    session:SetPoint("TOPRIGHT", -8, -8)
    session:SetHeight(26)

    local sessionBg = session:CreateTexture(nil, "BACKGROUND")
    sessionBg:SetAllPoints()
    SetSolidTexture(sessionBg, 0, 0, 0, 0.30)

    local sessionText = session:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sessionText:SetPoint("LEFT", 8, 0)
    sessionText:SetPoint("RIGHT", -80, 0)
    sessionText:SetJustifyH("LEFT")
    if sessionText.SetWordWrap then
        sessionText:SetWordWrap(false)
    end
    panel.sessionText = sessionText

    local leave = CreateRetailActionButton(session, 70, 20, "Leave")
    leave:SetPoint("RIGHT", -3, 0)
    leave:SetScript("OnClick", function()
        if GF.LeaveSpectate then
            GF:LeaveSpectate()
        end
    end)
    panel.leaveButton = leave

    -- System filters, each showing how many sessions it holds.
    panel.filterButtons = {}
    local count = #SPECTATE_FILTERS
    local buttonWidth, gap = 74, 4
    local x = math.floor((insetWidth - (count * buttonWidth + (count - 1) * gap)) / 2)
    local previous
    for _, def in ipairs(SPECTATE_FILTERS) do
        local button = CreateRetailActionButton(panel, buttonWidth, 20, def.label)
        button:SetNormalFontObject(GameFontNormalSmall)
        button:SetHighlightFontObject(GameFontHighlightSmall)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
        else
            button:SetPoint("TOPLEFT", x, -42)
        end
        button.filterKey = def.key
        button.baseLabel = def.label
        button:SetScript("OnClick", function(self)
            GF.spectateFilter = self.filterKey
            GF:RefreshSpectatePanel()
        end)
        panel.filterButtons[def.key] = button
        previous = button
    end

    -- Session list.
    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", 8, -68)
    list:SetPoint("BOTTOMRIGHT", -8, 56)

    local listBg = list:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    SetSolidTexture(listBg, 0, 0, 0, 0.30)

    local scroll = CreateFrame("ScrollFrame", "DCGroupFinderSpectateScroll", list, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", -24, 2)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(self.compactRowWidth or 285, 100)
    scroll:SetScrollChild(child)
    panel.scrollChild = child
    panel.rows = {}

    local emptyTitle = list:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyTitle:SetPoint("TOP", 0, -48)
    emptyTitle:SetTextColor(0.6, 0.6, 0.6)
    panel.emptyTitle = emptyTitle

    local emptySub = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptySub:SetPoint("TOP", emptyTitle, "BOTTOM", 0, -6)
    emptySub:SetWidth(260)
    emptySub:SetJustifyH("CENTER")
    emptySub:SetText("Mythic+ and bot dungeon runs, Hinterland BG matches and phased duels show up here while they are running.")
    panel.emptySub = emptySub

    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOM", 0, 34)
    note:SetWidth(300)
    note:SetJustifyH("CENTER")
    note:SetText("To spectate, leave your group, dismount, dismiss your pet and be out of combat.")

    -- Refresh on open and every few seconds while the tab stays open.
    panel:SetScript("OnShow", function(self)
        self._refreshAcc = 0
        GF:RequestSpectateList()
    end)
    panel:SetScript("OnUpdate", function(self, elapsed)
        self._refreshAcc = (self._refreshAcc or 0) + elapsed
        if self._refreshAcc < SPECTATE_REFRESH_SECONDS then return end
        self._refreshAcc = 0
        GF:RequestSpectateList()
    end)

    self.spectatePanel = panel
    return panel
end

function GF:CreateSpectateRow(parent)
    local rowWidth = self.compactRowWidth or 285
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(rowWidth, SPECTATE_ROW_HEIGHT - 2)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    SetRetailBlueMenuBackground(row.bg, "normal")

    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tag:SetPoint("TOPLEFT", 6, -5)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.tag, "RIGHT", 4, 0)
    row.name:SetWidth(rowWidth - 190)
    row.name:SetJustifyH("LEFT")

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("TOPLEFT", 6, -21)
    row.detail:SetWidth(rowWidth - 150)
    row.detail:SetJustifyH("LEFT")

    -- One line each: a wrapped line would paint over the row below. Guarded,
    -- as elsewhere in this file, because not every FontString has it.
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    if row.detail.SetWordWrap then row.detail:SetWordWrap(false) end

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("TOPRIGHT", -70, -6)
    row.meta:SetWidth(70)
    row.meta:SetJustifyH("RIGHT")

    row.watchers = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.watchers:SetPoint("TOPRIGHT", -70, -21)
    row.watchers:SetWidth(70)
    row.watchers:SetJustifyH("RIGHT")

    row.watch = CreateRetailActionButton(row, 60, 20, "Watch")
    row.watch:SetPoint("RIGHT", -4, 0)
    row.watch:SetNormalFontObject(GameFontNormalSmall)
    row.watch:SetHighlightFontObject(GameFontHighlightSmall)
    row.watch:SetDisabledFontObject(GameFontDisableSmall)
    row.watch:SetScript("OnClick", function(button)
        local entry = row.entry
        if not entry then return end

        if button.isCurrent then
            GF:LeaveSpectate()
            return
        end

        GF:SetStatusMessage("Requesting to watch: " .. (GF.DescribeLiveEntry(entry) or "session"))
        GF:RequestSpectate(entry.id or entry.runId or entry.instanceId, entry.leader or entry.name, entry.system)
    end)

    return row
end

-- Session strip only; also called on every live snapshot while watching.
function GF:UpdateSpectateSession()
    local panel = self.spectatePanel
    if not panel or not panel:IsShown() then return end

    if not self._spectatorSessionActive then
        panel.sessionText:SetText("|cffaaaaaaNot spectating. Pick a session below to watch it.|r")
        panel.leaveButton:Hide()
        return
    end

    local label = self._spectatorLabel
        or (self.LIVE_SYSTEM_LABELS and self.LIVE_SYSTEM_LABELS[self._spectatorSystem or "mplus"])
        or "a session"
    local detail = self.spectatorHUD and self.spectatorHUD.dungeonText and self.spectatorHUD.dungeonText:GetText()
    if detail and detail ~= "" and detail ~= label then
        panel.sessionText:SetText(string.format("|cff00ff00Watching:|r %s  |cffaaaaaa%s|r", label, detail))
    else
        panel.sessionText:SetText(string.format("|cff00ff00Watching:|r %s", label))
    end
    panel.leaveButton:Show()
end

function GF:RefreshSpectatePanel()
    local panel = self.spectatePanel
    if not panel or not panel:IsShown() then return end
    if not (self.DescribeLiveEntry and self.FilterLiveEntries) then return end

    self:UpdateSpectateSession()

    local entries = self.liveEntries or {}
    local filter = self.spectateFilter or "all"

    local counts = { all = #entries }
    for _, entry in ipairs(entries) do
        local system = entry.system or "mplus"
        counts[system] = (counts[system] or 0) + 1
    end

    for key, button in pairs(panel.filterButtons) do
        button:SetText(string.format("%s (%d)", button.baseLabel, counts[key] or 0))
        if key == filter then
            button:SetNormalFontObject(GameFontHighlightSmall)
            button:LockHighlight()
        else
            button:SetNormalFontObject(GameFontNormalSmall)
            button:UnlockHighlight()
        end
    end

    local shown = self:FilterLiveEntries(entries, filter)
    for _, row in ipairs(panel.rows) do
        row:Hide()
    end

    for i, entry in ipairs(shown) do
        local row = panel.rows[i]
        if not row then
            row = self:CreateSpectateRow(panel.scrollChild)
            panel.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -(i - 1) * SPECTATE_ROW_HEIGHT)

        local system = entry.system or "mplus"
        local title, detail, meta, watching = self.DescribeLiveEntry(entry)
        row.entry = entry
        local tag = SPECTATE_SYSTEM_TAGS[system] or system
        if self.IsKeylessLiveEntry and self.IsKeylessLiveEntry(entry) then
            tag = SPECTATE_DIFFICULTY_TAGS[math.floor(tonumber(entry.difficulty) or 0)] or tag
        end
        row.tag:SetText(tag)
        row.name:SetText(title or "")
        row.detail:SetText(detail or "")
        row.meta:SetText(meta or "")
        row.watchers:SetText(watching or "")

        -- The session being watched offers Leave; while watching anything,
        -- the other rows cannot start a second session.
        local id = tonumber(entry.id or entry.runId or entry.instanceId) or 0
        local isCurrent = self._spectatorSessionActive and self._spectatorSystem == system
            and self._spectatorSessionId == id
        row.watch.isCurrent = isCurrent
        if isCurrent then
            row.watch:SetText("Leave")
            row.watch:Enable()
            SetRetailBlueMenuBackground(row.bg, "selected")
        else
            row.watch:SetText("Watch")
            if self._spectatorSessionActive then
                row.watch:Disable()
            else
                row.watch:Enable()
            end
            SetRetailBlueMenuBackground(row.bg, "normal")
        end

        row:Show()
    end

    panel.scrollChild:SetHeight(math.max(#shown * SPECTATE_ROW_HEIGHT, 200))

    if #shown == 0 then
        panel.emptyTitle:SetText(filter == "all" and "Nothing to watch right now" or "None of these are running")
        panel.emptyTitle:Show()
        panel.emptySub:Show()
    else
        panel.emptyTitle:Hide()
        panel.emptySub:Hide()
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
-- Daily reward (GRPF system info)
-- =====================================================================

-- Icon + "2x Emblem of Frost" for the server's daily reward payload.
local function DescribeDailyReward(data)
    local text = ""
    local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"

    local rewardItemId = tonumber(data.rewardItemId) or 0
    local rewardItemCount = tonumber(data.rewardItemCount) or 1

    -- Prefer the central Upgrade Token if the server still sends a
    -- placeholder (commonly 49426 = Emblem of Frost).
    local DC = GetDCProtocol()
    local centralTokenId = (DC and tonumber(DC.TOKEN_ITEM_ID)) or 0
    if centralTokenId > 0 and (rewardItemId == 0 or rewardItemId == 49426) then
        rewardItemId = centralTokenId
        rewardItemCount = 1
    end

    if rewardItemId > 0 then
        local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(rewardItemId)
        if itemIcon then
            iconTexture = itemIcon
        end
        -- GetItemInfo is nil until the client has cached the item; the next
        -- system-info push refreshes the line.
        text = rewardItemCount .. "x " .. (itemName or ("Item " .. rewardItemId))
    elseif (tonumber(data.rewardCurrencyId) or 0) > 0 and GetCurrencyInfo then
        local name, _, icon = GetCurrencyInfo(data.rewardCurrencyId)
        if icon then
            iconTexture = icon
        end
        text = (tonumber(data.rewardCurrencyCount) or 1) .. "x " .. (name or "Currency")
    end

    return iconTexture, text
end

-- Show the daily reward line under the list in the Dungeon Finder queue
-- views only (it is the queue's reward, so it has no business on the
-- Spectate or Mythic+ tabs) and give the list the room back elsewhere.
function GF:UpdateRewardRow()
    local row = self.compactRewardRow
    if not (row and self.compactListFrame and self.compactBrowserFrame) then return end

    local kind = self.compactSelectedKind or "mythic"
    local reward = self._dailyReward
    local show = reward ~= nil and self.retailNavContext ~= "premade"
        and (kind == "dungeons" or kind == "mythic")

    if show then
        row.icon:SetTexture(reward.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.text:SetText(reward.text or "")
        row:Show()
    else
        row:Hide()
    end

    self.compactListFrame:SetPoint("BOTTOMRIGHT", self.compactBrowserFrame, "BOTTOMRIGHT",
        -8, self.LIST_BOTTOM + (show and 22 or 0))
end

function GF:UpdateSystemInfo(data)
    if type(data) ~= "table" then return end

    if data.rewardEnabled then
        local icon, text = DescribeDailyReward(data)
        self._dailyReward = { icon = icon, text = text }
    else
        self._dailyReward = nil
    end

    self:UpdateRewardRow()
end

Print("Group Finder UI module loaded")
