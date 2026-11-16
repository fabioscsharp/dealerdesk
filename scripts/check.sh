#!/bin/sh
# check.sh - the full check list, run by CI and by the release (spec 003, FR-001).
#
#   sh scripts/check.sh            run every check, then report
#
# Steps (each one runs even if an earlier one failed):
#   make test          build, unit tests, end-to-end tests
#   make test-mutation a wrong pricing constant must make the suite fail
#   make test-compat   the a2ba708 binary still reads the data written now (needs git history)
#   clean tree         `git status --porcelain` is the same after the checks as before
#
# Honours CC (passed through to make). Exit status 0 only if every step passed.
# Prints "check: ALL PASSED" or "check: FAILED at <step>[, <step>]".

ROOT=$(cd "$(dirname "$0")/.." && pwd) || exit 2
cd "$ROOT" || exit 2

failed=""

fail() {
    failed="$failed${failed:+, }$1"
}

# run <step name> <command...>: run one step and remember it if it fails.
run() {
    name=$1
    shift
    echo "== check: $name"
    "$@" || fail "$name"
}

before=$(git status --porcelain)

run "make test" sh -c 'make clean && make test'
run "make test-mutation" make test-mutation
run "make test-compat" make test-compat

echo "== check: clean tree"
after=$(git status --porcelain)
if [ "$before" != "$after" ]; then
    echo "check: the checks changed or left behind files:"
    printf '%s\n' "--- before" "$before" "--- after" "$after"
    fail "clean tree"
fi

if [ -z "$failed" ]; then
    echo "check: ALL PASSED"
    exit 0
fi
echo "check: FAILED at $failed"
exit 1
