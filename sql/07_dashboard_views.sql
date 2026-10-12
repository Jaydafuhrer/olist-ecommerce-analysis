-- Reconstructed from the final dashboard definitions and exported column layouts.
-- Exports were checked locally; these CREATE statements have not been executed locally.
-- Requires sql/03_reporting_views.sql. SQL percentages use 0–100 units.
BEGIN;
CREATE OR REPLACE VIEW gold.vw_monthly_growth AS
WITH m AS (
 SELECT purchase_month, total_orders, delivered_orders,
 delivered_merchandise_sales AS merchandise_sales, average_order_value,
 delivered_freight_value AS freight_value
 FROM gold.vw_monthly_sales
 WHERE purchase_month >= DATE '2017-01-01' AND purchase_month < DATE '2018-09-01'
)
SELECT c.purchase_month,c.total_orders,c.delivered_orders,c.merchandise_sales,c.average_order_value,c.freight_value,
 ROUND(100.0*c.freight_value/NULLIF(c.merchandise_sales,0),2) AS freight_to_sales_pct,
 p.merchandise_sales AS previous_year_sales,p.delivered_orders AS previous_year_orders,
 ROUND(100.0*(c.merchandise_sales/NULLIF(p.merchandise_sales,0)-1),2) AS sales_yoy_growth_pct,
 ROUND(100.0*(c.delivered_orders::numeric/NULLIF(p.delivered_orders,0)-1),2) AS orders_yoy_growth_pct,
 ROUND(100.0*(c.average_order_value/NULLIF(p.average_order_value,0)-1),2) AS aov_yoy_growth_pct
FROM m c LEFT JOIN m p ON p.purchase_month=(c.purchase_month-INTERVAL '1 year')::date;

CREATE OR REPLACE VIEW gold.vw_customer_repeat_90d AS
WITH ranked AS (
    SELECT customer_unique_id, purchased_at,
        LEAD(purchased_at) OVER w AS second_purchase_at,
        ROW_NUMBER() OVER w AS purchase_number
    FROM gold.vw_order_analysis
    WHERE order_status = 'DELIVERED'
      AND purchased_at < TIMESTAMP '2018-09-01'
      AND NULLIF(TRIM(customer_unique_id), '') IS NOT NULL
    WINDOW w AS (PARTITION BY customer_unique_id ORDER BY purchased_at)
), firsts AS (
    SELECT DATE_TRUNC('month', purchased_at)::date AS cohort_month,
        second_purchase_at <= purchased_at + INTERVAL '90 days' AS repeated_90d
    FROM ranked WHERE purchase_number = 1
)
SELECT cohort_month, COUNT(*) AS cohort_customers,
    COUNT(*) FILTER (WHERE repeated_90d) AS repeat_customers_90d,
    ROUND(100.0 * COUNT(*) FILTER (WHERE repeated_90d)
          / NULLIF(COUNT(*), 0), 2) AS repeat_purchase_90d_pct
FROM firsts
WHERE cohort_month >= DATE '2017-01-01'
  AND cohort_month + INTERVAL '1 month' + INTERVAL '90 days'
      <= TIMESTAMP '2018-09-01'
GROUP BY cohort_month;

CREATE OR REPLACE VIEW gold.vw_delivery_priority AS
SELECT customer_state,delivered_orders,lateness_eligible_orders,late_orders,late_delivery_pct,
 ROUND(100.0*late_orders/NULLIF(SUM(late_orders) OVER (),0),2) AS share_of_all_late_orders_pct,
 average_delivery_days,delivered_merchandise_sales AS merchandise_sales,freight_to_merchandise_pct,
 DENSE_RANK() OVER (ORDER BY late_orders DESC) AS late_volume_rank,
 CASE WHEN lateness_eligible_orders>=100 THEN '100+ eligible orders' ELSE 'Below 100 eligible orders' END AS sample_size_note
FROM gold.vw_state_performance;

CREATE OR REPLACE VIEW gold.vw_state_freight_analysis AS
SELECT customer_state,delivered_orders,delivered_merchandise_sales AS merchandise_sales,
 ROUND(100.0*delivered_merchandise_sales/NULLIF(SUM(delivered_merchandise_sales) OVER (),0),2) AS merchandise_sales_share_pct,
 average_order_value,average_freight_per_order,freight_to_merchandise_pct,average_delivery_days,
 CASE WHEN delivered_orders>=100 THEN '100+ delivered orders' ELSE 'Below 100 delivered orders' END AS sample_size_note
FROM gold.vw_state_performance;

CREATE OR REPLACE VIEW gold.vw_seller_delivery_priority AS
WITH overall AS (
 SELECT 100.0*COUNT(*) FILTER (WHERE is_late)/NULLIF(COUNT(is_late),0) AS rate
 FROM gold.vw_order_analysis
)
SELECT s.seller_id,s.delivered_orders,s.lateness_eligible_orders,s.late_orders,s.late_delivery_pct,
 ROUND(o.rate,2) AS overall_late_delivery_pct,
 ROUND(100.0*s.late_orders/NULLIF(s.lateness_eligible_orders,0)-o.rate,2) AS gap_vs_overall_percentage_points,
 s.average_delivery_days,s.merchandise_sales,
 CASE WHEN s.lateness_eligible_orders>=100 THEN '100+ eligible orders' ELSE 'Below 100 eligible orders' END AS sample_size_note
FROM gold.vw_seller_performance s CROSS JOIN overall o;
COMMIT;
