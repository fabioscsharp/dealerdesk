# Assumptions

Everything we are assuming about DealerDesk's implementation and rules that is **not
explicit**, or that **raised a question** while reading the code, docs and TICKET-142.

How to use this file

- Add new entries at the end of the relevant section. Never delete an entry.
- Status: `open` (needs an answer), `assumed` (we proceed with it), `confirmed`
  (a stakeholder or the code proves it), `rejected` (replaced, say by what).
- Existing documentation (`README.md`, `BRIEF.md`, `RELEASE.txt`, `TICKET-142.md`) is
  never edited; this file is where disagreements with it are recorded.
- Evidence references are `file:line` at commit `a2ba708` or git commits.

Created 2026-11-15.

---

## A. Source of truth

| ID | Assumption | Evidence / why | Status |
|----|-----------|----------------|--------|
| A-01 | When docs and code disagree, **the code and data files are authoritative**: it is what production runs and what staff see. | BRIEF: "nobody trusts the documentation", staff "rely on this app as it is". | assumed |
| A-02 | The implementation reflects the latest deliberate decisions; git history explains why docs went stale. | Commits `9dc21bb`, `3a46905`, `8ffd2ad`, `a42d118`, `399a544`. | assumed |

## B. Documentation vs code (existing behaviour we preserve)

| ID | Documentation says | Code actually does | Decision | Status |
|----|--------------------|--------------------|----------|--------|
| B-01 | Trade discount 5% (README, help screen `main.c:500`, `calc.c` header comment) | 10% of list, rounded (`calc.c:29`, commit `8ffd2ad "fix"`, invoice 50231 confirms 1349.50 on 13495.00) | Preserve **10%**. Help text and comments are stale. | assumed |
| B-02 | VAT on list price, discounts taken off the VAT-inclusive price (README) | VAT = 20% of `(net + delivery)` after discounts (`calc.c:40`; commits `9dc21bb` accountant, `3a46905`) | Preserve code behaviour. | assumed |
| B-03 | Delivery is VAT exempt (README) | Delivery **is** VATable; only registration is exempt (commit `3a46905 "delivery is vatable"`) | Preserve code behaviour. | assumed |
| B-04 | Salesman discount over 10% needs manager PIN (README, help screen, `calc.c` comment) | PIN removed (commit `a42d118`, 2019). Any value 0-15 is accepted; above 15 is silently clamped to 15, below 0 to 0 (`calc.c:31-34`). | Preserve. The PIN is **not** a rule any more. Do not reintroduce it. | assumed |
| B-05 | Menu 6 "Reports" (monthly sales, margin per vehicle) (README) | Reports removed (commit `399a544 "remove reports nobody uses them"`); main menu has 1-5, 9 (Help), 0. `report.c` in the README build command does not exist. | Reports are out of scope; do not rebuild them. | assumed |
| B-06 | README: version 2.1; RELEASE.txt: "Last release: 2.3 (2021-04-08)" | Screen header prints `v2.3` (`screen.c:18`) | Treat **2.3** as the current version. A fleet release will be a new version number; the number is not decided. | open |
| B-07 | Data read from `C:\DEALERDESK\DATA` (README, `dbfile.c` header comment) | `DATA_DIR "data/"`, relative to the working directory (`dbfile.c:13`, commit `c06ceb2`) | Preserve; always run from repo root. | assumed |
| B-08 | `main.c` note: plates are stored upper case with no spaces | Not true since commit `76169d5` (cherished plates). Sample data contains `yf20 hbn`, `ma17 zzt`, `hn69 aab`. `find_plate` uses case-sensitive `strcmp`, so searching `YF20 HBN` finds nothing. | Preserve as-is. Out of scope, flagged as a latent defect. | assumed |
| B-09 | Help screen: "Quotes are valid for 7 days"; quote header says the same | Nothing stores or checks a quote date; quotes are never saved. It is display text only. | Do not implement expiry. | assumed |
| B-10 | Build command `gcc -o dealerdesk main.c dbfile.c screen.c report.c` (README "BUILD") | `calc.c` is required and `report.c` does not exist; the QUICK START `gcc -o dealerdesk *.c -lm` works (`-lm` needed for `floor`). | Use `gcc ... *.c -lm`. | assumed |
| B-11 | README says Windows releases use the Borland compiler on "the old build PC" | Not available to us; we build with gcc/clang on Linux/macOS/WSL. | Avoid constructs a Borland-era compiler would reject if cheap, but this is not verifiable. | open |

## C. Implementation behaviour we observed (not documented anywhere)

| ID | Observation | Consequence |
|----|-------------|-------------|
| C-01 | `net` is not rounded; `list - trade_disc - disc` is a difference of two-decimal values, so it is exact to the cent apart from floating-point noise. `vat` and `total` are computed from unrounded `net`. Printing uses `%.2f`. | Fleet code must follow the same pattern (round each discount with `rnd2`, leave `net` unrounded) to stay consistent. |
| C-02 | `rnd2` rounds half **up** using `floor(x*100+0.5)/100` on binary doubles, so values like `x.xx5` can round either way because of representation. | Tests must pin expected cents from the existing implementation, not from decimal theory. |
| C-03 | Quotes and invoice previews are computed live from the **current** vehicle price and customer type. Only confirmed sales are stored. | Changing a customer to fleet affects future quotes only; existing invoices are never recalculated. |
| C-04 | The invoice stores `disc` as trade + salesman discounts **combined** and `fees` as delivery + registration combined. The salesman percentage and customer type are not stored. | Invoices cannot reconstruct which discount produced which amount. Showing "Fleet discount" as its own line on an **invoice** requires new stored data (see D-07). |
| C-05 | `view_invoice` prints "Discounts" (one line), "Fees", then "VAT" (different order from the quote, where delivery, VAT, registration are listed separately). | "Same way the trade discount does" is ambiguous on invoices because trade discount has **no** own line on an invoice today (see D-06). |
| C-06 | `view_invoice` takes the **last** matching invoice number; invoice numbers are unique in practice because of the counter. | No action. |
| C-07 | Customer type is any char; the loader keeps `t[0]`, a missing type defaults to `R`; only `T` is treated as trade, everything else displays as "Retail". | An unknown type value written by a new binary shows as Retail in the old one. |
| C-08 | Loaders ignore extra trailing fields and treat missing ones as 0/default (`strtok` + ternaries). Lines starting with `#` and blank lines are skipped. | Appending a field to a record is safe for both new and old binaries (see E-01). |
| C-09 | `read_line` replaces `|` in any input with `/`. | Names can never break the file format. |
| C-10 | Tables hold 500 vehicles, 500 customers, 2000 invoices; reaching a limit prints "file is full". Loading silently stops at the limit. | Out of scope. Flagged only. |
| C-11 | `save_*` report a write error but the app keeps running and the in-memory state diverges from disk. | Out of scope. Flagged only. |
| C-12 | `find_plate` reads into a 16-byte buffer; plates are 11 characters max. There is no input validation on year, mileage or money (`atoi`/`atof` yield 0 for text). `trade-in` is not validated (can be negative or larger than the price). | Behaviour preserved; do not "fix" silently. |
| C-13 | Sample `data/` is committed. Manual use modifies it; `git checkout -- data` restores it. A test harness must work on a copy so it never dirties the committed data. | Test design (spec 001). |
| C-14 | Invoice 50232 (Greenway Taxis, 2021-03-29, Fiesta 10495.00) has `disc` 839.60 = 8% of 10495.00: a **manual** fleet discount typed into the salesman discount field, as the ticket describes. It is retail customer 2008. | Historic; we never rewrite old invoices. Useful as a regression example. |
| C-15 | The `next_ids.dat` format is `key=value` lines read with `sscanf`; unknown keys are ignored. | No change needed for fleet. |
| C-16 | **Corrects C-08.** `strtok` treats a run of `|` as one separator, so an **empty field is skipped, not loaded as blank**, and every later field shifts one position left. Only *trailing* missing fields fall back to defaults. `add_customer` (`main.c:242-245`) accepts an empty phone and/or email, and `save_customers` (`dbfile.c:192-195`) writes them as `||`. Example: `2009|Acme||a@x|T` reloads as phone `a@x`, email `T`, type missing → `R`. **A trade customer saved with an empty phone or email silently becomes retail on the next start and loses the 10% trade discount.** Sample data has no such row. (From the C standard's definition of `strtok`; not executed, as no compiler was available when this was written.) | Existing latent defect. Fixing the loader changes how such rows load today, which is a behaviour change, so it needs a decision (E-04). Appending a field is only safe when no earlier field is empty. |
| C-17 | **Qualifies C-14.** Saying 50232's 8% was a *manual fleet discount* is an inference from the customer name and the ticket; the data does not record why the discount was given. It is also **double** the 4% the ticket asks for. | Treat it as assumed, not fact. Ask Sales whether Greenway's current deals rely on 8%, because moving to an automatic 4% would change their price. |
| C-18 | Input validation differs per screen: `add_vehicle` requires a plate and a price above 0 (`main.c:101`); `add_customer` requires only a name (`main.c:247`). Phone and email can be empty, which is the trigger for C-16. | Behaviour preserved; relevant to C-16 and E-04. |
| C-19 | `find_plate` (`main.c:124`) matches the **whole** plate exactly with `strcmp`: case-sensitive and spacing-sensitive, with no partial match. This adds to B-08. | Out of scope. Flagged only. |

## D. TICKET-142 (fleet discount): ambiguities and chosen defaults

| ID | Question | Default we proceed with | Status |
|----|----------|-------------------------|--------|
| D-01 | "4% off the vehicle price": of **list price**, or of price after trade discount? | 4% of the **list price** (the "vehicle price"), `rnd2(list * 0.04)`. The ticket says "vehicle price" and the code calls it `list`. | open |
| D-02 | Can a customer be both **trade and fleet**? Do the discounts stack? | Allowed (independent flag); both apply, each computed on list price. Needs a business answer; current data has no such customer. | open |
| D-03 | Order relative to the salesman discount: is the salesman % computed on `list - trade` (today) or on `list - trade - fleet`? | Salesman % applies to `list - trade_disc - fleet_disc`, so the fleet discount does not leave the salesperson with more than the 15% cap implies. This is the "discount the salesperson has left to negotiate" the ticket mentions, so fleet is applied first. | rejected (rationale replaced by D-16) |
| D-04 | Does the fleet discount appear when the customer is fleet but the salesperson enters 0%? | Yes, always automatic: a line "Fleet discount" shows whenever the customer is fleet and the amount is greater than 0. | assumed |
| D-05 | Is the fleet discount capped, or limited by the 15% salesman cap? | Not part of the 15% cap; the cap applies to the manually typed percentage only. | open |
| D-06 | "Its own line on quotes and invoices, **the same way the trade discount does**": on quotes the trade discount has its own line; on **invoices** it does not (only a combined "Discounts" line). | Quotes: add "Fleet discount" line directly after the "Trade discount" line, before the salesman discount line (same format, negative amount). Invoices: add a "Fleet discount" line **only for invoices that have a fleet discount**; other invoices print exactly as today. | open |
| D-07 | How is the fleet amount stored on the invoice? | New trailing field `fleet_disc` (12th) in `invoices.dat`; `disc` stays the **total of all discounts** (trade + fleet + salesman) so `list - disc = net` still holds for every invoice and old binaries still read correct totals. The invoice view prints "Discounts" = `disc - fleet_disc` and "Fleet discount" = `fleet_disc`. Old rows load with 0. | open |
| D-08 | How is "fleet" stored on the customer? | New trailing field (6th) in `customers.dat`: `1` = fleet, absent or `0` = not fleet. A separate flag rather than a new type character `F`, so type `R`/`T` keeps working and old binaries ignore the flag. | open (safe only once E-04 is decided) |
| D-09 | How do staff mark **existing** customers (Greenway Taxis) as fleet? There is no edit-customer screen. | Add one menu action in the Customers menu ("Set fleet status", by customer ID; toggles with Y/N). We do **not** edit `data/customers.dat` to flag Greenway; the flag is set through the app. | open |
| D-10 | Customer list and quote header show "Trade"/"Retail" only. | Show a fleet marker next to the type (e.g. "Retail, Fleet") **only** for fleet customers; unchanged for others. Exact wording to be confirmed. | open |
| D-11 | Is the fleet price in "Net price", i.e. does VAT apply after it? | Yes: `net = list - trade - fleet - disc` and VAT is `(net + delivery) * 20%`, consistent with every other discount (B-02). | assumed |
| D-12 | Do fees stay undiscounted? | Yes, delivery 150.00 and registration 55.00 are unchanged for fleet customers (ticket point 2). | confirmed |
| D-13 | Fleet status on existing invoices / retroactive discounts. | None. Past invoices are not changed, and old invoices still print as today. | assumed |
| D-14 | Does the customer **type** cleanup apply (e.g. should Greenway Taxis become Trade)? | No, fleet is orthogonal to R/T. | assumed |
| D-15 | Who may flag a customer as fleet (permissions)? | Any user of the app, as with every other action (there is no login). | assumed |
| D-16 | **Replaces D-03's rationale.** Order of fleet vs salesman discount. The ticket's complaint is that the hand-typed fleet discount "uses up the discount the salesperson has left to negotiate": fleet must **not** consume the salesperson's 0-15% room. Either order meets that, because the salesman % is entered on its own and is capped independently (D-05). What the order changes is only the base the salesman % is applied to: `list - trade` (salesman discount slightly larger) or `list - trade - fleet` (slightly smaller). | Default: salesman % on `list - trade_disc - fleet_disc`, i.e. each discount applies to the price after the previous one, as trade → salesman does today. Needs a business answer. | open |
| D-17 | Mixed bases: D-01/D-02 take fleet as a % of the **list price** (even for a trade customer), but D-16 applies the salesman % **after** trade and fleet. That means fleet does not compound on trade, yet the salesman % compounds on both. | Ask together with D-01 and D-02: "fleet on list, or after trade?" and "salesman % after fleet, or not?". The answers decide the cents, so the tests must use whatever is agreed. | open |

## E. Data file compatibility

| ID | Assumption | Status |
|----|-----------|--------|
| E-01 | New fields are **appended** (`customers.dat` field 6, `invoices.dat` field 12). New binary reads old files (missing field = default); old binary (`dealerdesk.old` rollback) reads new files and ignores the extra field. A rolled-back binary would show a fleet invoice's `disc` correctly (it is the total) but without the separate fleet line. | rejected (replaced by E-04, E-05) |
| E-02 | Records written by the new binary always contain all fields, including for non-fleet customers (`...|R|0`, `...|0.00`). Writing the extra field for everyone means re-saving rewrites existing lines with the added field the first time any save happens. We accept this: the old binary still reads them. If "files must stay byte-identical until a fleet record exists" is required, the writer can emit the new field only when it is non-default. | open |
| E-03 | We do not change `stock.dat` or `next_ids.dat`. | assumed |
| E-04 | **Replaces E-01.** Appending fields is safe **only for rows with no empty field before the new one** (C-16). A customer with an empty phone/email and the fleet flag, `2009|Acme||a@x|R|1`, is read by today's loader as phone `a@x`, email `R`, type `1`: shown as Retail, fleet lost. If it were `...|T|0`, the old binary would drop the trade discount. Default: the new loader splits on every `|`, so empty fields are kept and the flag is read reliably. Consequence: rows that already contain `||` would then load correctly instead of shifted, which is a fix but also a behaviour change (rule 3). No such row exists in the sample data. Alternative: keep `strtok` and refuse empty phone/email on new customers. Needs a decision. | open |
| E-05 | **Adds to E-01: a rollback loses data.** The old binary reads new files, but its first save (any add, reserve or sale) rewrites the whole file with its own format, so every customer's fleet flag and every invoice's `fleet_disc` are **silently dropped**. After rolling back (RELEASE.txt step 6) and then re-deploying, fleet customers must be flagged again, and the fleet line on invoices made before the rollback is gone. `disc` and the totals stay correct. | Document this in the release notes / NOTES.md. Option: back up `data/` before deploying. | open |
| E-06 | **Adds to E-02.** Files are **already** not byte-stable today: any save drops `#` comment lines and blank lines and rewrites every amount with `%.2f`. A "byte-identical until a fleet record exists" requirement could not be met even without the new field. | Compare files by parsed values, not bytes, in tests. | assumed |

## F. Delivery pipeline (spec 001)

| ID | Assumption | Status |
|----|-----------|--------|
| F-01 | "No reliable build" means today there is no `Makefile`; the README gives two inconsistent commands (B-10). We add one build entry point that produces the same binary name `dealerdesk`. | assumed |
| F-02 | Linux/macOS/WSL with gcc or clang is the supported dev and CI environment (README "Quick start"). The Windows/Borland release process is outside our reach and is not changed. | assumed |
| F-03 | Characterization tests drive the real binary through stdin with scripted menu input against a **copy** of `data/` and compare output, since `main.c` has no testable seam and "no change" is the requirement. Pricing in `calc.c` is additionally unit-tested directly. | assumed |
| F-04 | Behavioural "golden" files are generated from the **current** code **before** any change and committed; they define "unchanged to the penny". | assumed |
| F-05 | CI provider: GitHub Actions (suggested by BRIEF, repo is on GitHub). | assumed |
| F-06 | "Release" automation produces a build artifact in CI; copying to `\\fileserver01\apps\dealerdesk\` and e-mailing showrooms stays manual because we have no access to either. | assumed |
| F-07 | Screen output contains ANSI clear-screen sequences (`\033[2J\033[H` in `cls`). Tests normalise or strip these. | assumed |
| F-08 | `NOTES.md` (max two pages, required by BRIEF) is created in the dealerdesk repo at the end; it is a new file, not an edit of existing docs. | assumed |
| F-09 | The submodule remote was repointed to `fabioscsharp/dealerdesk`; work is committed there and the workspace pointer bumped afterwards. | confirmed |
