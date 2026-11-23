#pragma once

// Worldforged pickups: each ACCOUNT may loot each pickup once, for good (characters.dc_worldforged_claims).
// Nothing resets the claims; a prestige fresh start deliberately leaves them alone (decided 2026-11-21).
// The whole system lives in dc_worldforged_pickups.cpp, which registers through AddSC_dc_worldforged_pickups().
