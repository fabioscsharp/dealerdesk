#!/bin/sh
# version.sh - the one place the release version comes from (spec 003, FR-002, F-26).
#
#   sh scripts/version.sh              print the version shown in the app header (screen.c)
#   sh scripts/version.sh --check VER  succeed only if VER is the same version
#
# The header line is `DEALERDESK vX.Y`; the version here has no leading "v".
# VER comes from a tag name or a typed workflow input, so it is untrusted text: it is only
# compared and printed with printf %s, never evaluated (F-33).
#
# Exit status: 0 ok; 1 --check failed; 2 usage error or the header cannot be read.

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 2
PATTERN='^[0-9][0-9]*\.[0-9][0-9]*(\.[0-9][0-9]*)?$'

header=$(sed -n 's/.*DEALERDESK v\([0-9][0-9.]*\).*/\1/p' "$ROOT/screen.c" | head -n 1)
if ! printf '%s\n' "$header" | grep -Eq "$PATTERN"; then
    echo "version: cannot read a version like X.Y from the header in screen.c" >&2
    exit 2
fi

case "$1" in
    "")
        printf '%s\n' "$header"
        exit 0
        ;;
    --check)
        if [ $# -ne 2 ]; then
            echo "usage: version.sh [--check VERSION]" >&2
            exit 2
        fi
        ver=$2
        case "$ver" in
            v*)
                printf 'version: "%s" has a leading "v"; use the plain number, for example %s\n' "$ver" "$header" >&2
                exit 1
                ;;
        esac
        if ! printf '%s\n' "$ver" | grep -Eq "$PATTERN"; then
            printf 'version: "%s" is not a version like X.Y or X.Y.Z\n' "$ver" >&2
            exit 1
        fi
        if [ "$ver" != "$header" ]; then
            printf 'version: "%s" does not match the version in the app header (%s)\n' "$ver" "$header" >&2
            exit 1
        fi
        exit 0
        ;;
    *)
        echo "usage: version.sh [--check VERSION]" >&2
        exit 2
        ;;
esac
