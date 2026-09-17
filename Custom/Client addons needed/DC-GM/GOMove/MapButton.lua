-- GOMove minimap button placement.
--
-- The button rides the same ring as every other minimap button instead of
-- floating freely: LibDBIcon's track, radius 80 from the map centre, pulled
-- onto a bevelled square when GetMinimapShape() is SQUARE. Dragging moves it
-- along that ring and the angle is saved in GOMoveSV.MinimapAngle. When
-- DC-QOS's minimap module is enabled its button ring reads and writes the same
-- angle and moves the button aside if it would cover another one.

local DEFAULT_ANGLE = 190
local RING_RADIUS = 80
local RING_DIAG_RADIUS = math.sqrt(2 * RING_RADIUS * RING_RADIUS) - 10

local function SavedAngle()
    if type(GOMoveSV) == "table" and tonumber(GOMoveSV.MinimapAngle) then
        return tonumber(GOMoveSV.MinimapAngle)
    end
    return DEFAULT_ANGLE
end

function GOMove:UpdateMapButtonPosition()
    local button = GOMove_UI_MapButton
    if not button or not Minimap then
        return
    end

    local angle = math.rad(SavedAngle())
    local x, y = math.cos(angle), math.sin(angle)
    local shape = type(GetMinimapShape) == "function" and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        x = math.max(-RING_RADIUS, math.min(x * RING_DIAG_RADIUS, RING_RADIUS))
        y = math.max(-RING_RADIUS, math.min(y * RING_DIAG_RADIUS, RING_RADIUS))
    else
        x, y = x * RING_RADIUS, y * RING_RADIUS
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not mx or not my or not scale or scale <= 0 then
        return
    end

    local cx, cy = GetCursorPosition()
    if type(GOMoveSV) ~= "table" then
        GOMoveSV = {}
    end
    GOMoveSV.MinimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    GOMove:UpdateMapButtonPosition()
end

function GOMove:MapButtonDragStart(button)
    button.isDragging = true
    GameTooltip:Hide()
    button:SetScript("OnUpdate", FollowCursor)
end

function GOMove:MapButtonDragStop(button)
    button:SetScript("OnUpdate", nil)
    button.isDragging = nil
end

-- GOMoveSV is only loaded by ADDON_LOADED, after the button's OnLoad has run.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    GOMove:UpdateMapButtonPosition()
end)
