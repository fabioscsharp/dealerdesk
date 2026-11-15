This standard disclaimer states that the work is entirely fictional and any resemblance to real people, places, or events is coincidental.

DEALERDESK v2.1
===============

Dealer management for the showroom: stock, customers, quotes and invoices.


QUICK START (Linux, macOS, or WSL on Windows)
---------------------------------------------

You need a C compiler (gcc or clang). From the repository root:

    gcc -o dealerdesk *.c -lm
    ./dealerdesk

* Always run it from the repository root. It reads and writes the files in ./data
* Pick a menu option by typing its number and pressing ENTER. 0 goes back, and
  0 on the main menu exits.
* Every change (new vehicle, sale, ...) is saved to data/*.dat immediately.
  To put the sample data back:

      git checkout -- data


BUILD
-----

    gcc -o dealerdesk main.c dbfile.c screen.c report.c

(Windows releases are built with the Borland compiler on the old build PC.)


RUN
---

    ./dealerdesk

Data files are read from C:\DEALERDESK\DATA

    stock.dat       vehicles
    customers.dat   customers
    invoices.dat    invoices
    next_ids.dat    id counters

Do NOT edit the .dat files by hand while the program is running!


MENU
----

    1. Stock
    2. Customers
    3. Quote
    4. Sell vehicle
    5. Invoices
    6. Reports (monthly sales, margin per vehicle)
    0. Exit


PRICING RULES
-------------

* VAT (20%) is calculated on the list price. Discounts are then taken off
  the VAT inclusive price.
* Trade customers get a 5% trade discount.
* Salesman discount is up to 10%. Anything above 10% asks for a manager PIN.
* Delivery (150.00) and first registration (55.00) are added to every sale.
  Both are VAT exempt.
* Trade-in value is taken off the final total.


RELEASE
-------

See RELEASE.txt


Problems: ask Phil (ext. 214).


## Build and test (added 2026-11-16)

This section was added later. It supersedes both build commands above. The QUICK START
command still works; the BUILD command (with `report.c`) does not (see assumptions.md B-10).

From the repository root, on Linux, macOS or WSL with gcc or clang and `make`:

    make                # builds ./dealerdesk
    make test           # builds, then runs the unit and end-to-end tests
    make clean          # removes build outputs

`make test` never touches `data/`: every test runs on a temporary copy. See
`tests/README.md` for how the tests work and how to add one.
