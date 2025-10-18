-- Migration 002: add effect description to hlbg_affixes
ALTER TABLE `hlbg_affixes`
  ADD COLUMN `effect` TEXT NULL AFTER `name`;

-- You can populate effect with a concise description, e.g.:
-- UPDATE hlbg_affixes SET effect = 'Periodic lightning storms that deal damage and stun' WHERE id = 1;
