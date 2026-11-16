#!/bin/sh
# check-rebaseline.sh - one-off check for spec 002 (E-07, research R-6).
# For every spec 001 golden that 002 re-baselined, remove the approved additions
# from the new file and require it to equal the file at commit fcff60d byte for byte:
#   - the Customers menu line "  4. Set fleet status"
#   - the Add Customer prompt "  Fleet customer (Y/N)? "
#   - the Help line "  - Fleet customers receive an automatic 4% fleet discount."
#   - a trailing "|0" on customers.dat rows and "|0.00" on invoices.dat rows
# Not part of `make test`.
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BASE=fcff60d
S=tests/e2e/scenarios
FILES="$S/02-invalid-option/expected.out $S/04-help/expected.out
$S/10-customers-list/expected.out $S/11-customer-add/expected.out
$S/12-customer-find/expected.out $S/21-missing-data/expected.out
$S/22-capacity-full/expected.out $S/11-customer-add/expected-data/customers.dat
$S/16-sell-retail/expected-data/invoices.dat $S/17-sell-trade/expected-data/invoices.dat"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dealerdesk-rb.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
cd "$ROOT" || exit 2
bad=0
for f in $FILES; do
    git show "$BASE:$f" > "$tmp/old" 2>/dev/null || { echo "MISSING in $BASE: $f"; bad=1; continue; }
    case $f in
        *customers.dat) sed 's/|0$//' "$f" ;;
        *invoices.dat)  sed 's/|0\.00$//' "$f" ;;
        *) sed -e '/^  4\. Set fleet status$/d' \
               -e 's/  Fleet customer (Y\/N)? //g' \
               -e '/^  - Fleet customers receive an automatic 4% fleet discount\.$/d' "$f" ;;
    esac > "$tmp/new"
    if cmp -s "$tmp/old" "$tmp/new"; then
        echo "OK   $f"
    else
        echo "DIFF $f"
        diff -u "$tmp/old" "$tmp/new" | head -20
        bad=1
    fi
done
[ $bad -eq 0 ] && echo "check-rebaseline: only approved changes" || echo "check-rebaseline: UNAPPROVED changes"
exit $bad
