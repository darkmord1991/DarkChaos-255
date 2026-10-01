--[[
	Shared helpers for the DC-Talents tests: assertions, error tracking and the standard boot
	(DCCompat, DC-Journal's shared metatable patches, DC-Talents, the start-up events).
]]

local T = {}

T.verbose = arg and arg[1] == "-v"
SIM.printErrors = T.verbose

-- print() is the client's (it writes to the chat frame); test output goes to stdout.
function T.out(text)
	io.stdout:write(tostring(text) .. "\n")
end

T.pass, T.fail = 0, 0

function T.ok(condition, message)
	if condition then
		T.pass = T.pass + 1
		if T.verbose then
			T.out("  PASS " .. message)
		end
	else
		T.fail = T.fail + 1
		T.out("  FAIL " .. message)
	end
	return condition
end

function T.section(title)
	T.out("== " .. title .. " ==")
end

local errorCursor = 0

-- Every error since the last check fails the check and is printed once.
function T.noNewErrors(label)
	local new = {}
	for i = errorCursor + 1, #SIM.errors do
		new[#new + 1] = SIM.errors[i]
	end
	errorCursor = #SIM.errors
	for i = 1, math.min(#new, 5) do
		T.out("    " .. new[i]:gsub("\n", "\n    "))
	end
	if #new > 5 then
		T.out(("    ... and %d more"):format(#new - 5))
	end
	return T.ok(#new == 0, label .. " (no Lua errors)")
end

-- DC-AddonProtocol's compat layer, DC-Journal's shared metatable patches (as in game: both load
-- before DC-Talents), then DC-Talents in TOC order and the log-in events.
function T.Boot()
	SIM.LoadFile(SIM.ADDONS_DIR .. "DC-AddonProtocol/DCCompat.lua", "DC-AddonProtocol", {})
	SIM.client.loadedAddons["DC-AddonProtocol"] = true
	S_ATLAS_STORAGE = {}
	SIM.LoadFile(SIM.ADDONS_DIR .. "DC-Journal/Interface/SharedXML/SharedExtendedMethods.lua", "DC-Journal", {})
	local ns = SIM.LoadAddon("DC-Talents")
	SIM.FireEvent("ADDON_LOADED", "DC-Talents")
	SIM.FireEvent("VARIABLES_LOADED")
	SIM.FireEvent("PLAYER_LOGIN")
	SIM.FireEvent("PLAYER_ENTERING_WORLD")
	SIM.Run(1)
	return ns
end

function T.Finish()
	T.out(("RESULT %d passed, %d failed, %d warnings"):format(T.pass, T.fail, #SIM.warnings))
	if T.verbose then
		for _, warning in ipairs(SIM.warnings) do
			T.out("  WARN " .. warning)
		end
	end
	os.exit(T.fail == 0 and 0 or 1)
end

return T
