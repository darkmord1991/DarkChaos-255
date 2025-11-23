local POIData = {
    layers = {
        azshara_guard = {
            label = "Azshara Crater Services",
            description = "POIs exposed by the guard NPC teleporter inside Azshara Crater.",
            mapID = 37,
            source = "ac_guard_npc.cpp",
            points = {
                {name = "Startcamp", x = 131.000, y = 1012.000, z = 295.000, o = 5.000},
                {name = "Flight Master", x = 72.5327, y = 932.2570, z = 339.3900, o = 0.0680255},
                {name = "Innkeeper", x = 100.973, y = 1037.9, z = 297.107, o = 2.56106},
                {name = "Auction House", x = 117.113, y = 1051.78, z = 297.107, o = 0.92979},
                {name = "Stable Master", x = 95.3867, y = 1027.84, z = 297.107, o = 2.5163},
                {name = "Transmogrifier", x = 148.838, y = 1000.34, z = 295.753, o = 5.98384},
                {name = "Riding Trainer", x = 120.768, y = 955.565, z = 295.072, o = 5.15048},
                {name = "Profession Trainers", x = 43.905, y = 1172.420, z = 367.342, o = 2.560},
                {name = "Weapon Trainer", x = 100.351, y = 1004.96, z = 296.329, o = 0.258275},
                {name = "Violet Temple", x = -574.179, y = -208.159, z = 355.034, o = 3.8202},
                {name = "Dragon Statues", x = -53.4259, y = -40.4419, z = 271.541, o = 3.42052},
            },
        },
    },
}

_G.DCMapExtensionData = _G.DCMapExtensionData or {}
_G.DCMapExtensionData.POIData = POIData
