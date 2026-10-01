--[[
	DC-Talents - retail 11.x object pools (Blizzard_SharedXMLBase/Pools.lua, unsecured variant).

	Retail builds pools on SecureTypes / ProxyUtil, which 3.3.5 cannot provide (and addon code could
	not use anyway). This is the unsecured half of that file with the same public surface. One retail
	quirk is kept on purpose: a pool collection's GetOrCreatePool returns ONLY the pool (retail
	returns it through a proxy that drops the "isNew" value), so code written against retail, such as
	TalentFrameBaseMixin:AcquireTalentButton's `if isNewPool then pool:SetResetDisallowedIfNew(...)`,
	behaves exactly as it does there.
]]

local _, ns = ...
setfenv(1, ns.env)

local ObjectPoolMixin = {}

local function Reserve(pool, capacity)
	pool.capacity = capacity or math.huge
	if pool.capacity ~= math.huge then
		for _ = 1, pool.capacity do
			pool:Acquire()
		end
		pool:ReleaseAll()
	end
end

function ObjectPoolMixin:Init(createFunc, resetFunc, capacity)
	self.createFunc = createFunc
	self.resetFunc = resetFunc
	self.activeObjects = {}
	self.inactiveObjects = {}
	self.activeObjectCount = 0
	Reserve(self, capacity)
end

function ObjectPoolMixin:Acquire()
	if self.activeObjectCount == self.capacity then
		return nil, false
	end

	local object = tremove(self.inactiveObjects)
	local new = object == nil
	if new then
		object = self.createFunc(self)
		if self.resetFunc then
			self.resetFunc(self, object, true)
		end
	end

	self.activeObjects[object] = true
	self.activeObjectCount = self.activeObjectCount + 1
	return object, new
end

function ObjectPoolMixin:Release(object, canFailToFindObject)
	local active = self.activeObjects[object] ~= nil
	if not active then
		if not canFailToFindObject then
			assertsafe(false, "Attempted to release an object that is not active in this pool")
		end
		return false
	end

	if self.resetFunc then
		self.resetFunc(self, object, false)
	end
	tinsert(self.inactiveObjects, object)
	self.activeObjects[object] = nil
	self.activeObjectCount = self.activeObjectCount - 1
	return true
end

function ObjectPoolMixin:ReleaseAll()
	for object in pairs(self.activeObjects) do
		self:Release(object)
	end
end

function ObjectPoolMixin:EnumerateActive()
	return pairs(self.activeObjects)
end

function ObjectPoolMixin:GetNextActive(current)
	return (next(self.activeObjects, current))
end

function ObjectPoolMixin:IsActive(object)
	return self.activeObjects[object] ~= nil
end

function ObjectPoolMixin:GetNumActive()
	return self.activeObjectCount
end

function ObjectPoolMixin:DoesObjectBelongToPool(object)
	if self.activeObjects[object] then
		return true
	end
	for _, candidate in ipairs(self.inactiveObjects) do
		if candidate == object then
			return true
		end
	end
	return false
end

function ObjectPoolMixin:Dump()
	for object in self:EnumerateActive() do
		print(tostring(object))
	end
end

-- Present on retail pools created through collections only as a no-op in practice; see header.
function ObjectPoolMixin:SetResetDisallowedIfNew()
end

function Pool_HideAndClearAnchors(pool, region)
	region:Hide()
	region:ClearAllPoints()
end

function ActorPool_HideAndClearModel(pool, actor)
	if actor.ClearModel then
		actor:ClearModel()
	end
	actor:Hide()
end

local function CreateRegionPool(template, createFunc, resetFunc, capacity)
	local pool = CreateFromMixins(ObjectPoolMixin)
	pool:Init(createFunc, resetFunc or Pool_HideAndClearAnchors, capacity)
	pool.GetTemplate = function()
		return template
	end
	return pool
end

function CreateObjectPool(createFunc, resetFunc, capacity)
	local pool = CreateFromMixins(ObjectPoolMixin)
	pool:Init(createFunc, resetFunc, capacity)
	return pool
end

function CreateFramePool(frameType, parent, template, resetFunc, forbidden, postCreate, capacity)
	local function Create()
		local frame = CreateFrame(frameType, nil, parent, template)
		if postCreate then
			postCreate(frame)
		end
		return frame
	end
	return CreateRegionPool(template, Create, resetFunc, capacity)
end

function CreateTexturePool(parent, layer, subLayer, template, resetFunc, capacity)
	local function Create()
		return parent:CreateTexture(nil, layer, template, subLayer)
	end
	return CreateRegionPool(template, Create, resetFunc, capacity)
end

function CreateFontStringPool(parent, layer, subLayer, template, resetFunc, capacity)
	local function Create()
		return parent:CreateFontString(nil, layer, template, subLayer)
	end
	return CreateRegionPool(template, Create, resetFunc, capacity)
end

function CreateMaskTexturePool(parent, layer, subLayer, template, resetFunc, capacity)
	local function Create()
		return parent:CreateMaskTexture(nil, layer, template, subLayer)
	end
	return CreateRegionPool(template, Create, resetFunc, capacity)
end

function CreateActorPool(parent, template, resetFunc, capacity)
	local function Create()
		return parent:CreateActor(nil, template)
	end
	return CreateRegionPool(template, Create, resetFunc or ActorPool_HideAndClearModel, capacity)
end

CreateSecureObjectPool = CreateObjectPool
CreateSecureFramePool = CreateFramePool
CreateSecureTexturePool = CreateTexturePool
CreateSecureFontStringPool = CreateFontStringPool
CreateUnsecuredObjectPool = CreateObjectPool
CreateUnsecuredFramePool = function(frameType, parent, template, resetFunc, capacity)
	return CreateFramePool(frameType, parent, template, resetFunc, false, nil, capacity)
end
CreateUnsecuredTexturePool = CreateTexturePool
CreateUnsecuredFontStringPool = CreateFontStringPool
CreateUnsecuredMaskTexturePool = CreateMaskTexturePool
CreateUnsecuredRegionPoolInstance = CreateRegionPool

-- ----------------------------------------------------------------------------
-- Pool collections
-- ----------------------------------------------------------------------------

local function GetPoolKey(template, specialization)
	if specialization == nil then
		return tostring(template) .. "nil"
	end
	return tostring(template) .. tostring(specialization)
end

local function SpecializationToPostCreate(specialization)
	local specializationType = type(specialization)
	if specializationType == "function" then
		return specialization
	elseif specializationType == "table" then
		return function(frame)
			FrameUtil.SpecializeFrameWithMixins(frame, specialization)
		end
	end
	return nil
end

local PoolCollectionMixin = {}

function PoolCollectionMixin:Init()
	self.pools = {}
end

function PoolCollectionMixin:GetPool(template, specialization)
	return self.pools[GetPoolKey(template, specialization)]
end

function PoolCollectionMixin:GetNumActive()
	local total = 0
	for _, pool in pairs(self.pools) do
		total = total + pool:GetNumActive()
	end
	return total
end

function PoolCollectionMixin:Acquire(template, specialization)
	local pool = self:GetPool(template, specialization)
	return pool:Acquire()
end

function PoolCollectionMixin:Release(object)
	for _, pool in pairs(self.pools) do
		if pool:Release(object, true) then
			return true
		end
	end
	assertsafe(false, "Attempted to release an object that does not belong to this pool collection")
	return false
end

function PoolCollectionMixin:ReleaseAll()
	for _, pool in pairs(self.pools) do
		pool:ReleaseAll()
	end
end

function PoolCollectionMixin:ReleaseAllByTemplate(template, specialization)
	local pool = self:GetPool(template, specialization)
	if pool then
		pool:ReleaseAll()
	end
end

function PoolCollectionMixin:EnumerateActiveByTemplate(template, specialization)
	local pool = self:GetPool(template, specialization)
	if pool then
		return pool:EnumerateActive()
	end
	return nop
end

-- Returns objects only (unlike a pool, which also yields its value).
function PoolCollectionMixin:EnumerateActive()
	local currentObject = nil
	local currentPoolKey, currentPool = next(self.pools, nil)
	return function()
		if currentPool then
			currentObject = currentPool:GetNextActive(currentObject)
			while not currentObject do
				currentPoolKey, currentPool = next(self.pools, currentPoolKey)
				if currentPool then
					currentObject = currentPool:GetNextActive(nil)
				else
					break
				end
			end
		end
		return currentObject
	end, nil
end

function PoolCollectionMixin:IsActive(object)
	for _, pool in pairs(self.pools) do
		if pool:IsActive(object) then
			return true
		end
	end
	return false
end

function PoolCollectionMixin:DoesObjectBelongToPool(object)
	for _, pool in pairs(self.pools) do
		if pool:DoesObjectBelongToPool(object) then
			return true
		end
	end
	return false
end

function PoolCollectionMixin:Dump()
	for object in self:EnumerateActive() do
		print(tostring(object))
	end
end

local FramePoolCollectionMixin = CreateFromMixins(PoolCollectionMixin)

function FramePoolCollectionMixin:CreatePool(frameType, parent, template, resetFunc, forbidden, specialization, capacity)
	local key = GetPoolKey(template, specialization)
	assertsafe(self.pools[key] == nil, "Pool already exists for template " .. tostring(template))
	local pool = CreateFramePool(frameType, parent, template, resetFunc, forbidden, SpecializationToPostCreate(specialization), capacity)
	self.pools[key] = pool
	return pool
end

-- Retail returns only the pool here (see file header).
function FramePoolCollectionMixin:GetOrCreatePool(frameType, parent, template, resetFunc, forbidden, specialization, capacity)
	local pool = self:GetPool(template, specialization)
	if not pool then
		pool = self:CreatePool(frameType, parent, template, resetFunc, forbidden, specialization, capacity)
	end
	return pool
end

function CreateFramePoolCollection()
	local collection = CreateFromMixins(FramePoolCollectionMixin)
	collection:Init()
	return collection
end

CreateSecureFramePoolCollection = CreateFramePoolCollection
CreateUnsecuredFramePoolCollection = CreateFramePoolCollection

local FontStringPoolCollectionMixin = CreateFromMixins(PoolCollectionMixin)

function FontStringPoolCollectionMixin:GetPool(template)
	return self.pools[tostring(template)]
end

function FontStringPoolCollectionMixin:CreatePool(parent, layer, subLayer, template, resetFunc, capacity)
	local pool = CreateFontStringPool(parent, layer, subLayer, template, resetFunc, capacity)
	self.pools[tostring(template)] = pool
	return pool
end

function FontStringPoolCollectionMixin:GetOrCreatePool(parent, layer, subLayer, template, resetFunc, capacity)
	return self:GetPool(template) or self:CreatePool(parent, layer, subLayer, template, resetFunc, capacity)
end

function CreateFontStringPoolCollection()
	local collection = CreateFromMixins(FontStringPoolCollectionMixin)
	collection:Init()
	return collection
end

CreateSecureFontStringPoolCollection = CreateFontStringPoolCollection
