--[[
	DC-Talents - private environment for the retail port.

	Every file of this addon starts with `setfenv(1, ns.env)`. Retail FrameXML defines its mixins and
	utilities (TableUtil, CreateFramePool, CallbackRegistryMixin, ...) as globals; running the vendored
	retail files inside this environment keeps all of that out of _G:

	  * other addons never see our copies (DC-Journal ships Sirus' 8.x SharedXML with the same names
	    but different semantics, and whichever loaded second would win), and
	  * our copies never see theirs.

	Lookups go env -> ns.compat (DC implementations that must win over _G, e.g. Mixin, CreateFrame,
	C_Traits) -> _G. Writes land in env. Named frames still become real globals because the engine
	registers them, and mutations of shared tables (StaticPopupDialogs, UIPanelWindows) still reach _G.
]]

local addonName, ns = ...

ns.name = addonName
ns.realG = _G

local compat = setmetatable({}, { __index = _G })
local env = setmetatable({}, { __index = compat })
env._G = env

ns.compat = compat
ns.env = env

-- Debug helper: /run DCTalentsEnv().TalentFrameBaseMixin
_G.DCTalentsEnv = function()
	return env
end

-- Errors inside retail callbacks must reach the error handler without aborting the caller
-- (the retail engine behaves the same way for script handlers).
function ns.SafeCall(func, ...)
	local ok, err = pcall(func, ...)
	if not ok then
		local handler = geterrorhandler and geterrorhandler()
		if handler then
			handler(err)
		end
	end
	return ok
end
