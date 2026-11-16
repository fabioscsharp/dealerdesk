# DealerDesk tests

Characterization tests: they pin what the app does **today**, "to the penny", so any
unintended change fails. They were generated from the code at commit `a2ba708` and are
defined in the workspace spec `specs/001-build-and-tests/`.

## Running

Run these from the repository root on Linux, macOS or WSL (needs `make`, gcc or clang, and
POSIX tools only):

    make test                      # build, unit tests, end-to-end tests
    make unit                      # pricing unit tests only
    make e2e                       # end-to-end scenarios only
    make e2e SCENARIO='16-*'       # one scenario (shell glob)
    make test-mutation             # proves a wrong VAT constant makes the suite fail
    make test-compat               # the a2ba708 binary still reads v2.4 data (needs git)

The repository's `data/` is never written: every scenario runs on a temporary copy.

## Layout

    tests/unit/test_calc.c         calc_quote() and rnd2() case table (%.2f comparisons)
    tests/e2e/run.sh               scenario runner
    tests/e2e/normalise.sh         output/data normalisation
    tests/e2e/fixtures/make-full.sh  generates tables at capacity (fixture "full")
    tests/e2e/fixtures/fleet/      sample data with 1001/1012 in stock, 2008 and 2002 fleet
    tests/e2e/fixtures/legacy-gaps/  empty-field rows, old 5/11-field rows, odd flag value
    tests/e2e/scenarios/NN-name/   input, expected.out, [fixture], [expected-data/]
    tests/e2e/check-rebaseline.sh  one-off proof that spec 002 re-baselines are approved
    tests/mutation.sh              mutation check used by make test-mutation
    tests/compat.sh                old-binary read check used by make test-compat

## How a scenario works

1. A temporary directory is created. It gets a `data/` copy of the fixture: `sample`
   (the repo `data/`, the default), `empty` (no files), a committed directory
   `tests/e2e/fixtures/<name>/` (`fleet`, `legacy-gaps`), or `full` (500 vehicles, 500
   customers, 2000 invoices).
2. `input` is fed to `dealerdesk` on stdin, running in that directory. stdin is a
   file, so the app always ends (EOF exits with status 0). The exit status is
   appended to the output.
3. The output and every data file are normalised, in this order:
   1. the ANSI clear-screen `ESC[2J ESC[H` is removed;
   2. `DEALERDESK v2.3` becomes `DEALERDESK vX.Y`;
   3. the date(s) of the run become `<TODAY>`.

   Nothing else is changed.
4. The output must equal `expected.out` (shown with `diff -u` if not).
5. The data files must be byte-identical (`cmp`) to `expected-data/`. If that folder is
   absent, they must be byte-identical to the fixture, meaning nothing was written. Extra
   or missing files fail too.

## Adding or changing a scenario

- Create `tests/e2e/scenarios/NN-name/input`, with one answer per line. A "Press
  ENTER" pause needs an empty line. Leave each menu with `0`.
- Add a `fixture` file only if you need `empty` or `full`.
- Generate the golden with `make golden SCENARIO='NN-*'`, then **read** `expected.out`
  against the code before committing. Never hand-edit goldens.
- `make golden` refuses to run when the sources or sample data differ from `a2ba708`.
  Since spec 002 changed the sources, every new or re-baselined scenario needs `FORCE=1`.
  Once a spec has approved a behaviour change (for example 002 fleet discount), use
  `FORCE=1 make golden SCENARIO=...` and review the diff of every regenerated file.
- Add the scenario to the coverage table below.

Unit expectations are regenerated the same way. `tests/unit/test_calc --print` prints
the actual values in table syntax. Paste them, then review.

## Coverage (baseline `specs/000-baseline/spec.md`)

| BR | What | Covered by |
|----|------|------------|
| BR-001 | main menu options, invalid option | 01, 02 (all scenarios use the menu) |
| BR-002 | clear-screen + header on every screen | every scenario (normalised header) |
| BR-010 | list stock / list all vehicles | 05, 09 |
| BR-011 | add vehicle, required fields | 06, 21 |
| BR-012 | find by plate, exact and case-sensitive | 07 |
| BR-013 | change price, ≤ 0 rejected, unknown id | 08 |
| BR-014 | reserve / release, SOLD refused | 09 |
| BR-020 | list customers, Trade/Retail label, `, Fleet` marker | 10, 23, 24, 28 |
| BR-021 | add customer, name required, trade and fleet flags | 11, 24 |
| BR-022 | find customer, case-sensitive substring | 12 |
| BR-023 | no edit/delete customer; Set fleet status (Y, N, other, unknown id) | 10, 23 |
| BR-030 | quote prompts and errors | 13, 14, 15 |
| BR-031 | pricing from current list price | 13, 14 (and 08 changes a price) |
| BR-032 | quote layout, Fleet discount line | 13, 14, 25 |
| BR-033 | sell preview and confirmation, cancel | 16, 17, 18 |
| BR-034 | invoice created, vehicle SOLD, counters, fleet amount stored | 16, 17, 26, 27 (expected-data) |
| BR-040..047 | pricing rules incl. fleet step | unit `test_calc` (40 cases); 13, 14, 16, 17, 25, 27 |
| BR-050 | invoice record format (12 fields) | 16, 17, 26, 27 (expected-data/invoices.dat) |
| BR-051 | list invoices with count | 16, 19 |
| BR-052 | view invoice, not found, fleet invoice lines | 17, 20, 26, 27, 28, 29 |
| BR-060 | help screen (stale text pinned as-is, plus the fleet line) | 04 |
| BR-070 | data in ./data, missing file = empty table, empty fields kept, old rows load | 21, 28; every writing scenario; `make test-compat` |
| BR-080 | single user, no locking | not testable: nothing to assert |
| BR-081 | capacity limits | 22 |
| BR-082 | no tests / manual build | superseded by this suite and the Makefile |

**Known gap:** the `(unknown)` customer and `?` vehicle fallbacks in BR-051 and BR-052
(an invoice whose customer or vehicle no longer exists) are not exercised. The sample
data has no such invoice, and no fixture creates one yet.

Other paths: 03 covers EOF in the middle of a prompt. `make test-mutation` covers SC-004.
Spec 002 (fleet): 23-29, plus re-baselined 02, 04, 10, 11, 12, 16, 17, 21, 22 (checked by
`tests/e2e/check-rebaseline.sh`).
