TaxiMap750.blp -- flight-map background for map 750 (Mount Hyjal continent)
==========================================================================
MUST be packed into patch-enGB-3.MPQ, NOT patch-A or patch-4.

The file exists in BOTH Data\patch-A.MPQ and Data\enGB\patch-enGB-3.MPQ, and
the enGB chain outranks the Data\patch-N chain -- so a copy dropped into
patch-A/patch-4 is silently shadowed by the old art in patch-enGB-3 and nothing
appears to change. Update patch-A's copy too if you want the two to agree.

Paired with: DBFilesClient\WorldMapContinent.dbc (staged under patch-4, which is
where the client currently reads it from -- patch-4 outranks locale-enGB.MPQ).
The two MUST ship together: the DBC's TaxiMinX/MinY/MaxX/MaxY define the world
rectangle this image covers, so shipping one without the other puts every flight
point in the wrong place.

  box: TaxiMinX 800  TaxiMaxX 9850   TaxiMinY -7500  TaxiMaxY 1550   (square, 9050x9050)
  art: 512x512 BLP2 / DXT1 / 10 mips, cropped from Interface\WorldMap\Kalimdor
       with the seven map-750 zone names drawn on.
