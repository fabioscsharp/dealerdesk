#!/bin/sh
# package.sh - build the release package (spec 003, FR-005, F-29).
#
#   sh scripts/package.sh VERSION
#
# Writes, into $DIST_DIR (default: dist/ in the repository root):
#   dealerdesk-VERSION.zip          dealerdesk-VERSION/dealerdesk
#                                   dealerdesk-VERSION/data/{stock,customers,invoices,next_ids}.dat
#   dealerdesk-VERSION.zip.sha256   one line, checkable with `sha256sum -c` from inside DIST_DIR
#
# The data is the committed sample data, unmodified. Refuses to run if VERSION is not the
# version in the app header (scripts/version.sh --check) or if data/ has uncommitted changes.
# Builds with a clean `make`, so CC is honoured. Needs zip and sha256sum (or shasum).
#
# Exit status: 0 ok; 1 any failure.

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 1
cd "$ROOT" || exit 1

[ $# -eq 1 ] || { echo "usage: package.sh VERSION" >&2; exit 1; }
VER=$1

sh scripts/version.sh --check "$VER" || exit 1

if ! git diff --quiet HEAD -- data; then
    echo "package: data/ has uncommitted changes; run 'git checkout -- data' first" >&2
    exit 1
fi

if ! command -v zip > /dev/null 2>&1; then
    echo "package: the zip command is not installed" >&2
    exit 1
fi
if command -v sha256sum > /dev/null 2>&1; then
    SUM="sha256sum"
elif command -v shasum > /dev/null 2>&1; then
    SUM="shasum -a 256"
else
    echo "package: neither sha256sum nor shasum is installed" >&2
    exit 1
fi

DIST=${DIST_DIR:-$ROOT/dist}
NAME="dealerdesk-$VER"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dealerdesk-pkg.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

make clean > /dev/null && make > /dev/null || { echo "package: build failed" >&2; exit 1; }

mkdir -p "$tmp/$NAME/data" "$DIST" || exit 1
cp dealerdesk "$tmp/$NAME/dealerdesk" || exit 1
chmod 755 "$tmp/$NAME/dealerdesk"
for f in stock.dat customers.dat invoices.dat next_ids.dat; do
    cp "data/$f" "$tmp/$NAME/data/$f" || { echo "package: data/$f is missing" >&2; exit 1; }
done

rm -f "$DIST/$NAME.zip" "$DIST/$NAME.zip.sha256"
(
    cd "$tmp" && zip -q -X -D "$DIST/$NAME.zip" \
        "$NAME/dealerdesk" \
        "$NAME/data/stock.dat" \
        "$NAME/data/customers.dat" \
        "$NAME/data/invoices.dat" \
        "$NAME/data/next_ids.dat"
) || { echo "package: zip failed" >&2; exit 1; }

(cd "$DIST" && $SUM "$NAME.zip" > "$NAME.zip.sha256") || { echo "package: checksum failed" >&2; exit 1; }

echo "$DIST/$NAME.zip"
echo "$DIST/$NAME.zip.sha256"
