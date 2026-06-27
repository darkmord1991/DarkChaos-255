--	Filename:	ModelFrames.lua
--	Project:	Sirus Game Interface
--	Author:		Nyll
--	E-mail:		nyll@sirus.su
--	Web:		https://sirus.su/

UI_CAMERA_ID = {
	[12] = {2.050, -1.080, -0.370, -2.350, 133}, -- Transmog-Creature-Wand
	[13] = {1.390, -1.090, -0.440, -2.720, 133}, -- Transmog-Creature-OneHAxe
	[14] = {1.390, -1.090, -0.440, -2.720, 133}, -- Transmog-Creature-OneHSword
	[15] = {1.390, -1.090, -0.440, -2.720, 133}, -- Transmog-Creature-OneHMace
	[16] = {1.370, -1.060, -0.500, -2.820, 133}, -- Transmog-Creature-Dagger
	[17] = {1.380, -0.870, -0.150, -2.820, 133}, -- Transmog-Creature-Fist
	[18] = {1.500, 0.720, -0.540, -1.600, 46}, -- Transmog-Creature-Shield
	[19] = {2.160, -0.450, 0.060, 2.480, 107}, -- Transmog-Creature-Holdable
	[20] = {1.130, -1.200, -0.580, -2.820, 133}, -- Transmog-Creature-TwoHAxe
	[21] = {1.020, -1.250, -0.700, -2.820, 133}, -- Transmog-Creature-TwoHSword
	[22] = {1.230, -1.170, -0.560, -2.820, 133}, -- Transmog-Creature-TwoHMace
	[23] = {0.810, -1.130, -0.450, -2.720, 133}, -- Transmog-Creature-Staff
	[24] = {1.140, -1.260, -0.650, -2.780, 133}, -- Transmog-Creature-Polearm
	[25] = {0.890, 0.750, -0.500, -1.120, 46}, -- Transmog-Creature-Bow
	[26] = {0.470, -1.150, -0.460, -2.820, 133}, -- Transmog-Creature-Gun
	[27] = {1.200, -0.750, -0.600, 2.800, 28}, -- Transmog-Creature-Crossbow
	[28] = {1.100, -0.890, -0.270, -2.950, 133}, -- Transmog-Creature-Thrown
	[29] = {1.020, -1.250, -0.700, -2.820, 133}, -- Transmog-Creature-FishingPole
	[30] = {1.370, -1.060, -0.500, -2.820, 133}, -- Transmog-Creature-OtherWeapon

	[43] = {2.300, -0.660, -0.390, 1.600, 131}, -- Transmog-Creature-OneHAxe-Alt
	[44] = {2.220, -0.600, -0.470, 1.600, 131}, -- Transmog-Creature-OneHSword-Alt
	[45] = {2.280, -0.610, -0.480, 1.600, 131}, -- Transmog-Creature-OneHMace-Alt
	[46] = {2.270, -0.600, -0.450, 1.600, 131}, -- Transmog-Creature-Dagger-Alt
	[47] = {1.760, 0.510, -0.620, -1.400, 52}, -- Transmog-Creature-Fist-Alt

	[50] = {0, 0, 0, 0, 133},
	[63] = {1.390, -1.090, -0.440, -2.720, 133}, -- Transmog-Creature-Weapon
	[64] = {1.500, 0.720, -0.540, -1.600, 46}, -- Transmog-Creature-Shield
	[67] = {0.810, -1.130, -0.450, -2.720, 133}, -- Transmog-Creature-TwoHWeapon
	[71] = {0.810, -1.130, -0.450, -2.720, 133}, -- Transmog-Creature-WeaponMainHand
	[72] = {1.420, -0.540, -0.470, 1.670, 41}, -- Transmog-Creature-WeaponOffHand
	[73] = {2.220, -0.370, -0.080, 2.710, 107}, -- Transmog-Creature-Holdable
	[76] = {2.050, -1.080, -0.370, -2.350, 133}, -- Transmog-Creature-RangedRight

	[101] = {2.190, 0.060, -0.840, -0.598}, -- Transmog-Human-Male-Head
	[102] = {2.130, -0.280, -0.640, 0.030}, -- Transmog-Human-Male-Shoulder
	[103] = {2.000, 0.000, -0.210, -2.648}, -- Transmog-Human-Male-Back
	[104] = {1.880, 0.020, -0.190, -0.310}, -- Transmog-Human-Male-Robe
	[105] = {2.230, 0.030, -0.420, -0.368}, -- Transmog-Human-Male-Shirt
	[106] = {2.040, 0.030, -0.250, 0.009}, -- Transmog-Human-Male-Tabard
	[107] = {2.130, -0.250, -0.140, -0.598}, -- Transmog-Human-Male-Wrist
	[108] = {2.190, -0.230, -0.060, -0.506}, -- Transmog-Human-Male-Hands
	[109] = {2.230, 0.020, -0.220, 0.068}, -- Transmog-Human-Male-Waist
	[110] = {1.770, 0.020, 0.250, -0.160}, -- Transmog-Human-Male-Legs
	[111] = {2.080, 0.050, 0.570, -0.700}, -- Transmog-Human-Male-Feet
	[112] = {2.160, 0.030, -0.430, 0.310}, -- Transmog-Human-Male-Chest
	[114] = {-0.670, 0.000, -0.380, 0.000}, -- Transmog-Set-Details-Human-Male
	[115] = {1.100, 0.020, -0.360, 0.000}, -- Transmog-Set-Vendor-Human-Male
	[116] = {1.950, 0.040, -0.660, -0.545}, -- Transmog-Human-Female-Head
	[117] = {1.970, -0.140, -0.530, -0.335}, -- Transmog-Human-Female-Shoulder
	[118] = {1.600, 0.000, -0.220, -2.648}, -- Transmog-Human-Female-Back
	[119] = {1.620, 0.050, -0.200, -0.310}, -- Transmog-Human-Female-Robe
	[120] = {1.770, 0.010, -0.360, -0.310}, -- Transmog-Human-Female-Shirt
	[121] = {1.820, 0.010, -0.320, -0.228}, -- Transmog-Human-Female-Tabard
	[122] = {1.920, -0.180, -0.120, -0.598}, -- Transmog-Human-Female-Wrist
	[123] = {1.830, -0.160, -0.050, -0.817}, -- Transmog-Human-Female-Hands
	[124] = {1.820, 0.030, -0.160, 0.008}, -- Transmog-Human-Female-Waist
	[125] = {1.520, 0.030, 0.150, -0.045}, -- Transmog-Human-Female-Legs
	[126] = {1.620, 0.000, 0.560, -0.478}, -- Transmog-Human-Female-Feet
	[127] = {1.830, 0.030, -0.370, -0.310}, -- Transmog-Human-Female-Chest
	[129] = {-0.880, 0.000, -0.390, 0.000}, -- Transmog-Set-Details-Human-Female
	[130] = {1.170, 0.020, -0.410, 0.000}, -- Transmog-Set-Vendor-Human-Female
	[131] = {2.340, 0.070, -0.860, -0.456, 15}, -- Transmog-Orc-Male-Head
	[132] = {2.300, -0.410, -0.760, -0.232, 15}, -- Transmog-Orc-Male-Shoulder
	[133] = {1.510, -0.080, -0.020, -2.830, 15}, -- Transmog-Orc-Male-Back
	[134] = {1.910, 0.010, -0.150, -0.330, 15}, -- Transmog-Orc-Male-Robe
	[135] = {2.370, 0.020, -0.520, -0.330, 15}, -- Transmog-Orc-Male-Shirt
	[136] = {2.310, 0.010, -0.340, -0.065, 15}, -- Transmog-Orc-Male-Tabard
	[137] = {2.510, -0.370, -0.110, -0.598}, -- Transmog-Orc-Male-Wrist
	[138] = {2.270, -0.420, 0.070, -0.445}, -- Transmog-Orc-Male-Hands
	[139] = {2.630, 0.020, -0.240, -0.111, 15}, -- Transmog-Orc-Male-Waist
	[140] = {2.050, 0.010, 0.230, 0.085, 15}, -- Transmog-Orc-Male-Legs
	[141] = {2.190, -0.020, 0.630, -1.290, 15}, -- Transmog-Orc-Male-Feet
	[142] = {2.320, 0.020, -0.470, -0.330, 15}, -- Transmog-Orc-Male-Chest
	[144] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Orc-Male
	[145] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Orc-Male
	[146] = {2.340, 0.020, -0.660, -0.482, 15}, -- Transmog-Orc-Female-Head
	[147] = {2.380, -0.260, -0.500, -0.390}, -- Transmog-Orc-Female-Shoulder
	[148] = {1.850, -0.050, -0.010, -3.048, 15}, -- Transmog-Orc-Female-Back
	[149] = {1.950, 0.010, -0.120, -0.466, 15}, -- Transmog-Orc-Female-Robe
	[150] = {2.280, 0.010, -0.370, -0.466, 15}, -- Transmog-Orc-Female-Shirt
	[151] = {2.390, 0.000, -0.330, -0.214, 15}, -- Transmog-Orc-Female-Tabard
	[152] = {2.560, -0.360, -0.080, -0.598}, -- Transmog-Orc-Female-Wrist
	[153] = {2.340, -0.310, 0.010, -0.594, 8}, -- Transmog-Orc-Female-Hands
	[154] = {2.480, -0.020, -0.100, -0.168}, -- Transmog-Orc-Female-Waist
	[155] = {1.790, -0.020, 0.300, -0.160, 15}, -- Transmog-Orc-Female-Legs
	[156] = {2.050, 0.010, 0.670, -1.555, 15}, -- Transmog-Orc-Female-Feet
	[157] = {2.230, 0.010, -0.360, -0.466, 15}, -- Transmog-Orc-Female-Chest
	[159] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Orc-Female
	[160] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Orc-Female
	[161] = {2.790, -0.010, -0.600, -0.314}, -- Transmog-Dwarf-Male-Head
	[162] = {2.700, -0.350, -0.490, -0.194}, -- Transmog-Dwarf-Male-Shoulder
	[163] = {2.320, 0.000, -0.060, -3.157}, -- Transmog-Dwarf-Male-Back
	[164] = {2.310, 0.010, -0.030, -0.382}, -- Transmog-Dwarf-Male-Robe
	[165] = {2.720, -0.010, -0.330, -0.368}, -- Transmog-Dwarf-Male-Shirt
	[166] = {2.790, -0.010, -0.290, 0.048}, -- Transmog-Dwarf-Male-Tabard
	[167] = {2.790, -0.330, -0.110, -0.598}, -- Transmog-Dwarf-Male-Wrist
	[168] = {2.740, -0.370, 0.010, -0.310}, -- Transmog-Dwarf-Male-Hands
	[169] = {2.810, 0.000, -0.100, 0.083}, -- Transmog-Dwarf-Male-Waist
	[170] = {2.590, -0.030, 0.140, -0.377}, -- Transmog-Dwarf-Male-Legs
	[171] = {2.510, -0.030, 0.350, -0.775}, -- Transmog-Dwarf-Male-Feet
	[172] = {2.570, 0.010, -0.250, -0.368}, -- Transmog-Dwarf-Male-Chest
	[174] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Dwarf-Male
	[175] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Dwarf-Male
	[176] = {1.510, -0.030, -0.380, -0.376}, -- Transmog-Dwarf-Female-Head
	[177] = {1.560, -0.250, -0.220, -0.320}, -- Transmog-Dwarf-Female-Shoulder
	[178] = {1.270, -0.030, 0.080, -3.214}, -- Transmog-Dwarf-Female-Back
	[179] = {1.250, 0.000, 0.110, -0.310}, -- Transmog-Dwarf-Female-Robe
	[180] = {1.570, 0.000, -0.090, -0.368}, -- Transmog-Dwarf-Female-Shirt
	[181] = {1.560, -0.020, -0.090, -0.018}, -- Transmog-Dwarf-Female-Tabard
	[182] = {1.620, -0.240, 0.090, -0.598}, -- Transmog-Dwarf-Female-Wrist
	[183] = {1.570, -0.260, 0.170, -0.523}, -- Transmog-Dwarf-Female-Hands
	[184] = {1.570, -0.020, 0.090, -0.007}, -- Transmog-Dwarf-Female-Waist
	[185] = {1.400, -0.020, 0.310, -0.089}, -- Transmog-Dwarf-Female-Legs
	[186] = {1.370, -0.050, 0.550, -0.798}, -- Transmog-Dwarf-Female-Feet
	[187] = {1.540, -0.010, -0.090, -0.368}, -- Transmog-Dwarf-Female-Chest
	[189] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Dwarf-Female
	[190] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Dwarf-Female
	[191] = {2.920, 0.040, -0.930, -0.456}, -- Transmog-NightElf-Male-Head
	[192] = {2.750, -0.290, -0.730, -0.265}, -- Transmog-NightElf-Male-Shoulder
	[193] = {1.910, -0.070, -0.150, -2.822}, -- Transmog-NightElf-Male-Back
	[194] = {2.190, 0.000, -0.180, -0.336}, -- Transmog-NightElf-Male-Robe
	[195] = {2.920, 0.020, -0.570, -0.370}, -- Transmog-NightElf-Male-Shirt
	[196] = {3.060, 0.010, -0.560, 0.016}, -- Transmog-NightElf-Male-Tabard
	[197] = {3.090, -0.260, -0.230, -0.598}, -- Transmog-NightElf-Male-Wrist
	[198] = {2.740, -0.270, -0.110, -0.514}, -- Transmog-NightElf-Male-Hands
	[199] = {3.260, 0.000, -0.260, -0.007}, -- Transmog-NightElf-Male-Waist
	[200] = {2.550, 0.000, 0.190, 0.000}, -- Transmog-NightElf-Male-Legs
	[201] = {2.480, -0.040, 0.640, -1.086}, -- Transmog-NightElf-Male-Feet
	[202] = {2.760, 0.030, -0.560, -0.370}, -- Transmog-NightElf-Male-Chest
	[204] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-NightElf-Male
	[205] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-NightElf-Male
	[206] = {3.360, -0.010, -0.830, -0.411}, -- Transmog-NightElf-Female-Head
	[207] = {3.290, -0.240, -0.640, -0.316}, -- Transmog-NightElf-Female-Shoulder
	[208] = {2.710, -0.050, -0.160, -2.852}, -- Transmog-NightElf-Female-Back
	[209] = {2.890, 0.000, -0.250, -0.310}, -- Transmog-NightElf-Female-Robe
	[210] = {3.300, 0.000, -0.450, -0.299}, -- Transmog-NightElf-Female-Shirt
	[211] = {3.370, 0.005, -0.450, -0.006}, -- Transmog-NightElf-Female-Tabard
	[212] = {3.380, -0.200, -0.180, -0.598}, -- Transmog-NightElf-Female-Wrist
	[213] = {3.160, -0.230, -0.120, -0.826}, -- Transmog-NightElf-Female-Hands
	[214] = {3.440, 0.005, -0.240, 0.026}, -- Transmog-NightElf-Female-Waist
	[215] = {2.890, 0.000, 0.100, -0.071}, -- Transmog-NightElf-Female-Legs
	[216] = {2.950, -0.070, 0.690, -1.130}, -- Transmog-NightElf-Female-Feet
	[217] = {3.220, -0.000, -0.480, -0.299}, -- Transmog-NightElf-Female-Chest
	[219] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-NightElf-Female
	[220] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-NightElf-Female
	[221] = {2.150, 0.120, -0.650, -0.258}, -- Transmog-Scourge-Male-Head
	[222] = {2.090, -0.270, -0.550, 0.626}, -- Transmog-Scourge-Male-Shoulder
	[223] = {1.570, -0.310, 0.010, -2.460}, -- Transmog-Scourge-Male-Back
	[224] = {1.620, 0.020, -0.090, 0.766}, -- Transmog-Scourge-Male-Robe
	[225] = {2.220, 0.060, -0.440, 0.672}, -- Transmog-Scourge-Male-Shirt
	[226] = {2.140, 0.040, -0.330, 0.697}, -- Transmog-Scourge-Male-Tabard
	[227] = {2.210, -0.320, -0.090, 0.344}, -- Transmog-Scourge-Male-Wrist
	[228] = {2.210, -0.300, -0.000, 0.475}, -- Transmog-Scourge-Male-Hands
	[229] = {2.470, 0.040, -0.210, 0.410}, -- Transmog-Scourge-Male-Waist
	[230] = {1.990, 0.080, 0.040, 1.117}, -- Transmog-Scourge-Male-Legs
	[231] = {1.990, -0.140, 0.490, -0.611}, -- Transmog-Scourge-Male-Feet
	[232] = {2.080, 0.040, -0.430, 0.672}, -- Transmog-Scourge-Male-Chest
	[234] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Scourge-Male
	[235] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Scourge-Male
	[236] = {3.110, 0.060, -0.610, -0.441}, -- Transmog-Scourge-Female-Head
	[237] = {3.160, -0.220, -0.490, 0.021}, -- Transmog-Scourge-Female-Shoulder
	[238] = {2.740, -0.070, 0.080, -2.808}, -- Transmog-Scourge-Female-Back
	[239] = {2.720, 0.010, -0.060, -0.364}, -- Transmog-Scourge-Female-Robe
	[240] = {3.270, 0.010, -0.300, -0.368}, -- Transmog-Scourge-Female-Shirt
	[241] = {3.100, 0.000, -0.230, -0.012}, -- Transmog-Scourge-Female-Tabard
	[242] = {3.100, -0.220, -0.120, -0.598}, -- Transmog-Scourge-Female-Wrist
	[243] = {3.010, -0.200, -0.030, -0.520}, -- Transmog-Scourge-Female-Hands
	[244] = {3.320, 0.000, -0.110, 0.062}, -- Transmog-Scourge-Female-Waist
	[245] = {2.870, 0.000, 0.260, 0.018}, -- Transmog-Scourge-Female-Legs
	[246] = {2.840, 0.000, 0.550, -0.576}, -- Transmog-Scourge-Female-Feet
	[247] = {3.130, 0.010, -0.330, -0.368}, -- Transmog-Scourge-Female-Chest
	[249] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Scourge-Female
	[250] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Scourge-Female
	[251] = {2.990, 0.120, -0.580, -0.340}, -- Transmog-Tauren-Male-Head
	[252] = {3.100, -0.530, -0.530, -0.021}, -- Transmog-Tauren-Male-Shoulder
	[253] = {2.810, -0.130, 0.000, -2.781}, -- Transmog-Tauren-Male-Back
	[254] = {2.910, -0.000, -0.040, -0.435}, -- Transmog-Tauren-Male-Robe
	[255] = {3.160, 0.060, -0.430, -0.386}, -- Transmog-Tauren-Male-Shirt
	[256] = {3.200, -0.030, -0.180, 0.109}, -- Transmog-Tauren-Male-Tabard
	[257] = {3.400, -0.480, -0.010, -0.598}, -- Transmog-Tauren-Male-Wrist
	[258] = {3.360, -0.560, 0.190, -0.270}, -- Transmog-Tauren-Male-Hands
	[259] = {3.500, -0.020, -0.010, 0.134}, -- Transmog-Tauren-Male-Waist
	[260] = {3.340, -0.020, 0.300, -0.281}, -- Transmog-Tauren-Male-Legs
	[261] = {3.300, -0.020, 0.580, -0.411}, -- Transmog-Tauren-Male-Feet
	[262] = {3.110, -0.010, -0.390, -0.386}, -- Transmog-Tauren-Male-Chest
	[264] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Tauren-Male
	[265] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Tauren-Male
	[266] = {2.310, 0.080, -0.370, -0.287}, -- Transmog-Tauren-Female-Head
	[267] = {2.310, -0.280, -0.270, -0.048}, -- Transmog-Tauren-Female-Shoulder
	[268] = {1.700, -0.040, 0.190, -2.950}, -- Transmog-Tauren-Female-Back
	[269] = {1.840, -0.010, 0.230, -0.310}, -- Transmog-Tauren-Female-Robe
	[270] = {2.260, 0.020, -0.090, -0.311}, -- Transmog-Tauren-Female-Shirt
	[271] = {2.190, 0.020, 0.100, -0.024}, -- Transmog-Tauren-Female-Tabard
	[272] = {2.470, -0.320, 0.250, -0.598}, -- Transmog-Tauren-Female-Wrist
	[273] = {2.190, 0.290, 0.330, 0.933}, -- Transmog-Tauren-Female-Hands
	[274] = {2.440, 0.020, 0.290, -0.021}, -- Transmog-Tauren-Female-Waist
	[275] = {2.150, 0.020, 0.630, -0.116}, -- Transmog-Tauren-Female-Legs
	[276] = {2.230, -0.000, 0.900, -0.259}, -- Transmog-Tauren-Female-Feet
	[277] = {2.160, -0.000, -0.090, -0.311}, -- Transmog-Tauren-Female-Chest
	[279] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Tauren-Female
	[280] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Tauren-Female
	[281] = {1.180, 0.030, -0.230, -0.493}, -- Transmog-Gnome-Male-Head
	[282] = {1.390, -0.230, -0.120, -0.176}, -- Transmog-Gnome-Male-Shoulder
	[283] = {1.230, -0.060, 0.220, -2.838}, -- Transmog-Gnome-Male-Back
	[284] = {1.390, -0.020, 0.190, -0.481}, -- Transmog-Gnome-Male-Robe
	[285] = {1.560, -0.010, 0.030, -0.368}, -- Transmog-Gnome-Male-Shirt
	[286] = {1.540, 0.000, 0.140, 0.106}, -- Transmog-Gnome-Male-Tabard
	[287] = {1.550, -0.290, 0.160, -0.598, 11}, -- Transmog-Gnome-Male-Wrist
	[288] = {1.490, -0.290, 0.220, -0.506, 11}, -- Transmog-Gnome-Male-Hands
	[289] = {1.570, -0.000, 0.150, -0.045}, -- Transmog-Gnome-Male-Waist
	[290] = {1.520, -0.030, 0.300, -0.356}, -- Transmog-Gnome-Male-Legs
	[291] = {1.490, -0.040, 0.390, -0.984}, -- Transmog-Gnome-Male-Feet
	[292] = {1.530, -0.010, 0.050, -0.368}, -- Transmog-Gnome-Male-Chest
	[294] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Gnome-Male
	[295] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Gnome-Male
	[296] = {1.160, -0.010, -0.190, -0.376}, -- Transmog-Gnome-Female-Head
	[297] = {1.350, -0.190, -0.000, -0.120}, -- Transmog-Gnome-Female-Shoulder
	[298] = {1.120, -0.090, 0.200, -2.648}, -- Transmog-Gnome-Female-Back
	[299] = {1.250, -0.020, 0.200, -0.351}, -- Transmog-Gnome-Female-Robe
	[300] = {1.350, -0.020, 0.070, -0.368}, -- Transmog-Gnome-Female-Shirt
	[301] = {1.360, 0.000, 0.140, 0.119}, -- Transmog-Gnome-Female-Tabard
	[302] = {1.340, -0.230, 0.190, -0.598}, -- Transmog-Gnome-Female-Wrist
	[303] = {1.340, -0.230, 0.230, -0.523}, -- Transmog-Gnome-Female-Hands
	[304] = {1.370, -0.010, 0.190, -0.015}, -- Transmog-Gnome-Female-Waist
	[305] = {1.350, -0.030, 0.290, -0.325}, -- Transmog-Gnome-Female-Legs
	[306] = {1.270, -0.050, 0.390, -0.925}, -- Transmog-Gnome-Female-Feet
	[307] = {1.340, -0.050, 0.050, -0.368}, -- Transmog-Gnome-Female-Chest
	[309] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Gnome-Female
	[310] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Gnome-Female
	[311] = {3.020, 0.140, -0.540, -0.385}, -- Transmog-Troll-Male-Head
	[312] = {2.870, -0.480, -0.550, 0.201}, -- Transmog-Troll-Male-Shoulder
	[313] = {2.570, -0.090, 0.010, -2.959}, -- Transmog-Troll-Male-Back
	[314] = {2.740, 0.010, 0.180, -0.399, 131}, -- Transmog-Troll-Male-Robe
	[315] = {3.170, 0.040, -0.020, -0.546, 131}, -- Transmog-Troll-Male-Shirt
	[316] = {3.110, 0.030, 0.070, -0.270, 131}, -- Transmog-Troll-Male-Tabard
	[317] = {3.380, -0.440, 0.230, -0.198}, -- Transmog-Troll-Male-Wrist
	[318] = {3.070, -0.440, 0.310, -0.337}, -- Transmog-Troll-Male-Hands
	[319] = {3.450, -0.000, 0.290, -0.022, 131}, -- Transmog-Troll-Male-Waist
	[320] = {3.000, -0.030, 0.430, -0.088}, -- Transmog-Troll-Male-Legs
	[321] = {2.950, -0.060, 0.870, -0.659}, -- Transmog-Troll-Male-Feet
	[322] = {3.140, 0.030, -0.030, -0.546, 131}, -- Transmog-Troll-Male-Chest
	[324] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Troll-Male
	[325] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Troll-Male
	[326] = {2.910, -0.010, -0.690, -0.394}, -- Transmog-Troll-Female-Head
	[327] = {2.960, -0.290, -0.490, -0.249}, -- Transmog-Troll-Female-Shoulder
	[328] = {2.390, -0.170, -0.070, -2.664}, -- Transmog-Troll-Female-Back
	[329] = {2.740, -0.040, -0.120, -0.310}, -- Transmog-Troll-Female-Robe
	[330] = {2.980, -0.040, -0.310, -0.368}, -- Transmog-Troll-Female-Shirt
	[331] = {2.850, -0.040, -0.190, -0.032}, -- Transmog-Troll-Female-Tabard
	[332] = {3.000, -0.290, 0.000, -0.598}, -- Transmog-Troll-Female-Wrist
	[333] = {2.840, -0.270, 0.060, -0.705}, -- Transmog-Troll-Female-Hands
	[334] = {3.050, -0.050, -0.060, -0.016}, -- Transmog-Troll-Female-Waist
	[335] = {2.570, -0.050, 0.420, 0.000, 41}, -- Transmog-Troll-Female-Legs
	[336] = {2.700, -0.050, 0.850, -0.407}, -- Transmog-Troll-Female-Feet
	[337] = {2.940, -0.040, -0.330, -0.368}, -- Transmog-Troll-Female-Chest
	[339] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Troll-Female
	[340] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Troll-Female
	[341] = {1.840, 0.050, -0.180, -0.331}, -- Transmog-Goblin-Male-Head
	[342] = {1.920, -0.250, -0.030, -0.138}, -- Transmog-Goblin-Male-Shoulder
	[343] = {1.590, -0.030, 0.340, -2.799}, -- Transmog-Goblin-Male-Back
	[344] = {1.720, 0.010, 0.320, 0.083}, -- Transmog-Goblin-Male-Robe
	[345] = {2.020, -0.000, 0.150, -0.172}, -- Transmog-Goblin-Male-Shirt
	[346] = {2.030, -0.010, 0.220, 0.202}, -- Transmog-Goblin-Male-Tabard
	[347] = {1.950, -0.260, 0.270, -0.598}, -- Transmog-Goblin-Male-Wrist
	[348] = {1.830, -0.210, 0.340, -0.692}, -- Transmog-Goblin-Male-Hands
	[349] = {2.130, -0.010, 0.330, 0.217}, -- Transmog-Goblin-Male-Waist
	[350] = {1.990, -0.010, 0.460, -0.463}, -- Transmog-Goblin-Male-Legs
	[351] = {1.790, 0.010, 0.580, -0.753}, -- Transmog-Goblin-Male-Feet
	[352] = {1.990, -0.020, 0.120, -0.172}, -- Transmog-Goblin-Male-Chest
	[354] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Goblin-Male
	[355] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Goblin-Male
	[356] = {1.970, -0.030, -0.240, -0.474}, -- Transmog-Goblin-Female-Head
	[357] = {2.180, -0.250, -0.010, -0.195}, -- Transmog-Goblin-Female-Shoulder
	[358] = {1.710, -0.080, 0.290, -2.835}, -- Transmog-Goblin-Female-Back
	[359] = {1.900, -0.010, 0.280, -0.324}, -- Transmog-Goblin-Female-Robe
	[360] = {2.210, -0.000, 0.120, -0.375}, -- Transmog-Goblin-Female-Shirt
	[361] = {2.180, 0.000, 0.190, -0.096}, -- Transmog-Goblin-Female-Tabard
	[362] = {2.080, -0.270, 0.310, -0.625}, -- Transmog-Goblin-Female-Wrist
	[363] = {2.000, -0.270, 0.380, -0.621}, -- Transmog-Goblin-Female-Hands
	[364] = {2.220, -0.000, 0.300, -0.113}, -- Transmog-Goblin-Female-Waist
	[365] = {2.100, -0.010, 0.440, -0.187}, -- Transmog-Goblin-Female-Legs
	[366] = {2.020, 0.020, 0.600, 0.678}, -- Transmog-Goblin-Female-Feet
	[367] = {2.160, -0.020, 0.110, -0.375}, -- Transmog-Goblin-Female-Chest
	[369] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Goblin-Female
	[370] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Goblin-Female
	[371] = {2.810, 0.030, -0.860, -0.367, 1}, -- Transmog-BloodElf-Male-Head
	[372] = {2.750, -0.250, -0.680, 0.071, 1}, -- Transmog-BloodElf-Male-Shoulder
	[373] = {2.390, -0.160, -0.220, -2.499, 1}, -- Transmog-BloodElf-Male-Back
	[374] = {2.590, 0.040, -0.270, -0.079, 1}, -- Transmog-BloodElf-Male-Robe
	[375] = {2.870, 0.020, -0.550, -0.048, 1}, -- Transmog-BloodElf-Male-Shirt
	[376] = {2.780, -0.000, -0.400, 0.351, 1}, -- Transmog-BloodElf-Male-Tabard
	[377] = {2.870, -0.180, -0.330, -0.598, 1}, -- Transmog-BloodElf-Male-Wrist
	[378] = {2.750, -0.180, -0.190, -0.710, 1}, -- Transmog-BloodElf-Male-Hands
	[379] = {2.940, 0.010, -0.310, 0.287, 1}, -- Transmog-BloodElf-Male-Waist
	[380] = {2.650, 0.010, -0.010, 0.107, 1}, -- Transmog-BloodElf-Male-Legs
	[381] = {2.630, -0.110, 0.520, -0.700, 1}, -- Transmog-BloodElf-Male-Feet
	[382] = {2.850, -0.000, -0.540, -0.048}, -- Transmog-BloodElf-Male-Chest
	[384] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-BloodElf-Male
	[385] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-BloodElf-Male
	[386] = {2.310, 0.050, -0.700, -0.607}, -- Transmog-BloodElf-Female-Head
	[387] = {2.410, -0.130, -0.520, -0.179}, -- Transmog-BloodElf-Female-Shoulder
	[388] = {2.020, -0.020, -0.170, -2.969}, -- Transmog-BloodElf-Female-Back
	[389] = {2.030, 0.090, -0.170, -0.497}, -- Transmog-BloodElf-Female-Robe
	[390] = {2.360, 0.070, -0.360, -0.466}, -- Transmog-BloodElf-Female-Shirt
	[391] = {2.270, 0.050, -0.250, -0.228}, -- Transmog-BloodElf-Female-Tabard
	[392] = {2.400, -0.130, -0.100, -0.598}, -- Transmog-BloodElf-Female-Wrist
	[393] = {2.290, -0.110, -0.030, -0.826}, -- Transmog-BloodElf-Female-Hands
	[394] = {2.370, 0.040, -0.170, -0.299}, -- Transmog-BloodElf-Female-Waist
	[395] = {2.110, 0.060, 0.120, -0.354}, -- Transmog-BloodElf-Female-Legs
	[396] = {2.120, 0.070, 0.580, -1.604}, -- Transmog-BloodElf-Female-Feet
	[397] = {2.310, 0.050, -0.350, -0.466}, -- Transmog-BloodElf-Female-Chest
	[399] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-BloodElf-Female
	[400] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-BloodElf-Female
	[401] = {3.430, 0.100, -0.870, -0.447}, -- Transmog-Draenei-Male-Head
	[402] = {3.040, -0.380, -0.670, -0.614}, -- Transmog-Draenei-Male-Shoulder
	[403] = {2.880, -0.050, 0.000, -3.485}, -- Transmog-Draenei-Male-Back
	[404] = {2.690, 0.110, -0.040, -0.837}, -- Transmog-Draenei-Male-Robe
	[405] = {3.270, 0.120, -0.410, -0.897}, -- Transmog-Draenei-Male-Shirt
	[406] = {3.070, 0.070, -0.250, -0.333}, -- Transmog-Draenei-Male-Tabard
	[407] = {3.470, -0.360, -0.130, -0.651}, -- Transmog-Draenei-Male-Wrist
	[408] = {3.480, -0.430, 0.000, -0.328}, -- Transmog-Draenei-Male-Hands
	[409] = {3.420, 0.050, -0.040, -0.333}, -- Transmog-Draenei-Male-Waist
	[410] = {3.150, 0.010, 0.310, 0.195}, -- Transmog-Draenei-Male-Legs
	[411] = {3.460, 0.090, 0.700, 0.172}, -- Transmog-Draenei-Male-Feet
	[412] = {3.210, 0.090, -0.410, -0.897}, -- Transmog-Draenei-Male-Chest
	[414] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Draenei-Male
	[415] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Draenei-Male
	[416] = {2.950, -0.040, -0.920, -0.420}, -- Transmog-Draenei-Female-Head
	[417] = {2.950, -0.260, -0.730, -0.468}, -- Transmog-Draenei-Female-Shoulder
	[418] = {2.340, 0.010, -0.090, -3.059}, -- Transmog-Draenei-Female-Back
	[419] = {2.610, 0.010, -0.270, -0.363}, -- Transmog-Draenei-Female-Robe
	[420] = {2.980, -0.030, -0.490, -0.412}, -- Transmog-Draenei-Female-Shirt
	[421] = {2.920, -0.030, -0.400, -0.165}, -- Transmog-Draenei-Female-Tabard
	[422] = {3.110, -0.250, -0.250, -0.598}, -- Transmog-Draenei-Female-Wrist
	[423] = {2.830, -0.220, -0.140, -0.897}, -- Transmog-Draenei-Female-Hands
	[424] = {3.070, -0.040, -0.250, -0.068}, -- Transmog-Draenei-Female-Waist
	[425] = {2.710, -0.040, 0.110, -0.206}, -- Transmog-Draenei-Female-Legs
	[426] = {2.660, -0.060, 0.610, -1.533}, -- Transmog-Draenei-Female-Feet
	[427] = {2.960, -0.030, -0.480, -0.412}, -- Transmog-Draenei-Female-Chest
	[429] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Draenei-Female
	[430] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Draenei-Female
	[431] = {2.660, 0.150, -0.810, -0.411, 8}, -- Transmog-Worgen-Male-Head
	[432] = {2.580, -0.590, -0.780, 0.174, 8}, -- Transmog-Worgen-Male-Shoulder
	[433] = {2.590, -0.110, -0.290, -2.648, 8}, -- Transmog-Worgen-Male-Back
	[434] = {2.570, -0.030, -0.150, -0.378, 8}, -- Transmog-Worgen-Male-Robe
	[435] = {3.030, -0.040, -0.660, -0.440, 8}, -- Transmog-Worgen-Male-Shirt
	[436] = {3.180, -0.030, -0.510, -0.237, 8}, -- Transmog-Worgen-Male-Tabard
	[437] = {3.020, -0.490, -0.220, -0.598, 8}, -- Transmog-Worgen-Male-Wrist
	[438] = {2.810, -0.560, -0.100, -0.292, 8}, -- Transmog-Worgen-Male-Hands
	[439] = {3.210, -0.030, -0.370, 0.081, 8}, -- Transmog-Worgen-Male-Waist
	[440] = {2.950, -0.070, 0.110, -0.498, 8}, -- Transmog-Worgen-Male-Legs
	[441] = {2.770, -0.150, 0.540, -0.484, 8}, -- Transmog-Worgen-Male-Feet
	[442] = {2.860, -0.140, -0.700, -0.440, 8}, -- Transmog-Worgen-Male-Chest
	[444] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Worgen-Male
	[445] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Worgen-Male
	[446] = {3.860, 0.720, -0.810, -0.358, 11}, -- Transmog-Worgen-Female-Head
	[447] = {3.780, 0.350, -0.570, 0.016, 11}, -- Transmog-Worgen-Female-Shoulder
	[448] = {3.500, 0.500, -0.070, -2.692, 11}, -- Transmog-Worgen-Female-Back
	[449] = {3.640, 0.660, -0.130, -0.061, 11}, -- Transmog-Worgen-Female-Robe
	[450] = {4.100, 0.730, -0.450, -0.172, 11}, -- Transmog-Worgen-Female-Shirt
	[451] = {3.960, 0.740, -0.280, 0.163, 11}, -- Transmog-Worgen-Female-Tabard
	[452] = {4.120, 0.420, -0.110, -0.269, 11}, -- Transmog-Worgen-Female-Wrist
	[453] = {3.930, 0.380, -0.010, -0.317, 11}, -- Transmog-Worgen-Female-Hands
	[454] = {4.160, 0.780, -0.130, 0.245, 11}, -- Transmog-Worgen-Female-Waist
	[455] = {3.610, 0.620, 0.280, -0.133, 11}, -- Transmog-Worgen-Female-Legs
	[456] = {3.690, 0.630, 0.660, -0.282, 11}, -- Transmog-Worgen-Female-Feet
	[457] = {4.060, 0.700, -0.420, -0.172, 11}, -- Transmog-Worgen-Female-Chest
	[459] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Worgen-Female
	[460] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Worgen-Female
	[461] = {2.930, 0.190, -0.690, -0.320, 8}, -- Transmog-Naga-Male-Head
	[462] = {3.170, -0.320, -0.550, -0.110, 8}, -- Transmog-Naga-Male-Shoulder
	[463] = {2.950, 0.050, 0.100, -2.850, 8}, -- Transmog-Naga-Male-Back
	[464] = {2.610, 0.240, 0.280, -0.380, 8}, -- Transmog-Naga-Male-Robe
	[465] = {3.340, 0.110, -0.330, -0.290, 8}, -- Transmog-Naga-Male-Shirt
	[466] = {3.190, 0.070, -0.080, -0.110, 8}, -- Transmog-Naga-Male-Tabard
	[467] = {3.410, -0.370, 0.150, -0.470, 8}, -- Transmog-Naga-Male-Wrist
	[468] = {3.220, -0.300, 0.310, -0.490, 8}, -- Transmog-Naga-Male-Hands
	[469] = {3.540, 0.090, 0.040, -0.020, 8}, -- Transmog-Naga-Male-Waist
	[470] = {3.250, 0.160, 0.400, -0.120, 8}, -- Transmog-Naga-Male-Legs
	[471] = {3.190, 0.320, 0.530, -0.520, 8}, -- Transmog-Naga-Male-Feet
	[472] = {3.170, 0.070, -0.360, -0.290, 8}, -- Transmog-Naga-Male-Chest
	[474] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Naga-Male
	[475] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Naga-Male
	[476] = {3.690, 0.110, -0.650, -0.370, 8}, -- Transmog-Naga-Female-Head
	[477] = {3.710, -0.170, -0.490, -0.180, 8}, -- Transmog-Naga-Female-Shoulder
	[478] = {3.160, 0.090, 0.170, -2.930, 8}, -- Transmog-Naga-Female-Back
	[479] = {3.200, 0.110, 0.070, -0.330, 8}, -- Transmog-Naga-Female-Robe
	[480] = {3.700, 0.090, -0.210, -0.240, 8}, -- Transmog-Naga-Female-Shirt
	[481] = {3.660, 0.090, -0.080, -0.010, 8}, -- Transmog-Naga-Female-Tabard
	[482] = {3.730, -0.260, -0.010, -0.230, 8}, -- Transmog-Naga-Female-Wrist
	[483] = {3.460, -0.290, 0.160, -0.180, 8}, -- Transmog-Naga-Female-Hands
	[484] = {3.720, 0.080, 0.070, -0.020, 8}, -- Transmog-Naga-Female-Waist
	[485] = {3.470, 0.030, 0.340, -0.080, 8}, -- Transmog-Naga-Female-Legs
	[486] = {3.410, 0.090, 0.660, -0.540, 8}, -- Transmog-Naga-Female-Feet
	[487] = {3.580, 0.090, -0.240, -0.240, 8}, -- Transmog-Naga-Female-Chest
	[489] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Naga-Female
	[490] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Naga-Female
	[491] = {2.770, 0.030, -0.850, -0.651, 8}, -- Transmog-Pandaren-Male-Head
	[492] = {2.730, -0.530, -0.630, -0.091, 8}, -- Transmog-Pandaren-Male-Shoulder
	[493] = {1.900, -0.150, 0.220, -2.890, 8}, -- Transmog-Pandaren-Male-Back
	[494] = {2.200, 0.030, 0.220, -0.337, 8}, -- Transmog-Pandaren-Male-Robe
	[495] = {2.590, -0.010, -0.100, -0.368, 8}, -- Transmog-Pandaren-Male-Shirt
	[496] = {2.490, 0.020, 0.070, -0.192, 8}, -- Transmog-Pandaren-Male-Tabard
	[497] = {2.620, -0.600, 0.030, -0.598, 8}, -- Transmog-Pandaren-Male-Wrist
	[498] = {2.930, -0.600, 0.070, -0.310, 8}, -- Transmog-Pandaren-Male-Hands
	[499] = {2.650, 0.030, 0.240, -0.137, 8}, -- Transmog-Pandaren-Male-Waist
	[500] = {2.430, -0.090, 0.490, -0.933, 8}, -- Transmog-Pandaren-Male-Legs
	[501] = {2.690, -0.190, 0.700, -1.260, 8}, -- Transmog-Pandaren-Male-Feet
	[502] = {2.510, 0.010, -0.140, -0.368, 8}, -- Transmog-Pandaren-Male-Chest
	[504] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Pandaren-Male
	[505] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Pandaren-Male
	[506] = {2.000, 0.030, -0.750, -0.518, 8}, -- Transmog-Pandaren-Female-Head
	[507] = {2.040, -0.400, -0.520, -0.019, 8}, -- Transmog-Pandaren-Female-Shoulder
	[508] = {1.350, -0.180, 0.180, -2.648, 8}, -- Transmog-Pandaren-Female-Back
	[509] = {1.770, 0.010, 0.020, -0.106, 8}, -- Transmog-Pandaren-Female-Robe
	[510] = {2.070, 0.010, -0.180, -0.252, 8}, -- Transmog-Pandaren-Female-Shirt
	[511] = {2.070, 0.020, -0.080, 0.172, 8}, -- Transmog-Pandaren-Female-Tabard
	[512] = {2.100, -0.280, 0.020, -0.598, 8}, -- Transmog-Pandaren-Female-Wrist
	[513] = {2.270, -0.390, 0.120, 0.091, 8}, -- Transmog-Pandaren-Female-Hands
	[514] = {2.240, 0.000, 0.050, 0.347, 8}, -- Transmog-Pandaren-Female-Waist
	[515] = {2.040, -0.020, 0.380, 0.320, 8}, -- Transmog-Pandaren-Female-Legs
	[516] = {2.140, -0.010, 0.640, 0.155, 8}, -- Transmog-Pandaren-Female-Feet
	[517] = {2.110, 0.040, -0.200, -0.252, 8}, -- Transmog-Pandaren-Female-Chest
	[519] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Pandaren-Female
	[520] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Pandaren-Female
	[521] = {2.810, 0.030, -0.860, -0.367, 1}, -- Transmog-Queldo-Male-Head
	[522] = {2.750, -0.250, -0.680, 0.071, 1}, -- Transmog-Queldo-Male-Shoulder
	[523] = {2.390, -0.160, -0.220, -2.499, 1}, -- Transmog-Queldo-Male-Back
	[524] = {2.590, 0.040, -0.270, -0.079, 1}, -- Transmog-Queldo-Male-Robe
	[525] = {2.870, 0.020, -0.550, -0.048, 1}, -- Transmog-Queldo-Male-Shirt
	[526] = {2.780, -0.000, -0.400, 0.351, 1}, -- Transmog-Queldo-Male-Tabard
	[527] = {2.870, -0.180, -0.330, -0.598, 1}, -- Transmog-Queldo-Male-Wrist
	[528] = {2.750, -0.180, -0.190, -0.710, 1}, -- Transmog-Queldo-Male-Hands
	[529] = {2.940, 0.010, -0.310, 0.287, 1}, -- Transmog-Queldo-Male-Waist
	[530] = {2.650, 0.010, -0.010, 0.107, 1}, -- Transmog-Queldo-Male-Legs
	[531] = {2.630, -0.110, 0.520, -0.700, 1}, -- Transmog-Queldo-Male-Feet
	[532] = {2.850, -0.000, -0.540, -0.048}, -- Transmog-Queldo-Male-Chest
	[534] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Queldo-Male
	[535] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Queldo-Male
	[536] = {2.310, 0.050, -0.700, -0.607}, -- Transmog-Queldo-Female-Head
	[537] = {2.410, -0.130, -0.520, -0.179}, -- Transmog-Queldo-Female-Shoulder
	[538] = {2.020, -0.020, -0.170, -2.969}, -- Transmog-Queldo-Female-Back
	[539] = {2.030, 0.090, -0.170, -0.497}, -- Transmog-Queldo-Female-Robe
	[540] = {2.360, 0.070, -0.360, -0.466}, -- Transmog-Queldo-Female-Shirt
	[541] = {2.270, 0.050, -0.250, -0.228}, -- Transmog-Queldo-Female-Tabard
	[542] = {2.400, -0.130, -0.100, -0.598}, -- Transmog-Queldo-Female-Wrist
	[543] = {2.290, -0.110, -0.030, -0.826}, -- Transmog-Queldo-Female-Hands
	[544] = {2.370, 0.040, -0.170, -0.299}, -- Transmog-Queldo-Female-Waist
	[545] = {2.110, 0.060, 0.120, -0.354}, -- Transmog-Queldo-Female-Legs
	[546] = {2.120, 0.070, 0.580, -1.604}, -- Transmog-Queldo-Female-Feet
	[547] = {2.310, 0.050, -0.350, -0.466}, -- Transmog-Queldo-Female-Chest
	[549] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Queldo-Female
	[550] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Queldo-Female
	[581] = {3.320, -0.010, -0.790, -0.456, 60}, -- Transmog-Nightborne-Male-Head
	[582] = {3.300, -0.340, -0.550, -0.265, 60}, -- Transmog-Nightborne-Male-Shoulder
	[583] = {2.660, -0.100, 0.110, -2.822, 60}, -- Transmog-Nightborne-Male-Back
	[584] = {2.990, -0.010, -0.060, -0.336, 60}, -- Transmog-Nightborne-Male-Robe
	[585] = {3.410, -0.050, -0.340, -0.370, 60}, -- Transmog-Nightborne-Male-Shirt
	[586] = {3.350, -0.040, -0.240, 0.016, 60}, -- Transmog-Nightborne-Male-Tabard
	[587] = {3.590, -0.380, -0.020, -0.598, 60}, -- Transmog-Nightborne-Male-Wrist
	[588] = {3.180, -0.380, 0.080, -0.514, 60}, -- Transmog-Nightborne-Male-Hands
	[589] = {3.500, -0.040, -0.090, -0.007, 60}, -- Transmog-Nightborne-Male-Waist
	[590] = {2.950, -0.020, 0.320, -0.370, 60}, -- Transmog-Nightborne-Male-Legs
	[591] = {2.900, -0.000, 0.840, 0.534, 60}, -- Transmog-Nightborne-Male-Feet
	[592] = {3.380, -0.050, -0.370, -0.370, 60}, -- Transmog-Nightborne-Male-Chest
	[594] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Nightborne-Male
	[595] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Nightborne-Male
	[596] = {3.190, 0.070, -0.820, -0.411, 60}, -- Transmog-Nightborne-Female-Head
	[597] = {3.190, -0.150, -0.630, -0.316, 60}, -- Transmog-Nightborne-Female-Shoulder
	[598] = {2.860, -0.060, -0.130, -2.668, 60}, -- Transmog-Nightborne-Female-Back
	[599] = {2.750, 0.070, -0.180, 0.061, 60}, -- Transmog-Nightborne-Female-Robe
	[600] = {3.230, 0.080, -0.420, -0.056, 60}, -- Transmog-Nightborne-Female-Shirt
	[601] = {3.110, 0.060, -0.330, 0.288, 60}, -- Transmog-Nightborne-Female-Tabard
	[602] = {3.270, -0.120, -0.160, -0.592, 60}, -- Transmog-Nightborne-Female-Wrist
	[603] = {3.040, -0.070, -0.100, -0.826, 60}, -- Transmog-Nightborne-Female-Hands
	[604] = {3.260, 0.060, -0.200, 0.308, 60}, -- Transmog-Nightborne-Female-Waist
	[605] = {2.770, 0.030, 0.150, 0.351, 60}, -- Transmog-Nightborne-Female-Legs
	[606] = {2.890, 0.010, 0.710, -0.642, 60}, -- Transmog-Nightborne-Female-Feet
	[607] = {3.190, 0.080, -0.430, -0.056, 60}, -- Transmog-Nightborne-Female-Chest
	[609] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Nightborne-Female
	[610] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Nightborne-Female
	[611] = {2.970, 0.040, -0.870, -0.367, 60}, -- Transmog-VoidElf-Male-Head
	[612] = {2.780, -0.240, -0.660, 0.071, 60}, -- Transmog-VoidElf-Male-Shoulder
	[613] = {2.240, -0.150, -0.040, -2.499, 60}, -- Transmog-VoidElf-Male-Back
	[614] = {2.490, 0.000, -0.270, -0.079, 60}, -- Transmog-VoidElf-Male-Robe
	[615] = {2.910, 0.030, -0.520, -0.048, 60}, -- Transmog-VoidElf-Male-Shirt
	[616] = {2.860, 0.005, -0.410, 0.351, 60}, -- Transmog-VoidElf-Male-Tabard
	[617] = {2.960, -0.190, -0.280, -0.598, 60}, -- Transmog-VoidElf-Male-Wrist
	[618] = {2.810, -0.180, -0.180, -0.710, 60}, -- Transmog-VoidElf-Male-Hands
	[619] = {2.990, 0.010, -0.310, 0.287, 60}, -- Transmog-VoidElf-Male-Waist
	[620] = {2.500, -0.030, 0.100, 0.107, 60}, -- Transmog-VoidElf-Male-Legs
	[621] = {2.580, -0.100, 0.510, -0.700, 60}, -- Transmog-VoidElf-Male-Feet
	[622] = {2.910, 0.020, -0.520, -0.048, 60}, -- Transmog-VoidElf-Male-Chest
	[624] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-VoidElf-Male
	[625] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-VoidElf-Male
	[626] = {2.330, 0.050, -0.680, -0.607, 60}, -- Transmog-VoidElf-Female-Head
	[627] = {2.420, -0.130, -0.490, -0.179, 60}, -- Transmog-VoidElf-Female-Shoulder
	[628] = {1.800, 0.010, -0.020, -2.969, 60}, -- Transmog-VoidElf-Female-Back
	[629] = {2.080, 0.050, -0.180, -0.497, 60}, -- Transmog-VoidElf-Female-Robe
	[630] = {2.390, 0.060, -0.330, -0.466, 60}, -- Transmog-VoidElf-Female-Shirt
	[631] = {2.300, 0.060, -0.270, -0.228, 60}, -- Transmog-VoidElf-Female-Tabard
	[632] = {2.450, -0.140, -0.120, -0.598, 60}, -- Transmog-VoidElf-Female-Wrist
	[633] = {2.300, -0.140, -0.030, -0.826, 60}, -- Transmog-VoidElf-Female-Hands
	[634] = {2.410, 0.050, -0.170, -0.299, 60}, -- Transmog-VoidElf-Female-Waist
	[635] = {2.230, 0.060, 0.060, -0.354, 60}, -- Transmog-VoidElf-Female-Legs
	[636] = {2.130, 0.060, 0.570, -1.604, 60}, -- Transmog-VoidElf-Female-Feet
	[637] = {2.350, 0.060, -0.340, -0.466, 60}, -- Transmog-VoidElf-Female-Chest
	[639] = {-0.240, 0.000, -0.180, 0.000}, -- Transmog-Set-Details-VoidElf-Female
	[640] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-VoidElf-Female
	[641] = {2.700, 0.030, -0.220, -0.331, 8}, -- Transmog-Vulpera-Male-Head
	[642] = {2.790, -0.310, -0.050, -0.138, 8}, -- Transmog-Vulpera-Male-Shoulder
	[643] = {2.900, -0.080, 0.250, -2.799, 8}, -- Transmog-Vulpera-Male-Back
	[644] = {2.800, 0.000, 0.350, 0.000, 8}, -- Transmog-Vulpera-Male-Robe
	[645] = {3.190, -0.000, 0.120, -0.172, 8}, -- Transmog-Vulpera-Male-Shirt
	[646] = {3.200, 0.010, 0.210, 0.131, 8}, -- Transmog-Vulpera-Male-Tabard
	[647] = {3.130, -0.240, 0.310, -0.598, 8}, -- Transmog-Vulpera-Male-Wrist
	[648] = {3.270, -0.280, 0.380, 0.289, 8}, -- Transmog-Vulpera-Male-Hands
	[649] = {3.280, 0.020, 0.300, 0.118, 8}, -- Transmog-Vulpera-Male-Waist
	[650] = {3.140, -0.020, 0.460, -0.513, 8}, -- Transmog-Vulpera-Male-Legs
	[651] = {3.100, -0.050, 0.630, -0.582, 8}, -- Transmog-Vulpera-Male-Feet
	[652] = {3.170, 0.000, 0.110, -0.172, 8}, -- Transmog-Vulpera-Male-Chest
	[654] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Vulpera-Male
	[655] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Vulpera-Male
	[656] = {2.810, 0.030, -0.230, -0.474, 8}, -- Transmog-Vulpera-Female-Head
	[657] = {3.000, -0.230, 0.030, -0.195, 8}, -- Transmog-Vulpera-Female-Shoulder
	[658] = {3.010, -0.150, 0.220, -2.835, 8}, -- Transmog-Vulpera-Female-Back
	[659] = {2.890, 0.010, 0.330, -0.324, 8}, -- Transmog-Vulpera-Female-Robe
	[660] = {3.310, 0.010, 0.130, -0.375, 8}, -- Transmog-Vulpera-Female-Shirt
	[661] = {3.280, 0.020, 0.210, 0.146, 8}, -- Transmog-Vulpera-Female-Tabard
	[662] = {3.160, -0.240, 0.330, -0.625, 8}, -- Transmog-Vulpera-Female-Wrist
	[663] = {2.850, -0.110, 0.340, 2.302, 8}, -- Transmog-Vulpera-Female-Hands
	[664] = {3.320, 0.020, 0.310, 0.100, 8}, -- Transmog-Vulpera-Female-Waist
	[665] = {3.190, -0.020, 0.450, -0.492, 8}, -- Transmog-Vulpera-Female-Legs
	[666] = {3.100, -0.040, 0.630, -0.560, 8}, -- Transmog-Vulpera-Female-Feet
	[667] = {3.210, 0.000, 0.120, -0.375, 8}, -- Transmog-Vulpera-Female-Chest
	[669] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Vulpera-Female
	[670] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Vulpera-Female
	[821] = {3.430, 0.100, -0.870, -0.447}, -- Transmog-Eredar-Male-Head
	[822] = {3.040, -0.380, -0.670, -0.614}, -- Transmog-Eredar-Male-Shoulder
	[823] = {2.880, -0.050, 0.000, -3.485}, -- Transmog-Eredar-Male-Back
	[824] = {2.690, 0.110, -0.040, -0.837}, -- Transmog-Eredar-Male-Robe
	[825] = {3.270, 0.120, -0.410, -0.897}, -- Transmog-Eredar-Male-Shirt
	[826] = {3.070, 0.070, -0.250, -0.333}, -- Transmog-Eredar-Male-Tabard
	[827] = {3.470, -0.360, -0.130, -0.651}, -- Transmog-Eredar-Male-Wrist
	[828] = {3.480, -0.430, 0.000, -0.328}, -- Transmog-Eredar-Male-Hands
	[829] = {3.420, 0.050, -0.040, -0.333}, -- Transmog-Eredar-Male-Waist
	[830] = {3.150, 0.010, 0.310, 0.195}, -- Transmog-Eredar-Male-Legs
	[831] = {3.460, 0.090, 0.700, 0.172}, -- Transmog-Eredar-Male-Feet
	[832] = {3.210, 0.090, -0.410, -0.897}, -- Transmog-Eredar-Male-Chest
	[834] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Eredar-Male
	[835] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Eredar-Male
	[836] = {2.950, -0.040, -0.920, -0.420}, -- Transmog-Eredar-Female-Head
	[837] = {2.950, -0.260, -0.730, -0.468}, -- Transmog-Eredar-Female-Shoulder
	[838] = {2.340, 0.010, -0.090, -3.059}, -- Transmog-Eredar-Female-Back
	[839] = {2.610, 0.010, -0.270, -0.363}, -- Transmog-Eredar-Female-Robe
	[840] = {2.980, -0.030, -0.490, -0.412}, -- Transmog-Eredar-Female-Shirt
	[841] = {2.920, -0.030, -0.400, -0.165}, -- Transmog-Eredar-Female-Tabard
	[842] = {3.110, -0.250, -0.250, -0.598}, -- Transmog-Eredar-Female-Wrist
	[843] = {2.830, -0.220, -0.140, -0.897}, -- Transmog-Eredar-Female-Hands
	[844] = {3.070, -0.040, -0.250, -0.068}, -- Transmog-Eredar-Female-Waist
	[845] = {2.710, -0.040, 0.110, -0.206}, -- Transmog-Eredar-Female-Legs
	[846] = {2.660, -0.060, 0.610, -1.533}, -- Transmog-Eredar-Female-Feet
	[847] = {2.960, -0.030, -0.480, -0.412}, -- Transmog-Eredar-Female-Chest
	[849] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-Eredar-Female
	[850] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-Eredar-Female
	[851] = {2.220, -0.010, -0.490, -0.314}, -- Transmog-DarkIronDwarf-Male-Head
	[852] = {2.220, -0.330, -0.350, -0.194}, -- Transmog-DarkIronDwarf-Male-Shoulder
	[853] = {1.890, 0.010, 0.100, -3.157}, -- Transmog-DarkIronDwarf-Male-Back
	[854] = {1.910, -0.010, 0.110, -0.382}, -- Transmog-DarkIronDwarf-Male-Robe
	[855] = {2.330, -0.010, -0.110, -0.368}, -- Transmog-DarkIronDwarf-Male-Shirt
	[856] = {2.240, -0.010, -0.030, 0.048}, -- Transmog-DarkIronDwarf-Male-Tabard
	[857] = {2.240, -0.320, 0.070, -0.598}, -- Transmog-DarkIronDwarf-Male-Wrist
	[858] = {2.240, -0.370, 0.180, -0.310}, -- Transmog-DarkIronDwarf-Male-Hands
	[859] = {2.360, -0.010, 0.070, 0.083}, -- Transmog-DarkIronDwarf-Male-Waist
	[860] = {2.030, -0.020, 0.350, -0.377}, -- Transmog-DarkIronDwarf-Male-Legs
	[861] = {2.020, -0.020, 0.490, -0.775}, -- Transmog-DarkIronDwarf-Male-Feet
	[862] = {2.340, -0.010, -0.110, -0.368}, -- Transmog-DarkIronDwarf-Male-Chest
	[864] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-DarkIronDwarf-Male
	[865] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-DarkIronDwarf-Male
	[866] = {1.510, -0.030, -0.380, -0.376}, -- Transmog-DarkIronDwarf-Female-Head
	[867] = {1.560, -0.250, -0.220, -0.320}, -- Transmog-DarkIronDwarf-Female-Shoulder
	[868] = {1.270, -0.030, 0.080, -3.214}, -- Transmog-DarkIronDwarf-Female-Back
	[869] = {1.250, 0.000, 0.110, -0.310}, -- Transmog-DarkIronDwarf-Female-Robe
	[870] = {1.570, 0.000, -0.090, -0.368}, -- Transmog-DarkIronDwarf-Female-Shirt
	[871] = {1.560, -0.020, -0.090, -0.018}, -- Transmog-DarkIronDwarf-Female-Tabard
	[872] = {1.620, -0.240, 0.090, -0.598}, -- Transmog-DarkIronDwarf-Female-Wrist
	[873] = {1.570, -0.260, 0.170, -0.523}, -- Transmog-DarkIronDwarf-Female-Hands
	[874] = {1.570, -0.020, 0.090, -0.007}, -- Transmog-DarkIronDwarf-Female-Waist
	[875] = {1.400, -0.020, 0.310, -0.089}, -- Transmog-DarkIronDwarf-Female-Legs
	[876] = {1.370, -0.050, 0.550, -0.798}, -- Transmog-DarkIronDwarf-Female-Feet
	[877] = {1.540, -0.010, -0.090, -0.368}, -- Transmog-DarkIronDwarf-Female-Chest
	[879] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Details-DarkIronDwarf-Female
	[880] = {0.000, 0.000, 0.000, 0.000}, -- Transmog-Set-Vendor-DarkIronDwarf-Female
};

UI_CAMERA = {
	["Human"] = {
		["Male"] = {[1] = 101, [2] = 102, [3] = 103, [4] = 104, [5] = 105, [6] = 106, [7] = 107, [8] = 108, [9] = 109, [10] = 110, [11] = 111, [12] = 112, [14] = 114, [15] = 115},
		["Female"] = {[1] = 116, [2] = 117, [3] = 118, [4] = 119, [5] = 120, [6] = 121, [7] = 122, [8] = 123, [9] = 124, [10] = 125, [11] = 126, [12] = 127, [14] = 129, [15] = 130},
	},
	["Orc"] = {
		["Male"] = {[1] = 131, [2] = 132, [3] = 133, [4] = 134, [5] = 135, [6] = 136, [7] = 137, [8] = 138, [9] = 139, [10] = 140, [11] = 141, [12] = 142, [14] = 144, [15] = 145},
		["Female"] = {[1] = 146, [2] = 147, [3] = 148, [4] = 149, [5] = 150, [6] = 151, [7] = 152, [8] = 153, [9] = 154, [10] = 155, [11] = 156, [12] = 157, [14] = 159, [15] = 160},
	},
	["Dwarf"] = {
		["Male"] = {[1] = 161, [2] = 162, [3] = 163, [4] = 164, [5] = 165, [6] = 166, [7] = 167, [8] = 168, [9] = 169, [10] = 170, [11] = 171, [12] = 172, [14] = 174, [15] = 175},
		["Female"] = {[1] = 176, [2] = 177, [3] = 178, [4] = 179, [5] = 180, [6] = 181, [7] = 182, [8] = 183, [9] = 184, [10] = 185, [11] = 186, [12] = 187, [14] = 189, [15] = 190},
	},
	["NightElf"] = {
		["Male"] = {[1] = 191, [2] = 192, [3] = 193, [4] = 194, [5] = 195, [6] = 196, [7] = 197, [8] = 198, [9] = 199, [10] = 200, [11] = 201, [12] = 202, [14] = 204, [15] = 205},
		["Female"] = {[1] = 206, [2] = 207, [3] = 208, [4] = 209, [5] = 210, [6] = 211, [7] = 212, [8] = 213, [9] = 214, [10] = 215, [11] = 216, [12] = 217, [14] = 219, [15] = 220},
	},
	["Scourge"] = {
		["Male"] = {[1] = 221, [2] = 222, [3] = 223, [4] = 224, [5] = 225, [6] = 226, [7] = 227, [8] = 228, [9] = 229, [10] = 230, [11] = 231, [12] = 232, [14] = 234, [15] = 235},
		["Female"] = {[1] = 236, [2] = 237, [3] = 238, [4] = 239, [5] = 240, [6] = 241, [7] = 242, [8] = 243, [9] = 244, [10] = 245, [11] = 246, [12] = 247, [14] = 249, [15] = 250},
	},
	["Tauren"] = {
		["Male"] = {[1] = 251, [2] = 252, [3] = 253, [4] = 254, [5] = 255, [6] = 256, [7] = 257, [8] = 258, [9] = 259, [10] = 260, [11] = 261, [12] = 262, [14] = 264, [15] = 265},
		["Female"] = {[1] = 266, [2] = 267, [3] = 268, [4] = 269, [5] = 270, [6] = 271, [7] = 272, [8] = 273, [9] = 274, [10] = 275, [11] = 276, [12] = 277, [14] = 279, [15] = 280},
	},
	["Gnome"] = {
		["Male"] = {[1] = 281, [2] = 282, [3] = 283, [4] = 284, [5] = 285, [6] = 286, [7] = 287, [8] = 288, [9] = 289, [10] = 290, [11] = 291, [12] = 292, [14] = 294, [15] = 295},
		["Female"] = {[1] = 296, [2] = 297, [3] = 298, [4] = 299, [5] = 300, [6] = 301, [7] = 302, [8] = 303, [9] = 304, [10] = 305, [11] = 306, [12] = 307, [14] = 309, [15] = 310},
	},
	["Troll"] = {
		["Male"] = {[1] = 311, [2] = 312, [3] = 313, [4] = 314, [5] = 315, [6] = 316, [7] = 317, [8] = 318, [9] = 319, [10] = 320, [11] = 321, [12] = 322, [14] = 324, [15] = 325},
		["Female"] = {[1] = 326, [2] = 327, [3] = 328, [4] = 329, [5] = 330, [6] = 331, [7] = 332, [8] = 333, [9] = 334, [10] = 335, [11] = 336, [12] = 337, [14] = 339, [15] = 340},
	},
	["Goblin"] = {
		["Male"] = {[1] = 341, [2] = 342, [3] = 343, [4] = 344, [5] = 345, [6] = 346, [7] = 347, [8] = 348, [9] = 349, [10] = 350, [11] = 351, [12] = 352, [14] = 354, [15] = 355},
		["Female"] = {[1] = 356, [2] = 357, [3] = 358, [4] = 359, [5] = 360, [6] = 361, [7] = 362, [8] = 363, [9] = 364, [10] = 365, [11] = 366, [12] = 367, [14] = 369, [15] = 370},
	},
	["BloodElf"] = {
		["Male"] = {[1] = 371, [2] = 372, [3] = 373, [4] = 374, [5] = 375, [6] = 376, [7] = 377, [8] = 378, [9] = 379, [10] = 380, [11] = 381, [12] = 382, [14] = 384, [15] = 385},
		["Female"] = {[1] = 386, [2] = 387, [3] = 388, [4] = 389, [5] = 390, [6] = 391, [7] = 392, [8] = 393, [9] = 394, [10] = 395, [11] = 396, [12] = 397, [14] = 399, [15] = 400},
	},
	["Draenei"] = {
		["Male"] = {[1] = 401, [2] = 402, [3] = 403, [4] = 404, [5] = 405, [6] = 406, [7] = 407, [8] = 408, [9] = 409, [10] = 410, [11] = 411, [12] = 412, [14] = 414, [15] = 415},
		["Female"] = {[1] = 416, [2] = 417, [3] = 418, [4] = 419, [5] = 420, [6] = 421, [7] = 422, [8] = 423, [9] = 424, [10] = 425, [11] = 426, [12] = 427, [14] = 429, [15] = 430},
	},
	["Worgen"] = {
		["Male"] = {[1] = 431, [2] = 432, [3] = 433, [4] = 434, [5] = 435, [6] = 436, [7] = 437, [8] = 438, [9] = 439, [10] = 440, [11] = 441, [12] = 442, [14] = 444, [15] = 445},
		["Female"] = {[1] = 446, [2] = 447, [3] = 448, [4] = 449, [5] = 450, [6] = 451, [7] = 452, [8] = 453, [9] = 454, [10] = 455, [11] = 456, [12] = 457, [14] = 459, [15] = 460},
	},
	["Naga"] = {
		["Male"] = {[1] = 461, [2] = 462, [3] = 463, [4] = 464, [5] = 465, [6] = 466, [7] = 467, [8] = 468, [9] = 469, [10] = 470, [11] = 471, [12] = 472, [14] = 474, [15] = 475},
		["Female"] = {[1] = 476, [2] = 477, [3] = 478, [4] = 479, [5] = 480, [6] = 481, [7] = 482, [8] = 483, [9] = 484, [10] = 485, [11] = 486, [12] = 487, [14] = 489, [15] = 490},
	},
	["Pandaren"] = {
		["Male"] = {[1] = 491, [2] = 492, [3] = 493, [4] = 494, [5] = 495, [6] = 496, [7] = 497, [8] = 498, [9] = 499, [10] = 500, [11] = 501, [12] = 502, [14] = 504, [15] = 505},
		["Female"] = {[1] = 506, [2] = 507, [3] = 508, [4] = 509, [5] = 510, [6] = 511, [7] = 512, [8] = 513, [9] = 514, [10] = 515, [11] = 516, [12] = 517, [14] = 519, [15] = 520},
	},
	["Queldo"] = {
		["Male"] = {[1] = 521, [2] = 522, [3] = 523, [4] = 524, [5] = 525, [6] = 526, [7] = 527, [8] = 528, [9] = 529, [10] = 530, [11] = 531, [12] = 532, [14] = 534, [15] = 535},
		["Female"] = {[1] = 536, [2] = 537, [3] = 538, [4] = 539, [5] = 540, [6] = 541, [7] = 542, [8] = 543, [9] = 544, [10] = 545, [11] = 546, [12] = 547, [14] = 549, [15] = 550},
	},
	["Nightborne"] = {
		["Male"] = {[1] = 581, [2] = 582, [3] = 583, [4] = 584, [5] = 585, [6] = 586, [7] = 587, [8] = 588, [9] = 589, [10] = 590, [11] = 591, [12] = 592, [14] = 594, [15] = 595},
		["Female"] = {[1] = 596, [2] = 597, [3] = 598, [4] = 599, [5] = 600, [6] = 601, [7] = 602, [8] = 603, [9] = 604, [10] = 605, [11] = 606, [12] = 607, [14] = 609, [15] = 610},
	},
	["VoidElf"] = {
		["Male"] = {[1] = 611, [2] = 612, [3] = 613, [4] = 614, [5] = 615, [6] = 616, [7] = 617, [8] = 618, [9] = 619, [10] = 620, [11] = 621, [12] = 622, [14] = 624, [15] = 625},
		["Female"] = {[1] = 626, [2] = 627, [3] = 628, [4] = 629, [5] = 630, [6] = 631, [7] = 632, [8] = 633, [9] = 634, [10] = 635, [11] = 636, [12] = 637, [14] = 639, [15] = 640},
	},
	["Vulpera"] = {
		["Male"] = {[1] = 641, [2] = 642, [3] = 643, [4] = 644, [5] = 645, [6] = 646, [7] = 647, [8] = 648, [9] = 649, [10] = 650, [11] = 651, [12] = 652, [14] = 654, [15] = 655},
		["Female"] = {[1] = 656, [2] = 657, [3] = 658, [4] = 659, [5] = 660, [6] = 661, [7] = 662, [8] = 663, [9] = 664, [10] = 665, [11] = 666, [12] = 667, [14] = 669, [15] = 670},
	},
	["Eredar"] = {
		["Male"] = {[1] = 821, [2] = 822, [3] = 823, [4] = 824, [5] = 825, [6] = 826, [7] = 827, [8] = 828, [9] = 829, [10] = 830, [11] = 831, [12] = 832, [14] = 834, [15] = 835},
		["Female"] = {[1] = 836, [2] = 837, [3] = 838, [4] = 839, [5] = 840, [6] = 841, [7] = 842, [8] = 843, [9] = 844, [10] = 845, [11] = 846, [12] = 847, [14] = 849, [15] = 850},
	},
	["DarkIronDwarf"] = {
		["Male"] = {[1] = 851, [2] = 852, [3] = 853, [4] = 854, [5] = 855, [6] = 856, [7] = 857, [8] = 858, [9] = 859, [10] = 860, [11] = 861, [12] = 862, [14] = 864, [15] = 865},
		["Female"] = {[1] = 866, [2] = 867, [3] = 868, [4] = 869, [5] = 870, [6] = 871, [7] = 872, [8] = 873, [9] = 874, [10] = 875, [11] = 876, [12] = 877, [14] = 879, [15] = 880},
	},
};

MODELFRAME_DRAG_ROTATION_CONSTANT = 0.010
MODELFRAME_MAX_ZOOM = 0.7
MODELFRAME_MIN_ZOOM = 0.0
MODELFRAME_ZOOM_STEP = 0.15
MODELFRAME_DEFAULT_ROTATION = 0.61
ROTATIONS_PER_SECOND = .5
MODELFRAME_MAX_PLAYER_ZOOM = 0.8

local ModelSettings = {
	["HumanMale"] = { panMaxLeft = -0.4, panMaxRight = 0.4, panMaxTop = 1.2, panMaxBottom = -0.3, panValue = 38 },
	["HumanFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 1.2, panMaxBottom = -0.2, panValue = 45 },
	["OrcMale"] = { panMaxLeft = -0.7, panMaxRight = 0.8, panMaxTop = 1.2, panMaxBottom = -0.3, panValue = 30 },
	["OrcFemale"] = { panMaxLeft = -0.4, panMaxRight = 0.3, panMaxTop = 1.2, panMaxBottom = -0.3, panValue = 37 },
	["DwarfMale"] = { panMaxLeft = -0.4, panMaxRight = 0.6, panMaxTop = 0.9, panMaxBottom = -0.2, panValue = 44 },
	["DwarfFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 0.9, panMaxBottom = -0.2, panValue = 47 },
	["NightElfMale"] = { panMaxLeft = -0.5, panMaxRight = 0.5, panMaxTop = 1.5, panMaxBottom = -0.4, panValue = 30 },
	["NightElfFemale"] = { panMaxLeft = -0.4, panMaxRight = 0.4, panMaxTop = 1.4, panMaxBottom = -0.4, panValue = 33 },
	["ScourgeMale"] = { panMaxLeft = -0.4, panMaxRight = 0.4, panMaxTop = 1.1, panMaxBottom = -0.3, panValue = 35 },
	["ScourgeFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.4, panMaxTop = 1.1, panMaxBottom = -0.3, panValue = 36 },
	["TaurenMale"] = { panMaxLeft = -0.7, panMaxRight = 0.9, panMaxTop = 1.1, panMaxBottom = -0.5, panValue = 31 },
	["TaurenFemale"] = { panMaxLeft = -0.5, panMaxRight = 0.6, panMaxTop = 1.3, panMaxBottom = -0.4, panValue = 32 },
	["GnomeMale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 0.5, panMaxBottom = -0.2, panValue = 52 },
	["GnomeFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 0.5, panMaxBottom = -0.2, panValue = 60 },
	["TrollMale"] = { panMaxLeft = -0.5, panMaxRight = 0.6, panMaxTop = 1.3, panMaxBottom = -0.4, panValue = 27 },
	["TrollFemale"] = { panMaxLeft = -0.4, panMaxRight = 0.4, panMaxTop = 1.5, panMaxBottom = -0.4, panValue = 31 },
	["GoblinMale"] = { panMaxLeft = -0.3, panMaxRight = 0.4, panMaxTop = 0.7, panMaxBottom = -0.2, panValue = 43 },
	["GoblinFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 0.7, panMaxBottom = -0.3, panValue = 43 },
	["BloodElfMale"] = { panMaxLeft = -0.5, panMaxRight = 0.4, panMaxTop = 1.3, panMaxBottom = -0.3, panValue = 36 },
	["BloodElfFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.2, panMaxTop = 1.2, panMaxBottom = -0.3, panValue = 38 },
	["DraeneiMale"] = { panMaxLeft = -0.6, panMaxRight = 0.6, panMaxTop = 1.4, panMaxBottom = -0.4, panValue = 28 },
	["DraeneiFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 1.4, panMaxBottom = -0.3, panValue = 31 },
	["WorgenMale"] = { panMaxLeft = -0.6, panMaxRight = 0.8, panMaxTop = 1.2, panMaxBottom = -0.4, panValue = 25 },
	["WorgenMaleAlt"] = { panMaxLeft = -0.4, panMaxRight = 0.4, panMaxTop = 1.3, panMaxBottom = -0.3, panValue = 37 },
	["WorgenFemale"] = { panMaxLeft = -0.4, panMaxRight = 0.6, panMaxTop = 1.4, panMaxBottom = -0.4, panValue = 25 },
	["WorgenFemaleAlt"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 1.2, panMaxBottom = -0.2, panValue = 45 },
	["PandarenMale"] = { panMaxLeft = -0.7, panMaxRight = 0.9, panMaxTop = 1.1, panMaxBottom = -0.5, panValue = 31 },
	["PandarenFemale"] = { panMaxLeft = -0.5, panMaxRight = 0.6, panMaxTop = 1.3, panMaxBottom = -0.4, panValue = 32 },
	["QueldoMale"] = { panMaxLeft = -0.5, panMaxRight = 0.4, panMaxTop = 1.3, panMaxBottom = -0.3, panValue = 36 },
	["QueldoFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.2, panMaxTop = 1.2, panMaxBottom = -0.3, panValue = 38 },
	["NagaMale"] = { panMaxLeft = -0.4, panMaxRight = 0.4, panMaxTop = 1.2, panMaxBottom = -0.3, panValue = 38 },
	["NagaFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 1.2, panMaxBottom = -0.2, panValue = 45 },
	["NightborneMale"] = { panMaxLeft = -0.5, panMaxRight = 0.5, panMaxTop = 1.5, panMaxBottom = -0.4, panValue = 30 },
	["NightborneFemale"] = { panMaxLeft = -0.4, panMaxRight = 0.4, panMaxTop = 1.4, panMaxBottom = -0.4, panValue = 33 },
	["VoidElfMale"] = { panMaxLeft = -0.5, panMaxRight = 0.4, panMaxTop = 1.3, panMaxBottom = -0.3, panValue = 36 },
	["VoidElfFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.2, panMaxTop = 1.2, panMaxBottom = -0.3, panValue = 38 },
	["EredarMale"] = { panMaxLeft = -0.6, panMaxRight = 0.6, panMaxTop = 1.4, panMaxBottom = -0.4, panValue = 28 },
	["EredarFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 1.4, panMaxBottom = -0.3, panValue = 31 },
	["DarkIronDwarfMale"] = { panMaxLeft = -0.4, panMaxRight = 0.6, panMaxTop = 0.9, panMaxBottom = -0.2, panValue = 44 },
	["DarkIronDwarfFemale"] = { panMaxLeft = -0.3, panMaxRight = 0.3, panMaxTop = 0.9, panMaxBottom = -0.2, panValue = 47 },
}

local playerRaceSex
if ( UIParent ) then
	local _
	_, playerRaceSex = UnitRace("player")
	if ( UnitSex("player") == 2 ) then
		playerRaceSex = playerRaceSex.."Male"
	else
		playerRaceSex = playerRaceSex.."Female"
	end
end

function SharedXML_Model_OnLoad( self, maxZoom, minZoom, defaultRotation, onMouseUp )
	self.maxZoom = maxZoom or MODELFRAME_MAX_ZOOM
	self.minZoom = minZoom or MODELFRAME_MIN_ZOOM
	self.defaultRotation = defaultRotation or MODELFRAME_DEFAULT_ROTATION
	self.onMouseUpFunc = onMouseUp or SharedXML_Model_OnMouseUp

	self.rotation = self.defaultRotation
	self:SetRotation(self.rotation)
	self:RegisterEvent("UI_SCALE_CHANGED")
	self:RegisterEvent("DISPLAY_SIZE_CHANGED")
end

function SharedXML_Model_OnEvent( self, ... )
	-- self:RefreshCamera()
end

function SharedXML_Model_RotateLeft(model, rotationIncrement)
	if ( not rotationIncrement ) then
		rotationIncrement = 0.03
	end
	model.rotation = model.rotation - rotationIncrement
	model:SetRotation(model.rotation)
	PlaySound("igInventoryRotateCharacter")
end

function SharedXML_Model_RotateRight(model, rotationIncrement)
	if ( not rotationIncrement ) then
		rotationIncrement = 0.03
	end
	model.rotation = model.rotation + rotationIncrement
	model:SetRotation(model.rotation)
	PlaySound("igInventoryRotateCharacter")
end

function SharedXML_Model_OnMouseDown(model, button)
	if ( not button or button == "LeftButton" ) then
		model.mouseDown = true
		model.rotationCursorStart = GetCursorPosition()
	end
end

function SharedXML_Model_OnMouseUp(model, button)
	if ( not button or button == "LeftButton" ) then
		model.mouseDown = false
	end
end

function SharedXML_Model_OnMouseWheel(self, delta, maxZoom, minZoom)
	if self.disabledZooming then
		return
	end

	maxZoom = maxZoom or self.maxZoom
	minZoom = minZoom or self.minZoom
	local zoomLevel = self.zoomLevel or minZoom
	zoomLevel = zoomLevel + delta * MODELFRAME_ZOOM_STEP
	zoomLevel = min(zoomLevel, maxZoom)
	zoomLevel = max(zoomLevel, minZoom)
	local _, cameraY, cameraZ = self:GetPosition()
	self:SetPosition((self.positionX or 0) + zoomLevel, cameraY, cameraZ)
	self.zoomLevel = zoomLevel
end

function SharedXML_Model_OnUpdate(self, elapsedTime, rotationsPerSecond)
	if ( not rotationsPerSecond ) then
		rotationsPerSecond = ROTATIONS_PER_SECOND
	end

	-- Mouse drag rotation
	if (self.mouseDown) then
		if ( self.rotationCursorStart ) then
			local x = GetCursorPosition()
			local diff = (x - self.rotationCursorStart) * MODELFRAME_DRAG_ROTATION_CONSTANT
			self.rotationCursorStart = GetCursorPosition()
			self.rotation = self.rotation + diff
			if ( self.rotation < 0 ) then
				self.rotation = self.rotation + (2 * PI)
			end
			if ( self.rotation > (2 * PI) ) then
				self.rotation = self.rotation - (2 * PI)
			end
			self:SetRotation(self.rotation, false)
		end
	elseif ( self.panning ) then
		local modelScale = self:GetModelScale()
		local cursorX, cursorY = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		ModelPanningFrame:SetPoint("BOTTOMLEFT", cursorX / scale - 16, cursorY / scale - 16)	-- half the texture size to center it on the cursor
		-- settings
		local settings = ModelSettings[playerRaceSex]

		local zoom = self.zoomLevel or self.minZoom
		zoom = 1 + zoom - self.minZoom	-- want 1 at minimum zoom

		-- Panning should require roughly the same mouse movement regardless of zoom level so the model moves at the same rate as the cursor
		-- This formula more or less works for all zoom levels, found via trial and error
		local transformationRatio = settings.panValue * 2 ^ (zoom * 2) * scale / modelScale

		local positionY, positionZ = (self.positionY or 0), (self.positionX or 0)
		local dx = (cursorX - self.cursorX) / transformationRatio
		local dy = (cursorY - self.cursorY) / transformationRatio
		local cameraY = self.cameraY + dx - positionY
		local cameraZ = self.cameraZ + dy - positionZ
		-- bounds
		scale = scale * modelScale
		local maxCameraY = settings.panMaxRight * scale
		cameraY = min(cameraY, maxCameraY)
		local minCameraY = settings.panMaxLeft * scale
		cameraY = max(cameraY, minCameraY)
		local maxCameraZ = settings.panMaxTop * scale
		cameraZ = min(cameraZ, maxCameraZ)
		local minCameraZ = settings.panMaxBottom * scale
		cameraZ = max(cameraZ, minCameraZ)

		self:SetPosition(self.cameraX, cameraY + positionY, cameraZ + positionZ)
	end

	-- Rotate buttons
	local leftButton, rightButton
	if ( self.controlFrame ) then
		leftButton = self.controlFrame.rotateLeftButton
		rightButton = self.controlFrame.rotateRightButton
	else
		leftButton = self.RotateLeftButton or (self:GetName() and _G[self:GetName().."RotateLeftButton"])
		rightButton = self.RotateRightButton or (self:GetName() and _G[self:GetName().."RotateRightButton"])
	end

	if ( leftButton and leftButton:GetButtonState() == "PUSHED" ) then
		self.rotation = self.rotation + (elapsedTime * 2 * PI * rotationsPerSecond)
		if ( self.rotation < 0 ) then
			self.rotation = self.rotation + (2 * PI)
		end
		self:SetRotation(self.rotation)
	elseif ( rightButton and rightButton:GetButtonState() == "PUSHED" ) then
		self.rotation = self.rotation - (elapsedTime * 2 * PI * rotationsPerSecond)
		if ( self.rotation > (2 * PI) ) then
			self.rotation = self.rotation - (2 * PI)
		end
		self:SetRotation(self.rotation)
	end
end

function SharedXML_Model_SetDefaultRotation(self, rotation)
	self.defaultRotation = rotation
	self.rotation = rotation
	self:SetRotation(rotation)
end

function SharedXML_Model_Reset(self)
	self.rotation = self.defaultRotation
	self:SetRotation(self.rotation)
	self:SetPosition(self.positionX or 0, self.positionY or 0, self.positionZ or 0)
	self.zoomLevel = self.minZoom
end

function SharedXML_Model_StartPanning(self, usePanningFrame)
	if ( usePanningFrame ) then
		ModelPanningFrame.model = self
		ModelPanningFrame:Show()
	end
	self.panning = true
	local cameraX, cameraY, cameraZ = self:GetPosition()
	self.cameraX = cameraX
	self.cameraY = cameraY
	self.cameraZ = cameraZ
	local cursorX, cursorY = GetCursorPosition()
	self.cursorX = cursorX
	self.cursorY = cursorY
end

function SharedXML_Model_StopPanning(self)
	self.panning = false
	ModelPanningFrame:Hide()
end

function ModelControlButton_OnMouseDown(self)
	self.bg:SetTexCoord(0.01562500, 0.26562500, 0.14843750, 0.27343750)
	self.icon:SetPoint("CENTER", 1, -1)
	self:GetParent().buttonDown = self
end

function ModelControlButton_OnMouseUp(self)
	self.bg:SetTexCoord(0.29687500, 0.54687500, 0.14843750, 0.27343750)
	self.icon:SetPoint("CENTER", 0, 0)
	self:GetParent().buttonDown = nil
end

function GetUICameraInfo(uiCameraID)
	local uiCamera = UI_CAMERA_ID[uiCameraID];
	if uiCamera then
		return uiCamera[1], uiCamera[2], uiCamera[3], uiCamera[4], uiCamera[5];
	else
		return 0, 0, 0, 0, 0;
	end
end

local cameraWidth = 1366;
local cameraHeight = 768;
local cameraSquare = math.sqrt(cameraWidth * cameraWidth + cameraHeight * cameraHeight);

function Model_ApplyUICamera(self, uiCameraID)
	local posX, posY, posZ, yaw, animId = GetUICameraInfo(uiCameraID);
	if posX and posY and posZ and yaw then
		local scale = self:GetEffectiveScale();
		local width = GetScreenWidth() * scale;
		local height = GetScreenHeight() * scale;

		local square = math.sqrt(width * width + height * height);
		local diff = (cameraSquare / square) * self:GetModelScale();

		self:SetPosition(posX * diff, posY * diff, posZ * diff);
		self:SetFacing(yaw);

		if animId then
			self:SetSequence(animId);
		else
			self:SetSequence(3);
		end

		self.animId = animId;
	end
end