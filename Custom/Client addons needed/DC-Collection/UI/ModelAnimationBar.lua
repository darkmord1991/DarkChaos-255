--[[
    DC-Collection UI/ModelAnimationBar.lua
    ======================================

    Animation buttons for the Mounts, Pets, Beastmaster and Forms 3D previews:
    Idle, Walk, Run, Fly, Swim, Jump, Attack and Special -- Special being
    MountSpecial, what a mount does when you jump while standing still.

    Built only when the WotLKExtensions DLL has the two natives below
    (CustomLua.cpp, DC_NATIVE_MODELANIMATION). Model:SetSequence cannot do this
    on its own: the previews are DressUpModels, and PlayerModel's per-frame
    update puts any animation other than Stand back to Stand before the model
    is drawn.
      SetModelAnimation(model, animId)  plays the animation and holds it until
                                        the next SetFacing; 0 = stock again
      GetModelAnimations(model)         { [animId] = durationMs } of the loaded
                                        model, nil until it is loaded
    The table decides which buttons a model gets -- a model without the
    animation would play the AnimationData fallback instead (Fly -> Swim ->
    Walk, the others -> Stand) -- and its durations end the one-shots on time.

    Every animation offered is embedded in the preview .m2 files: a census of
    patch_g_staging (1,519 mount and 1,696 pet previews, 2026-09-25) found none
    that needs an external .anim, which the preview archives do not ship.

    Usage: bar = DC:CreateModelAnimationBar(previewFrame, model, kind[, options])
    with kind "mount", "pet", "beast" or "form" and options.offsetY to lift the
    bar off the preview's bottom edge; then bar:ModelChanged(hasModel) whenever
    the preview loads or clears a model.
]]

local DC = DCCollection
local L = DC and DC.L or {}

-- AnimationData ids (3.3.5a).
local ANIM_STAND = 0
local ANIM_WALK = 4
local ANIM_RUN = 5
local ANIM_ATTACK = 16
local ANIM_JUMP_START = 37
local ANIM_JUMP = 38
local ANIM_JUMP_END = 39
local ANIM_SWIM = 42
local ANIM_MOUNT_SPECIAL = 94
local ANIM_FLY = 135
local ANIM_HOVER = 193

local BUTTON_HEIGHT = 20
local BUTTON_MIN_WIDTH = 52
local BUTTON_TEXT_PADDING = 18
local BUTTON_GAP = 4

-- How long the airborne Jump loop is held between take-off and landing.
local JUMP_AIRTIME = 0.4
-- Floor for a step whose sequence claims next to no length.
local MIN_STEP_SECONDS = 0.25
-- Hold again this soon after the last SetFacing. PlayerModel's own Stand reset
-- fires 100 ms after it, so getting in first avoids a flash of Stand.
local FACING_SETTLE_SECONDS = 0.08
-- Stop waiting on a model that never finishes loading.
local LOAD_TIMEOUT_SECONDS = 5

-- loop:  candidates; the first one the model has plays until something else is
--        picked, and survives switching to another mount or pet.
-- steps: played once in order, then back to the loop. A step the model lacks
--        is skipped; the first step decides whether the button is offered.
local ACTIONS = {
    idle = { label = "ANIM_IDLE", fallback = "Idle", loop = { ANIM_STAND } },
    walk = { label = "ANIM_WALK", fallback = "Walk", loop = { ANIM_WALK } },
    run = { label = "ANIM_RUN", fallback = "Run", loop = { ANIM_RUN } },
    -- 228 of the flying previews have Hover but no Fly.
    fly = { label = "ANIM_FLY", fallback = "Fly", loop = { ANIM_FLY, ANIM_HOVER } },
    swim = { label = "ANIM_SWIM", fallback = "Swim", loop = { ANIM_SWIM } },
    jump = {
        label = "ANIM_JUMP", fallback = "Jump",
        steps = { ANIM_JUMP_START, ANIM_JUMP, ANIM_JUMP_END },
    },
    attack = { label = "ANIM_ATTACK", fallback = "Attack", steps = { ANIM_ATTACK } },
    special = {
        label = "ANIM_SPECIAL", fallback = "Special",
        tip = "ANIM_SPECIAL_TIP", tipFallback = "What a mount does when you jump while standing still.",
        steps = { ANIM_MOUNT_SPECIAL },
    },
}

local LAYOUTS = {
    mount = { "idle", "walk", "run", "fly", "swim", "jump", "special" },
    pet = { "idle", "walk", "run", "fly", "jump", "attack", "special" },
    -- Hunter pets and druid forms fight and swim as well; the model still
    -- decides which of these it gets (Flight Form flies, Aquatic Form swims).
    beast = { "idle", "walk", "run", "fly", "swim", "jump", "attack", "special" },
    form = { "idle", "walk", "run", "fly", "swim", "jump", "attack", "special" },
}

local DEFAULT_OFFSET_Y = 8

local function Localized(key, fallback)
    local text = L[key]
    if type(text) == "string" and text ~= "" then
        return text
    end
    return fallback
end

local Bar = {}
Bar.__index = Bar

-- Plays animId and holds it; ANIM_STAND hands the model back to the stock
-- Stand logic. False when the frame has no model object yet -- OnUpdate retries.
function Bar:Play(animId)
    local ok, played = pcall(SetModelAnimation, self.model, animId)
    self.held = animId ~= ANIM_STAND
    if ok and played == 1 then
        self.pendingAnim = nil
        return true
    end

    if self.pendingAnim ~= animId then
        self.pendingAnim = animId
        self.pendingLeft = LOAD_TIMEOUT_SECONDS
    end
    return false
end

-- The animation a looping action plays on the current model: the first
-- candidate it has, or the first candidate while its list is not known yet.
function Bar:LoopAnim(key)
    local candidates = ACTIONS[key].loop
    if not self.anims then
        return candidates[1]
    end

    for _, animId in ipairs(candidates) do
        if self.anims[animId] then
            return animId
        end
    end
    return nil
end

function Bar:Offers(key)
    if key == "idle" then
        return true
    end
    if not self.anims then
        return false
    end

    local action = ACTIONS[key]
    for _, animId in ipairs(action.loop or { action.steps[1] }) do
        if self.anims[animId] then
            return true
        end
    end
    return false
end

function Bar:RefreshHighlight()
    local active = self.steps and self.stepKey or self.loopKey
    for key, button in pairs(self.buttons) do
        if key == active then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

-- Back to the chosen looping animation, or to Idle when this model lacks it.
function Bar:ApplyLoop()
    self.steps = nil
    local animId = self:LoopAnim(self.loopKey)
    if not animId then
        self.loopKey = "idle"
        animId = ANIM_STAND
    end

    -- Without a hold on the widget the model is already on the stock Stand.
    if animId ~= ANIM_STAND or self.held then
        self:Play(animId)
    end
    self:RefreshHighlight()
end

function Bar:NextStep()
    self.stepIndex = self.stepIndex + 1
    local step = self.steps[self.stepIndex]
    if not step then
        self:ApplyLoop()
        return
    end

    self.stepLeft = step.seconds
    self:Play(step.animId)
    self:RefreshHighlight()
end

function Bar:StartSteps(key)
    local steps = {}
    for index, animId in ipairs(ACTIONS[key].steps) do
        local ms = self.anims and self.anims[animId]
        if ms or index == 1 then
            local seconds = (ms or 0) / 1000
            if animId == ANIM_JUMP then
                seconds = math.min(seconds, JUMP_AIRTIME)
            end
            steps[#steps + 1] = { animId = animId, seconds = math.max(seconds, MIN_STEP_SECONDS) }
        end
    end

    self.steps = steps
    self.stepKey = key
    self.stepIndex = 0
    self:NextStep()
end

function Bar:Select(key)
    self.settleLeft = nil
    if ACTIONS[key].steps then
        self:StartSteps(key)
    else
        self.loopKey = key
        self:ApplyLoop()
    end
end

function Bar:Layout()
    local shown, width = {}, 0
    for _, key in ipairs(self.order) do
        local button = self.buttons[key]
        if self.hasModel and self:Offers(key) then
            shown[#shown + 1] = button
            width = width + button.dcWidth
        else
            button:Hide()
        end
    end

    -- Idle on its own is not worth a bar.
    if #shown < 2 then
        for _, button in ipairs(shown) do
            button:Hide()
        end
        return
    end

    self.frame:SetWidth(width + (#shown - 1) * BUTTON_GAP)
    local x = 0
    for _, button in ipairs(shown) do
        button:ClearAllPoints()
        button:SetPoint("LEFT", self.frame, "LEFT", x, 0)
        button:Show()
        x = x + button.dcWidth + BUTTON_GAP
    end
end

function Bar:PollAnimations(elapsed)
    local ok, anims = pcall(GetModelAnimations, self.model)
    if ok and type(anims) == "table" then
        self.waiting = nil
        self.anims = anims
        self.hasModel = true
        self:Layout()
        if self.loopKey ~= "idle" and not self.steps then
            self:ApplyLoop()
        end
        return
    end

    self.waiting = self.waiting + elapsed
    if self.waiting >= LOAD_TIMEOUT_SECONDS then
        self.waiting = nil
        self.hasModel = false
        self:Layout()
    end
end

-- Call after the preview put a model on the frame (hasModel) or cleared it.
function Bar:ModelChanged(hasModel)
    self.steps = nil
    self.settleLeft = nil
    self.pendingAnim = nil

    if not hasModel then
        self.waiting = nil
        self.hasModel = false
        if self.held then
            -- Drops the hold even with no model on the frame.
            self:Play(ANIM_STAND)
            self.pendingAnim = nil
        end
        self:Layout()
        return
    end

    -- The new model starts on the stock Stand. The chosen loop follows once the
    -- model's own animation list is known; the old model's may not apply to it.
    if self.held then
        self:Play(ANIM_STAND)
    end
    self.waiting = 0
    self:RefreshHighlight()
    self:PollAnimations(0)
end

-- PlayerModel's SetFacing re-arms the widget's Stand reset (and may play a
-- shuffle step), so whatever was held is re-applied once the turning stops.
function Bar:FacingChanged()
    if self.held or self.steps or self.settleLeft then
        self.held = false
        self.steps = nil
        self.settleLeft = FACING_SETTLE_SECONDS
        self:RefreshHighlight()
    end
end

function Bar:OnUpdate(elapsed)
    if self.waiting then
        self:PollAnimations(elapsed)
    end

    if self.pendingAnim then
        self.pendingLeft = self.pendingLeft - elapsed
        if self.pendingLeft <= 0 then
            self.pendingAnim = nil
        else
            self:Play(self.pendingAnim)
        end
    end

    if self.settleLeft then
        self.settleLeft = self.settleLeft - elapsed
        if self.settleLeft <= 0 then
            self.settleLeft = nil
            self:ApplyLoop()
        end
    end

    if self.steps then
        self.stepLeft = self.stepLeft - elapsed
        if self.stepLeft <= 0 then
            self:NextStep()
        end
    end
end

local function ShowTooltip(button)
    local action = button.dcAction
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(Localized(action.label, action.fallback))
    GameTooltip:AddLine(Localized(action.tip, action.tipFallback), 1, 1, 1, true)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- Returns nil on a DLL without the natives, so callers keep a plain preview.
function DC:CreateModelAnimationBar(parent, model, kind, options)
    if type(SetModelAnimation) ~= "function" or type(GetModelAnimations) ~= "function" then
        return nil
    end

    local order = LAYOUTS[kind]
    if not parent or not model or not order then
        return nil
    end

    local bar = setmetatable({
        model = model,
        order = order,
        buttons = {},
        loopKey = "idle",
    }, Bar)

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(BUTTON_HEIGHT)
    frame:SetPoint("BOTTOM", parent, "BOTTOM", 0,
        (options and tonumber(options.offsetY)) or DEFAULT_OFFSET_Y)
    -- Above the mouse-enabled model, which would otherwise swallow the clicks.
    frame:SetFrameLevel((model:GetFrameLevel() or parent:GetFrameLevel() or 0) + 5)
    bar.frame = frame

    for _, key in ipairs(order) do
        local action = ACTIONS[key]
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetText(Localized(action.label, action.fallback))
        button.dcWidth = math.max(BUTTON_MIN_WIDTH,
            math.ceil((button:GetTextWidth() or 0) + BUTTON_TEXT_PADDING))
        button:SetSize(button.dcWidth, BUTTON_HEIGHT)
        button:SetScript("OnClick", function()
            bar:Select(key)
        end)
        if action.tip then
            button.dcAction = action
            button:SetScript("OnEnter", ShowTooltip)
            button:SetScript("OnLeave", HideTooltip)
        end
        button:Hide()
        bar.buttons[key] = button
    end

    frame:SetScript("OnUpdate", function(_, elapsed)
        bar:OnUpdate(elapsed)
    end)
    frame:Show()

    -- Drags, pose resets and the right-click camera reset all call SetFacing
    -- through the frame, so wrapping it here sees every one of them.
    local setFacing = model.SetFacing
    if type(setFacing) == "function" then
        model.SetFacing = function(self, ...)
            setFacing(self, ...)
            bar:FacingChanged()
        end
    end

    return bar
end
