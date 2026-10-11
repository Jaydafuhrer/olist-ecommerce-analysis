"""Recompute dashboard findings from the included historical reporting snapshots.

Python standard library only. Run from any directory.
"""
import csv
from decimal import Decimal as D, ROUND_HALF_UP
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data/exports'
def rows(name):
    with (DATA / (name + '.csv')).open(newline='', encoding='utf-8-sig') as file:
        return list(csv.DictReader(file))
def total(records, field):
    return sum((D(row[field]) for row in records if row[field] not in ('', 'NULL')), D(0))
def pct(part, whole):
    return part / whole * 100

def calculate():
    monthly = rows('monthly_growth')
    sales = total(monthly, 'merchandise_sales')
    orders = total(monthly, 'delivered_orders')
    periods = [[r for r in monthly if r['purchase_month'].startswith(str(year)) and '01' <= r['purchase_month'][5:7] <= '08'] for year in (2017, 2018)]
    s0, s1 = [total(p, 'merchandise_sales') for p in periods]
    n0, n1 = [total(p, 'delivered_orders') for p in periods]
    full_sales = total(rows('monthly_sales'), 'delivered_merchandise_sales')
    delivery = rows('delivery_priority')
    cohorts = rows('customer_repeat_90d')
    late = total(delivery, 'late_orders')
    eligible = total(delivery, 'lateness_eligible_orders')
    sellers = rows('seller_delivery')
    prefixes = [s['seller_id'][:8] for s in sellers]
    if len(set(prefixes)) != len(prefixes):
        raise ValueError('Seller display prefixes collide: increase display length.')
    top_seller = sellers[0]
    ma = next(r for r in rows('state_freight') if r['customer_state'] == 'MA')
    metrics = {
        'headline_sales_brl': sales, 'headline_delivered_orders': orders,
        'headline_aov_brl': sales/orders,
        'jan_aug_2017_sales_brl': s0, 'jan_aug_2018_sales_brl': s1,
        'jan_aug_2017_delivered_orders': n0, 'jan_aug_2018_delivered_orders': n1,
        'jan_aug_sales_growth_pct': pct(s1-s0, s0),
        'jan_aug_order_growth_pct': pct(n1-n0, n0),
        'jan_aug_aov_growth_pct': pct(s1/n1-s0/n0, s0/n0),
        'headline_freight_to_merchandise_pct': pct(total(monthly,'freight_value'), sales),
        'jan_aug_2017_freight_to_merchandise_pct': pct(total(periods[0],'freight_value'),s0),
        'jan_aug_2018_freight_to_merchandise_pct': pct(total(periods[1],'freight_value'),s1),
        'overall_late_orders': late, 'overall_lateness_eligible_orders': eligible,
        'overall_late_delivery_pct': pct(late,eligible),
        'sp_rj_share_of_late_orders_pct': pct(total([r for r in delivery if r['customer_state'] in ('SP','RJ')],'late_orders'),late),
        'cohort_customers': total(cohorts,'cohort_customers'),
        'repeat_customers_90d': total(cohorts,'repeat_customers_90d'),
        'repeat_purchase_90d_pct': pct(total(cohorts,'repeat_customers_90d'),total(cohorts,'cohort_customers')),
        'sp_rj_mg_sales_share_pct': pct(total([r for r in rows('state_performance') if r['customer_state'] in ('SP','RJ','MG')],'delivered_merchandise_sales'),full_sales),
        'top10_category_sales_share_pct': pct(total(rows('product_categories'),'merchandise_sales'),full_sales),
        'ma_freight_to_merchandise_pct': D(ma['freight_to_merchandise_pct']),
        'top_seller_late_orders': D(top_seller['late_orders']),
        'top_seller_late_rate_pct': D(top_seller['late_delivery_pct']),
        'top_seller_gap_percentage_points': pct(D(top_seller['late_orders']),D(top_seller['lateness_eligible_orders']))-pct(late,eligible),
        'analysed_seller_prefixes': D(len(prefixes)),
        'unique_analysed_seller_prefixes': D(len(set(prefixes))),
    }
    return {k:v.quantize(D('0.01'),rounding=ROUND_HALF_UP) for k,v in metrics.items()}

if __name__ == '__main__':
    metrics=calculate()
    with (DATA/'derived_insights.csv').open('w',newline='',encoding='utf-8') as file:
        writer=csv.writer(file);writer.writerow(['metric','value']);writer.writerows(metrics.items())
    for key,value in metrics.items():print(f'{key}: {value:.2f}')
