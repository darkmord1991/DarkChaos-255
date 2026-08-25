-- Minimal WoW 3.3.5 API simulator.
-- Frames and textures share a method table reached via getmetatable(w).__index,
-- the way the real client exposes them, so metatable polyfills are exercised.
local now = 0
_G.GetTime = function() return now end

local frames = {}
_G.frameCount = 0

local FrameMethods = {}
FrameMethods.__index = FrameMethods
function FrameMethods:SetScript(k, v) self._scripts[k] = v end
function FrameMethods:GetScript(k) return self._scripts[k] end
function FrameMethods:Show() self._shown = true end
function FrameMethods:Hide() self._shown = false end
function FrameMethods:IsShown() return self._shown end
function FrameMethods:IsVisible() return self._shown end
function FrameMethods:SetParent(p) self._parent = p end
function FrameMethods:GetChildren() return unpack(self._children or {}) end
function FrameMethods:SetSize() end
function FrameMethods:SetPoint() end
function FrameMethods:SetHeight() end
function FrameMethods:GetWidth() return 300 end

function FrameMethods:RegisterEvent() end
function FrameMethods:UnregisterEvent() end
function FrameMethods:SetWidth() end
function FrameMethods:GetHeight() return 100 end
function FrameMethods:SetBackdrop() end
function FrameMethods:SetBackdropColor() end
function FrameMethods:EnableMouse() end
function FrameMethods:SetMovable() end
function FrameMethods:RegisterForDrag() end
function FrameMethods:SetFrameStrata() end
function FrameMethods:SetToplevel() end
function FrameMethods:Raise() end
function FrameMethods:SetScrollChild() end
function FrameMethods:SetText() end
function FrameMethods:GetName() return "stub" end

-- widget methods used by options panels / log panel
function FrameMethods:SetChecked(v) self._checked = v end
function FrameMethods:GetChecked() return self._checked end
function FrameMethods:SetNormalTexture() end
function FrameMethods:SetHighlightTexture() end
function FrameMethods:SetPushedTexture() end
function FrameMethods:SetDisabledTexture() end
function FrameMethods:Enable() self._enabled = true end
function FrameMethods:Disable() self._enabled = false end
function FrameMethods:SetEnabled(v) self._enabled = v end
function FrameMethods:IsEnabled() return self._enabled ~= false end
function FrameMethods:SetAutoFocus() end
function FrameMethods:SetNumeric() end
function FrameMethods:SetMaxLetters() end
function FrameMethods:SetCursorPosition() end
function FrameMethods:ClearFocus() end
function FrameMethods:GetText() return self._text or "" end
function FrameMethods:SetFontObject() end
function FrameMethods:SetJustifyH() end
function FrameMethods:SetMinMaxValues() end
function FrameMethods:SetValue(v) self._value = v end
function FrameMethods:GetValue() return self._value or 0 end
function FrameMethods:SetValueStep() end
function FrameMethods:SetObeyStepOnDrag() end
function FrameMethods:SetClampedToScreen() end
function FrameMethods:SetResizable() end
function FrameMethods:SetMinResize() end
function FrameMethods:StartMoving() end
function FrameMethods:StopMovingOrSizing() end
function FrameMethods:SetAlpha() end
function FrameMethods:GetAlpha() return 1 end
function FrameMethods:SetID() end
function FrameMethods:GetID() return 0 end
function FrameMethods:GetParent() return self._parent end
function FrameMethods:GetObjectType() return self._type end
function FrameMethods:SetScrollChild(c) self._scrollChild = c end
function FrameMethods:GetScrollChild() return self._scrollChild end
function FrameMethods:UpdateScrollChildRect() end
function FrameMethods:SetVerticalScroll() end
function FrameMethods:GetVerticalScroll() return 0 end
function FrameMethods:SetScale() end
function FrameMethods:ClearAllPoints() end
function FrameMethods:SetAllPoints() end
function FrameMethods:SetHitRectInsets() end
function FrameMethods:RegisterForClicks() end
function FrameMethods:SetToplevel() end
function FrameMethods:Raise() end
function FrameMethods:IsObjectType() return false end
function FrameMethods:CreateLine() return setmetatable({}, {__index = TextureMethods}) end
function FrameMethods:SetVertexColor() end
function FrameMethods:SetTexture() end
function FrameMethods:SetTexCoord() end

local TextureMethods = {}
TextureMethods.__index = TextureMethods
function TextureMethods:SetAllPoints() end
function TextureMethods:SetTexture(...) self._tex = {...} end
function TextureMethods:SetVertexColor(...) self._vc = {...} end
function TextureMethods:SetPoint() end
function TextureMethods:SetText(t) self._text = t end
function TextureMethods:SetTextColor() end
function TextureMethods:Show() end
function TextureMethods:Hide() end
function TextureMethods:SetJustifyH() end
function TextureMethods:SetFontObject() end
function TextureMethods:SetShadowOffset() end
function TextureMethods:SetShadowColor() end
function TextureMethods:SetJustifyV() end
function TextureMethods:SetWordWrap() end
function TextureMethods:SetNonSpaceWrap() end
function TextureMethods:GetStringWidth() return 100 end
function TextureMethods:SetAlpha() end
function TextureMethods:SetVertexColor() end
function TextureMethods:ClearAllPoints() end
function TextureMethods:SetBlendMode() end
function TextureMethods:SetGradientAlpha() end
function TextureMethods:SetSize() end
function TextureMethods:SetWidth() end
function TextureMethods:SetHeight() end
function TextureMethods:SetTexCoord() end
function TextureMethods:SetDrawLayer() end
function TextureMethods:GetText() return self._text end

function FrameMethods:CreateTexture()
    return setmetatable({}, {__index = TextureMethods})
end
FrameMethods.CreateFontString = FrameMethods.CreateTexture

_G.CreateFrame = function(ftype, name, parent, tmpl)
    _G.frameCount = _G.frameCount + 1
    local f = setmetatable(
        {_shown = false, _scripts = {}, _type = ftype, _parent = parent, _children = {}},
        {__index = FrameMethods})
    if parent and parent._children then parent._children[#parent._children + 1] = f end
    frames[#frames + 1] = f
    return f
end

_G.DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) print("CHAT: " .. m) end}
_G.geterrorhandler = function() return function(m) print("ERR: " .. tostring(m)) end end

function _G.advance(dt)
    now = now + dt
    for _, f in ipairs(frames) do
        if f._shown and f._scripts.OnUpdate then f._scripts.OnUpdate(f, dt) end
    end
end

-- Unknown widget METHODS resolve to a no-op so a smoke test does not become a
-- game of whack-a-mole. Matched on a verb prefix rather than "PascalCase",
-- because several real WoW widget FIELDS are PascalCase too (checkbox.Text,
-- button.Icon); treating those as methods hands the caller a function where it
-- expects a font string.
--
-- Lua patterns have no alternation, so this is a plain prefix list, not "^(a|b)".
local METHOD_PREFIXES = {
    "Set", "Get", "Is", "Has", "Can", "Show", "Hide", "Enable", "Disable",
    "Register", "Unregister", "Clear", "Start", "Stop", "Create", "Add",
    "Remove", "Update", "Play", "Advance", "Toggle", "Raise", "Lower", "Draw",
    "Queue", "Insert", "Select", "Pick", "Scroll", "Highlight", "Click",
    "Lock", "Unlock", "Refresh", "Reset", "Apply", "Attach", "Detach",
    "Save", "Load",
}

local function noop() return nil end

local function methodFallback(_, key)
    if type(key) ~= "string" then return nil end
    for _, prefix in ipairs(METHOD_PREFIXES) do
        if key:sub(1, #prefix) == prefix then return noop end
    end
    return nil
end

setmetatable(FrameMethods, {__index = methodFallback})
setmetatable(TextureMethods, {__index = methodFallback})
