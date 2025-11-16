-- Tile Investigation Script
-- Check what's actually being displayed in the tiles

print("|cFF00FF00=== Tile Investigation ===|r")

-- Check all detail tiles
for i = 1, 16 do
    local tile = _G["WorldMapDetailTile" .. i]
    if tile then
        local shown = tile:IsShown()
        local texture = tile:GetTexture()
        local alpha = tile:GetAlpha()
        local layer = tile:GetDrawLayer()
        
        if shown then
            print(string.format("Tile %d: SHOWN", i))
            print(string.format("  Texture: %s", tostring(texture or "NONE")))
            print(string.format("  Alpha: %.2f", alpha))
            print(string.format("  Layer: %s", tostring(layer)))
            
            -- Check if it's our custom tile
            if tile._DCMapCustom then
                print("  Type: CUSTOM (ours)")
            else
                print("  Type: BLIZZARD (not ours!)")
            end
        end
    end
end

-- Check for base map texture
if WorldMapDetailFrame then
    print("\n|cFFFFFF00WorldMapDetailFrame Textures:|r")
    for i = 1, WorldMapDetailFrame:GetNumRegions() do
        local region = select(i, WorldMapDetailFrame:GetRegions())
        if region and region.GetTexture then
            local tex = region:GetTexture()
            if tex then
                print(string.format("  Region %d: %s", i, tostring(tex)))
            end
        end
    end
end

print("|cFF00FF00=== End Investigation ===|r")
