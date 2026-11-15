#!/bin/sh
# normalise.sh - filter stdin to stdout so golden comparisons are stable (spec 001, R-5).
#
#   sh normalise.sh [RUN_DATE ...] < raw > normalised
#
# In this order:
#   1. remove the ANSI clear-screen sequence ESC[2J ESC[H written by cls()
#   2. DEALERDESK v<major>.<minor>  ->  DEALERDESK vX.Y   (version bump must not break goldens)
#   3. each RUN_DATE (YYYY-MM-DD, the day(s) the binary ran) -> <TODAY>
# Nothing else is rewritten.
esc=$(printf '\033')
script="s/${esc}\[2J${esc}\[H//g; s/DEALERDESK v[0-9][0-9]*\.[0-9][0-9]*/DEALERDESK vX.Y/g"
for d in "$@"; do
    script="$script; s/$d/<TODAY>/g"
done
exec sed "$script"
