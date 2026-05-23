-- HLBG_Info.lua - Info panel for Hinterland Battleground AddOn
-- This file provides updated info about the battleground
-- Initialize our addon namespace if needed
if not HLBG then HLBG = {} end

-- Store server config data
HLBG.ServerConfig = HLBG.ServerConfig or {}

-- Parse optional CONFIG_INFO protocol message from server.
-- Some realms no longer publish this payload; the info panel degrades gracefully.
function HLBG.ParseConfigInfo(message)
    if not message or not message:find("CONFIG_INFO") then return end
    HLBG.DebugPrint("Parsing CONFIG_INFO: " .. message)
    
    -- Split by pipe delimiter
    for param in message:gmatch("[^|]+") do
        if param ~= "CONFIG_INFO" then
            local key, value = param:match("([^=]+)=([^=]+)")
            if key and value then
                -- Convert numeric values
                if tonumber(value) then
                    HLBG.ServerConfig[key] = tonumber(value)
                else
                    HLBG.ServerConfig[key] = value
                end
            end
        end
    end
    
    -- Count table entries (works for hash tables)
    local count = 0
    for _ in pairs(HLBG.ServerConfig) do count = count + 1 end
    HLBG.DebugPrint("Server config updated: " .. count .. " parameters")
    
    -- Refresh Info panel if it's currently visible
    if HLBG.UI and HLBG.UI.Info and HLBG.UI.Info:IsShown() then
        HLBG.UpdateInfo()
    end
end

local function BuildInfoText()
    local cfg = HLBG.ServerConfig or {}
    local lines = {}

    local matchDuration = tonumber(cfg.MATCH_DURATION) or 0
    local resourcesAlliance = tonumber(cfg.RESOURCES_ALLIANCE) or 0
    local resourcesHorde = tonumber(cfg.RESOURCES_HORDE) or 0
    local season = tonumber(cfg.SEASON) or 1
    local affixEnabled = tonumber(cfg.AFFIX_ENABLED) or 0
    local rewardHonor = tonumber(cfg.REWARD_HONOR) or 0
    local rewardHonorDepletion = tonumber(cfg.REWARD_HONOR_DEPLETION) or 0

    table.insert(lines, "|cFFFFD700Hinterland Battleground|r")
    table.insert(lines, "|cFFAAAAAAVersion 1.4.0|r")
    table.insert(lines, "")
    table.insert(lines, "|cFFFFD700Current Window Tabs|r")
    table.insert(lines, "- |cFFFFFFFFInfo|r: battleground overview, config, commands")
    table.insert(lines, "- |cFFFFFFFFQueue|r: join/leave queue and queue status")
    table.insert(lines, "")
    table.insert(lines, "|cFFFFD700Feature Locations|r")
    table.insert(lines,
        "- History and statistics: |cFFFFFFFFDC-Leaderboards|r (|cFFFFFFFF/leaderboard|r)")
    table.insert(lines,
        "- Addon settings: |cFFFFFFFF/hlbgconfig|r or Esc -> Interface -> AddOns -> DC HLBG Addon")
    table.insert(lines,
        "- Queue controls: Queue tab, |cFFFFFFFF/hlbgq join|r, |cFFFFFFFF/hlbgq leave|r, |cFFFFFFFF/hlbgq status|r")
    table.insert(lines,
        "- Chat command fallback: |cFFFFFFFF.hlbg queue join|r, |cFFFFFFFF.hlbg queue leave|r, |cFFFFFFFF.hlbg queue status|r")
    table.insert(lines, "")

    table.insert(lines, "|cFFFFD700Battleground Overview|r")
    table.insert(lines,
        "Hinterland BG is a 25v25 battleground with rotating affixes that can alter damage, " ..
        "movement, and resource pressure each match.")
    table.insert(lines,
        "Teams compete for map control and resource advantage while adapting to the active affix.")
    table.insert(lines, "")

    table.insert(lines, "|cFFFFD700Server Configuration|r")
    if next(cfg) then
        local durationText = "Not provided"
        if matchDuration > 0 then
            durationText = string.format("%d minutes", math.floor(matchDuration / 60))
        end

        table.insert(lines,
            string.format("- Match duration: |cFFFFFFFF%s|r", durationText))
        if cfg.RESOURCES_ALLIANCE ~= nil or cfg.RESOURCES_HORDE ~= nil then
            table.insert(lines,
                string.format("- Starting resources: |cFFFFFFFFAlliance %d|r / |cFFFFFFFFHorde %d|r",
                    resourcesAlliance, resourcesHorde))
        end
        if cfg.SEASON ~= nil then
            table.insert(lines,
                string.format("- Current season: |cFFFFFFFF%d|r", season))
        end
        if cfg.AFFIX_ENABLED ~= nil then
            local affixText = (affixEnabled == 1) and "Enabled" or "Disabled"
            table.insert(lines,
                string.format("- Affix system: |cFFFFFFFF%s|r", affixText))
        end
        if cfg.REWARD_HONOR ~= nil or cfg.REWARD_HONOR_DEPLETION ~= nil then
            table.insert(lines,
                string.format("- Honor rewards: |cFFFFFFFFMatch %d|r / |cFFFFFFFFDepletion %d|r",
                    rewardHonor, rewardHonorDepletion))
        end
    else
        table.insert(lines,
            "This realm does not publish an HLBG CONFIG_INFO payload. Use the Queue tab, |cFFFFFFFF/hlbgq|r, |cFFFFFFFF.hlbg live|r, or |cFFFFFFFF/leaderboard|r for current data.")
    end
    table.insert(lines, "")

    table.insert(lines, "|cFFFFD700Slash Commands|r")
    table.insert(lines, "- |cFFFFFFFF/hlbg|r: open main window")
    table.insert(lines, "- |cFFFFFFFF/hlbgconfig|r: open HLBG addon settings")
    table.insert(lines, "- |cFFFFFFFF/hlbgq join|r: join queue")
    table.insert(lines, "- |cFFFFFFFF/hlbgq leave|r: leave queue")
    table.insert(lines, "- |cFFFFFFFF/hlbgq status|r: request queue status")
    table.insert(lines, "- |cFFFFFFFF/hlbg devmode on|off|r: toggle debug mode")
    table.insert(lines,
        "- |cFFFFFFFF/hlbg season <n>|r: set season filter (0 = all/current)")
    table.insert(lines, "")

    table.insert(lines, "|cFFFFD700Server Chat Fallback|r")
    table.insert(lines, "- |cFFFFFFFF.hlbg queue join|r: join queue via chat command")
    table.insert(lines, "- |cFFFFFFFF.hlbg queue leave|r: leave queue via chat command")
    table.insert(lines, "- |cFFFFFFFF.hlbg queue status|r: request queue status via chat command")

    return table.concat(lines, "\n")
end

-- Update info panel with current version and features
function HLBG.UpdateInfo()
    -- Make sure the UI is loaded
    if not HLBG._ensureUI('Info') then return end
    local info = HLBG.UI.Info

    if not info.Content then
        return
    end

    -- Hide any previously generated static children from old layouts.
    if info.Content.children then
        for _, child in ipairs(info.Content.children) do
            if child and child.Hide then
                child:Hide()
            end
        end
        info.Content.children = nil
    end

    if not info.Scroll then
        info.Scroll = CreateFrame("ScrollFrame", "HLBG_InfoScrollFrame", info.Content,
            "UIPanelScrollFrameTemplate")
        info.Scroll:SetPoint("TOPLEFT", info.Content, "TOPLEFT", 16, -72)
        info.Scroll:SetPoint("BOTTOMRIGHT", info.Content, "BOTTOMRIGHT", -36, 16)
        info.Scroll:EnableMouseWheel(true)
        info.Scroll:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll()
            local maxScroll = self:GetVerticalScrollRange() or 0
            local step = 36

            if delta < 0 then
                self:SetVerticalScroll(math.min(maxScroll, current + step))
            else
                self:SetVerticalScroll(math.max(0, current - step))
            end
        end)
    end

    if not info.ScrollChild then
        info.ScrollChild = CreateFrame("Frame", nil, info.Scroll)
        info.ScrollChild:SetPoint("TOPLEFT", info.Scroll, "TOPLEFT", 0, 0)
        info.ScrollChild:SetSize(560, 1)
        info.Scroll:SetScrollChild(info.ScrollChild)
    end

    if not info.InfoText then
        info.InfoText = info.ScrollChild:CreateFontString(nil, "OVERLAY",
            "GameFontHighlight")
        info.InfoText:SetPoint("TOPLEFT", info.ScrollChild, "TOPLEFT", 0, 0)
        info.InfoText:SetJustifyH("LEFT")
        info.InfoText:SetJustifyV("TOP")
    end

    local width = info.Scroll:GetWidth() or 0
    if width < 100 then
        width = 560
    end
    width = math.max(380, width - 28)

    info.ScrollChild:SetWidth(width)
    info.InfoText:SetWidth(width)
    info.InfoText:SetText(BuildInfoText())

    local textHeight = info.InfoText:GetStringHeight() or 0
    info.ScrollChild:SetHeight(math.max(1, textHeight + 18))
    info.Scroll:SetVerticalScroll(0)

    -- Keep legacy container height valid for compatibility hooks.
    info.Content:SetHeight(math.max(info.Content:GetHeight() or 1, textHeight + 120))
    info:Show()
end


