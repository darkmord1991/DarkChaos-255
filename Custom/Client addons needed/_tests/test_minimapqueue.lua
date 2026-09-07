-- DC-MythicPlus minimap queue eye: the blizzlike "you are queued" indicator.
-- Drives UI/MatchmakingQueue.lua's real handlers (the server messages the
-- client actually receives) and asserts the eye follows the queue through
-- join -> status -> ready check -> leave, including the /reload path where the
-- finder window does not exist yet.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

_G.UIParent = CreateFrame("Frame")
_G.Minimap = CreateFrame("Frame")
_G.GameTooltip = CreateFrame("Frame")
_G.GameTooltip.lines = {}
function _G.GameTooltip:SetText(t) self.lines = { t } end
function _G.GameTooltip:AddLine(t) table.insert(self.lines, t) end
function _G.GameTooltip:SetOwner() end
function _G.GameTooltip:Show() end
function _G.GameTooltip:Hide() end
function _G.GameTooltip:Text() return table.concat(self.lines, "\n") end

_G.UnitName = function() return "Tester" end
_G.UnitLevel = function() return 80 end
_G.GetRealmName = function() return "DC" end
_G.GetCursorPosition = function() return 0, 0 end
_G.tinsert, _G.tremove = table.insert, table.remove
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.SLASH_DCQUEUE1 = nil
_G.C_Timer = { After = function() end }
_G.PlaySound = function() end
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function(info) table.insert(_G._menu, info) end
_G.UIDropDownMenu_Initialize = function(_, fn) _G._menu = {}; fn(nil, 1) end
_G.ToggleDropDownMenu = function() end

-- MatchmakingQueue.lua is loaded on its own: GroupFinderFrame.lua drags in the
-- whole retail-styled window, and every hook the queue needs from it is
-- guarded. The two fields it reads without a guard are stubbed here.
local namespace = { GroupFinder = {} }
_G.DCMythicPlusHUD = namespace
namespace.GroupFinder.DUNGEON_DIFFICULTY_LABELS = { [0]="Normal", [1]="Heroic", [2]="Mythic" }
namespace.GroupFinder.SetStatusMessage = function(self, m) self._msg = m end
namespace.GroupFinder.Show = function() end
namespace.GroupFinder.Toggle = function() _G._toggled = true end

dofile(ROOT..[[DC-MythicPlus\UI\MatchmakingQueue.lua]])
dofile(ROOT..[[DC-MythicPlus\UI\MinimapQueue.lua]])

local GF = namespace.GroupFinder

print("MinimapQueue")

-- 1. Nothing on screen before a queue exists.
GF:UpdateMinimapQueueEye()
ok(GF.minimapQueueEye == nil, "no eye is created while not queued")

-- 2. SMSG_QUEUE_JOINED brings the eye up even though the finder window --
--    and therefore GF.compactListFrame -- was never created.
GF:OnQueueJoined({ category = 1 })
local eye = GF.minimapQueueEye
ok(eye ~= nil and eye:IsShown(), "eye appears on SMSG_QUEUE_JOINED")
ok(GF.queueStatusFrame == nil, "in-window queue panel stays uncreated without the finder")

-- 3. The searching flipbook advances on its own.
local tick = eye:GetScript("OnUpdate")
ok(type(tick) == "function", "eye runs an OnUpdate animation")
tick(eye, 0.2)
ok((eye._frame or 0) > 0, "LFG-Eye flipbook advances while searching")

-- 4. A status push fills the tooltip with the role tally and the ETAs.
GF._queueLabel = "Random Heroic Dungeon"
GF:OnQueueStatus({ queued = true, category = 1, waitSeconds = 65,
    tanks = 1, healers = 2, dps = 9, total = 12,
    waitAvg = 130, waitTank = 20, waitHealer = 60, waitDps = 310 })
GF:ShowMinimapQueueTooltip(eye)
local tip = GameTooltip:Text()
ok(tip:find("Dungeon Finder", 1, true) ~= nil, "tooltip titled Dungeon Finder")
ok(tip:find("Random Heroic Dungeon", 1, true) ~= nil, "tooltip names what was queued for")
ok(tip:find("Time in Queue: 1:05", 1, true) ~= nil, "tooltip shows the server-synced wait")
ok(tip:find("1 Tanks  2 Healers  9 DPS", 1, true) ~= nil, "tooltip shows the role tally")
ok(tip:find("Average Wait: 2:10", 1, true) ~= nil, "tooltip shows the average wait")

-- 5. A raid queue relabels the whole indicator.
GF._queueCategory = 2
ok(GF:MinimapQueueTitle() == "Raid Finder", "raid queue retitles the eye")
GF._queueCategory = 1

-- 6. Ready check: the eye freezes, badges, and pulses instead of spinning.
GF:OnQueueProposal({ proposalId = 7, role = "Tank", size = 5, accepted = 2, timeout = 40 })
ok(GF._proposalActive == true, "proposal marks the eye state")
ok(eye.mark:IsShown(), "ready-check badge shown on the eye")
local frozen = eye._frame
tick = eye:GetScript("OnUpdate")
tick(eye, 0.5)
ok(eye._frame == frozen, "flipbook freezes while a ready check is out")
GF:OnQueueProposalUpdate({ accepted = 4, total = 5 })
GF:ShowMinimapQueueTooltip(eye)
tip = GameTooltip:Text()
ok(tip:find("Group Found!", 1, true) ~= nil, "tooltip announces the match")
ok(tip:find("4 of 5 players have accepted", 1, true) ~= nil, "tooltip counts acceptances")

-- 7. Right-click menu offers the ready check back plus the queue actions.
eye:GetScript("OnClick")(eye, "RightButton")
local labels = {}
for _, info in ipairs(_G._menu) do labels[info.text] = true end
ok(labels["Leave Queue"], "menu offers Leave Queue")
ok(labels["Show Ready Check"], "menu offers the ready check while one is out")

-- 8. Accepting keeps the eye up (still waiting on the others).
GF:RespondToQueueProposal(true)
ok(eye:IsShown() and GF._proposalAccepted == true, "eye stays up after accepting")

-- 9. A cancelled proposal that requeues drops back to searching.
GF:OnQueueProposalFailed({ reason = "Someone declined.", requeued = true })
ok(GF._proposalActive == nil and not eye.mark:IsShown(), "badge clears when the match falls apart")
ok(eye:IsShown(), "eye keeps spinning while still queued")

-- 10. Leaving takes the eye away.
GF:OnQueueLeft({ matched = false })
ok(not eye:IsShown(), "eye disappears when the queue ends")
ok(GF.queueInProgress == false, "queue state cleared")

-- 11. /reload path: the label is restored from SavedVariables when the server
--     says this character is still queued.
DCMythicPlusHUDDB.minimapQueue.label = "Halls of Lightning (Heroic)"
DCMythicPlusHUDDB.minimapQueue.charKey = "Tester-DC"
GF._queueLabel = nil
GF:OnQueueStatus({ queued = true, category = 1, waitSeconds = 300,
    tanks = 0, healers = 0, dps = 3, total = 3, waitAvg = -1 })
ok(eye:IsShown(), "eye comes back after a reload while queued")
ok(GF._queueLabel == "Halls of Lightning (Heroic)", "queue label survives the reload")

-- 12. A {queued:false} status (the usual login reply) leaves nothing behind.
GF:OnQueueStatus({ queued = false })
ok(not eye:IsShown(), "login status with no queue hides the eye")
ok(DCMythicPlusHUDDB.minimapQueue.label == nil, "stale saved label is dropped")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
