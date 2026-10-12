-- Applies the tested rewrite; aborts if any result changes.
-- No indexes or persistent memory settings are changed.
BEGIN;
CREATE TEMP TABLE cohort_before_update ON COMMIT DROP AS
SELECT * FROM gold.vw_customer_repeat_90d;
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
DO $$
BEGIN
 IF EXISTS (
  (SELECT * FROM gold.vw_customer_repeat_90d EXCEPT ALL SELECT * FROM cohort_before_update)
  UNION ALL
  (SELECT * FROM cohort_before_update EXCEPT ALL SELECT * FROM gold.vw_customer_repeat_90d)
 ) THEN RAISE EXCEPTION 'Cohort results changed; roll back this transaction'; END IF;
END;
$$;
COMMIT;
