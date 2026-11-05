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
-- LINES TERMINATED BY '\\n'
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
