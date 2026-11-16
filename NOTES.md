# DealerDesk delivery notes

This document is kept to at most two pages (BRIEF). It grows as the work is delivered. The
specs and plans are in the workspace repository, under `specs/`.

## Rollback risk (v2.4)

v2.4 adds a trailing field to two data files: the fleet flag (6th field of
`customers.dat`) and the fleet discount (12th field of `invoices.dat`).

- The previous binary (`dealerdesk.old`, v2.3) **reads** v2.4 files correctly and shows
  correct totals. `make test-compat` checks this.
- Its **first save** (any add, reserve or sale) rewrites the files in the v2.3 format, so
  every fleet flag and every invoice fleet amount is silently lost (assumption E-05).
- Mitigation: back up `data/` before deploying (see the 2.4 section in `RELEASE.txt`).
  After a rollback, restore that backup before re-deploying 2.4, or re-flag the fleet
  customers through Customers > 4.
