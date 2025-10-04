-- HLBG_AFK.lua - AFK warning system for Hinterland Battleground

-- Ensure HLBG namespace exists
HLBG = HLBG or {}

-- Minimal AFK warning stub (client-side only, non-invasive)
do
    local afkTimer, afkAccum = nil, 0
    local lastX, lastY, lastTime = nil, nil, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, elapsed)
        if not HinterlandAffixHUDDB or not HinterlandAffixHUDDB.enableAFKWarning then return end
        afkAccum = afkAccum + (elapsed or 0)
        if afkAccum < 5.0 then return end -- check every 5s
        afkAccum = 0
        local inBG = InHinterlands()
        if not inBG then return end
        
        -- approximate movement using map position if available (use safe wrapper when present)
        local x,y = 0,0
        if type(HLBG) == 'table' and type(HLBG.safeGetPlayerMapPosition) == 'function' then
            local px, py = HLBG.safeGetPlayerMapPosition("player")
            if px and py then x,y = px,py end
        end
        
        local moved = (lastX == nil or math.abs((x - (lastX or 0))) > 0.001 or math.abs((y - (lastY or 0))) > 0.001)
        local now = time()
        if moved then lastX, lastY, lastTime = x, y, now; return end
        
        -- no movement; if more than N seconds, warn
        local idleSec = now - (lastTime or now)
        local threshold = (HinterlandAffixHUDDB.afkWarnSeconds or 120)
        if idleSec >= threshold then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00HLBG|r: You seem AFK. Please move or you may be removed.")
            -- reset timer to avoid spamming
            lastTime = now - (threshold/2)
        end
    end)
end