#!/bin/sh
# mutation.sh - prove the suite catches a wrong pricing constant (spec 001, SC-004).
#
# Copies the project (sources, Makefile, data, tests) to a temp dir, checks the
# unmodified copy passes, changes the VAT rate in the copy's calc.c from 0.20 to
# 0.21 and runs `make test` again. Passes only if that second run FAILS.
# The working tree is never modified.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dealerdesk-mut.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cd "$ROOT" || exit 2
cp ./*.c ./*.h Makefile "$tmp"/ && cp -R data tests "$tmp"/ || exit 2
rm -f "$tmp/tests/unit/test_calc"

if ! make -C "$tmp" --no-print-directory test > "$tmp/clean.log" 2>&1; then
    cat "$tmp/clean.log"
    echo "mutation: the UNMODIFIED copy already fails; fix that first"
    exit 1
fi

sed 's/(q->net + q->delivery) \* 0\.20)/(q->net + q->delivery) * 0.21)/' calc.c > "$tmp/calc.c"
if cmp -s calc.c "$tmp/calc.c"; then
    echo "mutation: VAT constant not found in calc.c; update tests/mutation.sh"
    exit 1
fi

if make -C "$tmp" --no-print-directory test > "$tmp/mutant.log" 2>&1; then
    cat "$tmp/mutant.log"
    echo "mutation: SURVIVED - the suite passed with VAT at 21%"
    exit 1
fi
grep -E '^(unit|e2e):' "$tmp/mutant.log"
echo "mutation: killed - the suite fails when VAT is 21% (as it should)"
exit 0
