-- IconName picks a stock cursor, or Interface\Cursor\<IconName>.blp. These names have neither, so the old client shows
-- no cursor over them. The native client falls back to the gears, and with these rows shows the intended cursor.

-- The stock file really is spelled vehichleCursor
UPDATE `creature_template` SET `IconName` = 'vehichleCursor' WHERE `IconName` = 'VehicleCursor';

-- Retail names from imported templates
UPDATE `creature_template` SET `IconName` = 'Interact' WHERE `IconName` IN ('openhand', 'openhandglow');
UPDATE `gameobject_template` SET `IconName` = 'Interact' WHERE `IconName` IN ('questinteract', 'openhandglow');

-- Not cursor names at all: empty lets the object's type choose
UPDATE `gameobject_template` SET `IconName` = '' WHERE `IconName` IN ('0', 'Infused Moonstone');
