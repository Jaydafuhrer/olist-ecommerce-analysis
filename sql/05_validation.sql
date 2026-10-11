-- Read-only metric reconciliation for the supplied reference snapshot.
-- Run after 03_reporting_views.sql and 07_dashboard_views.sql.
WITH checks AS (
 SELECT 'headline_merchandise_sales'::text AS metric,SUM(merchandise_sales) AS actual,13181027.13::numeric AS expected FROM gold.vw_monthly_growth
 UNION ALL SELECT 'headline_delivered_orders',SUM(delivered_orders),96211 FROM gold.vw_monthly_growth
 UNION ALL SELECT 'headline_aov',ROUND(SUM(merchandise_sales)/NULLIF(SUM(delivered_orders),0),2),137.00 FROM gold.vw_monthly_growth
 UNION ALL SELECT 'matched_sales_growth_pct',ROUND(100.0*(SUM(merchandise_sales) FILTER (WHERE purchase_month>=DATE '2018-01-01')/NULLIF(SUM(merchandise_sales) FILTER (WHERE purchase_month<DATE '2017-09-01'),0)-1),2),141.13 FROM gold.vw_monthly_growth
 UNION ALL SELECT 'late_orders',SUM(late_orders),6534 FROM gold.vw_delivery_priority
 UNION ALL SELECT 'lateness_eligible_orders',SUM(lateness_eligible_orders),96470 FROM gold.vw_delivery_priority
 UNION ALL SELECT 'late_delivery_pct',ROUND(100.0*SUM(late_orders)/NULLIF(SUM(lateness_eligible_orders),0),2),6.77 FROM gold.vw_delivery_priority
 UNION ALL SELECT 'freight_to_merchandise_pct',ROUND(100.0*SUM(freight_value)/NULLIF(SUM(merchandise_sales),0),2),16.63 FROM gold.vw_monthly_growth
 UNION ALL SELECT 'cohort_customers',SUM(cohort_customers),75123 FROM gold.vw_customer_repeat_90d
 UNION ALL SELECT 'repeat_customers_90d',SUM(repeat_customers_90d),1711 FROM gold.vw_customer_repeat_90d
 UNION ALL SELECT 'repeat_purchase_90d_pct',ROUND(100.0*SUM(repeat_customers_90d)/NULLIF(SUM(cohort_customers),0),2),2.28 FROM gold.vw_customer_repeat_90d
 UNION ALL SELECT 'full_dataset_merchandise_sales',SUM(merchandise_value),13221498.11 FROM gold.vw_order_analysis WHERE order_status='DELIVERED'
 UNION ALL SELECT 'ma_freight_pct',freight_to_merchandise_pct,26.32 FROM gold.vw_state_freight_analysis WHERE customer_state='MA'
 UNION ALL SELECT 'top_seller_late_orders',late_orders,172 FROM gold.vw_seller_delivery_priority WHERE seller_id='4a3ca9315b744ce9f8e9374361493884'
)
SELECT metric,actual,expected,CASE WHEN actual=expected THEN 'PASS' ELSE 'FAIL' END AS result FROM checks ORDER BY metric;
