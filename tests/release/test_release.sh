#!/bin/sh
# test_release.sh - tests for scripts/version.sh, package.sh and release-notes.sh
# (spec 003, contracts/scripts.md "test_release.sh cases").
#
#   sh tests/release/test_release.sh      (or: make test-release)
#
# Works in temporary directories and leaves the repository as it found it. The packaging
# cases need the zip command: where it is missing they are SKIPPED, except when CI=true
# (GitHub Actions), where a missing zip is a failure so nothing is skipped silently.
ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 2
cd "$ROOT" || exit 2
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dealerdesk-rel.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

pass=0
fail=0
skip=0
ok()   { pass=$((pass + 1)); echo "  ok   $1"; }
bad()  { fail=$((fail + 1)); echo "  FAIL $1"; }
skipped() { skip=$((skip + 1)); echo "  skip $1"; }

HEADER=$(sed -n 's/.*DEALERDESK v\([0-9][0-9.]*\).*/\1/p' screen.c | head -n 1)
before=$(git status --porcelain)

echo "release scripts (header version: $HEADER)"

# 1. version.sh prints the number in screen.c
if [ -n "$HEADER" ] && [ "$(sh scripts/version.sh)" = "$HEADER" ]; then
    ok "1 version.sh prints the header version"
else
    bad "1 version.sh prints the header version"
fi

# 2. --check accepts the same number and rejects the others
good=1
sh scripts/version.sh --check "$HEADER" > /dev/null 2>&1 || good=0
for v in "99.99" "v$HEADER" "abc" "" "$HEADER; echo pwned" "$HEADER.9.9"; do
    if sh scripts/version.sh --check "$v" > /dev/null 2>&1; then
        good=0
        echo "       wrongly accepted: [$v]"
    fi
done
if [ $good -eq 1 ]; then
    ok "2 --check accepts the header version and rejects 99.99, v$HEADER, abc, empty, injected text"
else
    bad "2 --check accepts the header version and rejects the others"
fi

# 3 and 4 need zip only for the success path
have_zip=1
command -v zip > /dev/null 2>&1 || have_zip=0

# 3. package.sh creates the zip with exactly the expected entries and a verifying checksum
if [ $have_zip -eq 0 ] && [ "$CI" != "true" ]; then
    skipped "3 package.sh builds the zip and checksum (zip is not installed; runs in CI)"
elif [ $have_zip -eq 0 ]; then
    bad "3 package.sh builds the zip and checksum (zip is not installed, but CI must have it)"
else
    out="$tmp/dist"
    if DIST_DIR="$out" sh scripts/package.sh "$HEADER" > "$tmp/package.log" 2>&1; then
        want="dealerdesk-$HEADER/data/customers.dat
dealerdesk-$HEADER/data/invoices.dat
dealerdesk-$HEADER/data/next_ids.dat
dealerdesk-$HEADER/data/stock.dat
dealerdesk-$HEADER/dealerdesk"
        got=$(zip -sf "$out/dealerdesk-$HEADER.zip" | sed -n 's/^  //p' | sort)
        if [ "$got" = "$want" ] && (cd "$out" && sha256sum -c "dealerdesk-$HEADER.zip.sha256" > /dev/null 2>&1); then
            ok "3 package.sh builds the zip with the expected entries and a verifying checksum"
        else
            bad "3 package.sh zip entries or checksum are wrong"
            echo "$got" | sed 's/^/       got: /'
        fi
    else
        bad "3 package.sh failed"
        sed 's/^/       /' "$tmp/package.log"
    fi
fi

# 4. package.sh fails on a version mismatch and writes nothing
if DIST_DIR="$tmp/dist4" sh scripts/package.sh "99.99" > /dev/null 2>&1; then
    bad "4 package.sh refuses a version that does not match the header"
elif [ -e "$tmp/dist4" ]; then
    bad "4 package.sh refused but still created output"
else
    ok "4 package.sh refuses a version that does not match the header and writes nothing"
fi

# 5. release-notes.sh: content, and failure when the markers are missing
notes=$(sh scripts/release-notes.sh "$HEADER" 2>&1)
good=1
for want in "# DealerDesk $HEADER" "back up the data" "Rollback warning" "dealerdesk.old" "dealerdesk-$HEADER.zip.sha256"; do
    printf '%s\n' "$notes" | grep -q "$want" || { good=0; echo "       notes lack: $want"; }
done
sed '/notes:begin/d' RELEASING.md > "$tmp/no-begin.md"
sed '/notes:end/d' RELEASING.md > "$tmp/no-end.md"
for f in "$tmp/no-begin.md" "$tmp/no-end.md"; do
    if RELEASING_FILE="$f" sh scripts/release-notes.sh "$HEADER" > /dev/null 2>&1; then
        good=0
        echo "       accepted a file with a missing marker: $f"
    fi
done
if [ $good -eq 1 ]; then
    ok "5 release-notes.sh prints the backup step and rollback warning, and fails without the markers"
else
    bad "5 release-notes.sh content or marker check"
fi

# 6. the working tree is as it was
after=$(git status --porcelain)
if [ "$before" = "$after" ]; then
    ok "6 git status is the same before and after"
else
    bad "6 git status is the same before and after"
fi

echo "release: $pass passed, $fail failed, $skip skipped"
[ $fail -eq 0 ]
