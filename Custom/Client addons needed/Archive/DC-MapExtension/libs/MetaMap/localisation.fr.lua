--[[

-- MetaMap Localization Data (French)
-- Translation by Sparrows (Comics UI)
-- Last Update: 05/16/2006

 à: C3 A0 - \195\160
 â: C3 A2 - \195\162
 ç: C3 A7 - \185\167
 è: C3 A8 - \195\168
 é: C3 A9 - \195\169
 ê: C3 AA - \195\170
 ë: C3 AB - \195\171
 î: C3 AE - \195\174
 ô: C3 B4 - \195\180
 û: C3 BB - \195\187
 œ: C5 93 - \197\147

--]]


if (GetLocale() == "frFR") then

-- General
METAMAP_CATEGORY = "Interface";
METAMAP_SUBTITLE = "WorldMap Mod";
METAMAP_DESC = "MetaMap est une modification de la carte standard du monde.";
METAMAP_STRING_LOCATION = "Lieux";
METAMAP_STRING_LEVELRANGE = "Plage de niveaux";
METAMAP_STRING_PLAYERLIMIT = "Limit\195\169 \195\160";
METAMAP_MAPLIST_INFO = "Clic gauche: Ping Note\nClic droit: Editer Note\nCtrl+Clic: Table des Loots";
METAMAP_HINT = "Conseil : Clic gauche pour ouvrir MetaMap.\nClic droit pour les options";
METAMAP_NOTES_SHOWN = "Notes"
METAMAP_LINES_SHOWN = "Lignes"
METAMAP_SEARCHTEXT = "Recherche";
METAMAPLIST_SORTED = "Voir liste tri\195\169e";
METAMAPLIST_UNSORTED = "Voir liste non tri\195\169e";
METAMAP_CLOSE_BUTTON ="Fermer";

BINDING_HEADER_METAMAP_TITLE = "MetaMap";
BINDING_NAME_METAMAP_MAPTOGGLE = "Carte du Monde On/Off";
BINDING_NAME_METAMAP_MAPTOGGLE1 = "Carte du Monde Mode 1";
BINDING_NAME_METAMAP_MAPTOGGLE2 = "Carte du Monde Mode 2";
BINDING_NAME_METAMAP_FSTOGGLE = "Plein \195\169cran On/Off";
BINDING_NAME_METAMAP_SAVESET = "Choisir le mode d\'affichage de la carte";
BINDING_NAME_METAMAP_KB = "Afficher la base de donn\195\169es"
BINDING_NAME_METAMAP_KB_TARGET_UNIT = "Enregistrer les infos de la cible";
BINDING_NAME_METAMAP_BWPCLEAR = "Clear Waypoint";
BINDING_NAME_METAMAP_QST = "Log de quête On/Off"
BINDING_NAME_METAMAP_TRK = "Toggle Tracker Display"
BINDING_NAME_METAMAP_QUICKNOTE = "Cr\195\169er une Note Rapide";

-- Commands
METAMAP_ENABLE_COMMANDS = { "/mapnote" }
METAMAP_ONENOTE_COMMANDS = { "/onenote", "/allowonenote", "/aon" }
METAMAP_MININOTE_COMMANDS = { "/nextmininote", "/nmn" }
METAMAP_MININOTEONLY_COMMANDS = { "/nextmininoteonly", "/nmno" }
METAMAP_MININOTEOFF_COMMANDS = { "/mininoteoff", "/mno" }
METAMAP_QUICKNOTE_COMMANDS = { "/quicknote", "/qnote", "/qtloc" }

-- Interface Configuration
METAMAP_OPTIONS_TITLE = "MetaMap Options";
METAMAP_OPTIONS_BUTTON = "Options";
METAMAP_OPTIONS_SHOWAUTHOR = "Afficher Cr\195\169ateur Notes"
METAMAP_OPTIONS_SHOWBUT = "Voir Bouton Minimap";
METAMAP_OPTIONS_AUTOSEL = "Retour a la ligne auto du tooltip";
METAMAP_OPTIONS_BUTPOS = "Position du Minimap Bouton";
METAMAP_OPTIONS_POI = "Afficher les POI a l'entr\195\169e de zone (Points d'Interet)";
METAMAP_OPTIONS_LISTCOLORS = "Use coloured Sidelist";
METAMAP_OPTIONS_TRANS = "Transparence";
METAMAP_OPTIONS_SHADER = "BackDrop Shader";
METAMAP_OPTIONS_SHADESET = "Instance Backdrop Color";
METAMAP_OPTIONS_DONE = "OK";
METAMAP_OPTIONS_SCALE = "Taille de la carte";
METAMAP_OPTIONS_TTSCALE = "Taille des Tooltip";
METAMAP_OPTIONS_TRACKICON = "Show Tracker on MetaMap Icon";
METAMAP_OPTIONS_CCREATOR = "[Click for Creator]";
METAMAP_OPTIONS_CONTAINER = "Data Display Opacity";
METAMAP_OPTIONS_NOTESIZE = "Map Note Scale";
METAMAP_OPTIONS_AUTOFILLCOORDS = "Autofill note subject with coordinates";
METAMAP_OPTIONS_DEBUG = "Enable Debug prints";
METAMAP_OPTIONS_FRAMESTRATA = "Set map window level";

METAMAP_MENU_FONT = "Menu FontSize";
METAMAP_MENU_MODE = "Menu sur clic";
METAMAP_MENU_EXTOPT = "General Options/Help";
METAMAP_MENU_MAPCRD = "Voir Coords";
METAMAP_MENU_MINCRD = "Voir Coords sur MiniMap";
METAMAP_MENU_FILTER = "Afficher Notes"
METAMAP_MENU_FILTER1 = "Tout Afficher"
METAMAP_MENU_FILTER2 = "Tout Cacher"
METAMAP_MENU_TRKFILTER = "Tracker Filter";
METAMAP_MENU_MAPSET = "Mode d\'Affichage Carte";
METAMAP_MENU_MAPMOD = "Cr\195\169er Notes avec MapMod";
METAMAP_MENU_ACTION = "Clic à travers Carte";
METAMAP_MENU_FLIGHT = "Options FlightMap";
METAMAP_MENU_TRKMOD = "Tracker Display";
METAMAP_MENU_TRKSET = "Track Herbs/Minerals";
METAMAP_MENU_BWPMOD = "D\195\169finir destination";
METAMAP_MENU_FWMMOD = "Affiche l\'inexplor\195\169";
METAMAP_MENU_WKBMOD = "Base de donn\195\169es"
METAMAP_MENU_NBKMOD = "Note Book";
METAMAP_MENU_QSTMOD = "Quest Log";

METAMAP_TABTEXT1 = "General";
METAMAP_TABTEXT2 = "MetaNotes";
METAMAP_TABTEXT3 = "Modules";
METAMAP_TABTEXT4 = "Database";
METAMAP_TABTEXT5 = "ZoneCheck";
METAMAP_TABTEXT6 = "Help";

METAMAP_NOMODULE = "module is missing or not enabled!";
METAMAP_MODULETEXT = "Always load the following modules when starting a new session";
METAMAP_FWM_TEXT = "Show FWM Options";

METAMAP_LOADCVT_BUTTON = "Load Import Module";
METAMAP_LOADEXP_BUTTON = "Export User file";
METAMAP_LOADBKP_BUTTON = "Backup/Restore";
METAMAP_IMPORTS_HEADER = "Import/Export Module";
METAMAP_RELOADUI_BUTTON = "Reload UI";
METAMAP_IMPORT_BUTTON = "Import";
METAMAP_IMPORT_INSTANCE = "Instance Notes";
METAMAP_IMPORT_INSTANCE_INFO = "This will import any notes created for the instance maps. The file 'MetaMapData.lua' must exist in the MetaMapCVT directory, and contain data in the correct format. This file is included as standard with MetaMap";
METAMAP_IMPORT_EXP = "User File";
METAMAP_IMPORT_EXP_INFO = "This will import User created notes into MetaMap. The file 'MetaMapEXP.lua' must exist in the MetaMapCVT directory, and contain data in the correct format. This is the file created as 'SavedVariables\\MetaMapEXP.lua' by the Exports module.\nThis will additionally import notes created by MapMod or QuestHistory into MetaMap. Please refer to 'Modules' in the Help section for correct procedure.";
METAMAP_IMPORTS_INFO = "Reload the User Interface after use, to ensure all redundant data is cleared from memory.";
METAMAP_CONFIRM_IMPORT = "Current import file contains data for";
METAMAP_CONFIRM_EXPORT = "Please select the desired data file to export";

METAMAP_ZONECHECK_BUTTON = "Check Zones";
METAMAP_ZONEMOVE_BUTTON = "Convert Zone";
METAMAP_ORPHAN_TEXT1 = "Selected %s of |cffff0000%s|r orphaned zones:";
METAMAP_ORPHAN_TEXT2 = "Select correct zone to convert to:";
METAMAP_ZONE_ERROR = "Found incorrect zone names for:";
METAMAP_ZONE_SHIFTED = "Successfully converted |cffff0000%s|r to |cff00ff00%s|r";
METAMAP_ZONE_NOSHIFT = "No orphaned zones found. All data zones match current zones.";

METAMAPEXP_EXPORTED = "Exported %s unique %s entries to";

METAMAPFWM_USECOLOR = "Colorier zones inexplor\195\169es";
METAMAPFWM_SETCOLOR = "D\195\169finir couleur";

METAKB_LOAD_MODULE = "Load Module";
METAMAP_NOKBDATA = "MetaMapWKB module not loaded - KB data not processed";

METAMAPBLT_HINT = "Maj+Clic: Lien Chat  -  Ctrl+Clic: Cabine d'essayage";
METAMAPBLT_NO_INFO = "No information available for this item";
METAMAPBLT_NO_DATA = "Data not yet available or data not imported";
METAMAPBLT_CLASS_SELECT = "Select required class below";

METAMAPBKP_BACKUP = "Backup Donn\195\169es";
METAMAPBKP_RESTORE = "Restauration Donn\195\169es";
METAMAPBKP_INFO = "Backup will save all current data to a seperate file. Choose Restore at any time to replace the current data with the last saved data.";
METAMAPBKP_BACKUP_DONE = "Successfuly backed up all data";
METAMAPBKP_RESTORE_DONE = "Successfuly restored all data";
METAMAPBKP_RESTORE_FAIL = "No data found to restore";

METAMAP_INFOLINE_HINT1 = "Clic gauche pour StoryLine On/Off";
METAMAP_INFOLINE_HINT2 = "Clic droit pour Liste On/Off";
METAMAP_INFOLINE_HINT3 = "-Clic Droit sur carte pour zoom arri\195\168re"
METAMAP_INFOLINE_HINT4 = "-Ctrl+Clic Gauche pour cr\195\169er une Note"
METAMAP_INFOLINE_HINT5 = "ShiftClick to insert coords";
METAMAP_INFOLINE_HINT6 = "CTRLClick to toggle colours";

METAMAP_BUTTON_TOOLTIP1 = "Clic gauche pour afficher la carte";
METAMAP_BUTTON_TOOLTIP2 = "Clic droit pour les options";
METAMAP_CLICK_ON_SECOND_NOTE = "Choisissez une Note pour tracer/effacer une ligne"
METAMAP_CLICK_ON_LOCATION = "Clic Gauche sur la Carte pour un nouvel emplacement de Note"

METAMAP_NEW_NOTE = "Cr\195\169er Note"
METAMAP_MININOTE_OFF = "MiniNotes off"
METAMAP_OPTIONS_TEXT = "Notes Options"
METAMAP_CANCEL = "Annuler"
METAMAP_EDIT_NOTE = "Modifier Note"
METAMAP_MININOTE_ON = " MiniNote On"
METAMAP_SEND_NOTE = "Envoyer Note"
METAMAP_TOGGLELINE = "Ligne +/-"
METAMAP_MOVE_NOTE = "D\195\169placer Note";
METAMAP_DELETE_NOTE = "Supprimer Note"
METAMAP_SAVE_NOTE = "Sauvegarder"
METAMAP_NEWNOTE = "Nouveau";
METAMAP_EDIT_TITLE = "Titre (requis):"
METAMAP_EDIT_INFO1 = "Ligne d\226\128\153Information 1 (optionnelle):"
METAMAP_EDIT_INFO2 = "Ligne d\226\128\153Information 2 (optionnelle):"
METAMAP_EDIT_CREATOR = "Cr\195\169ateur (optionnel - Laisser vide pour cacher):"

METAMAP_SEND_MENU = "Envoyer Note"
METAMAP_SLASHCOMMAND = "Changer de Mode"
METAMAP_SEND_TIP = "Les notes peuvent \195\170tre re\195\167ues par les utilisateurs de Mapnotes"
METAMAP_SEND_PLAYER = "Nom du joueur :"
METAMAP_SENDTOPLAYER = "Envoyer Joueur"
METAMAP_SENDTOPARTY = "Envoyer Groupe"
METAMAP_SENDTOGUILD = "Envoyer Guild"
METAMAP_SHOWSEND = "Changer Mode"
METAMAP_SEND_SLASHTITLE = "Obtenir la /commande :"
METAMAP_SEND_SLASHTIP = "Selectionnez ceci et utilisez CTRL+C pour la copier dans le presse-papier.\n(Vous pouvez ensuite l\226\128\153envoyer sur un forum par exemple)"
METAMAP_SEND_SLASHCOMMAND = "/Commande :"
METAMAP_PARTYSENT = "PartyNote envoy\195\169e a tous le Groupe.";
METAMAP_RAIDSENT = "PartyNote envoy\195\169e a tous le Raid.";
METAMAP_GUILDSENT = "Note sent to all Guild members.";
METAMAP_NOGUILD = "Not currently a Guild member.";
METAMAP_NOPARTY = "Vous n'\195\170tes pas dans un Groupe ou un Raid.";
METAMAP_NOPLAYER = "Player name missing!";

METAMAP_OWNNOTES = "Afficher les notes cr\195\169\195\169es par votre personnage."
METAMAP_OTHERNOTES = "Afficher les Notes re\195\167ues des autres joueurs."
METAMAP_HIGHLIGHT_LASTCREATED = "Mettre en \195\169vidence (en |cFFFF0000rouge|r) la derni\195\168re Note cr\195\169\195\169e."
METAMAP_HIGHLIGHT_MININOTE = "Mettre en \195\169vidence (en |cFF6666FFbleu|r) la Note selectionn\195\169e."
METAMAP_ACCEPTINCOMING = "Accepter les Notes des autres utilisateurs."
METAMAP_AUTOPARTYASMININOTE = "Membres du groupe en MiniNote."
METAMAP_ZONESEARCH_TEXT = "Effacer les Notes pour |cffffffff%s|r par:"
METAMAP_ZONESEARCH_TEXTHINT = "Hint: Open WorldMap and set map to desired area for deletion";
METAMAP_BATCHDELETE = "This will delete all notes for |cFFFFD100%s|r with creator as |cFFFFD100%s|r.";
METAMAP_DELETED_BY_NAME = "Deleted selected notes with creator |cFFFFD100%s|r and name |cFFFFD100%s|r."
METAMAP_DELETED_BY_CREATOR = "Deleted all notes with creator |cFFFFD100%s|r."
METAMAP_DELETED_BY_ZONE = "Deleted all notes for |cFFFFD100%s|r with creator |cFFFFD100%s|r."

METAMAP_CREATEDBY = "Cr\195\169\195\169 par"
METAMAP_MAPNOTEHELP = "Cette commande ne peut \195\170tre utilis\195\169e que pour ajouter une Note."
METAMAP_ACCEPT_NOTE = "Note ajout\195\169 dans |cFFFFD100%s|r."
METAMAP_DECLINE_NOTE = "Ajout impossible, Note trop proche de |cFFFFD100%q|r dans |cFFFFD100%s|r."
METAMAP_ACCEPT_MININOTE = "MiniNote active pour la carte de |cFFFFD100%s|r.";
METAMAP_DECLINE_GET = "|cFFFFD100%s|r a essay\195\169 de vous envoyer la Note |cFFFFD100%s|r, mais elle est trop proche de |cFFFFD100%q|r."
METAMAP_DISABLED_GET = "R\195\169ception impossible, la r\195\169ception de Notes est d\195\169sactiv\195\169e."
METAMAP_ACCEPT_GET = "Vous avez re\195\167u la Note \226\128\153|cFFFFD100%s|r dans |cFFFFD100%s|r"
METAMAP_PARTY_GET = "|cFFFFD100%s|r utilis\195\169 comme Note de g\226\128\153roupe dans |cFFFFD100%s|r."
METAMAP_NOTE_SENT = "Note envoy\195\169e \195\160 |cFFFFD100%s|r."
METAMAP_QUICKNOTE_DEFAULTNAME = "Note Rapide"
METAMAP_MININOTE_DEFAULTNAME = "MiniNote"
METAMAP_VNOTE_DEFAULTNAME = "VirtuelNote"
METAMAP_SETMININOTE = "Utiliser comme MiniNote"
METAMAP_PARTYNOTE = "Note de groupe"
METAMAP_SETCOORDS = "Coords (xx,yy):"
METAMAP_VNOTE = "Virtuel"
METAMAP_VNOTE_INFO = "Cr\195\169er une note virtuelle. Sauver sur la carte au choix."
METAMAP_VNOTE_SET = "Note virtuelle cr\195\169e sur la carte du monde."
METAMAP_MININOTE_INFO = "Cr\195\169e une note sur la Minimap seulement."
METAMAP_INVALIDZONE = "Cr\195\169ation impossible - Pas de coordonn\195\169es disponibles dans cette zone.";

--- Instances Information

---Profondeurs de Brassenoire
METAMAP_BFD_INFO = "Situé le long de la grève de Zoram, en Ashenvale, les profondeurs de Brassenoire étaient autrefois un merveilleux temple, dédié à Élune, la déesse-lune des elfes de la nuit. La Grande Fracture a englouti le temple sous les vagues de la Mer voilée. Il y est resté, intouché, jusqu'à ce que les nagas et les satyres, attirés par son pouvoir ancien, émergent pour fouiller ses secrets. À en croire la légende, la bête ancienne nommée Aku'mai s'y est installée. Aku'mai, qui était le familier favori des Anciens dieux primordiaux, sévit dans la région depuis fort longtemps. Attiré par la présence d'Aku'mai, le culte connu sous le nom de Marteau du crépuscule est venu savourer la présence maléfique des Anciens dieux.";
---Profondeurs de Rochenoire
METAMAP_BRD_INFO = "Ce labyrinthe volcanique était autrefois la capitale des nains Dark Iron. C'est aujourd'hui le domaine de Ragnaros, le seigneur du feu. Ragnaros a découvert le moyen de créer la vie à partir de la pierre, et il compte bâtir une armée de golems pour l'aider à conquérir la totalité du mont Blackrock. Obsédé par l'idée de vaincre Nefarian et ses sbires draconiques, Ragnaros est prêt à n'importe quelle extrémité pour triompher.";
---Pic Rochenoire
METAMAP_BRS_INFO = "La puissante forteresse taillée dans les entrailles enflammées du mont Blackrock fut conçue par le maître-maçon nain Franclorn Forgewright. Elle devait être le symbole de la puissance des Dark Iron, et ceux-ci la conservèrent pendant des siècles. Mais Nefarian, le rusé fils du dragon Deathwing avait d'autres plans pour cet immense donjon. Aidé par ses sbires draconiques, il prit le contrôle du haut du pic et partit en guerre contre les domaines des nains, dans les profondeurs volcaniques de la montagne. Réalisant que les nains étaient dirigés par le grand élémentaire de feu, Ragnaros, Nefarian fit le vœu d'écraser ses adversaires et de s'emparer de la totalité de la montagne.";
---Pic Blackrock supérieur
METAMAP_BSU_INFO = "La puissante forteresse taillée dans les entrailles enflammées du mont Blackrock fut conçue par le maître-maçon nain Franclorn Forgewright. Elle devait être le symbole de la puissance des Dark Iron, et ceux-ci la conservèrent pendant des siècles. Mais Nefarian, le rusé fils du dragon Deathwing avait d'autres plans pour cet immense donjon. Aidé par ses sbires draconiques, il prit le contrôle du haut du pic et partit en guerre contre les domaines des nains, dans les profondeurs volcaniques de la montagne. Réalisant que les nains étaient dirigés par le grand élémentaire de feu, Ragnaros, Nefarian fit le vœu d'écraser ses adversaires et de s'emparer de la totalité de la montagne.";
---Repaire de l'Aile noire
METAMAP_BWL_INFO = "Blackwing Lair can be found at the very height of Blackrock Spire. It is there in the dark recesses of the mountain's peak that Nefarian has begun to unfold the final stages of his plan to destroy Ragnaros once and for all and lead his army to undisputed supremacy over all the races of Azeroth. Nefarian has vowed to crush Ragnaros. To this end, he has recently begun efforts to bolster his forces, much as his father Deathwing had attempted to do in ages past. However, where Deathwing failed, it now seems the scheming Nefarian may be succeeding. Nefarian's mad bid for dominance has even attracted the ire of the Red Dragon Flight, which has always been the Black Flight's greatest foe. Though Nefarian's intentions are known, the methods he is using to achieve them remain a mystery. It is believed, however that Nefarian has been experimenting with the blood of all of the various Dragon Flights to produce unstoppable warriors.";
---Hache-Tripes
METAMAP_DMC_INFO = "Bâtie il y a douze mille ans par une secte secrète de sorciers elfes de la nuit, l'antique cite d'Eldre'Thalas servait à protéger les secrets magiques les plus précieux de la reine Azshara. Elle fut ravagée par la Grande Fracture du monde, mais une bonne partie de la ville se dresse encore, rebaptisée Hache-tripes. Les trois quartiers de la ville ont été envahis de toutes sortes de créatures, Bien-nés spectraux, vils satyres et ogres brutaux. Seuls les groupes d'aventuriers les plus audacieux peuvent pénétrer dans cette ville détruite et affronter les maux anciens qui y sont enfermés dans ses salles antiques.";
---Gnomeregan
METAMAP_GNM_INFO = "Capitale des gnomes depuis des générations, Gnomeregan était la merveille technologique de Dun Morogh. Mais il y a peu, une race de troggs mutants hostiles a attaqué plusieurs régions de Dun Morogh, y compris la grand cité gnome. Dans une tentative désespérée pour repousser les envahisseurs, le Grand Artisan Mekkatorque ordonna que les réservoirs de déchets radioactifs soient purgés. Les gnomes se précipitèrent aux abris, attendant que les substances toxiques qui saturaient l'air tuent les troggs ou les poussent à la fuite. Malheureusement, bien que les troggs aient été irradiés, ils poursuivirent le siège. Les gnomes qui ne furent pas tués par les vapeurs durent fuir et se réfugier dans la cité naine toute proche, Ironforge. Le Grand Artisan Mekkatorque cherche à y recruter des âmes vaillantes pour aider son peuple à reprendre sa ville bien-aimée. On murmure que l'ancien conseiller de Mekkatorque, le Mekgineer Thermaplug a trahi son peuple en permettant à l'invasion de se produire. Devenu fou, Thermaplug est toujours à Gnomeregan, ourdissant de sinistres complots et servant de nouveau technomaître à la ville.";
---Maraudon
METAMAP_MDN_INFO = "Protégé par les terribles centaures Maraudine, Maraudon est l'un des lieux les plus sacrés de Désolace. Ce grand temple/caverne est la tombe de Zaetar, l'un des deux fils immortels nés du demi-dieu Cénarius. A en croire la légende, Zaetar et Theradras, la princesse des élémentaires de terre, engendrèrent le peuple des centaures. On dit également que peu après, les centaures barbares se retournèrent contre leur père et le tuèrent. Certains croient que Theradras, dans son chagrin, emprisonna l'esprit de Zaetar dans la caverne sinueuse, et qu'elle se servit de cette énergie dans des buts maléfiques. Les tunnels souterrains sont peuplés des esprits cruels des Khans centaures morts depuis longtemps, sans oublier les sbires élémentaires déchaînés de Theradras.";
---Cœur du Magma
METAMAP_TMC_INFO = "Le Cœur du Magma repose au fin fond des profondeurs de Blackrock. Il est le cœur de la montagne Blackrock et le lieu où, il y a bien longtemps, tentant désespérément de changer le cours de la guerre civile naine, l'empereur Thaurissan invoqua Ragnaros, le seigneur du Feu, en Azeroth. Bien que le seigneur du Feu soit incapable de s'éloigner du noyau ardent, certains pensent que ses serviteurs commandent aux nains Dark Iron, travaillant activement à la création d'une armée à partir de pierre vivante. Le lac enflammé où Ragnaros repose endormi sert de portail vers le plan du feu, que des élémentaires malveillants n'hésitent pas à traverser. C'est au majordome Executus que revient le soin de diriger les agents de Ragnaros. Cet élémentaire particulièrement rusé est le seul capable de réveiller le seigneur du Feu.";
---Repaire d'Onyxia
METAMAP_ONL_INFO = "Onyxia est la fille du puissant dragon Deathwing, et la sœur de l'intrigant Nefarian, seigneur du Pic Blackrock. Il est dit qu'Onyxia aime à corrompre les peuples mortels en se mêlant de leurs affaires politiques. À cette fin, elle revêtirait diverses formes humanoïdes et userait de ses charmes et de ses pouvoirs pour influencer à sa convenance la diplomatie, ô combien délicate, entre les différents peuples d'Azeroth. Certains croient même qu'Onyxia a assumé une identité autrefois prise par son père, à savoir le titre de la maison royale Prestor. Lorsqu'elle ne se mêle pas des affaires des mortels, Onyxia demeure dans les caves embrasées sous le Cloaque aux dragons, un lugubre marais du Marécage d'Âprefange. Dans son repaire, elle est protégée par ses pairs, membres survivants du Vol des dragon noirs.";
---Gouffre de Ragefeu
METAMAP_RFC_INFO = "Le gouffre de Ragefeu est un réseau de cavernes volcaniques qui se trouve sous Orgrimmar, la nouvelle capitale des orcs. Depuis peu, des rumeurs prétendent qu'un culte loyal au démoniaque Conseil des ombres s'est installé dans ses profondeurs enflammées. Ce culte, nommé la Lame ardente, menace la souveraineté même de Durotar. Beaucoup de gens croient que le Chef de guerre Thrall est informé de l'existence de la Lame et a choisi de ne pas la détruire dans l'espoir que ses membres pourraient le mener au Conseil des ombres. Quoi qu'il advienne, la puissance ténébreuse qui émane du gouffre de Ragefeu pourrait anéantir tout ce pour quoi les orcs ont lutté.";
---Souilles de Tranchebauge
METAMAP_RFD_INFO = "Taillées dans les mêmes ronces géantes que le Kraal de Tranchebauge, les Souilles de Tranchebauge sont la capitale traditionnelle du peuple huran, le peuple des hommes-sangliers. Ce labyrinthe immense et hérissé d'épines abrite une véritable armée de hurans loyaux et leurs grands prêtres – la tribu Tête de Mort. Depuis peu, une ombre lugubre s'étend sur ce domaine primitif. Des agents du Fléau mort-vivant, conduits par la liche Amnennar, dite le Porte-froid, ont pris le contrôle du peuple huran et ont transformé le labyrinthe de ronces en un bastion de la puissance des morts-vivants. Les hurans livrent une bataille désespérée pour reconquérir leur ville bien-aimée avant qu'Amnennar n'étende sa puissance sur les Tarides.";
---Kraal de Tranchebauge
METAMAP_RFK_INFO = "Il y a dix mille ans, au cours de la guerre des Anciens, le puissant demi-dieu Agamaggan partit affronter la Légion ardente. Le colossal sanglier tomba au combat, mais son sacrifice aida à préserver Azeroth de la défaite. Avec le temps, là où avait coulé son sang, d'immenses plantes épineuses sortirent du sol. Les hurans, les hommes-sangliers, dont on suppose qu'ils sont les descendants mortels du dieu, vinrent occuper ces régions, sacrées pour eux. Le cœur de ces colonies de ronces géantes prit le nom de Tranchebauge. Une grande partie du Kraal a été conquise par la vieille mégère Charlga Razorflank. Sous sa férule, les hurans, pratiquant la foi chamanique, attaquent les tribus rivales et les villages de la Horde. À en croire les rumeurs, Charlga négocierait avec des agents du Fléau, et serait en train de placer sa tribu, qui ne se doute de rien, parmi les rangs des morts-vivants pour une raison inconnue.";
---Monastère écarlate
METAMAP_TSM_INFO = "Le monastère était autrefois un grand centre d'éducation et d'illumination, l'orgueil de la prêtrise de Lordaeron. Avec la venue du Fléau mort-vivant au cours de la Troisième Guerre, ce paisible monastère devint la forteresse des fanatiques de la Croisade écarlate. Les Croisés se montrent intolérants envers toutes les races non-humaines, quelles que soient leurs alliances ou leur affiliation. Soupçonnant tous les étrangers d'être porteurs de la Peste de la non-vie, ils les tuent sans hésitation. Les rapports indiquent que les aventuriers qui pénètrent dans le monastère sont forcés d'affronter le Commandant écarlate Mograine, qui contrôle une importante garnison de guerriers fanatiques. Toutefois, le vrai maître des lieux est la Grande inquisitrice Whithemane – une prêtresse qui possède la capacité de ressusciter les guerriers qui tombent en combattant pour elle.";
---Scholomance
METAMAP_SLM_INFO = "La Scholomance se trouve dans une série de cryptes, sous le donjon en ruine de Caer Darrow. C'était autrefois le domaine de la noble famille Barov, mais il tomba au cours de la Deuxième Guerre. Lorsque le mage Kel'thuzad recrutait des disciples pour former le Culte des Damnés, il promettait souvent l'immortalité en échange de la promesse de servir le Roi-liche. La famille Barov succomba au charisme de Kel'thuzad et donna son donjon et ses cryptes au Fléau. Les sectateurs tuèrent les Barov et transformèrent les cryptes en une école de nécromancie, la Scholomance. Kel'thuzad ne réside plus dans les cryptes, mais elles sont encore infestées de fanatiques et de leurs instructeurs. La liche Ras Frostwhisper règne sur les lieux et les protége au nom du Fléau. Quant au nécromancien mortel, le Sombre Maître Gandling, il sert de directeur à l'école.";
---Donjon d'Ombrecroc
METAMAP_SFK_INFO = "Au cours de la Troisième Guerre, les mages du Kirin Tor combattirent les armées mortes-vivantes du Fléau. Mais à chaque mage de Dalaran qui tombait au combat, se relevait peu après un mort-vivant ; et leur puissance s'ajoutait à celle du Fléau. Frustré par l'absence de résultats (et contre l'avis de ses pairs), l'archimage Arugal décida d'invoquer des entités extradimensionnelles pour renforcer les rangs déclinants de Dalaran. L'invocation d'Arugal ouvrit les portes d'Azeroth aux voraces worgens. Ces hommes-loups sauvages massacrèrent les troupes du Fléau avant de se retourner contre les mages eux-mêmes. Ensuite, ils assiégèrent le château du noble baron Silverlaine. Situé au-dessus du hameau de Bois-du-Bûcher, le donjon ne tarda pas à se transformer en une sombre ruine. Rendu fou par la culpabilité, Arugal adopta les worgens comme ses enfants et se retira dans le tout fraîchement rebaptisé « donjon d'Ombrecroc ». On dit qu'il y vit toujours, protégé par son colossal familier Fenrus, et hanté par le fantôme vengeur du baron Silverlaine.";
---Stratholme
METAMAP_STR_INFO = "La ville de Stratholme était le joyau de Lordaeron. C'est là que le prince Arthas se retourna contre son mentor, Uther Lightbringer, et qu'il mit à mort des centaines de ses propres sujets, qu'il croyait atteint par la terrible Peste de la non-vie. Peu après, Arthas bascula et se livra au Roi-liche. La cité en ruine est à présent le domaine du Fléau mort-vivant, dirigé par la puissante liche Kel'thuzad. Un contingent de Croisés écarlates, dirigés par le Grand croisé Dathrohan tient également une partie de la ville. Les deux camps ne cessent de se combattre. Les aventuriers assez braves (ou assez fous) pour pénétrer dans Stratholme ne tarderont pas à se mettre les deux factions à dos. On dit que la ville est gardée par trois tours de garde géantes, sans oublier de puissants nécromanciens, des banshees et des abominations. Certains rapports mentionnent également un Chevalier de la mort monté sur un effrayant destrier. Sa colère s'abattrait sur tous ceux qui osent pénétrer dans le royaume du Fléau.";
---Les Mortemines
METAMAP_TDM_INFO = "Les « mines mortes » étaient autrefois le principal centre de production d'or des royaumes humains, mais elles furent abandonnées lorsque la Horde rasa Stormwind au cours de la Première Guerre. De nos jours, la Confrérie défias s'est établie dans ces tunnels obscurs et en a fait son sanctuaire. On murmure que ces voleurs auraient recruté des gobelins pour les aider à construire quelque chose de terrible au fond des mines – mais nul ne sait quoi. À en croire les rumeurs, l'accès des Mortemines se trouverait non loin du petit village discret de Ruisselune.";
---La Prison
METAMAP_TSK_INFO = "La Prison est un complexe de haute sécurité, caché sous le quartier des canaux de Stormwind. Dirigée par le Gardien Thelwater, la Prison est le domaine des petits voyous, des protestataires, des assassins et de dizaines de criminels violents. Récemment, une révolte de prisonniers à déclenché le chaos dans la Prison – les gardes en ont été chassés et les prisonniers ont pris le contrôle des lieux. Le Gardien Thelwater est parvenu à s'échapper et tente de recruter des têtes brûlées pour s'introduire dans la prison et liquider le chef des mutins, le rusé Bazil Thredd.";
---Le temple d'Atal'Hakkar
METAMAP_TST_INFO = "Il y a plus de mille ans, le puissant empire Gurubashi a été ravagé par une guerre civile de grande ampleur. Un groupe de prêtres trolls influents, les Ata'lai, ont tenté de ramener un ancien dieu du sang nommé Hakkar l'Ecorcheur d'esprit. Bien que les prêtres aient été vaincus et exilés, le grand empire troll s'effondra malgré tout. Les prêtres exilés s'enfuirent vers le nord, dans le Marais des Chagrins. Ils y bâtirent un grand temple dédié à Hakkar, d'où ils préparèrent son arrivée dans le monde physique. Le grand Aspect dragon, Ysera, découvrit les plans des Ata'lai et détruisit le temple. Aujourd'hui encore, ses ruines englouties sont gardées par des dragons verts qui tentent d'empêcher toute entrée ou sortie. On suppose que certains Ata'lai auraient survécu à la colère d'Ysera, et se seraient consacrés à nouveau au noir service d'Hakkar.";
---Uldaman
METAMAP_ULD_INFO = "Uldaman est une antique cache des Titans, enfoui au plus profond de la terre depuis la création du monde. Des fouilles naines ont récemment ouvert cette cité oubliée, libérant la première création manquée des Titans, les troggs. La légende prétend que les Titans ont taillé les troggs dans la pierre. Lorsqu'ils ont estimé que l'expérience était un échec, les Titans ont enfermé les troggs et ont procédé à un deuxième essai, donnant naissance aux nains. Les secrets de la création des nains sont conservés sur les Disques de Norgannon, de massifs artefacts fabriqués par les Titans, et qui se trouvent aux tréfonds de la ville. Depuis peu, les nains Dark Iron ont lancé une série d'incursions dans Uldaman, dans l'espoir de découvrir les disques pour leur maître incandescent, Ragnaros. Toutefois, la ville est protégée par plusieurs gardiens, des géants de pierre artificiels et animés qui broient les intrus. Les Disques eux-mêmes sont protégés par Archadeas, un colossal Gardien des pierres éveillé à la conscience. Certaines rumeurs laissent entendre que les ancêtres des nains, les terrestres à la peau de pierre, pourraient encore vivre dans les cachettes les plus profondes de la cité.";
---Cavernes des lamentations
METAMAP_TWC_INFO = "Récemment, Naralex, un druide elfe de la nuit, a découvert un réseau de cavernes souterraines au cœur des Tarides. Elles doivent leur nom aux évents volcaniques qui produisent de longs gémissements lugubres lorsque de la vapeur s'en échappe. Naralex s'imaginait qu'il pourrait se servir des sources souterraines des cavernes pour rendre leur fertilité aux Tarides - mais pour cela, il aurait dû siphonner l'énergie du légendaire Rêve d'émeraude. Mais lorsqu'il se connecta au Rêve, la vision du druide tourna au cauchemar. Les Cavernes des lamentations changèrent. Leurs eaux croupirent et les créatures dociles qui y vivaient se métamorphosèrent en prédateurs vicieux. On dit que Naralex en personne vit quelque part au cœur de ce labyrinthe, piégé aux confins du Rêve d'émeraude. Même ses anciens acolytes ont été corrompus par le cauchemar éveillé de leur maître. Ils sont devenus les cruels Druides déviants.";
---Zul'Farrak
METAMAP_ZFK_INFO = "Cette cite écrasée de soleil est le domaine des trolls Sandfury, connus pour leur cruauté et leur mysticisme ténébreux. Les légendes trolls parlent d'une épée puissante, Sul'thraze la Flagellante, capable d'instiller la peur et la faiblesse au plus redoutable des ennemis. Il y a bien longtemps, l'épée fut brisée en deux, mais on dit que les deux moitiés se trouveraient quelque part dans les murs de Zul'Farrak. D'autres rumeurs laissent entendre qu'une bande de mercenaires fuyant Gadgetzan se sont aventurés dans la cité et y ont été piégés. Le sort reste mystérieux. Mais le plus perturbant restent les murmures qui mentionnent une créature ancienne qui dormirait sous un bassin sacré au cœur de la cité – un puissant demi-dieu qui détruira impitoyablement tout aventurier assez fou pour venir l'éveiller.";
---Zul'Gurub
METAMAP_ZGB_INFO = "Plus de mille ans auparavant, le puissant empire Gurubashi a été déchiré par une gigantesque guerre civile. Un groupe de prêtres trolls influents, les Atal'ai, tenta de faire revenir l'avatar d'un dieu ancien et terrible, Hakkar l'Écorcheur d'âmes, le Dieu sanglant. Les prêtres furent vaincus, puis exilés, mais le grand empire troll s'effondra. Les prêtres bannis s'enfuirent vers le nord, dans le marais des Chagrins, où ils bâtirent un grand temple à Hakkar pour préparer son retour dans le monde physique.";
---Ahn'Qiraj
METAMAP_TAQ_INFO = "C'est au cœur d'Ahn'Qiraj que repose ce très ancien temple. Construit en des temps où l'histoire n'était pas encore écrite, c'est à la fois un monument à d'indicibles dieux et une ruche massive où nait l'armée qiraji. Depuis que la guerre des Sables changeants s'est achevée il y a un millier d'années, les empereurs jumeaux de l'empire qiraji ont été enfermés dans leur temple, à peine contenus par la barrière magique érigée par le dragon de bronze Anachronos et les elfes de la nuit. Maintenant que le sceptre des Sables changeant a été réassemblé et que le sceau a été brisé, le chemin vers le sanctuaire d'Ahn'Qiraj a été ouvert. Par delà la folie grouillante des ruches, sous le temple d'Ahn'Qiraj, des légions de qiraji se préparent à l'invasion. Ils doivent être arrêtés à tout prix, avant qu'ils ne lâchent à nouveau sur Kalimdor leurs armées insectoïdes et voraces, et qu'une seconde guerre des Sables changeants ne se déclenche.";
---Ruines d'Ahn'Qiraj
METAMAP_RAQ_INFO = "Au cours des instants finaux de la guerre des Sables changeants, les forces combinées des elfes de la nuit et des quatre vols de dragon poussèrent la bataille jusqu'au cœur même de l'empire qiraji, dans la cité forteresse d'Ahn'Qiraj. Toutefois, alors qu'elles étaient aux portes de la cité, les armées de Kalimdor rencontrèrent une concentration de silithides guerriers plus importante que tout ce qu'elles avaient affronté auparavant. Finalement, les silithides et leurs maîtres qiraji ne furent point défaits, mais seulement emprisonnés derrière une barrière magique ; et la guerre laissa en ruines la cité maudite. Un millier d'années a passé depuis ce jour mais les forces qiraji ne sont pas restées inactives. Une nouvelle et terrible armée est née des ruches, et les ruines d'Ahn'Qiraj grouillent à nouveau de nuées de silithides et de qiraji. Cette menace doit être éliminée ou tout Azeroth pourrait tomber devant la puissance terrifiante de la nouvelle armée qiraji.";
---Naxxramas
METAMAP_NAX_INFO = "Flottant au-dessus des Maleterres, la nécropole de Naxxramas sert de résidence à l'un des plus puissants serviteurs du roi-liche, la terrible liche Kel'Thuzad. Des horreurs venues du passé s'y rassemblent, rejoignant de nouvelles terreurs encore inconnues du reste du monde. Les serviteurs du roi-liche se préparent à l'assaut. Le Fléau est en marche... Naxxramas est un nouveau donjon de raid pour 40 personnes. Il représentera un défi épique pour les personnages-joueurs les plus puissants et les plus expérimentés.";
---Hellfire Citadel
METAMAP_HFC_INFO = "Bien que Draenor ait été en grande partie déchiqueté par les actions du téméraire Ner'zhul, la citadelle des Flammes infernales est restée intacte, maintenant habitée par des bandes de gangr’orcs, rouges, furieux et en maraude. Même si la présence de cette nouvelle et sauvage engeance reste un mystère, le plus étrange est sans aucun doute que le nombre de ces gangr’orcs grossit de jour en jour. \n\nMalgré la réussite du plan de Thrall et de Grom Hellscream pour mettre un terme à la corruption de la Horde par l'assassinat de Mannoroth, les orcs barbares de la citadelle des Flammes infernales semblent avoir trouvé une nouvelle source de corruption qui leur permet d'alimenter leur furie sanguinaire. \n\nBien que personne ne sache qui dirige ces orcs, tout indique qu'ils ne travaillent pas pour la Légion ardente. \n\nLes nouvelles les plus troublantes en provenance de l'Outreterre concernent peut-être les témoignages décrivant des cris sauvages et retentissants en provenance des profondeurs de la citadelle. Beaucoup se sont demandés si ces hurlements inhumains étaient liés de près ou de loin avec la multiplication des gangr’orcs corrompus. Malheureusement ces questions demeurent sans réponse. \n\nAu moins pour le moment…";
---Coilfang Reservoir
METAMAP_CFR_INFO = "The delicate ecology of Zangarmarsh has been thrown out of balance. Unnatural phenomena are corrupting and destroying the marsh's native flora and fauna. This disturbance has been traced to the foreboding Coilfang Reservoir. It is rumored that the leader of this mysterious edifice is none other than the infamous Lady Vashj. Only you can discover her nefarious plans and stop them before it's too late. Coilfang Reservoir is divided into four areas, three of which are five-man dungeons (the Slave Pens, the Underbog, and the Steamvault), in addition to the 20-man raid dungeon, Serpentshrine Cavern.";
---Auchindoun
METAMAP_AUC_INFO = "It was once a holy ground for Draenei burial until a group of renegade Orcs botched an attempt to summon a demon in its walls. The resulting magical disaster nearly destroyed the entire area. Its crypt-filled interior looks quite haunting. \n\nAuchindoun is now in turmoil as different factions vie for power in this magical spot. [5] \n\nNow it is ruled by a being named Murmur, a powerful elemental similar to Ragnaros and Thunderaan, but aligned with the power of elemental sound rather than with fire, wind, or other known elements. Along the way, you face fallen draenei, demons (including a fel guard overseer), ethereals, orcs, ogres, and even some undead.\n";
---Tempest Keep
METAMAP_TTK_INFO = "The mighty Tempest Keep was created by the enigmatic naaru: sentient beings of pure energy and the sworn enemies of the Burning Legion. As a base of operations for the naaru, the structure itself possesses the technology to teleport through alternate dimensions, traveling from one location to another in the blink of an eye. \n\nWith Outland serving as the strategic battlefront in the ongoing Burning Crusade, the naaru recently used Tempest Keep to reach the shattered land. However, when the naaru set out from their stronghold, Prince Kael’thas and his blood elves quickly raided the dimensional fortress and assumed control over its satellite structures. \n\nNow, guided by some unknown purpose, Kael’thas manipulates the keep’s otherworldly technologies, using them to harness the chaotic energies of the Netherstorm itself. \n\nThough Kael’thas and his minions maintain a tight hold on the keep, a band of draenei recently hijacked one of its satellite structures, the Exodar, and used it to escape Outland. In seeking out other worlds, the draenei, led by the ancient prophet, Velen, hoped to find allies who would stand with them against the Legion and its nihilistic Crusade.\n";
---Magtheridons Lair
METAMAP_MAG_INFO = "A brutal Pit Lord and servant of Mannoroth the Destructor, Magtheridon found his way to Draenor after its cataclysm. With the clans in disarray, and most killed in the disaster, Magtheridon was quick to show his power, and rallied the surviving orcs under his pennant. The orcs were corrupted and became Fel Orcs. He declared himself the ruler of the ruined world Outland. \n\nOver the years, Magtheridon brought legions of demons to Outland through the four dimensional gateways which Ner'zhul shattered the world with, and his forces became very expansive. These demons included Nether Dragons, Voidwalkers, Succubi, Felguards, Felbeasts, Doomguards, Eredar, and Infernals. \n\nIt was almost twenty years after the Cataclysm that Illidan and his servants came to Outland with a plan to rid the land of all demonic entities there, so that Kil'jaeden, Illidan's vengeful master, could not follow him. \n\nMagtheridon found himself under attack by Illidan, Kael'thas and his Blood Elves, Lady Vashj's army of naga, and even the elusive draenei, led by the Elder Sage, Akama. \n\nThe combined disrupted the dimensional gateways which supplied Magtheridon with reinforcements, and then laid siege to Magtheridon's Black Citadel itself. \n\nThe Pit Lord rallied his forces to defend him, but the combined skills of the heroes crushed his resistances. Eventually, Magtheridon was defeated by the four generals, and asked if Illidan had been sent to test him. Illidan cackled in reply, saying that he had come to replace him.";
---Karazhan
METAMAP_KZN_INFO = "Between Duskwood and the Swamp of Sorrows lies the desolate region of Deadwind Pass, where jagged, brooding spires of granite loom over petrified, lifeless forests. As its name suggests, it is a land devoid of life.\nBut it was not always so... \n\nMedivh, the Last Guardian, made his home in Deadwind, in the bright tower of Karazhan. Though he was the greatest wizard of his day (and humanity's intended custodian) Medivh was secretly possessed by the dark spirit of Sargeras, the Destroyer of Worlds. Through Medivh, Sargeras opened the Dark Portal and allowed the orcs to wage war upon the mortal kingdoms of Azeroth. \n\nAs the war progressed, Medivh fought against Sargeras' control. The raging conflict within him finally drove the wizard irrevocably insane. His childhood friend and the king's lieutenant-at-arms, Anduin Lothar, suspected the mage of treachery. With the aid of Medivh's young apprentice, Khadgar, Lothar stormed Karazhan and killed his one-time comrade. Since that day, a terrible curse has pervaded both the tower and the lands around it - casting a dark pall over Deadwind Pass and the region that is now known as Duskwood \n\nIn recent years, nobles of Darkshire ventured into Deadwind Pass to investigate the blight that had settled over the region. They entered the dark tower – but never emerged. In fact, witnesses maintain that the dread spirits of the nobles now reside within Karazhan's walls, cursed to revel in the tower's crumbling opera house for eternity. Yet far more perilous spirits reside within Medivh's macabre study, for it was there that demonic entities responded to the deranged wizard's summons. \n\nDespite the myriad terrors that lie within, adventurers are still drawn to Karazhan - tempted by rumors of unspeakable secrets that may be found within the tower's arcane libraries. It is said that the vast, magical halls house the powerful spellbooks of Medivh himself.\n\nOnly one thing is certain when visiting the dreaded tower of Karazhan...\n\n...you may never find your way out.\n";
---Gruul's Lair
METAMAP_GRL_INFO = "";
---Caverns of Time
METAMAP_COT_INFO = "";

end
