--[[
    DC-Collection Data/CompanionItemSeeds.lua
    ========================================

    Optional fallback seed list for Companions (Pets tab).

    Why this exists:
    - Some servers may not provide pet definitions immediately (or at all).
    - Characters with zero learned companions would otherwise see an empty list.

    How to use:
    - Populate the table below with companion *item IDs* (WotLK item class: Miscellaneous -> Companions).
    - The addon will use GetItemInfo/GetItemSpell at runtime to resolve name/icon/spellId.

    Suggested source:
    - Wowhead WotLK "Companion Items" list (209 items): https://www.wowhead.com/wotlk/items=15.2

    Note:
    - Leave this empty if your server already provides definitions.
]]

local DC = DCCollection

DC.COMPANION_ITEM_SEEDS = DC.COMPANION_ITEM_SEEDS or {
    -- Example:
    -- 8485,  -- Cat Carrier (Bombay)
}
