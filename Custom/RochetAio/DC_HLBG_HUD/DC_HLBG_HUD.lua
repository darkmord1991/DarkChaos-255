-- DC HLBG HUD - minimal AIO-aware client addon
-- Requires Rochet2/AIO client-side to be installed and loaded before this addon.

local addonName = "DC_HLBG_HUD"
local AIOChannel = addonName

local function log(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[HLBG]|r " .. tostring(msg))
end

-- Example AIO callback if server sends messages. Replace with Rochet2/AIO API as needed.
-- The exact API name depends on the AIO version (e.g., AIO.Register, AIO:Add, etc.)
if AIO and AIO.Register then
    AIO.Register(AIOChannel, function(opcode, payload)
        if opcode == "HELLO" then
            log("Server handshake: " .. tostring(payload))
        elseif opcode == "PING" then
            log("Ping received from server.")
        else
            log("AIO opcode: " .. tostring(opcode) .. " payload: " .. tostring(payload))
        end
    end)
else
    -- Fallback: tell the user AIO is missing client-side
    log("Rochet2/AIO not detected. Install AIO to enable HUD messages.")
end

