-- POI Diagnostic Script
-- Run this to see what POI frames are visible on the map

print("|cFF00FF00=== POI Diagnostic ===|r")

-- Check WorldMapFrame children
if WorldMapFrame then
    print("\n|cFFFFFF00WorldMapFrame Children:|r")
    local count = 0
    for i = 1, WorldMapFrame:GetNumChildren() do
        local child = select(i, WorldMapFrame:GetChildren())
        if child and child:IsShown() then
            local name = child:GetName() or "Unnamed"
            print("  " .. i .. ": " .. name .. " (SHOWN)")
            count = count + 1
        end
    end
    print("Total shown: " .. count)
end

-- Check WorldMapDetailFrame children
if WorldMapDetailFrame then
    print("\n|cFFFFFF00WorldMapDetailFrame Children:|r")
    local count = 0
    for i = 1, WorldMapDetailFrame:GetNumChildren() do
        local child = select(i, WorldMapDetailFrame:GetChildren())
        if child and child:IsShown() then
            local name = child:GetName() or "Unnamed"
            local width = child:GetWidth() or 0
            local height = child:GetHeight() or 0
            print(string.format("  %d: %s (SHOWN) Size: %.0fx%.0f", i, name, width, height))
            count = count + 1
        end
    end
    print("Total shown: " .. count)
end

-- Check for Mapster
if Mapster then
    print("\n|cFF00FF00Mapster Detected:|r")
    print("  Version: " .. tostring(Mapster.version or "unknown"))
    if Mapster.pins then
        local pinCount = 0
        for k, v in pairs(Mapster.pins) do
            pinCount = pinCount + 1
        end
        print("  Pins: " .. pinCount)
    end
end

-- Check specific POI frames
print("\n|cFFFFFF00Specific POI Frames:|r")
local poiFrames = {
    "WorldMapPOIFrame",
    "WorldMapBlobFrame", 
    "WorldMapTooltip",
    "WorldMapArchaeologyDigSites",
    "Cartographer_POI",
}

for _, frameName in ipairs(poiFrames) do
    local frame = _G[frameName]
    if frame then
        local shown = frame:IsShown() and "SHOWN" or "HIDDEN"
        print("  " .. frameName .. ": " .. shown)
    else
        print("  " .. frameName .. ": NOT FOUND")
    end
end

-- Check for stranglethorn-specific text
print("\n|cFFFFFF00Looking for Stranglethorn elements:|r")
for i = 1, 100 do
    local frame = _G["WorldMapFramePOI" .. i]
    if frame and frame:IsShown() then
        local name = frame:GetName()
        local text = ""
        if frame.name then
            text = tostring(frame.name)
        end
        if text:lower():find("strang") or text:lower():find("vale") then
            print("  FOUND: " .. name .. " - " .. text)
        end
    end
end

print("|cFF00FF00=== End Diagnostic ===|r")
