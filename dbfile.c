/*
 * dbfile.c - flat file storage
 *
 * Files live in C:\DEALERDESK\DATA
 * One record per line, fields separated by |
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "globals.h"
#include "dbfile.h"

#define DATA_DIR "data/"

static void cpy(char *d, const char *s, int n)
{
    strncpy(d, s ? s : "", n - 1);
    d[n - 1] = 0;
}

/*
 * next_field - split on every '|', keeping empty fields (TICKET-142, E-04).
 * Returns the field at *p (possibly ""), NUL-terminates it and moves *p past the
 * '|'. Returns NULL once the line is used up, so a missing trailing field reads as
 * NULL and gets its default. strtok() is not used here because it merges "||" and
 * shifts every later field (C-16).
 */
static char *next_field(char **p)
{
    char *f, *bar;

    if (*p == NULL)
        return NULL;
    f = *p;
    bar = strchr(f, '|');
    if (bar) {
        *bar = 0;
        *p = bar + 1;
    } else {
        *p = NULL;
    }
    return f;
}

static void load_stock(void)
{
    FILE *f;
    char line[512];
    char *t;
    VEHICLE *v;

    nveh = 0;
    f = fopen(DATA_DIR "stock.dat", "r");
    if (!f)
        return;
    while (fgets(line, sizeof line, f) && nveh < MAX_VEH) {
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] == 0 || line[0] == '#')
            continue;
        v = &veh[nveh];
        t = strtok(line, "|");
        if (!t)
            continue;
        v->id = atoi(t);
        t = strtok(NULL, "|");
        cpy(v->plate, t, sizeof v->plate);
        t = strtok(NULL, "|");
        cpy(v->make, t, sizeof v->make);
        t = strtok(NULL, "|");
        cpy(v->model, t, sizeof v->model);
        t = strtok(NULL, "|");
        v->year = t ? atoi(t) : 0;
        t = strtok(NULL, "|");
        v->mileage = t ? atol(t) : 0;
        t = strtok(NULL, "|");
        v->cost = t ? atof(t) : 0;
        t = strtok(NULL, "|");
        v->price = t ? atof(t) : 0;
        t = strtok(NULL, "|");
        v->status = t ? atoi(t) : 0;
        nveh++;
    }
    fclose(f);
}

static void load_customers(void)
{
    FILE *f;
    char line[512];
    char *t, *p;
    CUSTOMER *c;

    ncust = 0;
    f = fopen(DATA_DIR "customers.dat", "r");
    if (!f)
        return;
    while (fgets(line, sizeof line, f) && ncust < MAX_CUST) {
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] == 0 || line[0] == '#')
            continue;
        c = &cust[ncust];
        p = line;
        t = next_field(&p);
        c->id = atoi(t);
        t = next_field(&p);
        cpy(c->name, t, sizeof c->name);
        t = next_field(&p);
        cpy(c->phone, t, sizeof c->phone);
        t = next_field(&p);
        cpy(c->email, t, sizeof c->email);
        t = next_field(&p);
        c->type = (t && t[0]) ? t[0] : 'R';
        t = next_field(&p);
        c->fleet = (t && strcmp(t, "1") == 0) ? 1 : 0;
        ncust++;
    }
    fclose(f);
}

static void load_invoices(void)
{
    FILE *f;
    char line[512];
    char *t, *p;
    INVOICE *i;

    ninv = 0;
    f = fopen(DATA_DIR "invoices.dat", "r");
    if (!f)
        return;
    while (fgets(line, sizeof line, f) && ninv < MAX_INV) {
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] == 0 || line[0] == '#')
            continue;
        i = &inv[ninv];
        p = line;
        t = next_field(&p);
        i->no = atoi(t);
        t = next_field(&p);
        cpy(i->date, t, sizeof i->date);
        t = next_field(&p);
        i->veh_id = t ? atoi(t) : 0;
        t = next_field(&p);
        i->cust_id = t ? atoi(t) : 0;
        t = next_field(&p);
        i->list = t ? atof(t) : 0;
        t = next_field(&p);
        i->disc = t ? atof(t) : 0;
        t = next_field(&p);
        i->net = t ? atof(t) : 0;
        t = next_field(&p);
        i->vat = t ? atof(t) : 0;
        t = next_field(&p);
        i->fees = t ? atof(t) : 0;
        t = next_field(&p);
        i->tradein = t ? atof(t) : 0;
        t = next_field(&p);
        i->total = t ? atof(t) : 0;
        t = next_field(&p);
        i->fleet_disc = t ? atof(t) : 0;
        ninv++;
    }
    fclose(f);
}

static void load_ids(void)
{
    FILE *f;
    char line[128];

    f = fopen(DATA_DIR "next_ids.dat", "r");
    if (!f)
        return;
    while (fgets(line, sizeof line, f)) {
        sscanf(line, "vehicle=%d", &next_veh_id);
        sscanf(line, "customer=%d", &next_cust_id);
        sscanf(line, "invoice=%d", &next_inv_no);
    }
    fclose(f);
}

void load_all(void)
{
    load_stock();
    load_customers();
    load_invoices();
    load_ids();
}

void save_stock(void)
{
    FILE *f;
    int i;

    f = fopen(DATA_DIR "stock.dat", "w");
    if (!f) {
        printf("  ERROR: cannot write stock.dat\n");
        return;
    }
    for (i = 0; i < nveh; i++)
        fprintf(f, "%d|%s|%s|%s|%d|%ld|%.2f|%.2f|%d\n",
                veh[i].id, veh[i].plate, veh[i].make, veh[i].model,
                veh[i].year, veh[i].mileage, veh[i].cost, veh[i].price,
                veh[i].status);
    fclose(f);
}

void save_customers(void)
{
    FILE *f;
    int i;

    f = fopen(DATA_DIR "customers.dat", "w");
    if (!f) {
        printf("  ERROR: cannot write customers.dat\n");
        return;
    }
    for (i = 0; i < ncust; i++)
        fprintf(f, "%d|%s|%s|%s|%c|%d\n",
                cust[i].id, cust[i].name, cust[i].phone, cust[i].email,
                cust[i].type, cust[i].fleet);
    fclose(f);
}

void save_invoices(void)
{
    FILE *f;
    int i;

    f = fopen(DATA_DIR "invoices.dat", "w");
    if (!f) {
        printf("  ERROR: cannot write invoices.dat\n");
        return;
    }
    for (i = 0; i < ninv; i++)
        fprintf(f, "%d|%s|%d|%d|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f\n",
                inv[i].no, inv[i].date, inv[i].veh_id, inv[i].cust_id,
                inv[i].list, inv[i].disc, inv[i].net, inv[i].vat,
                inv[i].fees, inv[i].tradein, inv[i].total, inv[i].fleet_disc);
    fclose(f);
}

void save_ids(void)
{
    FILE *f;

    f = fopen(DATA_DIR "next_ids.dat", "w");
    if (!f) {
        printf("  ERROR: cannot write next_ids.dat\n");
        return;
    }
    fprintf(f, "vehicle=%d\ncustomer=%d\ninvoice=%d\n",
            next_veh_id, next_cust_id, next_inv_no);
    fclose(f);
}
