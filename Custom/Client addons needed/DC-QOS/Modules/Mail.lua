-- ============================================================
-- DC-QoS: Mail Module
-- ============================================================
-- Enhanced mail features (Collect All button)
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Mail = {
    displayName = "Mail Enhancements",
    settingKey = "mail",
    icon = "Interface\\Icons\\INV_Letter_15",
}

-- ============================================================
-- Constants & Variables
-- ============================================================
local mailFrame
local collectAllBtn

-- ============================================================
-- UI Creation
-- ============================================================
local function CreateMailUI()
    if mailFrame then return end
    
    -- Enhanced mail frame container
    mailFrame = CreateFrame("Frame", "DCEnhancedMail", MailFrame)
    mailFrame:SetSize(100, 30)
    mailFrame:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", -40, -10)
    
    -- "Collect All" Button
    collectAllBtn = CreateFrame("Button", nil, mailFrame, "UIPanelButtonTemplate")
    collectAllBtn:SetSize(100, 25)
    collectAllBtn:SetPoint("CENTER")
    collectAllBtn:SetText("Collect All")
    
    collectAllBtn:SetScript("OnClick", function()
        if addon:IsConnected() then
            addon.protocol:RequestCollectAllMail()
            collectAllBtn:Disable() -- Prevent spam
            addon:DelayedCall(2, function() collectAllBtn:Enable() end)
        else
            addon:Print("Cannot collect mail: Not connected to server.", true)
        end
    end)
    
    -- Mail Count Text
    local countText = mailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOM", collectAllBtn, "TOP", 0, 2)
    
    local function UpdateMailCount()
        local count = GetInboxNumItems()
        if count > 0 then
            countText:SetText(count .. " mails")
            collectAllBtn:Enable()
        else
            countText:SetText("Empty")
            collectAllBtn:Disable()
        end
    end
    
    mailFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    mailFrame:RegisterEvent("MAIL_SHOW")
    mailFrame:SetScript("OnEvent", UpdateMailCount)
    
    -- Initial update
    UpdateMailCount()
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Mail.OnInitialize()
    -- Hook into MailFrame if it's already loaded, otherwise wait for ADDON_LOADED
    if IsAddOnLoaded("Blizzard_MailUI") then
        CreateMailUI()
    else
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, event, arg1)
            if arg1 == "Blizzard_MailUI" then
                CreateMailUI()
                self:UnregisterAllEvents()
            end
        end)
    end
end

function Mail.OnEnable()
    if mailFrame then
        mailFrame:Show()
    end
end

function Mail.OnDisable()
    if mailFrame then
        mailFrame:Hide()
    end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function Mail.CreateSettings(parent)
    -- Start with "Mail Enhancements" being enabled/disabled via the main module toggle.
    -- If we add more specific options later (like Open All speed), we can add checkboxes here.
    
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Mail Settings")
    
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Adds 'Collect All' button to the mailbox interface.")
    
    return -50
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Mail", Mail)
