/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#ifndef DC_NAXX40_CONFIG_H
#define DC_NAXX40_CONFIG_H

#include "Config.h"
#include "ScriptMgr.h"

#define NAXXRAMAS_PHASE_MAX 2
std::array<std::string, NAXXRAMAS_PHASE_MAX> const NaxxramasPhasesNames =
{
    "ScourgeEvent",
    "Naxxramas"
};

class VanillaNaxxramas
{
public:
    static VanillaNaxxramas* instance();

    bool enabled, requireNaxxStrath, requireAttunement;
};

#define sVanillaNaxxramas VanillaNaxxramas::instance()

#endif // DC_NAXX40_CONFIG_H
