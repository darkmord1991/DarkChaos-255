--[[----------------------------------------------------------------------------------------------
DCGlueCamera.lua -- Ascension-style camera framing for the glue screens (create + select).

What it does:
  * CREATE: the character is shown larger than stock (a constant "body" dolly toward the camera),
    and customizing face/hair/facial features eases in to a head-and-shoulders framing;
    touching the skin axis (or changing race/gender) eases back out to the full body.
  * Either screen: the scroll wheel is a free zoom across that same range.
  * SELECT: every character is shown larger via a constant dolly, re-applied after each selection
    (SetBackgroundModel may rebuild the scene).

v19 -- optical zoom. Magnification is now DCSetGlueZoom, which scales the glue scene camera's FOV
(cam+0x114, written at the projection-setup choke point 0x4BECF0). Mechanism and both addresses
are from bozo-1/wxl-glue-zoom (GPL-3.0); the placement side stays ours, since hooking
CModel::SetTransform costs a handful of calls per frame where that module rewrites the placement
matrix on every DrawIndexedPrimitive.

Optical zoom EXTENDS the dolly, it does not replace it. v19.0 tried replacing it -- deriving a
vertical-only offset that put the eyes on the view axis, deleting faceForward and the per-race df
trims -- and it failed in-client on 2026-08-22 in two ways that share one cause. Moving the
character vertically without also moving it forward sinks it into the scene FLOOR (gnome and dwarf
were lowered ~2.6x further than v18 and went visibly underground), and the derived lift was about
half what the tall races need (tauren -0.43 vs v18's -1.13, draenei -0.59 vs -1.21), so the frame
centred on the chest. v18's placement had been calibrated over 18 in-client rounds and was not the
thing to replace.

So the split is:
  * t = 0 .. 1  -- v18, verbatim. The dolly walks the character from the body baseline to the face
    framing, and every knob it needs (faceSize, chestHeight, faceForward, the FACE_TUNE df/dz/dy
    trims) is still live. Zoom stays 1.0 across this whole range, so t = 1 IS v18.
  * t = 1 .. 2  -- placement PINNED at the face framing; magnification is FOV alone. Nothing moves,
    so no amount of extra zoom can sink the model. This is the range the wheel adds.
  * Framing is parameterised by t rather than by an offset triple because the wheel has to
    retarget mid-glide; t eases with frame-rate-independent exponential smoothing.

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

Face framing is per race/sex: the camera zooms about its own axis, so the model is lowered by
(eye height - the axis height above the character) to keep the face centred. Eye heights are
estimates; refine with the tuning panel and edit EYE_HEIGHT.

Load order: after DCCharCustomize.lua (its functions are wrapped at install time), before
DCCharCreateUI/Layout (the layout calls DCGlueCamera.OnStageChanged). Select-screen hooks are
installed on the driver's first tick, by which point every GlueXML file has loaded regardless of
GlueXML.toc order.

Degradation: a DLL without DCSetGlueZoom (or whose FOV hook failed to take) simply caps t at 1,
which is v18 exactly -- the worst case is the behaviour that already shipped. If the offset apply
errors 20 times running the module disables itself and the screens behave stock.
------------------------------------------------------------------------------------------------]]

DCGlueCamera = {}

DCGlueCamera.Config = {
	enabled = true,
	-- The in-screen tuning panel. OFF for normal play (2026-08-11, after 18 calibration rounds);
	-- flip to true and redeploy to resume framing work -- the per-race knobs live in FACE_TUNE.
	tune = false,

	-- Framing progress `t` eases toward its goal with frame-rate-independent exponential
	-- smoothing (replaces the old fixed-duration tween: the mouse wheel needs to retarget
	-- mid-flight, which a from/to/start tween cannot do without restarting the ease).
	-- Higher = snappier; 9 lands a wheel notch as a ~0.2s glide.
	zoomSmooth = 9.0,
	wheelStep = 0.12,         -- t added per wheel notch
	wheelEnabled = true,      -- scroll-wheel free zoom on the glue screens
	wheelOnSelect = true,     -- ... including the character-select screen

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
	-- Magnification is OPTICAL since v19 (DCSetGlueZoom scales the scene camera's FOV), but it is
	-- an EXTENSION of the v18 dolly, not a replacement for it. v19.0 tried replacing it -- deriving
	-- a vertical-only offset that put the eyes on the view axis -- and that failed in-client two
	-- ways at once (2026-08-22):
	--   * Vertical-only movement sinks the model into the scene FLOOR. The dolly moved the
	--     character forward as well, which is what kept its feet on the ground; without that, gnome
	--     and dwarf were lowered ~2.6x further than v18 and went visibly underground.
	--   * It under-lifted the tall races (tauren -0.43 vs v18's -1.13, draenei -0.59 vs -1.21), so
	--     the frame centred on the chest instead of the face.
	-- So placement is v18's, unchanged and still calibrated; FOV only adds magnification BEYOND the
	-- face framing, where the character no longer moves and so cannot sink.
	faceSize = 0.9,           -- face framing distance = faceSize / tan(fov/2)
	faceLift = 0,             -- world-up bias; per-race trims live in FACE_TUNE instead
	chestHeight = 1.1,        -- what the camera's aim target height means on the character
	faceForward = 3.0,        -- no camera data: forward offset
	aimHeight = 1.2,          -- no camera data: face height constant
	-- Optical zoom applied across t = 1 -> tMax, on top of the face framing. 2.0 doubles the
	-- apparent size again past the point where v18 stopped.
	extraZoom = 2.0,
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
	-- Pandaren (22 Alliance / 23 Horde, same model): from the MoP-Classic create-screen
	-- camera targets (tz 2.125 male / 1.999 female); untrimmed pending in-client review.
	[22] = { [0] = 2.10, [1] = 1.95 },
	[23] = { [0] = 2.10, [1] = 1.95 },
	[24] = { [0] = 1.05, [1] = 1.00 },  -- Vulpera: goblin-sized
	[25] = { [0] = 2.05, [1] = 1.90 },  -- Zandalari Troll
	[26] = { [0] = 2.05, [1] = 1.85 },  -- Kul Tiran
	[27] = { [0] = 1.25, [1] = 1.20 },  -- Dark Iron Dwarf: dwarf model, dwarf eye height
}

-- Per-race face-framing trims on top of the analytic camera math, from in-client review
-- (2026-08-11): dz = vertical delta (+up), dy = side delta. The geometry gets every race close;
-- these encode taste and the residual scene quirks.
--
-- df (forward delta) is DEAD as of v19 and is ignored: it trimmed the dolly distance, which was
-- the old magnification mechanism. Optical zoom needs no distance, so tauren's -0.80 and
-- draenei's -1.20 have nothing left to act on. The rows are kept because their dz/dy still
-- apply; the df values are retained only as a record of the dolly-era calibration.
local FACE_TUNE = {
	[1]  = { dz = -0.60, dy = -0.10 },  -- Human: -0.35 overshot left, back toward the right (r4)
	[3]  = { dz = 0.25 },               -- Dwarf: lands at goblin's approved framing ratio
	[4]  = { dz = -0.15, dy = -0.25 },  -- Night Elf: slightly up + left (round 3)
	[6]  = { df = -0.80, dz = 0.50 },   -- Tauren: back off, up again (round 3)
	[7]  = { dz = 0.25 },               -- Gnome: shares the dwarf screen, same trim
	[8]  = { dz = -0.15 },              -- Troll: slightly up (round 3)
	[10] = { dz = -0.05 },              -- Blood Elf
	[11] = { df = -1.20, dz = 0.0 },    -- Draenei: distance settled in r3; +0.90 raise showed
	                                    -- only the torso -- character back down (r4)
	[12] = { dz = 0.25 },               -- Worgen: up a bit (round 3)
	[22] = { dz = -0.40 },              -- Pandaren: face sat above the frame on the tauren
	[23] = { dz = -0.40 },              -- scene - character down (round 1, untrimmed guess)
	-- Scourge: pure analytic is the keeper.
	-- (The undead brightening during face zoom is scene lighting near the camera, not framing.)
}

-- Per-race body-framing back-off in character units: the stage-1 dolly only ever moves IN,
-- but some models crop at a scene's baseline camera (pandaren bulk on the tauren scene).
local BODY_TUNE = {
	[22] = { back = 2.4 },   -- r3: 1.2 -> 1.6 was still too tight, bigger step out
	[23] = { back = 2.4 },
	-- First guesses pending in-client review; bulky frames crop like pandaren did.
	[25] = { back = 2.0 },   -- r1: 0.8 still cropped a very tall frame, out toward pandaren's step
	[26] = { back = 1.4 },
}

local AXIS_SKIN = 1

local cfg = DCGlueCamera.Config

-- ---------------------------------------------------------------------------------- screen state

-- name -> { frame, cur = {a1,a2,a3,zoom}, t, tGoal, settled }
--   t is the framing progress: 0 = body, 1 = face. Everything the player does moves tGoal; the
--   driver eases t toward it and derives the whole framing from t. (v18 tweened the offset
--   triple directly; the wheel needs to retarget mid-flight, which a from/to/start tween cannot
--   do without restarting the ease.)
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
	state = { frame = frame, cur = { 0, 0, 0, 1 }, t = 0, tGoal = 0, settled = false }
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
-- v19: optical zoom. Scales the scene camera's FOV, magnifying WITHOUT moving the character --
-- which is exactly what the dolly cannot do, since past the face framing any further movement
-- buries the model in the scene floor. It extends the range rather than replacing the dolly;
-- absent (older DLL) TMax caps t at 1 and the framing is v18 exactly.
local nativeZoom = type(DCSetGlueZoom) == "function" and DCSetGlueZoom or nil
DCGlueCamera.HasOpticalZoom = nativeZoom ~= nil

-- Last zoom pushed to the native, so an unchanged frame costs no call. The zoom is global (only
-- one glue screen is ever up), unlike the per-screen offsets.
local appliedZoom = 1.0

local function ApplyZoom(zoom)
	if not nativeZoom then
		return true
	end
	if math.abs(zoom - appliedZoom) < 0.0005 then
		return true
	end
	local ok, ret = pcall(nativeZoom, zoom)
	if ok and ret == 1 then
		appliedZoom = zoom
		return true
	end
	stats.zoomFailures = (stats.zoomFailures or 0) + 1
	stats.lastError = ok and "zoom rejected" or tostring(ret)
	-- The native returns 0 when MinHook could not take 0x4BECF0. Registered-but-not-hooked is the
	-- one state that would look BROKEN rather than merely unimproved: the vertical recentring
	-- would apply with no magnification behind it, i.e. a character shoved off-frame for nothing.
	-- Demote to the dolly path on the first rejection -- FramingAt reads this same upvalue, so the
	-- next tick is already framing the v18 way.
	nativeZoom = nil
	DCGlueCamera.HasOpticalZoom = false
	appliedZoom = 1.0
	return false
end

local function ScreenArg(state)
	return (state.frame == _G["CharacterSelect"]) and "select" or "create"
end

-- midTween applies skip the native's forced transform refresh (5th arg 0): the glue scene
-- rebuilds on its own cadence from the ANIMATED base position, and forcing extra rebuilds
-- between its frames made rapid tween steps visibly fight it ("applies then resets" flicker).
-- Final values (tween end, nudges, presets) do refresh so they show even if the scene is idle.
-- Applies one framing: the character offset (whichever native path is live) plus the optical
-- zoom. Returns true only when BOTH landed, so the driver keeps retrying a framing that could not
-- bind yet -- the screen-entry apply fires before the character model exists.
local function Apply(state, a1, a2, a3, zoom, midTween)
	zoom = zoom or 1.0
	local zoomOk = ApplyZoom(zoom)

	local ok, ret
	if nativeCharOffset then
		ok, ret = pcall(nativeCharOffset, ScreenArg(state), a1, a2, a3)
		if ok and ret ~= 1 then
			ok, ret = false, "char model not resolvable"
		end
	elseif nativeOffset then
		ok, ret = pcall(nativeOffset, state.frame, a1, a2, a3, midTween and 0 or 1)
		if ok and ret ~= 1 then
			ok, ret = false, "native offset rejected the frame"
		end
	else
		ok, ret = pcall(state.frame.SetPosition, state.frame, a1, a2, a3)
	end

	if not ok then
		stats.failures = stats.failures + 1
		stats.lastError = tostring(ret)
		-- Streaks are per screen: the other screen applying fine must not mask a broken one.
		state.failStreak = (state.failStreak or 0) + 1
		if state.failStreak >= 20 then
			cfg.enabled = false
		end
		return false
	end

	stats.applies = stats.applies + 1
	state.failStreak = 0
	stats.lastError = nil
	state.cur[1], state.cur[2], state.cur[3], state.cur[4] = a1, a2, a3, zoom
	return zoomOk
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
	local race = DCCharCustomize and DCCharCustomize.RaceSex and select(1, DCCharCustomize.RaceSex())
	local back = (race and BODY_TUNE[race] and BODY_TUNE[race].back) or 0
	local cam = state and ScreenCamera(state)
	if cam then
		return { cam.dh * cfg.bodyFraction * scale - back, 0, 0 }
	end
	return Compose(cfg.bodyForward * scale - back, 0, 0)
end

--- The face framing: v18, verbatim and still the only thing that decides WHERE the character
--- goes. Walks it up the camera's view axis to an fov-normalized distance so the eyes land on
--- the axis at a consistent apparent size, anchoring the vertical to the camera's aim target
--- (which is why scenes that do not stand the character at scene origin -- dwarf/gnome low,
--- night elf high -- still frame correctly).
---
--- Optical zoom does NOT change this. It magnifies further once the character is already here,
--- which is the one thing the dolly could not do without sinking the model into the floor.
local function FaceArgs(state)
	local eye = EyeHeight()
	local race = DCCharCustomize and DCCharCustomize.RaceSex and select(1, DCCharCustomize.RaceSex())
	local tune = race and FACE_TUNE[race] or nil
	local df, dz = (tune and tune.df or 0), (tune and tune.dz or 0)
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

--- The complete framing at progress t: offset triple + optical zoom.
--- t = 0 is the screen's baseline (body dolly on create, stock on select); t = 1 is the face.
--- Maximum t. Without optical zoom the range stops at the v18 face framing; with it the wheel
--- can carry on past that point on FOV alone.
local function TMax()
	return nativeZoom and 2.0 or 1.0
end

--- The complete framing at progress t: offset triple + optical zoom.
---   t = 0        the screen's baseline (body dolly on create, stock on select)
---   t = 0 .. 1   v18: dolly from baseline to the face framing. Zoom stays 1.0.
---   t = 1 .. 2   placement PINNED at the face framing; magnification is FOV only.
--- Splitting it there is the whole design: everything that moves the character is v18's approved
--- calibration, and everything past it moves nothing, so no amount of extra zoom can sink the
--- model into the scene floor.
local function FramingAt(state, t)
	local base = (state.frame == _G["CharacterSelect"]) and SelectArgs() or BodyArgs(state)
	if t <= 0 then
		return base[1], base[2], base[3], 1.0
	end

	local face = FaceArgs(state)
	local k = (t < 1) and t or 1
	local a1 = base[1] + (face[1] - base[1]) * k
	local a2 = base[2] + (face[2] - base[2]) * k
	local a3 = base[3] + (face[3] - base[3]) * k

	local zoom = 1.0
	if t > 1 and nativeZoom then
		zoom = 1.0 + (cfg.extraZoom - 1.0) * (t - 1)
	end
	return a1, a2, a3, zoom
end

-- ---------------------------------------------------------------------------------- easing

--- Retargets the framing. Everything player-facing goes through here: it only moves the goal, so
--- a wheel notch arriving mid-glide redirects the same motion instead of restarting it.
local function SetFraming(state, goal, instant)
	local top = TMax()
	if goal < 0 then
		goal = 0
	elseif goal > top then
		goal = top
	end
	state.tGoal = goal
	if instant or cfg.zoomSmooth <= 0 then
		state.t = goal
	end
	state.settled = false
end

--- One driver tick. Frame-rate independent exponential smoothing, so the glide is the same on a
--- 30fps laptop and a 200fps desktop.
--- Mid-glide applies pass midTween: they skip the native's forced transform refresh, because the
--- glue scene rebuilds on its own cadence and extra rebuilds between its frames made rapid steps
--- visibly fight it (the 2026-08-11 "applies then resets" flicker). The settling apply refreshes.
local function StepFraming(state, dt)
	if state.t ~= state.tGoal then
		local f = 1 - math.exp(-cfg.zoomSmooth * dt)
		state.t = state.t + (state.tGoal - state.t) * f
		if math.abs(state.tGoal - state.t) < 0.002 then
			state.t = state.tGoal
		end
		local a1, a2, a3, zoom = FramingAt(state, state.t)
		Apply(state, a1, a2, a3, zoom, true)
		state.settled = false
	elseif not state.settled then
		-- Settled, or retrying: native offsets persist on their own, so once an apply has landed
		-- there is nothing to re-assert. An apply that FAILED (screen entry can fire before the
		-- character model exists) leaves settled false and is retried next tick.
		local a1, a2, a3, zoom = FramingAt(state, state.t)
		state.settled = Apply(state, a1, a2, a3, zoom, false)
	elseif not (nativeCharOffset or nativeOffset) then
		-- SetPosition fallback: the scene re-derivation stomps the position every frame, so it
		-- must be re-asserted every tick.
		Apply(state, state.cur[1], state.cur[2], state.cur[3], state.cur[4], false)
	end
end

-- Re-applies deferred one frame, so they land AFTER a SetBackgroundModel/scene rebuild in the same
-- call chain has finished with the frame.
local pending = {} -- screenName -> { t = number, instant = bool }

-- ---------------------------------------------------------------------------------- public API

function DCGlueCamera.OnAxisTouched(axis)
	if not cfg.enabled then
		return
	end
	local state = GetScreen("CharacterCreate")
	if not state then
		return
	end
	SetFraming(state, axis == AXIS_SKIN and 0 or 1)
end

--- Free zoom. `delta` is in wheel notches (+1 = toward the face). Nudges the goal rather than
--- setting it, so repeated notches accumulate and the ease keeps up with the wheel.
function DCGlueCamera.Nudge(screenName, delta)
	if not cfg.enabled then
		return
	end
	local state = GetScreen(screenName)
	if state and state.frame:IsShown() then
		SetFraming(state, state.tGoal + delta * cfg.wheelStep)
	end
end

--- Called by DCCharCreateLayout.ApplyStage. Both stages share the body baseline; what this really
--- does is ease back out of a face zoom when the player leaves customization.
function DCGlueCamera.OnStageChanged(customize)
	if not cfg.enabled then
		return
	end
	local state = GetScreen("CharacterCreate")
	if state then
		SetFraming(state, 0)
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
			pending["CharacterCreate"] = { t = 0, instant = true }
		end
		return a, b, c, d
	end
	WrapGlobal("SetCharacterRace", reframeCreate)
	WrapGlobal("SetCharacterGender", reframeCreate)
	WrapGlobal("CharacterCreate_Randomize", reframeCreate)

	WrapGlobal("CharacterCreate_OnShow", function(stock, ...)
		local a, b, c, d = stock(...)
		if cfg.enabled and GetScreen("CharacterCreate") then
			pending["CharacterCreate"] = { t = 0, instant = true }
		end
		return a, b, c, d
	end)

	local function reframeSelect(stock, ...)
		local a, b, c, d = stock(...)
		if cfg.enabled and GetScreen("CharacterSelect") then
			pending["CharacterSelect"] = { t = 0, instant = true }
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
				pending[screenName] = nil
				state.t, state.tGoal, state.settled = 0, 0, true
				-- Zoom 1.0 is not just "no magnification": it is what makes the native restore
				-- the camera's own FOV and drop its base cache, so a scene that comes back with
				-- a different camera is measured fresh.
				Apply(state, 0, 0, 0, 1.0)
				state.cur[1], state.cur[2], state.cur[3], state.cur[4] = 0, 0, 0, 1.0
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

	-- Scroll-wheel free zoom. A full-screen catcher rather than EnableMouseWheel on the glue
	-- screens themselves: those are ModelFFX frames whose scripts the stock UI owns, and a
	-- separate frame keeps the whole feature removable by flipping cfg.wheelEnabled.
	-- BACKGROUND strata on purpose -- the wheel goes to the TOPMOST frame under the cursor that
	-- has it enabled, so the character-select scroll list still wins over its own area. Only the
	-- wheel is enabled, never mouse clicks, so nothing here can swallow a button press.
	if cfg.wheelEnabled and not DCGlueCamera._wheel then
		local wheel = CreateFrame("Frame", "DCGlueCameraWheel", GlueParent)
		wheel:SetAllPoints(GlueParent)
		wheel:SetFrameStrata("BACKGROUND")
		wheel:EnableMouseWheel(true)
		wheel:SetScript("OnMouseWheel", function(self, delta)
			-- 3.3.5 passes (self, delta); the arg1 fallback covers a glue state that still
			-- dispatches the pre-3.0 way.
			local d = delta or arg1
			if not d or d == 0 then
				return
			end
			local create = _G["CharacterCreate"]
			if create and create:IsShown() then
				DCGlueCamera.Nudge("CharacterCreate", d)
			elseif cfg.wheelOnSelect then
				local select = _G["CharacterSelect"]
				if select and select:IsShown() then
					DCGlueCamera.Nudge("CharacterSelect", d)
				end
			end
		end)
		DCGlueCamera._wheel = wheel
	end

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
	-- Real elapsed time, clamped: the first tick has no previous stamp, and an alt-tab or a
	-- loading screen must not deliver one giant step that snaps the ease.
	local dt = DCGlueCamera._lastTick and (now - DCGlueCamera._lastTick) or 0.016
	DCGlueCamera._lastTick = now
	if dt < 0.001 then
		dt = 0.001
	elseif dt > 0.1 then
		dt = 0.1
	end
	if cfg.enabled then
		for name, entry in pairs(pending) do
			local state = GetScreen(name)
			if state then
				SetFraming(state, entry.t, entry.instant)
			end
			pending[name] = nil
		end
		for _, state in pairs(screens) do
			if state.frame:IsShown() then
				StepFraming(state, dt)
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
			"%s %s  applies %d  fail %d/%d  cam %s%s\ncur %.2f / %.2f / %.2f  zoom %.2fx"
				.. "  t %.2f>%.2f  %s%s",
			(nativeCharOffset and "|cff00ff00char|r")
				or (nativeOffset and "|cffffcc00widget|r") or "|cffff4040setpos|r",
			nativeZoom and "|cff00ff00fov|r" or "|cffff4040dolly|r",
			stats.applies, stats.failures, stats.zoomFailures or 0, model or "?", hit,
			create and create.cur[1] or 0, create and create.cur[2] or 0,
			create and create.cur[3] or 0, create and create.cur[4] or 1,
			create and create.t or 0, create and create.tGoal or 0,
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
	title:SetText("|cff00ff00DC glue camera tuner v19|r")

	-- Live diagnostics, refreshed by the driver: whether applies are flowing every frame, whether
	-- the OnUpdateModel handlers fire at all, and the last SetPosition error if any.
	local statsText = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	statsText:SetPoint("BOTTOMLEFT", 12, 10)
	statsText:SetJustifyH("LEFT")
	statsText:SetWidth(216)
	DCGlueCamera._statsText = statsText
	panel:SetHeight(254)

	local readout = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	readout:SetPoint("TOPLEFT", 12, -28)
	readout:SetJustifyH("LEFT")
	readout:SetText("arg1 0.00  arg2 0.00  arg3 0.00  zoom 1.00x")

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
		readout:SetText(string.format("arg1 %.2f  arg2 %.2f  arg3 %.2f  zoom %.2fx",
			state.cur[1], state.cur[2], state.cur[3], state.cur[4]))
	end

	-- A manual nudge has to FREEZE the driver, or the next tick re-derives the framing from t and
	-- throws the measurement away. Parking tGoal on t and declaring the state settled is exactly
	-- what leaves StepFraming with nothing to do in native mode.
	local function Freeze(state)
		state.tGoal = state.t
		state.settled = true
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

	-- Row 4 is the optical zoom, which needs a far finer step than the offsets: 0.5x per click
	-- would jump straight past every framing worth recording.
	for arg = 1, 4 do
		local y = -46 - (arg - 1) * 24
		local step = (arg == 4) and 0.1 or STEP
		local label = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
		label:SetPoint("TOPLEFT", 12, y - 4)
		label:SetText((arg == 4) and "zoom" or ("arg" .. arg))
		local function nudge(state, by)
			Freeze(state)
			state.cur[arg] = state.cur[arg] + by
			if arg == 4 and state.cur[4] < 1 then
				state.cur[4] = 1
			end
			Apply(state, state.cur[1], state.cur[2], state.cur[3], state.cur[4])
		end
		MakeButton("-", 60, y, 30, function(state) nudge(state, -step) end)
		MakeButton("+", 94, y, 30, function(state) nudge(state, step) end)
	end

	-- Instant on purpose: while MEASURING, a mid-flight tween is exactly what makes results
	-- unreadable (each step re-drives the scene). The production hooks keep the ease; the tuner
	-- shows steady states only.
	MakeButton("Body", 12, -148, 60, function(state)
		SetFraming(state, 0, true)
	end)
	-- Face is t = 1, i.e. v18's framing exactly -- the reference to calibrate FACE_TUNE against.
	-- Max is the far end of the optical range, which moves nothing further.
	MakeButton("Face", 76, -148, 60, function(state)
		SetFraming(state, 1, true)
	end)
	MakeButton("Max", 140, -148, 60, function(state)
		SetFraming(state, TMax(), true)
	end)

	local hint = panel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 12, -176)
	hint:SetJustifyH("LEFT")
	hint:SetWidth(216)
	hint:SetText("|cffffcc00Body/Half/Face set t; args trim the offset, zoom the FOV. Record dz/dy into "
		.. "FACE_TUNE and the zoom ratio into Config.faceSize.|r")
end
