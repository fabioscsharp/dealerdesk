# DealerDesk delivery notes

 The agent setup (`CLAUDE.md`, the constitution, the specs and the
spec-kit skills) is in the companion repository `fabioscsharp/workspace`, which holds this
repository as a submodule: clone it with `--recursive`. Every decision below has an ID in
`assumptions.md`.

I used spec-kit (Spec Driven Development) to organize the workflow for this challenge.

## What I changed, and why in this order

1. **Tests first (spec 001).** A `Makefile` and a characterization suite: 40 unit cases on
   `calc_quote`/`rnd2` and 29 end-to-end scenarios that drive the real binary through stdin on
   a temporary data copy, with output and data files compared byte for byte. Why first: "unchanged  
   to the penny" can only be proved with tests taken from  the old code, and every other change 
   depends on it.
2. **TICKET-142 through that suite (spec 002).** Fleet customers get 4% off the vehicle price,
   fees excluded, as its own line. Two trailing fields (`customers.dat` 6th, `invoices.dat`
   12th), so old files load unchanged. Shipped as v2.4; the 10 existing goldens that changed
   were checked to differ only by the approved menu line.
3. **CI and release (spec 003).** `scripts/check.sh` is the one list of checks; `ci.yml` runs it
   with gcc and clang, and `build-and-test` is the required check on `master`. `release.yml` 
   builds a versioned zip (binary and sample data) with a SHA256 file. Release `2.4` was made
   with it from the existing tag, after confirming the application and data on `master` equal
   the tag. The first run was refused (an empty Release "V 2.4" already existed, which I deleted);
   the next one stalled in GitHub's queue, and a retry published the zip, the checksum and the notes.


## How I worked with the agent

Claude Code with spec-kit: constitution, a baseline spec reverse-engineered from the code, then
specify, clarify, plan, tasks, analyze, implement for each change. Rules live in `CLAUDE.md`.
Where it got things wrong:

- **AI used the claude.md to hold architecture** and requirements related to the application when it should only hold agent's guidance
- **First CI plan ignored the rules.** It proposed fixing README and `RELEASE.txt` (the docs are
  append-only) and a Windows and file-server deploy that spec 003 puts out of scope. I caught
  it by checking the plan against the spec, and it was re-planned.
- **A pull request was opened by mistake against the original repository** (based on a link generated 
  by the agen) and was closed within minutes, with a comment.

## Assumptions (full list in `assumptions.md`)

- Code and data beat the docs: the README, help text and `RELEASE.txt` disagree with the code (B-01 to B-11).
- Fleet pricing: 4% of the list price after the trade discount, outside the 15% salesman cap
  (D-01 to D-05). A rollback to the old binary silently drops fleet data on its first save (E-05).
- v2.4 is the fleet release, so the header changes from v2.3 (B-06).
- The supported platform is Linux, so the released binary is Linux only (F-02, F-24). The
  Borland release process is out of reach.
- The version has one source, the header in `screen.c` (F-26). The existing `2.4` tag is used as is (F-32).

## What I would do next

- A **Windows build** (F-31): a smoke-tested MinGW build first, then CRLF-aware goldens, then
  parity with the Borland release, which needs the old binary or a pilot showroom.
- Prove the tag-push path and "a manual run creates a new tag" at the next real version (F-28, F-32).
- Pin the actions to commit SHAs, and stop admins bypassing the required check.
- Cover the orphan-invoice fallbacks (F-20), and automate the showroom notification.

## Rollback risk (v2.4)

The previous binary (`dealerdesk.old`, v2.3) reads v2.4 files correctly (`make test-compat`), but
its **first save** rewrites them in the old format and silently drops every fleet flag and every
invoice fleet amount (E-05). Back up `data/` before deploying (`RELEASE.txt`, `RELEASING.md`);
after a rollback restore that backup, or re-flag fleet customers through Customers, then 4. Easy to mitigate with 
AI assitance.
