-- RECONSTRUCTED loader: original INSERT/UPDATE statements were not exported.
-- Run only on empty silver tables in a fresh reproduction database.
-- Explicit mappings preserve the actual database's misspelled column names.
-- Invalid typed values abort the transaction. No arbitrary duplicate removal.
BEGIN;
DO $$
DECLARE t record; has_rows boolean;
BEGIN
 FOR t IN SELECT table_name FROM information_schema.tables
          WHERE table_schema = 'silver' AND table_type = 'BASE TABLE'
 LOOP
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM silver.%I)', t.table_name) INTO has_rows;
  IF has_rows THEN RAISE EXCEPTION 'silver.% contains data; use a fresh database', t.table_name; END IF;
 END LOOP;
END $$;

INSERT INTO silver."olist_customers" ("customer_id", "customer_unique_id", "customer_zip_code_prefix", "customer_city", "customer_state")
SELECT NULLIF(BTRIM("customer_id"), ''),
       NULLIF(BTRIM("customer_unique_id"), ''),
       (NULLIF(BTRIM("customer_zip_code_prefix"), ''))::integer,
       NULLIF(BTRIM("customer_city"), ''),
       UPPER(NULLIF(BTRIM("customer_state"), ''))
FROM bronze."olist_customers";

INSERT INTO silver."olist_geolocation" ("geolocation_zip_code", "geolocation_lag", "geolocation_lng", "geolocation_city", "geolocation_state")
SELECT (NULLIF(BTRIM("geolocation_zip_code"), ''))::integer,
       NULLIF(BTRIM("geolocation_lat"), ''),
       NULLIF(BTRIM("geolocation_lng"), ''),
       NULLIF(BTRIM("geolocation_city"), ''),
       UPPER(NULLIF(BTRIM("geolocation_state"), ''))
FROM bronze."olist_geolocation";

INSERT INTO silver."olist_order_items" ("order_id", "order_item_id", "product_id", "seller_id", "shipping_limit_date", "price", "freight_value")
SELECT NULLIF(BTRIM("order_id"), ''),
       (NULLIF(BTRIM("order_item_id"), ''))::integer,
       NULLIF(BTRIM("product_id"), ''),
       NULLIF(BTRIM("seller_id"), ''),
       (NULLIF(BTRIM("shipping_limit_date"), ''))::date,
       (NULLIF(BTRIM("price"), ''))::numeric,
       (NULLIF(BTRIM("freight_value"), ''))::numeric
FROM bronze."olist_order_items";

INSERT INTO silver."olist_order_payments" ("order_id", "payment_sequential", "payment_type", "payment_installments", "payment_value")
SELECT NULLIF(BTRIM("order_id"), ''),
       (NULLIF(BTRIM("payment_sequential"), ''))::numeric,
       LOWER(NULLIF(BTRIM("payment_type"), '')),
       (NULLIF(BTRIM("payment_installments"), ''))::numeric,
       (NULLIF(BTRIM("payment_value"), ''))::numeric
FROM bronze."olist_order_payments";

INSERT INTO silver."olist_orders" ("order_id", "customer_id", "order_status", "order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date", "order_delivered_customer_date", "order_estimated_delivery_date")
SELECT NULLIF(BTRIM("order_id"), ''),
       NULLIF(BTRIM("customer_id"), ''),
       UPPER(NULLIF(BTRIM("order_status"), '')),
       (NULLIF(BTRIM("order_purchase_timestamp"), ''))::timestamp without time zone,
       (NULLIF(BTRIM("order_approved_at"), ''))::timestamp without time zone,
       (NULLIF(BTRIM("order_delivered_carrier_date"), ''))::timestamp without time zone,
       (NULLIF(BTRIM("order_delivered_customer_date"), ''))::timestamp without time zone,
       (NULLIF(BTRIM("order_estimated_delivery_date"), ''))::timestamp without time zone
FROM bronze."olist_orders";

INSERT INTO silver."olist_products" ("product_id", "product_category_name", "product_name_length", "product_desciption_length", "product_photos_qty", "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm")
SELECT NULLIF(BTRIM("product_id"), ''),
       INITCAP(REPLACE(NULLIF(BTRIM("product_category_name"), ''), '_', ' ')),
       (NULLIF(BTRIM("product_name_length"), ''))::numeric,
       (NULLIF(BTRIM("product_description_length"), ''))::numeric,
       (NULLIF(BTRIM("product_photos_qty"), ''))::numeric,
       (NULLIF(BTRIM("product_weight_g"), ''))::numeric,
       (NULLIF(BTRIM("product_length_cm"), ''))::numeric,
       (NULLIF(BTRIM("product_height_cm"), ''))::numeric,
       (NULLIF(BTRIM("product_width_cm"), ''))::numeric
FROM bronze."olist_products";

INSERT INTO silver."olist_seller" ("seller_id", "seller_zip_code_prefix", "seller_city", "seller_state")
SELECT NULLIF(BTRIM("seller_id"), ''),
       (NULLIF(BTRIM("seller_zip_code_prefix"), ''))::numeric,
       NULLIF(BTRIM("seller_city"), ''),
       UPPER(NULLIF(BTRIM("seller_state"), ''))
FROM bronze."olist_seller";

COMMIT;
