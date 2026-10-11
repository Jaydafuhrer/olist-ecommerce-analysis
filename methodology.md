# Metric definitions and reporting scope

## Layers and grain

Bronze stores raw CSV records. Silver stores cleaned and typed tables. Gold owns analytical joins and views. The order view aggregates item and payment totals independently before joining, preserving one row per order. Category sales use item grain. Payment value uses payment-record grain. Seller order totals can overlap across sellers and must not be summed into a global order count.

## Measures

| Measure | Definition |
|---|---|
| Merchandise sales | Item price sum for delivered orders, excludes freight |
| Dashboard AOV | Merchandise sales / delivered orders in the same period |
| Monthly view AOV | Mean non-null delivered order merchandise value; matches the dashboard where all delivered values are known |
| YoY | Same calendar month one year earlier; SQL returns percentages on a 0–100 scale |
| Headline sales growth | Aggregate Jan–Aug 2018 sales / aggregate Jan–Aug 2017 sales minus one |
| Late order | Delivered status, valid purchase/delivery chronology, estimated date not before purchase date, delivered calendar date after estimated calendar date |
| Late rate | Late orders / orders with a non-null lateness indicator |
| Freight burden | Freight / merchandise value; state view uses matched non-null monetary pairs |
| Repeat within 90 days | More than one distinct delivered order purchased between a customer's first observed delivered purchase and 90 days later, including same-day separate orders |

## Periods and observation windows

Executive sales/orders/AOV and the freight headline use Jan 2017–Aug 2018. YoY uses Jan–Aug in both 2017 and 2018; later 2017 months remain on the monthly sales chart but have no 2018 comparator. State/category sales and late-delivery rankings use the full dataset.

The cohort cutoff is 2018-09-01. First purchases are found from all earlier delivered-order history, including 2016, before filtering displayed cohorts to 2017 onward. Only cohorts whose entire calendar month has 90 days of follow-up are included. The displayed cohorts therefore run Jan 2017–May 2018. The headline is weighted: sum of repeat customers / sum of cohort customers, not the mean of cohort percentages. First observed purchase is not necessarily a customer's lifetime first purchase. Complete windows refer to this dataset cutoff, not guaranteed capture of every real-world purchase.

## Rankings and identifiers

States are ranked by absolute late-order count. Freight rankings require at least 100 delivered orders. Seller exports require at least 100 lateness-eligible orders and retain the top 15; the dashboard displays five. Top-ten charts are partial rankings.

Seller labels show the first eight characters. All 15 labels were checked as unique. Full IDs remain in the export and underpin calculations and joins. Prefix uniqueness is established only for these 15 records. Seller late orders reflect whole-order delivery outcomes and do not establish seller fault.

## Recovery and reproducibility

Core view SELECT definitions and 96 column layouts across 16 bronze/silver tables came from the supplied database metadata. Those historical metadata files retain pre-migration schema names. Column spellings such as `geolocation_lag`, `product_desciption_length` and `olist_producct_category_name` are preserved to match the user's database.

The loader and five new dashboard CREATE VIEW statements are reconstructed. The author reported reproducing the project from source in a fresh PostgreSQL database on 11 October 2026 and confirmed the final dashboard validation passed. The four full-history totals were also evidenced in a supplied screenshot. The full final validation grid was not retained; the remaining results are author-confirmed. No PostgreSQL execution was performed in the packaging environment. Checks compare exports, cached workbook values, reference ranges and independently derived metrics. Original metadata is retained for traceability; it does not prove original indexes, constraints, grants or loading logic. The existing internal date-status field is retained for compatibility with recovered table/view definitions, but no data-quality reporting is included.

Sales do not measure profit. Freight ratios do not identify carrier margin. The analysis supports investigation and does not establish causation.

## Reference snapshots and workbook dependencies

`data/exports/` holds historical aggregated reporting snapshots, not raw source data. The five final-dashboard exports are monthly_growth, customer_repeat_90d, delivery_priority, state_freight and seller_delivery. Older snapshots remain because workbook sheets or concentration calculations use them. Fresh exports go to ignored data/refreshed/; raw source files go to ignored data/raw/.

The final workbook preserves the Executive overview and Delivery & Customer Analysis layouts, KPI cards, charts, insight text and supporting worksheets. The former Dashboard sheet is absent. chart_data, stateperformance and olist_product_category remain because dashboard charts reference them. The displayed seller chart uses five records; helper charts may retain 15. Period and seller-ID explanations appear beneath the insights on their respective dashboards.

Jan–Aug 2017 sales were R$2,993,456.13 across 21,998 orders. Jan–Aug 2018 sales were R$7,218,125.12 across 52,783 orders. Freight-to-merchandise ratios were 16.02% and 17.09%, respectively. These equal-period figures support the README findings.

Seller 4a3ca931’s gap against the overall late rate is 2.93 percentage points when calculated from unrounded counts. Subtracting the displayed rounded rates, 9.71% and 6.77%, gives 2.94 points; the SQL and supporting Python calculation use the underlying counts.
