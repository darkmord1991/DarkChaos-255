--
-- Mythic+ keystones (M+2..M+20, items 300313-300331) become Bind on Pickup.
-- They were bonding 0: a key could be traded or mailed to an alt and the vendor handed out
-- another, so key levels could be duplicated and sold and depletion skipped by keeping spares.
-- The vendor now also checks the bank. Keys already in bags were created unbound and stay
-- tradeable until they expire (7-day duration).
--
UPDATE `item_template` SET `bonding` = 1 WHERE `entry` BETWEEN 300313 AND 300331;
