--	Filename:	EventHandler.lua
--	Project:	Sirus Game Interface
--	Author:		Devilers
--	Web:		https://sirus.su/

function FireCustomClientEvent(eventID, ...)
	local eventName = E_CLIEN_CUSTOM_EVENTS[eventID];

	if eventName and REGISTERED_CUSTOM_EVENTS[eventName] then
		for frame in pairs(REGISTERED_CUSTOM_EVENTS[eventName]) do
			local eventFunc = frame:GetScript("OnEvent");

			if eventFunc then
				eventFunc(frame, eventName, ...);
			end
		end
	end
end

EventHandler = setmetatable(
	{
		events = {},		-- Original events
		listeners = {},		-- New tables for handling events outside og EventHandler
		RegisterListener = function(self, listener)
			self.listeners[listener] = true
		end,
		Handle = function(self, opcode, message, unk, sender)
			-- printec(">> EventHandler:Handle", self, opcode, message, unk, sender)
			if sender == UnitName("player") then
				if opcode == "ASMSG_FIRE_CLIENT_EVENT" and message then
					local params = C_Split(message, ":")

					if params and #params > 0 then
						local eventID 	  = tonumber(table.remove(params, 1))
						local clientEvent = E_DEFAULT_CLIENT_EVENTS[eventID]

						if clientEvent then
							for _, frame in pairs({GetFramesRegisteredForEvent(clientEvent)}) do
								if frame then
									local onEventFunc = frame:GetScript("OnEvent")

									if onEventFunc then
										onEventFunc(frame, clientEvent, unpack(params))
									end
								end
							end
						end
					end
				end

				for listener, _ in pairs(self.listeners) do
					if listener[opcode] then
						listener[opcode](listener, message)
					end
				end

				if self.events[opcode] then
					self.events[opcode](self, message)
				end
			end
		end
	},
	{
		__newindex = function(self, key, value)
			if type(value) == "function" then
				self.events[key] = value
			end
			rawset(self, key, value)
		end
	}
)

local EventHandlerFrame = CreateFrame("Frame")
EventHandlerFrame:RegisterEvent("CHAT_MSG_ADDON")
EventHandlerFrame:SetScript("OnEvent", function(self, event, opcode, message, unk, sender)
	EventHandler:Handle(opcode, message, unk, sender)
end)

function C_OnReceiveOpcodeHandler(opcode, ...)
    local args = {...}
    xpcall(function()
    	-- printc(opcode, unpack(args))
        EventHandler:Handle(opcode, nil, unpack(args))
    end, function(err)
        _ERRORMESSAGE(err)
    end)
end
