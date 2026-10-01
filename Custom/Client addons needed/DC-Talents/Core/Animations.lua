--[[
	DC-Talents - retail AnimationGroup semantics in Lua.

	3.3.5 animation groups only animate their own region, have no fromAlpha/toAlpha, no childKey or
	target, no FlipBook and no TextureCoordTranslation. Retail talent UI templates use all of those,
	so animation groups created for the port are plain Lua objects driven by one OnUpdate frame:

	  * animations with the same order run together; each order lasts max(startDelay + duration +
	    endDelay) of its members,
	  * looping NONE / REPEAT / BOUNCE, Play(reverse, offset), Stop, Pause, Restart, Finish,
	  * group scripts OnPlay / OnFinished / OnStop / OnLoop / OnUpdate / OnPause,
	  * targets: childKey / targetKey ("$parent.Foo" paths from the group's owner), target (global
	    name) or the owner itself,
	  * when a group ends, transforms (translation, scale, rotation, texture coordinates) snap back;
	    alpha stays at its final value only with setToFinalAlpha, like retail.
]]

local _, ns = ...
setfenv(1, ns.env)

local Anim = {}
ns.Anim = Anim

local groupsByOwner = setmetatable({}, { __mode = "k" })
local active = {}
local driver

local function Smooth(progress, smoothing)
	if smoothing == "IN" then
		return progress * progress
	elseif smoothing == "OUT" then
		return 1 - (1 - progress) * (1 - progress)
	elseif smoothing == "IN_OUT" then
		if progress < 0.5 then
			return 2 * progress * progress
		end
		return 1 - 2 * (1 - progress) * (1 - progress)
	end
	return progress
end

-- ----------------------------------------------------------------------------
-- Animations
-- ----------------------------------------------------------------------------

local AnimationMethods = {}
local AnimationMeta = { __index = AnimationMethods }

function AnimationMethods:GetParent()
	return self.group
end

function AnimationMethods:GetRegionParent()
	return self.group.owner
end

function AnimationMethods:GetObjectType()
	return self.animType
end

function AnimationMethods:IsObjectType(objectType)
	return objectType == self.animType or objectType == "Animation"
end

function AnimationMethods:GetName()
	return self.name
end

function AnimationMethods:SetTarget(target)
	self.target = target
	self.childKey = nil
end

function AnimationMethods:SetChildKey(key)
	self.childKey = key
	self.target = nil
end

AnimationMethods.SetTargetKey = AnimationMethods.SetChildKey

function AnimationMethods:SetTargetName(name)
	self.targetName = name
	self.target = nil
end

function AnimationMethods:SetTargetParent()
	self.target = nil
	self.childKey = nil
end

function AnimationMethods:GetTarget()
	if self.target then
		return self.target
	end
	local owner = self.group.owner
	if self.childKey then
		local key = self.childKey
		if not key:find("$parent", 1, true) then
			return owner[key]
		end
		return ns.XML.ResolveRelativeKey(owner, key)
	end
	if self.targetName then
		local parent = owner.GetParent and owner:GetParent()
		local name = self.targetName:gsub("%$parent", parent and parent.GetName and parent:GetName() or "")
		return ns.realG[name]
	end
	return owner
end

function AnimationMethods:SetDuration(duration)
	self.duration = duration or 0
end

function AnimationMethods:GetDuration()
	return self.duration or 0
end

function AnimationMethods:SetStartDelay(delay)
	self.startDelay = delay or 0
end

function AnimationMethods:GetStartDelay()
	return self.startDelay or 0
end

function AnimationMethods:SetEndDelay(delay)
	self.endDelay = delay or 0
end

function AnimationMethods:GetEndDelay()
	return self.endDelay or 0
end

function AnimationMethods:SetOrder(order)
	self.order = order or 1
	self.group.scheduleDirty = true
end

function AnimationMethods:GetOrder()
	return self.order or 1
end

function AnimationMethods:SetSmoothing(smoothing)
	self.smoothing = smoothing
end

function AnimationMethods:GetSmoothing()
	return self.smoothing or "NONE"
end

-- Alpha
function AnimationMethods:SetFromAlpha(alpha)
	self.fromAlpha = alpha
end

function AnimationMethods:GetFromAlpha()
	return self.fromAlpha or 0
end

function AnimationMethods:SetToAlpha(alpha)
	self.toAlpha = alpha
end

function AnimationMethods:GetToAlpha()
	return self.toAlpha or 0
end

function AnimationMethods:SetChange(change)
	self.change = change
end

-- Translation / TextureCoordTranslation
function AnimationMethods:SetOffset(x, y)
	self.offsetX, self.offsetY = x or 0, y or 0
end

function AnimationMethods:GetOffset()
	return self.offsetX or 0, self.offsetY or 0
end

-- Scale
function AnimationMethods:SetScaleFrom(x, y)
	self.fromScaleX, self.fromScaleY = x, y
end

AnimationMethods.SetFromScale = AnimationMethods.SetScaleFrom

function AnimationMethods:SetScaleTo(x, y)
	self.toScaleX, self.toScaleY = x, y
end

AnimationMethods.SetToScale = AnimationMethods.SetScaleTo

function AnimationMethods:SetScale(x, y)
	self.fromScaleX, self.fromScaleY = 1, 1
	self.toScaleX, self.toScaleY = x, y
end

function AnimationMethods:SetOrigin(point, x, y)
	self.originPoint, self.originX, self.originY = point, x, y
end

-- Rotation
function AnimationMethods:SetDegrees(degrees)
	self.radians = math.rad(degrees or 0)
end

function AnimationMethods:GetDegrees()
	return math.deg(self.radians or 0)
end

function AnimationMethods:SetRadians(radians)
	self.radians = radians or 0
end

function AnimationMethods:GetRadians()
	return self.radians or 0
end

-- FlipBook
function AnimationMethods:SetFlipBookRows(rows)
	self.flipRows = rows
end

function AnimationMethods:SetFlipBookColumns(columns)
	self.flipColumns = columns
end

function AnimationMethods:SetFlipBookFrames(frames)
	self.flipFrames = frames
end

function AnimationMethods:SetFlipBookFrameWidth(width)
	self.flipFrameWidth = width
end

function AnimationMethods:SetFlipBookFrameHeight(height)
	self.flipFrameHeight = height
end

-- VertexColor
function AnimationMethods:SetStartColor(color)
	self.startColor = color
end

function AnimationMethods:SetEndColor(color)
	self.endColor = color
end

function AnimationMethods:SetScript(handler, func)
	self.scripts = self.scripts or {}
	self.scripts[handler] = func
end

function AnimationMethods:GetScript(handler)
	return self.scripts and self.scripts[handler]
end

function AnimationMethods:HookScript(handler, func)
	local previous = self:GetScript(handler)
	if previous then
		self:SetScript(handler, function(...)
			previous(...)
			func(...)
		end)
	else
		self:SetScript(handler, func)
	end
end

function AnimationMethods:IsPlaying()
	return self.group:IsPlaying() and self.started and not self.done
end

function AnimationMethods:IsDone()
	return self.done == true
end

function AnimationMethods:IsDelaying()
	return self.group:IsPlaying() and not self.started
end

function AnimationMethods:GetProgress()
	return self.progress or 0
end

function AnimationMethods:GetSmoothProgress()
	return Smooth(self.progress or 0, self.smoothing)
end

function AnimationMethods:GetElapsed()
	return (self.progress or 0) * (self.duration or 0)
end

function AnimationMethods:Play()
	self.group:Play()
end

function AnimationMethods:Stop()
	self.group:Stop()
end

function AnimationMethods:Pause()
	self.group:Pause()
end

function AnimationMethods:Restart()
	self.group:Restart()
end

local function FireAnimationScript(animation, handler, ...)
	local func = animation.scripts and animation.scripts[handler]
	if func then
		ns.SafeCall(func, animation, ...)
	end
end

-- ----------------------------------------------------------------------------
-- Target state: captured at Play, restored when the group ends
-- ----------------------------------------------------------------------------

local function CaptureState(target)
	local state = { alpha = target:GetAlpha() }
	if target.GetNumPoints then
		state.points = {}
		for i = 1, target:GetNumPoints() do
			state.points[i] = { target:GetPoint(i) }
		end
	end
	if target.GetTexCoord then
		state.texCoord = { target:GetTexCoord() }
	end
	if target.GetScale then
		state.scale = target:GetScale()
	end
	if target.GetSize then
		state.width, state.height = target:GetSize()
	end
	if target.GetVertexColor then
		state.vertexColor = { target:GetVertexColor() }
	end
	return state
end

local function ApplyTranslation(target, state, dx, dy)
	if not state.points or #state.points == 0 then
		return
	end
	target:ClearAllPoints()
	for _, point in ipairs(state.points) do
		target:SetPoint(point[1], point[2], point[3], (point[4] or 0) + dx, (point[5] or 0) + dy)
	end
end

local function RestoreState(target, state, keepAlpha)
	if not keepAlpha and state.alpha then
		target:SetAlpha(state.alpha)
	end
	if state.translated then
		ApplyTranslation(target, state, 0, 0)
		state.translated = nil
	end
	if state.scaled then
		local objectType = target.GetObjectType and target:GetObjectType()
		if objectType == "Texture" or objectType == "FontString" then
			if state.width and state.height and state.width > 0 then
				target:SetSize(state.width, state.height)
			end
		elseif target.SetScale and state.scale then
			target:SetScale(state.scale)
		end
		state.scaled = nil
	end
	if state.texCoordChanged and state.texCoord and #state.texCoord == 8 then
		target:SetTexCoord(unpack(state.texCoord))
		state.texCoordChanged = nil
	end
	if state.colored and state.vertexColor then
		target:SetVertexColor(unpack(state.vertexColor))
		state.colored = nil
	end
end

-- ----------------------------------------------------------------------------
-- Groups
-- ----------------------------------------------------------------------------

local GroupMethods = {}
local GroupMeta = { __index = GroupMethods }

function GroupMethods:GetParent()
	return self.owner
end

function GroupMethods:GetName()
	return self.name
end

function GroupMethods:GetObjectType()
	return "AnimationGroup"
end

function GroupMethods:IsObjectType(objectType)
	return objectType == "AnimationGroup"
end

function GroupMethods:CreateAnimation(animType, name, template)
	local animation = setmetatable({
		group = self,
		animType = animType or "Animation",
		name = name,
		order = 1,
		duration = 0,
		startDelay = 0,
		endDelay = 0,
	}, AnimationMeta)
	self.animations[#self.animations + 1] = animation
	self.scheduleDirty = true
	return animation
end

function GroupMethods:GetAnimations()
	return unpack(self.animations)
end

function GroupMethods:SetLooping(looping)
	self.looping = looping or "NONE"
end

function GroupMethods:GetLooping()
	return self.looping or "NONE"
end

function GroupMethods:GetLoopState()
	return self.reverse and "REVERSE" or "FORWARD"
end

function GroupMethods:SetToFinalAlpha(value)
	self.toFinalAlpha = value and true or false
end

function GroupMethods:IsSetToFinalAlpha()
	return self.toFinalAlpha == true
end

function GroupMethods:SetSpeedMultiplier(multiplier)
	self.speed = multiplier or 1
end

function GroupMethods:GetSpeedMultiplier()
	return self.speed or 1
end

function GroupMethods:SetScript(handler, func)
	self.scripts[handler] = func
end

function GroupMethods:GetScript(handler)
	return self.scripts[handler]
end

function GroupMethods:HookScript(handler, func)
	local previous = self.scripts[handler]
	if previous then
		self.scripts[handler] = function(...)
			previous(...)
			func(...)
		end
	else
		self.scripts[handler] = func
	end
end

local function FireGroupScript(group, handler, ...)
	local func = group.scripts[handler]
	if func then
		ns.SafeCall(func, group, ...)
	end
end

local function BuildSchedule(group)
	local orders = {}
	local lengths = {}
	for _, animation in ipairs(group.animations) do
		local order = animation.order or 1
		local length = (animation.startDelay or 0) + (animation.duration or 0) + (animation.endDelay or 0)
		if not lengths[order] then
			orders[#orders + 1] = order
			lengths[order] = length
		elseif length > lengths[order] then
			lengths[order] = length
		end
	end
	table.sort(orders)

	local starts = {}
	local total = 0
	for _, order in ipairs(orders) do
		starts[order] = total
		total = total + lengths[order]
	end

	group.orderStarts = starts
	group.totalDuration = total
	group.scheduleDirty = false
end

function GroupMethods:GetDuration()
	if self.scheduleDirty or not self.totalDuration then
		BuildSchedule(self)
	end
	return self.totalDuration
end

function GroupMethods:IsPlaying()
	return self.playing == true and not self.paused
end

function GroupMethods:IsPaused()
	return self.paused == true
end

function GroupMethods:IsDone()
	return self.done == true
end

function GroupMethods:IsPendingFinish()
	return false
end

function GroupMethods:GetProgress()
	local total = self:GetDuration()
	if total <= 0 then
		return self.done and 1 or 0
	end
	return math.min(1, (self.elapsed or 0) / total)
end

function GroupMethods:GetElapsed()
	return self.elapsed or 0
end

local function CaptureTargets(group)
	group.states = {}
	for _, animation in ipairs(group.animations) do
		local target = animation:GetTarget()
		if target and not group.states[target] then
			group.states[target] = CaptureState(target)
		end
		animation.started = false
		animation.done = false
		animation.progress = 0
	end
end

local function ApplyAnimation(group, animation, target, state, progress)
	local eased = Smooth(progress, animation.smoothing)
	local animType = animation.animType

	if animType == "Alpha" then
		local from = animation.fromAlpha
		local to = animation.toAlpha
		if animation.change and not from and not to then
			from = state.alpha or 1
			to = from + animation.change
		end
		from = from or 0
		to = to or 0
		target:SetAlpha(math.max(0, math.min(1, from + (to - from) * eased)))
	elseif animType == "Translation" or animType == "LineTranslation" then
		state.dx = (state.dx or 0) + (animation.offsetX or 0) * eased
		state.dy = (state.dy or 0) + (animation.offsetY or 0) * eased
		state.translated = true
	elseif animType == "Scale" or animType == "LineScale" then
		local fromX, fromY = animation.fromScaleX or 1, animation.fromScaleY or 1
		local toX, toY = animation.toScaleX or 1, animation.toScaleY or 1
		state.sx = (state.sx or 1) * (fromX + (toX - fromX) * eased)
		state.sy = (state.sy or 1) * (fromY + (toY - fromY) * eased)
		state.scaled = true
	elseif animType == "Rotation" then
		if target.SetRotation then
			state.rotation = (state.rotation or 0) + (animation.radians or 0) * eased
			state.rotated = true
		end
	elseif animType == "TextureCoordTranslation" then
		state.du = (state.du or 0) + (animation.offsetX or 0) * eased
		state.dv = (state.dv or 0) + (animation.offsetY or 0) * eased
		state.texShifted = true
	elseif animType == "FlipBook" then
		local frames = animation.flipFrames or ((animation.flipRows or 1) * (animation.flipColumns or 1))
		if frames > 0 then
			state.flipFrame = math.min(frames - 1, math.floor(progress * frames))
			state.flipAnimation = animation
		end
	elseif animType == "VertexColor" then
		local startColor, endColor = animation.startColor, animation.endColor
		if startColor and endColor and target.SetVertexColor then
			target:SetVertexColor(
				startColor.r + (endColor.r - startColor.r) * eased,
				startColor.g + (endColor.g - startColor.g) * eased,
				startColor.b + (endColor.b - startColor.b) * eased,
				(startColor.a or 1) + ((endColor.a or 1) - (startColor.a or 1)) * eased)
			state.colored = true
		end
	end
end

local function CommitTransforms(target, state)
	if state.translated then
		ApplyTranslation(target, state, state.dx or 0, state.dy or 0)
	end
	if state.scaled then
		local objectType = target.GetObjectType and target:GetObjectType()
		if objectType == "Texture" or objectType == "FontString" then
			if state.width and state.height and state.width > 0 and (target.GetNumPoints and target:GetNumPoints() <= 1) then
				target:SetSize(state.width * (state.sx or 1), state.height * (state.sy or 1))
			end
		elseif target.SetScale and state.scale then
			target:SetScale(math.max(0.001, state.scale * math.max(state.sx or 1, state.sy or 1)))
		end
	end
	if state.rotated then
		target:SetRotation(state.rotation or 0)
		state.texCoordChanged = true
	end
	if state.texShifted and state.texCoord and #state.texCoord == 8 then
		local c = state.texCoord
		local du, dv = state.du or 0, state.dv or 0
		target:SetTexCoord(c[1] + du, c[2] + dv, c[3] + du, c[4] + dv, c[5] + du, c[6] + dv, c[7] + du, c[8] + dv)
		state.texCoordChanged = true
	end
	if state.flipFrame and state.flipAnimation and state.texCoord and #state.texCoord == 8 then
		local animation = state.flipAnimation
		local columns = animation.flipColumns or 1
		local rows = animation.flipRows or 1
		local c = state.texCoord
		local left, top = c[1], c[2]
		local right, bottom = c[7], c[8]
		local cellWidth = (right - left) / columns
		local cellHeight = (bottom - top) / rows
		local column = state.flipFrame % columns
		local row = math.floor(state.flipFrame / columns)
		local l = left + column * cellWidth
		local t = top + row * cellHeight
		target:SetTexCoord(l, l + cellWidth, t, t + cellHeight)
		state.texCoordChanged = true
	end
end

local function StepGroup(group)
	if group.scheduleDirty or not group.totalDuration then
		BuildSchedule(group)
	end

	local elapsed = group.elapsed
	local total = group.totalDuration

	for _, state in pairs(group.states) do
		state.dx, state.dy, state.sx, state.sy, state.rotation, state.du, state.dv = nil, nil, nil, nil, nil, nil, nil
		state.flipFrame, state.flipAnimation = nil, nil
	end

	local time = group.reverse and (total - elapsed) or elapsed
	for _, animation in ipairs(group.animations) do
		local target = animation:GetTarget()
		local state = target and group.states[target]
		if state then
			local start = (group.orderStarts[animation.order or 1] or 0) + (animation.startDelay or 0)
			local duration = animation.duration or 0
			if time >= start then
				local progress = duration > 0 and math.min(1, (time - start) / duration) or 1
				if not animation.started then
					animation.started = true
					FireAnimationScript(animation, "OnPlay")
				end
				animation.progress = progress
				ApplyAnimation(group, animation, target, state, progress)
				if progress >= 1 and not animation.done then
					animation.done = true
					FireAnimationScript(animation, "OnFinished", false)
				end
			end
		end
	end

	for target, state in pairs(group.states) do
		CommitTransforms(target, state)
	end
end

local function EndGroup(group, keepAlpha)
	group.playing = false
	group.paused = false
	active[group] = nil
	for target, state in pairs(group.states or {}) do
		RestoreState(target, state, keepAlpha)
	end
end

local function OnDriverUpdate(self, elapsed)
	local any = false
	for group in pairs(active) do
		any = true
		if not group.paused then
			local total = group:GetDuration()
			group.elapsed = group.elapsed + elapsed * (group.speed or 1)
			if group.elapsed >= total then
				local looping = group.looping or "NONE"
				if looping == "REPEAT" and total > 0 then
					group.elapsed = group.elapsed % total
					for _, animation in ipairs(group.animations) do
						animation.started, animation.done = false, false
					end
					StepGroup(group)
					FireGroupScript(group, "OnLoop", "FORWARD")
				elseif looping == "BOUNCE" and total > 0 then
					group.elapsed = group.elapsed % total
					group.reverse = not group.reverse
					for _, animation in ipairs(group.animations) do
						animation.started, animation.done = false, false
					end
					StepGroup(group)
					FireGroupScript(group, "OnLoop", group.reverse and "REVERSE" or "FORWARD")
				else
					group.elapsed = total
					StepGroup(group)
					group.done = true
					EndGroup(group, group.toFinalAlpha)
					FireGroupScript(group, "OnFinished", false)
				end
			else
				StepGroup(group)
			end
			if group.playing then
				FireGroupScript(group, "OnUpdate", elapsed)
			end
		end
	end
	if not any then
		self:Hide()
	end
end

local function EnsureDriver()
	if not driver then
		driver = ns.realG.CreateFrame("Frame")
		driver:SetScript("OnUpdate", OnDriverUpdate)
	end
	driver:Show()
end

function GroupMethods:Play(reverse, offset)
	if self.playing and not self.paused then
		return
	end
	if self.paused then
		self.paused = false
		EnsureDriver()
		return
	end

	self.playing = true
	self.done = false
	self.reverse = reverse and true or false
	self.elapsed = offset or 0
	CaptureTargets(self)
	active[self] = true
	FireGroupScript(self, "OnPlay")
	if self.playing then
		StepGroup(self)
		EnsureDriver()
	end
end

function GroupMethods:Stop()
	if not self.playing then
		return
	end
	EndGroup(self, self.toFinalAlpha)
	FireGroupScript(self, "OnStop", true)
end

function GroupMethods:Pause()
	if self.playing and not self.paused then
		self.paused = true
		FireGroupScript(self, "OnPause")
	end
end

function GroupMethods:Restart(reverse, offset)
	if self.playing then
		EndGroup(self, false)
	end
	self:Play(reverse, offset)
end

function GroupMethods:Finish()
	if self.playing then
		self.elapsed = self:GetDuration()
		StepGroup(self)
		self.done = true
		EndGroup(self, self.toFinalAlpha)
		FireGroupScript(self, "OnFinished", true)
	end
end

function GroupMethods:SetPlaying(playing)
	if playing and not self:IsPlaying() then
		self:Play()
	elseif not playing and self.playing then
		self:Stop()
	end
end

function GroupMethods:RemoveAnimations()
	if self.playing then
		self:Stop()
	end
	wipe(self.animations)
	self.scheduleDirty = true
end

-- ----------------------------------------------------------------------------
-- Construction
-- ----------------------------------------------------------------------------

function Anim.NewGroup(owner, name)
	local group = setmetatable({
		owner = owner,
		name = name,
		animations = {},
		scripts = {},
		looping = "NONE",
		elapsed = 0,
		speed = 1,
		scheduleDirty = true,
	}, GroupMeta)

	local list = groupsByOwner[owner]
	if not list then
		list = {}
		groupsByOwner[owner] = list
	end
	list[#list + 1] = group

	if name then
		ns.realG[name] = group
	end
	return group
end

function Anim.NewGroupFromTemplate(owner, name, template)
	if template and ns.XML.GetTemplate(template) then
		local ctx = { anchors = {}, loads = {} }
		local group = ns.XML.BuildAnimationGroup(ctx, owner, { tag = "AnimationGroup", attr = { name = name, inherits = template } })
		for _, entry in ipairs(ctx.loads) do
			ns.SafeCall(entry.func, entry.object)
		end
		return group
	end
	return Anim.NewGroup(owner, name)
end

function Anim.GetGroupsOf(owner)
	local list = groupsByOwner[owner]
	if not list then
		return
	end
	return unpack(list)
end

function Anim.StopAllOf(owner)
	local list = groupsByOwner[owner]
	if list then
		for _, group in ipairs(list) do
			group:Stop()
		end
	end
end

local function NumberAttr(attr, key)
	return attr[key] and tonumber(attr[key]) or nil
end

-- Reads a retail animation XML element (Alpha / Translation / Scale / ...).
function Anim.ConfigureFromXML(animation, element)
	local attr = element.attr or {}
	animation.order = NumberAttr(attr, "order") or 1
	animation.duration = NumberAttr(attr, "duration") or 0
	animation.startDelay = NumberAttr(attr, "startDelay") or 0
	animation.endDelay = NumberAttr(attr, "endDelay") or 0
	animation.smoothing = attr.smoothing
	animation.childKey = attr.childKey or attr.targetKey
	animation.targetName = attr.target

	local animType = element.tag
	if animType == "Alpha" then
		animation.fromAlpha = NumberAttr(attr, "fromAlpha")
		animation.toAlpha = NumberAttr(attr, "toAlpha")
		animation.change = NumberAttr(attr, "change")
	elseif animType == "Translation" or animType == "LineTranslation" then
		animation.offsetX = NumberAttr(attr, "offsetX") or 0
		animation.offsetY = NumberAttr(attr, "offsetY") or 0
	elseif animType == "TextureCoordTranslation" then
		animation.offsetX = NumberAttr(attr, "offsetU") or 0
		animation.offsetY = NumberAttr(attr, "offsetV") or 0
	elseif animType == "Scale" or animType == "LineScale" then
		animation.fromScaleX = NumberAttr(attr, "fromScaleX") or 1
		animation.fromScaleY = NumberAttr(attr, "fromScaleY") or 1
		animation.toScaleX = NumberAttr(attr, "toScaleX") or NumberAttr(attr, "scaleX") or 1
		animation.toScaleY = NumberAttr(attr, "toScaleY") or NumberAttr(attr, "scaleY") or 1
	elseif animType == "Rotation" then
		local degrees = NumberAttr(attr, "degrees")
		animation.radians = degrees and math.rad(degrees) or NumberAttr(attr, "radians") or 0
	elseif animType == "FlipBook" then
		animation.flipRows = NumberAttr(attr, "flipBookRows")
		animation.flipColumns = NumberAttr(attr, "flipBookColumns")
		animation.flipFrames = NumberAttr(attr, "flipBookFrames")
	end

	if element.children then
		for _, child in ipairs(element.children) do
			if child.tag == "Origin" then
				local originAttr = child.attr or {}
				animation.originPoint = originAttr.point
			elseif child.tag == "StartColor" or child.tag == "EndColor" then
				local r, g, b, a = ns.XML.ReadColor(child)
				local color = { r = r, g = g, b = b, a = a }
				if child.tag == "StartColor" then
					animation.startColor = color
				else
					animation.endColor = color
				end
			end
		end
	end
end
