-- Recovered on 2026-10-10; reporting view references migrated to gold.
-- Underlying cleaned source tables remain in silver.
-- Requires the existing silver.olist_* tables, including olist_orders.date_quality_status.
-- Reporting definitions only: this does not recover table DDL or bronze-to-silver loading logic.
BEGIN;

CREATE OR REPLACE VIEW gold.vw_order_analysis AS
WITH item_totals AS (
         SELECT olist_order_items.order_id,
            count(*) AS item_count,
            count(DISTINCT olist_order_items.seller_id) AS seller_count,
            sum(olist_order_items.price) AS merchandise_value,
            sum(olist_order_items.freight_value) AS freight_value
           FROM silver.olist_order_items
          GROUP BY olist_order_items.order_id
        ), payment_totals AS (
         SELECT olist_order_payments.order_id,
            sum(olist_order_payments.payment_value) AS payment_total,
            string_agg(DISTINCT lower(TRIM(BOTH FROM olist_order_payments.payment_type)), ', '::text ORDER BY (lower(TRIM(BOTH FROM olist_order_payments.payment_type)))) AS payment_methods,
            max(olist_order_payments.payment_installments) AS max_payment_installments
           FROM silver.olist_order_payments
          GROUP BY olist_order_payments.order_id
        ), base AS (
         SELECT oo.order_id,
            oc.customer_id,
            oc.customer_unique_id,
            oc.customer_zip_code_prefix,
            upper(TRIM(BOTH FROM oc.customer_city)) AS customer_city,
            upper(TRIM(BOTH FROM oc.customer_state)) AS customer_state,
            upper(TRIM(BOTH FROM oo.order_status)) AS order_status,
            oo.order_purchase_timestamp AS purchased_at,
            oo.order_approved_at AS approved_at,
            oo.order_delivered_carrier_date AS carrier_at,
            oo.order_delivered_customer_date AS delivered_at,
            oo.order_estimated_delivery_date AS estimated_at,
            oo.date_quality_status,
            it.item_count,
            it.seller_count,
            it.merchandise_value,
            it.freight_value,
            pt.payment_total,
            pt.payment_methods,
            pt.max_payment_installments
           FROM silver.olist_orders oo
             LEFT JOIN silver.olist_customers oc ON oo.customer_id::text = oc.customer_id::text
             LEFT JOIN item_totals it ON oo.order_id::text = it.order_id::text
             LEFT JOIN payment_totals pt ON oo.order_id::text = pt.order_id::text
        )
 SELECT order_id,
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_status,
    purchased_at,
    approved_at,
    carrier_at,
    delivered_at,
    estimated_at,
    date_quality_status,
    item_count,
    seller_count,
    merchandise_value,
    freight_value,
    payment_total,
    payment_methods,
    max_payment_installments,
    date_trunc('month'::text, purchased_at)::date AS purchase_month,
        CASE
            WHEN approved_at >= purchased_at THEN floor(EXTRACT(epoch FROM approved_at - purchased_at) / 3600.0)::integer
            ELSE NULL::integer
        END AS approval_hours,
        CASE
            WHEN order_status = 'DELIVERED'::text AND delivered_at >= purchased_at THEN floor(EXTRACT(epoch FROM delivered_at - purchased_at) / 86400.0)::integer
            ELSE NULL::integer
        END AS delivery_days,
        CASE
            WHEN order_status = 'DELIVERED'::text AND carrier_at >= purchased_at AND delivered_at >= carrier_at THEN floor(EXTRACT(epoch FROM delivered_at - carrier_at) / 86400.0)::integer
            ELSE NULL::integer
        END AS shipping_days,
        CASE
            WHEN order_status = 'DELIVERED'::text AND delivered_at >= purchased_at AND estimated_at::date >= purchased_at::date THEN delivered_at::date > estimated_at::date
            ELSE NULL::boolean
        END AS is_late,
        CASE
            WHEN order_status = 'DELIVERED'::text AND delivered_at >= purchased_at AND estimated_at::date >= purchased_at::date THEN GREATEST(delivered_at::date - estimated_at::date, 0)
            ELSE NULL::integer
        END AS days_late
   FROM base;

CREATE OR REPLACE VIEW gold.vw_category_performance AS
WITH category_totals AS (
         SELECT COALESCE(NULLIF(TRIM(BOTH FROM op.product_category_name), ''::text), 'Unknown'::text) AS product_category,
            count(*) AS items_sold,
            count(DISTINCT oi.order_id) AS orders_containing_category,
            count(DISTINCT oi.product_id) AS distinct_products,
            count(DISTINCT oi.seller_id) AS distinct_sellers,
            sum(oi.price) AS merchandise_sales,
            round(avg(oi.price), 2) AS average_item_price,
            sum(oi.freight_value) AS total_freight_value,
            round(avg(oi.freight_value), 2) AS average_freight_per_item,
            round(100.0 * sum(oi.freight_value) FILTER (WHERE oi.price IS NOT NULL AND oi.freight_value IS NOT NULL) / NULLIF(sum(oi.price) FILTER (WHERE oi.price IS NOT NULL AND oi.freight_value IS NOT NULL), 0::numeric), 2) AS freight_to_merchandise_pct
           FROM silver.olist_order_items oi
             JOIN gold.vw_order_analysis orders ON oi.order_id::text = orders.order_id::text
             LEFT JOIN silver.olist_products op ON oi.product_id::text = op.product_id::text
          WHERE orders.order_status = 'DELIVERED'::text
          GROUP BY (COALESCE(NULLIF(TRIM(BOTH FROM op.product_category_name), ''::text), 'Unknown'::text))
        )
 SELECT product_category,
    items_sold,
    orders_containing_category,
    distinct_products,
    distinct_sellers,
    merchandise_sales,
    average_item_price,
    total_freight_value,
    average_freight_per_item,
    freight_to_merchandise_pct,
    round(100.0 * merchandise_sales / NULLIF(sum(merchandise_sales) OVER (), 0::numeric), 2) AS sales_share_pct,
    dense_rank() OVER (ORDER BY merchandise_sales DESC NULLS LAST) AS sales_rank
   FROM category_totals;

CREATE OR REPLACE VIEW gold.vw_customer_purchase_behavior AS
WITH customer_totals AS (
         SELECT vw_order_analysis.customer_unique_id,
            count(*) AS delivered_orders,
            count(vw_order_analysis.merchandise_value) AS orders_with_known_value,
            sum(vw_order_analysis.merchandise_value) AS merchandise_spend,
            round(avg(vw_order_analysis.merchandise_value), 2) AS average_order_value,
            min(vw_order_analysis.purchased_at) AS first_purchase_at,
            max(vw_order_analysis.purchased_at) AS latest_purchase_at
           FROM gold.vw_order_analysis
          WHERE vw_order_analysis.order_status = 'DELIVERED'::text AND vw_order_analysis.customer_unique_id IS NOT NULL AND TRIM(BOTH FROM vw_order_analysis.customer_unique_id) <> ''::text
          GROUP BY vw_order_analysis.customer_unique_id
        )
 SELECT customer_unique_id,
    delivered_orders,
    orders_with_known_value,
    merchandise_spend,
    average_order_value,
    first_purchase_at,
    latest_purchase_at,
        CASE
            WHEN delivered_orders > 1 THEN 'Repeat customer'::text
            ELSE 'Single-order customer'::text
        END AS customer_segment,
    latest_purchase_at::date - first_purchase_at::date AS purchase_span_days
   FROM customer_totals;

CREATE OR REPLACE VIEW gold.vw_monthly_sales AS
WITH monthly AS (
         SELECT vw_order_analysis.purchase_month,
            count(*) AS total_orders,
            count(*) FILTER (WHERE vw_order_analysis.order_status = 'DELIVERED'::text) AS delivered_orders,
            count(*) FILTER (WHERE vw_order_analysis.order_status = 'CANCELED'::text) AS canceled_orders,
            count(*) FILTER (WHERE vw_order_analysis.order_status = 'DELIVERED'::text AND vw_order_analysis.merchandise_value IS NOT NULL) AS delivered_orders_with_value,
            sum(vw_order_analysis.merchandise_value) FILTER (WHERE vw_order_analysis.order_status = 'DELIVERED'::text) AS delivered_merchandise_sales,
            sum(vw_order_analysis.freight_value) FILTER (WHERE vw_order_analysis.order_status = 'DELIVERED'::text) AS delivered_freight_value,
            round(avg(vw_order_analysis.merchandise_value) FILTER (WHERE vw_order_analysis.order_status = 'DELIVERED'::text), 2) AS average_order_value
           FROM gold.vw_order_analysis
          WHERE vw_order_analysis.purchase_month IS NOT NULL
          GROUP BY vw_order_analysis.purchase_month
        ), comparison AS (
         SELECT monthly.purchase_month,
            monthly.total_orders,
            monthly.delivered_orders,
            monthly.canceled_orders,
            monthly.delivered_orders_with_value,
            monthly.delivered_merchandise_sales,
            monthly.delivered_freight_value,
            monthly.average_order_value,
            lag(monthly.purchase_month) OVER (ORDER BY monthly.purchase_month) AS previous_month,
            lag(monthly.delivered_merchandise_sales) OVER (ORDER BY monthly.purchase_month) AS previous_month_sales
           FROM monthly
        )
 SELECT purchase_month,
    total_orders,
    delivered_orders,
    canceled_orders,
    delivered_orders_with_value,
    delivered_merchandise_sales,
    delivered_freight_value,
    average_order_value,
        CASE
            WHEN previous_month = (purchase_month - '1 mon'::interval)::date THEN round(100.0 * (delivered_merchandise_sales - previous_month_sales) / NULLIF(previous_month_sales, 0::numeric), 2)
            ELSE NULL::numeric
        END AS sales_growth_pct
   FROM comparison;

CREATE OR REPLACE VIEW gold.vw_payment_method_analysis AS
WITH payment_summary AS (
         SELECT COALESCE(NULLIF(lower(TRIM(BOTH FROM pay.payment_type)), ''::text), 'unknown'::text) AS payment_type,
            count(*) AS payment_records,
            count(DISTINCT pay.order_id) AS orders_using_method,
            sum(pay.payment_value) AS recorded_payment_value,
            sum(pay.payment_value) FILTER (WHERE orders.order_status = 'DELIVERED'::text) AS delivered_order_payment_value,
            round(avg(pay.payment_installments) FILTER (WHERE pay.payment_installments > 0::numeric), 2) AS average_positive_installments,
            count(*) FILTER (WHERE pay.payment_installments > 1::numeric) AS payment_records_with_multiple_installments,
            round(100.0 * count(*) FILTER (WHERE pay.payment_installments > 1::numeric)::numeric / NULLIF(count(*) FILTER (WHERE pay.payment_installments > 0::numeric), 0)::numeric, 2) AS multiple_installment_pct
           FROM silver.olist_order_payments pay
             JOIN gold.vw_order_analysis orders ON pay.order_id::text = orders.order_id::text
          GROUP BY (COALESCE(NULLIF(lower(TRIM(BOTH FROM pay.payment_type)), ''::text), 'unknown'::text))
        )
 SELECT payment_type,
    payment_records,
    orders_using_method,
    recorded_payment_value,
    delivered_order_payment_value,
    average_positive_installments,
    payment_records_with_multiple_installments,
    multiple_installment_pct,
    round(100.0 * recorded_payment_value / NULLIF(sum(recorded_payment_value) OVER (), 0::numeric), 2) AS payment_value_share_pct
   FROM payment_summary;

CREATE OR REPLACE VIEW gold.vw_seller_performance AS
WITH seller_orders AS (
         SELECT olist_order_items.seller_id,
            olist_order_items.order_id,
            count(*) AS item_count,
            sum(olist_order_items.price) AS merchandise_value
           FROM silver.olist_order_items
          GROUP BY olist_order_items.seller_id, olist_order_items.order_id
        ), seller_totals AS (
         SELECT so.seller_id,
            count(*) AS delivered_orders,
            sum(so.item_count) AS items_sold,
            sum(so.merchandise_value) AS merchandise_sales,
            round(avg(so.merchandise_value), 2) AS average_seller_value_per_order,
            round(avg(orders.delivery_days), 2) AS average_delivery_days,
            count(orders.delivery_days) AS delivery_duration_eligible_orders,
            count(orders.is_late) AS lateness_eligible_orders,
            count(*) FILTER (WHERE orders.is_late = true) AS late_orders,
            round(100.0 * count(*) FILTER (WHERE orders.is_late = true)::numeric / NULLIF(count(orders.is_late), 0)::numeric, 2) AS late_delivery_pct,
            count(*) FILTER (WHERE orders.is_late IS NULL) AS orders_excluded_from_lateness
           FROM seller_orders so
             JOIN gold.vw_order_analysis orders ON so.order_id::text = orders.order_id::text
          WHERE orders.order_status = 'DELIVERED'::text
          GROUP BY so.seller_id
        )
 SELECT seller_id,
    delivered_orders,
    items_sold,
    merchandise_sales,
    average_seller_value_per_order,
    average_delivery_days,
    delivery_duration_eligible_orders,
    lateness_eligible_orders,
    late_orders,
    late_delivery_pct,
    orders_excluded_from_lateness,
    dense_rank() OVER (ORDER BY merchandise_sales DESC NULLS LAST) AS sales_rank
   FROM seller_totals;

CREATE OR REPLACE VIEW gold.vw_state_performance AS
SELECT customer_state,
    count(*) AS total_orders,
    count(*) FILTER (WHERE order_status = 'DELIVERED'::text) AS delivered_orders,
    count(DISTINCT customer_unique_id) FILTER (WHERE order_status = 'DELIVERED'::text) AS delivered_customers,
    sum(merchandise_value) FILTER (WHERE order_status = 'DELIVERED'::text) AS delivered_merchandise_sales,
    round(avg(merchandise_value) FILTER (WHERE order_status = 'DELIVERED'::text), 2) AS average_order_value,
    round(avg(freight_value) FILTER (WHERE order_status = 'DELIVERED'::text), 2) AS average_freight_per_order,
    round(100.0 * sum(freight_value) FILTER (WHERE order_status = 'DELIVERED'::text AND merchandise_value IS NOT NULL AND freight_value IS NOT NULL) / NULLIF(sum(merchandise_value) FILTER (WHERE order_status = 'DELIVERED'::text AND merchandise_value IS NOT NULL AND freight_value IS NOT NULL), 0::numeric), 2) AS freight_to_merchandise_pct,
    round(avg(delivery_days), 2) AS average_delivery_days,
    count(delivery_days) AS delivery_duration_eligible_orders,
    count(is_late) AS lateness_eligible_orders,
    count(*) FILTER (WHERE is_late = true) AS late_orders,
    round(100.0 * count(*) FILTER (WHERE is_late = true)::numeric / NULLIF(count(is_late), 0)::numeric, 2) AS late_delivery_pct,
    count(*) FILTER (WHERE order_status = 'DELIVERED'::text AND is_late IS NULL) AS orders_excluded_from_lateness
   FROM gold.vw_order_analysis
  GROUP BY customer_state;

COMMIT;
