--[[----------------------------------------------------------------------------------------------
DCCharCustomize.lua -- the C_CharacterCreation stand-in for 3.3.5a.

Retail drives its customization UI from C_CharacterCreation.GetAvailableCustomizations() (a
category -> option -> choice tree) and SetCustomizationChoice(optionID, choiceID). Neither exists
here. All 3.3.5a gives Lua is:

    CycleCharCustomization(axis, dir)    -- blind relative step, no return value

and, thanks to WotLK-Extensions, a readback of where you landed:

    GetSkinColorSelection() GetFaceSelection() GetHairStyleSelection()
    GetHairColorSelection() GetFacialHairSelection()

This file turns those two primitives into "how many choices are there" and "jump to choice N".

HOW THE COUNT IS DISCOVERED
Cycle forward, recording the readback each step, until it returns to where it started. The number
of steps is the count, and the recorded values are the enumeration order. Three properties make
this the right approach rather than trusting a generated table:

  * self-restoring   -- a full loop lands back on the original selection, so probing is invisible;
  * authoritative    -- it is the client's own enumerator talking, so it honours Death-Knight
                        gating and any CharSections expansion with no UI redeploy;
  * order-accurate   -- it captures the ACTUAL cycle order, which need not be sorted or contiguous.

DCCharCustomizeData.lua supplies only colour swatches and a cross-check. If the two disagree, the
probe wins.

GRACEFUL DEGRADATION
If the readback is not synchronous -- i.e. the getter still reports the old value immediately after
a cycle -- every probe returns a count of 1. That is detectable (IsProbeTrustworthy), and the UI is
expected to fall back to plain arrow cycling rather than showing a broken palette. Likewise, if the
WXL getters are missing entirely (older DLL), IsAvailable() returns false and the caller should
leave the stock screen alone.
------------------------------------------------------------------------------------------------]]

-- DCApplyAtlas now lives in DCGlueAtlas.lua, shared with the character-select screen.

DCCharCustomize = {}

local AXIS_SKIN, AXIS_FACE, AXIS_HAIR_STYLE, AXIS_HAIR_COLOR, AXIS_FACIAL = 1, 2, 3, 4, 5

DCCharCustomize.AXES = { AXIS_SKIN, AXIS_FACE, AXIS_HAIR_STYLE, AXIS_HAIR_COLOR, AXIS_FACIAL }

-- Resolved by name at call time: the DLL registers these into the glue Lua state, and we must not
-- capture a nil upvalue if this file happens to load first.
local READER_NAME = {
	[AXIS_SKIN]       = "GetSkinColorSelection",
	[AXIS_FACE]       = "GetFaceSelection",
	[AXIS_HAIR_STYLE] = "GetHairStyleSelection",
	[AXIS_HAIR_COLOR] = "GetHairColorSelection",
	[AXIS_FACIAL]     = "GetFacialHairSelection",
}

-- Stock glue strings, so the category headings stay localised and race-correct.
DCCharCustomize.AXIS_LABEL_KEY = {
	[AXIS_SKIN]       = "CHAR_CUSTOMIZATION1_DESC",
	[AXIS_FACE]       = "CHAR_CUSTOMIZATION2_DESC",
	[AXIS_HAIR_STYLE] = "CHAR_CUSTOMIZATION3_DESC",
	[AXIS_HAIR_COLOR] = "CHAR_CUSTOMIZATION4_DESC",
	[AXIS_FACIAL]     = "CHAR_CUSTOMIZATION5_DESC",
}

-- Runaway guard for a single probe. The uint8 wire ceiling is 255, but the largest axis in the
-- real data is 24 (Human Female hair style), so 64 covers everything with wide margin.
--
-- Keep this SMALL on purpose. Every CycleCharCustomization is real work inside the client's
-- character-create path, and a burst of them in one frame is the most dangerous thing this file
-- does. A 256-step ceiling meant a misbehaving readback could fire 256 calls per axis in a single
-- frame; 64 bounds that to something the client comfortably survives, and any axis genuinely
-- larger than 64 would be a data bug worth failing loudly on rather than cycling through.
local MAX_CYCLE = 64

-- Soft ceiling on cycles issued across ALL axes within one frame; consulted before STARTING a
-- probe, charged by actual cycles used.
--
-- Set LOW on purpose: the in-client spike (S0-3, 2026-08-07) measured cycling as COSTLY - each
-- CycleCharCustomization does real recomposite work, ~4ms+ apiece - so probing all five axes in
-- one frame (~45 cycles) is a visible ~180ms hitch at screen-open and on every race change. At 12,
-- roughly one axis probes per frame and the same total work spreads over ~5 frames of small
-- hitches instead. The UI is built for that: deferred axes fill in on later frames.
local MAX_CYCLES_PER_FRAME = 12
local frameBudget, frameBudgetStamp = MAX_CYCLES_PER_FRAME, nil

local cache = {}        -- cacheKey -> { [axis] = probeResult }
local currentKey = nil

local function reader(axis)
	local name = READER_NAME[axis]
	return name and _G[name] or nil
end

--- True when the WXL readback getters are present. An unpatched client ignores custom GlueXML
--- entirely, but an OLDER patched DLL may have the GlueXML unlock without these getters.
function DCCharCustomize.IsAvailable()
	if type(CycleCharCustomization) ~= "function" then
		return false
	end
	for _, axis in ipairs(DCCharCustomize.AXES) do
		if type(reader(axis)) ~= "function" then
			return false
		end
	end
	return true
end

--- TWO stock glue getters lie about their units, and both bit us in-client on 2026-08-07:
---   GetSelectedSex()  returns 2/3 (SEX_MALE/SEX_FEMALE), while all data tables use 0/1.
---   GetSelectedRace() returns a 1-BASED INDEX INTO THE AVAILABLE RACE LIST, not a ChrRaces id -
---                     Troll reports 10 and Draenei reports 5. Indexing race-keyed data with it
---                     silently reads a DIFFERENT race's rows (it painted Blood Elf swatches on
---                     a Troll before this was found).
--- Never index DCCharCustomizeData with the raw getters; always go through RaceSex().

-- fileString (from GetNameForRace) -> ChrRaces id, for the no-DLL fallback path.
local RACE_ID_BY_FILE_STRING = {
	Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Undead = 5, Tauren = 6,
	Gnome = 7, Troll = 8, Goblin = 9, BloodElf = 10, Draenei = 11, Worgen = 12,
}

--- Real ChrRaces id and 0/1 sex for the current selection. Prefers the native (reads the live
--- char-create component directly); falls back to mapping the race's file string.
function DCCharCustomize.RaceSex()
	if type(DCGetCharCreateRaceSex) == "function" then
		local race, sex = DCGetCharCreateRaceSex()
		if race then
			return race, sex
		end
	end

	local sex = GetSelectedSex and GetSelectedSex() or 0
	if sex == 2 then sex = 0 elseif sex == 3 then sex = 1 end

	local race
	if GetNameForRace then
		local _, fileString = GetNameForRace()
		race = fileString and RACE_ID_BY_FILE_STRING[fileString]
	end
	return race, sex
end

--- Cache key. Class matters because Death Knights are offered extra skins and faces.
local function buildKey()
	local race = GetSelectedRace and GetSelectedRace() or 0
	local sex = GetSelectedSex and GetSelectedSex() or 0
	local _, _, classIndex = GetSelectedClass and GetSelectedClass()
	return string.format("%s:%s:%s", tostring(race), tostring(sex), tostring(classIndex or 0))
end

--- Drop cached probes. Call from the race / sex / class change hooks.
function DCCharCustomize.Invalidate()
	cache = {}
	currentKey = nil
end

local function bucket()
	local key = buildKey()
	if key ~= currentKey then
		currentKey = key
		cache[key] = cache[key] or {}
	end
	return cache[key]
end

--- Walk one axis all the way round.
--- Returns { count, sequence = {values in cycle order}, position = {value -> 1-based slot},
---           wrapped = bool }.
local function probeAxis(axis)
	local get = reader(axis)
	if not get then
		return { count = 0, sequence = {}, position = {}, wrapped = false }
	end

	local start = get()
	local sequence = { start }
	local position = { [start] = 1 }
	local wrapped = false
	local cycles = 0

	for _ = 1, MAX_CYCLE do
		CycleCharCustomization(axis, 1)
		cycles = cycles + 1
		local value = get()
		if value == start then
			wrapped = true
			break
		end
		if position[value] then
			-- Returned to a value we have already seen without passing through the start. The
			-- enumeration is not a simple ring; stop extending but keep stepping below so the
			-- selection is restored rather than left drifted.
			break
		end
		sequence[#sequence + 1] = value
		position[value] = #sequence
	end

	if not wrapped then
		-- Restore: keep stepping until we are home again, bounded so a misbehaving readback
		-- cannot spin forever.
		for _ = 1, MAX_CYCLE do
			if get() == start then
				break
			end
			CycleCharCustomization(axis, 1)
			cycles = cycles + 1
		end
	end

	return { count = #sequence, sequence = sequence, position = position,
	         wrapped = wrapped, cycles = cycles }
end

--- True when this frame still has room to start another probe. GetTime() only advances at frame
--- boundaries on this client, so an unchanged timestamp means we are still in the same frame.
local function frameHasBudget()
	local now = GetTime and GetTime() or 0
	if now ~= frameBudgetStamp then
		frameBudgetStamp = now
		frameBudget = MAX_CYCLES_PER_FRAME
	end
	return frameBudget > 0
end

--- Native fast path: DCGetCharCreateChoices(axis) (WotLK-Extensions 2026-08-07+) enumerates the
--- valid indices from the DBC data in microseconds - no cycling, no recomposites, no per-frame
--- spreading. Returns an info table, or nil when the native is absent or has no data (older DLL,
--- unreadable DBCs) - the caller then falls back to the probe.
local function nativeAxisInfo(axis)
	if type(DCGetCharCreateChoices) ~= "function" then
		return nil
	end
	local joined = DCGetCharCreateChoices(axis)
	if type(joined) ~= "string" or joined == "" then
		return nil
	end
	local sequence, position = {}, {}
	for token in string.gmatch(joined, "[^,]+") do
		local value = tonumber(token)
		if value then
			sequence[#sequence + 1] = value
			position[value] = #sequence
		end
	end
	if #sequence == 0 then
		return nil
	end
	return { count = #sequence, sequence = sequence, position = position,
	         wrapped = true, native = true }
end

--- Probe result for one axis, cached per race/gender/class. Native first; the cycling probe is
--- the fallback. Returns a deferred placeholder rather than probing when this frame has already
--- cycled enough; deliberately NOT cached, so the caller gets the real answer on a later frame.
---
--- The two sources can disagree about ORDER: the native returns a sorted std::set, which predicts
--- the client's cycle order rather than observing it. That prediction was untestable for years
--- because every selectable index set in CharSections was contiguous from 0, making sorted order
--- and cycle order numerically identical; Dwarf skin colours 22-25 (retail Wildhammer tattoo tones,
--- 2026-08-07) are the first set where they can part company. Rather than pay a full probe to learn
--- the true order, the panel simply does not depend on it - see SetSlot.
function DCCharCustomize.GetAxisInfo(axis)
	local store = bucket()
	if not store[axis] then
		local info = nativeAxisInfo(axis)
		if not info then
			if not frameHasBudget() then
				return { count = 0, sequence = {}, position = {}, wrapped = false, deferred = true }
			end
			info = probeAxis(axis)
			frameBudget = frameBudget - (info.cycles or 0)
		end
		store[axis] = info
	end
	return store[axis]
end

--- Number of choices on an axis.
function DCCharCustomize.GetCount(axis)
	return DCCharCustomize.GetAxisInfo(axis).count
end

--- Current value on an axis (the raw index the client reports, not a slot number).
function DCCharCustomize.GetCurrent(axis)
	local get = reader(axis)
	return get and get() or 0
end

--- 1-based slot of the current selection within the cycle order, for "3 of 12" style captions.
function DCCharCustomize.GetCurrentSlot(axis)
	local info = DCCharCustomize.GetAxisInfo(axis)
	return info.position[DCCharCustomize.GetCurrent(axis)] or 1
end

--- Replace an axis's cached enumeration with values actually observed from the client.
---
--- Sorted rather than kept in cycle order, purely so the palette stays in a stable, readable order
--- across corrections. Nothing depends on the order matching the client's - see SetSlot.
local function adoptObserved(axis, observed)
	local sequence = {}
	for _, value in ipairs(observed) do
		sequence[#sequence + 1] = value
	end
	table.sort(sequence)

	local position = {}
	for slot, value in ipairs(sequence) do
		position[value] = slot
	end

	bucket()[axis] = { count = #sequence, sequence = sequence, position = position,
	                   wrapped = true, observed = true }
end

--- Jump to the choice shown in a given slot (1-based, in the panel's own display order).
--- Returns true when the readback confirms we landed on it.
---
--- Steps one at a time and CHECKS AFTER EVERY STEP, rather than computing a step count up front and
--- trusting it. That distinction is the whole fix for the mis-selecting palette: the cached
--- enumeration may have the right set of choices in the wrong order, and a precomputed count lands
--- confidently on the wrong one, whereas a verified walk cannot - a bad order costs a few extra
--- cycles instead of selecting something the user did not click.
---
--- The panel therefore never needs to know the client's true cycle order. It only needs to be
--- self-consistent: the swatch in slot N shows the colour of sequence[N], clicking it selects
--- exactly that value, and the selection ring sits on position[current] - all keyed by VALUE, so
--- display stays correct whatever order the client walks internally.
---
--- Cost is bounded by one full lap. The cached order still picks the direction, so when it is right
--- (every race but Dwarf skin today) the walk is the same short path as before; when it is wrong
--- the worst case is a lap that ends back where it started.
function DCCharCustomize.SetSlot(axis, slot)
	local info = DCCharCustomize.GetAxisInfo(axis)
	local count = info.count
	if count <= 1 then
		return false
	end
	slot = ((slot - 1) % count) + 1

	local target = info.sequence[slot]
	if target == nil then
		return false
	end

	local get = reader(axis)
	if not get or get() == target then
		return get ~= nil
	end

	-- Direction is a hint from the cached order; every step re-composites, so prefer the short way.
	local direction = 1
	local from = info.position[get()]
	if from then
		local forward = (slot - from) % count
		if count - forward < forward then
			direction = -1
		end
	end

	-- Stop on returning to where we started rather than after `count` steps: count comes from the
	-- cached enumeration and can be LARGER than the client's real ring (a listed value the client
	-- will not offer), in which case counting steps overshoots and leaves the selection moved.
	-- Watching for the start value ends the lap exactly where it began, whatever the real size is.
	local start = get()
	local seen, seenAt = { start }, { [start] = 1 }
	for _ = 1, MAX_CYCLE do
		CycleCharCustomization(axis, direction)
		local landed = get()
		if landed == target then
			return true
		end
		if landed == start then
			-- A full lap of the CLIENT'S ring without meeting the target: the cached enumeration
			-- offers a choice the client does not. Rather than keep lying about it, adopt what we
			-- just observed - the lap was the probe. This is how an over-counting native corrects
			-- itself (Worgen Male DK lists 8 skin colours from the DBC; the client offers 5).
			adoptObserved(axis, seen)
			return false
		end
		if seenAt[landed] then
			break            -- not a simple ring; leave the cache alone rather than corrupt it
		end
		seen[#seen + 1] = landed
		seenAt[landed] = #seen
	end

	-- The value is not offered on this axis. The lap is self-restoring, so the selection is back
	-- where the user left it.
	return false
end

--- Jump to a raw index value rather than a slot.
function DCCharCustomize.SetChoice(axis, value)
	local info = DCCharCustomize.GetAxisInfo(axis)
	local slot = info.position[value]
	if not slot then
		return false
	end
	return DCCharCustomize.SetSlot(axis, slot)
end

--- Step one choice on behalf of the arrow buttons, using the result as a free consistency check.
---
--- Arrows are always correct on their own - they just hand the step to the client - but they also
--- reveal a wrong enumeration for nothing: if the client does not land where the cached order said
--- it would, the cache is over-promising (typically listing choices the client will not offer, as
--- the DBC does for Worgen Male Death Knight skins). Walking the ring once then costs a lap and
--- ends exactly where it began, and the caption stops claiming choices that are not there.
function DCCharCustomize.CycleAxis(axis, direction)
	local get = reader(axis)
	if not get then
		CycleCharCustomization(axis, direction)
		return
	end

	local info = DCCharCustomize.GetAxisInfo(axis)
	local before = info.position[get()]
	CycleCharCustomization(axis, direction)

	if info.observed or info.count < 2 or not before then
		return                              -- already trusted, or nothing to compare against
	end
	local expected = info.sequence[((before - 1 + direction) % info.count) + 1]
	if get() == expected then
		return
	end

	local start = get()
	local seen, seenAt = { start }, { [start] = true }
	for _ = 1, MAX_CYCLE do
		CycleCharCustomization(axis, 1)
		local landed = get()
		if landed == start then
			adoptObserved(axis, seen)
			return
		end
		if seenAt[landed] then
			return                          -- not a simple ring; leave the cache alone
		end
		seen[#seen + 1] = landed
		seenAt[landed] = true
	end
end

--- Swatch colour for a slot, or nil. Skin and hair colour only; the other axes are previewed on
--- the 3D model. Falls back to nil when the generated table is older than the client data.
function DCCharCustomize.GetSwatch(axis, slot)
	if not DCCharCustomizeData then
		return nil
	end
	local race, sex = DCCharCustomize.RaceSex()
	local byRace = race and DCCharCustomizeData[race]
	local bySex = byRace and sex and byRace[sex]
	local entry = bySex and bySex[axis]
	if not (entry and entry.swatch) then
		return nil
	end

	local info = DCCharCustomize.GetAxisInfo(axis)
	local value = info.sequence[slot]
	local rgb = value and entry.swatch[value]
	if rgb then
		return rgb[1], rgb[2], rgb[3]
	end
	return nil
end

--- The GetAvailableCustomizations() stand-in: the tree the UI renders.
--- Two categories, because five axes do not justify more; Tier 3 would add to this.
function DCCharCustomize.GetAvailableCustomizations()
	local categories = {
		{ name = "Body", axes = { AXIS_SKIN, AXIS_FACE } },
		{ name = "Hair", axes = { AXIS_HAIR_STYLE, AXIS_HAIR_COLOR, AXIS_FACIAL } },
	}

	local out = {}
	for _, category in ipairs(categories) do
		local options = {}
		for _, axis in ipairs(category.axes) do
			local count = DCCharCustomize.GetCount(axis)
			-- An axis with nothing on it is hidden rather than shown as an empty picker.
			if count > 0 then
				options[#options + 1] = {
					axis = axis,
					name = _G[DCCharCustomize.AXIS_LABEL_KEY[axis]] or ("Option " .. axis),
					count = count,
					currentSlot = DCCharCustomize.GetCurrentSlot(axis),
					hasSwatches = (axis == AXIS_SKIN or axis == AXIS_HAIR_COLOR),
				}
			end
		end
		if #options > 0 then
			out[#out + 1] = { name = category.name, options = options }
		end
	end
	return out
end

--- Sanity gate for the whole design. If the readback is not synchronous every probe collapses to
--- a count of 1, so compare against the offline table: when the generated data says an axis has
--- several choices and the probe insists on one, the probe is lying and the caller should fall
--- back to plain arrow cycling.
function DCCharCustomize.IsProbeTrustworthy()
	if not DCCharCustomizeData then
		return true      -- nothing to compare against; assume the probe is fine
	end
	local race, sex = DCCharCustomize.RaceSex()
	local bySex = race and sex and DCCharCustomizeData[race]
		and DCCharCustomizeData[race][sex]
	if not bySex then
		return true
	end

	local suspicious = 0
	for _, axis in ipairs(DCCharCustomize.AXES) do
		local expected = bySex[axis] and #bySex[axis].indices or 0
		if expected > 1 and DCCharCustomize.GetCount(axis) <= 1 then
			suspicious = suspicious + 1
		end
	end
	return suspicious < 2
end
