#!/bin/sh
# run.sh - end-to-end characterization tests for dealerdesk (spec 001).
#
#   sh tests/e2e/run.sh [--update] BINARY
#
# Each directory tests/e2e/scenarios/NN-name/ holds:
#   input           keystrokes fed to the binary on stdin (required)
#   expected.out    golden output, normalised (required)
#   fixture         optional: sample (default, the repo data/), empty, full, or the
#                   name of a committed directory tests/e2e/fixtures/<name>/ (spec 002)
#   expected-data/  optional: golden data/*.dat after the run, normalised;
#                   when absent the data must be byte-identical to the fixture
#
# Every run happens in a fresh temporary directory holding a copy of the fixture,
# so the repository's data/ is never written. Output and data are normalised with
# normalise.sh (ANSI clear-screen, version string, run date) and then compared:
# output with diff, data files byte for byte with cmp.
#
# --update rewrites the goldens from the current binary instead of comparing. It is
# only for new or deliberately re-baselined scenarios and refuses to run unless the
# application sources and sample data equal commit a2ba708 (or FORCE=1 is set).
# SCENARIO=<glob> limits the run to matching scenario directories.

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
BASELINE=a2ba708

update=0
if [ "$1" = "--update" ]; then
    update=1
    shift
fi
[ $# -eq 1 ] || { echo "usage: run.sh [--update] BINARY" >&2; exit 2; }
case $1 in
    /*) BIN=$1 ;;
    *)  BIN=$(pwd)/$1 ;;
esac
[ -x "$BIN" ] || { echo "run.sh: binary not found: $BIN (run make first)" >&2; exit 2; }

if [ $update -eq 1 ] && [ "${FORCE:-0}" != 1 ]; then
    if ! git -C "$ROOT" diff --quiet "$BASELINE" -- '*.c' '*.h' data 2>/dev/null; then
        echo "run.sh --update: sources or data differ from $BASELINE (or no git);" >&2
        echo "goldens must come from the original code. Set FORCE=1 only for a" >&2
        echo "behaviour change a spec has approved, and review the diff." >&2
        exit 2
    fi
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dealerdesk-e2e.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# make_fixture NAME DIR: fill DIR (a data directory) with the named fixture
make_fixture() {
    mkdir -p "$2"
    case $1 in
        sample) cp "$ROOT"/data/*.dat "$2"/ ;;
        empty)  : ;;
        full)   sh "$HERE/fixtures/make-full.sh" "$2" ;;
        *)      if [ -n "$1" ] && [ -d "$HERE/fixtures/$1" ]; then
                    cp "$HERE/fixtures/$1"/*.dat "$2"/
                else
                    echo "unknown fixture: $1" >&2; return 1
                fi ;;
    esac
}

# normalise_dir SRC DST d1 d2: normalised copy of every file in SRC
normalise_dir() {
    mkdir -p "$2"
    for f in "$1"/* ; do
        [ -f "$f" ] || continue
        sh "$HERE/normalise.sh" "$3" "$4" < "$f" > "$2/$(basename "$f")"
    done
}

# same_dir A B: same file names and byte-identical contents; prints differences
same_dir() {
    sd=0
    la=$(cd "$1" && ls -A)
    lb=$(cd "$2" && ls -A)
    if [ "$la" != "$lb" ]; then
        echo "    data files differ: expected [$(echo $la)] got [$(echo $lb)]"
        sd=1
    fi
    for f in $la; do
        [ -f "$2/$f" ] || continue
        if ! cmp -s "$1/$f" "$2/$f"; then
            echo "    data/$f differs from golden:"
            diff -u "$1/$f" "$2/$f" | sed 's/^/      /' | head -40
            sd=1
        fi
    done
    return $sd
}

pass=0
fail=0
failed_names=

for dir in "$HERE"/scenarios/${SCENARIO:-*}/ ; do
    dir=${dir%/}
    [ -f "$dir/input" ] || continue
    name=$(basename "$dir")
    fixture=sample
    [ -f "$dir/fixture" ] && fixture=$(head -n 1 "$dir/fixture" | tr -cd 'a-z0-9-')

    rm -rf "$tmp"/*
    make_fixture "$fixture" "$tmp/run/data" || exit 2
    make_fixture "$fixture" "$tmp/ref" || exit 2

    d1=$(date +%Y-%m-%d)
    (cd "$tmp/run" && "$BIN" < "$dir/input" > "$tmp/actual.raw" 2>&1)
    status=$?
    d2=$(date +%Y-%m-%d)
    echo "[exit status: $status]" >> "$tmp/actual.raw"

    sh "$HERE/normalise.sh" "$d1" "$d2" < "$tmp/actual.raw" > "$tmp/actual.out"
    normalise_dir "$tmp/run/data" "$tmp/actual-data" "$d1" "$d2"
    normalise_dir "$tmp/ref" "$tmp/ref-data" "$d1" "$d2"

    if [ $update -eq 1 ]; then
        cp "$tmp/actual.out" "$dir/expected.out"
        rm -rf "$dir/expected-data"
        if ! same_dir "$tmp/ref-data" "$tmp/actual-data" > /dev/null; then
            cp -R "$tmp/actual-data" "$dir/expected-data"
            echo "UPDATED $name (output + data)"
        else
            echo "UPDATED $name (output, data unchanged)"
        fi
        continue
    fi

    ok=0
    {
        if [ ! -f "$dir/expected.out" ]; then
            echo "    no expected.out (run make golden SCENARIO=$name)"
            ok=1
        elif ! diff -u "$dir/expected.out" "$tmp/actual.out" > "$tmp/out.diff"; then
            echo "    output differs from golden:"
            sed 's/^/      /' "$tmp/out.diff" | head -60
            ok=1
        fi
        if [ -d "$dir/expected-data" ]; then
            same_dir "$dir/expected-data" "$tmp/actual-data" || ok=1
        else
            same_dir "$tmp/ref-data" "$tmp/actual-data" || ok=1
        fi
    } > "$tmp/report"

    if [ $ok -eq 0 ]; then
        echo "PASS $name"
        pass=$((pass + 1))
    else
        echo "FAIL $name"
        cat "$tmp/report"
        fail=$((fail + 1))
        failed_names="$failed_names $name"
    fi
done

[ $update -eq 1 ] && exit 0
echo "e2e: $pass passed, $fail failed"
[ $fail -eq 0 ] || { echo "failed:$failed_names"; exit 1; }
[ $pass -gt 0 ] || { echo "e2e: no scenarios matched"; exit 1; }
exit 0
