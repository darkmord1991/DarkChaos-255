--[[----------------------------------------------------------------------------------------------
DCGlueCamera.lua -- Ascension-style camera framing for the glue screens (create + select).

What it does:
  * CREATE: the character is shown larger than stock (a constant "body" dolly toward the camera),
    and customizing face/hair/facial features eases the camera in to a head-and-shoulders framing;
    touching the skin axis (or changing race/gender) eases back out to the full body.
  * SELECT: every character is shown larger via a constant dolly, re-applied after each selection
    (SetBackgroundModel may rebuild the scene).

How it works -- everything rides on facts the 2026-08-07 spike proved in-client:
  * CharacterCreate / CharacterSelect are ModelFFX frames; :SetPosition(a1, a2, a3) MOVES the
    natively-placed character (S0-4). :SetModelScale is a no-op, so a dolly is the only zoom.
  * The native scene update re-places the scene EVERY frame, stomping a one-shot SetPosition.
    Confirmed in-client 2026-08-11 (frame-by-frame video analysis): a tween renders correctly
    while the driver applies each tick, then snaps back within one frame of the tween ending.
    Re-asserting from an OnUpdateModel wrapper (after the stock handler) did NOT survive to the
    render either -- only an apply from the driver's OnUpdate demonstrably wins the frame order.
    So the driver below re-applies the current framing every tick while a screen is shown; that
    per-frame re-assert IS the mechanism, not an optimization.
  * What the spike did NOT settle is which SetPosition argument is "toward the camera". The guess
    (forwardArg = 1, i.e. x = depth) follows the in-game Model widget convention. If it is wrong
    the model shifts sideways or sinks instead of zooming: flip Config.forwardArg / upArg -- the
    tuning panel below (Config.tune = true) settles it in a single deploy.
  * Nothing here runs on its own at load beyond creating hidden frames (the ERROR #132 lesson from
    the spike: no probing, no cycling, no model moves until the player actually does something).

Face framing is per race/sex: the dolly magnifies around the camera's aim point (roughly chest
height), so the model is also lowered by (eye height - aim height) to keep the face centred.
Eye heights are estimates; refine with the tuning panel and edit EYE_HEIGHT.

Load order: after DCCharCustomize.lua (its functions are wrapped at install time), before
DCCharCreateUI/Layout (the layout calls DCGlueCamera.OnStageChanged). Select-screen hooks are
installed on the driver's first tick, by which point every GlueXML file has loaded regardless of
GlueXML.toc order.

Degradation: if SetPosition ever errors the module disables itself and the screens behave stock.
------------------------------------------------------------------------------------------------]]

DCGlueCamera = {}

DCGlueCamera.Config = {
	enabled = true,
	-- The in-screen tuning panel. OFF for normal play (2026-08-11, after 18 calibration rounds);
	-- flip to true and redeploy to resume framing work -- the per-race knobs live in FACE_TUNE.
	tune = false,

	duration = 0.35,          -- seconds for the ease between framings

	-- SetPosition argument mapping (see header). forward = toward the camera, up = screen-up.
	forwardArg = 1,
	sideArg = 2,
	upArg = 3,

	-- Scale calibrated in-client 2026-08-11 (v5 run, undead male): the glue camera sits far from
	-- the character, so 0.45 forward was a barely-visible zoom and 3.5 only moderate. These are
	-- the next iteration; refine with the tuner.
	-- Units are CHARACTER-model offsets since v9 (the char moves, the background stays).
	-- Framing is driven by DCGlueCameraData (cameras extracted OFFLINE from each UI_*.m2 -- the
	-- v11 runtime camera getter returned nil in glue, no world = no active camera):
	--   flat cameras (|fz|<0.2: orc/nightelf/tauren/scourge/dwarf/draenei/select) get analytic
	--   eyes-on-the-view-axis face framing -- cross-checked: the math reproduces the user-approved
	--   worgen forward value (3.99 vs 4.0) from pure M2 data;
	--   steep cameras (worgen/goblin/bloodelf family, high + pitched down) get the empirically
	--   approved constant formula -- the analytic vertical is provably wrong for them;
	--   no data (ui_human's camera track ends mid-flythrough) falls back likewise.
	faceSize = 0.9,           -- face zoom: angular size knob; distance = faceSize/tan(fov/2), so
	                          -- narrow-fov screens (worgen 0.75) dolly further than wide ones
	chestHeight = 1.1,        -- what the camera's aim target height means on the character
	faceLift = 0,             -- world-up bias; per-race trims live in FACE_TUNE instead
	faceForward = 3.0,        -- no-data fallback (human): forward offset
	aimHeight = 1.2,          -- no-data fallback: face height constant
	bodyFraction = 0.09,      -- body zoom fraction of camera distance, height-scaled per race so
	                          -- tauren does not crop while gnome still visibly zooms
	bodyForward = 0.45,       -- body fallback without camera data
	-- 1.0 was FAR too much in character units ("select was fine before") -- select zoom off.
	selectForward = 0,
	selectUp = 0,
}

-- Approximate eye heights in model units, [raceId] = { [0] = male, [1] = female }. Races not
-- listed fall back to DEFAULT_EYE -- the face framing is then merely a little high or low, never
-- broken. Extend as the custom races (12-21) get face-zoom testing.
local DEFAULT_EYE = 1.7
local EYE_HEIGHT = {
	[1]  = { [0] = 1.70, [1] = 1.55 },  -- Human
	[2]  = { [0] = 1.90, [1] = 1.75 },  -- Orc
	[3]  = { [0] = 1.25, [1] = 1.20 },  -- Dwarf
	[4]  = { [0] = 2.05, [1] = 1.90 },  -- Night Elf
	[5]  = { [0] = 1.60, [1] = 1.50 },  -- Scourge
	[6]  = { [0] = 2.40, [1] = 2.20 },  -- Tauren
	[7]  = { [0] = 0.95, [1] = 0.90 },  -- Gnome
	[8]  = { [0] = 2.00, [1] = 1.85 },  -- Troll
	[9]  = { [0] = 1.00, [1] = 0.95 },  -- Goblin
	[10] = { [0] = 1.80, [1] = 1.65 },  -- Blood Elf
	[11] = { [0] = 2.20, [1] = 2.00 },  -- Draenei
	[12] = { [0] = 2.10, [1] = 1.90 },  -- Worgen
}

-- Per-race face-framing trims on top of the analytic camera math, from in-client review
-- (2026-08-11): df = forward delta (zoom), dz = vertical delta (+up). The geometry gets every
-- race close; these encode taste and the residual scene quirks.
local FACE_TUNE = {
	[1]  = { dz = -0.60, dy = -0.35 },  -- Human: face left (round 3)
	[3]  = { dz = 0.25 },               -- Dwarf: lands at goblin's approved framing ratio
	[4]  = { dz = -0.15, dy = -0.25 },  -- Night Elf: slightly up + left (round 3)
	[6]  = { df = -0.80, dz = 0.50 },   -- Tauren: back off, up again (round 3)
	[7]  = { dz = 0.25 },               -- Gnome: shares the dwarf screen, same trim
	[8]  = { dz = -0.15 },              -- Troll: slightly up (round 3)
	[10] = { dz = -0.05 },              -- Blood Elf
	[11] = { df = -1.20, dz = 0.90 },   -- Draenei: was a giant dark blob = far too close;
	                                    -- back way off (round 3)
	[12] = { dz = 0.25 },               -- Worgen: up a bit (round 3)
	-- Scourge: pure analytic is the keeper.
	-- (The undead brightening during face zoom is scene lighting near the camera, not framing.)
}

local AXIS_SKIN = 1

local cfg = DCGlueCamera.Config

-- ---------------------------------------------------------------------------------- screen state

-- name -> { frame, cur = {a1,a2,a3}, goal = {a1,a2,a3}, tween = {from,to,start,duration} }
local screens = {}

local function GetScreen(name)
	local state = screens[name]
	if state then
		return state
	end
	local frame = _G[name]
	if not (frame and frame.SetPosition) then
		return nil
	end
	state = { frame = frame, cur = { 0, 0, 0 }, goal = { 0, 0, 0 }, tween = nil }
	screens[name] = state
	return state
end

-- Diagnostics, shown live by the tuning panel. A transient SetPosition failure must NOT kill the
-- module (an earlier build disabled itself on the first failure, which presents exactly like "the
-- zoom snaps back and never works again"); only a solid streak of failures disables it.
local stats = { applies = 0, failures = 0, modelFrames = 0, lastError = nil }
DCGlueCamera.Stats = stats

-- WXL native path: SetModelPositionOffset writes the offset below the client's per-frame scene
-- re-derivation, which is what made plain SetPosition a dead letter here (applies flowed at 60/s,
-- fail 0, and the render ignored every one -- proven in-client 2026-08-11). The offset persists
-- natively, so with it the per-tick re-assert is belt only. Falls back to SetPosition when the
-- DLL predates the native.
local nativeOffset = type(SetModelPositionOffset) == "function" and SetModelPositionOffset or nil
-- The correct native (v9): moves the glue CHARACTER model, which disassembly proved is a separate
-- object from the ModelFFX widget model every earlier mechanism was (wrongly) moving. Background
-- stays fixed, character zooms -- the Ascension look.
local nativeCharOffset = type(DCSetGlueCharOffset) == "function" and DCSetGlueCharOffset or nil

local function ScreenArg(state)
	return (state.frame == _G["CharacterSelect"]) and "select" or "create"
end

-- midTween applies skip the native's forced transform refresh (5th arg 0): the glue scene
-- rebuilds on its own cadence from the ANIMATED base position, and forcing extra rebuilds
-- between its frames made rapid tween steps visibly fight it ("applies then resets" flicker).
-- Final values (tween end, nudges, presets) do refresh so they show even if the scene is idle.
local function Apply(state, a1, a2, a3, midTween)
	if nativeCharOffset then
		local ok, ret = pcall(nativeCharOffset, ScreenArg(state), a1, a2, a3)
		if ok and ret == 1 then
			stats.applies = stats.applies + 1
			state.failStreak = 0
			stats.lastError = nil
			state.cur[1], state.cur[2], state.cur[3] = a1, a2, a3
			return
		end
		stats.failures = stats.failures + 1
		stats.lastError = ok and "char model not resolvable" or tostring(ret)
		state.failStreak = (state.failStreak or 0) + 1
		if state.failStreak >= 20 then
			cfg.enabled = false
		end
		return
	end
	if nativeOffset then
		local ok, ret = pcall(nativeOffset, state.frame, a1, a2, a3, midTween and 0 or 1)
		if ok and ret == 1 then
			stats.applies = stats.applies + 1
			state.failStreak = 0
			stats.lastError = nil
			state.cur[1], state.cur[2], state.cur[3] = a1, a2, a3
			return
		end
		stats.failures = stats.failures + 1
		stats.lastError = ok and "native offset rejected the frame" or tostring(ret)
		state.failStreak = (state.failStreak or 0) + 1
		if state.failStreak >= 20 then
			cfg.enabled = false
		end
		return
	end
	local ok, err = pcall(state.frame.SetPosition, state.frame, a1, a2, a3)
	if not ok then
		stats.failures = stats.failures + 1
		stats.lastError = tostring(err)
		-- Streaks are per screen: the other screen applying fine must not mask a broken one.
		state.failStreak = (state.failStreak or 0) + 1
		if state.failStreak >= 20 then
			cfg.enabled = false
		end
		return
	end
	stats.applies = stats.applies + 1
	state.failStreak = 0
	stats.lastError = nil
	state.cur[1], state.cur[2], state.cur[3] = a1, a2, a3
end

-- ---------------------------------------------------------------------------------- framings

local function Compose(forward, side, up)
	local args = { 0, 0, 0 }
	args[cfg.forwardArg] = forward
	args[cfg.sideArg] = side
	args[cfg.upArg] = up
	return args
end

-- Current background model per screen name, recorded by the SetBackgroundModel wrapper --
-- normalized to the lowercase basename ("ui_orc") DCGlueCameraData is keyed by.
local screenModel = {}

local function NormalizeModelName(path)
	if type(path) ~= "string" then
		return nil
	end
	local name = path:lower():gsub("%.mdx$", ""):gsub("%.m2$", "")
	return name:match("([^\\/]+)$")
end

--- Static camera data for a screen, or nil.
local function ScreenCamera(state)
	local data = DCGlueCameraData
	if not data then
		return nil
	end
	local name = state.frame:GetName()
	local model = screenModel[name]
	if not model then
		return nil
	end
	-- Stock passes bare race tags ("Scourge", "CharacterSelect" -- see GlueAmbienceTracks'
	-- strupper(currentModel) keys), while the extractor keys by m2 basename ("ui_scourge").
	return data[model] or data["ui_" .. model]
end

local function EyeHeight()
	-- Only meaningful (and only SAFE -- the stock fallback getters crash off-screen) while the
	-- create screen is up; everywhere else the default is fine.
	local create = _G["CharacterCreate"]
	if not (create and create:IsShown()) then
		return DEFAULT_EYE
	end
	local race, sex
	if DCCharCustomize and DCCharCustomize.RaceSex then
		race, sex = DCCharCustomize.RaceSex()
	end
	local eyes = race and EYE_HEIGHT[race]
	return (eyes and sex and eyes[sex]) or DEFAULT_EYE
end

local function BodyArgs(state)
	-- A fraction of THIS screen's camera distance, height-scaled CUBED: the stock cameras already
	-- frame tall races tightly (tauren cropped at even a linear-scaled dolly), so the allowance
	-- falls off hard with height. Clamped for the small races so gnomes do not rocket in.
	local scale = DEFAULT_EYE / EyeHeight()
	scale = math.min(scale * scale * scale, 1.6)
	local cam = state and ScreenCamera(state)
	if cam then
		return { cam.dh * cfg.bodyFraction * scale, 0, 0 }
	end
	return Compose(cfg.bodyForward * scale, 0, 0)
end

local function FaceArgs(state)
	local eye = EyeHeight()
	local race = DCCharCustomize and DCCharCustomize.RaceSex and select(1, DCCharCustomize.RaceSex())
	local tune = race and FACE_TUNE[race] or nil
	local df, dz = (tune and tune.df or 0), (tune and tune.dz or 0)
	-- Side trim: +y is screen-RIGHT for a camera looking down the -x axis (right-handed, z up),
	-- so "move the face left" entries carry negative dy.
	local dy = tune and tune.dy or 0
	local cam = state and ScreenCamera(state)
	if cam then
		-- Eyes on the camera's view axis, at an fov-normalized distance (equal face size on every
		-- screen). Vertical is anchored to the camera's TARGET height -- it aims at the character's
		-- chest -- which absorbs scenes whose scenery sits off-origin (nightelf, dwarf).
		-- Cross-check: reproduces the user-approved worgen framing (4.26/-1.18 vs 4.0/-1.05).
		local fx, fz = cam.th - cam.dh, cam.tz - cam.cz
		local len = math.sqrt(fx * fx + fz * fz)
		fx, fz = fx / len, fz / len
		local d = cfg.faceSize / math.tan(cam.fov * 0.5) - df
		local ex = cam.dh + fx * d
		local ez = cam.cz + fz * d
		return { ex, dy, (cfg.chestHeight + ez - cam.tz) - eye + cfg.faceLift + dz }
	end
	return Compose(cfg.faceForward + df, dy, -(eye - cfg.aimHeight) + dz)
end

local function SelectArgs()
	return Compose(cfg.selectForward, 0, cfg.selectUp)
end

-- ---------------------------------------------------------------------------------- tweening

local function Ease(t) -- easeInOutQuad
	if t < 0.5 then
		return 2 * t * t
	end
	return 1 - 2 * (1 - t) * (1 - t)
end

local function StartTween(state, target, instant)
	state.goal = target
	if instant or cfg.duration <= 0 then
		state.tween = nil
		Apply(state, target[1], target[2], target[3])
		return
	end
	state.tween = {
		from = { state.cur[1], state.cur[2], state.cur[3] },
		to = target,
		start = GetTime(),
		duration = cfg.duration,
	}
end

local function ProcessTween(state, now)
	local tween = state.tween
	if not tween then
		return
	end
	local t = (now - tween.start) / tween.duration
	if t >= 1 then
		state.tween = nil
		Apply(state, tween.to[1], tween.to[2], tween.to[3])
		return
	end
	local k = Ease(t)
	Apply(state,
		tween.from[1] + (tween.to[1] - tween.from[1]) * k,
		tween.from[2] + (tween.to[2] - tween.from[2]) * k,
		tween.from[3] + (tween.to[3] - tween.from[3]) * k,
		true)
end

-- Re-applies deferred one frame, so they land AFTER a SetBackgroundModel/scene rebuild in the same
-- call chain has finished with the frame.
local pending = {} -- screenName -> { args = {...}, instant = bool }

-- ---------------------------------------------------------------------------------- public API

function DCGlueCamera.OnAxisTouched(axis)
	if not cfg.enabled then
		return
	end
	local state = GetScreen("CharacterCreate")
	if not state then
		return
	end
	StartTween(state, axis == AXIS_SKIN and BodyArgs(state) or FaceArgs(state))
end

--- Called by DCCharCreateLayout.ApplyStage. Both stages share the body baseline; what this really
--- does is ease back out of a face zoom when the player leaves customization.
function DCGlueCamera.OnStageChanged(customize)
	if not cfg.enabled then
		return
	end
	local state = GetScreen("CharacterCreate")
	if state then
		StartTween(state, BodyArgs(state))
	end
end

-- ---------------------------------------------------------------------------------- hooks

local function WrapGlobal(name, wrapper)
	local stock = _G[name]
	if type(stock) ~= "function" then
		return
	end
	_G[name] = function(...)
		return wrapper(stock, ...)
	end
end

local function Install()
	-- Face/body zoom rides on the customization bridge; without it (older DLL, stock sliders)
	-- the constant framing below still applies.
	if DCCharCustomize then
		local stockCycle = DCCharCustomize.CycleAxis
		if stockCycle then
			DCCharCustomize.CycleAxis = function(axis, direction)
				DCGlueCamera.OnAxisTouched(axis)
				return stockCycle(axis, direction)
			end
		end
		local stockSetSlot = DCCharCustomize.SetSlot
		if stockSetSlot then
			DCCharCustomize.SetSlot = function(axis, slot)
				DCGlueCamera.OnAxisTouched(axis)
				return stockSetSlot(axis, slot)
			end
		end
	end

	-- Model rebuilds reset nothing we know of, but a rebuilt scene deserves a re-applied framing;
	-- race/gender changes also zoom back out (the whole body changed, show it).
	local function reframeCreate(stock, ...)
		local a, b, c, d = stock(...)
		if cfg.enabled and GetScreen("CharacterCreate") then
			pending["CharacterCreate"] = { args = BodyArgs(GetScreen("CharacterCreate")), instant = true }
		end
		return a, b, c, d
	end
	WrapGlobal("SetCharacterRace", reframeCreate)
	WrapGlobal("SetCharacterGender", reframeCreate)
	WrapGlobal("CharacterCreate_Randomize", reframeCreate)

	WrapGlobal("CharacterCreate_OnShow", function(stock, ...)
		local a, b, c, d = stock(...)
		if cfg.enabled and GetScreen("CharacterCreate") then
			pending["CharacterCreate"] = { args = BodyArgs(GetScreen("CharacterCreate")), instant = true }
		end
		return a, b, c, d
	end)

	local function reframeSelect(stock, ...)
		local a, b, c, d = stock(...)
		if cfg.enabled and GetScreen("CharacterSelect") then
			pending["CharacterSelect"] = { args = SelectArgs(), instant = true }
		end
		return a, b, c, d
	end
	WrapGlobal("CharacterSelect_OnShow", reframeSelect)
	WrapGlobal("UpdateCharacterSelection", reframeSelect)

	-- Screen teardown destroys the glue character models; a surviving native offset binding is a
	-- stale pointer, and re-placing through it corrupted the heap (the ERROR #132 crash on Back).
	-- Clear on hide: zero the offset (the DLL erases the binding even when the model is already
	-- gone) and reset local state so re-entry starts from stock framing.
	local function clearOnHide(screenName)
		return function(stock, ...)
			local state = screens[screenName]
			if state then
				state.tween = nil
				pending[screenName] = nil
				Apply(state, 0, 0, 0)
				state.cur[1], state.cur[2], state.cur[3] = 0, 0, 0
				state.goal[1], state.goal[2], state.goal[3] = 0, 0, 0
			end
			return stock(...)
		end
	end
	WrapGlobal("CharacterCreate_OnHide", clearOnHide("CharacterCreate"))
	WrapGlobal("CharacterSelect_OnHide", clearOnHide("CharacterSelect"))

	-- Record which background model each screen currently shows; DCGlueCameraData is keyed by it.
	WrapGlobal("SetBackgroundModel", function(stock, frame, path, ...)
		local name = frame and frame.GetName and frame:GetName()
		if name then
			screenModel[name] = NormalizeModelName(path)
		end
		return stock(frame, path, ...)
	end)

	-- NO OnUpdateModel wrappers. The v3/v4 rounds proved they are pure harm here: their applies
	-- never survived to the render, and firing at model-frame rate from inside the client's
	-- dispatch they drove the fail counter and Lua "C stack overflow" errors. Native offsets
	-- persist in the DLL map and are re-applied by the client's own rebuild, so nothing needs
	-- re-asserting from Lua at all in native mode.
end

-- ---------------------------------------------------------------------------------- driver

local driver = CreateFrame("Frame", nil, GlueParent)
local installed = false

driver:SetScript("OnUpdate", function()
	if not installed then
		-- First tick: all GlueXML files have loaded whatever the .toc order, so the select-screen
		-- globals exist and can be wrapped.
		installed = true
		Install()
	end
	local now = GetTime()
	if cfg.enabled then
		for name, entry in pairs(pending) do
			local state = GetScreen(name)
			if state then
				StartTween(state, entry.args, entry.instant)
			end
			pending[name] = nil
		end
		for _, state in pairs(screens) do
			if state.frame:IsShown() then
				ProcessTween(state, now)
				if not state.tween then
					if nativeCharOffset or nativeOffset then
						-- Native offsets persist on their own; but an apply that FAILED (the
						-- screen-entry apply can fire before the character model exists) leaves
						-- cur behind goal -- retry until it binds.
						if state.cur[1] ~= state.goal[1] or state.cur[2] ~= state.goal[2]
							or state.cur[3] ~= state.goal[3] then
							Apply(state, state.goal[1], state.goal[2], state.goal[3])
						end
					else
						-- SetPosition fallback: the scene re-derivation stomps the position every
						-- frame, so it must be re-asserted every tick.
						Apply(state, state.cur[1], state.cur[2], state.cur[3])
					end
				end
			end
		end
	end
	-- Stats keep refreshing even when disabled -- that is exactly when they must be readable.
	local statsText = DCGlueCamera._statsText
	if statsText and (not DCGlueCamera._statsNext or now >= DCGlueCamera._statsNext) then
		DCGlueCamera._statsNext = now + 0.25
		local create = screens["CharacterCreate"]
		local model = screenModel["CharacterCreate"]
		local hit = model and DCGlueCameraData
			and (DCGlueCameraData[model] or DCGlueCameraData["ui_" .. model]) and "+" or "-"
		statsText:SetText(string.format(
			"%s  applies %d  fail %d  cam %s%s\ncur %.2f / %.2f / %.2f  %s%s",
			(nativeCharOffset and "|cff00ff00char|r")
				or (nativeOffset and "|cffffcc00widget|r") or "|cffff4040setpos|r",
			stats.applies, stats.failures, model or "?", hit,
			create and create.cur[1] or 0, create and create.cur[2] or 0,
			create and create.cur[3] or 0,
			cfg.enabled and "|cff00ff00on|r" or "|cffff4040DISABLED|r",
			stats.lastError and ("\n|cffff4040" .. string.sub(stats.lastError, -60) .. "|r") or ""))
	end
end)

-- ---------------------------------------------------------------------------------- tuning panel

-- Opt-in (Config.tune). Nudges SetPosition arguments on whichever glue screen is visible and shows
-- the applied values, so the axis mapping and framing constants can be settled in one deploy.
-- Everything is player-triggered -- same safety stance as the retired spike.
if cfg.tune then
	-- 0.25 was calibrated for the (dead) SetPosition scale; the native offset units need several
	-- model units of travel, so nudge coarser.
	local STEP = 0.5

	local panel = CreateFrame("Frame", "DCGlueCameraTuner", GlueParent)
	panel:SetWidth(240)
	panel:SetHeight(190)
	panel:SetFrameStrata("DIALOG")
	panel:SetPoint("BOTTOMRIGHT", -20, 120)
	panel:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	panel:SetBackdropColor(0, 0, 0, 0.85)

	local title = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	title:SetPoint("TOPLEFT", 12, -10)
	-- The version tag is the "is the new deploy actually live?" check: glue Lua loads once per
	-- client start, so a stale tag means the client was not fully restarted.
	title:SetText("|cff00ff00DC glue camera tuner v18|r")

	-- Live diagnostics, refreshed by the driver: whether applies are flowing every frame, whether
	-- the OnUpdateModel handlers fire at all, and the last SetPosition error if any.
	local statsText = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	statsText:SetPoint("BOTTOMLEFT", 12, 10)
	statsText:SetJustifyH("LEFT")
	statsText:SetWidth(216)
	DCGlueCamera._statsText = statsText
	panel:SetHeight(230)

	local readout = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	readout:SetPoint("TOPLEFT", 12, -28)
	readout:SetJustifyH("LEFT")
	readout:SetText("arg1 0.00  arg2 0.00  arg3 0.00")

	local function ActiveScreen()
		local create = _G["CharacterCreate"]
		if create and create:IsShown() then
			return GetScreen("CharacterCreate")
		end
		local select = _G["CharacterSelect"]
		if select and select:IsShown() then
			return GetScreen("CharacterSelect")
		end
		return nil
	end

	local function Refresh(state)
		readout:SetText(string.format("arg1 %.2f  arg2 %.2f  arg3 %.2f",
			state.cur[1], state.cur[2], state.cur[3]))
	end

	local function MakeButton(label, x, y, width, onClick)
		local button = CreateFrame("Button", nil, panel)
		button:SetWidth(width or 30)
		button:SetHeight(20)
		button:SetPoint("TOPLEFT", x, y)
		button:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		button:SetBackdropColor(0.15, 0.15, 0.15, 1)
		local text = button:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
		text:SetPoint("CENTER")
		text:SetText(label)
		button:SetScript("OnClick", function()
			local state = ActiveScreen()
			if state then
				onClick(state)
				Refresh(state)
			end
		end)
		return button
	end

	for arg = 1, 3 do
		local y = -46 - (arg - 1) * 24
		local label = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
		label:SetPoint("TOPLEFT", 12, y - 4)
		label:SetText("arg" .. arg)
		MakeButton("-", 60, y, 30, function(state)
			state.tween = nil
			state.cur[arg] = state.cur[arg] - STEP
			Apply(state, state.cur[1], state.cur[2], state.cur[3])
		end)
		MakeButton("+", 94, y, 30, function(state)
			state.tween = nil
			state.cur[arg] = state.cur[arg] + STEP
			Apply(state, state.cur[1], state.cur[2], state.cur[3])
		end)
	end

	-- Instant on purpose: while MEASURING, a mid-flight tween is exactly what makes results
	-- unreadable (each step re-drives the scene). The production hooks keep the ease; the tuner
	-- shows steady states only.
	MakeButton("Zero", 12, -124, 60, function(state)
		StartTween(state, { 0, 0, 0 }, true)
	end)
	MakeButton("Body", 76, -124, 60, function(state)
		StartTween(state, BodyArgs(state), true)
	end)
	MakeButton("Face", 140, -124, 60, function(state)
		StartTween(state, FaceArgs(state), true)
	end)

	local hint = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 12, -152)
	hint:SetJustifyH("LEFT")
	hint:SetWidth(216)
	hint:SetText("|cffffcc00Nudge args to find the toward-camera axis; record values into DCGlueCamera.Config.|r")
end
