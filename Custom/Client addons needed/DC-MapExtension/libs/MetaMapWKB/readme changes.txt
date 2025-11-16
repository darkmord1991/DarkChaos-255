--add mob to MetaMap db

comment out MetaMapWKB.lua Print (spam) Statements lines:
143: --MetaMap_Print(METAMAP_INVALIDZONE, WKB_Options.ShowUpdates);
268: --MetaMap_Print(format(TEXT(WKB_UPDATED_MINMAX_XY), unitName, mapName), WKB_Options.ShowUpdates);
268: --MetaMap_Print(format(TEXT(WKB_UPDATED_INFO), unitName, mapName), WKB_Options.ShowUpdates);

27 add:
	WKB_SingelPrint= nil
227 add:
	WKB_SingelPrint= true
263 change:
	if(addedSomething) then
		MetaMap_Print(format(TEXT(WKB_ADDED_UNIT_IN_ZONE), unitName, mapName), WKB_Options.ShowUpdates);
	end
    to:
	if(addedSomething) then
		if WKB_SingelPrint then
			WKB_SingelPrint = nil
		else
			MetaMap_Print(format(TEXT(WKB_ADDED_UNIT_IN_ZONE), unitName, mapName), WKB_Options.ShowUpdates);
		end
	end