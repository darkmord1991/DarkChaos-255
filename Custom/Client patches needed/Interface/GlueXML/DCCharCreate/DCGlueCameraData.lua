-- DCGlueCameraData.lua -- GENERATED 2026-08-11 (rev 2, corrected M2 camera layout:
-- type/fov/far/near + tracks; the first extraction skipped fov and read all fields
-- shifted by 4). Axis frame: the client yaw-aligns each scene so +x points from the
-- character toward the camera; dh/cz = camera, th/tz = its aim target, fov in radians.
DCGlueCameraData = {
	["ui_bloodelf"] = { dh = 6.180, cz = 0.679, th = -2.870, tz = 1.218, fov = 0.846 },
	["ui_characterselect"] = { dh = 4.662, cz = 0.239, th = -0.326, tz = 1.183, fov = 1.134 },
	["ui_draenei"] = { dh = 7.378, cz = 0.565, th = 2.911, tz = 0.888, fov = 0.950 },
	["ui_dwarf"] = { dh = 2.216, cz = -0.972, th = -6.467, tz = -0.161, fov = 1.134 },
	["ui_goblin"] = { dh = 6.609, cz = 0.653, th = -2.870, tz = 1.218, fov = 0.970 },
	-- ui_human: camera off-scene (dh=237), falls back
	["ui_mainmenu"] = { dh = 4.331, cz = -1.027, th = -1.566, tz = 0.922, fov = 1.501 },
	["ui_mainmenu_burningcrusade"] = { dh = 12.610, cz = -2.094, th = -0.575, tz = 2.643, fov = 1.466 },
	["ui_mainmenu_legion"] = { dh = 6.039, cz = 3.171, th = 29.517, tz = 14.140, fov = 1.750 },
	["ui_mainmenu_northrend"] = { dh = 11.117, cz = 2.441, th = -10.285, tz = 2.441, fov = 2.094 },
	["ui_nightelf"] = { dh = 4.854, cz = 2.856, th = 0.390, tz = 3.082, fov = 1.047 },
	["ui_orc"] = { dh = 4.662, cz = 0.239, th = -0.326, tz = 1.183, fov = 1.134 },
	["ui_scourge"] = { dh = 3.795, cz = 0.468, th = -1.444, tz = 1.167, fov = 1.134 },
	["ui_tauren"] = { dh = 4.788, cz = 0.454, th = -0.643, tz = 1.012, fov = 1.134 },
	["ui_worgen"] = { dh = 6.609, cz = 0.653, th = -2.870, tz = 1.218, fov = 0.750 },
}
