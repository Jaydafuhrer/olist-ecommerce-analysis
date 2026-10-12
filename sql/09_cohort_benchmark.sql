-- Run in one session. Temporary views disappear when the session ends.
-- Benchmark does not alter source tables or the permanent view.
CREATE TEMP VIEW cohort_original_benchmark AS
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
CREATE TEMP VIEW cohort_candidate_benchmark AS
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
-- Expected: 0. Compare all columns and duplicate row multiplicities.
SELECT COUNT(*) AS differing_rows FROM (
 (SELECT * FROM cohort_original_benchmark EXCEPT ALL SELECT * FROM cohort_candidate_benchmark)
 UNION ALL
 (SELECT * FROM cohort_candidate_benchmark EXCEPT ALL SELECT * FROM cohort_original_benchmark)
) differences;
-- Execute statements separately in pgAdmin so each plan can be copied.
-- Repeat at 4MB and 16MB; alternate query order and record multiple runs.
BEGIN;
SET LOCAL work_mem = '16MB';
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM cohort_original_benchmark ORDER BY cohort_month;
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM cohort_candidate_benchmark ORDER BY cohort_month;
ROLLBACK;
