#!/bin/sh
# Runs the DC addon suite regression tests under a stubbed WoW 3.3.5 API.
# Requires a `lua` interpreter on PATH. Run from this directory.
fail=0
for t in test_compat.lua test_integration.lua test_wishlist.lua test_lazycache.lua test_hubsplit.lua; do
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
