Hook = {
	hooks = {},
	listeners = {},
	global = CreateFrame("Frame")
}

Hook.global:RegisterAllEvents()
Hook.global:SetScript("OnEvent", function(_ ,event, ...)
    -- printec("Hook.global:OnEvent", self, event, ...)
    Hook:FireEvent(event, event, ...)
end)

function Hook:RegisterListener(listener)
	Hook.listeners[listener] = true
end

function Hook:RegisterCallback(group, events, callback)
	if type(events) == "string" then
		events = {events}
	end

	for _,event in pairs(events) do
		if not self.hooks[group] then
			self.hooks[group] = {}
		end

		if not self.hooks[group][event] then
			self.hooks[group][event] = {}
		end

		self.hooks[group][event][#self.hooks[group][event] + 1] = callback
	end
end

function Hook:UnregisterCallback(group, events)
	if self.hooks[group] then
		if not events then
			self.hooks[group] = nil
		else
			if type(events) == "string" then
				events = {events}
			end

			for _, event in pairs(events) do
				self.hooks[group][event] = nil
			end
		end
	end
end

function Hook:FireEvent(events, ...)
	-- printec(">> Hook:FireEvent", events, ...)
	if type(events) == "string" then
		events = {events}
	end

	for listener, _ in pairs(self.listeners) do
		for _, event in pairs(events) do
			if listener[event] then
				local args = { pcall(listener[event], listener, ...) }

				if args[1] then
					if #args > 1 then
						table.remove(args, 1)
						return unpack(args)
					end
				else
					_ERRORMESSAGE(args[2])
					return
				end
			end
		end
	end

	for _, group in pairs(self.hooks) do
		for _, event in pairs(events) do
			if group[event] then
				for _, callback in pairs(group[event]) do
					local args = { pcall(callback, ...) }

					if args[1] then
						if #args > 1 then
							table.remove(args, 1)
							return unpack(args)
						end
					else
						_ERRORMESSAGE(args[2])
						return
					end
				end
			end
		end
	end
end

function Hook:IsRegisterEvent(group, event)
	if self.hooks[group] then
		return self.hooks[group][event] ~= nil
	end

	return nil
end
