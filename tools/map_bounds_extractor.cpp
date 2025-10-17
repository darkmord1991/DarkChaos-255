// Simple map bounds extractor for DarkChaos
// Scans client data path (Data/World/Maps/) and writes var/map_bounds.csv
// Usage: map_bounds_extractor <path-to-client-data>

#include <iostream>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#if __has_include("wdtfile.h") && __has_include("adtfile.h")
#include "wdtfile.h"
#include "adtfile.h"
#define HAVE_WDT_ADT 1
#else
#define HAVE_WDT_ADT 0
#endif

int main(int argc, char** argv)
{
    if (argc < 2)
    {
        std::cout << "Usage: map_bounds_extractor <client-data-path>\n";
        return 1;
    }

    std::string dataPath = argv[1];
    if (dataPath.back() != '/' && dataPath.back() != '\\')
        dataPath += '/';

    std::string mapsRoot = dataPath + "World/Maps/";
    if (!std::filesystem::exists(mapsRoot))
    {
        std::cerr << "Maps root not found: " << mapsRoot << "\n";
        return 2;
    }

    std::ofstream ofs("var/map_bounds.csv");
    if (!ofs)
    {
        std::cerr << "Failed to open var/map_bounds.csv for writing\n";
        return 3;
    }
    ofs << "mapId,minX,maxX,minY,maxY,source\n";

    for (auto const& entry : std::filesystem::directory_iterator(mapsRoot))
    {
        if (!entry.is_directory()) continue;
        std::string mapName = entry.path().filename().string();
        std::string wdtPath = mapsRoot + mapName + "/" + mapName + ".wdt";
        if (!std::filesystem::exists(wdtPath)) continue;

#if HAVE_WDT_ADT
        char wdtC[1024]; strncpy(wdtC, wdtPath.c_str(), sizeof(wdtC)); wdtC[sizeof(wdtC)-1]=0;
        char mapNameC[256]; strncpy(mapNameC, mapName.c_str(), sizeof(mapNameC)); mapNameC[sizeof(mapNameC)-1]=0;
        // Map id lookup is not available here; we output by map name (user may map names to ids manually)
        WDTFile WDT(wdtC, mapNameC);
        if (!WDT.init(0)) // init with 0 as we don't have id mapping here
        {
            std::cerr << "WDT init failed for " << mapName << "\n";
            continue;
        }

        int minTx = INT_MAX, maxTx = INT_MIN, minTy = INT_MAX, maxTy = INT_MIN;
        for (int tx = 0; tx < 64; ++tx)
            for (int ty = 0; ty < 64; ++ty)
            {
                if (ADTFile* ADT = WDT.GetMap(tx, ty))
                {
                    minTx = std::min(minTx, tx);
                    maxTx = std::max(maxTx, tx);
                    minTy = std::min(minTy, ty);
                    maxTy = std::max(maxTy, ty);
                    delete ADT;
                }
            }

        if (minTx <= maxTx && minTy <= maxTy)
        {
            const float TILE = 533.3333333f;
            float minX = minTx * TILE;
            float maxX = (maxTx + 1) * TILE;
            float minY = minTy * TILE;
            float maxY = (maxTy + 1) * TILE;
            ofs << "0," << minX << "," << maxX << "," << minY << "," << maxY << ",wdt\n";
            std::cout << "Map " << mapName << " -> bounds: " << minX <<","<<maxX<<","<<minY<<","<<maxY<<"\n";
        }
#else
        std::cerr << "Extractor was built without WDT/ADT support; rebuild with tool headers available.\n";
#endif
    }

    ofs.close();
    std::cout << "Wrote var/map_bounds.csv\n";
    return 0;
}
