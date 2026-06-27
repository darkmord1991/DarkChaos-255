--	Filename:	Sirus_CacheSystem.lua
--	Project:	Sirus Game Interface
--	Author:		Devilers
--	E-mail:		devilers@sirus.su
--	Web:		https://sirus.su/

local function LOG(key, ...)
	-- if key == "SIRUS_PVPLADDER_CACHE" then
		-- print(...)
	-- end
end

C_Cache = setmetatable(
	{
		items = {}
	},
	{
		__call = function(self, cacheKey, isLocal)
			function itemKey(global)
				return (isLocal and not global) and UnitName("player") or "__global__"
			end

			_G[cacheKey] = {}

			local cache = setmetatable({
				Set = function(self, key, value, ttl, global)
					LOG(cacheKey, "-- @== Set", key, value, ttl, global, itemKey(global))
					ttl = ttl or 0

					if not key then
						return nil
					end
					local itemKey = itemKey(global)
					local items = _G[cacheKey]
					if not items[itemKey] then
						items[itemKey] = {}
					end
					items[itemKey][key] = {
						ttl = ttl == 0 and 0 or time() + ttl,
						value = value
					}
				end,
				Get = function(self, key, value, ttl, global)
					LOG(cacheKey, "-- @== Get", key, value, ttl, global, itemKey(global))
					local itemKey = itemKey(global)
					local items = _G[cacheKey]
					LOG(cacheKey, items[itemKey], value)
					if items[itemKey] or value then
						if not items[itemKey] then
							items[itemKey] = {}
						end
						local item = items[itemKey][key]

						if item and (item.ttl ~= 0 and item.ttl < time()) then
							LOG(cacheKey, "TTL delete", itemKey, key, item.value, item.ttl)
							item = nil
							items[itemKey][key] = nil
						end

						if item then
							LOG(cacheKey, "CASE #1", item.value)
							return item.value
						elseif value then
							LOG(cacheKey, "CASE #2", value)
							rawget(self, "Set")(self, key, value, ttl)
							return value
						end
					end
				end
			}, {
				__index = function(self, key)
					-- print("-- @== index", self, key, rawget(self, key))
					return rawget(self, "Get")(self, key)
				end,
				__newindex = function(self, key, value)
					-- print("-- @== newindex", self, key, rawget(self, key))
					rawget(self, "Set")(self, key, value, 0)
				end
			})

			self.items[cacheKey] = cache
			RegisterForSave(cacheKey)

			return cache
		end
	})