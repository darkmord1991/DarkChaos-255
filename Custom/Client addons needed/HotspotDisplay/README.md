This folder contains the HotspotDisplay addon.

Libs/Astrolabe/ contains a local copy of the Astrolabe library (previously in `!Astrolabe`).

If you prefer to use the repository-wide copy, you can remove these files and point your TOC to the shared copy instead.

Original Astrolabe sources can be found at:
Custom/Client addons needed/!Astrolabe/

Configuration
-------------

The addon's saved variables live in `HotspotDisplaySafeDB`. A new option `serverAnnounce` (boolean) controls whether the addon sends a server-visible SAY message when it loads. Default: `false` (the addon will print a local-only message instead). To enable server announcements, set `serverAnnounce = true` in your saved variables or use an in-game SavedVariables editor.
