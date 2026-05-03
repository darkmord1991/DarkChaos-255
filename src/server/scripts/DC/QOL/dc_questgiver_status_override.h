#ifndef DC_QUESTGIVER_STATUS_OVERRIDE_H
#define DC_QUESTGIVER_STATUS_OVERRIDE_H

#include "QuestDef.h"

class Creature;
class Player;

namespace DCQuestgiverStatusOverride
{
    QuestGiverStatus GetDialogStatus(Player* player, Creature* creature);
    void LoadConfig(bool reload = false);
}

#endif