#!/bin/sh
# release-notes.sh - print the GitHub Release notes (spec 003, FR-004, F-23).
#
#   sh scripts/release-notes.sh VERSION > notes.md
#
# The body is the block of RELEASING.md between <!-- notes:begin --> and <!-- notes:end -->,
# so the backup step and the rollback warning exist in one place only. RELEASING_FILE can
# point to another file (used by the tests).
#
# Exit status: 0 ok; 1 missing argument, markers or an empty block.

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
FILE=${RELEASING_FILE:-$ROOT/RELEASING.md}

[ $# -eq 1 ] || { echo "usage: release-notes.sh VERSION" >&2; exit 1; }
VER=$1

[ -f "$FILE" ] || { echo "release-notes: $FILE not found" >&2; exit 1; }

block=$(sed -n '/<!-- notes:begin -->/,/<!-- notes:end -->/p' "$FILE" | sed '1d;$d')
if ! grep -q '<!-- notes:begin -->' "$FILE" || ! grep -q '<!-- notes:end -->' "$FILE" || [ -z "$block" ]; then
    echo "release-notes: the notes:begin / notes:end block is missing or empty in $FILE" >&2
    exit 1
fi

printf '# DealerDesk %s\n\n' "$VER"
printf '%s\n\n' "$block"
printf 'Files: `dealerdesk-%s.zip` and its checksum `dealerdesk-%s.zip.sha256`. ' "$VER" "$VER"
printf 'Verify with `sha256sum -c dealerdesk-%s.zip.sha256`.\n' "$VER"
