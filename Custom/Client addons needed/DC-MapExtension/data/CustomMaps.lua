local CustomMaps = {
    -- Example entry: update with actual texture atlas info when exported.
    AzsharaCrater = {
        mapID = 9001,
        name = "Azshara Crater",
        textures = {
            {file = "Textures/AzsharaCrater_1", width = 1024, height = 768},
        },
        bounds = {left = 0, right = 1, top = 1, bottom = 0},
    },
}

_G.DCMapExtensionData = _G.DCMapExtensionData or {}
_G.DCMapExtensionData.CustomMaps = CustomMaps
