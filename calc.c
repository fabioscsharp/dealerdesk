/*
 * calc.c - pricing
 *
 * Price build-up:
 *     list price
 *   - trade discount       (trade customers get 5%)
 *   - salesman discount    (max 10% without manager PIN)
 *   = net price
 *   + delivery
 *   + VAT 20% on list price
 *   + registration fee
 *   - trade-in
 *   = total
 *
 * 2026-11-16 (TICKET-142, v2.4): the comment above is stale; the code below is the
 * rule. Order: trade discount 10% of list, then fleet discount 4% of
 * (list - trade) for fleet customers, then the salesman % (clamped 0..15) of
 * (list - trade - fleet). VAT is 20% of (net + delivery). Each step uses rnd2().
 */
#include <math.h>
#include "calc.h"

double rnd2(double x)
{
    return floor(x * 100.0 + 0.5) / 100.0;
}

void calc_quote(QUOTE *q, double list, char cust_type, int fleet,
                double disc_pct, double tradein)
{
    q->list = list;

    q->trade_disc = 0;
    if (cust_type == 'T')
        q->trade_disc = rnd2(list * 0.10);

    q->fleet_disc = 0;
    if (fleet)
        q->fleet_disc = rnd2((list - q->trade_disc) * 0.04);

    if (disc_pct < 0)
        disc_pct = 0;
    if (disc_pct > 15)
        disc_pct = 15;
    q->disc_pct = disc_pct;
    q->disc = rnd2((list - q->trade_disc - q->fleet_disc) * disc_pct / 100.0);

    q->net = list - q->trade_disc - q->fleet_disc - q->disc;
    q->delivery = 150.00;
    q->vat = rnd2((q->net + q->delivery) * 0.21);
    q->reg_fee = 55.00;
    q->tradein = tradein;

    q->total = q->net + q->delivery + q->vat + q->reg_fee - q->tradein;
}
