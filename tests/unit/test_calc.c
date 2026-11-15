/*
 * test_calc.c - characterization tests for calc_quote() and rnd2() (spec 001).
 *
 * Expected values were captured from the unmodified calc.c (commit a2ba708) with
 * `tests/unit/test_calc --print` and are compared as "%.2f" strings: exactly what the
 * app shows on screen and writes to the data files ("to the penny").
 * Do not recompute them by hand; regenerate with --print and review the diff.
 */
#include <stdio.h>
#include <string.h>
#include "calc.h"

#define NFIELDS 10

typedef struct {
    const char *name;
    double list;
    char type;
    double pct;
    double tradein;
    const char *exp[NFIELDS]; /* list trade_disc disc_pct disc net delivery vat reg_fee tradein total */
} CASE;

static const char *field_names[NFIELDS] = {
    "list", "trade_disc", "disc_pct", "disc", "net",
    "delivery", "vat", "reg_fee", "tradein", "total"
};

static CASE cases[] = {
    /* name                        list      type pct    tradein   expected */
    { "inv50230 retail 5% tradein", 9295.00,  'R', 5,     1500.00,
      { "9295.00", "0.00", "5.00", "464.75", "8830.25", "150.00", "1796.05", "55.00", "1500.00", "9331.30" } },
    { "inv50231 trade 0%",          13495.00, 'T', 0,     0,
      { "13495.00", "1349.50", "0.00", "0.00", "12145.50", "150.00", "2459.10", "55.00", "0.00", "14809.60" } },
    { "inv50232 retail 8%",         10495.00, 'R', 8,     0,
      { "10495.00", "0.00", "8.00", "839.60", "9655.40", "150.00", "1961.08", "55.00", "0.00", "11821.48" } },
    { "retail 0%",                  10995.00, 'R', 0,     0,
      { "10995.00", "0.00", "0.00", "0.00", "10995.00", "150.00", "2229.00", "55.00", "0.00", "13429.00" } },
    { "retail 5%",                  10995.00, 'R', 5,     0,
      { "10995.00", "0.00", "5.00", "549.75", "10445.25", "150.00", "2119.05", "55.00", "0.00", "12769.30" } },
    { "retail 10%",                 15995.00, 'R', 10,    0,
      { "15995.00", "0.00", "10.00", "1599.50", "14395.50", "150.00", "2909.10", "55.00", "0.00", "17509.60" } },
    { "retail 15%",                 15995.00, 'R', 15,    0,
      { "15995.00", "0.00", "15.00", "2399.25", "13595.75", "150.00", "2749.15", "55.00", "0.00", "16549.90" } },
    { "retail 15.01% clamps to 15", 15995.00, 'R', 15.01, 0,
      { "15995.00", "0.00", "15.00", "2399.25", "13595.75", "150.00", "2749.15", "55.00", "0.00", "16549.90" } },
    { "retail 40% clamps to 15",    16750.00, 'R', 40,    0,
      { "16750.00", "0.00", "15.00", "2512.50", "14237.50", "150.00", "2877.50", "55.00", "0.00", "17320.00" } },
    { "retail -5% clamps to 0",     16750.00, 'R', -5,    0,
      { "16750.00", "0.00", "0.00", "0.00", "16750.00", "150.00", "3380.00", "55.00", "0.00", "20335.00" } },
    { "retail 7.5% with tradein",   12750.00, 'R', 7.5,   2250.00,
      { "12750.00", "0.00", "7.50", "956.25", "11793.75", "150.00", "2388.75", "55.00", "2250.00", "12137.50" } },
    { "trade 5%",                   25495.00, 'T', 5,     0,
      { "25495.00", "2549.50", "5.00", "1147.28", "21798.22", "150.00", "4389.64", "55.00", "0.00", "26392.86" } },
    { "trade 15% tradein",          22995.00, 'T', 15,    4000.00,
      { "22995.00", "2299.50", "15.00", "3104.33", "17591.17", "150.00", "3548.23", "55.00", "4000.00", "17344.40" } },
    { "trade 20% clamps to 15",     18995.00, 'T', 20,    0,
      /* (18995 - 1899.50) * 15% = 2564.325 exactly on paper, but rnd2 gives 2564.32
         in binary floating point: pinned as the code behaves, not as arithmetic says */
      { "18995.00", "1899.50", "15.00", "2564.32", "14531.18", "150.00", "2936.24", "55.00", "0.00", "17672.42" } },
    { "trade -1% clamps to 0",      9750.00,  'T', -1,    0,
      { "9750.00", "975.00", "0.00", "0.00", "8775.00", "150.00", "1785.00", "55.00", "0.00", "10765.00" } },
    { "type t lower case = retail", 9750.00,  't', 0,     0,
      { "9750.00", "0.00", "0.00", "0.00", "9750.00", "150.00", "1980.00", "55.00", "0.00", "11935.00" } },
    { "trade-in above total",       1000.00,  'R', 0,     5000.00,
      { "1000.00", "0.00", "0.00", "0.00", "1000.00", "150.00", "230.00", "55.00", "5000.00", "-3565.00" } },
    { "list 0",                     0,        'R', 0,     0,
      { "0.00", "0.00", "0.00", "0.00", "0.00", "150.00", "30.00", "55.00", "0.00", "235.00" } },
    { "trade list 0.05 half penny", 0.05,     'T', 0,     0,
      { "0.05", "0.01", "0.00", "0.00", "0.04", "150.00", "30.01", "55.00", "0.00", "235.05" } },
    { "retail odd pennies 3%",      9999.99,  'R', 3,     0.01,
      { "9999.99", "0.00", "3.00", "300.00", "9699.99", "150.00", "1970.00", "55.00", "0.01", "11874.98" } },
    { "very large list",            9999999.99, 'T', 12.5, 0,
      { "9999999.99", "1000000.00", "12.50", "1125000.00", "7874999.99", "150.00", "1575030.00", "55.00", "0.00", "9450234.99" } },
};

typedef struct {
    double in;
    const char *exp;
} RCASE;

static RCASE rcases[] = {
    { 0.125,   "0.13" },
    { 2.675,   "2.68" },
    { 1.005,   "1.00" },
    { 10.045,  "10.05" },
    { 0.004,   "0.00" },
    { 0.005,   "0.01" },
    { 1349.5,  "1349.50" },
    { 464.749, "464.75" },
    { -1.005,  "-1.00" },
};

#define NCASES  ((int)(sizeof cases / sizeof cases[0]))
#define NRCASES ((int)(sizeof rcases / sizeof rcases[0]))

static void fmt_quote(const QUOTE *q, char out[NFIELDS][32])
{
    double v[NFIELDS];
    int i;
    v[0] = q->list; v[1] = q->trade_disc; v[2] = q->disc_pct; v[3] = q->disc;
    v[4] = q->net;  v[5] = q->delivery;   v[6] = q->vat;      v[7] = q->reg_fee;
    v[8] = q->tradein; v[9] = q->total;
    for (i = 0; i < NFIELDS; i++)
        sprintf(out[i], "%.2f", v[i]);
}

int main(int argc, char **argv)
{
    int print = argc > 1 && strcmp(argv[1], "--print") == 0;
    int passed = 0, failed = 0;
    int i, f;
    QUOTE q;
    char got[NFIELDS][32];
    char r[32];

    for (i = 0; i < NCASES; i++) {
        int ok = 1;
        calc_quote(&q, cases[i].list, cases[i].type, cases[i].pct, cases[i].tradein);
        fmt_quote(&q, got);
        if (print) {
            printf("{ \"%s\", ", cases[i].name);
            for (f = 0; f < NFIELDS; f++)
                printf("\"%s\"%s", got[f], f < NFIELDS - 1 ? ", " : " }\n");
            continue;
        }
        for (f = 0; f < NFIELDS; f++) {
            if (strcmp(got[f], cases[i].exp[f]) != 0) {
                printf("FAIL %s: %s expected %s got %s\n",
                       cases[i].name, field_names[f], cases[i].exp[f], got[f]);
                ok = 0;
            }
        }
        if (ok) passed++; else failed++;
    }

    for (i = 0; i < NRCASES; i++) {
        sprintf(r, "%.2f", rnd2(rcases[i].in));
        if (print) {
            printf("rnd2(%.3f) = %s\n", rcases[i].in, r);
            continue;
        }
        if (strcmp(r, rcases[i].exp) != 0) {
            printf("FAIL rnd2(%.3f): expected %s got %s\n", rcases[i].in, rcases[i].exp, r);
            failed++;
        } else {
            passed++;
        }
    }

    if (print)
        return 0;
    printf("unit: %d passed, %d failed\n", passed, failed);
    return failed ? 1 : 0;
}
