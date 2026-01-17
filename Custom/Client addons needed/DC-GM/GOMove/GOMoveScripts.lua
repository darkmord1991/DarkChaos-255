GOMove.FavL = {NameWidth = 17}
local function ensureGOMoveSV()
    if(not GOMoveSV or type(GOMoveSV) ~= "table") then
        GOMoveSV = {}
    end
    if (type(GOMoveSV.NPCFavL) ~= "table") then
        GOMoveSV.NPCFavL = {}
    end
end
ensureGOMoveSV()
GOMove.Mode = GOMove.Mode or "GO"
GOMove.ActiveModule = GOMove.ActiveModule or "GOMV"
GOMove.ActiveChannel = GOMove.ActiveChannel or "GOMOVE"

local function cloneFavs(source)
    local out = {NameWidth = 17}
    if (type(source) == "table") then
        for _, v in ipairs(source) do
            if (type(v) == "table") then
                table.insert(out, {v[1], v[2]})
            end
        end
    end
    return out
end

local function saveFavsForMode(mode)
    ensureGOMoveSV()
    if (mode == "NPC") then
        GOMoveSV.NPCFavL = cloneFavs(GOMove.FavL)
    else
        GOMoveSV.FavL = cloneFavs(GOMove.FavL)
    end
end

local function loadFavsForMode(mode)
    local source = (mode == "NPC") and GOMoveSV.NPCFavL or GOMoveSV.FavL
    local data = cloneFavs(source)
    for i = #GOMove.FavL, 1, -1 do
        table.remove(GOMove.FavL, i)
    end
    for _, v in ipairs(data) do
        table.insert(GOMove.FavL, v)
    end
    GOMove.FavL.NameWidth = 17
end
function GOMove.FavL:Add(name, guid)
    self:Del(guid)
    table.insert(self, 1, {name, guid})
    saveFavsForMode(GOMove.Mode)
end
function GOMove.FavL:Del(guid)
    for k,v in ipairs(self) do
        if(v[2] == guid) then
            table.remove(self, k)
            break
        end
    end
    saveFavsForMode(GOMove.Mode)
end

local FavFrame, SelFrame

GOMove.SelL = {NameWidth = 30}
function GOMove.SelL:Add(name, guid, entry, x, y, z)
    table.insert(self, 1, {name, guid, entry, x, y, z})
end
function GOMove.SelL:Del(guid)
    for k,v in ipairs(self) do
        if(v[2] == guid) then
            table.remove(self, k)
            break
        end
    end
end

GOMove.Selected = {}
function GOMove.Selected:Add(name, guid)
    self[guid] = name
end
function GOMove.Selected:Del(guid)
    self[guid] = nil
end

local function clearAllSelected()
    for guid, _ in pairs(GOMove.Selected) do
        if (tonumber(guid)) then
            GOMove.Selected:Del(guid)
        end
    end
end

local function clearSelectionList()
    for i = #GOMove.SelL, 1, -1 do
        GOMove.SelL:Del(GOMove.SelL[i][2])
    end
end

local function selectOnly(name, guid)
    clearAllSelected()
    if (name and guid) then
        GOMove.Selected:Add(name, guid)
        GOMove.LastSpawnedGUID = guid
    end
end

-- Filled in after MainFrame is created.
local UpdateMainHeader
local UpdateSelectedInfoPanel
local focusSelectionRow




-- MAIN FRAME
local MainFrame = GOMove:CreateFrame("GOMove_UI", 220, 495)
GOMove.MainFrame = MainFrame
MainFrame:Position("LEFT", UIParent, "LEFT", 0, 85)
loadFavsForMode(GOMove.Mode)

function GOMove:SetMode(mode, showUI)
    local newMode = (mode == "NPC") and "NPC" or "GO"
    if (self.Mode ~= newMode) then
        saveFavsForMode(self.Mode)
        self.Mode = newMode
        self.ActiveModule = (newMode == "NPC") and "NPCM" or "GOMV"
        self.ActiveChannel = (newMode == "NPC") and "NPCMOVE" or "GOMOVE"
        loadFavsForMode(newMode)
        clearAllSelected()
        clearSelectionList()
        self.LastSpawnedGUID = nil
    end

    if SelInfoTitle then
        SelInfoTitle:SetText((self.Mode == "NPC") and "Selected NPC" or "Selected GameObject")
    end
    if UpdateMainHeader then
        UpdateMainHeader()
    end
    if UpdateSelectedInfoPanel then
        UpdateSelectedInfoPanel()
    end
    if FavFrame and FavFrame.Update then
        FavFrame:Update()
    end
    if SelFrame and SelFrame.Update then
        SelFrame:Update()
    end

    if showUI and self.MainFrame and not self.MainFrame:IsVisible() then
        self.MainFrame:Show()
        if FavFrame then FavFrame:Show() end
        if SelFrame then SelFrame:Show() end
    end
end
MainFrame:Hide()  -- Hide at startup; open only via /gomove command

-- Small info panel attached to the main UI to show the currently focused selection.
local SelectedInfoPanel = CreateFrame("Frame", "GOMove_UI_SelectedInfo", MainFrame)
SelectedInfoPanel:SetSize(250, 70)
SelectedInfoPanel:SetPoint("TOPLEFT", MainFrame, "TOPRIGHT", 6, -8)
SelectedInfoPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32,
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})

do
    local bg = SelectedInfoPanel:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\DC-GM\\Textures\\Backgrounds\\FelLeather_512.tga")
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = SelectedInfoPanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, 0.60)

    SelectedInfoPanel:SetBackdropColor(0, 0, 0, 0)
    SelectedInfoPanel.__dcBg = bg
    SelectedInfoPanel.__dcTint = tint
end
SelectedInfoPanel:Hide()

local SelInfoTitle = SelectedInfoPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
SelInfoTitle:SetPoint("TOPLEFT", SelectedInfoPanel, "TOPLEFT", 8, -6)
SelInfoTitle:SetText((GOMove.Mode == "NPC") and "Selected NPC" or "Selected GameObject")

local SelInfoGuid = SelectedInfoPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
SelInfoGuid:SetPoint("TOPLEFT", SelInfoTitle, "BOTTOMLEFT", 0, -4)
SelInfoGuid:SetText("Spawn GUID: -")

local SelInfoEntry = SelectedInfoPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
SelInfoEntry:SetPoint("TOPLEFT", SelInfoGuid, "BOTTOMLEFT", 0, -2)
SelInfoEntry:SetText("Entry: -")

local SelInfoName = SelectedInfoPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
SelInfoName:SetPoint("TOPLEFT", SelInfoEntry, "BOTTOMLEFT", 0, -2)
SelInfoName:SetText("Name: -")

-- Clicking outside the GOMove UI should release EditBox focus, so movement keys work.
if (WorldFrame and not GOMove._worldClickHooked) then
    GOMove._worldClickHooked = true
    WorldFrame:HookScript("OnMouseDown", function()
        if (GOMove.MainFrame and GOMove.MainFrame:IsVisible()) then
            for _, inputfield in ipairs(GOMove.Inputs) do
                inputfield:ClearFocus()
            end
        end
    end)
end

-- Finalize radius selection after the server stops sending ADD messages.
local RadiusFinalizeFrame = CreateFrame("Frame")
RadiusFinalizeFrame:Hide()
RadiusFinalizeFrame:SetScript("OnUpdate", function(self)
    if (not GOMove._radiusFinalizeAt) then
        self:Hide()
        return
    end
    if (GetTime() >= GOMove._radiusFinalizeAt) then
        self:Hide()
        GOMove._radiusFinalizeAt = nil
        GOMove._radiusSelecting = false

        local count = #GOMove.SelL
        if (count <= 0) then
            return
        end

        -- Sort by distance if coordinates are available
        local px, py, pz
        px, py, pz = GOMove._radiusOriginX, GOMove._radiusOriginY, GOMove._radiusOriginZ
        if (not (px and py and pz) and type(UnitPosition) == "function") then
            px, py, pz = UnitPosition("player")
        end

        if (px and py and pz) then
            -- Cache distance (row[7]) and squared distance (row[8]) once per search.
            for _, row in ipairs(GOMove.SelL) do
                local rx, ry, rz = tonumber(row[4]), tonumber(row[5]), tonumber(row[6])
                if (rx and ry and rz) then
                    local dist2 = (rx - px)^2 + (ry - py)^2 + (rz - pz)^2
                    row[8] = dist2
                    row[7] = math.sqrt(dist2)
                else
                    row[8] = nil
                    row[7] = nil
                end
            end

            table.sort(GOMove.SelL, function(a, b)
                local da = a[8]
                local db = b[8]
                if (da and db) then
                    return da < db
                end
                if (da and not db) then
                    return true
                end
                return false
            end)
        end

        -- Always open the selection window when radius results are available.
        SelFrame:Show()

        if (count == 1) then
            focusSelectionRow(GOMove.SelL[1])
            SelFrame:Update()
            if (UpdateSelectedInfoPanel) then
                UpdateSelectedInfoPanel()
            end
            return
        end

        clearAllSelected()
        GOMove._pickOneMode = true
        SelFrame:Update()
        if (UpdateSelectedInfoPanel) then
            UpdateSelectedInfoPanel()
        end
    end
end)

local function scheduleRadiusFinalize()
    GOMove._radiusFinalizeAt = GetTime() + 0.25
    RadiusFinalizeFrame:Show()
end

local NEWS = GOMove:CreateInput(MainFrame, "NEWS", 40, 25, 0, -50, 4, 30)

local NORTH = GOMove:CreateButton(MainFrame, "N", 50, 25, 0, -25)
function NORTH:OnClick()
    GOMove:Move("NORTH", NEWS:GetNumber())
end
local EAST = GOMove:CreateButton(MainFrame, "E", 50, 25, 50, -50)
function EAST:OnClick()
    GOMove:Move("EAST", NEWS:GetNumber())
end
local SOUTH = GOMove:CreateButton(MainFrame, "S", 50, 25, 0, -75)
function SOUTH:OnClick()
    GOMove:Move("SOUTH", NEWS:GetNumber())
end
local WEST = GOMove:CreateButton(MainFrame, "W", 50, 25, -50, -50)
function WEST:OnClick()
    GOMove:Move("WEST", NEWS:GetNumber())
end

local NORTHEAST = GOMove:CreateButton(MainFrame, "NE", 40, 20, 45, -30)
function NORTHEAST:OnClick()
    GOMove:Move("NORTHEAST", NEWS:GetNumber())
end
local NORTHWEST = GOMove:CreateButton(MainFrame, "NW", 40, 20, -45, -30)
function NORTHWEST:OnClick()
    GOMove:Move("NORTHWEST", NEWS:GetNumber())
end
local SOUTHEAST = GOMove:CreateButton(MainFrame, "SE", 40, 20, 45, -75)
function SOUTHEAST:OnClick()
    GOMove:Move("SOUTHEAST", NEWS:GetNumber())
end
local SOUTHWEST = GOMove:CreateButton(MainFrame, "SW", 40, 20, -45, -75)
function SOUTHWEST:OnClick()
    GOMove:Move("SOUTHWEST", NEWS:GetNumber())
end

local X = GOMove:CreateButton(MainFrame, "X", 35, 20, -60, -105)
function X:OnClick()
    GOMove:Move("X")
end
local Y = GOMove:CreateButton(MainFrame, "Y", 35, 20, -20, -105)
function Y:OnClick()
    GOMove:Move("Y")
end
local Z = GOMove:CreateButton(MainFrame, "Z", 35, 20, 20, -105)
function Z:OnClick()
    GOMove:Move("Z")
end
local O = GOMove:CreateButton(MainFrame, "O", 35, 20, 60, -105)
function O:OnClick()
    GOMove:Move("O")
end

local ROTHEI = GOMove:CreateInput(MainFrame, "ROTHEI", 40, 25, 0, -155, 4, 30)
local UP = GOMove:CreateButton(MainFrame, "Up", 40, 25, 0, -130)
function UP:OnClick()
    GOMove:Move("UP", ROTHEI:GetNumber())
end
local DOWN = GOMove:CreateButton(MainFrame, "Down", 40, 25, 0, -180)
function DOWN:OnClick()
    GOMove:Move("DOWN", ROTHEI:GetNumber())
end
local RIGHT = GOMove:CreateButton(MainFrame, "Right", 40, 25, 45, -155)
function RIGHT:OnClick()
    GOMove:Move("RIGHT", ROTHEI:GetNumber())
end
local LEFT = GOMove:CreateButton(MainFrame, "Left", 40, 25, -45, -155)
function LEFT:OnClick()
    GOMove:Move("LEFT", ROTHEI:GetNumber())
end

local RESPAWN = GOMove:CreateButton(MainFrame, "Respawn", 65, 25, -35, -237.5)
function RESPAWN:OnClick()
    GOMove:Move("RESPAWN")
end
local FLOOR = GOMove:CreateButton(MainFrame, "Floor", 65, 25, 35, -237.5)
function FLOOR:OnClick()
    GOMove:Move("FLOOR")
end
local SELECTNEAR = GOMove:CreateButton(MainFrame, "Target", 50, 25, 55, -210)
function SELECTNEAR:OnClick()
    GOMove:Move("SELECTNEAR")
end
local FACE = GOMove:CreateButton(MainFrame, "Snap", 50, 25, 0, -210)
function FACE:OnClick()
    GOMove:Move("FACE")
end
local DELETE = GOMove:CreateButton(MainFrame, "Delete", 50, 25, -55, -210)
function DELETE:OnClick()
    GOMove:Move("DELETE")
end

local GROUND = GOMove:CreateButton(MainFrame, "Ground", 70, 25, -40, -265)
function GROUND:OnClick()
    GOMove:Move("GROUND")
end
local GOTO = GOMove:CreateButton(MainFrame, "Go to", 70, 25, 40, -265)
function GOTO:OnClick()
    GOMove:Move("GOTO")
end

local ENTRY = GOMove:CreateInput(MainFrame, "ENTRY", 65, 25, -30, -295, 10)
local SPAWN = GOMove:CreateButton(MainFrame, "Spawn", 50, 25, 40, -295)
function SPAWN:OnClick()
    GOMove:Move("SPAWN", ENTRY:GetNumber())
end

-- Label showing current focused ENTRY value
local ENTRY_LABEL = MainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ENTRY_LABEL:SetPoint("TOPLEFT", ENTRY, "BOTTOMLEFT", 0, -6)
ENTRY_LABEL:SetTextColor(0.9, 0.9, 0.9)
local function UpdateEntryLabel()
    local val = ENTRY:GetNumber() or 0
    if val == 0 then
        ENTRY_LABEL:SetText("Focused ENTRY: (none)")
    else
        ENTRY_LABEL:SetText("Focused ENTRY: " .. tostring(val))
    end
end
-- Update when user changes ENTRY or when we set it programmatically
ENTRY:SetScript("OnTextChanged", function() UpdateEntryLabel() end)
UpdateEntryLabel()

local function findSelRowByGuid(guid)
    if (not guid) then return nil end
    for _, row in ipairs(GOMove.SelL) do
        if (tostring(row[2]) == tostring(guid)) then
            return row
        end
    end
    return nil
end

UpdateMainHeader = function()
    if (not MainFrame or not MainFrame.NameFrame or not MainFrame.NameFrame.text) then
        return
    end

    local selectedGuid, selectedName
    local selectedCount = 0
    for guid, name in pairs(GOMove.Selected) do
        if (tonumber(guid)) then
            selectedCount = selectedCount + 1
            if (selectedCount == 1) then
                selectedGuid = guid
                selectedName = name
            end
        end
    end

    local base = (GOMove.Mode == "NPC") and "NPCMove UI" or "GOMove UI"
    if (selectedCount == 0) then
        MainFrame.NameFrame.text:SetText(base)
        return
    end
    if (selectedCount > 1) then
        MainFrame.NameFrame.text:SetText(base .. " (" .. tostring(selectedCount) .. " selected)")
        return
    end

    MainFrame.NameFrame.text:SetText(base)
end

UpdateSelectedInfoPanel = function()
    if (not SelectedInfoPanel) then
        return
    end
    if (not MainFrame:IsVisible()) then
        SelectedInfoPanel:Hide()
        return
    end

    local selectedGuid, selectedName
    local selectedCount = 0
    for guid, name in pairs(GOMove.Selected) do
        if (tonumber(guid)) then
            selectedCount = selectedCount + 1
            if (selectedCount == 1) then
                selectedGuid = guid
                selectedName = name
            end
        end
    end

    SelectedInfoPanel:Show()
    if (selectedCount == 0) then
        SelInfoGuid:SetText("Spawn GUID: -")
        SelInfoEntry:SetText("Entry: -")
        SelInfoName:SetText("Name: -")
        return
    end
    if (selectedCount > 1) then
        SelInfoGuid:SetText("Spawn GUID: (multiple)")
        SelInfoEntry:SetText("Entry: (multiple)")
        SelInfoName:SetText("Name: (" .. tostring(selectedCount) .. " selected)")
        return
    end

    local row = findSelRowByGuid(selectedGuid)
    local entry = row and row[3] or "?"
    local name = selectedName or (row and row[1]) or "(unknown)"
    SelInfoGuid:SetText("Spawn GUID: " .. tostring(selectedGuid))
    SelInfoEntry:SetText("Entry: " .. tostring(entry))
    SelInfoName:SetText("Name: " .. tostring(name))
end

focusSelectionRow = function(row)
    if (not row) then return end

    -- Set current spawn GUID as the only selected object for modifications.
    selectOnly(row[1], row[2])

    -- Fill the ENTRY box for quick spawn/usage.
    local entryInput = _G["GOMove_UI_ENTRY"]
    if (entryInput and entryInput.SetNumber) then
        entryInput:SetNumber(tonumber(row[3]) or 0)
        UpdateEntryLabel()
    end

    if (UpdateMainHeader) then
        UpdateMainHeader()
    end
    if (UpdateSelectedInfoPanel) then
        UpdateSelectedInfoPanel()
    end
    MainFrame:Show()
end

local RADIUS = GOMove:CreateInput(MainFrame, "RADIUS", 40, 25, -55, -325, 4, 20)
local SELECTALLNEAR = GOMove:CreateButton(MainFrame, "Select by radius", 110, 25, 25, -325)
function SELECTALLNEAR:OnClick()
    -- Populate selection list, then force choosing a single object if multiple are found.
    clearAllSelected()
    clearSelectionList()
    GOMove._radiusSelecting = true

    -- Snapshot player position at click time, so distances are computed once per search.
    if (type(UnitPosition) == "function") then
        GOMove._radiusOriginX, GOMove._radiusOriginY, GOMove._radiusOriginZ = UnitPosition("player")
    else
        GOMove._radiusOriginX, GOMove._radiusOriginY, GOMove._radiusOriginZ = nil, nil, nil
    end

    GOMove:Move("SELECTALLNEAR", RADIUS:GetNumber())
end

local MASK = GOMove:CreateInput(MainFrame, "MASK", 65, 25, -30, -355, 10)
local PHASE = GOMove:CreateButton(MainFrame, "Phase", 50, 25, 40, -355)
function PHASE:OnClick()
    GOMove:Move("PHASE", MASK:GetNumber())
end

local FAVOURITES = GOMove:CreateButton(MainFrame, "Favourites", 80, 25, -40, -385)
function FAVOURITES:OnClick()
    if(FavFrame:IsVisible()) then
        FavFrame:Hide()
    else
        FavFrame:Show()
    end
end
local SELECTIONS = GOMove:CreateButton(MainFrame, "Selections", 80, 25, 40, -385)
function SELECTIONS:OnClick()
    if(SelFrame:IsVisible()) then
        SelFrame:Hide()
    else
        SelFrame:Show()
    end
end

local SPELLENTRY = GOMove:CreateInput(MainFrame, "SPELLENTRY", 65, 25, -30, -415, 10)
local SPELLSPAWN = GOMove:CreateButton(MainFrame, "Send", 50, 25, 40, -415)
function SPELLSPAWN:OnClick()
    GOMove:Move("SPAWNSPELL", SPELLENTRY:GetNumber())
end

local RESETVALUES = GOMove:CreateButton(MainFrame, "Reset", 110, 25, 0, -440)
function RESETVALUES:OnClick()
    GOMove:ResetInputDefaults()
end

GOMove.SCMD = {}
function GOMove.SCMD.help()
    for k, v in pairs(GOMove.SCMD) do
        print(k)
    end
end
function GOMove.SCMD.reset()
    for k, inputfield in ipairs(GOMove.Inputs) do
        inputfield:ClearFocus()
    end
    print("Frames reset")
    for k, Frame in pairs(GOMove.Frames) do
        if(Frame.Default) then
            Frame:ClearAllPoints()
            Frame:SetPoint(Frame.Default[1], Frame.Default[2], Frame.Default[3], Frame.Default[4], Frame.Default[5])
        end
        Frame:Show()
    end
    -- Also reset input fields to their defaults (empty for MASK and SPELLENTRY)
    if GOMove.ResetInputDefaults then
        GOMove:ResetInputDefaults()
        print("Inputs reset")
    end
end
function GOMove.SCMD.invertselection()
    local sel = {}
    for GUID, NAME in pairs(GOMove.Selected) do
        if(tonumber(GUID)) then
            table.insert(sel, GUID)
        end
    end
    for k, tbl in ipairs(SelFrame.DataTable) do
        GOMove.Selected:Add(tbl[1], tbl[2])
    end
    for k,v in ipairs(sel) do
        GOMove.Selected:Del(v)
    end
    SelFrame:Update()
end

-- FAVOURITE LIST
FavFrame = GOMove:CreateFrame("Favourite_List", 200, 280, GOMove.FavL, true)
FavFrame:Position("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
FavFrame:Hide()  -- Hide at startup
FavFrame:Hide()  -- Hide at startup
function FavFrame:ButtonOnClick(ID)
    local entry = self.DataTable[FauxScrollFrame_GetOffset(self.ScrollBar) + ID][2]
    if IsShiftKeyDown() then
        GOMove:Move("SPAWN", entry)
    else
        local entryInput = _G["GOMove_UI_ENTRY"]
        if (entryInput and entryInput.SetNumber) then
            entryInput:SetNumber(tonumber(entry) or 0)
            UpdateEntryLabel()
            MainFrame:Show()
            entryInput:SetFocus()
        end
    end
end
function FavFrame:MiscOnClick(ID)
    self.DataTable:Del(self.DataTable[FauxScrollFrame_GetOffset(self.ScrollBar) + ID][2])
    self:Update()
end

function FavFrame:ButtonTooltip(ID, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Spawn favourite", 1, 1, 1)
    GameTooltip:AddLine("Spawns the saved gameobject entry.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

function FavFrame:MiscTooltip(ID, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Remove from favourites", 1, 1, 1)
    GameTooltip:AddLine("Deletes this entry from your favourites list.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

-- SELECTION LIST
SelFrame = GOMove:CreateFrame("Selection_List", 360, 320, GOMove.SelL, true, 36)
SelFrame:Position("BOTTOMRIGHT", FavFrame, "TOPRIGHT", 0, 0)
SelFrame:Hide()  -- Hide at startup
SelFrame:Hide()  -- Hide at startup
function SelFrame:ButtonOnClick(ID)
    local DATAID = FauxScrollFrame_GetOffset(self.ScrollBar) + ID

    -- After select-by-radius we want the user to pick a single object.
    if (GOMove._pickOneMode) then
        local row = self.DataTable[DATAID]
        if (row) then
            focusSelectionRow(row)
            GOMove._pickOneMode = false
        end
    else
        local row = self.DataTable[DATAID]
        if (not row) then
            return
        end

        -- Default: focus the clicked object for modification (single-select + fill ENTRY).
        -- Shift-click preserves legacy multi-select toggle behavior.
        if (IsShiftKeyDown()) then
            if (GOMove.Selected[row[2]]) then
                GOMove.Selected:Del(row[2])
            else
                GOMove.Selected:Add(row[1], row[2])
            end
            if (UpdateMainHeader) then
                UpdateMainHeader()
            end
        else
            focusSelectionRow(row)
        end
    end
    self:Update()
    if (UpdateSelectedInfoPanel) then
        UpdateSelectedInfoPanel()
    end
end
function SelFrame:MiscOnClick(ID)
    local DATAID = FauxScrollFrame_GetOffset(self.ScrollBar) + ID
    GOMove.Selected:Del(self.DataTable[DATAID][2])
    self.DataTable:Del(self.DataTable[DATAID][2])
    if (UpdateMainHeader) then
        UpdateMainHeader()
    end
    if (UpdateSelectedInfoPanel) then
        UpdateSelectedInfoPanel()
    end
    self:Update()
end
function SelFrame:UpdateScript(ID)
    local DATAID = FauxScrollFrame_GetOffset(self.ScrollBar) + ID
    if(self.DataTable[DATAID]) then
        if(GOMove.Selected[self.DataTable[DATAID][2]]) then
            self.Buttons[ID]:GetFontString():SetTextColor(1, 0.8, 0)
        else
            self.Buttons[ID]:GetFontString():SetTextColor(1, 1, 1)
        end
    end
end

function SelFrame:ButtonTooltip(ID, owner)
    local DATAID = FauxScrollFrame_GetOffset(self.ScrollBar) + ID
    if (not self.DataTable[DATAID]) then return end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if (GOMove._pickOneMode) then
        GameTooltip:AddLine("Choose this object", 1, 1, 1)
        GameTooltip:AddLine("Selects only this object and exits pick mode.", 0.8, 0.8, 0.8, true)
    else
        if (GOMove.Selected[self.DataTable[DATAID][2]]) then
            GameTooltip:AddLine("Deselect", 1, 1, 1)
            GameTooltip:AddLine("Removes this object from your selection.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Select", 1, 1, 1)
            GameTooltip:AddLine("Adds this object to your selection.", 0.8, 0.8, 0.8, true)
        end
    end
    -- Show spawn ID and GO template entry for convenience
    local guid = tostring(self.DataTable[DATAID][2] or "")
    local entry = tostring(self.DataTable[DATAID][3] or "")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Spawn ID: "..guid, 0.9, 0.9, 0.9)
    if (entry ~= "") then
        GameTooltip:AddLine("Entry: "..entry, 0.9, 0.9, 0.9)
    end
    GameTooltip:Show()
end

function SelFrame:MiscTooltip(ID, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Remove from list", 1, 1, 1)
    GameTooltip:AddLine("Removes this object from the selection list.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end
local ClearButton = CreateFrame("Button", SelFrame:GetName().."_ToggleSelect", SelFrame)
ClearButton:SetSize(16, 16)
ClearButton:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Disabled")
ClearButton:SetPushedTexture("Interface\\Buttons\\UI-GuildButton-OfficerNote-Up")
ClearButton:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
ClearButton:SetPoint("TOPRIGHT", SelFrame, "TOPRIGHT", -30, -5)
ClearButton:SetScript("OnClick", function()
    local empty = true
    for k,v in pairs(GOMove.Selected) do
        if(tonumber(k)) then
            empty = false
        end
    end
    if(empty) then
        for k, tbl in ipairs(SelFrame.DataTable) do
            GOMove.Selected:Add(tbl[1], tbl[2])
        end
    else
        for k,v in pairs(GOMove.Selected) do
            if(tonumber(k)) then
                GOMove.Selected:Del(k)
            end
        end
    end
    SelFrame:Update()
end)
ClearButton:SetScript("OnEnter", function(self)
    local empty = true
    for k, _ in pairs(GOMove.Selected) do
        if (tonumber(k)) then
            empty = false
            break
        end
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if (empty) then
        GameTooltip:AddLine("Select all", 1, 1, 1)
        GameTooltip:AddLine("Selects all objects currently in the list.", 0.8, 0.8, 0.8, true)
    else
        GameTooltip:AddLine("Clear selection", 1, 1, 1)
        GameTooltip:AddLine("Unselects all currently selected objects.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:Show()
end)
ClearButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
for i = 1, SelFrame.ButtonCount do
    local rowIndex = i
    local Button = SelFrame.Buttons[rowIndex]
    local MiscButton = Button.MiscButton
    local FavButton = CreateFrame("Button", Button:GetName().."_Favourite", MiscButton)
    FavButton:SetSize(16, 16)
    FavButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    FavButton:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
    FavButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilighted")
    FavButton:SetPoint("TOPRIGHT", MiscButton, "TOPLEFT", 0, 0)
    FavButton:SetScript("OnClick", function()
        local DATAID = FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + rowIndex
        local row = SelFrame.DataTable[DATAID]
        if (not row) then return end
        FavFrame.DataTable:Add(row[1], row[3])
        FavFrame:Update()
        FavFrame:Show()
        -- Also set ENTRY to this object's entry and open main spawn UI
        local entryInput = _G["GOMove_UI_ENTRY"]
        if (entryInput and entryInput.SetNumber) then
            entryInput:SetNumber(tonumber(row[3]) or 0)
            UpdateEntryLabel()
            MainFrame:Show()
            entryInput:SetFocus()
        end
    end)
    FavButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Add to favourites", 1, 1, 1)
        GameTooltip:AddLine("Saves this object so you can quickly spawn it again.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    FavButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local DeleteButton = CreateFrame("Button", Button:GetName().."_Delete", FavButton)
    DeleteButton:SetSize(16, 16)
    DeleteButton:SetNormalTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon5")
    DeleteButton:SetPushedTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon7")
    DeleteButton:SetHighlightTexture("Interface\\PaperDollInfoFrame\\SpellSchoolIcon3")
    DeleteButton:SetPoint("TOPRIGHT", FavButton, "TOPLEFT", 0, 0)
    DeleteButton:SetScript("OnClick", function()
        local DATAID = FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + rowIndex
        local row = SelFrame.DataTable[DATAID]
        if (not row) then return end
        -- Delete this specific object (do not depend on current selection).
        GOMove:MoveOnGuid("DELETE", row[2], 0)
    end)
    DeleteButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Delete object", 1, 1, 1)
        GameTooltip:AddLine("Deletes this gameobject from the world.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    DeleteButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local SpawnButton = CreateFrame("Button", Button:GetName().."_Spawn", DeleteButton)
    SpawnButton:SetSize(16, 16)
    SpawnButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    SpawnButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    SpawnButton:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    SpawnButton:SetPoint("TOPRIGHT", DeleteButton, "TOPLEFT", 0, 0)
    SpawnButton:SetScript("OnClick", function()
        local DATAID = FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + rowIndex
        local row = SelFrame.DataTable[DATAID]
        if (not row) then return end
        -- Respawn this specific object (do not depend on current selection).
        GOMove:MoveOnGuid("RESPAWN", row[2], 0)
    end)
    SpawnButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Respawn object", 1, 1, 1)
        GameTooltip:AddLine("Respawns this gameobject (useful if it was deleted/hidden).", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    SpawnButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local UseEntryButton = CreateFrame("Button", Button:GetName().."_Use", SpawnButton)
    UseEntryButton:SetSize(16, 16)
    UseEntryButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    UseEntryButton:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
    UseEntryButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilighted")
    UseEntryButton:SetPoint("TOPRIGHT", SpawnButton, "TOPLEFT", 0, 0)
    UseEntryButton:SetScript("OnClick", function()
        local DATAID = FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + rowIndex
        local row = SelFrame.DataTable[DATAID]
        if (not row) then return end
        -- Set the ENTRY input to this object's entry so it can be spawned repeatedly.
        if IsShiftKeyDown() then
            -- shift-click spawn immediately
            GOMove:Move("SPAWN", row[3])
            return
        end
        local entryInput = _G["GOMove_UI_ENTRY"]
        if (entryInput and entryInput.SetNumber) then
            entryInput:SetNumber(tonumber(row[3]) or 0)
            UpdateEntryLabel()
            MainFrame:Show()
            entryInput:SetFocus()
            DEFAULT_CHAT_FRAME:AddMessage("GOMove: ENTRY set to " .. tostring(row[3]))
        end
    end)
    UseEntryButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Use entry", 1, 1, 1)
        GameTooltip:AddLine("Sets the ENTRY value to this object's entry so you can spawn it repeatedly.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    UseEntryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local FocusButton = CreateFrame("Button", Button:GetName().."_Focus", UseEntryButton)
    FocusButton:SetSize(16, 16)
    FocusButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    FocusButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    FocusButton:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    FocusButton:SetPoint("TOPRIGHT", UseEntryButton, "TOPLEFT", 0, 0)
    FocusButton:SetScript("OnClick", function()
        local DATAID = FauxScrollFrame_GetOffset(SelFrame.ScrollBar) + rowIndex
        local row = SelFrame.DataTable[DATAID]
        if (not row) then return end
        focusSelectionRow(row)
        SelFrame:Update()
    end)
    FocusButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Select for modify", 1, 1, 1)
        GameTooltip:AddLine("Selects only this spawn GUID and fills ENTRY in the GOMove UI.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    FocusButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local EmptyButton = CreateFrame("Button", SelFrame:GetName().."_EmptyButton", SelFrame)
EmptyButton:SetSize(30, 30)
EmptyButton:SetNormalTexture("Interface\\Buttons\\CancelButton-Up")
EmptyButton:SetPushedTexture("Interface\\Buttons\\CancelButton-Down")
EmptyButton:SetHighlightTexture("Interface\\Buttons\\CancelButton-Highlight")
EmptyButton:SetPoint("TOPRIGHT", SelFrame, "TOPRIGHT", -45, 0)
EmptyButton:SetHitRectInsets(9, 7, 7, 10)
EmptyButton:SetScript("OnClick", function()
    for k,v in pairs(GOMove.Selected) do
        if(tonumber(k)) then
            GOMove.Selected:Del(k)
        end
    end
    for i = #SelFrame.DataTable, 1, -1 do
        SelFrame.DataTable:Del(SelFrame.DataTable[i][2])
    end
    if (UpdateMainHeader) then
        UpdateMainHeader()
    end
    if (UpdateSelectedInfoPanel) then
        UpdateSelectedInfoPanel()
    end
    SelFrame:Update()
end)
EmptyButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Clear list", 1, 1, 1)
    GameTooltip:AddLine("Removes all entries from the selection list and clears selection.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
EmptyButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

SLASH_GOMOVE1 = '/gomove'
function SlashCmdList.GOMOVE(msg, editBox)
    GOMove:SetMode("GO")
    if(msg ~= '') then
        for k, v in pairs(GOMove.SCMD) do
            if(type(k) == "string" and string.find(k, msg:lower()) == 1 and type(v) == "function") then
                v()
                break;
            end
        end
        return
    end
    if(MainFrame:IsVisible()) then
        MainFrame:Hide()
        FavFrame:Hide()
        SelFrame:Hide()
        if (UpdateSelectedInfoPanel) then
            UpdateSelectedInfoPanel()
        end
    else
        MainFrame:Show()
        FavFrame:Show()
        SelFrame:Show()

        if (UpdateMainHeader) then
            UpdateMainHeader()
        end
        if (UpdateSelectedInfoPanel) then
            UpdateSelectedInfoPanel()
        end

        -- Make sure no input box steals movement keys when opening.
        for _, inputfield in ipairs(GOMove.Inputs) do
            inputfield:ClearFocus()
        end
    end
end

SLASH_NPCMOVE1 = '/npcmove'
function SlashCmdList.NPCMOVE(msg, editBox)
    GOMove:SetMode("NPC")
    if(msg ~= '') then
        for k, v in pairs(GOMove.SCMD) do
            if(type(k) == "string" and string.find(k, msg:lower()) == 1 and type(v) == "function") then
                v()
                break;
            end
        end
        return
    end
    if(MainFrame:IsVisible()) then
        MainFrame:Hide()
        FavFrame:Hide()
        SelFrame:Hide()
        if (UpdateSelectedInfoPanel) then
            UpdateSelectedInfoPanel()
        end
    else
        MainFrame:Show()
        FavFrame:Show()
        SelFrame:Show()

        if (UpdateMainHeader) then
            UpdateMainHeader()
        end
        if (UpdateSelectedInfoPanel) then
            UpdateSelectedInfoPanel()
        end

        -- Make sure no input box steals movement keys when opening.
        for _, inputfield in ipairs(GOMove.Inputs) do
            inputfield:ClearFocus()
        end
    end
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("CHAT_MSG_ADDON")

EventFrame:SetScript("OnEvent",
    function(self, event, MSG, MSG2, Type, Sender)
        if(event == "CHAT_MSG_ADDON") then
            -- Compatibility: handle DC protocol error responses for GOMove
            if MSG == "DC" then
                -- Format: MODULE|OPCODE|... - module for GOMove is GOMV
                local parts = {}
                for p in string.gmatch(MSG2, "([^|]+)") do table.insert(parts, p) end
                if #parts >= 2 then
                    local module = parts[1]
                    local opcode = tonumber(parts[2]) or 0
                    -- Error opcodes: Core.SMSG_PERMISSION_DENIED (0x1E) or SMSG_ERROR (0x1F)
                    if (module == "GOMV" or module == "NPCM") and (opcode == 0x1E or opcode == 0x1F) then
                        local errCode = tonumber(parts[3]) or 0
                        local errMsg = parts[4] or "Unknown error"
                        local label = (module == "NPCM") and "NPCMove" or "GOMove"
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[" .. label .. "] Error:|r " .. errMsg)
                        return
                    end
                end
            end
            -- Legacy behaviour: original GOMove channel uses prefix "GOMOVE"
            if Sender ~= UnitName("player") then return end
            local activePrefix = GOMove.ActiveChannel or "GOMOVE"
            if MSG ~= activePrefix then return end
            local ID, ENTRYORGUID, ARG2, ARG3, ARG4, ARG5, ARG6 = strsplit("|", MSG2)
            if(ID) then
                --if(ID == "USED") then
                --    for k,v in ipairs(GOMove.UseL) do
                --        if(ENTRYORGUID == v[2]) then
                --            return
                --        end
                --    end
                --    GOMove.UseL:Add(ARG2, ENTRYORGUID)
                --    GOMove:Update()
                if(ID == "REMOVE") then
                    local guid = ENTRYORGUID
                    GOMove.Selected:Del(guid)
                    for k,tbl in ipairs(GOMove.SelL) do
                        if(tbl[2] == guid) then
                            GOMove.SelL:Del(guid)
                            break
                        end
                    end
                    GOMove:Update()
                    if (UpdateMainHeader) then
                        UpdateMainHeader()
                    end
                    if (UpdateSelectedInfoPanel) then
                        UpdateSelectedInfoPanel()
                    end
                elseif(ID == "ADD") then
                    local guid = ENTRYORGUID

                    -- While selecting-by-radius, gather results but don't auto-select all.
                    if (GOMove._radiusSelecting) then
                        local exists = false
                        for _, tbl in ipairs(GOMove.SelL) do
                            if (tbl[2] == guid) then
                                exists = true
                                break
                            end
                        end
                        if (not exists) then
                            GOMove.SelL:Add(ARG2, guid, ARG3, ARG4, ARG5, ARG6)
                        end
                        scheduleRadiusFinalize()
                        GOMove:Update()
                        if (UpdateMainHeader) then
                            UpdateMainHeader()
                        end
                        if (UpdateSelectedInfoPanel) then
                            UpdateSelectedInfoPanel()
                        end
                        return
                    end

                    -- If SPAWN just happened, make this the only selected object.
                    if (GOMove._expectSpawnAdd) then
                        GOMove._expectSpawnAdd = false
                        selectOnly(ARG2, guid)
                    else
                        GOMove.Selected:Add(ARG2, guid)
                    end
                    local exists = false
                    for k, tbl in ipairs(GOMove.SelL) do
                        if(tbl[2] == guid) then
                            exists = true
                            break
                        end
                    end
                    if(not exists) then
                        GOMove.SelL:Add(ARG2, guid, ARG3, ARG4, ARG5, ARG6)
                    end
                    GOMove:Update()
                    if (UpdateMainHeader) then
                        UpdateMainHeader()
                    end
                    if (UpdateSelectedInfoPanel) then
                        UpdateSelectedInfoPanel()
                    end
                elseif(ID == "SWAP") then
                    local oldGUID, newGUID = ENTRYORGUID, ARG3
                    GOMove.Selected:Add(GOMove.Selected[oldGUID], newGUID)
                    GOMove.Selected:Del(oldGUID)
                    for k,tbl in ipairs(GOMove.SelL) do
                        if(tbl[2] == oldGUID) then
                            tbl[2] = newGUID
                            break
                        end
                    end

                    if (GOMove._expectSpawnAdd) then
                        GOMove._expectSpawnAdd = false
                        selectOnly(GOMove.Selected[newGUID], newGUID)
                    end

                    GOMove:Update()
                    if (UpdateMainHeader) then
                        UpdateMainHeader()
                    end
                    if (UpdateSelectedInfoPanel) then
                        UpdateSelectedInfoPanel()
                    end
                end
            end
        elseif(MSG == "GOMove" and event == "ADDON_LOADED") then
            if(not GOMoveSV or type(GOMoveSV) ~= "table") then
                GOMoveSV = {}
            end
            ensureGOMoveSV()
            loadFavsForMode(GOMove.Mode)
            GOMove:Update()
            -- Register DC protocol error handler if DC library is present
            if DCAddonProtocol ~= nil and type(DC) == "table" and DC.RegisterErrorHandler then
                DC:RegisterErrorHandler("GOMV", function(errCode, errMsg, opcode)
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[GOMove] Error:|r " .. (errMsg or "Unknown error"))
                end)
                DC:RegisterErrorHandler("NPCM", function(errCode, errMsg, opcode)
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[NPCMove] Error:|r " .. (errMsg or "Unknown error"))
                end)
            end
        end
    end
)
