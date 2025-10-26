DC-MapExtension Textures - Debug README

Files included:
 - azshara_crater_1024.png  (1024x1024 PNG, preferred if supported)
 - azshara_crater.png       (standard PNG)
 - azshara_crater.blp       (BLP - may not decode on all clients)

If you see a warning "texture exists in Textures folder but failed to load", it means the addon found the file path but the client rejected it when trying to SetTexture. Common causes:
 - The BLP is corrupted or encoded with an unsupported format.
 - The PNG is not power-of-two (non-POT) and the client can't use it for large backgrounds on this UI scale.
 - The file permissions are incorrect (rare for typical addons).

To enable in-game debug diagnostics (so the addon prints which texture was used and the above warnings), add the following saved-variable to your SavedVariables for this addon (e.g., in `WTF/Account/.../SavedVariables/DC-MapExtension.lua`):

DCMapExtensionDB = {
    debug = true,
}

After enabling, reload the UI (/reload) or relog to see the diagnostics printed in your chat frame. Once you've finished debugging, set `debug = false` to silence these messages.
