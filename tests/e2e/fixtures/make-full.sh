#!/bin/sh
# make-full.sh DIR - write data files with every table at capacity (BR-081):
# 500 vehicles, 500 customers, 2000 invoices, in the formats of docs/architecture.md.
set -e
dir=$1
[ -n "$dir" ] || { echo "usage: make-full.sh DIR" >&2; exit 2; }
mkdir -p "$dir"
awk 'BEGIN { for (i = 0; i < 500; i++)
    printf "%d|FULL %03d|Make|Model %d|2020|10000|5000.00|7500.00|0\n", 1000 + i, i, i }' > "$dir/stock.dat"
awk 'BEGIN { for (i = 0; i < 500; i++)
    printf "%d|Customer %03d|0000 %06d|c%d@example.com|R\n", 2000 + i, i, i, i }' > "$dir/customers.dat"
awk 'BEGIN { for (i = 0; i < 2000; i++)
    printf "%d|2021-01-01|1000|2000|7500.00|0.00|7500.00|1530.00|205.00|0.00|9235.00\n", 50000 + i }' > "$dir/invoices.dat"
printf 'vehicle=1500\ncustomer=2500\ninvoice=52000\n' > "$dir/next_ids.dat"
