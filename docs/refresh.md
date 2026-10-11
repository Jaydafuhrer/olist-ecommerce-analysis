# Refresh reporting exports and Excel

1. Run the gold view scripts against a separate reproduction database, or use the existing analytical database after reviewing the reconstructed definitions. Do not run setup/import/loading scripts on the existing populated project.
2. Run sql/05_validation.sql to compare dashboard metrics with the included reference snapshot. Different source versions can change the results.
3. Create data/refreshed and run sql/06_export.psql from the repository root. In pgAdmin, use the equivalent SELECT statements in sql/04_analysis_queries.sql and export CSV results.
4. Replace each Excel source sheet's data with its matching refreshed CSV, retaining the header/column order. The five new exports map to monthly_growth, customer_repeat_90d, delivery_priority, state_freight and seller_delivery. Older exports map to their existing workbook sheets.
5. Keep data sorted as specified in the export queries. Update helper formulas, chart ranges and KPI ranges if the number of rows changes; these are fixed snapshot ranges, not an automatic live connection.
6. Check labels, cached results and chart order. The freight helpers should stay paired with their state codes. Check COUNTIF for duplicate shortened seller labels and use longer prefixes if needed.
7. Update insight text and reporting-period notes to reflect any changed data or cutoff. Save Excel and regenerate dashboard previews.

SQL percentages are stored as 0–100 values. Helpers divide them by 100 before applying Excel percentage formats. Source data sheets can retain the original numeric scale.
