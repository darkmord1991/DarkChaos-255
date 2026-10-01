--[[
	DC-Talents - client of the TLNT server module (src/server/scripts/DC/AddonExtension/dc_addon_talents.cpp).

	  CMSG 0x01 HELLO {}                                  -> SMSG 0x11 {v, enabled, freeRespec, pet, max}
	  CMSG 0x02 APPLY_BUILD {req, spec, t = {{id, r}}}     -> SMSG 0x12 {req, ok, code, msg, spent, failed}
	  CMSG 0x03 APPLY_PET_BUILD {req, t = {{id, r}}}       -> SMSG 0x13 (same shape)

	The server resets and relearns a whole build in one step (free, out of combat), so the retail
	talent frame can refund learned talents and switch loadouts. SMSG_TALENTS_INFO always reaches
	the client before the result. A server without the module never answers HELLO: after a timeout
	the port falls back to the stock rules (talents can only be added, through the 3.3.5
	preview-talent path).
]]

local _, ns = ...
setfenv(1, ns.env)

local G = ns.realG

local Server = {}
ns.Server = Server

local MODULE = "TLNT"
local CMSG_HELLO = 0x01
local CMSG_APPLY_BUILD = 0x02
local CMSG_APPLY_PET_BUILD = 0x03
local SMSG_HELLO = 0x11
local SMSG_APPLY_RESULT = 0x12
local SMSG_APPLY_PET_RESULT = 0x13

local HELLO_TIMEOUT = 15
local APPLY_TIMEOUT = 10
local CHAT_FILTER_GRACE = 3

local state = {
	hello = nil,
	helloPending = false,
	nextRequest = 1,
	pending = {},
	filterUntil = 0,
}
Server.state = state

local function Protocol()
	local DC = rawget(G, "DCAddonProtocol")
	if DC and DC.Request and DC.RegisterHandler then
		return DC
	end
	return nil
end

function Server.IsAvailable()
	return state.hello ~= nil and state.hello.enabled ~= false
end

function Server.SupportsFreeRespec()
	return Server.IsAvailable() and state.hello.freeRespec == true
end

function Server.SupportsPetBuilds()
	return Server.IsAvailable() and state.hello.pet == true
end

function Server.SendHello()
	local DC = Protocol()
	if not DC or state.helloPending then
		return
	end
	state.helloPending = true
	DC:Request(MODULE, CMSG_HELLO, {})
	G.C_Timer.After(HELLO_TIMEOUT, function()
		state.helloPending = false
	end)
end

local function Finish(request, ok, message, data)
	local pending = state.pending[request]
	if not pending then
		return
	end
	state.pending[request] = nil
	state.filterUntil = G.GetTime() + CHAT_FILTER_GRACE
	if pending.callback then
		ns.SafeCall(pending.callback, ok, message, data)
	end
end

-- Sends a full target build. `ranks` = { [talentID] = rank }; talents not listed go to rank 0.
function Server.ApplyBuild(config, ranks, callback)
	local DC = Protocol()
	if not DC or not Server.IsAvailable() then
		return false
	end
	if config.isPet and not Server.SupportsPetBuilds() then
		return false
	end

	local list = {}
	for talentID, rank in pairs(ranks) do
		if rank > 0 then
			list[#list + 1] = { id = talentID, r = rank }
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)

	local request = state.nextRequest
	state.nextRequest = request + 1
	state.pending[request] = { callback = callback, started = G.GetTime() }
	state.filterUntil = G.GetTime() + APPLY_TIMEOUT

	if config.isPet then
		DC:Request(MODULE, CMSG_APPLY_PET_BUILD, { req = request, t = list })
	else
		DC:Request(MODULE, CMSG_APPLY_BUILD, { req = request, spec = config.group, t = list })
	end

	G.C_Timer.After(APPLY_TIMEOUT, function()
		if state.pending[request] then
			Finish(request, false, ns.L and ns.L.ERR_SERVER_TIMEOUT or "The server did not answer.")
		end
	end)
	return true
end

local function OnHello(data)
	if type(data) ~= "table" then
		return
	end
	state.helloPending = false
	state.hello = data
	if ns.OnServerCapabilitiesChanged then
		ns.SafeCall(ns.OnServerCapabilitiesChanged)
	end
end

local function OnApplyResult(data)
	if type(data) ~= "table" then
		return
	end
	local ok = data.ok == true
	local message = data.msg
	if not ok and (not message or message == "") then
		message = data.code
	end
	Finish(tonumber(data.req) or 0, ok, message, data)
end

-- The reset path unlearns and relearns every talent spell; the client prints a chat line for each.
-- Swallow those while an apply is in flight (and a moment after), keep everything else.
local learnPatterns
local function BuildLearnPatterns()
	learnPatterns = {}
	for _, key in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S", "ERR_SPELL_UNLEARNED_S" }) do
		local format = G[key]
		if type(format) == "string" then
			local pattern = "^" .. format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$"
			learnPatterns[#learnPatterns + 1] = pattern
		end
	end
end

local function LearnSpamFilter(self, event, message, ...)
	if G.GetTime() > state.filterUntil or type(message) ~= "string" then
		return false
	end
	if not learnPatterns then
		BuildLearnPatterns()
	end
	for _, pattern in ipairs(learnPatterns) do
		if message:find(pattern) then
			return true
		end
	end
	return false
end

function Server.Initialize()
	local DC = Protocol()
	if not DC then
		return
	end
	DC:RegisterHandler(MODULE, SMSG_HELLO, OnHello)
	DC:RegisterHandler(MODULE, SMSG_APPLY_RESULT, OnApplyResult)
	DC:RegisterHandler(MODULE, SMSG_APPLY_PET_RESULT, OnApplyResult)
	if G.ChatFrame_AddMessageEventFilter then
		G.ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", LearnSpamFilter)
	end
end
