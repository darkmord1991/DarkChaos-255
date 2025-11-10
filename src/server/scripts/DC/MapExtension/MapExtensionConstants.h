/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * 
 * DarkChaos MapExtension System - Constants
 * 
 * Centralized constants for the GPS tracking system integrated with client addons
 * via AIO (Addon I/O). This system provides real-time player position updates
 * with normalized coordinates for custom zone navigation.
 */

#ifndef MAP_EXTENSION_CONSTANTS_H
#define MAP_EXTENSION_CONSTANTS_H

#include <cstdint>

namespace MapExtensionConstants
{
    // Update timing (in milliseconds)
    constexpr uint32 GPS_UPDATE_INTERVAL_MS = 2000;          // 2 seconds default update rate
    constexpr uint32 ZONE_CHANGE_IMMEDIATE_UPDATE_MS = 100;  // Immediate update on zone change
    
    // Payload limits
    constexpr size_t MAX_GPS_PAYLOAD_BYTES = 512;  // Maximum JSON payload size for AIO
    
    // Security and throttling
    constexpr uint32 MIN_UPDATE_INTERVAL_MS = 500;   // Minimum time between updates (anti-spam)
    constexpr uint32 MAX_UPDATE_INTERVAL_MS = 10000; // Maximum configurable interval
    
    // Default enabled maps for GPS tracking
    // 0 = Eastern Kingdoms, 1 = Kalimdor, 530 = Outland, 571 = Northrend, 37 = Azshara Crater
    constexpr uint32 DEFAULT_ENABLED_MAPS[] = {0, 1, 530, 571, 37};
    constexpr size_t DEFAULT_ENABLED_MAPS_COUNT = sizeof(DEFAULT_ENABLED_MAPS) / sizeof(DEFAULT_ENABLED_MAPS[0]);
    
    // AIO message identifiers
    const char* const AIO_ADDON_NAME = "DCMapGPS";
    const char* const AIO_MSG_UPDATE = "Update";
    const char* const AIO_MSG_ZONE_CHANGE = "ZoneChange";
    const char* const AIO_MSG_ERROR = "Error";
}

#endif // MAP_EXTENSION_CONSTANTS_H
