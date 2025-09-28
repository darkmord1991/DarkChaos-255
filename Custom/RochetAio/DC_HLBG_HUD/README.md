# DC HLBG HUD (AIO)

Client addon skeleton to receive messages from the server via Rochet2/AIO.

## Requirements
- World of Warcraft 3.3.5a (Wrath)
- Rochet2/AIO client addon installed and loaded before this addon

## Install
- Copy the `DC_HLBG_HUD` folder into your WoW `Interface/AddOns/` directory
- Ensure the Rochet2/AIO addon is also installed and enabled

## What it does
- Registers an AIO channel `DC_HLBG_HUD`
- Logs simple messages from the server (HELLO, PING) to chat

## Server setup (summary)
- Install Rochet2/AIO on the server (per its documentation)
- Define `HAS_AIO` in your server build flags and add include directories for `AIO.h`
- Wire the call in `src/server/scripts/DC/AIO/aio_bridge.cpp` to use the real AIO send API

## Verify
- In-game, use `.aio ping` command; you should see a chat line from the addon
