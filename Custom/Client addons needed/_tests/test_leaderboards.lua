-- DC-Leaderboards (DC-Leaderboards/DC-Leaderboards.lua) driven through its real
-- protocol handlers with server-shaped payloads. Pins that the Achievements
-- board is requested as the account-wide board (legacy "achieve_progress"
-- deep links included), that "Your rank" comes from the page and shows
-- nothing -- not "#0" -- for a player who is not on the board, that the
-- player's own row and their alts are highlighted from the server's flags
-- rather than by name, that win rates are divided back from x10 for duels as
-- well as HLBG, that large values arrive in full (score_str) and ranks are
-- coloured by rank rather than by row, that the "Show bots" / "One per
-- account" toggles travel with every request and file replies under their own
-- cache key, that the refresh acknowledgement is not mistaken for a board,
-- that the info column is only narrow beside the AOE quality columns, that
-- all 16 Mythic+ dungeons are selectable, and that the Character Overview
-- asks for each rank once.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

_G.unpack = _G.unpack or table.unpack
_G.tinsert = table.insert
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.PlaySound = function() end
_G.InterfaceOptions_AddCategory = function() end
_G.InterfaceOptionsFrame_OpenToCategory = function() end
_G.UIDropDownMenu_SetWidth = function() end
_G.UIDropDownMenu_Initialize = function() end
_G.UIDropDownMenu_SetText = function() end
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function() end

local playerName = "Darkmord"
_G.UnitName = function() return playerName end

local clock = 1000000
_G.time = function() return clock end

-- Named template frames expose <name>Text / Low / High children, and
-- GetName() returns the real name (the simulator answers "stub").
local allFrames = {}
local realCreateFrame = CreateFrame
_G.CreateFrame = function(ftype, name, parent, template)
    local f = realCreateFrame(ftype, name, parent, template)
    allFrames[#allFrames + 1] = f
    if name then
        f.GetName = function() return name end
        _G[name] = f
        if template then
            for _, suffix in ipairs({ "Text", "Low", "High" }) do
                _G[name .. suffix] = f:CreateFontString()
            end
        end
    end
    return f
end

_G.UIParent = CreateFrame("Frame")
_G.GameTooltip = CreateFrame("GameTooltip")

-- Font strings record their width so the info column can be checked.
local probe = CreateFrame("Frame"):CreateTexture()
getmetatable(probe).__index.SetWidth = function(self, w) self._width = w end

-- DCAddonProtocol: record requests, keep the handlers the addon registers.
local sent = {}
local handlers = {}
_G.DCAddonProtocol = {
    Module = {},
    Request = function(_, module, opcode, payload)
        table.insert(sent, { module = module, opcode = opcode, payload = payload })
    end,
    RegisterHandler = function(_, module, opcode, fn)
        handlers[module .. "_" .. opcode] = fn
    end,
    DebugPrint = function() end,
}

local CMSG_GET_LEADERBOARD, CMSG_GET_MY_RANK, CMSG_REFRESH = 0x01, 0x03, 0x04
local SMSG_LEADERBOARD_DATA, SMSG_MY_RANK = 0x10, 0x12

local function requests(opcode)
    local out = {}
    for _, r in ipairs(sent) do
        if r.module == "LBRD" and r.opcode == opcode then
            table.insert(out, r.payload)
        end
    end
    return out
end
local function lastRequest(opcode)
    local list = requests(opcode)
    return list[#list]
end
local function reply(opcode, payload) handlers["LBRD_" .. opcode](payload) end

dofile(ROOT .. [[DC-Leaderboards\DC-Leaderboards.lua]])
for _, f in ipairs(allFrames) do
    if f._scripts.OnEvent then f._scripts.OnEvent(f, "PLAYER_LOGIN") end
end

local LB = DCLeaderboards
print("Leaderboards")

-- A v1.5 server page.
local function page(category, subcategory, entries, extra)
    local data = {
        category = category, subcategory = subcategory,
        page = 1, totalPages = 1, totalEntries = #entries,
        accountScoped = false, includeBots = false, perAccount = false, myRunsOnly = false,
        myRank = 0, myScore = 0,
        entries = entries,
    }
    for k, v in pairs(extra or {}) do data[k] = v end
    return data
end
local function row(i) return LB.entryPool[i] end

-- 1. Achievements: the account-wide board.
LB:Show()
sent = {}
LB:SelectCategory("achieve")
local req = lastRequest(CMSG_GET_LEADERBOARD)
ok(req and req.category == "achieve" and req.subcategory == "achieve_points",
    "Achievements opens on Achievement Points")
ok(req.includeBots == false and req.perAccount == false, "the view flags travel with the request (bots hidden by default)")
ok(#requests(CMSG_GET_LEADERBOARD) == 1, "opening a category sends its first request once")
ok(#requests(CMSG_GET_MY_RANK) == 0, "no separate my-rank request: the page carries it")
ok(LB.noDataText and LB.noDataText:GetText():find("Loading", 1, true) ~= nil,
    "the new board shows a loading state instead of the previous board's rows")
ok(not LB.Frames.perAccountToggle:IsEnabled() and LB.Frames.perAccountToggle:GetChecked(),
    "One per account is shown ticked and locked on the account-wide board")

reply(SMSG_LEADERBOARD_DATA, page("achieve", "achieve_points", {
    { rank = 1, name = "Tybeyz", class = "DEATHKNIGHT", score = 1549, extra = "80 done, 10 chars" },
    { rank = 2, name = "Darkmord", class = "ROGUE", score = 1523, extra = "108 done, 22 chars", self = true },
    { rank = 3, name = "Egreg", class = "DRUID", score = 730, extra = "70 done, 3 chars" },
}, { accountScoped = true, myRank = 2, myScore = 1523 }))

ok(row(1).score:GetText() == "1,549" and row(2).score:GetText() == "1,523",
    "scores are exact (1,523 and 1,549 do not both read 1.5K)")
ok(LB.Frames.myRank:GetText():find("Your account: |cff00ff00#2|r (top 66.7%)", 1, true) ~= nil,
    "the page's own rank shows as the account's rank")
ok(LB.Frames.totalPlayers:GetText():find("accounts", 1, true) ~= nil, "the footer counts accounts")
ok(LB.Frames.nameHeader:GetText():find("Account (main)", 1, true) ~= nil,
    "the name column says it lists each account's main character")
local bgSelf = row(2).bg._tex
ok(bgSelf and bgSelf[1] == 0.2 and bgSelf[2] == 0.4, "the player's account row is highlighted")

-- Highlighting follows the server's flags, not the character name.
playerName = "SomeAlt"
LB:UpdateLeaderboardDisplay()
bgSelf = row(2).bg._tex
ok(bgSelf and bgSelf[1] == 0.2 and bgSelf[2] == 0.4,
    "an alt on the same account still sees its account highlighted (flag, not name)")
playerName = "Darkmord"

-- Legacy deep link (DC-Welcome used achieve_progress).
sent = {}
LB:SelectCategory("mplus")
sent = {}
LB:SelectSubCategory("achieve_progress")
ok(LB.currentCategory == "achieve" and LB.currentSubCategory == "achieve_points",
    "a legacy achieve_progress link opens Achievement Points")
ok(#requests(CMSG_GET_LEADERBOARD) == 0, "...served from cache, nothing re-requested")

-- 2. Not on the board: "--", never "#0".
LB:SelectCategory("seasons")
reply(SMSG_LEADERBOARD_DATA, page("seasons", "season_tokens", {
    { rank = 1, name = "Adaafaafasdf", class = "DRUID", score = 1000, extra = "0 quests", alt = true },
}, { myRank = 0 }))
ok(LB.Frames.myRank:GetText() == "Your rank: |cffffffff--|r", "rank 0 shows as -- rather than #0")
local bgAlt = row(1).bg._tex
ok(bgAlt and bgAlt[1] == 0.15 and bgAlt[2] == 0.25, "another character on the player's account gets the alt highlight")
ok(LB.Frames.perAccountToggle:IsEnabled(), "One per account is available on a character board")
ok(LB.Frames.nameHeader:GetText():find("Player", 1, true) ~= nil, "character boards keep the Player column")

-- 3. View toggles: carried by the request, cached per view.
sent = {}
LB.Frames.showBotsToggle:SetChecked(1)
LB.Frames.showBotsToggle._scripts.OnClick(LB.Frames.showBotsToggle)
req = lastRequest(CMSG_GET_LEADERBOARD)
ok(req and req.includeBots == true and req.subcategory == "season_tokens", "ticking Show bots re-requests with includeBots")
reply(SMSG_LEADERBOARD_DATA, page("seasons", "season_tokens", {
    { rank = 1, name = "BOT Tybeyz", class = "DEATHKNIGHT", score = 5000, bot = true, extra = "" },
    { rank = 2, name = "Adaafaafasdf", class = "DRUID", score = 1000, alt = true, extra = "" },
}, { includeBots = true }))
ok(row(1).name:GetText():find("BOT Tybeyz", 1, true) ~= nil, "the bot view lists bots")
sent = {}
LB.Frames.showBotsToggle:SetChecked(nil)
LB.Frames.showBotsToggle._scripts.OnClick(LB.Frames.showBotsToggle)
ok(#requests(CMSG_GET_LEADERBOARD) == 0, "switching back uses the cached bot-free board")
ok(row(1).name:GetText():find("Adaafaafasdf", 1, true) ~= nil, "...and shows it")

-- A reply is filed under the view it was requested for, even if the
-- toggle moved while it was in flight.
LB:SetSetting("perAccount", true)
reply(SMSG_LEADERBOARD_DATA, page("seasons", "season_essence", {
    { rank = 1, name = "X", class = "MAGE", score = 1, extra = "" },
}, { perAccount = false }))
ok(LB.Cache.data["seasons_season_essence"] ~= nil and LB.Cache.data["seasons_season_essence_acct"] == nil,
    "a reply lands under its echoed view")
LB:SetSetting("perAccount", false)

-- 4. The refresh acknowledgement is not a board.
local before = LB.Cache.data["seasons_season_tokens"]
reply(SMSG_LEADERBOARD_DATA, { refreshed = true })
ok(LB.Cache.data["unknown_unknown"] == nil and LB.Cache.data["seasons_season_tokens"] == before,
    "the refresh ack neither creates a board nor clears the shown one")

-- 5. Duels: win rate x10 for duels too, damage in full.
LB:SelectCategory("duel")
LB:SelectSubCategory("duel_winrate")
reply(SMSG_LEADERBOARD_DATA, page("duel", "duel_winrate", {
    { rank = 1, name = "A", class = "WARRIOR", score = 655, extra = "20 duels" },
}))
ok(row(1).score:GetText() == "65.5%", "a 65.5% duel win rate is not shown as 655%")
LB:SelectSubCategory("duel_damage")
reply(SMSG_LEADERBOARD_DATA, page("duel", "duel_damage", {
    { rank = 1, name = "A", class = "WARRIOR", score = 0, score_str = "1234567", extra = "3 wins" },
}))
ok(row(1).score:GetText() == "1.23M", "duel damage arrives in full and is abbreviated client-side")

-- 6. Page 2: rank 26 is not coloured gold.
LB:SelectCategory("upgrade")
local entries = {}
for i = 1, 3 do entries[i] = { rank = 25 + i, name = "P" .. i, class = "MAGE", score = 10, extra = "" } end
reply(SMSG_LEADERBOARD_DATA, page("upgrade", "upgrade_tokens", entries, { page = 2, totalPages = 2, totalEntries = 28 }))
ok(row(1).rank:GetText() == "26", "rank 26 on page 2 is plain, not gold")
ok(LB.Frames.pageInfo:GetText() == "Page 2 / 2", "paging comes from this board's reply")
ok(row(1).extra._width == 185, "the info column is full width outside the AOE quality view")

-- 7. AOE item view narrows the info column for the quality columns.
LB:SelectCategory("aoe")
reply(SMSG_LEADERBOARD_DATA, page("aoe", "aoe_items", {
    { rank = 1, name = "Darkmord", class = "ROGUE", score = 105, extra = "50 / 29", self = true,
      qLeg = 0, qEpic = 6, qRare = 3, qUncommon = 0 },
}))
ok(row(1).extra._width == 68 and row(1).qEpic:GetText():find("6", 1, true) ~= nil,
    "the AOE item view narrows the info column beside L/E/R/U")

-- 8. Categories: Prestige and Artifact Mastery are separate.
local prestige, mastery = LB:GetCategory("prestige"), LB:GetCategory("mastery")
ok(prestige.name == "Prestige" and prestige.subcats[1].id == "prestige_level", "Prestige is its own category")
ok(mastery and mastery.name == "Artifact Mastery" and mastery.subcats[1].id == "mastery_points",
    "Artifact Mastery has its own category")
sent = {}
LB:SelectCategory("mplus")
sent = {}
LB:SelectSubCategory("prestige_points")
ok(LB.currentCategory == "prestige" and LB.currentSubCategory == "prestige_points",
    "a deep link to Prestige XP switches category")
ok(#requests(CMSG_GET_LEADERBOARD) == 2, "...requesting the category's first tab and the linked one")

LB:Show("seasonal")
ok(LB.currentCategory == "seasons", "Show(\"seasonal\") (DC-InfoBar) opens Seasons")

-- 9. All 16 featured dungeons are selectable.
LB:SelectCategory("mplus")
local dungeons = {}
for i = 1, 16 do dungeons[i] = { mapId = 573 + i, name = "Dungeon " .. i } end
handlers["LBRD_" .. 0x17]({ seasonId = 1, dungeons = dungeons })
LB:UpdateDungeonDropdownItems()
local items = {}
for _, child in ipairs(LB.Frames.dungeonDropdown._children) do
    if child._scripts.OnClick then items[#items + 1] = child end
end
ok(#items >= 17, "the dungeon filter lists All Dungeons plus all 16 dungeons")
sent = {}
items[#items]._scripts.OnClick(items[#items])
req = lastRequest(CMSG_GET_LEADERBOARD)
ok(req and req.subcategory == "mplus_dungeon_589", "picking the last dungeon requests its own board")
ok(#requests(CMSG_REFRESH) == 0, "a dungeon pick does not flush the server's caches")
LB:SelectSubCategory("mplus_runs")
ok(LB.SelectedDungeonMapId == 0 and LB.Frames.dungeonText:GetText():find("All Dungeons", 1, true) ~= nil,
    "choosing a regular tab resets the dungeon filter label")

-- 10. Character Overview: one rank request per board, redrawn on reply.
-- Boards whose pages were already received carry the rank; only the rest are asked.
local boards, unknown = 0, 0
for _, cat in ipairs(LB.Categories) do
    if cat.id ~= "statistics" then
        for _, sub in ipairs(cat.subcats) do
            if sub.id ~= "mplus_history" then
                boards = boards + 1
                if not LB.Cache.myRanks[LB:GetCacheKey(cat.id, sub.id)] then unknown = unknown + 1 end
            end
        end
    end
end
sent = {}
LB:SelectCategory("statistics")
local asked = #requests(CMSG_GET_MY_RANK)
ok(unknown < boards, "ranks carried by pages already received are reused")
ok(asked == unknown, "every other board's rank is asked for once (" .. asked .. "/" .. unknown .. "), history excluded")
LB:UpdateStatisticsDisplay()
ok(#requests(CMSG_GET_MY_RANK) == asked, "redrawing does not ask again while replies are pending")

reply(SMSG_MY_RANK, { category = "hlbg", subcategory = "hlbg_winrate", rank = 3, total = 12, score = 750,
    includeBots = false, perAccount = false })
reply(SMSG_MY_RANK, { category = "seasons", subcategory = "season_quests", rank = 0, total = 40, score = 0,
    includeBots = false, perAccount = false })
advance(0.3)
local winrateRow, questsRow
for _, e in ipairs(LB.statsEntryPool) do
    if e.subName:GetText() == "Win Rate %" then winrateRow = e end
    if e.subName:GetText() == "Quests Completed" then questsRow = e end
end
ok(winrateRow and winrateRow.rank:GetText() == "#3" and winrateRow.score:GetText() == "75.0%",
    "a rank reply redraws the overview with the formatted score")
ok(questsRow and questsRow.rank:GetText() == "-", "not being on a board shows -")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
