-- HLBG win/loss views: count losses with the TeamId convention the server writes.
-- dc_hlbg_winner_history.winner_tid and dc_hlbg_match_participants.team both hold a TeamId
-- (0 = Alliance, 1 = Horde). winner_tid 2 is a draw or a manual reset, which is neither a win
-- nor a loss. The old views read winner_tid 0 as a draw, so no Horde loss to the Alliance was
-- ever counted, and a draw with participants would have been a loss for both teams.
-- Column names and every other column are unchanged from the live definitions.
-- SQL SECURITY INVOKER so the views do not depend on the account that applies this file.

ALTER TABLE `dc_hlbg_match_participants`
    MODIFY COLUMN `team` TINYINT NOT NULL COMMENT 'TeamId: 0=Alliance, 1=Horde';

DROP VIEW IF EXISTS `v_hlbg_player_seasonal_stats`;
CREATE SQL SECURITY INVOKER VIEW `v_hlbg_player_seasonal_stats` AS
SELECT
    `p`.`guid` AS `guid`,
    `p`.`account_id` AS `account_id`,
    `p`.`player_name` AS `player_name`,
    `p`.`account_name` AS `account_name`,
    `p`.`season_id` AS `season_id`,
    COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) AS `wins`,
    COUNT(CASE WHEN `wh`.`winner_tid` IN (0, 1) AND `wh`.`winner_tid` <> `p`.`team` THEN 1 END) AS `losses`,
    COUNT(*) AS `games_played`,
    ROUND((COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) * 100.0) / COUNT(*), 2) AS `win_rate`,
    SUM(`p`.`kills`) AS `total_kills`,
    SUM(`p`.`deaths`) AS `total_deaths`,
    ROUND(SUM(`p`.`kills`) / NULLIF(SUM(`p`.`deaths`), 0), 2) AS `kd_ratio`,
    ROUND(SUM(`p`.`kills`) / NULLIF(COUNT(*), 0), 2) AS `avg_kills_per_game`,
    ROUND(SUM(`p`.`damage_done`) / NULLIF(COUNT(*), 0), 0) AS `avg_damage_per_game`,
    SUM(`p`.`healing_done`) AS `total_healing`,
    SUM(`p`.`resources_captured`) AS `total_resources_captured`,
    SUM(`p`.`flags_returned`) AS `total_flags_returned`,
    COALESCE((
        SELECT
            SUM(`p2`.`rating_change`)
        FROM `dc_hlbg_match_participants` `p2`
        WHERE `p2`.`guid` = `p`.`guid` AND `p2`.`season_id` = `p`.`season_id`) + 1200, 1200) AS `current_rating`,
    MAX(`p`.`match_date`) AS `last_match_date`
FROM `dc_hlbg_match_participants` `p`
LEFT JOIN `dc_hlbg_winner_history` `wh` ON `p`.`match_id` = `wh`.`id`
GROUP BY `p`.`guid`, `p`.`account_id`, `p`.`player_name`, `p`.`account_name`, `p`.`season_id`;

DROP VIEW IF EXISTS `v_hlbg_player_alltime_stats`;
CREATE SQL SECURITY INVOKER VIEW `v_hlbg_player_alltime_stats` AS
SELECT
    `p`.`guid` AS `guid`,
    `p`.`account_id` AS `account_id`,
    `p`.`player_name` AS `player_name`,
    `p`.`account_name` AS `account_name`,
    COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) AS `total_wins`,
    COUNT(CASE WHEN `wh`.`winner_tid` IN (0, 1) AND `wh`.`winner_tid` <> `p`.`team` THEN 1 END) AS `total_losses`,
    COUNT(*) AS `total_games_played`,
    ROUND((COUNT(CASE WHEN `wh`.`winner_tid` = `p`.`team` THEN 1 END) * 100.0) / COUNT(*), 2) AS `overall_win_rate`,
    SUM(`p`.`kills`) AS `total_kills`,
    SUM(`p`.`deaths`) AS `total_deaths`,
    ROUND(SUM(`p`.`kills`) / NULLIF(SUM(`p`.`deaths`), 0), 2) AS `overall_kd_ratio`,
    ROUND(SUM(`p`.`kills`) / NULLIF(COUNT(*), 0), 2) AS `avg_kills_per_game`,
    ROUND(SUM(`p`.`damage_done`) / NULLIF(COUNT(*), 0), 0) AS `avg_damage_per_game`,
    SUM(`p`.`healing_done`) AS `total_healing`,
    SUM(`p`.`resources_captured`) AS `total_resources_captured`,
    SUM(`p`.`flags_returned`) AS `total_flags_returned`,
    (
        SELECT
            COALESCE(SUM(`p2`.`rating_change`), 0) + 1200
        FROM `dc_hlbg_match_participants` `p2`
        WHERE `p2`.`guid` = `p`.`guid` AND `p2`.`season_id` = (
            SELECT
                MAX(`p3`.`season_id`)
            FROM `dc_hlbg_match_participants` `p3`
            WHERE `p3`.`guid` = `p`.`guid`)) AS `current_rating`,
    COUNT(DISTINCT `p`.`season_id`) AS `seasons_participated`,
    MIN(`p`.`match_date`) AS `first_match_date`,
    MAX(`p`.`match_date`) AS `last_match_date`
FROM `dc_hlbg_match_participants` `p`
LEFT JOIN `dc_hlbg_winner_history` `wh` ON `p`.`match_id` = `wh`.`id`
GROUP BY `p`.`guid`, `p`.`account_id`, `p`.`player_name`, `p`.`account_name`;
