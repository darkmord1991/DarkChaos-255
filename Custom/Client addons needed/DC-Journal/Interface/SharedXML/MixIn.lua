
-- Mixin code
function Mixin(object, ...)
	local mixins = {...}

	for _, mixin in pairs(mixins) do
		for k,v in pairs(mixin) do
			object[k] = v
		end
	end

	object["RegisterEventListener"] = function(self)
		--printec("Mixin:RegisterEventListener", self, EventHandler)
		EventHandler:RegisterListener(self)
	end

	object["RegisterHookListener"] = function(self)
		--printec("Mixin:RegisterHookListener", self, Hook)
		Hook:RegisterListener(self)
	end

	-- Connect hooks
	object["RegisterCallbacks"] = function(_ , ...)
		for _ ,v in pairs({ ...}) do
			assert(object[v] ~= nil, string.format("Callback handler %s not found in mixin", v))

			Hook:RegisterCallback(tostring(object), v, function(...)
				object[v](object, ...)
			end)
		end
	end

	return object
end

function CreateFromMixins(...)
	return Mixin({ }, ...)
end

function CreateAndInitFromMixin(mixin, ...)
	local object = CreateFromMixins(mixin);
	object:Init(...);
	return object;
end