#!/bin/sh
# compat.sh - the previous release can still READ files written by v2.4
# (spec 002, US3 #4, E-05). Builds the a2ba708 sources from git history, runs
# that binary on the data written by scenario 26 (a fleet sale) and checks it
# lists and views the fleet invoice with the right total and exits normally.
# Not part of `make test` because it needs git history.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OLD=a2ba708
GOLD="$ROOT/tests/e2e/scenarios/26-fleet-sell-invoice/expected-data"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dealerdesk-compat.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

if ! git -C "$ROOT" archive "$OLD" -- '*.c' '*.h' | tar -x -C "$tmp"; then
    echo "compat: cannot read commit $OLD from git history" >&2
    exit 2
fi
(cd "$tmp" && ${CC:-cc} -o old *.c -lm) || { echo "compat: old build failed" >&2; exit 2; }

mkdir -p "$tmp/run/data"
for f in "$GOLD"/*.dat; do
    sed 's/<TODAY>/2026-01-01/g' "$f" > "$tmp/run/data/$(basename "$f")"
done

printf '5\n1\n\n2\n50233\n\n0\n0\n' > "$tmp/input"
(cd "$tmp/run" && ../old < ../input > ../out 2>&1)
status=$?

fail=0
[ $status -eq 0 ] || { echo "compat: old binary exited with $status"; fail=1; }
grep -q '^  50233 ' "$tmp/out" || { echo "compat: invoice 50233 missing from old list"; fail=1; }
grep -q 'TOTAL  *12325\.24' "$tmp/out" || { echo "compat: old view does not show TOTAL 12325.24"; fail=1; }
grep -q 'Greenway Taxis' "$tmp/out" || { echo "compat: customer row misread by old binary"; fail=1; }
if [ $fail -ne 0 ]; then
    sed 's/\x1b\[2J\x1b\[H//g' "$tmp/out"
    exit 1
fi
echo "compat: $OLD binary reads v2.4 data (fleet invoice 50233, TOTAL 12325.24): OK"
echo "compat: note - its next save would drop customers field 6 and invoices field 12 (E-05)"
exit 0
