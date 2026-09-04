local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
-- HLBG_Stubs.lua - Minimal compatibility stubs for older clients
-- These provide safe fallbacks for functions the addon expects to exist.
if not HLBG.UpdateHUD then
    function HLBG.UpdateHUD()
        -- No-op stub; real HUD will overwrite this when loaded.
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage('|cFFFFFF00HLBG Debug:|r UpdateHUD stub called (HUD not loaded)')
        end
    end
end
-- Affix codes mirror HinterlandBGConstants::HLBGAffixCode on the server
-- (src/server/scripts/DC/HinterlandBG/hlbg_constants.h). Keep both in step:
-- names come from GetAffixName, descriptions from GetAffixDescription.
-- Affix codes mirror HinterlandBGConstants::HLBGAffixCode on the server
-- (src/server/scripts/DC/HinterlandBG/hlbg_constants.h). Keep both in step.
--
-- Entries are filled individually rather than with `T = T or {...}`.
-- HLBG_Utils.lua runs first and does `HLBG.AFFIX_NAMES = HLBG.AFFIX_NAMES or {}`,
-- so the whole-table guard saw a non-nil (empty) table and kept it -- every
-- affix rendered as "Affix 4" instead of "Storm". Same trap as the C_Timer
-- incident written up in HLBG_TimerCompat.lua: guard per entry, not per table.
HLBG.AFFIX_NAMES = HLBG.AFFIX_NAMES or {}
HLBG.AFFIX_DESCRIPTIONS = HLBG.AFFIX_DESCRIPTIONS or {}

do
    local names = {
        [0]  = "None",
        [1]  = "Sunlight",
        [2]  = "Clear Skies",
        [3]  = "Gentle Breeze",
        [4]  = "Storm",
        [5]  = "Heavy Rain",
        [6]  = "Fog",
        [7]  = "Warlords",
        [8]  = "Skirmish",
        [9]  = "Bloodlust",
        [10] = "Nightfall",
    }

    local descriptions = {
        [0]  = "",
        [1]  = "Healing done increased by 15%.",
        [2]  = "Damage done increased by 5%.",
        [3]  = "Movement speed increased by 12%.",
        [4]  = "Damage taken increased by 12%.",
        [5]  = "Movement speed reduced by 12%.",
        [6]  = "Creatures notice you from 8 yards closer.",
        [7]  = "Faction bosses are worth double resources.",
        [8]  = "Killing NPCs drains no resources - players only.",
        [9]  = "Player kills drain double resources.",
        [10] = "Night falls. Creatures notice you from 8 yards closer.",
    }

    for id, value in pairs(names) do
        if HLBG.AFFIX_NAMES[id] == nil then
            HLBG.AFFIX_NAMES[id] = value
        end
    end

    for id, value in pairs(descriptions) do
        if HLBG.AFFIX_DESCRIPTIONS[id] == nil then
            HLBG.AFFIX_DESCRIPTIONS[id] = value
        end
    end
end

if not HLBG.GetAffixName then
    function HLBG.GetAffixName(affixId)
        local id = tonumber(affixId) or 0
        return HLBG.AFFIX_NAMES[id] or ("Affix " .. tostring(affixId))
    end
end

if not HLBG.GetAffixDescription then
    function HLBG.GetAffixDescription(affixId)
        return HLBG.AFFIX_DESCRIPTIONS[tonumber(affixId) or 0] or ""
    end
end

-- "Fog - Creatures notice you from 8 yards closer." for tooltips/HUD.
if not HLBG.GetAffixLabel then
    function HLBG.GetAffixLabel(affixId)
        local name = HLBG.GetAffixName(affixId)
        local desc = HLBG.GetAffixDescription(affixId)
        if desc ~= "" then
            return name .. " - " .. desc
        end
        return name
    end
end
-- Common small helpers
if not HLBG.PlayerName then
    HLBG.PlayerName = (type(UnitName) == 'function' and UnitName("player")) or "Unknown"
end
if not HLBG.IsInGroup then
    -- GetNumGroupMembers is Cata+ and does not exist on 3.3.5a, so the old
    -- implementation was guarded into always returning false. 3.3.5 splits the
    -- count across party and raid.
    function HLBG.IsInGroup()
        local raid = (type(GetNumRaidMembers) == "function" and GetNumRaidMembers()) or 0
        if raid > 0 then
            return true
        end

        local party = (type(GetNumPartyMembers) == "function" and GetNumPartyMembers()) or 0
        return party > 0
    end
end
if not HLBG.SafePrint then
    function HLBG.SafePrint(...)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(table.concat({ ... }, " "))
        end
    end
end
return HLBG

