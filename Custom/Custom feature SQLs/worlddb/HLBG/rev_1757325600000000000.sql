-- Hinterland BG (battleground_template id 20): raise the cap from 10v10 to
-- 20v20, so a full match is 40 players. MinPlayersPerTeam stays at 1 - HLBG
-- fills from the playerbot pool once a real player queues, and a higher
-- minimum would stall the queue when the bot roster is thin.
UPDATE `battleground_template` SET `MaxPlayersPerTeam` = 20 WHERE `ID` = 20;
