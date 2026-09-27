-- Animation buttons for the mount and pet previews (DC-Collection/UI/ModelAnimationBar.lua).
--
-- The previews are DressUpModels, whose per-frame PlayerModel update puts any animation
-- other than Stand back to Stand, so the bar drives two WotLKExtensions natives:
-- SetModelAnimation (play and hold until the next SetFacing) and GetModelAnimations (what
-- the loaded model has, with durations). They are stubbed here by a model that records what
-- it was told to play, drops its hold on SetFacing like the real widget, and can be made to
-- load late or not at all.

dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local SRC = os.getenv("DC_MODELANIMATIONBAR_FILE") or (ROOT .. [[DC-Collection\UI\ModelAnimationBar.lua]])

local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m)
    else fail = fail + 1; print("  FAIL " .. m) end
end

-- Buttons record their highlight so the active animation can be asserted.
local FrameMethods = getmetatable(CreateFrame("Frame")).__index
function FrameMethods:LockHighlight() self._lit = true end
function FrameMethods:UnlockHighlight() self._lit = false end

_G.GameTooltip = {
    SetOwner = function() end, SetText = function() end, AddLine = function() end,
    Show = function() end, Hide = function() end,
}
_G.DCCollection = { L = {} }
dofile(SRC)
local DC = _G.DCCollection

-- ------------------------------------------------------------------ stub client
local calls = {}   -- { animId, time } for every SetModelAnimation
local function natives()
    _G.SetModelAnimation = function(model, animId)
        calls[#calls + 1] = { animId, GetTime() }
        model._held = animId ~= 0
        if not model._hasModel then
            return 0
        end
        model._current = animId
        return 1
    end
    _G.GetModelAnimations = function(model)
        return model._hasModel and model._anims or nil
    end
end

local function newModel()
    local model = CreateFrame("DressUpModel")
    -- The widget's own SetFacing: re-arms the Stand reset, i.e. drops any hold.
    model.SetFacing = function(self, facing)
        self._facing = facing
        self._held = false
    end
    return model
end

local function lastCall() return calls[#calls] and calls[#calls][1] end
local function run(seconds)
    for _ = 1, math.floor(seconds / 0.01 + 0.5) do advance(0.01) end
end
local function click(bar, key) bar.buttons[key]._scripts.OnClick(bar.buttons[key]) end
local function shown(bar)
    local keys = {}
    for _, key in ipairs(bar.order) do
        if bar.buttons[key]:IsShown() then keys[#keys + 1] = key end
    end
    return table.concat(keys, ",")
end
local function lit(bar)
    for key, button in pairs(bar.buttons) do
        if button._lit then return key end
    end
end

-- What the preview does on every model change: ClearModel, apply, ResetModelPose.
local function loadModel(bar, model, anims, facingReset)
    model._hasModel, model._anims = true, anims
    if facingReset ~= false then model:SetFacing(0) end
    bar:ModelChanged(true)
end

-- Durations in ms, shaped like real previews (census medians).
local HORSE = { [0] = 2800, [4] = 1333, [5] = 800, [37] = 833, [38] = 1000, [39] = 1100,
    [41] = 2267, [42] = 1533, [94] = 4000, [143] = 800 }
local GRYPHON = { [0] = 3000, [4] = 1000, [5] = 700, [37] = 800, [38] = 700, [39] = 900,
    [42] = 1500, [94] = 2000, [135] = 1567 }
local HOVERER = { [0] = 2000, [4] = 1000, [5] = 700, [94] = 3000, [193] = 2000 }

local parent = CreateFrame("Frame"); parent:Show()

-- ----------------------------------------------------------------------- tests
print("== an old DLL without the natives gets no bar ==")
_G.SetModelAnimation, _G.GetModelAnimations = nil, nil
ok(DC:CreateModelAnimationBar(parent, newModel(), "mount") == nil, "no natives -> nil, plain preview")
natives()

print("== a ground mount offers what its model has ==")
local model = newModel()
local bar = DC:CreateModelAnimationBar(parent, model, "mount")
ok(bar ~= nil, "bar built once the natives exist")
ok(shown(bar) == "", "no buttons before a model is on the frame")
loadModel(bar, model, HORSE)
ok(shown(bar) == "idle,walk,run,swim,jump,special", "horse: no Fly button (got " .. shown(bar) .. ")")
ok(#calls == 0, "loading a model sends nothing: the stock Stand logic is untouched")
ok(lit(bar) == "idle", "Idle is the active animation")

print("== a loop plays and holds ==")
click(bar, "run")
ok(lastCall() == 5 and model._held, "Run sent and held")
ok(lit(bar) == "run", "Run highlighted")

print("== Special plays once for its own length, then Run resumes ==")
click(bar, "special")
ok(lastCall() == 94, "MountSpecial sent")
ok(lit(bar) == "special", "Special highlighted while it plays")
run(3.9)
ok(lastCall() == 94, "still playing at 3.9 s of a 4.0 s sequence")
run(0.2)
ok(lastCall() == 5 and lit(bar) == "run", "back to Run after 4.0 s")

print("== Jump chains take-off, a short airtime and landing ==")
local first = #calls + 1
click(bar, "jump")
run(3)
local seq, t = {}, {}
for i = first, #calls do seq[#seq + 1] = calls[i][1]; t[#t + 1] = calls[i][2] end
ok(table.concat(seq, ",") == "37,38,39,5", "JumpStart, Jump, JumpEnd, then Run (got " .. table.concat(seq, ",") .. ")")
ok(math.abs((t[2] - t[1]) - 0.833) < 0.02, "take-off lasts JumpStart's 833 ms")
ok(math.abs((t[3] - t[2]) - 0.4) < 0.02, "airtime capped at 0.4 s")
ok(math.abs((t[4] - t[3]) - 1.1) < 0.02, "landing lasts JumpEnd's 1100 ms")

print("== the chosen loop carries over to the next mount ==")
loadModel(bar, model, GRYPHON)
ok(lastCall() == 5, "Run re-applied on the gryphon once its list is known")
ok(shown(bar) == "idle,walk,run,fly,swim,jump,special", "gryphon: Fly offered (got " .. shown(bar) .. ")")
click(bar, "fly")
ok(lastCall() == 135, "Fly plays the Fly sequence")

print("== a flyer without Fly hovers instead ==")
loadModel(bar, model, HOVERER)
ok(lastCall() == 193, "Fly falls back to Hover")
ok(shown(bar) == "idle,walk,run,fly,special", "hover-only flyer layout (got " .. shown(bar) .. ")")

print("== a model without the chosen loop drops back to Idle ==")
local before = #calls
loadModel(bar, model, HORSE)
ok(#calls == before, "nothing sent: the preview's SetFacing already released the hold")
ok(lit(bar) == "idle" and bar.loopKey == "idle", "Idle is active again")
ok(not bar.buttons.fly:IsShown(), "Fly hidden again")

print("== a model change without a SetFacing still releases the hold ==")
click(bar, "run")
first = #calls + 1
loadModel(bar, model, HORSE, false)
ok(calls[first] and calls[first][1] == 0 and lastCall() == 5, "hold released, then Run re-applied")

print("== turning the model: nothing fights the drag, the loop resumes after ==")
before = #calls
for i = 1, 30 do
    model:SetFacing(i * 0.05)
    advance(0.016)
end
ok(#calls == before, "nothing re-sent while the model is being turned")
ok(not model._held, "the widget's own SetFacing dropped the hold")
run(0.1)
ok(#calls == before + 1 and lastCall() == 5 and model._held, "Run re-applied once the turning stopped")

print("== a turn interrupts a one-shot ==")
click(bar, "special")
model:SetFacing(1)
ok(lit(bar) == "run", "Special cancelled by the turn")
run(0.1)
ok(lastCall() == 5, "back to the Run loop, not the rest of Special")
run(5)
ok(lastCall() == 5, "no stale Special step fires later")

print("== clearing the preview ==")
model._hasModel = false
bar:ModelChanged(false)
ok(lastCall() == 0 and not model._held, "hold released on a frame with no model")
ok(shown(bar) == "", "no buttons without a model")
ok(bar.pendingAnim == nil, "no retry queued for the release")

print("== a model that loads late ==")
model._hasModel, model._anims = true, nil
bar:ModelChanged(true)
ok(shown(bar) == "", "still no buttons while it loads")
run(0.3)
model._anims = HORSE
run(0.02)
ok(shown(bar) == "idle,walk,run,swim,jump,special", "buttons once it has loaded")
ok(lastCall() == 5, "and the chosen loop is applied then")

print("== a model that never loads ==")
model._anims = nil
bar:ModelChanged(true)
run(5.1)
ok(shown(bar) == "", "buttons dropped after the load timeout")
ok(bar.waiting == nil, "polling stopped")

print("== no model object yet: the play is retried, then given up ==")
model._hasModel, model._anims = false, HORSE
bar:Select("walk")
before = #calls
run(0.1)
ok(#calls > before and model._current ~= 4, "retried while the frame has no model")
model._hasModel = true
run(0.02)
ok(model._current == 4, "played as soon as the model exists")
model._hasModel = false
bar:Select("run")
run(5.1)
before = #calls
run(0.5)
ok(#calls == before, "retries stop after the load timeout")

print("== pets ==")
local petModel = newModel()
local petBar = DC:CreateModelAnimationBar(parent, petModel, "pet")
loadModel(petBar, petModel, { [0] = 2000, [4] = 1000, [5] = 800, [16] = 1000, [37] = 800, [39] = 900 })
ok(shown(petBar) == "idle,walk,run,jump,attack", "pet layout: Attack, no Swim (got " .. shown(petBar) .. ")")
first = #calls + 1
click(petBar, "jump")
run(3)
seq = {}
for i = first, #calls do seq[#seq + 1] = calls[i][1] end
ok(table.concat(seq, ",") == "37,39,0", "a missing airborne Jump is skipped (got " .. table.concat(seq, ",") .. ")")
click(petBar, "attack")
run(0.99)
ok(lastCall() == 16, "Attack still playing inside its 1000 ms")
run(0.05)
ok(lastCall() == 0 and not petModel._held, "then back to Idle with the hold released")
loadModel(petBar, petModel, { [0] = 2000 })
ok(shown(petBar) == "", "Idle alone is not worth a bar")

print("== Beastmaster and Forms ==")
local beastModel = newModel()
local beastBar = DC:CreateModelAnimationBar(parent, beastModel, "beast")
loadModel(beastBar, beastModel, { [0] = 2000, [4] = 1000, [5] = 800, [16] = 1000, [37] = 800,
    [38] = 600, [39] = 900, [42] = 1500, [135] = 1200 })
ok(shown(beastBar) == "idle,walk,run,fly,swim,jump,attack",
   "a flying hunter pet flies, swims and attacks (got " .. shown(beastBar) .. ")")
-- FormFrame parents the bar to the preview model itself.
local formModel = newModel()
local formBar = DC:CreateModelAnimationBar(formModel, formModel, "form", { offsetY = 30 })
loadModel(formBar, formModel, { [0] = 2000, [4] = 1000, [5] = 800, [16] = 1000, [42] = 1500 })
ok(shown(formBar) == "idle,walk,run,swim,attack",
   "a form model gets what it has (got " .. shown(formBar) .. ")")
click(formBar, "swim")
ok(lastCall() == 42 and formModel._held, "Swim plays on the form model")
ok(DC:CreateModelAnimationBar(parent, newModel(), "unknown") == nil, "an unknown kind builds no bar")

print("")
print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
