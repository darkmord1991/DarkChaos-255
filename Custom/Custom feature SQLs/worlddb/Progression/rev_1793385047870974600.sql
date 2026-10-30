-- Path of Chaos: say what each prestige challenge asks for. The book's revision changes with
-- the text, so clients fetch it again at their next login.
UPDATE `dc_path_tasks` SET `description` = 'Complete the Iron prestige challenge: climb back without dying.' WHERE `id` = 310;
UPDATE `dc_path_tasks` SET `description` = 'Complete the Speed prestige challenge: climb back within 100 hours.' WHERE `id` = 311;
UPDATE `dc_path_tasks` SET `description` = 'Complete the Solo prestige challenge: climb back without grouping.' WHERE `id` = 312;
