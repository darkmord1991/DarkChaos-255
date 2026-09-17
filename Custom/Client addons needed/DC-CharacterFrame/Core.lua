--[[
    DC-CharacterFrame / Core.lua
    ============================
    Retail-style (11.x) character panel for the 3.3.5a client.

    The stock CharacterFrame / PaperDollFrame are NOT replaced - every Blizzard
    global keeps its implementation and every other addon that hooks the
    character frame keeps working. This addon restyles the frames in place:
    retail nine-slice chrome, re-anchored equipment slots, a sidebar with
    Stats / Titles / Equipment Sets / Upgrades panes and a synced outfit
    dropdown. For the other tabs (Pet, Reputation, Skills, Currency), whose art
    is baked into their own 384x512 textures, the frame switches back to the
    stock geometry.

    Files:
      Core.lua     - namespace, art tables, saved settings, mode switching, init
      Chrome.lua   - outer frame art, insets, model backdrop, slot layout
      Stats.lua    - sidebar 1: item level + collapsible stat categories
      Sidebar.lua  - sidebar tab strip, Titles pane, Equipment Sets pane
      Outfits.lua  - synced transmog outfit dropdown (DC-Collection)
      Upgrades.lua - sidebar 4: item / heirloom upgrade pane (DC-ItemUpgrade)
]]

DCCharacterFrame = DCCharacterFrame or {}
local DCCF = DCCharacterFrame

DCCF.VERSION = "1.0.0"
DCCF.TEX = "Interface\\AddOns\\DC-CharacterFrame\\Textures\\"

-- Retail PortraitFrame / InsetFrame nine-slice art. Root paths: these files ship
-- in the DC client patch (Interface\FrameGeneral) and are already used by the
-- DC-Journal SharedXML templates.
DCCF.TEX_FRAME      = "Interface\\FrameGeneral\\UI-Frame"
DCCF.TEX_FRAME_H    = "Interface\\FrameGeneral\\_UI-Frame"
DCCF.TEX_FRAME_V    = "Interface\\FrameGeneral\\!UI-Frame"
DCCF.TEX_ROCK       = "Interface\\FrameGeneral\\UI-Background-Rock"
DCCF.TEX_MARBLE     = "Interface\\FrameGeneral\\UI-Background-Marble"
DCCF.TEX_WHITEFRAME = "Interface\\Common\\WhiteIconFrame"

-- Retail character-frame art bundled with the addon (extracted from 11.2.5).
DCCF.TEX_PARTS   = DCCF.TEX .. "Char-Paperdoll-Parts"
DCCF.TEX_HORIZ   = DCCF.TEX .. "Char-Paperdoll-Horizontal"
DCCF.TEX_VERT    = DCCF.TEX .. "Char-Paperdoll-Vertical"
DCCF.TEX_STATMID = DCCF.TEX .. "Char-Stat-Middle"
DCCF.TEX_INFO1   = DCCF.TEX .. "PaperDollInfoPart1"
DCCF.TEX_INFO2   = DCCF.TEX .. "PaperDollInfoPart2"
DCCF.TEX_SIDEBAR = DCCF.TEX .. "PaperDollSidebarTabs"
DCCF.TEX_PLUS    = DCCF.TEX .. "Character-Plus"
DCCF.TEX_PANELBG = DCCF.TEX .. "CharacterPanelBackground"

-- Geometry. Retail: PANEL_DEFAULT_WIDTH 338, CHARACTERFRAME_EXPANDED_WIDTH 540,
-- height 424. The paperdoll always shows expanded (sidebar visible). The frame
-- is 16px wider than retail so the sidebar keeps retail-width rows next to the
-- 3.3.5 scrollbar.
DCCF.RETAIL_WIDTH  = 556
DCCF.RETAIL_HEIGHT = 424
DCCF.PANEL_WIDTH   = 338
DCCF.STOCK_WIDTH   = 384
DCCF.STOCK_HEIGHT  = 512
-- UIPanel x offset in retail mode: the portrait ring hangs 14px past the
-- frame edge and would be clipped at the screen edge otherwise.
DCCF.RETAIL_XOFFSET = 16

-- ---------------------------------------------------------------------------
-- Atlas pieces. { width, height, left, right, top, bottom }
-- ---------------------------------------------------------------------------

-- Char-Paperdoll-Parts (256x128)
DCCF.PARTS = {
    StatBottom       = { 169, 46, 0.00390625, 0.66406250, 0.00781250, 0.36718750 },
    StatMinimized    = { 169, 14, 0.00390625, 0.66406250, 0.38281250, 0.49218750 },
    StatTop          = { 169, 9,  0.00390625, 0.66406250, 0.50781250, 0.57812500 },
    RightSlot        = { 50, 44,  0.00390625, 0.19921875, 0.59375000, 0.93750000 },
    StatMinus        = { 7, 3,    0.00390625, 0.03125000, 0.95312500, 0.97656250 },
    LeftSlot         = { 49, 44,  0.20703125, 0.39843750, 0.59375000, 0.93750000 },
    CornerLowerRight = { 7, 7,    0.40625000, 0.43359375, 0.59375000, 0.64843750 },
    CornerLowerLeft  = { 7, 7,    0.40625000, 0.43359375, 0.66406250, 0.71875000 },
    CornerUpperRight = { 7, 7,    0.40625000, 0.43359375, 0.73437500, 0.78906250 },
    CornerUpperLeft  = { 7, 7,    0.40625000, 0.43359375, 0.80468750, 0.85937500 },
    StatPlus         = { 7, 7,    0.40625000, 0.43359375, 0.87500000, 0.92968750 },
    BottomSlot       = { 42, 53,  0.67187500, 0.83593750, 0.00781250, 0.42187500 },
    SlotBottomRight  = { 7, 54,   0.67187500, 0.69921875, 0.43750000, 0.85937500 },
    SlotBottomLeft   = { 6, 54,   0.70703125, 0.73046875, 0.43750000, 0.85937500 },
}

-- PaperDollInfoPart1 (1024x1024)
DCCF.INFO = {
    Title           = { 196, 40, 0.000976562, 0.192383, 0.698242, 0.737305 },
    LineBounce      = { 157, 19, 0.000976562, 0.154297, 0.769531, 0.788086 },
    ItemLevelBounce = { 162, 29, 0.000976562, 0.15918,  0.739258, 0.767578 },
}

-- UI-Character-Info-<CLASS>-BG (197x355). { part, left, right, top, bottom }
DCCF.CLASS_BG = {
    WARLOCK     = { 1, 0.583984, 0.776367, 0.000977, 0.347656 },
    WARRIOR     = { 1, 0.778320, 0.970703, 0.000977, 0.347656 },
    MAGE        = { 1, 0.000977, 0.193359, 0.000977, 0.347656 },
    PALADIN     = { 1, 0.195312, 0.387695, 0.000977, 0.347656 },
    ROGUE       = { 1, 0.389648, 0.582031, 0.000977, 0.347656 },
    PRIEST      = { 1, 0.195312, 0.387695, 0.349609, 0.696289 },
    SHAMAN      = { 1, 0.389648, 0.582031, 0.349609, 0.696289 },
    MONK        = { 1, 0.000977, 0.193359, 0.349609, 0.696289 },
    DRUID       = { 2, 0.389648, 0.582031, 0.001953, 0.695312 },
    HUNTER      = { 2, 0.583984, 0.776367, 0.001953, 0.695312 },
    DEATHKNIGHT = { 2, 0.000977, 0.193359, 0.001953, 0.695312 },
    DEMONHUNTER = { 2, 0.195312, 0.387695, 0.001953, 0.695312 },
}

-- character-panel-background (450x420 inside CurrencyWindow 1024x512)
DCCF.PANELBG_COORDS = { 0.000976562, 0.44043, 0.00195312, 0.822266 }

-- PaperDollSidebarTabs (64x256)
DCCF.SIDEBAR = {
    DecorLeft   = { 28, 11, 0.01562500, 0.45312500, 0.00390625, 0.04687500 },
    DecorRight  = { 28, 13, 0.01562500, 0.45312500, 0.05468750, 0.10546875 },
    Hider       = { 34, 19, 0.01562500, 0.54687500, 0.11328125, 0.18750000 },
    Highlight   = { 31, 31, 0.01562500, 0.50000000, 0.19531250, 0.31640625 },
    IconTitles  = { 33, 35, 0.01562500, 0.53125000, 0.32421875, 0.46093750 },
    IconSets    = { 33, 35, 0.01562500, 0.53125000, 0.46875000, 0.60546875 },
    TabInactive = { 50, 43, 0.01562500, 0.79687500, 0.61328125, 0.78125000 },
    TabActive   = { 50, 43, 0.01562500, 0.79687500, 0.78906250, 0.95703125 },
}

-- UI-Frame (nine-slice corners)
DCCF.FRAME = {
    Portrait       = { 78, 78, 0.0078125, 0.6171875, 0.0078125, 0.6171875 },
    TopCornerRight = { 33, 33, 0.6328125, 0.890625,  0.0078125, 0.265625 },
    TopLeftCorner  = { 32, 32, 0.6328125, 0.8828125, 0.28125,   0.53125 },
    BotCornerLeft  = { 14, 14, 0.0078125, 0.1171875, 0.6328125, 0.7421875 },
    BotCornerRight = { 11, 11, 0.1328125, 0.21875,   0.8984375, 0.984375 },
    InnerTopLeft   = { 6, 6, 0.6328125, 0.6796875, 0.546875, 0.59375 },
    InnerTopRight  = { 6, 6, 0.90625,   0.953125,  0.21875,  0.265625 },
    InnerBotLeft   = { 6, 6, 0.6953125, 0.7421875, 0.546875, 0.59375 },
    InnerBotRight  = { 6, 6, 0.7578125, 0.8046875, 0.546875, 0.59375 },
}

-- _UI-Frame horizontal tiles: { height, top, bottom }
DCCF.FRAME_H = {
    TitleTile      = { 28, 0.4375,    0.65625 },
    TopTileStreaks = { 37, 0.671875,  0.9609375 },
    Bot            = { 9,  0.203125,  0.2734375 },
    TitleTileBG    = { 18, 0.2890625, 0.421875 },
    InnerTopTile   = { 3,  0.0859375, 0.109375 },
    InnerBotTile   = { 3,  0.0078125, 0.03125 },
}

-- !UI-Frame vertical tiles: { width, left, right }
DCCF.FRAME_V = {
    LeftTile       = { 16, 0.359375, 0.609375 },
    RightTile      = { 10, 0.171875, 0.328125 },
    InnerLeftTile  = { 3,  0.09375,  0.140625 },
    InnerRightTile = { 3,  0.015625, 0.0625 },
}

-- ---------------------------------------------------------------------------
-- Texture helpers
-- ---------------------------------------------------------------------------

-- Fixed-size atlas piece.
function DCCF.Tex(parent, layer, file, piece, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    tex:SetWidth(piece[1])
    tex:SetHeight(piece[2])
    tex:SetTexCoord(piece[3], piece[4], piece[5], piece[6])
    return tex
end

-- The 3.3.5 client has no Texture:SetHorizTile / SetVertTile (not in its
-- UI.xsd, never called by stock FrameXML). Thin lines are simply stretched;
-- patterned art is built from fixed-size segments; large backgrounds use the
-- frame backdrop, which does tile.

-- Stretched horizontal strip (height fixed, width from anchors).
function DCCF.TexH(parent, layer, file, def, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    tex:SetHeight(def[1])
    tex:SetTexCoord(0, 1, def[2], def[3])
    return tex
end

-- Stretched vertical strip (width fixed, height from anchors).
function DCCF.TexV(parent, layer, file, def, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    tex:SetWidth(def[1])
    tex:SetTexCoord(def[2], def[3], 0, 1)
    return tex
end

-- Horizontal strip of `totalW` built from `tileW`-wide segments so the
-- pattern repeats. The caller anchors segs[1]; the rest chain to its right.
function DCCF.StripH(parent, layer, file, def, totalW, tileW, sublevel)
    tileW = tileW or 256
    local segs, remaining, prev = {}, totalW, nil
    while remaining > 0 do
        local w = math.min(tileW, remaining)
        local tex = parent:CreateTexture(nil, layer, nil, sublevel)
        tex:SetTexture(file)
        tex:SetHeight(def[1])
        tex:SetWidth(w)
        tex:SetTexCoord(0, w / tileW, def[2], def[3])
        if prev then
            tex:SetPoint("TOPLEFT", prev, "TOPRIGHT")
        end
        table.insert(segs, tex)
        prev = tex
        remaining = remaining - w
    end
    return segs
end

-- Vertical strip of `totalH` built from `tileH`-tall segments; segs[1] is
-- anchored by the caller, the rest chain below it.
function DCCF.StripV(parent, layer, file, def, totalH, tileH, sublevel)
    tileH = tileH or 256
    local segs, remaining, prev = {}, totalH, nil
    while remaining > 0 do
        local h = math.min(tileH, remaining)
        local tex = parent:CreateTexture(nil, layer, nil, sublevel)
        tex:SetTexture(file)
        tex:SetWidth(def[1])
        tex:SetHeight(h)
        tex:SetTexCoord(def[2], def[3], 0, h / tileH)
        if prev then
            tex:SetPoint("TOP", prev, "BOTTOM")
        end
        table.insert(segs, tex)
        prev = tex
        remaining = remaining - h
    end
    return segs
end

-- Retail InsetFrameTemplate border (6px corners + 3px tiles) on `frame`.
function DCCF.AddInsetBorder(frame, layer)
    layer = layer or "OVERLAY"
    local F, FH, FV = DCCF.FRAME, DCCF.FRAME_H, DCCF.FRAME_V
    local tl = DCCF.Tex(frame, layer, DCCF.TEX_FRAME, F.InnerTopLeft)
    tl:SetPoint("TOPLEFT")
    local tr = DCCF.Tex(frame, layer, DCCF.TEX_FRAME, F.InnerTopRight)
    tr:SetPoint("TOPRIGHT")
    local bl = DCCF.Tex(frame, layer, DCCF.TEX_FRAME, F.InnerBotLeft)
    bl:SetPoint("BOTTOMLEFT", 0, -1)
    local br = DCCF.Tex(frame, layer, DCCF.TEX_FRAME, F.InnerBotRight)
    br:SetPoint("BOTTOMRIGHT", 0, -1)
    local top = DCCF.TexH(frame, layer, DCCF.TEX_FRAME_H, FH.InnerTopTile)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
    local bot = DCCF.TexH(frame, layer, DCCF.TEX_FRAME_H, FH.InnerBotTile)
    bot:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT")
    bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left = DCCF.TexV(frame, layer, DCCF.TEX_FRAME_V, FV.InnerLeftTile)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
    local right = DCCF.TexV(frame, layer, DCCF.TEX_FRAME_V, FV.InnerRightTile)
    right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
end

-- Tiled marble background used by every inset (backdrops tile; textures
-- created from Lua cannot on this client).
function DCCF.AddMarble(frame)
    frame:SetBackdrop({ bgFile = DCCF.TEX_MARBLE, tile = true, tileSize = 256 })
end

function DCCF:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00DC Character Frame:|r " .. tostring(msg))
end

-- ---------------------------------------------------------------------------
-- Saved settings (per character)
-- ---------------------------------------------------------------------------

local DEFAULTS = {
    sidebar = 1,               -- last selected sidebar pane
    collapsedStats = nil,      -- category key -> true (nil = class defaults)
    selectedOutfitId = 0,      -- last chosen outfit in the dropdown
    showSlotItemLevel = true,  -- item level badge on equipment slots
    position = nil,            -- { left, top } once the player dragged the frame
}

function DCCF:InitDB()
    DCCharacterFrameCharDB = DCCharacterFrameCharDB or {}
    self.db = DCCharacterFrameCharDB
    for k, v in pairs(DEFAULTS) do
        if self.db[k] == nil then
            self.db[k] = v
        end
    end
end

-- ---------------------------------------------------------------------------
-- Sidebar registry. Panes register at file load; Sidebar.lua builds them.
--   def = { key, name, icon/texCoords or portrait = true, build(parent) -> pane,
--           IsActive() -> bool [, disabledTooltip], onShow(pane) }
-- ---------------------------------------------------------------------------

DCCF.sidebars = {}

function DCCF:RegisterSidebar(def)
    table.insert(self.sidebars, def)
    return #self.sidebars
end

-- ---------------------------------------------------------------------------
-- Retail / stock mode switching
-- ---------------------------------------------------------------------------

DCCF.mode = nil

local function SafeCall(fn, ...)
    if type(fn) == "function" then
        return fn(...)
    end
end

-- The UIPanel layout reads xoffset from the UIPanelWindows entry (and from the
-- attribute once "defined"); keep both in sync.
local function SetPanelXOffset(x)
    local info = UIPanelWindows and UIPanelWindows["CharacterFrame"]
    if info then
        info.xoffset = x
    end
    CharacterFrame:SetAttribute("UIPanelLayout-xoffset", x)
end

-- ---------------------------------------------------------------------------
-- Player-dragged position (overrides the UIPanel slot until reset)
-- ---------------------------------------------------------------------------

function DCCF:SavePosition()
    local left, top = CharacterFrame:GetLeft(), CharacterFrame:GetTop()
    if left and top then
        self.db.position = { left = left, top = top }
    end
end

function DCCF:ApplySavedPosition()
    local pos = self.db and self.db.position
    if not pos then
        return
    end
    CharacterFrame:ClearAllPoints()
    CharacterFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.left, pos.top)
end

function DCCF:ResetPosition()
    self.db.position = nil
    UpdateUIPanelPositions(CharacterFrame)
end

function DCCF:ApplyRetailMode()
    if self.mode == "retail" then
        return
    end
    self.mode = "retail"

    CharacterFrame:SetWidth(self.RETAIL_WIDTH)
    CharacterFrame:SetHeight(self.RETAIL_HEIGHT)
    CharacterFrame:SetHitRectInsets(0, 0, 0, 0)
    SetPanelXOffset(self.RETAIL_XOFFSET)

    -- The stock portrait lives on CharacterFrame (a lower frame level than the
    -- chrome), so the chrome draws its own copy inside the retail ring.
    CharacterFramePortrait:Hide()

    -- Name goes into the title bar.
    CharacterNameFrame:ClearAllPoints()
    CharacterNameFrame:SetPoint("TOP", CharacterFrame, "TOP", 0, -3)
    CharacterNameFrame:SetWidth(200)
    CharacterNameFrame:SetHeight(16)
    CharacterNameFrame:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 3)
    CharacterNameText:SetWidth(200)

    CharacterFrameCloseButton:ClearAllPoints()
    CharacterFrameCloseButton:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", 4, 5)

    CharacterFrameTab1:ClearAllPoints()
    CharacterFrameTab1:SetPoint("TOPLEFT", CharacterFrame, "BOTTOMLEFT", 11, 2)

    UpdateUIPanelPositions(CharacterFrame)
end

function DCCF:ApplyStockMode()
    if self.mode == "stock" then
        return
    end
    self.mode = "stock"

    CharacterFrame:SetWidth(self.STOCK_WIDTH)
    CharacterFrame:SetHeight(self.STOCK_HEIGHT)
    CharacterFrame:SetHitRectInsets(0, 30, 0, 45)
    SetPanelXOffset(0)

    CharacterFramePortrait:Show()

    CharacterNameFrame:ClearAllPoints()
    CharacterNameFrame:SetPoint("CENTER", CharacterFrame, "CENTER", 6, 232)
    CharacterNameFrame:SetWidth(109)
    CharacterNameFrame:SetHeight(12)
    CharacterNameFrame:SetFrameLevel(CharacterFrame:GetFrameLevel() + 2)
    CharacterNameText:SetWidth(300)

    CharacterFrameCloseButton:ClearAllPoints()
    CharacterFrameCloseButton:SetPoint("CENTER", CharacterFrame, "TOPRIGHT", -44, -25)

    CharacterFrameTab1:ClearAllPoints()
    CharacterFrameTab1:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 11, 46)

    UpdateUIPanelPositions(CharacterFrame)
end

function DCCF:UpdateMode()
    if PaperDollFrame:IsShown() then
        self:ApplyRetailMode()
    else
        self:ApplyStockMode()
    end
end

-- ---------------------------------------------------------------------------
-- Refresh entry points (called by Chrome / events)
-- ---------------------------------------------------------------------------

function DCCF:OnPaperDollShow()
    self:ApplyRetailMode()
    SafeCall(self.UpdateHeader, self)
    SafeCall(self.UpdateModelBackground, self)
    SafeCall(self.UpdateWeaponRow, self)
    SafeCall(self.UpdateAllSlotOverlays, self)
    SafeCall(self.UpdateSidebarTabs, self)
    SafeCall(self.RefreshSidebar, self)
    SafeCall(self.RefreshOutfits, self)
end

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------

local initialized = false

local function Initialize()
    if initialized then
        return
    end
    initialized = true

    DCCF:InitDB()
    DCCF:BuildChrome()
    DCCF:LayoutPaperDoll()
    DCCF:BuildSidebar()
    SafeCall(DCCF.BuildOutfits, DCCF)
    SafeCall(DCCF.BuildUpgrades, DCCF)
    DCCF:BuildDragHandle()

    -- Tab switches inside the frame.
    hooksecurefunc("CharacterFrame_ShowSubFrame", function()
        DCCF:UpdateMode()
    end)
    CharacterFrame:HookScript("OnShow", function()
        DCCF:UpdateMode()
        DCCF:ApplySavedPosition()
    end)
    -- Every UIPanel re-layout (open/close of any panel) re-anchors the frame;
    -- put it back where the player dragged it.
    if FramePositionDelegate and type(FramePositionDelegate.UpdateUIPanelPositions) == "function" then
        hooksecurefunc(FramePositionDelegate, "UpdateUIPanelPositions", function()
            DCCF:ApplySavedPosition()
        end)
    end
    PaperDollFrame:HookScript("OnShow", function()
        DCCF:OnPaperDollShow()
    end)
    hooksecurefunc("PaperDollFrame_SetLevel", function()
        DCCF:UpdateHeader()
    end)

    DCCF:UpdateMode()
    if PaperDollFrame:IsShown() and CharacterFrame:IsShown() then
        DCCF:OnPaperDollShow()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_GUILD_UPDATE")
events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        Initialize()
        return
    end
    if not initialized then
        return
    end
    if event == "PLAYER_GUILD_UPDATE" then
        SafeCall(DCCF.UpdateHeader, DCCF)
    elseif event == "UNIT_PORTRAIT_UPDATE" then
        if arg1 == "player" then
            SafeCall(DCCF.UpdatePortrait, DCCF)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
        if PaperDollFrame:IsShown() then
            SafeCall(DCCF.UpdateWeaponRow, DCCF)
            SafeCall(DCCF.UpdateAllSlotOverlays, DCCF)
            SafeCall(DCCF.OnEquipmentChanged, DCCF)
        end
    end
end)
