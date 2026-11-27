-- DC-GM Modules/Linkifier.lua link actions (2026-11-10 security rework): a link only acts when this
-- client saw it in server output, arguments must have the expected shape, and anything that changes
-- state asks first. Pins the fix for player-posted links steering a GM into dot commands.
local path = arg and arg[1] or "../DC-GM/Modules/Linkifier.lua"

local sent, popups, notices, fellThrough = {}, {}, {}, {}
Strings = setmetatable({}, { __index = function() return "^NOMATCH_PATTERN$" end })
Locale = setmetatable({}, { __index = function(_, k) return k end })
AzerothAdmin = { db = { profile = { style = { color = { linkifier = { r = 1, g = 0, b = 0 } } } } } }
StaticPopupDialogs = {}
YES, NO = "Yes", "No"
function SendChatMessage(msg, chatType) sent[#sent + 1] = { msg, chatType } end
function StaticPopup_Show(which, a1, a2, data)
  local d = { which = which, text = a1, data = data }
  popups[#popups + 1] = d
  return d
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) notices[#notices + 1] = m end }
function MangLinkifier_SetItemRef_Original(link) fellThrough[#fellThrough + 1] = link end
strsub = string.sub

dofile(path)

local pass, fail = 0, 0
local function check(cond, name)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. name) end
end
local function reset() sent, popups, notices, fellThrough = {}, {}, {}, {} end

-- 1. A link a player posts in chat never acts, even with a custom DC-GM type.
reset()
MangLinkifier_SetItemRef("lookupspelllearn:12345", "[Shadowmourne]", "LeftButton")
check(#sent == 0 and #popups == 0, "player-posted lookupspelllearn sends nothing")
check(#notices == 1, "player-posted link is reported")
MangLinkifier_SetItemRef("creature_entry:123", "[Thunderfury]", "LeftButton")
check(#sent == 0 and #popups == 0, "creature_entry no longer spawns on click")
check(fellThrough[1] == "creature_entry:123", "creature_entry falls through to the stock handler")

-- 2. A SYSTEM line from .lookup creature is linkified and its links remembered.
reset()
local line = "|cffffffff|Hcreature_entry:4567|h[Test Mob]|h|r"
local out = MangLinkifier_ProcessServerLine(line)
check(out:find("lookupcreatureadd:4567", 1, true) ~= nil, "server line gets a [Spawn] link")
MangLinkifier_SetItemRef("lookupcreatureadd:4567", "[Spawn]", "LeftButton")
check(#sent == 0 and #popups == 1, "spawn asks for confirmation")
check(popups[1] and popups[1].data == ".npc add 4567", "popup carries the exact command")
StaticPopupDialogs["DCGM_CONFIRM_LINK_COMMAND"].OnAccept(nil, popups[1].data)
check(sent[1] and sent[1][1] == ".npc add 4567" and sent[1][2] == "SAY", "accept sends the command")

-- 3. Read-only / navigation links act without a popup.
reset()
MangLinkifier_SetItemRef("lookupcreaturelist:4567", "[List]", "LeftButton")
check(#popups == 0 and sent[1] and sent[1][1] == ".list creature 4567", "list runs directly")

-- 4. Arguments are validated: a remembered link with extra words is refused.
reset()
MangLinkifier_ProcessServerLine("|cffffffff|Htele:name Victim Stormwind|h[x]|h|r")
MangLinkifier_SetItemRef("tele:name Victim Stormwind", "[x]", "LeftButton")
check(#sent == 0 and #popups == 0, "tele with extra words refused")
MangLinkifier_ProcessServerLine("|cffffffff|Htele:Stormwind|h[Stormwind]|h|r")
MangLinkifier_SetItemRef("tele:Stormwind", "[Stormwind]", "LeftButton")
check(sent[1] and sent[1][1] == ".tele Stormwind", "plain tele name works")

-- 5. Item links: [Add] takes the leading item id only and confirms.
reset()
MangLinkifier_ProcessServerLine("|cffa335ee|Hitem:49623:0:0:0:0:0:0:0:80|h[Shadowmourne]|h|r")
local addLink = "lookupitemadd:49623:0:0:0:0:0:0:0:80"
MangLinkifier_SetItemRef(addLink, "[Add]", "LeftButton")
check(popups[1] and popups[1].data == ".additem 49623", "item add confirms with the id only")

-- 6. npcdisplay2 is its own type (the old prefix match sent the wrong argument).
reset()
MangLinkifier_ProcessServerLine("|cffff8000|Hnpcdisplay2:999|h[Morph]|h|r")
MangLinkifier_SetItemRef("npcdisplay2:999", "[Morph]", "LeftButton")
check(popups[1] and popups[1].data == ".modify morph 999", "npcdisplay2 parsed as its own type")

-- 7. Non-DC link types still reach the stock handler.
reset()
MangLinkifier_SetItemRef("player:Someone", "[Someone]", "LeftButton")
check(fellThrough[1] == "player:Someone", "player links fall through")

print(string.format("RESULT %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
