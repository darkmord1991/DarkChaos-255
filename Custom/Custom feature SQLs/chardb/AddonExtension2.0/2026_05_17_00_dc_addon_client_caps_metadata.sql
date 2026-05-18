ALTER TABLE `dc_addon_client_caps`
  ADD COLUMN `native_build_fingerprint` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' AFTER `negotiated_caps`,
  ADD COLUMN `data_revisions_json` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' AFTER `native_build_fingerprint`;

ALTER TABLE `dc_addon_client_caps_history`
  ADD COLUMN `native_build_fingerprint` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' AFTER `character_name`,
  ADD COLUMN `data_revisions_json` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' AFTER `native_build_fingerprint`;