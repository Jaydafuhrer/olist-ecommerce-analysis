-- Column layout recovered from olistcolumns.csv.
-- Run ONLY in a fresh database: table creation deliberately fails if a table already exists.
-- This metadata does not contain PK/FK/check constraints, indexes, or privileges.
BEGIN;
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE "bronze"."olist_customers" (
    "customer_id" character varying,
    "customer_unique_id" character varying,
    "customer_zip_code_prefix" character varying,
    "customer_city" character varying,
    "customer_state" character varying
);

CREATE TABLE "bronze"."olist_geolocation" (
    "geolocation_zip_code" character varying,
    "geolocation_lat" character varying,
    "geolocation_lng" character varying,
    "geolocation_city" character varying,
    "geolocation_state" character varying
);

CREATE TABLE "bronze"."olist_order_items" (
    "order_id" character varying,
    "order_item_id" character varying,
    "product_id" character varying,
    "seller_id" character varying,
    "shipping_limit_date" character varying,
    "price" character varying,
    "freight_value" character varying
);

CREATE TABLE "bronze"."olist_order_payments" (
    "order_id" character varying,
    "payment_sequential" character varying,
    "payment_type" character varying,
    "payment_installments" character varying,
    "payment_value" character varying
);

CREATE TABLE "bronze"."olist_order_reviews" (
    "review_id" character varying,
    "order_id" character varying,
    "review_score" character varying,
    "review_comment_title" character varying,
    "review_comment_message" character varying,
    "review_creation_date" character varying,
    "review_answer_timestamp" character varying
);

CREATE TABLE "bronze"."olist_orders" (
    "order_id" character varying,
    "customer_id" character varying,
    "order_status" character varying,
    "order_purchase_timestamp" character varying,
    "order_approved_at" character varying,
    "order_delivered_carrier_date" character varying,
    "order_delivered_customer_date" character varying,
    "order_estimated_delivery_date" character varying
);

CREATE TABLE "bronze"."olist_producct_category_name" (
    "product_category_name" character varying,
    "product_category_name_english" character varying
);

CREATE TABLE "bronze"."olist_products" (
    "product_id" character varying,
    "product_category_name" character varying,
    "product_name_length" character varying,
    "product_description_length" character varying,
    "product_photos_qty" character varying,
    "product_weight_g" character varying,
    "product_length_cm" character varying,
    "product_height_cm" character varying,
    "product_width_cm" character varying
);

CREATE TABLE "bronze"."olist_seller" (
    "seller_id" character varying,
    "seller_zip_code_prefix" character varying,
    "seller_city" character varying,
    "seller_state" character varying
);

CREATE TABLE "silver"."olist_customers" (
    "customer_id" character varying,
    "customer_unique_id" character varying,
    "customer_zip_code_prefix" integer,
    "customer_city" character varying,
    "customer_state" character varying
);

CREATE TABLE "silver"."olist_geolocation" (
    "geolocation_zip_code" integer,
    "geolocation_lag" character varying,
    "geolocation_lng" character varying,
    "geolocation_city" character varying,
    "geolocation_state" character varying
);

CREATE TABLE "silver"."olist_order_items" (
    "order_id" character varying,
    "order_item_id" integer,
    "product_id" character varying,
    "seller_id" character varying,
    "shipping_limit_date" date,
    "price" numeric,
    "freight_value" numeric
);

CREATE TABLE "silver"."olist_order_payments" (
    "order_id" character varying,
    "payment_sequential" numeric,
    "payment_type" character varying,
    "payment_installments" numeric,
    "payment_value" numeric
);

CREATE TABLE "silver"."olist_orders" (
    "order_id" character varying,
    "customer_id" character varying,
    "order_status" character varying,
    "order_purchase_timestamp" timestamp without time zone,
    "order_approved_at" timestamp without time zone,
    "order_delivered_carrier_date" timestamp without time zone,
    "order_delivered_customer_date" timestamp without time zone,
    "order_estimated_delivery_date" timestamp without time zone,
    "date_quality_status" character varying
);

CREATE TABLE "silver"."olist_products" (
    "product_id" character varying,
    "product_category_name" character varying,
    "product_name_length" numeric,
    "product_desciption_length" numeric,
    "product_photos_qty" numeric,
    "product_weight_g" numeric,
    "product_length_cm" numeric,
    "product_height_cm" numeric,
    "product_width_cm" numeric
);

CREATE TABLE "silver"."olist_seller" (
    "seller_id" character varying,
    "seller_zip_code_prefix" numeric,
    "seller_city" character varying,
    "seller_state" character varying
);

COMMIT;
