--[[
    DC-Collection UI/WardrobeFrame.lua
    ==================================

    Wardrobe entrypoint.

    The implementation lives in:
      UI/Wardrobe/WardrobeCore.lua
      UI/Wardrobe/WardrobeUI.lua
      UI/Wardrobe/WardrobeItems.lua
      UI/Wardrobe/WardrobeSets.lua
      UI/Wardrobe/WardrobeOutfits.lua
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
