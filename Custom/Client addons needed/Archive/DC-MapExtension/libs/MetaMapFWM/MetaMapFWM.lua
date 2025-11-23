--[[--------------------------------------------------------------------------------------------
  
Uses a hardcoded list of overlay data which duplicates data available in the client.  Since it
also queries the client to find out which overlays should be 100%, it will detect discrepancies
in the client data and record any mismatched or not-present data in a saved Errata table.

--]]--------------------------------------------------------------------------------------------
local FWM_OverlayInfo = {
	["Teldrassil"] = { "RUTTHERANVILLAGE:128:100:494:548", "STARBREEZEVILLAGE:200:200:561:292",
	  "GNARLPINEHOLD:185:128:368:443", "LAKEALAMETH:256:185:436:380", "WELLSPRINGLAKE:180:256:377:93",
	  "THEORACLEGLADE:170:240:272:127", "BANETHILHOLLOW:160:210:382:281", "DOLANAAR:190:128:462:323",
	  "SHADOWGLEN:225:225:491:153", "POOLSOFARLITHRIEN:128:190:335:313", "DARNASSUS:315:256:101:247",
	},
	["Sunwell"] = {
		"SunsReachHarbor:512:416:252:252",
		"SunsReachSanctum:512:512:251:4",
	},
	["DunMorogh"] = { "AMBERSTILLRANCH:128:128:573:280", "FROSTMANEHOLD:125:125:217:287",
	  "ICEFLOWLAKE:128:180:281:167", "THEGRIZZLEDDEN:200:185:314:311", "HELMSBEDLAKE:155:170:694:273",
	  "SHIMMERRIDGE:128:190:347:163", "CHILLBREEZEVALLEY:180:128:274:296", "ANVILMAR:240:185:155:403",
	  "MISTYPINEREFUGE:128:165:502:221", "GOLBOLARQUARRY:165:165:608:291", "KHARANOS:200:200:386:294",
	  "THETUNDRIDHILLS:155:128:522:322", "IRONFORGE:315:200:397:163", "COLDRIDGEPASS:150:128:295:385",
	  "NORTHERNGATEOUTPOST:128:165:759:173", "SOUTHERNGATEOUTPOST:128:120:792:279",
	  "GNOMERAGON:180:165:166:184", "BREWNALLVILLAGE:115:115:252:249",
	},
	["Elwynn"] = { "EASTVALELOGGINGCAMP:256:210:704:330", "BRACKWELLPUMPKINPATCH:256:249:577:419",
	  "FORESTSEDGE:256:341:124:327", "FARGODEEPMINE:256:240:238:428", "JERODSLANDING:256:237:425:431",
	  "STORMWIND:485:405:0:0", "GOLDSHIRE:240:220:250:270", "TOWEROFAZORA:255:250:551:292",
	  "CRYSTALLAKE:225:220:422:332", "RIDGEPOINTTOWER:306:233:696:435",
	  "STONECAIRNLAKE:310:256:587:190", "NORTHSHIREVALLEY:256:256:381:147",
	},
	["Mulgore"] = { "WINTERHOOFWATERWELL:170:128:458:369", "THUNDERHORNWATERWELL:128:155:379:242",
	  "RAVAGEDCARAVAN:128:120:473:260", "PALEMANEROCK:128:205:303:307", "WINDFURYRIDGE:205:128:395:0",
	  "REDCLOUDMESA:470:243:270:425", "THUNDERBLUFF:280:240:249:59", "BAELDUNDIGSITE:210:180:255:214",
	  "WILDMANEWATERWELL:185:128:291:0", "THEGOLDENPLAINS:215:240:428:80", "REDROCKS:205:230:502:16",
	  "BLOODHOOFVILLAGE:256:200:367:303", "THEROLLINGPLAINS:256:190:523:356",
	  "THEVENTURECOMINE:225:235:532:238",
	},
	["Tirisfal"] = { "SCARLETWATCHPOST:175:247:689:104", "SOLLIDENFARMSTEAD:256:156:239:250",
	  "GARRENSHAUNT:174:220:497:145", "VENOMWEBVALE:237:214:757:205", "NIGHTMAREVALE:243:199:363:349",
	  "AGAMANDMILLS:256:210:335:139", "CRUSADEROUTPOST:173:128:694:289", "DEATHKNELL:245:205:227:328",
	  "BALNIRFARMSTEAD:216:179:630:326", "BRIGHTWATERLAKE:201:288:587:139", "BULWARK:230:205:698:362",
	  "RUINSOFLORDAERON:315:235:463:361", "COLDHEARTHMANOR:150:128:474:327",
	  "MONASTARY:211:189:746:125", "STILLWATERPOND:186:128:395:277", "BRILL:128:256:537:299",
	},
	["Durotar"] = { "RAZORMANEGROUNDS:230:230:301:189", "VALLEYOFTRIALS:215:215:355:320",
	  "SKULLROCK:128:110:464:33", "DRYGULCHRAVINE:210:160:427:78", "THUNDERRIDGE:190:200:327:60",
	  "ORGRIMMAR:445:160:244:0", "SENJINVILLAGE:160:190:474:384", "TIRAGARDEKEEP:190:180:462:286",
	  "ECHOISLES:200:240:549:427", "RAZORHILL:220:230:432:170", "KOLKARCRAG:160:120:413:476",
	},
	["Westfall"] = { "WESTFALLLIGHTHOUSE:280:190:205:467", "FURLBROWSPUMPKINFARM:210:215:387:11",
	  "JANGOLODEMINE:215:215:307:29", "SALDEANSFARM:225:210:459:105", "THEDUSTPLAINS:288:235:523:377",
	  "SENTINELHILL:195:240:442:241", "DEMONTSPLACE:200:185:208:375", "THEMOLSENFARM:225:205:328:148",
	  "THEDEADACRE:200:240:524:252", "THEJANSENSTEAD:165:200:488:0", "THEDAGGERHILLS:256:175:339:418",
	  "GOLDCOASTQUARRY:225:256:220:102", "ALEXSTONFARMSTEAD:305:210:204:260",
	  "MOONBROOK:220:200:317:331",
	},
	["Silverpine"] = { "THEDECREPITFERRY:180:185:457:144", "FENRISISLE:250:215:593:74",
	  "THEDEADFIELD:175:165:402:65", "MALDENSORCHARD:256:160:465:0", "OLSENSFARTHING:165:185:382:252",
	  "DEEPELEMMINE:160:170:470:261", "SHADOWFANGKEEP:220:160:364:359", "BERENSPERIL:240:180:491:417",
	  "THESEPULCHER:210:160:352:168", "PYREWOODVILLAGE:140:125:391:446", "AMBERMILL:240:240:494:262",
	  "THESKITTERINGDARK:185:165:286:37", "NORTHTIDESHOLLOW:180:128:323:128",
	  "THEGREYMANEWALL:210:215:379:447", "THESHININGSTRAND:256:220:459:13",
	},
	["LochModan"] = { "SILVERSTREAMMINE:235:270:229:11", "MOGROSHSTRONGHOLD:315:235:542:48",
	  "STONESPLINTERVALLEY:255:285:215:348", "IRONBANDSEXCAVATIONSITE:345:256:482:321",
	  "VALLEYOFKINGS:195:250:109:370", "GRIZZLEPAWRIDGE:295:358:309:310", "THELSAMAR:256:230:217:203",
	  "THELOCH:320:410:352:87", "NORTHGATEPASS:230:300:125:12", "STONEWROUGHTDAM:290:175:339:11",
	  "THEFARSTRIDERLODGE:370:295:546:199",
	},
	["Darkshore"] = { "RUINSOFMATHYSTRA:195:215:510:0", "TOWEROFALTHALAXX:170:195:468:85",
	  "GROVEOFTHEANCIENTS:200:170:305:412", "BASHALARAN:180:195:365:181", "AMETHARAN:190:205:324:306",
	  "THEMASTERSGLAIVE:175:158:329:510", "REMTRAVELSEXCAVATION:175:183:229:485",
	  "AUBERDINE:150:215:318:162", "CLIFFSPRINGRIVER:230:190:375:94",
	},
	["Redridge"] = { "STONEWATCH:255:300:500:215", "GALARDELLVALLEY:250:250:654:161",
	  "ALTHERSMILL:235:270:399:129", "RENDERSVALLEY:465:255:484:361", "LAKEEVERSTILL:535:275:133:240",
	  "REDRIDGECANYONS:365:245:121:72", "STONEWATCHFALLS:320:210:595:320", "LAKESHIRE:340:195:83:197",
	  "RENDERSCAMP:275:256:277:0", "THREECORNERS:365:350:0:284", "LAKERIDGEHIGHWAY:430:290:187:333",
	},
	["Wetlands"] = { "ANGERFANGENCAMPMENT:225:185:347:218", "DUNMODR:205:180:401:21",
	  "SUNDOWNMARSH:300:240:92:82", "THELGANROCK:230:190:470:371", "BLACKCHANNELMARSH:240:175:77:245",
	  "BLUEGILLMARSH:225:190:89:142", "MOSSHIDEFEN:205:245:527:264", "IRONBEARDSTOMB:200:185:349:115",
	  "THEGREENBELT:185:240:456:125", "SALTSPRAYGLEN:200:240:237:41", "MENETHILHARBOR:175:128:13:314",
	  "GRIMBATOL:350:360:611:230", "RAPTORRIDGE:190:160:628:176", "DIREFORGEHILL:256:250:507:115",
	  "WHELGARSEXCAVATIONSITE:195:185:247:205",
	},
	["Hilsbrad"] = { "DARROWHILL:205:155:414:154", "NETHANDERSTEAD:215:240:541:236",
	  "DURNHOLDEKEEP:384:365:605:75", "SOUTHSHORE:235:270:418:201", "HILLSBRADFIELDS:305:275:198:155",
	  "TARRENMILL:220:310:509:0", "AZURELOADMINE:165:200:175:275", "SOUTHPOINTTOWER:288:225:2:192",
	  "DUNGAROK:240:275:637:294", "EASTERNSTRAND:230:320:524:339", "WESTERNSTRAND:285:155:208:368",
	  "PURGATIONISLE:125:100:109:482",
	},
	["Duskwood"] = { "THEYORGENFARMSTEAD:235:250:390:382", "THEROTTINGORCHARD:250:230:539:369",
	  "VULGOLOGREMOUND:255:285:243:348", "TWILIGHTGROVE:360:420:298:79", "ADDLESSTEAD:275:250:55:342",
	  "MANORMISTMANTLE:200:175:653:120", "THEDARKENEDBANK:910:210:89:31", "RAVENHILL:195:145:102:302",
	  "THEHUSHEDBANK:160:330:19:132", "DARKSHIRE:315:280:631:162", "BRIGHTWOODGROVE:220:340:504:117",
	  "TRANQUILGARDENSCEMETARY:220:220:690:353", "RAVENHILLCEMETARY:350:300:85:149",
	},
	["Alterac"] = { "LORDAMEREINTERNMENTCAMP:330:265:44:403", "DANDREDSFOLD:285:230:276:0",
	  "MISTYSHORE:220:280:196:131", "CHILLWINDPOINT:350:370:626:253", "GALLOWSCORNER:200:200:406:279",
	  "CORRAHNSDAGGER:195:288:399:380", "CRUSHRIDGEHOLD:280:240:334:162", "THEUPLANDS:235:200:462:77",
	  "GAVINSNAZE:160:175:225:478", "GROWLESSCAVE:190:170:317:372", "RUINSOFALTERAC:255:255:270:197",
	  "STRAHNBRAD:370:300:549:105", "THEHEADLAND:165:197:314:471", "SOFERASNAZE:255:320:462:307",
	  "DALARAN:300:300:26:262",
	},
	["Barrens"] = { "THEFORGOTTENPOOLS:120:125:384:115", "THESTAGNANTOASIS:155:128:481:211",
	  "THEMORSHANRAMPART:128:100:412:0", "DREADMISTPEAK:128:105:419:63", "THEDRYHILLS:200:145:317:29",
	  "BOULDERLODEMINE:120:110:555:0", "THESLUDGEFEN:170:120:456:0", "THECROSSROADS:155:155:431:118",
	  "NORTHWATCHFOLD:150:120:527:307", "RAPTORGROUNDS:115:110:507:294", "THORNHILL:140:128:498:119",
	  "THEMERCHANTCOAST:95:100:581:247", "LUSHWATEROASIS:175:185:365:177", "RATCHET:125:125:556:189",
	  "HONORSSTAND:128:128:306:130", "BRAMBLESCAR:125:165:442:298", "BLACKTHORNRIDGE:155:128:335:462",
	  "BAELMODAN:128:128:431:479", "RAZORFENKRAUL:128:128:341:537", "RAZORFENDOWNS:155:115:407:553",
	  "CAMPTAURAJO:145:125:365:350", "GROLDOMFARM:125:115:492:63", "FARWATCHPOST:100:165:564:52",
	  "AGAMAGOR:200:185:340:234", "FIELDOFGIANTS:210:150:355:402",
	},
	["Stranglethorn"] = { "NESINGWARYSEXPEDITION:140:110:269:26", "RUINSOFJUBUWAL:110:110:306:301",
	  "ZIATAJAIRUINS:128:125:364:231", "BOOTYBAY:145:128:203:433", "NEKMANIWELLSPRING:90:115:211:359",
	  "RUINSOFABORAZ:95:95:350:335", "CRYSTALVEINMINE:120:120:345:276", "MIZJAHRUINS:105:110:311:131",
	  "WILDSHORE:165:190:229:422", "BLOODSAILCOMPOUND:165:175:194:284", "JAGUEROISLE:125:120:314:493",
	  "GROMGOLBASECAMP:110:105:260:132", "MOSHOGGOGREMOUND:128:175:432:94", "KALAIRUINS:95:95:299:88",
	  "RUINSOFZULMAMWE:170:125:394:212", "MISTVALEVALLEY:125:125:280:368", "THEARENA:200:185:235:189",
	  "ZUULDAIARUINS:115:115:156:42", "BALIAMAHRUINS:110:140:371:129", "LAKENAZFERITI:128:125:331:59",
	  "KURZENSCOMPOUND:155:150:388:0", "RUINSOFZULKUNDA:125:140:196:3", "ZULGURUB:245:220:483:8",
	  "THEVILEREEF:190:175:152:90", "VENTURECOBASECAMP:105:125:387:64",
	  "BALALRUINS:90:80:241:92", "REBELCAMP:170:90:284:0",
	},
	["SwampOfSorrows"] = { "SPLINTERSPEARJUNCTION:275:240:129:236", "THEHARBORAGE:235:205:171:145",
	  "FALLOWSANCTUARY:365:305:492:0", "MISTYREEDSTRAND:256:668:746:0", "POOLOFTEARS:300:275:565:218",
	  "THESHIFTINGMIRE:315:235:286:110", "MISTYVALLEY:245:305:0:140", "ITHARIUSSCAVE:240:245:0:262",
	  "STONARD:360:315:279:237", "STAGALBOG:345:250:552:378", "SORROWMURK:215:365:724:120",
	},
	["Arathi"] = { "CIRCLEOFINNERBINDING:210:185:286:310", "CIRCLEOFOUTERBINDING:170:155:419:293",
	  "NORTHFOLDMANOR:230:240:192:90", "BOULDERGOR:245:245:232:145", "STROMGARDEKEEP:240:230:108:287",
	  "FALDIRSCOVE:256:215:171:424", "THANDOLSPAN:200:220:355:412", "BOULDERFISTHALL:215:235:432:362",
	  "GOSHEKFARM:230:195:531:276", "HAMMERFALL:205:250:655:120", "WITHERBARKVILLAGE:215:210:559:333",
	  "DABYRIESFARMSTEAD:180:210:472:165", "CIRCLEOFEASTBINDING:160:230:558:112",
	  "REFUGEPOINT:175:225:370:186", "THORADINSWALL:190:240:87:138",
	  "CIRCLEOFWESTBINDING:190:210:138:54",
	},
	["Badlands"] = { "CAMPKOSH:220:220:551:48", "LETHLORRAVINE:370:455:611:110", "AGMONDSEND:265:270:345:389",
	  "CAMPBOFF:255:280:501:341", "THEDUSTBOWL:270:275:159:199", "HAMMERTOESDIGSITE:200:195:445:120",
	  "VALLEYOFFANGS:230:230:349:256", "ANGORFORTRESS:195:200:325:148",
	  "DUSTWINDGULCH:245:205:498:209", "THEMAKERSTERRACE:245:205:389:7",
	  "CAMPCAGG:256:256:12:428", "KARGATH:256:256:0:148", "APOCRYPHANSREST:256:256:17:310", "MIRAGEFLATS:256:256:148:384",
	},
	["Hinterlands"] = { "JINTHAALOR:235:285:505:333", "THEOVERLOOKCLIFFS:170:310:693:303",
	  "AERIEPEAK:255:205:13:245", "PLAGUEMISTRAVINE:145:220:158:149", "THEALTAROFZUL:200:165:373:365",
	  "HIRIWATHA:225:200:171:306", "QUELDANILLODGE:185:195:237:185", "VALORWINDLAKE:170:170:319:302",
	  "SHADRAALOR:195:185:240:387", "AGOLWATHA:205:195:374:164", "THECREEPINGRUIN:180:170:408:260",
	  "SERADANE:275:275:509:19", "SKULKROCK:160:145:512:232", "SHAOLWATHA:280:205:571:239",
	},
	["UngoroCrater"] = { "GOLAKKAHOTSPRINGS:315:345:121:151", "THESLITHERINGSCAR:345:285:367:380",
	  "FIREPLUMERIDGE:295:270:367:178", "TERRORRUN:345:285:158:368", "THEMARSHLANDS:310:355:560:240",
	  "IRONSTONEPLATEAU:285:285:582:67", "LAKKARITARPITS:570:265:160:6",
	},
	["Tanaris"] = { "THISTLESHRUBVALLEY:185:250:203:286", "VALLEYOFTHEWATCHERS:150:160:291:434",
	  "LANDSENDBEACH:205:157:445:511", "ABYSSALSANDS:215:180:363:194", "ZALASHJISDEN:110:140:611:147",
	  "CAVERNSOFTIME:155:150:561:256", "EASTMOONRUINS:160:150:395:346", "GADGETZAN:175:165:421:91",
	  "BROKENPILLAR:110:180:473:234", "SOUTHMOONRUINS:195:210:323:359", "ZULFARRAK:210:175:254:0",
	  "THEGAPINGCHASM:220:210:449:372", "SOUTHBREAKSHORE:215:175:499:293",
	  "DUNEMAULCOMPOUND:205:145:325:289", "THENOXIOUSLAIR:180:200:252:199",
	  "WATERSPRINGFIELD:165:180:509:168", "LOSTRIGGERCOVE:160:190:629:220",
	  "STEAMWHEEDLEPORT:155:150:592:75", "NOONSHADERUINS:120:135:533:104",
	  "SANDSORROWWATCH:195:175:299:100",
	},
	["Dustwallow"] = { "THEWYRMBOG:285:240:367:381", "ALCAZISLAND:200:195:660:21",
	  "THERAMOREISLE:230:205:534:224", "WITCHHILL:250:315:422:0", "BRACKENWALLVILLAGE:280:270:230:0",
	  "BACKBAYWETLANDS:400:255:239:189", "THEDENOFFLAME:255:250:257:313",
	},
	["ThousandNeedles"] = { "THEGREATLIFT:210:180:205:70", "DARKCLOUDPINNACLE:205:195:259:131",
	  "THESHIMMERINGFLATS:320:365:610:300", "SPLITHOOFCRAG:210:195:391:192", "CAMPETHOK:305:310:0:0",
	  "WINDBREAKCANYON:240:220:492:250", "FREEWINDPOST:210:190:357:264", "HIGHPERCH:190:190:31:155",
	  "THESCREECHINGCANYON:250:240:179:200",
	},
	["SearingGorge"] = { "GRIMSILTDIGSITE:305:220:494:300",
	  "THESEAOFCINDERS:360:280:247:388", "TANNERCAMP:305:230:545:407", "DUSTFIREVALLEY:460:365:422:8",
	  "FIREWATCHRIDGE:405:430:85:30", "THECAULDRON:425:325:250:170", "BLACKCHARCAVE:275:235:77:366",
	},
	["Ashenvale"] = { "THISTLEFURVILLAGE:255:195:203:158", "THESHRINEOFAESSINA:220:195:104:259",
	  "THEZORAMSTRAND:245:245:19:28", "LAKEFALATHIM:128:195:131:137", "MAESTRASPOST:215:305:205:38",
	  "ASTRANAAR:205:185:272:251", "IRISLAKE:200:205:392:218", "THERUINSOFSTARDUST:155:150:260:373",
	  "FIRESCARSHRINE:165:175:189:324", "MYSTRALLAKE:275:240:356:347", "BOUGHSHADOW:146:200:856:151",
	  "THEHOWLINGVALE:210:185:463:141", "FELFIREHILL:245:255:713:344", "NIGHTRUN:225:255:597:258",
	  "WARSONGLUMBERCAMP:200:160:796:311", "RAYNEWOODRETREAT:180:245:520:238",
	  "FALLENSKYLAKE:235:205:547:426", "SATYRNAAR:285:185:694:225",
	},
	["Desolace"] = { "SHADOWPREYVILLAGE:230:230:167:389", "THUNDERAXEFORTRESS:190:220:447:102",
	  "ETHELRETHOR:205:250:311:61", "GELKISVILLAGE:195:242:293:426", "VALLEYOFSPEARS:245:285:212:215",
	  "RANAZJARISLE:100:100:241:6", "MAGRAMVILLAGE:205:285:590:365", "MANNOROCCOVEN:285:280:399:380",
	  "SARGERON:285:245:625:33", "KOLKARVILLAGE:220:220:607:215", "KORMEKSHUT:170:160:555:181",
	  "SHADOWBREAKRAVINE:205:195:690:444", "KODOGRAVEYARD:275:250:387:244",
	  "NIJELSPOINT:200:250:554:0", "TETHRISARAN:205:145:431:0",
	},
	["BurningSteppes"] = { "DRACODAR:415:315:56:258", "RUINSOFTHAURISSAN:270:285:513:99",
	  "DREADMAULROCK:220:225:707:168", "MORGANSVIGIL:294:270:708:311", "ALTAROFSTORMS:225:220:36:109",
	  "TERRORWINGPATH:280:355:722:46", "BLACKROCKPASS:270:310:589:279", "PILLAROFASH:320:270:377:285",
	  "BLACKROCKSTRONGHOLD:245:265:334:114", "BLACKROCKMOUNTAIN:256:280:173:101",
	},
	["BlastedLands"] = { "DREADMAULPOST:245:195:361:195", "THETAINTEDSCAR:384:450:212:178",
	  "DREADMAULHOLD:195:180:361:15", "GARRISONARMORY:170:200:472:9", "ALTAROFSTORMS:185:155:310:133",
	  "SERPENTSCOIL:225:170:501:140", "DARKPORTAL:265:220:453:259", "NETHERGARDEKEEP:185:190:559:30",
	  "RISEOFTHEDEFILER:170:145:405:123",
	},
	["Aszhara"] = { "SHADOWSONGSHRINE:225:180:35:422", "TIMBERMAWHOLD:235:270:250:106",
	  "BAYOFSTORMS:270:300:479:201", "THESHATTEREDSTRAND:160:210:404:194", "JAGGEDREEF:570:170:366:0",
	  "BITTERREACHES:245:185:644:40", "TOWEROFELDARA:120:155:818:107", "FORLORNRIDGE:220:255:191:369",
	  "TEMPLEOFARKKORAN:190:200:681:153", "LEGASHENCAMPMENT:235:140:478:44", "URSOLAN:145:215:422:95",
	  "RUINSOFELDARATH:265:280:238:221", "SOUTHRIDGEBEACH:370:220:389:353", "VALORMOK:215:175:84:229",
	  "THALASSIANBASECAMP:240:155:499:119", "RAVENCRESTMONUMENT:240:125:552:499",
	  "HALDARRENCAMPMENT:200:150:77:331", "THERUINEDREACHES:395:128:396:540",
	  "LAKEMENNAR:315:200:296:429",
	},
	["Felwood"] = { "RUINSOFCONSTELLAS:235:155:297:381", "EMERALDSANCTUARY:185:160:405:429",
	  "FELPAWVILLAGE:240:145:483:0", "TALONBRANCHGLADE:160:145:548:90", "MORLOSARAN:145:159:496:509",
	  "JADEFIRERUN:195:170:330:29", "SHATTERSCARVALE:235:200:307:123", "JAEDENAR:245:128:271:331",
	  "BLOODVENOMFALLS:235:145:292:263", "DEADWOODVILLAGE:175:135:408:533",
	  "JADEFIREGLEN:165:155:332:465", "IRONTREEWOODS:215:215:420:54",
	},
	["EasternPlaguelands"] = { "EASTWALLTOWER:256:256:562:219", "NORTHDALE:256:256:590:106",
	  "ZULMASHAR:256:256:584:8", "QUELLITHIENLODGE:256:256:392:14", "NORTHPASSTOWER:256:256:427:87",
	  "PLAGUEWOOD:384:288:139:61", "STRATHOLME:256:243:164:0", "TERRORDALE:256:256:49:76",
	  "THONDRORILRIVER:256:384:0:209", "THEMARRISSTEAD:256:256:126:338", "THEUNDERCROFT:256:191:142:455",
	  "DARROWSHIRE:256:179:279:467", "CROWNGUARDTOWER:256:256:261:379", "THEFUNGALVALE:256:256:241:239",
	  "LAKEMERELDAR:256:205:474:412", "TheInfectisScar:256:256:379:323", "BLACKWOODLAKE:256:256:412:177",
	  "CORINSCROSSING:256:256:471:345", "PestilentScar:256:288:590:269", "TYRSHAND:256:197:687:449",
	  "THENOXIOUSGLADE:256:256:692:144", "ScarletEnclave:284:450:718:218", "LIGHTSHOPECHAPEL:256:256:656:277",
	},
	["StonetalonMountains"] = { "BOULDERSLIDERAVINE:145:107:572:561",
	  "WEBWINDERPATH:288:355:457:282", "MIRKFALLONLAKE:200:215:390:145", "CAMPAPARAJE:190:97:718:571",
	  "SISHIRCANYON:125:125:475:433", "STONETALONPEAK:270:205:247:0", "GRIMTOTEMPOST:225:120:668:515",
	  "MALAKAJIN:125:86:663:582", "WINDSHEARCRAG:320:275:553:197", "THECHARREDVALE:230:355:210:234",
	  "SUNROCKRETREAT:150:150:389:320",
	},
	["WesternPlaguelands"] = { "DARROWMERELAKE:370:270:504:343", "RUINSOFANDORHOL:285:230:260:355",
	  "THEBULWARK:225:185:137:293", "FELSTONEFIELD:160:125:300:311", "THEWEEPINGCAVE:160:200:566:198",
	  "CAERDARROW:170:165:600:412", "SORROWHILL:300:206:355:462", "GAHRRONSWITHERING:180:205:520:250",
	  "HEARTHGLEN:340:288:307:16", "DALSONSTEARS:220:150:381:265", "THEWRITHINGHAUNT:170:190:451:323",
	  "NORTHRIDGELUMBERCAMP:220:180:382:164", "THONDRORILRIVER:205:340:590:86",
	},
	["Feralas"] = { "THEFORGOTTENCOAST:145:320:404:256", "FRAYFEATHERHIGHLANDS:110:170:478:386",
	  "RUINSOFRAVENWIND:190:155:305:0", "THETWINCOLOSSALS:285:245:319:75", "DREAMBOUGH:150:125:454:0",
	  "GORDUNNIOUTPOST:140:165:690:141", "ISLEOFDREAD:215:293:192:375", "LOWERWILDS:225:180:751:198",
	  "FERALSCARVALE:115:115:486:329", "RUINSOFISILDIEN:190:250:540:320", "ONEIROS:110:110:493:70",
	  "DIREMAUL:230:195:454:201", "SARDORISLE:180:180:208:234", "CAMPMOJACHE:155:160:689:233",
	  "THEWRITHINGDEEP:240:220:618:298", "GRIMTOTEMCOMPOUND:120:195:623:167",
	},
	["Winterspring"] = { "WINTERFALLVILLAGE:145:125:617:158", "ICETHISTLEHILLS:125:165:611:242",
	  "LAKEKELTHERIL:215:185:401:198", "STARFALLVILLAGE:185:160:392:137", "EVERLOOK:165:200:509:107",
	  "FROSTFIREHOTSPRINGS:240:140:222:172", "FROSTWHISPERGORGE:200:160:523:376",
	  "THEHIDDENGROVE:175:185:555:27", "DARKWHISPERGORGE:255:205:447:441",
	  "FROSTSABERROCK:250:180:368:7", "OWLWINGTHICKET:165:140:593:340",
	  "TIMBERMAWPOST:230:120:229:243", "MAZTHORIL:185:180:493:258",
	},
	["Silithus"] = { "THESCARABWALL:288:256:116:413",
	  "THECRYSTALVALE:320:289:104:24", "HIVEASHI:512:320:265:12", "SOUTHWINDVILLAGE:384:384:500:65",
	  "TWILIGHTBASECAMP:320:256:344:197", "HIVEZORA:384:512:97:144", "HIVEREGAL:512:384:245:285",
	},
	["DeadwindPass"] = { "THEVICE:270:270:426:299", "KARAZHAN:300:245:269:337",
	  "DEADMANSCROSSING:380:365:249:76",
	},
	["AlteracValley"] = { "DUNBALDAR:270:240:348:13", "ICEBLOODGARRISON:300:300:335:172", "FROSTWOLFKEEP:235:290:399:375",
	},
	["Moonglade"] = { "LAKEELUNEARA:555:510:244:89", },
	["Hellfire"] = { "TheLegionFront:256:512:579:128", "RuinsofShanaar:256:378:25:290",
	  "HellfireCitadel:256:458:338:210", "FallenSkyRidge:256:256:34:142", "ExpeditionArmory:512:255:261:413",
	  "Thrallmar:256:256:467:154", "MagharPost:256:256:206:110", "DenofHaalesh:256:256:182:412", "TempleofTelhamat:512:512:38:152",
	  "PoolsofAggonar:256:512:326:45", "ForgeCampRage:512:512:478:25", "ThroneofKiljaeden:512:256:477:6",
	  "ZethGor:422:238:580:430", "TheStairofDestiny:256:512:737:156", "VoidRidge:256:256:705:368",
	  "WarpFields:256:260:308:408", "FalconWatch:512:342:183:326", "HonorHold:256:256:469:298",
	},
	["Zangarmarsh"] = { "TheLagoon:256:256:512:303", "FeralfenVillage:512:336:314:332", "OreborHarborage:256:512:329:25",
	  "TheDeadMire:286:512:716:128", "CoilfangReservoir:256:512:462:90", "Sporeggar:512:256:20:202",
	  "MarshlightLake:256:256:81:152", "QuaggRidge:256:343:141:325", "ZabraJin:256:256:175:232",
	  "TheHewnBog:256:512:219:51", "UmbrafenVillage:256:207:720:461", "Telredor:256:512:569:112",
	  "AngoroshStronghold:256:128:124:0", "CenarionRefuge:308:256:694:321", "BloodscaleEnclave:256:256:596:412",
	  "TwinspireRuins:256:256:342:249", "AngoroshGrounds:256:256:88:50", "TheSpawningGlen:256:256:31:339",
	},
	["Nagrand"] = { "WindyreedPass:256:256:598:79", "Telaar:256:256:387:390", "BurningBladeRUins:256:334:660:334",
	  "Halaa:256:256:335:193", "WarmaulHill:256:256:157:32", "SunspringPost:256:256:219:199",
	  "TwilightRidge:256:512:10:107", "SouthwindCleft:256:256:391:258", "KilsorrowFortress:256:241:558:427",
	  "LaughingSkullRuins:256:256:351:52", "OshuGun:512:334:168:334", "ThroneoftheElements:256:256:504:53",
	  "ClanWatch:256:256:532:363", "RingofTrials:256:256:533:267", "ForgeCampHate:256:256:162:154",
	  "ZangarRidge:256:256:277:54", "ForgeCampFear:512:420:36:248", "WindyreedVillage:256:256:666:233",
	  "Garadar:256:256:431:143",
	},
	["TerokkarForest"] = { "RaastokGlade:256:256:505:154", "ShattrathCity:512:512:104:4",
	  "BleedingHollowClanRuins:256:367:103:301", "CarrionHill:256:256:377:272", "SethekkTomb:256:256:245:289",
	  "RazorthornShelf:256:256:478:19", "GrangolvarVilliage:512:256:143:171", "Tuurem:256:512:455:34",
	  "TheBarrierHills:256:256:116:4", "StonebreakerHold:256:256:397:165", "CenarionThicket:256:256:314:0",
	  "FirewingPoint:385:512:617:149", "AllerianStronghold:256:256:480:277", "BonechewerRuins:256:256:521:275",
	  "SkethylMountains:512:320:449:348", "RingofObservance:256:256:310:345", "WrithingMound:256:256:417:327",
	  "VeilRhaze:256:256:222:362", "AuchenaiGrounds:256:234:247:434", "SmolderingCaravan:256:208:321:460",
	  "RefugeCaravan:128:256:316:268",
	  "TheBoneWastes:512:400:224:268",		-- Seems to have been replaced by separate regions...
	},
	["ShadowmoonValley"] = { "NetherwingLedge:492:223:510:445", "WildhammerStronghold:512:439:168:229",
	  "LegionHold:512:512:104:155", "TheWardensCage:512:410:469:258", "IlladarPoint:256:256:143:256",
	  "ShadowmoonVilliage:512:512:116:35", "TheHandofGuldan:512:512:394:90", "CoilskarPoint:512:512:348:8",
	  "NetherwingCliffs:256:256:554:308", "TheBlackTemple:396:512:606:126", "AltarofShatar:256:256:520:93",
	  "TheDeathForge:256:512:290:129", "EclipsePoint:512:358:343:310",
	},
	["BladesEdgeMountains"] = { "VeilRuuan:256:128:563:151", "VortexPinnacle:256:462:166:206",
	  "BladedGulch:256:256:623:147", "Grishnath:256:256:286:28",
	  "BrokenWilds:256:256:733:109", "ThunderlordStronghold:256:396:405:272", "RuuanWeald:256:512:479:98",
	  "BloodmaulOutpost:256:297:342:371", "VeilLashh:256:240:271:428", "RavensWood:512:256:214:55",
	  "MokNathalVillage:256:256:658:297", "Skald:256:256:673:71", "JaggedRidge:256:254:446:414",
	  "BladesipreHold:256:507:314:161", "DeathsDoor:256:419:512:249", "GruulsLayer:256:256:527:81",
	  "ForgeCampAnger:416:256:586:147", "BloodmaulCamp:256:256:412:95",
	  "ForgeCampTerror:512:252:144:416", "ForgeCampWrath:256:256:254:176", "VekhaarStand:256:256:629:406",
	  "Sylvanaar:256:318:289:350", "BashirLanding:256:256:422:0", "CircleofWrath:256:256:439:210",
	  "RazorRidge:256:336:533:332", "RidgeofMadness:256:410:554:258", "TheCrystalpine:256:256:585:0",
	},
	["Netherstorm"] = { "ManaforgeBanar:256:387:147:281", "RuinedManaforge:256:256:513:138",
	  "SunfuryHold:256:217:454:451", "ManafrogeAra:256:256:171:155", "SocretharsSeat:256:256:229:38",
	  "EtheriumStagingGrounds:256:256:481:208", "TempestKeep:409:384:593:284",
	  "ManaforgeDuro:256:256:465:336", "TheScrapField:256:256:356:261", "CelestialRidge:256:256:644:173",
	  "TheStormspire:256:256:298:134", "Area52:256:128:241:388", "ArklonRuins:256:256:328:397",
	  "RuinsofEnkaat:256:256:253:301", "ManaforgeCoruu:256:179:357:489", "Netherstone:256:256:411:20",
	  "KirinVarVillage:256:145:490:523", "ForgeBaseOG:256:256:237:22", "RuinsofFarahlon:512:256:354:49",
	  "EcoDomeFarfield:256:256:396:10", "TheHeap:256:213:239:455", "NetherstormBridge:256:256:132:294",
	},
	["Ghostlands"] = { "ThalassiaPass:256:262:364:406", "ZebNowa:512:431:466:237",
	 "AmaniPass:404:436:598:232", "SanctumoftheSun:256:512:448:150", "Deatholme:512:293:95:375",
	 "BleedingZiggurat:256:256:184:238", "WindrunnerVillage:256:512:60:117", "WindrunnerSpire:256:256:40:287",
	 "HowlingZiggurat:256:449:340:219", "SanctumoftheMoon:256:256:210:126", "GoldenmistVillage:512:512:44:0",
	 "Tranquillien:256:512:365:2", "ElrendarCrossing:512:256:326:0", "SuncrownVillage:512:256:460:0",
	 "DawnstarSpire:427:256:575:0", "FarstriderEnclave:429:256:573:136", "IsleofTribulations:256:256:585:0",
	 },
	["EversongWoods"] = { "SunstriderIsle:512:512:195:5", "TorWatha:256:353:648:315",
	 "RunestoneFalithas:256:172:378:496", "TheScortchedGrove:256:128:255:507",
	 "TheGoldenStrand:128:253:183:415", "SunsailAnchorage:256:128:231:404", "GoldenboughPass:256:128:243:469",
	 "SatherilsHaven:256:256:324:384", "FairbreezeVilliage:256:256:386:386", "TheLivingWood:128:248:511:420",
	 "RunestoneShandor:256:174:464:494", "Zebwatha:128:193:554:475", "LakeElrendar:128:197:584:471",
	 "ElrendarFalls:128:256:580:399", "EastSanctum:256:256:460:373", "FarstriderRetreat:256:128:524:359",
	 "SilvermoonCity:512:512:440:87", "StillwhisperPond:256:256:474:314", "ThuronsLivery:256:128:539:305",
	 "NorthSanctum:256:256:361:298", "WestSanctum:128:256:292:319", "TranquilShore:256:256:215:298",
	 "RuinsofSilvermoon:256:256:307:136", "DuskwitherGrounds:256:256:605:253",
	 "AzurebreezeCoast:256:256:669:228", -- added in WotLK update
	},
	["AzuremystIsle"] = { "AmmenVale:475:512:527:104", "AmmenFord:256:256:515:279",
	 "MoongrazeWoods:256:256:449:183", "Emberglade:256:256:488:24", "FairbridgeStrand:256:128:356:0",
	 "ValaarsBerth:256:256:176:303", "BristlelimbVillage:256:256:174:363", "WrathscalePoint:256:247:220:421",
	 "SilvermystIsle:256:222:23:446", "OdesyusLanding:256:256:352:378", "GreezlesCamp:256:256:507:350",
	 "PodWreckage:128:256:462:349", "AzureWatch:256:256:383:249", "PodCluster:256:256:281:305",
	 "TheExodar:512:512:74:85", "StillpineHold:256:256:365:49", "SiltingShore:256:256:291:3",
	},
	["BloodmystIsle"] = { "KesselsCrossing:485:141:517:527", "TheCrimsonReach:256:256:555:87",
	 "BristlelimbEnclave:256:256:546:410", "WrathscaleLair:256:256:598:338", "RuinsofLorethAran:256:256:556:216",
	 "WyrmscarIsland:256:256:613:82", "BloodscaleIsle:239:256:763:256", -- "BloodcurseIsle:239:256:763:256", replaced by BloodscaleIsle in the data
	 "VeridianPoint:256:256:637:0", "TalonStand:256:256:657:78", "RagefeatherRidge:256:256:481:117",
	 "Bladewood:256:256:367:209", "TheWarpPiston:256:256:451:29", "TheBloodwash:256:256:302:27",
	 "Axxarien:256:256:297:136", "TheFoulPool:256:256:221:136", "AmberwebPass:256:512:44:62",
	 "TheVectorCoil:512:430:43:238", "VindicatorsRest:256:256:232:242", "BlacksiltShore:512:242:177:426",
	 "Nazzivian:256:256:250:404", "Mystwood:256:185:309:483", "TheLostFold:256:198:503:470",
	 "BloodWatch:256:256:437:258", "TheCryoCore:256:256:293:285", "Middenvale:256:256:414:406",
	 "TelathionsCamp:128:128:180:216",
	 "TheBloodcursedReef:256:256:729:54", "TheHiddenReef:256:256:205:39", -- added in WotLK update
	},
	["IcecrownGlacier"] = { "Jotunheim:393:474:22:122", "TheFleshwerks:219:283:218:291", "Corprethar:308:212:342:392",
		"TheConflagration:227:210:327:305", "Aldurthar:373:375:355:37", "TheShadowVault:223:399:321:15",
		"Valhalas:238:240:217:50", "TheBombardment:248:243:538:181", "Ymirheim:223:207:444:276",
		"IcecrownCitadel:308:202:392:466", "TheBrokenFront:283:231:558:329", "SindragosasFall:291:331:635:43",
		"Scourgeholme:245:239:690:267", "ValleyofEchoes:269:217:715:390", "OnslaughtHarbor:204:268:0:167",
	},
	["ZulDrak"] = { "Zeramas:307:256:7:412", "LightsBreach:321:305:181:363", "AltarOfMamToth:291:258:575:88",
		"GunDrak:336:297:629:0", "AltarOfQuetzLun:261:288:607:251", "AltarOfHarKoa:265:257:533:345",
		"Kolramas:302:231:380:437", "DrakSotraFields:286:265:326:358", "AmphitheaterOfAnguish:266:254:289:287",
		"AltarOfRhunok:247:304:431:127", "AltarOfSseratus:237:248:288:168", "Voltarus:218:291:174:191",
		"ThrymsEnd:272:268:0:247", "ZimTorga:249:258:479:241",
	},
	["SholazarBasin"] = { "KartaksHold:329:293:76:375", "TheSuntouchedPillar:455:316:82:186", 
		"RiversHeart:468:329:359:339", "TheLifebloodPillar:312:369:501:134", "TheMakersOverlook:233:286:705:236",
		"TheMosslightPillar:239:313:265:355", "TheStormwrightsShelf:268:288:138:58", "TheMakersPerch:249:248:172:135",
		"RainspeakerCanopy:207:235:427:244", "TheGlimmeringPillar:294:327:308:34", "TheSavageThicket:293:229:396:51",
		"TheAvalanche:322:265:596:92", -- [12]
	},
	["CrystalsongForest"] = { "VioletStand:264:303:0:176", "TheDecrepitFlow:288:222:0:0",
		"TheUnboundThicket:502:477:500:105", "ForlornWoods:544:668:129:0", "TheGreatTree:252:260:0:91",
		"TheAzureFront:416:424:0:244", "WindrunnersOverlook:558:285:444:383", "SunreaversCommand:446:369:536:40",
	},
	["HowlingFjord"] = { "VengeanceLanding:223:338:664:25", "GiantsRun:298:306:572:0", "FortWildervar:251:192:490:0",
		"TheTwistedGlade:266:210:420:57", "Gjalerbron:242:189:225:0", "CampWinterHoof:223:209:354:0",
		"ApothecaryCamp:263:265:99:37", "WestguardKeep:347:220:90:180", "AncientLift:177:191:342:351",
		"Kamagua:333:265:99:278", "ScalawagPoint:350:258:168:410", "UtgardeKeep:248:382:477:216",
		"NewAgamand:284:308:415:360", "Halgrind:187:263:397:208", "EmberClutch:213:256:283:203",
		"SteelGate:222:168:222:100", "Skorn:238:232:343:108", "Baleheim:174:173:576:170",
		"Nifflevar:178:208:595:240", "BaelgunsExcavationSite:244:305:621:327", "ExplorersLeagueOutpost:232:216:585:336",
		"IvaldsRuin:193:201:668:223", "CauldrosIsle:181:178:490:161",
	},
	["GrizzlyHills"] = { "DunArgol:455:400:547:257", "RageFangShrine:475:362:312:294", "ConquestHold:332:294:17:307",
		"Voldrune:283:247:176:421", "VentureBay:274:207:18:461", "GraniteSprings:356:224:7:207",
		"DrakTheronKeep:382:285:0:46", "BlueSkyLoggingGrounds:249:235:232:129", "GrizzleMaw:294:227:358:187",
		"AmberpineLodge:278:290:217:244", "UrsocsDen:328:260:331:32", "ThorModan:329:246:509:0",
		"CampOneqwah:324:265:548:137", "DrakilJinRuins:351:284:607:41",
	},
	["BoreanTundra"] = { "WarsongStronghold:260:278:329:237", "TorpsFarm:186:276:272:237",
		"GarroshsLanding:267:378:153:238", "RiplashStrand:382:258:293:383", "ValianceKeep:259:302:457:264",
		"Kaskala:385:316:509:214", "DeathsStand:289:279:707:181", "TempleCityOfEnKilah:290:292:712:15",
		"TheGeyserFields:375:342:480:0", "TheDensOfDying:203:209:662:11", "BorGorokOutpost:396:203:314:0",
		"Coldarra:460:381:50:0", "AmberLedge:244:214:325:140", "SteeljawsCaravan:244:319:397:66",
	},
	["Dragonblight"] = { "VenomSpite:226:212:661:264", "LakeIndule:356:300:217:313", "WestwindRefugeeCamp:229:299:42:187",
		"NewHearthglen:214:261:614:358", "TheForgottenShore:301:286:698:332", "EmeraldDragonshrine:196:218:543:362",
		"WyrmrestTemple:317:353:453:219", "Naxxramas:311:272:691:160", "ScarletPoint:235:354:569:7",
		"LightsRest:299:278:703:7", "TheCrystalVice:229:259:487:0", "GalakrondsRest:258:225:433:118",
		"ColdwindHeights:213:219:403:0", "Angrathar:306:242:210:0", "ObsidianDragonshrine:304:203:256:104",
		"RubyDragonshrine:188:211:374:208", "AgmarsHammer:236:218:258:203", "IcemistVillage:235:337:134:165",
	},
	["TheStormPeaks"] = { "Valkyrion:228:158:98:318", "SparksocketMinefield:251:200:242:468",
		"Frosthold:244:220:134:429", "BorsBreath:322:195:109:375", "EngineoftheMakers:210:179:316:296",
		"TempleofStorms:169:164:239:301", "SnowdriftPlains:205:232:162:143", "Nidavelir:221:200:108:206",
		"NarvirsCradle:180:239:214:144", "Ulduar:369:265:218:0", "TerraceoftheMakers:363:341:292:122",
		"TempleofLife:182:270:570:113", "Thunderfall:306:484:627:179", "DunNiffelem:309:383:481:285",
		"GarmsBane:184:191:395:470", "BrunnhildarVillage:305:298:339:370",
	},

}

local old_GetNumMapOverlays = GetNumMapOverlays;
local old_NUM_WORLDMAP_OVERLAYS = NUM_WORLDMAP_OVERLAYS;
local old_WorldMapFrame_Update = WorldMapFrame_Update;
------------------------------------------------------------------------------------------------

function MetaFWM_OnEvent(event)
	if(event == "ADDON_LOADED" and arg1 == "MetaMapFWM") then
		if(FWM_Options == nil) then FWM_Options = {}; end
		if(FWM_Options.red == nil) then FWM_Options.red = 1; end
		if(FWM_Options.green == nil) then FWM_Options.green = 1; end
		if(FWM_Options.blue == nil) then FWM_Options.blue = 1; end
		if(FWM_Options.alpha == nil) then FWM_Options.alpha = 1; end
		if(FWM_Options.Errata == nil) then FWM_Options.Errata = {}; end
		if(FWM_Options.FWMcolor == nil) then FWM_Options.FWMcolor = false; end
		if(FWM_ShowUnexplored == nil) then FWM_ShowUnexplored = false; end
		MetaMapFWM_colorCheckButton:SetChecked(FWM_Options.FWMcolor);
		FWM_WorldMapFrame_Init();
	end
end

function GetNumMapOverlays()
    if (NUM_WORLDMAP_OVERLAYS == 0) then return 0 end;
    return old_GetNumMapOverlays()
end

function WorldMapFrame_Update()
	old_NUM_WORLDMAP_OVERLAYS = NUM_WORLDMAP_OVERLAYS;
	NUM_WORLDMAP_OVERLAYS = 0;
	old_WorldMapFrame_Update();
	if(old_NUM_WORLDMAP_OVERLAYS) then
		NUM_WORLDMAP_OVERLAYS = old_NUM_WORLDMAP_OVERLAYS;
	else NUM_WORLDMAP_OVERLAYS = 1;
	end
	worldMapFrame_UpdateOverlays();
end

function FWM_WorldMapFrame_Init()
	-- Integrate the contents of the errata table into the main dataset.
	-- and while we're at it, remove anything we don't recognize from the errata table!
	local mapFileName, errataTable, i, oinfo
	for mapFileName,errataTable in next,FWM_Options.Errata do
		-- hack to keep strings short and maintainable.
		local prefix = "Interface\\WorldMap\\"..mapFileName.."\\"
		-- build a temporary index of the mainTable, from textureName to index!
		local mainIndex = {}
		
		local mainTable = getMainTable(mapFileName)
		for i,oinfo in next,mainTable do
			local tname = oinfo_uncombine(prefix,oinfo)
			if tname then mainIndex[tname] = i; end
		end
		-- build a temporary index of the errata too (removing redundant entries).
		local errataIndex = {}
		for i,oinfo in next,errataTable do
			local tname = oinfo_uncombine(prefix,oinfo)
			if not tname then
				if (FWM_DEBUG) then MetaMap_Print(mapFileName..": borked: "..oinfo, true) end
				errataTable[i] = nil
			else
				if errataIndex[tname] then
					if (FWM_DEBUG) then 
						local old = errataTable[errataIndex[tname]]
						MetaMap_Print(mapFileName..": redundant: "..old, true)
					end
					errataTable[errataIndex[tname]] = nil
				end
				errataIndex[tname] = i;
			end
		end
			-- now integrate errata into mainTable (for this session only)
		for i,oinfo in next,errataTable do
			local tname = oinfo_uncombine(prefix,oinfo)
			if mainIndex[tname] then
				if mainTable[mainIndex[tname]] ~= oinfo then
					if (FWM_DEBUG) then MetaMap_Print(mapFileName..": update "..oinfo, true) end
					mainTable[mainIndex[tname]] = oinfo
				else
					if (FWM_DEBUG) then MetaMap_Print(mapFileName..": redundant: "..oinfo, true) end
					errataTable[i] = nil
				end
			else
				if (FWM_DEBUG) then MetaMap_Print(mapFileName..": add "..oinfo, true) end
				table.insert(mainTable, oinfo)
			end
		end
	end
end

function MetaMapFWM_Initcolor()
	ColorPickerFrame.func = MetaMapFWM_Setcolor;
	ColorPickerFrame.cancelFunc = MetaMapFWM_Cancelcolor;
	ColorPickerFrame.previousValues = {FWM_Options.red, FWM_Options.green, FWM_Options.blue};
	ColorPickerFrame:SetFrameStrata("FULLSCREEN");
	ColorPickerFrame:Show();
	ColorPickerFrame:SetColorRGB(FWM_Options.red, FWM_Options.green, FWM_Options.blue);
end

function MetaMapFWM_Setcolor()
	FWM_Options.red, FWM_Options.green, FWM_Options.blue = ColorPickerFrame:GetColorRGB();
	WorldMapFrame_Update();
end

function MetaMapFWM_Cancelcolor(prevColors)
	FWM_Options.red, FWM_Options.green, FWM_Options.blue = unpack(prevColors);
	WorldMapFrame_Update();
end

function oinfo_combine(prefix,tname,tw,th,ofx,ofy,mpx,mpy)
    -- shorten strings by replacing redundant prefix paths with a marker token
    local result = ":"..tw..":"..th..":"..ofx..":"..ofy
    if (mpx~=0 or mpy~=0) then result = result..":"..mpx..":"..mpy end
    if string.sub(tname, 0, string.len(prefix)) == prefix then
        return string.sub(tname, string.len(prefix)+1)..result
    end
    return "|"..result
end

function oinfo_uncombine(prefix,oinfo)
    local pfxUnused,tname,tw,th,ofx,ofy,mpx,mpy;
    _,_,pfxUnused,tname,tw,th,ofx,ofy = string.find(oinfo,
        "^([|]?)([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)")
    if (not tname or not ofy) then return nil; end -- safety check
    if (ofy) then
        _,_,mpx,mpy = string.find(oinfo,
            "^[|]?[^:]+:[^:]+:[^:]+:[^:]+:[^:]+:([^:]+):([^:]+)")
    end
    if (not mpy) then mpx=0; mpy=0 end
    if (pfxUnused~="|") then tname = prefix..tname; end
    return tname,tw+0,th+0,ofx+0,ofy+0,mpx+0,mpy+0
end

function oinfo_getname(prefix,oinfo)
    local junk1,junk2,pfxUnused,tname = string.find(oinfo, "^([|]?)([^:]+):")
    if (not tname) then return nil; end -- safety check
    if (pfxUnused~="|") then tname = prefix..tname; end
    return tname
end

function getMainTable(mapFileName)
    local t = FWM_OverlayInfo[mapFileName]
    if not t then t = { }; FWM_OverlayInfo[mapFileName] = t end
    return t
end

function getErrataTable(mapFileName)
    local t = FWM_Options.Errata[mapFileName]
    if not t then t = { }; FWM_Options.Errata[mapFileName] = t end
    return t
end

-- This code replaces the short-circuited code from WorldMapFrame_Update.
function worldMapFrame_UpdateOverlays(dtlFrame, ovrLay)
	local mapOverLay;
	if((dtlFrame) and (ovrLay)) then
		mapOverLay = ovrLay;
	else
		dtlFrame = "WorldMapDetailFrame";
		mapOverLay = "WorldMapOverlay";
	end
	local mapFileName, textureHeight = GetMapInfo();
	if (not mapFileName) then mapFileName = "World"; end

    -- hack to keep strings short and maintainable.
    local prefix = "Interface\\WorldMap\\"..mapFileName.."\\"

    -- (1) create oinfos for discovered areas in this zone.
	local i, tname, oinfo
	local discovered = {}
	local numOverlays = GetNumMapOverlays()
	for i=1, numOverlays do
		local tname,tw,th,ofx,ofy,mpx,mpy = GetMapOverlayInfo(i)
		discovered[tname] = oinfo_combine(prefix,tname,tw,th,ofx,ofy,mpx,mpy)
	end

    -- (2) update any overlays for which our stored data is *incorrect* (should never happen!)
    local zoneTable = getMainTable(mapFileName)
    
    numOverlays = #(zoneTable)
    for i,oinfo in next,zoneTable do
        local tname = oinfo_getname(prefix,oinfo)
					if discovered[tname] then
            if discovered[tname] == 1 then
                if (FWM_DEBUG) then MetaMap_Print(mapFileName..": repeating "..tname.." ??", true) end
            elseif discovered[tname] ~= oinfo then
                if (FWM_DEBUG) then MetaMap_Print(mapFileName..": update "..discovered[tname], true) end
                zoneTable[i] = discovered[tname]
                -- record in the errata table for next time!
                table.insert(getErrataTable(mapFileName),discovered[tname])
            end
            discovered[tname] = 1
        end
    end
    -- (3) add any overlays which are *missing* from our stored data (should never happen!)
    for tname,oinfo in next,discovered do
        if oinfo ~= 1 then
            if (FWM_DEBUG) then MetaMap_Print(mapFileName..": adding "..oinfo, true) end
            table.insert(zoneTable,oinfo)
            -- record in the errata table for next time!
            table.insert(getErrataTable(mapFileName),oinfo)
        end
    end
    
	-- Modified version of original overlay stuff
	local textureName, textureWidth, textureHeight, offsetX, offsetY, mapPointX, mapPointY;
	local textureCount = 1;
	local texture;
	local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight;
	local numTexturesWide, numTexturesTall;

	for i=1, 100 do
		if(getglobal(mapOverLay..i) == nil) then
			break;
		end
		getglobal(mapOverLay..i):Hide();
	end
	for i,oinfo in next,zoneTable do
		textureName, textureWidth, textureHeight, offsetX, offsetY, mapPointX, mapPointY =
		oinfo_uncombine(prefix,oinfo)
		if FWM_ShowUnexplored or discovered[textureName] then
			numTexturesWide = ceil(textureWidth/256);
			numTexturesTall = ceil(textureHeight/256);
			neededTextures = textureCount + (numTexturesWide * numTexturesTall);
			if ( neededTextures > NUM_WORLDMAP_OVERLAYS ) then
				for j=NUM_WORLDMAP_OVERLAYS+1, neededTextures do
					WorldMapDetailFrame:CreateTexture("WorldMapOverlay"..j, "ARTWORK");
				end
				NUM_WORLDMAP_OVERLAYS = neededTextures;
			end
    		for j=1, numTexturesTall do
    			if (j < numTexturesTall) then
    				texturePixelHeight = 256; textureFileHeight = 256;
    			else
    				texturePixelHeight = mod(textureHeight, 256);
    				if (texturePixelHeight == 0) then texturePixelHeight = 256; end
    				textureFileHeight = 16;
    				while(textureFileHeight < texturePixelHeight) do
    					textureFileHeight = textureFileHeight * 2;
    				end
    			end
    			for k=1, numTexturesWide do
    				if (textureCount > NUM_WORLDMAP_OVERLAYS) then
    				    message("Too many worldmap overlays!");	return;
    				end
    				texture = getglobal(mapOverLay..textureCount);
    				if (k < numTexturesWide) then
    				    texturePixelWidth = 256; textureFileWidth = 256;
    				else
    					texturePixelWidth = mod(textureWidth, 256);
    					if (texturePixelWidth == 0) then texturePixelWidth = 256; end
    					textureFileWidth = 16;
    					while(textureFileWidth < texturePixelWidth) do
    						textureFileWidth = textureFileWidth * 2;
    					end
    				end
    				texture:SetWidth(texturePixelWidth);
    				texture:SetHeight(texturePixelHeight);
    				texture:SetTexCoord(0, texturePixelWidth/textureFileWidth, 0,
    				    texturePixelHeight/textureFileHeight);
    				texture:ClearAllPoints();
    				texture:SetPoint("TOPLEFT", dtlFrame, "TOPLEFT",
							offsetX + (256 * (k-1)), -(offsetY + (256 * (j - 1))));

    				texture:SetTexture(textureName..(((j - 1) * numTexturesWide) + k));
    				
    				if discovered[textureName] then
       				texture:SetVertexColor(1.0,1.0,1.0)
   				    texture:SetAlpha(1.0)
						else
							if(FWM_Options.FWMcolor) then
								texture:SetVertexColor(FWM_Options.red,FWM_Options.green,FWM_Options.blue,FWM_Options.alpha);
							else
								texture:SetVertexColor(1.0,1.0,1.0)
							end                            
    				end
    				texture:Show();
    				textureCount = textureCount + 1;
    			end
    		end
     end
	end
	for i=textureCount+1, NUM_WORLDMAP_OVERLAYS do
		if(getglobal(mapOverLay..i)) then
			getglobal(mapOverLay..i):Hide();
		end
	end
end
