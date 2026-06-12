-- DC-Housing Core: addon namespace, init, slash commands.
DCHousing = DCHousing or {}
local DC = DCHousing
local L = DCHousingLocale

DC.MODULE_ID = "DECO"

-- Server-pushed state (refreshed via SMSG_BUDGET).
DC.budget = { used = 0, cap = 0, houseLevel = 0,
    canSpawn = false, canMove = false, canDelete = false }

function DC:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFCC00[DC-Housing]|r " .. tostring(msg))
end

-- Catalog data comes from the generated Data\HousingModels.lua; entries
-- flagged enabled=false exist server-side but their model has not shipped
-- in the client patch yet.
function DC:GetItem(entry)
    return DCHousingModelData and DCHousingModelData[entry]
end

function DC:GetCategories()
    if self._categories then
        return self._categories
    end

    local seen, list = {}, {}
    for _, item in pairs(DCHousingModelData or {}) do
        if item.enabled and not seen[item.category] then
            seen[item.category] = true
            table.insert(list, item.category)
        end
    end
    table.sort(list)
    self._categories = list
    return list
end

-- Sorted list of enabled entries, optionally filtered.
function DC:GetFilteredEntries(category, search)
    local result = {}
    local needle = search and search ~= "" and string.lower(search) or nil
    for entry, item in pairs(DCHousingModelData or {}) do
        if item.enabled
            and (not category or item.category == category)
            and (not needle
                or string.find(string.lower(item.name), needle, 1, true))
        then
            table.insert(result, entry)
        end
    end
    table.sort(result, function(a, b)
        return DCHousingModelData[a].name < DCHousingModelData[b].name
    end)
    return result
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if not DCAddonProtocol then
        DC:Print("|cffff0000Error:|r DC-AddonProtocol not found.")
        return
    end
    DC.Protocol:Init()
end)

SLASH_DCHOUSING1 = "/dchousing"
SLASH_DCHOUSING2 = "/dch"
SlashCmdList.DCHOUSING = function(message)
    local command = string.lower(string.match(message or "", "^(%S*)") or "")
    if command == "edit" then
        DC.EditMode:Toggle()
    elseif command == "budget" then
        DC.Protocol:RequestBudget()
    else
        DC.Catalog:Toggle()
    end
end
