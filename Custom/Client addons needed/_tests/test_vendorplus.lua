--[[
    What DC-QOS/Modules/VendorPlus.lua adds to the merchant window, on the strict 3.3.5a client.
    Both parts used to sit outside the vendor window:

    - The Sell Junk button hung 4 px above MerchantFrame's bottom edge, in the transparent strip
      under the frame art (the art ends near y 63). It now sits where retail puts
      MerchantSellAllJunkButton: an icon in the repair box, right of the repair buttons, or on its
      own when the vendor cannot repair.
    - The repair cost preview was a tooltip-style box hanging off the frame's right edge. It is now
      one or two text lines in the empty stone band under the title bar.

    The merchant frames are stand-ins laid out like the stock MerchantFrame.xml, and
    MerchantFrame_UpdateRepairButtons is copied verbatim from the 3.3.5a FrameXML, so the stock
    re-anchoring on every refresh is real.

    Coordinates are measured from MerchantFrame's BOTTOMLEFT (the frame is 384x512), from the
    client's own UI-Merchant-* textures at their stock anchors:
    - repair box inside MerchantFrameBottomLeftBorder: x 20..174, y 86..134 (the divider to the
      buyback box starts at x 175);
    - stone band under the title bar: x 74..340, y 441..477 (35..71 px below the top; the portrait
      ring is left of it and the item grid starts 80 px below the top).

    Run from this directory:  lua test_vendorplus.lua        (-v prints every check)
    DC_VENDORPLUS_FILE=<copy> tests another copy of the module.
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors

local BOX = { left = 20, right = 174, bottom = 86, top = 134 }
local BOX_CENTER_X = (BOX.left + BOX.right) / 2
local BAND = { left = 74, right = 340, bottom = 441, top = 477 }
local EPS = 0.01

-- ----------------------------------------------------------------------------
-- Vendor and bag state
-- ----------------------------------------------------------------------------

local vendor = { canRepair = true, guildRepair = false, repairCost = 1234 }

function CanMerchantRepair()
    return vendor.canRepair and 1 or nil
end

function CanGuildBankRepair()
    return vendor.guildRepair and 1 or nil
end

function GetRepairAllCost()
    return vendor.repairCost, vendor.canRepair and 1 or nil
end

-- bags[bag][slot] = { id, name, quality, count, price }
local bags = {}
local used = {}

local function link(item)
    return ("|cff9d9d9d|Hitem:%d:0:0:0:0:0:0:0|h[%s]|h|r"):format(item.id, item.name)
end

local function putItem(bag, slot, id, name, quality, count, price)
    bags[bag] = bags[bag] or {}
    bags[bag][slot] = { id = id, name = name, quality = quality, count = count or 1, price = price or 0 }
end

function GetContainerNumSlots(bag)
    return bags[bag] and 16 or 0
end

function GetContainerItemLink(bag, slot)
    local item = bags[bag] and bags[bag][slot]
    return item and link(item) or nil
end

function GetContainerItemInfo(bag, slot)
    local item = bags[bag] and bags[bag][slot]
    if not item then
        return nil
    end
    return "Interface\\Icons\\INV_Misc_Bone_01", item.count, nil, item.quality
end

function GetItemInfo(query)
    for _, slots in pairs(bags) do
        for _, item in pairs(slots) do
            if query == item.id or query == link(item) then
                return item.name, link(item), item.quality, 1, 1, "Junk", "Junk", 20, "", "", item.price
            end
        end
    end
    return nil
end

-- Selling at an open vendor removes the item; BAG_UPDATE follows.
function UseContainerItem(bag, slot)
    used[#used + 1] = bag .. ":" .. slot
    if bags[bag] then
        bags[bag][slot] = nil
    end
end

function GetCoinTextureString(copper)
    return tostring(copper) .. "c"
end

local money = 100000
function GetMoney()
    return money
end

function GetInventoryItemLink()
    return nil
end

function GetMerchantItemLink()
    return nil
end

function GetMerchantNumItems()
    return 0
end

function ContainerFrameItemButton_OnModifiedClick()
end

-- ----------------------------------------------------------------------------
-- The merchant frames, laid out as MerchantFrame.xml leaves them
-- ----------------------------------------------------------------------------

MerchantFrame = CreateFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame:SetWidth(384)
MerchantFrame:SetHeight(512)
MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
MerchantFrame:Hide()
MerchantFrame.selectedTab = 1

MerchantRepairText = MerchantFrame:CreateFontString("MerchantRepairText", "ARTWORK", "GameFontHighlightSmall")
MerchantRepairText:SetText(REPAIR_ITEMS or "Repair Items")
MerchantRepairText:SetPoint("BOTTOMLEFT", 26, 103)

local function NewButton(name, size)
    local button = CreateFrame("Button", name, MerchantFrame)
    button:SetWidth(size)
    button:SetHeight(size)
    return button
end

MerchantRepairAllButton = NewButton("MerchantRepairAllButton", 36)
MerchantRepairAllButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", 172, 91)
MerchantRepairItemButton = NewButton("MerchantRepairItemButton", 36)
MerchantRepairItemButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", -2, 0)
MerchantGuildBankRepairButton = NewButton("MerchantGuildBankRepairButton", 32)
MerchantGuildBankRepairButton:SetPoint("LEFT", MerchantRepairAllButton, "RIGHT", 4, 0)
MerchantGuildBankRepairButton:Hide()

-- 153x37, TOPLEFT on MerchantItem10's BOTTOMLEFT (0, -53): x 189, y 90..127.
MerchantBuyBackItem = CreateFrame("Frame", "MerchantBuyBackItem", MerchantFrame)
MerchantBuyBackItem:SetWidth(153)
MerchantBuyBackItem:SetHeight(37)
MerchantBuyBackItem:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 189, 90)

-- MerchantFrame.lua (3.3.5a), verbatim.
function MerchantFrame_UpdateRepairButtons()
	if ( CanMerchantRepair() ) then
		--See if can guildbank repair
		if ( CanGuildBankRepair() ) then
			MerchantRepairAllButton:SetWidth(32);
			MerchantRepairAllButton:SetHeight(32);
			MerchantRepairItemButton:SetWidth(32);
			MerchantRepairItemButton:SetHeight(32);
			MerchantRepairItemButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", -4, 0);

			MerchantRepairAllButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", 115, 89);
			MerchantRepairText:ClearAllPoints();
			MerchantRepairText:SetPoint("CENTER", MerchantFrame, "BOTTOMLEFT", 97, 129);
			MerchantGuildBankRepairButton:Show();
		else
			MerchantRepairAllButton:SetWidth(36);
			MerchantRepairAllButton:SetHeight(36);
			MerchantRepairItemButton:SetWidth(36);
			MerchantRepairItemButton:SetHeight(36);
			MerchantRepairItemButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", -2, 0);

			MerchantRepairAllButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", 172, 91);
			MerchantRepairText:ClearAllPoints();
			MerchantRepairText:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 26, 103);
			MerchantGuildBankRepairButton:Hide();
		end
		MerchantRepairText:Show();
		MerchantRepairAllButton:Show();
		MerchantRepairItemButton:Show();
	else
		MerchantRepairText:Hide();
		MerchantRepairAllButton:Hide();
		MerchantRepairItemButton:Hide();
		MerchantGuildBankRepairButton:Hide();
	end
end

-- The parts of MerchantFrame_UpdateMerchantInfo / _UpdateBuybackInfo that touch the bottom row.
function MerchantFrame_UpdateMerchantInfo()
    MerchantFrame_UpdateRepairButtons()
    MerchantBuyBackItem:Show()
end

function MerchantFrame_UpdateBuybackInfo()
    MerchantRepairAllButton:Hide()
    MerchantRepairItemButton:Hide()
    MerchantBuyBackItem:Hide()
    MerchantRepairText:Hide()
    MerchantGuildBankRepairButton:Hide()
end

function MerchantFrame_Update()
    if MerchantFrame.selectedTab == 1 then
        MerchantFrame_UpdateMerchantInfo()
    else
        MerchantFrame_UpdateBuybackInfo()
    end
end

-- ----------------------------------------------------------------------------
-- DC-QOS
-- ----------------------------------------------------------------------------

local notes = {}

DCQOS = {
    defaults = {},
    modules = {},
}

function DCQOS:RegisterModule(name, module)
    self.modules[name] = module
end

function DCQOS:DelayedCall(delay, func)
    SIM.Schedule(delay, func)
end

function DCQOS:Debug()
end

function DCQOS:Print(message)
    notes[#notes + 1] = message
end

function DCQOS:Notify(message)
    notes[#notes + 1] = message
end

function DCQOS:SaveSettings()
end

-- DC_VENDORPLUS_FILE points the test at another copy of the module.
SIM.LoadFile(os.getenv("DC_VENDORPLUS_FILE") or (SIM.ADDONS_DIR .. "DC-QOS/Modules/VendorPlus.lua"), "DC-QOS", {})
local VendorPlus = DCQOS.modules.VendorPlus

DCQOS.settings = {
    vendorPlus = {
        enabled = true,
        showSellPrice = true,
        showRepairCost = true,
        showTotalJunkValue = true,
        junkList = {},
        neverSellList = {},
    },
    automation = { enabled = true, autoSellJunk = false },
}

VendorPlus.OnInitialize()
VendorPlus.OnEnable()
noNewErrors("load and enable")

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

-- Rect relative to MerchantFrame's BOTTOMLEFT: left, bottom, right, top.
local function rel(region)
    local fl, fb = SIM.Rect(MerchantFrame)
    local l, b, r, t = SIM.Rect(region)
    if not (fl and l) then
        return nil
    end
    return { l - fl, b - fb, r - fl, t - fb }
end

local function within(rc, area)
    return rc ~= nil
        and rc[1] >= area.left - EPS and rc[3] <= area.right + EPS
        and rc[2] >= area.bottom - EPS and rc[4] <= area.top + EPS
end

local function inBox(rc)
    return within(rc, BOX)
end

local function overlaps(a, b)
    return a[1] < b[3] - EPS and b[1] < a[3] - EPS and a[2] < b[4] - EPS and b[2] < a[4] - EPS
end

local function near(a, b, eps)
    return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or EPS)
end

local function sameRect(a, b)
    if not (a and b) then
        return false
    end
    for i = 1, 4 do
        if not near(a[i], b[i]) then
            return false
        end
    end
    return true
end

local function junkButton()
    return _G.DCQoS_SellJunkButton
end

-- MERCHANT_SHOW: the stock handler shows and fills the page first, then the module's handler runs.
local function openVendor(canRepair, guildRepair)
    vendor.canRepair, vendor.guildRepair = canRepair, guildRepair
    MerchantFrame.selectedTab = 1
    MerchantFrame:Show()
    MerchantFrame_Update()
    SIM.FireEvent("MERCHANT_SHOW")
    SIM.Run(0.5)
end

local function closeVendor()
    SIM.FireEvent("MERCHANT_CLOSED")
    MerchantFrame:Hide()
end

local function shownRepairButtons()
    local list = {}
    for _, button in ipairs({ MerchantRepairItemButton, MerchantRepairAllButton, MerchantGuildBankRepairButton }) do
        if button:IsShown() then
            list[#list + 1] = button
        end
    end
    return list
end

-- Everything a vendor page with the junk button must satisfy.
local function checkRow(label, expectedRepairButtons)
    local junk = junkButton()
    ok(junk ~= nil and junk:IsVisible(), label .. ": the junk button is shown")
    if not (junk and junk:IsVisible()) then
        return
    end
    local junkRect = rel(junk)
    ok(inBox(junkRect), label .. ": the junk button sits inside the repair box, not below the frame")
    ok(not overlaps(junkRect, rel(MerchantBuyBackItem)), label .. ": it leaves the buyback item alone")

    local repairs = shownRepairButtons()
    ok(#repairs == expectedRepairButtons, ("%s: %d repair buttons shown"):format(label, expectedRepairButtons))

    local row = { junkRect }
    local rowLeft, rowRight = junkRect[1], junkRect[3]
    for _, button in ipairs(repairs) do
        local rc = rel(button)
        ok(inBox(rc), label .. ": " .. button:GetName() .. " sits inside the repair box")
        ok(junkRect[1] >= rc[3] - EPS, label .. ": the junk button is right of " .. button:GetName())
        ok(near(rc[2], junkRect[2]) and near(rc[4], junkRect[4]), label .. ": " .. button:GetName() .. " shares its row")
        row[#row + 1] = rc
        rowLeft = math.min(rowLeft, rc[1])
        rowRight = math.max(rowRight, rc[3])
    end
    local clean = true
    for i = 1, #row do
        for j = i + 1, #row do
            if overlaps(row[i], row[j]) then
                clean = false
            end
        end
    end
    ok(clean, label .. ": no two buttons overlap")
    ok(near((rowLeft + rowRight) / 2, BOX_CENTER_X, 1), label .. ": the row is centred in the box")

    if #repairs > 0 then
        ok(MerchantRepairText:IsShown(), label .. ": the Repair Items label is shown")
        local labelRect = rel(MerchantRepairText)
        ok(labelRect and labelRect[2] >= junkRect[4] - EPS, label .. ": the label sits above the buttons")
        -- y 129 is where stock 3.3.5 centres it above its own compact (guild bank) row.
        ok(labelRect and labelRect[1] >= BOX.left and labelRect[3] <= BOX.right
            and near((labelRect[2] + labelRect[4]) / 2, 129, 0.5), label .. ": the label stays in the box at the stock height")
    end
end

-- ----------------------------------------------------------------------------
section("Vendor that repairs (no guild bank)")
-- ----------------------------------------------------------------------------

putItem(0, 1, 2589, "Linen Cloth", 1, 5, 13)
putItem(0, 2, 4865, "Ruined Pelt", 0, 2, 5)
putItem(1, 4, 3300, "Rabbit's Foot", 0, 1, 7)

-- First open ever: the stock refresh runs before the module has made its button.
openVendor(true, false)
checkRow("repair", 2)
local junk = junkButton()
ok(junk and near(junk:GetWidth(), 32) and near(MerchantRepairAllButton:GetWidth(), 32),
    "repair: the row uses the compact 32 px stock layout")
local repairRect = rel(junk)

-- PLAYER_MONEY / GUILDBANK_UPDATE_MONEY call the stock function alone; it resets 36 px anchors.
MerchantFrame_UpdateRepairButtons()
ok(sameRect(rel(junk), repairRect) and near(MerchantRepairAllButton:GetWidth(), 32),
    "a stock re-anchor on a money event is laid out again")
noNewErrors("repair vendor")

-- ----------------------------------------------------------------------------
section("Junk state, tooltip and selling")
-- ----------------------------------------------------------------------------

-- nil when there is no icon, so the checks below fail rather than error on an older copy.
local function desaturated()
    if not junk.icon then
        return nil
    end
    return SIM.State(junk.icon).desaturated
end

ok(junk.icon ~= nil, "the button is an icon button, as on retail")
ok(desaturated() == false, "junk in the bags: the icon is in colour")
ok(junk:IsEnabled() == 1, "junk in the bags: the button is enabled")

SIM.CallScript(junk, "OnEnter")
local tip = SIM.TooltipText(GameTooltip)
ok(tip:find("Sell All Junk Items", 1, true) and tip:find("Items:", 1, true) and tip:find("3", 1, true),
    "the tooltip names the action and counts the 3 junk items")
SIM.CallScript(junk, "OnLeave")

SIM.CallScript(junk, "OnClick", "LeftButton")
table.sort(used)
ok(#used == 2 and used[1] == "0:2" and used[2] == "1:4", "a click sells both grey stacks and nothing else")
SIM.FireEvent("BAG_UPDATE", 0)
SIM.Run(0.5)
ok(desaturated() == true, "no junk left: the icon greys out, as on retail")
ok(junk:IsEnabled() == 1, "no junk left: the button stays clickable")

notes = {}
SIM.CallScript(junk, "OnClick", "LeftButton")
ok(#used == 2, "a click without junk sells nothing")
ok(notes[1] and notes[1]:find("Ctrl+Right-click", 1, true), "and explains how to mark items as junk")
noNewErrors("selling")

-- ----------------------------------------------------------------------------
section("Buyback tab")
-- ----------------------------------------------------------------------------

MerchantFrame.selectedTab = 2
MerchantFrame_Update()
ok(not junk:IsShown(), "the Buyback tab hides the junk button")
MerchantFrame_UpdateRepairButtons()
ok(not junk:IsShown(), "a money event on the Buyback tab does not bring it back")
MerchantFrame.selectedTab = 1
MerchantFrame_Update()
ok(junk:IsShown() and sameRect(rel(junk), repairRect), "back on the Merchant tab it returns to its spot")
closeVendor()
noNewErrors("tabs")

-- ----------------------------------------------------------------------------
section("Vendor with guild bank repair")
-- ----------------------------------------------------------------------------

putItem(0, 3, 4865, "Ruined Pelt", 0, 1, 5)
openVendor(true, true)
checkRow("guild repair", 3)
ok(desaturated() == false, "reopening with new junk: the icon is in colour again")
closeVendor()
noNewErrors("guild vendor")

-- ----------------------------------------------------------------------------
section("Vendor that cannot repair")
-- ----------------------------------------------------------------------------

openVendor(false, false)
checkRow("no repair", 0)
ok(near(junk:GetWidth(), 36), "no repair: full 36 px icon, the buyback slot's size")
closeVendor()
noNewErrors("no-repair vendor")

-- ----------------------------------------------------------------------------
section("Repair cost preview")
-- ----------------------------------------------------------------------------

local function text(fontString)
    return fontString:GetText() or ""
end

local function centerY(rc)
    return rc and (rc[2] + rc[4]) / 2
end

vendor.repairCost = 12345
openVendor(true, false)
local preview = _G.DCQoS_RepairCostFrame
local costLine, junkLine = preview and preview.costText, preview and preview.junkText
ok(preview ~= nil and preview:IsVisible(), "damaged gear: the repair cost preview shows")
ok(within(rel(preview), BAND), "it sits in the band under the title bar, inside the window")

local junkValue, junkCount = VendorPlus.CalculateJunkValue()
ok(junkCount > 0, "(setup) there is junk in the bags")
ok(costLine and text(costLine):find("Repair cost:", 1, true) and text(costLine):find("12345c", 1, true),
    "line 1 shows the repair cost")
ok(junkLine and junkLine:IsVisible() and text(junkLine):find(GetCoinTextureString(junkValue), 1, true)
    and text(junkLine):find("(" .. junkCount .. " items)", 1, true), "line 2 shows the junk value and count")
ok(costLine and within(rel(costLine), BAND) and junkLine and within(rel(junkLine), BAND),
    "both lines stay inside the band")
ok(costLine and junkLine and not overlaps(rel(costLine), rel(junkLine)), "the two lines do not overlap")
ok(costLine and not text(costLine):find("ff2020", 1, true), "an affordable repair is not shown in red")

money = 100
SIM.FireEvent("PLAYER_MONEY")
ok(costLine and text(costLine):find("|cffff2020" .. "12345c", 1, true), "a repair you cannot afford turns red")
money = 100000
SIM.FireEvent("PLAYER_MONEY")

DCQOS.settings.vendorPlus.showTotalJunkValue = false
SIM.FireEvent("BAG_UPDATE", 0)
ok(not junkLine:IsShown(), "junk value turned off: one line only")
ok(near(centerY(rel(costLine)), (BAND.bottom + BAND.top) / 2, 0.5), "a single line is centred in the band")

MerchantFrame.selectedTab = 2
MerchantFrame_Update()
ok(preview:IsVisible() and within(rel(preview), BAND), "the preview stays in place on the Buyback tab")
MerchantFrame.selectedTab = 1
MerchantFrame_Update()

-- Repair All -> UPDATE_INVENTORY_DURABILITY; it used to keep the old cost until a bag update.
vendor.repairCost = 0
SIM.FireEvent("UPDATE_INVENTORY_DURABILITY")
ok(not preview:IsShown(), "after repairing, with the junk value off, the preview hides")

DCQOS.settings.vendorPlus.showTotalJunkValue = true
SIM.FireEvent("BAG_UPDATE", 0)
ok(preview:IsShown() and text(costLine):find("Fully repaired", 1, true) and junkLine:IsShown(),
    "fully repaired with junk in the bags: says so above the junk value")

closeVendor()
ok(not preview:IsShown(), "closing the vendor hides it")
DCQOS.settings.vendorPlus.showRepairCost = false
vendor.repairCost = 12345
openVendor(true, false)
ok(not preview:IsShown(), "the setting turns it off")
DCQOS.settings.vendorPlus.showRepairCost = true
closeVendor()
noNewErrors("repair cost preview")

-- ----------------------------------------------------------------------------
section("Disabling the module")
-- ----------------------------------------------------------------------------

openVendor(true, false)
VendorPlus.OnDisable()
ok(not junk:IsShown(), "disabling hides the junk button")
local all = rel(MerchantRepairAllButton)
local text = rel(MerchantRepairText)
ok(all and near(all[3], 172) and near(all[2], 91) and near(MerchantRepairAllButton:GetWidth(), 36),
    "the repair buttons go back to the stock 36 px row")
ok(text and near(text[1], 26) and near(text[2], 103), "the Repair Items label goes back to the stock spot")
MerchantFrame_UpdateRepairButtons()
ok(near(MerchantRepairAllButton:GetWidth(), 36) and not junk:IsShown(), "later refreshes leave the stock row alone")

VendorPlus.OnEnable()
MerchantFrame_Update()
ok(junk:IsShown() and near(MerchantRepairAllButton:GetWidth(), 32), "enabling again brings the junk button back")
closeVendor()
noNewErrors("disable")

T.Finish()
