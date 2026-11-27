#!/bin/sh
# Runs the DC addon suite regression tests under a stubbed WoW 3.3.5 API.
# Requires a `lua` interpreter on PATH. Run from this directory.
fail=0
for t in test_compat.lua test_integration.lua test_wishlist.lua test_lazycache.lua test_hubsplit.lua test_petdrag.lua test_minimapqueue.lua test_minimapbuttons.lua test_combatmeter.lua test_collectionlinks.lua test_worldmapdropdowns.lua test_hlbgpresence.lua test_dangerzone.lua test_journalmicrobutton.lua test_bosstracker.lua test_mythicbadge.lua test_mythicforces.lua test_spectatelive.lua test_spectatormap.lua test_greatvault.lua test_characterframe.lua test_groupfinderframe.lua test_leaderboards.lua test_modelanimations.lua test_collectionicons.lua test_housingcatalog.lua test_talents.lua test_talents_pet.lua test_expansionfilter.lua test_nativepush.lua test_collectionwave1.lua test_loginoutfit.lua test_enchantreroll.lua test_path.lua test_videooptions.lua test_videooptions_old.lua test_videooptions_olderexe.lua test_handshakeack.lua test_collectionfavorites.lua test_appearancefavorites.lua test_worldbossstatus.lua test_worldmapzoom.lua test_linkifier.lua test_hlbgchatfallback.lua test_outfitlinks.lua test_gmaddmessage.lua test_bugsackcomm.lua test_groupfinderescape.lua test_vendorplus.lua test_labprobe.lua test_bugreport.lua test_nameplates.lua test_nameplates_old.lua test_chargecooldowns.lua test_chargecooldowns_old.lua test_formskinlist.lua; do
    printf '%-24s ' "$t"
    if out=$(lua "$t" 2>&1); then
        echo "$out" | grep -E '^RESULT'
    else
        echo "FAILED"
        echo "$out" | sed 's/^/    /'
        fail=1
    fi
done
exit $fail
