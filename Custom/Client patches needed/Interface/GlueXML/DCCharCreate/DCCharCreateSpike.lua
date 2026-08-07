--[[----------------------------------------------------------------------------------------------
DCCharCreateSpike.lua -- TEMPORARY in-client diagnostic for the SL character-creation downport.

Answers, on screen, the questions that cannot be settled from source. Delete this file once the
answers are recorded; nothing in the real UI depends on it.

  S0-1  Is the readback synchronous?  Does GetSkinColorSelection() change in the SAME frame as
        CycleCharCustomization()? If not, the absolute-set design collapses and the UI must fall
        back to plain arrow cycling. THIS IS THE ONE THAT GATES EVERYTHING.
  S0-2  Does a forward loop wrap, and how many steps per axis? Compared against the offline table.
  S0-3  Do N cycles in one frame cost one bake or N? Reported as elapsed ms for 30 cycles.
  S0-4  Does CharacterCreate:SetModelScale() / :SetPosition() move the natively-placed character?
  S0-5  Does :SetCamera(n) give a usable head-and-shoulders framing?
  S0-7  Do <Animations> work in the GLUE Lua state? (They exist in 3.3.5a FrameXML, but no stock
        GlueXML file uses them, and glue is a separate Lua state.)

DEPLOY (temporary):
  1. add to Interface\GlueXML\CharacterCreate.xml, as the LAST child of <Ui>:
         <Script file="DCCharCreate\DCCharCustomizeData.lua"/>
         <Script file="DCCharCreate\DCCharCustomize.lua"/>
         <Script file="DCCharCreate\DCCharCreateSpike.lua"/>
  2. pack all three plus the edited CharacterCreate.xml into Data\enGB\patch-enGB-3.MPQ
     (NOT patch-5 -- the enGB chain outranks it for .lua/.xml, so a root-chain copy is inert)
  3. start the client, go to character creation, read the panel

Press the on-screen button to re-run against the currently selected race/gender/class. Worth doing
for at least one Death Knight, since DK unlocks extra skins and faces.
------------------------------------------------------------------------------------------------]]

local PANEL_WIDTH = 460
local CYCLE_BENCH_STEPS = 12

local spike = CreateFrame("Frame", "DCCharCreateSpike", CharacterCreate)
spike:SetWidth(PANEL_WIDTH)
spike:SetHeight(560)
-- DIALOG strata + clear of the left panel: the first position (TOPLEFT 24,-24, default strata)
-- rendered UNDER the race column and class icons - unreadable, and the Run button swallowed
-- clicks meant for it or was itself unclickable.
spike:SetFrameStrata("DIALOG")
spike:SetPoint("TOPLEFT", 620, -60)
spike:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
spike:SetBackdropColor(0, 0, 0, 0.85)

local title = spike:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("|cff00ff00DC char-create spike|r")

local body = spike:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
body:SetPoint("TOPLEFT", 14, -34)
body:SetWidth(PANEL_WIDTH - 28)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")

-- Built without inheriting GlueButtonTemplate on purpose: this file is injected into the live
-- character-create screen, and a missing template at load time would throw inside it. A plain
-- button with its own textures cannot fail that way.
local rerun = CreateFrame("Button", nil, spike)
rerun:SetWidth(150)
rerun:SetHeight(24)
rerun:SetPoint("BOTTOMLEFT", 14, 12)
rerun:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
rerun:SetBackdropColor(0.15, 0.15, 0.15, 1)
local rerunText = rerun:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
rerunText:SetPoint("CENTER")
rerunText:SetText("Re-run")

local lines = {}
local function out(fmt, ...)
	lines[#lines + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt
end

local function verdict(ok, yes, no)
	return (ok and "|cff00ff00" .. yes .. "|r") or ("|cffff4040" .. no .. "|r")
end

--- S0-1: cycle once and see whether the readback moved within this frame.
local function testReadbackSync()
	local get = GetSkinColorSelection
	if type(get) ~= "function" or type(CycleCharCustomization) ~= "function" then
		out("S0-1 readback: %s", verdict(false, "", "WXL getters MISSING - wrong DLL build"))
		return false
	end
	local before = get()
	CycleCharCustomization(1, 1)
	local after = get()
	CycleCharCustomization(1, -1)     -- put it back
	local synchronous = (after ~= before)
	out("S0-1 readback synchronous: %s   (%s -> %s)",
		verdict(synchronous, "YES", "NO - absolute-set will not work"),
		tostring(before), tostring(after))
	return synchronous
end

--- S0-2: probed counts vs the offline table.
local function testCounts()
	-- Use the resolved ChrRaces id / 0-1 sex, NOT GetSelectedRace()/GetSelectedSex(): those return
	-- a race-list index and 2/3. Reading the offline table with the raw getters is what made this
	-- panel report Blood Elf numbers next to a Troll's probe results.
	local race, sex = DCCharCustomize.RaceSex()
	race = race or -1
	local offline = DCCharCustomizeData and race and sex
		and DCCharCustomizeData[race] and DCCharCustomizeData[race][sex]
	out(" ")
	out("S0-2 counts (race %d, sex %s)  [list index %s]",
		race, tostring(sex), tostring(GetSelectedRace and GetSelectedRace()))
	out("     axis            probed  offline  wrapped")

	DCCharCustomize.Invalidate()
	local allWrapped, anyMismatch = true, false
	for _, axis in ipairs(DCCharCustomize.AXES) do
		local info = DCCharCustomize.GetAxisInfo(axis)
		local expected = offline and offline[axis] and #offline[axis].indices or 0
		local label = _G[DCCharCustomize.AXIS_LABEL_KEY[axis]] or ("axis " .. axis)
		local mismatch = (expected > 0 and expected ~= info.count)
		anyMismatch = anyMismatch or mismatch
		allWrapped = allWrapped and info.wrapped
		out("     %-14s %6d  %7s  %s%s", label, info.count,
			expected > 0 and tostring(expected) or "-",
			info.wrapped and "yes" or "|cffff4040NO|r",
			mismatch and "  |cffffcc00<- differs|r" or "")
	end
	out("     all axes wrapped: %s", verdict(allWrapped, "YES", "NO"))
	out("     probe trustworthy: %s",
		verdict(DCCharCustomize.IsProbeTrustworthy(), "YES", "NO - fall back to arrows"))
	if anyMismatch then
		out("     |cffffcc00note: a difference is EXPECTED for a Death Knight (extra skins/faces)|r")
	end
end

--- S0-3: is the re-composite deferred to one per frame, or paid per cycle?
local function testCycleCost()
	local start = GetTime()
	for _ = 1, CYCLE_BENCH_STEPS do
		CycleCharCustomization(1, 1)
	end
	local elapsed = (GetTime() - start) * 1000
	for _ = 1, CYCLE_BENCH_STEPS do
		CycleCharCustomization(1, -1)  -- restore
	end
	out(" ")
	out("S0-3 %d cycles took %.1f ms  (%s)", CYCLE_BENCH_STEPS, elapsed,
		elapsed < 50 and "|cff00ff00cheap - bake is deferred|r"
		or "|cffffcc00costly - spread the delta over frames|r")
end

--- S0-4 / S0-5: can we frame the head for per-category zoom?
local function testCamera()
	out(" ")
	out("S0-4/5 camera - watch the MODEL while these apply:")
	local okScale = pcall(function() CharacterCreate:SetModelScale(1.6) end)
	out("     SetModelScale(1.6): %s", okScale and "called - did the model grow?" or "|cffff4040not supported|r")
	local okPos = pcall(function() CharacterCreate:SetPosition(0, 0, -0.6) end)
	out("     SetPosition:        %s", okPos and "called - did the model shift?" or "|cffff4040not supported|r")
	-- Put it back so the screen is usable afterwards.
	pcall(function() CharacterCreate:SetModelScale(1.0) end)
	pcall(function() CharacterCreate:SetPosition(0, 0, 0) end)
	out("     (reset applied; if the model is still off, UpdateCustomizationScene overrides it)")
end

--- S0-7: do declarative animations run in the glue Lua state?
local function testAnimations()
	out(" ")
	local ok, supported = pcall(function()
		local probe = CreateFrame("Frame", nil, spike)
		if type(probe.CreateAnimationGroup) ~= "function" then
			return false
		end
		local group = probe:CreateAnimationGroup()
		local alpha = group:CreateAnimation("Alpha")
		return alpha ~= nil
	end)
	out("S0-7 <Animations> in glue: %s",
		verdict(ok and supported, "YES - no tweener polyfill needed", "NO - use the OnUpdate tweener"))
end

local function run()
	lines = {}
	out("build: %s", (GetWotLKExtensionsBuildFingerprint and GetWotLKExtensionsBuildFingerprint())
		or "|cffff4040WXL fingerprint unavailable|r")
	out(" ")

	if not (DCCharCustomize and DCCharCustomize.IsAvailable()) then
		out("|cffff4040DCCharCustomize unavailable - the WXL readback getters are not registered.|r")
		out("Check GLUEMGREXTENSION=ON and that the deployed DLL matches this client build.")
		body:SetText(table.concat(lines, "\n"))
		return
	end

	local synchronous = testReadbackSync()
	testCounts()
	if synchronous then
		testCycleCost()
	else
		out(" ")
		out("S0-3 skipped - readback is not synchronous, so cycle timing is moot.")
	end
	testAnimations()
	out(" ")
	out("S0-4/5 camera: |cffffcc00opt-in|r - press Camera. It calls SetModelScale/SetPosition on the")
	out("     live character model, which is the riskiest thing here, so it is kept separate.")

	body:SetText(table.concat(lines, "\n"))
end

rerunText:SetText("Run")
rerun:SetScript("OnClick", run)

-- Separate button: the camera test is the only thing that touches the live character model.
local camera = CreateFrame("Button", nil, spike)
camera:SetWidth(120)
camera:SetHeight(24)
camera:SetPoint("LEFT", rerun, "RIGHT", 8, 0)
camera:SetBackdrop(rerun:GetBackdrop())
camera:SetBackdropColor(0.15, 0.15, 0.15, 1)
local cameraText = camera:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
cameraText:SetPoint("CENTER")
cameraText:SetText("Camera")
camera:SetScript("OnClick", function()
	lines = {}
	testCamera()
	body:SetText(table.concat(lines, "\n"))
end)

-- DELIBERATELY MANUAL. An earlier version auto-ran two frames after the screen appeared, and the
-- client died with ERROR #132 at 0x004EA77F (a null+0x10 read inside the character-create code the
-- DLL's CharacterCreationRaceCrashfix patches). That version also probed all five axes at once,
-- benchmarked 60 more cycles, and moved the model - all in a single frame. Whether or not that was
-- the trigger, nothing here should fire on its own inside the live create screen: the tester
-- chooses the moment, on a screen that is already settled.
spike:SetScript("OnShow", function()
	body:SetText("Ready.\n\nPick a race, gender and class, let the screen settle, then press Run.\n"
		.. "|cffffcc00Nothing is probed until you do.|r")
end)
