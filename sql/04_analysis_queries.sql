-- monthly_sales
SELECT * FROM gold.vw_monthly_sales ORDER BY purchase_month;

-- state_performance
SELECT customer_state, delivered_merchandise_sales FROM gold.vw_state_performance ORDER BY delivered_merchandise_sales DESC NULLS LAST, customer_state LIMIT 10;

-- late_delivery_by_state
SELECT customer_state, late_delivery_pct, lateness_eligible_orders FROM gold.vw_state_performance WHERE lateness_eligible_orders > 0 ORDER BY late_delivery_pct DESC NULLS LAST, customer_state LIMIT 10;

-- product_categories
SELECT INITCAP(REPLACE(product_category, '_', ' ')) AS product_category, merchandise_sales FROM gold.vw_category_performance ORDER BY merchandise_sales DESC NULLS LAST, product_category LIMIT 10;

-- payment_methods
SELECT INITCAP(REPLACE(payment_type, '_', ' ')) AS payment_method, delivered_order_payment_value FROM gold.vw_payment_method_analysis WHERE delivered_order_payment_value IS NOT NULL ORDER BY delivered_order_payment_value DESC;

-- customer_segments
SELECT customer_segment, COUNT(*) AS customer_count FROM gold.vw_customer_purchase_behavior GROUP BY customer_segment ORDER BY customer_count DESC;

-- Final dashboard exports (same filters as sql/06_export.psql).
SELECT * FROM gold.vw_monthly_growth ORDER BY purchase_month;
SELECT * FROM gold.vw_customer_repeat_90d ORDER BY cohort_month;
SELECT * FROM gold.vw_delivery_priority ORDER BY late_orders DESC, customer_state;
SELECT * FROM gold.vw_state_freight_analysis WHERE delivered_orders>=100 ORDER BY freight_to_merchandise_pct DESC NULLS LAST, customer_state;
SELECT * FROM gold.vw_seller_delivery_priority WHERE lateness_eligible_orders>=100 ORDER BY late_orders DESC, merchandise_sales DESC, seller_id LIMIT 15;
