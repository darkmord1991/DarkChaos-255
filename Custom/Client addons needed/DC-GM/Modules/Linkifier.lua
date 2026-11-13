-------------------------------------------------------------------------------------------------------------
--
-- AzerothAdmin Version 3.x
-- AzerothAdmin is a derivative of TrinityAdmin/MangAdmin.
--
-- Copyright (C) 2007 Free Software Foundation, Inc.
-- License GPLv3+: GNU GPL version 3 or later <https://www.gnu.org/licenses/gpl-3.0.en.html>
-- This is free software: you are free to change and redistribute it.
-- There is NO WARRANTY, to the extent permitted by law.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--
-- Repository: https://github.com/superstyro/AzerothAdmin
--
-------------------------------------------------------------------------------------------------------------

local function RGBPercToHex(r, g, b)
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("%02x%02x%02x", r*255, g*255, b*255)
end
function MangLinkifier_Decompose(chatstring)
  if chatstring ~= nil then
    ----------====~~GO Target Command Match Text ~~====----------
    for guid in string.gmatch(chatstring, Strings["lfer_GOtargid1"]) do --TARGET ID
      chatstring = string.gsub (chatstring, Strings["lfer_GOtargid2"], MangLinkifier_Link(Strings["lfer_GOtargid3"], "%2", "targid"))
    end
    for guid in string.gmatch(chatstring, Strings["lfer_GOtargguid1"]) do --TARGET GUID
      chatstring = string.gsub (chatstring, Strings["lfer_GOtargguid1"], MangLinkifier_Link(Strings["lfer_GOtargguid3"], "%1", "targguid"))
    end
    for guid in string.gmatch(chatstring, Strings["lfer_GOtargxyz1"]) do --TARGET XYZ
      chatstring = string.gsub (chatstring, Strings["lfer_GOtargxyz2"], MangLinkifier_Link(Strings["lfer_GOtargxyz3"], "1 %2 %3 %4", "targxyz"))
    end
    ----------====~~ NPC Info Command Match Text ~~====----------
    for guid in string.gmatch(chatstring, Strings["lfer_NPCInfoguid1"]) do --NPCINFO GUID
      chatstring = string.gsub (chatstring, Strings["lfer_NPCInfoguid2"], MangLinkifier_Link(Strings["lfer_NPCInfoguid3"], "%1", "npcguid"))
    end
    for guid in string.gmatch(chatstring, Strings["lfer_NPCInfoentry1"]) do --NPCINFO Entry
      chatstring = string.gsub (chatstring, Strings["lfer_NPCInfoentry2"], MangLinkifier_Link(Strings["lfer_NPCInfoentry3"], "%1", "npcentry"))
    end
    for guid in string.gmatch(chatstring, Strings["lfer_NPCInfodisplay1"]) do --NPCINFO Display
      chatstring = string.gsub (chatstring, Strings["lfer_NPCInfodisplay2"], MangLinkifier_Link(Strings["lfer_NPCInfodisplay3"], "%1", "npcdisplay"))
    end
    for guid in string.gmatch(chatstring, Strings["lfer_NPCInfodisplay21"]) do --NPCINFO Display Native
      chatstring = string.gsub (chatstring, Strings["lfer_NPCInfodisplay22"], MangLinkifier_Link(Strings["lfer_NPCInfodisplay23"], "%1", "npcdisplay2"))
    end
    ----------====~~ ADD GO Command Match Text ~~====----------
    for guid in string.gmatch(chatstring, Strings["lfer_AddGoguid1"]) do --ADDGO GUID
      chatstring = string.gsub (chatstring, Strings["lfer_AddGoguid2"], MangLinkifier_Link(Strings["lfer_AddGoguid3"], "%1", "addgoguid"))
    end
    for guid in string.gmatch(chatstring, Strings["lfer_AddGoid1"]) do --ADDGO ID
      chatstring = string.gsub (chatstring, Strings["lfer_AddGoid2"], MangLinkifier_Link(Strings["lfer_AddGoid3"], "%1", "addgoid"))
    end
    for guid in string.gmatch(chatstring, Strings["lfer_AddGoxyz1"]) do --ADDGO XYZ
      chatstring = string.gsub (chatstring, Strings["lfer_AddGoxyz2"], MangLinkifier_Link(Strings["lfer_AddGoxyz3"], "%1 %2 %3", "addgoxyz"))
    end
    ----------====~~ GPS Command Match Text ~~====----------
    for guid in string.gmatch(chatstring, Strings["lfer_GPSxyz1"]) do --GPS XYZ
      chatstring = string.gsub (chatstring, Strings["lfer_GPSxyz2"], MangLinkifier_Link(Strings["lfer_GPSxyz3"], "%1 %2 %3", "gpsxyz"))
    end
    ----------====~~ Added Options for Clickable Links Made by Mangos ~~====----------
    for guid in string.gmatch(chatstring, "%|cffffffff%|Hquest:(.*)%|h%[(.*)%]%|h%|r") do --LOOKUP QUEST
      chatstring = string.gsub (chatstring, "%|cffffffff%|Hquest:(.*)%|h%[(.*)%]%|h%|r", MangLinkifier_Link("%2", "%1", "lookupquest"))
    end
    for guid in string.gmatch(chatstring, "%|cff(.*)%|Hitem:(.*)%|h%[(.*)%]%|h%|r") do --LOOKUP ITEM -- Bug when more than 1 item is linked in chat, it is not  translated
      chatstring = string.gsub (chatstring, "%|cff(.*)%|Hitem:(.*)%|h%[(.*)%]%|h%|r", MangLinkifier_Link("%3-%1", "%2", "lookupitem"))
    end
    for guid in string.gmatch(chatstring, "%|cffffffff%|Hgameobject_entry:(.*)%|h%[(.*)%]%|h%|r") do --LOOKUP OBJECT
      chatstring = string.gsub (chatstring, "%|cffffffff%|Hgameobject_entry:(.*)%|h%[(.*)%]%|h%|r", MangLinkifier_Link("%2", "%1", "lookupgo"))
    end
    for guid in string.gmatch(chatstring, "%|cffffffff%|Hcreature_entry:(.*)%|h%[(.*)%]%|h%|r") do --LOOKUP CREATURE
      chatstring = string.gsub (chatstring, "%|cffffffff%|Hcreature_entry:(.*)%|h%[(.*)%]%|h%|r", MangLinkifier_Link("%2", "%1", "lookupcreature"))
    end
    for guid in string.gmatch(chatstring, "%|cffffffff%|Hspell:(.*)%|h%[(.*)%]%|h%|r") do --LOOKUP SPELL
      chatstring = string.gsub (chatstring, "%|cffffffff%|Hspell:(.*)%|h%[(.*)%]%|h%|r", MangLinkifier_Link("%2", "%1", "lookupspell"))
    end
    for guid in string.gmatch(chatstring, "%|cffffffff%|Htele:(.*)%|h%[(.*)%]%|h%|r") do --LOOKUP TELE
      chatstring = string.gsub (chatstring, "%|cffffffff%|Htele:(.*)%|h%[(.*)%]%|h%|r", MangLinkifier_Link("%2", "%1", "lookuptele"))
    end
  end
  return chatstring
end

function MangLinkifier_Link(orgtxt, id, type)
  local color = AzerothAdmin.db.profile.style.color.linkifier
  local urlcolor = RGBPercToHex(color.r,color.g,color.b)
  --local urlcolor = (string.rep("0",6-string.len((string.upper(string.format("%x", dec)))))..(string.upper(string.format("%x", dec))))
  ----------====~~GO Target Command Replace Text ~~====----------
  if(type == "targid") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Htargidadd:" .. id .. "|h["..Locale["lfer_Spawn"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Htargidlist:" .. id .. "|h["..Locale["lfer_List"].."]|h|r "
  elseif(type == "targguid") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Htargguidgo:" .. id .. "|h["..Locale["lfer_Goto"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Htargguidmove:" .. id .. "|h["..Locale["lfer_Move"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Htargguidturn:" .. id .. "|h["..Locale["lfer_Turn"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Htargguiddel:" .. id .. "|h["..Locale["lfer_Delete"].."]|h|r \n"
  elseif(type == "targxyz") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Htargxyz:" .. id .. "|h["..Locale["lfer_Teleport"].."]|h|r "
  ----------====~~ NPC Info Command Replace Text ~~====----------
  elseif(type == "npcguid") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Hnpcguidgo:" .. id .. "|h["..Locale["lfer_Goto"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Hnpcguidmove:" .. id .. "|h["..Locale["lfer_Move"].."]|h|r "
  elseif(type == "npcentry") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Hnpcentryadd:" .. id .. "|h["..Locale["lfer_Spawn"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Hnpcentrylist:" .. id .. "|h["..Locale["lfer_List"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Hnpcentryreload:" .. id .. "|h["..Locale["lfer_Reload"].."]|h|r "
  elseif(type == "npcdisplay") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Hnpcdisplay:" .. id .. "|h["..Locale["lfer_Morph"].."]|h|r "
  elseif(type == "npcdisplay2") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Hnpcdisplay2:" .. id .. "|h["..Locale["lfer_Morph"].."]|h|r "
  ----------====~~ ADD GO Command Replace Text ~~====----------
  elseif(type == "addgoguid") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Haddgoguidgo:" .. id .. "|h["..Locale["lfer_Goto"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Haddgoguidmove:" .. id .. "|h["..Locale["lfer_Move"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Haddgoguidturn:" .. id .. "|h["..Locale["lfer_Turn"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Haddgoguiddel:" .. id .. "|h["..Locale["lfer_Delete"].."]|h|r \n"
  elseif(type == "addgoid") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Haddgoid:" .. id .. "|h["..Locale["lfer_Spawn"].."]|h|r \n"
  elseif(type == "addgoxyz") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Haddgoxyz:" .. id .. "|h["..Locale["lfer_Teleport"].."]|h|r "
  ----------====~~ GPS Command Replace Text ~~====----------
  elseif(type == "gpsxyz") then
    link = orgtxt .." - |cff" .. urlcolor .. "|Hgpsxyz:" .. id .. "|h["..Locale["lfer_Teleport"].."]|h|r "
  ----------====~~ Added Options for Clickable Links Made by Mangos ~~====----------
  elseif(type == "lookupquest") then
    link = "|cffffffff|Hquest:" .. id .. "|h[" .. orgtxt .. "]|h|r"
    link = link .." - |cff" .. urlcolor .. "|Hlookupquestadd:" .. id .. "|h["..Locale["lfer_Add"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Hlookupquestrem:" .. id .. "|h["..Locale["lfer_Remove"].."]|h|r "
  elseif(type == "lookupitem") then
    for orgtxt, color in string.gmatch (orgtxt, "(.*)%-(.*)") do
      link = "|cff" .. color .."|Hitem:" .. id .. "|h[" .. orgtxt .. "]|h|r"
      link = link .." - |cff" .. urlcolor .. "|Hlookupitemadd:" .. id .. "|h["..Locale["lfer_Add"].."]|h|r "  
      link = link .." - |cff" .. urlcolor .. "|Hlookupitemlist:" .. id .. "|h["..Locale["lfer_List"].."]|h|r "
    end
  elseif(type == "lookupgo") then
    link = "|cffffffff|Hgameobject_entry:" .. id .. "|h[" .. orgtxt .. "]|h|r"
    link = link .." - |cff" .. urlcolor .. "|Hlookupgoadd:" .. id .. "|h["..Locale["lfer_Spawn"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Hlookupgolist:" .. id .. "|h["..Locale["lfer_List"].."]|h|r "
  elseif(type == "lookupcreature") then
    link = "|cffffffff|Hcreature_entry:" .. id .. "|h[" .. orgtxt .. "]|h|r"
    link = link .." - |cff" .. urlcolor .. "|Hlookupcreatureadd:" .. id .. "|h["..Locale["lfer_Spawn"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Hlookupcreaturelist:" .. id .. "|h["..Locale["lfer_List"].."]|h|r "
  elseif(type == "lookupspell") then
    link = "|cffffffff|Hspell:" .. id .. "|h[" .. orgtxt .. "]|h|r"
    link = link .." - |cff" .. urlcolor .. "|Hlookupspelllearn:" .. id .. "|h["..Locale["lfer_Learn"].."]|h|r "
    link = link .." - |cff" .. urlcolor .. "|Hlookupspellunlearn:" .. id .. "|h["..Locale["lfer_Unlearn"].."]|h|r "
  elseif(type == "lookuptele") then
    link = "|cffffffff|Htele:" .. id .. "|h[" .. orgtxt .. "]|h|r"
    link = link .." - |cff" .. urlcolor .. "|Hlookupteledelete:" .. id .. "|h["..Locale["lfer_Delete"].."]|h|r "
  else
    link = orgtxt .." - |cffc20000"..Locale["lfer_Error"].." |r |cff008873" .. type .. "|r"
  end
  return link
end

-------------------------------------------------------------------------------------------------------------
-- Link actions (DarkChaos security rework, 2026-11-10)
--
-- A click used to send ".<command> <link data>" for ANY link with a matching type prefix, wherever the
-- link came from. Every chat line a GM sends that starts with "." runs with GM rights, so another player
-- could post a disguised link (it renders like an item) and make the GM run commands of their choosing.
-- Now:
--   * only links this client built or saw in a SYSTEM (server) line act; links in player chat do not,
--   * the argument must match the shape the command expects (numbers, coordinates, a tele name),
--   * anything that changes the world or a character asks for confirmation and shows the exact command.
-------------------------------------------------------------------------------------------------------------

-- link type -> command prefix, argument shape, confirm before sending
local LINK_ACTIONS = {
  targidadd          = { ".gobject add ",              "id",   true  },
  targidlist         = { ".list object ",              "id",   false },
  targguidgo         = { ".go gameobject ",            "id",   false },
  targguidmove       = { ".gobject move ",             "id",   true  },
  targguidturn       = { ".gobject turn ",             "id",   true  },
  targguiddel        = { ".gobject delete ",           "id",   true  },
  targxyz            = { ".go ",                       "xyz",  false },
  npcguidgo          = { ".go creature ",              "id",   false },
  npcguidmove        = { ".go creature ",              "id",   false },
  npcentryadd        = { ".npc add ",                  "id",   true  },
  npcentrylist       = { ".list creature ",            "id",   false },
  npcentryreload     = { ".reload creature_template ", "id",   true  },
  npcdisplay         = { ".modify morph ",             "id",   true  },
  npcdisplay2        = { ".modify morph ",             "id",   true  },
  addgoguidgo        = { ".go gameobject ",            "id",   false },
  addgoguidmove      = { ".gobject move ",             "id",   true  },
  addgoguidturn      = { ".gobject turn ",             "id",   true  },
  addgoguiddel       = { ".gobject delete ",           "id",   true  },
  addgoid            = { ".gobject add ",              "id",   true  },
  addgoxyz           = { ".go ",                       "xyz",  false },
  gpsxyz             = { ".go  ",                      "xyz",  false },
  lookupquestadd     = { ".quest add ",                "id",   true  },
  lookupquestrem     = { ".quest remove ",             "id",   true  },
  lookupitemadd      = { ".additem ",                  "id",   true  },
  lookupitemlist     = { ".list item ",                "id",   false },
  lookupgoadd        = { ".gobject add ",              "id",   true  },
  lookupgolist       = { ".list object ",              "id",   false },
  lookupcreatureadd  = { ".npc add ",                  "id",   true  },
  lookupcreaturelist = { ".list creature ",            "id",   false },
  lookupspelllearn   = { ".learn ",                    "id",   true  },
  lookupspellunlearn = { ".unlearn ",                  "id",   true  },
  lookupteledelete   = { ".tele del ",                 "name", true  },
  -- Standard link types the server prints in .list / .lookup output: clicking teleports the GM.
  -- gameobject_entry / creature_entry no longer spawn on click: use the [Spawn] link next to them.
  gameobject         = { ".go gameobject ",            "id",   false },
  creature           = { ".go creature ",              "id",   false },
  tele               = { ".tele ",                     "name", false },
}

-- Links seen in server output or built by MangLinkifier_Link, keyed by "type:data".
local knownLinks = {}
local knownLinkCount = 0
local KNOWN_LINK_LIMIT = 4000

local function RememberLinksIn(text)
  if type(text) ~= "string" then
    return
  end
  for data in string.gmatch(text, "|H([^|]+)|h") do
    local linkType = string.match(data, "^([^:]+)")
    if linkType and LINK_ACTIONS[linkType] and not knownLinks[data] then
      if knownLinkCount >= KNOWN_LINK_LIMIT then
        -- Old links go dead rather than the table growing for the whole session.
        knownLinks = {}
        knownLinkCount = 0
      end
      knownLinks[data] = true
      knownLinkCount = knownLinkCount + 1
    end
  end
end

-- Linkify a SYSTEM (server) line and remember the links in it. Player chat is not linkified.
function MangLinkifier_ProcessServerLine(text)
  text = MangLinkifier_Decompose(text)
  RememberLinksIn(text)
  return text
end

local function BuildArgument(kind, data)
  if kind == "id" then
    -- Item and quest links carry "id:extra:...": the command takes the leading number only.
    return string.match(data, "^(%d+)")
  elseif kind == "xyz" then
    if string.match(data, "^[%d%.%- ]+$") then
      return data
    end
  elseif kind == "name" then
    -- One word: a tele name, never extra arguments such as ".tele name <player> <location>".
    if string.match(data, "^[%w_%-%.']+$") then
      return data
    end
  end
  return nil
end

StaticPopupDialogs["DCGM_CONFIRM_LINK_COMMAND"] = {
  text = "Run this GM command?\n\n%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(self, data)
    if type(data) == "string" then
      SendChatMessage(data, "SAY")
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

local function Notify(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[DC-GM]|r " .. message)
  end
end

-- chatFrame must be forwarded: stock channel links (right-click "[Guild]" ->
-- Move to New Window) use it as the frame to remove the channel from.
function MangLinkifier_SetItemRef(link, text, button, chatFrame)
  local linkType, data = string.match(link or "", "^([^:]+):?(.*)$")
  local action = linkType and LINK_ACTIONS[linkType]
  if not action then
    return MangLinkifier_SetItemRef_Original(link, text, button, chatFrame)
  end

  if not knownLinks[link] then
    -- Posted by a player (any link type can be typed into chat), or older than the link memory.
    Notify("Ignored a " .. linkType .. " link that did not come from server output.")
    return
  end

  local argument = BuildArgument(action[2], data or "")
  if not argument then
    Notify("Ignored a " .. linkType .. " link with an unexpected argument.")
    return
  end

  local command = action[1] .. argument
  if not action[3] then
    SendChatMessage(command, "SAY")
    return
  end

  local dialog = StaticPopup_Show("DCGM_CONFIRM_LINK_COMMAND", (string.gsub(command, "|", "||")), nil, command)
  if dialog then
    dialog.data = command
  end
end
