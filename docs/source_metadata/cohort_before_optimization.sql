-- Exact pre-optimisation SELECT exported from olist_project on 2026-10-12.
WITH delivered AS (
         SELECT vw_order_analysis.order_id,
            vw_order_analysis.customer_unique_id,
            vw_order_analysis.purchased_at
           FROM gold.vw_order_analysis
          WHERE vw_order_analysis.order_status = 'DELIVERED'::text AND vw_order_analysis.purchased_at < '2018-09-01 00:00:00'::timestamp without time zone AND NULLIF(TRIM(BOTH FROM vw_order_analysis.customer_unique_id), ''::text) IS NOT NULL
        ), first_purchase AS (
         SELECT delivered.customer_unique_id,
            min(delivered.purchased_at) AS first_purchase_at
           FROM delivered
          GROUP BY delivered.customer_unique_id
        ), customer_activity AS (
         SELECT f.customer_unique_id,
            date_trunc('month'::text, f.first_purchase_at)::date AS cohort_month,
            count(*) FILTER (WHERE d.purchased_at <= (f.first_purchase_at + '90 days'::interval)) AS delivered_orders_within_90d
           FROM first_purchase f
             JOIN delivered d ON d.customer_unique_id::text = f.customer_unique_id::text
          GROUP BY f.customer_unique_id, f.first_purchase_at
        )
 SELECT cohort_month,
    count(*) AS cohort_customers,
    count(*) FILTER (WHERE delivered_orders_within_90d > 1) AS repeat_customers_90d,
    round(100.0 * count(*) FILTER (WHERE delivered_orders_within_90d > 1)::numeric / NULLIF(count(*), 0)::numeric, 2) AS repeat_purchase_90d_pct
   FROM customer_activity
  WHERE cohort_month >= '2017-01-01'::date AND (cohort_month + '1 mon'::interval + '90 days'::interval) <= '2018-09-01 00:00:00'::timestamp without time zone
  GROUP BY cohort_month;
