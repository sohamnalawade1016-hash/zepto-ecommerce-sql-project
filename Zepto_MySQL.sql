/*
PROJECT: Zepto E-Commerce SQL Analytics
DIALECT: MySQL 8.0+
SOURCE: zepto.csv (3,732 rows; 9 source columns)

IMPORTANT DATA NOTES
1. Source prices are in paise. Divide by 100 to report INR.
2. This is a product/inventory snapshot, not an order or transaction table.
   Do NOT label price * availableQuantity as revenue or actual sales.
3. The source contains one zero-MRP row and four zero-weight rows.
   Keep raw data unchanged; flag questionable records in the clean layer.
4. Product names can repeat across categories. Do not deduplicate on name alone.
*/

-- =========================================================
-- 0. DATABASE AND RAW TABLE
-- =========================================================
CREATE DATABASE IF NOT EXISTS zepto_analytics;
USE zepto_analytics;

DROP VIEW IF EXISTS vw_zepto_analytics;
DROP TABLE IF EXISTS zepto_clean;
DROP TABLE IF EXISTS zepto_raw;

CREATE TABLE zepto_raw (
    sku_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(120),
    name VARCHAR(200) NOT NULL,
    mrp_paise INT,
    discount_percent DECIMAL(5,2),
    available_quantity INT,
    selling_price_paise INT,
    weight_g INT,
    out_of_stock BOOLEAN,
    quantity INT,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_name (name),
    INDEX idx_stock (out_of_stock)
);

-- Import the CSV using MySQL Workbench Table Data Import Wizard:
--   1. Right-click zepto_analytics > Tables > Table Data Import Wizard.
--   2. Select zepto.csv.
--   3. Import into zepto_raw and map the 9 CSV columns in this order:
--      Category, name, mrp, discountPercent, availableQuantity,
--      discountedSellingPrice, weightInGms, outOfStock, quantity.
--   4. Do not map sku_id or imported_at; they are generated automatically.
--
-- Alternative command-line import (edit the path for your computer):
-- SET GLOBAL local_infile = 1; -- may require administrator privileges
-- LOAD DATA LOCAL INFILE 'C:/path/to/zepto.csv'
-- INTO TABLE zepto_raw
-- FIELDS TERMINATED BY ',' ENCLOSED BY '"'
-- LINES TERMINATED BY '\r\n'  -- Windows CSV; use '\n' if the file came from Linux/macOS
-- (The header row starts with a hidden BOM character before "Category", which
--  is harmless here because IGNORE 1 ROWS skips it and columns map by position.)
-- IGNORE 1 ROWS
-- (category, name, mrp_paise, discount_percent, available_quantity,
--  selling_price_paise, weight_g, out_of_stock, quantity);

-- =========================================================
-- 1. DATA VALIDATION / EXPLORATION
-- =========================================================
-- 1.1 Total records
SELECT COUNT(*) AS total_rows FROM zepto_raw;

-- 1.2 Preview
SELECT * FROM zepto_raw ORDER BY sku_id LIMIT 10;

-- 1.3 NULL audit
SELECT
    SUM(category IS NULL OR TRIM(category) = '') AS missing_category,
    SUM(name IS NULL OR TRIM(name) = '') AS missing_name,
    SUM(mrp_paise IS NULL) AS missing_mrp,
    SUM(discount_percent IS NULL) AS missing_discount,
    SUM(available_quantity IS NULL) AS missing_available_quantity,
    SUM(selling_price_paise IS NULL) AS missing_selling_price,
    SUM(weight_g IS NULL) AS missing_weight,
    SUM(out_of_stock IS NULL) AS missing_stock_status,
    SUM(quantity IS NULL) AS missing_quantity
FROM zepto_raw;

-- 1.4 Distinct categories and SKU count
SELECT category, COUNT(*) AS sku_count
FROM zepto_raw
GROUP BY category
ORDER BY sku_count DESC;

-- 1.5 Stock availability
SELECT
    CASE WHEN out_of_stock = 1 THEN 'Out of stock' ELSE 'In stock' END AS stock_status,
    COUNT(*) AS sku_count,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM zepto_raw
GROUP BY out_of_stock;

-- 1.6 Repeated names (not necessarily duplicates)
SELECT name, COUNT(*) AS occurrences,
       COUNT(DISTINCT category) AS category_count
FROM zepto_raw
GROUP BY name
HAVING COUNT(*) > 1
ORDER BY occurrences DESC, name;

-- 1.7 Exact duplicate source records
SELECT category, name, mrp_paise, discount_percent, available_quantity,
       selling_price_paise, weight_g, out_of_stock, quantity,
       COUNT(*) AS duplicate_count
FROM zepto_raw
GROUP BY category, name, mrp_paise, discount_percent, available_quantity,
         selling_price_paise, weight_g, out_of_stock, quantity
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 1.8 Invalid / suspicious values
SELECT *
FROM zepto_raw
WHERE mrp_paise IS NULL OR mrp_paise <= 0
   OR selling_price_paise IS NULL OR selling_price_paise < 0
   OR discount_percent IS NULL OR discount_percent NOT BETWEEN 0 AND 100
   OR available_quantity IS NULL OR available_quantity < 0
   OR weight_g IS NULL OR weight_g < 0
   OR quantity IS NULL OR quantity < 0
   OR category IS NULL OR TRIM(category) = ''
   OR name IS NULL OR TRIM(name) = '';

-- 1.9 Check arithmetic consistency of the discount
SELECT sku_id, name, mrp_paise, selling_price_paise, discount_percent,
       ROUND((mrp_paise - selling_price_paise) * 100.0 / NULLIF(mrp_paise, 0), 2)
           AS calculated_discount_percent
FROM zepto_raw
WHERE mrp_paise > 0
  AND ABS(discount_percent -
      ((mrp_paise - selling_price_paise) * 100.0 / mrp_paise)) > 1.5;

-- 1.10 Stock flag consistency
SELECT *
FROM zepto_raw
WHERE (out_of_stock = 1 AND available_quantity <> 0)
   OR (out_of_stock = 0 AND available_quantity = 0);

-- =========================================================
-- 2. CLEAN LAYER
-- =========================================================
-- Preserve raw source values. Convert paise to rupees only in this layer.
-- Do not delete zero-weight items: weight may be missing/not applicable.
-- Zero MRP is flagged and excluded from price-based analysis, not erased.

-- Exact duplicates: rows identical across all 9 source columns. The first
-- occurrence (lowest sku_id) is kept (duplicate_flag = 0); later copies are
-- flagged (duplicate_flag = 1) and excluded from the analytical view.
CREATE TABLE zepto_clean AS
WITH ranked AS (
    SELECT
        r.*,
        ROW_NUMBER() OVER (
            PARTITION BY category, name, mrp_paise, discount_percent,
                         available_quantity, selling_price_paise, weight_g,
                         out_of_stock, quantity
            ORDER BY sku_id
        ) AS dup_rank
    FROM zepto_raw r
)
SELECT
    sku_id,
    TRIM(category) AS category,
    TRIM(name) AS product_name,
    CAST(mrp_paise / 100.0 AS DECIMAL(10,2)) AS mrp_inr,
    discount_percent,
    available_quantity,
    CAST(selling_price_paise / 100.0 AS DECIMAL(10,2)) AS selling_price_inr,
    weight_g,
    out_of_stock,
    quantity,
    CASE
        WHEN mrp_paise IS NULL OR mrp_paise <= 0 THEN 'INVALID_MRP'
        WHEN selling_price_paise IS NULL OR selling_price_paise < 0 THEN 'INVALID_SELLING_PRICE'
        WHEN discount_percent IS NULL OR discount_percent NOT BETWEEN 0 AND 100 THEN 'INVALID_DISCOUNT'
        WHEN available_quantity IS NULL OR available_quantity < 0 THEN 'INVALID_STOCK_QUANTITY'
        WHEN weight_g IS NULL OR weight_g < 0 THEN 'INVALID_WEIGHT'
        ELSE 'VALID'
    END AS data_quality_status,
    CASE WHEN weight_g IS NULL OR weight_g = 0 THEN 1 ELSE 0 END AS weight_missing_flag,
    CASE WHEN dup_rank > 1 THEN 1 ELSE 0 END AS duplicate_flag
FROM ranked;

ALTER TABLE zepto_clean
    ADD PRIMARY KEY (sku_id),
    ADD INDEX idx_clean_category (category),
    ADD INDEX idx_clean_stock (out_of_stock),
    ADD INDEX idx_clean_price (selling_price_inr);

-- Reusable analytical view: only valid, de-duplicated records.
CREATE VIEW vw_zepto_analytics AS
SELECT *,
       ROUND((mrp_inr - selling_price_inr) * 100.0 /
             NULLIF(mrp_inr, 0), 2) AS calculated_discount_percent,
       CASE
           WHEN weight_g = 0 OR weight_g IS NULL THEN NULL
           ELSE ROUND(selling_price_inr / weight_g, 4)
       END AS price_per_gram_inr,
       ROUND(selling_price_inr * available_quantity, 2)
           AS estimated_inventory_value_inr
FROM zepto_clean
WHERE data_quality_status = 'VALID'
  AND duplicate_flag = 0;

-- =========================================================
-- 3. BUSINESS ANALYSIS
-- =========================================================

-- Q1. Executive snapshot
SELECT
    COUNT(*) AS valid_skus,
    COUNT(DISTINCT category) AS categories,
    SUM(out_of_stock = 0) AS in_stock_skus,
    SUM(out_of_stock = 1) AS out_of_stock_skus,
    ROUND(AVG(discount_percent), 2) AS average_discount_percent,
    ROUND(AVG(mrp_inr), 2) AS average_mrp_inr,
    ROUND(AVG(selling_price_inr), 2) AS average_selling_price_inr
FROM vw_zepto_analytics;

-- Q2. Top 10 best discounts (include category and both prices)
SELECT category, product_name, mrp_inr, selling_price_inr,
       discount_percent
FROM vw_zepto_analytics
ORDER BY discount_percent DESC, mrp_inr DESC
LIMIT 10;

-- Q3. High-MRP products currently out of stock
SELECT category, product_name, mrp_inr, selling_price_inr
FROM vw_zepto_analytics
WHERE out_of_stock = 1
ORDER BY mrp_inr DESC
LIMIT 20;

-- Q4. Category-level inventory and estimated inventory value.
-- This is stock value at current selling price, NOT realized revenue.
SELECT category,
       COUNT(*) AS total_skus,
       SUM(out_of_stock = 0) AS in_stock_skus,
       SUM(out_of_stock = 1) AS out_of_stock_skus,
       SUM(available_quantity) AS total_available_quantity,
       ROUND(SUM(estimated_inventory_value_inr), 2)
           AS estimated_inventory_value_inr
FROM vw_zepto_analytics
GROUP BY category
ORDER BY estimated_inventory_value_inr DESC;

-- Q5. Categories with highest average discount
SELECT category,
       COUNT(*) AS sku_count,
       ROUND(AVG(discount_percent), 2) AS average_discount_percent
FROM vw_zepto_analytics
GROUP BY category
HAVING COUNT(*) >= 10
ORDER BY average_discount_percent DESC;

-- Q6-prep. Justify the thresholds below. Run these first and write down
-- the numbers; then pick cutoffs from the data (e.g. MRP above the 75th
-- percentile, discount below the median) and replace the hard-coded values.
-- MySQL has no PERCENTILE_CONT, so percentiles are taken by row rank.

-- MRP distribution (INR)
WITH r AS (
    SELECT mrp_inr,
           ROW_NUMBER() OVER (ORDER BY mrp_inr) AS rn,
           COUNT(*) OVER () AS n
    FROM vw_zepto_analytics
)
SELECT MIN(mrp_inr) AS min_mrp,
       MIN(CASE WHEN rn >= 0.25 * n THEN mrp_inr END) AS p25,
       MIN(CASE WHEN rn >= 0.50 * n THEN mrp_inr END) AS median,
       MIN(CASE WHEN rn >= 0.75 * n THEN mrp_inr END) AS p75,
       MIN(CASE WHEN rn >= 0.90 * n THEN mrp_inr END) AS p90,
       MAX(mrp_inr) AS max_mrp
FROM r;

-- Discount distribution (%)
WITH r AS (
    SELECT discount_percent,
           ROW_NUMBER() OVER (ORDER BY discount_percent) AS rn,
           COUNT(*) OVER () AS n
    FROM vw_zepto_analytics
)
SELECT MIN(discount_percent) AS min_disc,
       MIN(CASE WHEN rn >= 0.25 * n THEN discount_percent END) AS p25,
       MIN(CASE WHEN rn >= 0.50 * n THEN discount_percent END) AS median,
       MIN(CASE WHEN rn >= 0.75 * n THEN discount_percent END) AS p75,
       MAX(discount_percent) AS max_disc
FROM r;

-- Weight distribution (g), known weights only
WITH r AS (
    SELECT weight_g,
           ROW_NUMBER() OVER (ORDER BY weight_g) AS rn,
           COUNT(*) OVER () AS n
    FROM vw_zepto_analytics
    WHERE weight_g > 0
)
SELECT MIN(weight_g) AS min_w,
       MIN(CASE WHEN rn >= 0.25 * n THEN weight_g END) AS p25,
       MIN(CASE WHEN rn >= 0.50 * n THEN weight_g END) AS median,
       MIN(CASE WHEN rn >= 0.75 * n THEN weight_g END) AS p75,
       MAX(weight_g) AS max_w
FROM r;

-- Q6. Products with MRP above ₹500 and discount below 10%
-- (TODO: replace 500 and 10 with data-driven cutoffs from Q6-prep.)
SELECT category, product_name, mrp_inr, selling_price_inr, discount_percent
FROM vw_zepto_analytics
WHERE mrp_inr > 500 AND discount_percent < 10
ORDER BY mrp_inr DESC;

-- Q7. Best unit-price value (only known weights >= 100g)
SELECT category, product_name, weight_g, selling_price_inr,
       price_per_gram_inr
FROM vw_zepto_analytics
WHERE weight_g >= 100
ORDER BY price_per_gram_inr ASC
LIMIT 20;

-- Q8. How does the catalog split by pack weight?
-- Zero-weight rows are excluded (weight unknown), so percentages are of
-- products with a known weight.
SELECT weight_segment,
       COUNT(*) AS sku_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_catalog
FROM (
    SELECT CASE
               WHEN weight_g < 1000 THEN '1. Small (<1kg)'
               WHEN weight_g < 5000 THEN '2. Medium (1-5kg)'
               ELSE '3. Bulk (>=5kg)'
           END AS weight_segment
    FROM vw_zepto_analytics
    WHERE weight_g > 0
) seg
GROUP BY weight_segment
ORDER BY weight_segment;

-- Q9. Category-wise stock availability rate
SELECT category,
       COUNT(*) AS total_skus,
       SUM(out_of_stock = 0) AS in_stock_skus,
       ROUND(100.0 * SUM(out_of_stock = 0) / COUNT(*), 2)
           AS in_stock_rate_percent
FROM vw_zepto_analytics
GROUP BY category
ORDER BY in_stock_rate_percent ASC;

-- Q10. Potential discount opportunities:
-- high-MRP items with no discount
SELECT category, product_name, mrp_inr, selling_price_inr
FROM vw_zepto_analytics
WHERE discount_percent = 0
ORDER BY mrp_inr DESC
LIMIT 20;

-- Q11. Price spread by category
SELECT category,
       ROUND(MIN(selling_price_inr), 2) AS min_selling_price_inr,
       ROUND(AVG(selling_price_inr), 2) AS avg_selling_price_inr,
       ROUND(MAX(selling_price_inr), 2) AS max_selling_price_inr
FROM vw_zepto_analytics
GROUP BY category
ORDER BY avg_selling_price_inr DESC;

-- Q12. Inventory weight by category (only known weights)
SELECT category,
       SUM(weight_g * available_quantity) AS estimated_inventory_weight_g,
       ROUND(SUM(weight_g * available_quantity) / 1000.0, 2)
           AS estimated_inventory_weight_kg
FROM vw_zepto_analytics
WHERE weight_g > 0
GROUP BY category
ORDER BY estimated_inventory_weight_kg DESC;

-- =========================================================
-- 4. FINAL QUALITY CHECKS
-- =========================================================
SELECT data_quality_status, COUNT(*) AS row_count
FROM zepto_clean
GROUP BY data_quality_status;

SELECT duplicate_flag, COUNT(*) AS row_count
FROM zepto_clean
GROUP BY duplicate_flag;

SELECT COUNT(*) AS raw_row_count FROM zepto_raw;
SELECT COUNT(*) AS clean_row_count FROM zepto_clean;
SELECT COUNT(*) AS analytics_row_count FROM vw_zepto_analytics;

/*
PORTFOLIO / INTERVIEW TALKING POINTS
- The dataset is a catalog/inventory snapshot; it has no order date, order ID,
  units sold, customer, or transaction amount. Therefore actual revenue,
  sales trends, customer retention, and product demand cannot be calculated.
- estimated_inventory_value_inr is an estimate: current selling price multiplied
  by available quantity. It is not revenue.
- Repeated product names are not automatically duplicates; products can occur
  in multiple categories. Exact duplicate source rows (identical on all 9
  columns) are flagged with ROW_NUMBER() and excluded from the view, keeping
  the first occurrence, so totals are not double-counted.
- The 'quantity' source field is retained without assuming its business meaning.
  Confirm its definition before using it in KPIs.
*/
