local NpcId = 800009
local QuestId = 820057

local function OnQuestAccept(event, player, creature, quest)
    if (quest:GetId() == QuestId) then
        creature:SendUnitWhisper("Let me show you the Start of the Level Area of Ashzara Crater.", 0, player)
        creature:MoveTo( 1, 141.98, 991.51, 295.1, 1)
        creature:MoveIdle()
        creature:SendUnitWhisper("We have lots of creatures living in the Crater, as it was never explored completely, its your turn now!", 0, player)
        creature:MoveTo( 2, 157.81, 977.75, 293.65, 1)
        creature:MoveIdle()
        creature:SendUnitWhisper("This area is huge and has lots of different zones!", 0, player)
	creature:SendUnitWhisper("Go and start your journey, you will find lots of wild stuff, I am sure.", 0, player)
	creature:SendUnitWhisper("Use your start gear and your mobile teleporter pet to get around!", 0, player)
	-- creature:MoveTo( 3, 149.01, 985.66, 295.07, 1)
	-- creature:MoveIdle()	
	-- creature:MoveTo( 4, 140.19, 971.87, 295.22, 1)
	-- creature:MoveIdle()
	creature:SendUnitWhisper("Do you see this Shrine? It is for more challenging experiences.", 0, player)
        creature:MoveIdle()
    end
end

local function OnQuestReward(event, player, creature, quest)
    if (quest:GetId() == QuestId) then
        creature:SendUnitWhisper("Lots of fun with leveling to 80!", 0, player)
        creature:DespawnOrUnsummon(2000)
        -- optional if someone does not complete the quest, so no respawn is done
        -- creature:SpawnCreature(NpcId, 130.521, 999.735, 295.539, 1.46258)
    end
end

RegisterCreatureEvent(NpcId, 31, OnQuestAccept)
RegisterCreatureEvent(NpcId, 34, OnQuestReward)