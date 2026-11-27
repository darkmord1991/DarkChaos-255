-- Retired with the dynamic item-upgrade cutover.
--
-- Clone item entries are no longer inserted into `dc_item_templates_upgrade`,
-- and the server no longer expects `dc_item_upgrade_clones` for runtime tier
-- resolution. Keep this file as a no-op marker so older operational runbooks do
-- not silently recreate the retired clone model.

SELECT 'RETIRED: populate_clones_in_upgrade_table.sql is intentionally a no-op after the dynamic item-upgrade cutover.' AS status;
