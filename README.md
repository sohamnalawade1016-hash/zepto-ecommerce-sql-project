# Zepto Product & Inventory Analytics (MySQL)

An exploratory SQL project on a Zepto product and inventory snapshot. It profiles the catalog, finds and fixes data-quality problems, and answers 12 business questions on pricing, discounts, stock availability and estimated inventory value.

**Tools:** MySQL 8.0+ (Workbench), SQL (CTEs, window functions, views)

## Headline findings
- 3,732 rows collapse to **1,800 unique products**. The same products are listed under several category labels.
- **87.94%** of unique products are in stock; the average discount is only **7.72%** (max 51%).
- **Fruits & Vegetables** carry the deepest average discount (15.46%, about 2× the overall average).
- About **30%** of products (536 of 1,800) have no discount at all.
- **Biscuits** has the lowest in-stock rate (71.43%).

## Dataset profile
- 3,732 rows, 9 source columns, no NULLs
- 14 category labels but only **9 distinct product lists** (e.g. Cooking Essentials and Munchies list the same 514 products)
- 1,800 unique products after removing category-driven repeats and invalid rows
- 2 exact duplicate pairs (the same Listerine mouthwash row, duplicated within Personal Care and within Paan Corner)
- 1 row with zero MRP; 4 rows with zero weight
- Prices are in paise (divided by 100 to report INR)

## Important interpretation
This is a catalog/inventory **snapshot**, not a sales table. It has no order IDs, dates, units sold or customers, so revenue, demand and sales trends cannot be measured. `selling price × available quantity` is an **estimated inventory value**, not revenue.

## Method
1. **Raw layer** (`zepto_raw`): source data untouched.
2. **Clean layer** (`zepto_clean`): paise → INR, trimmed names, quality flags (`data_quality_status`, `weight_missing_flag`, `duplicate_flag`). Duplicates are flagged with `ROW_NUMBER()` over all 9 columns, never deleted and never matched on name alone.
3. **Views:** `vw_zepto_analytics` (valid, de-duplicated rows) and `vw_zepto_unique_products` (one row per product, ignoring category).
4. **Thresholds come from the data**, not guesses (measured on the 3,729-row view):

| Metric | Min | P25 | Median | P75 | P90 | Max |
|---|---|---|---|---|---|---|
| MRP (₹) | 10 | 60 | 110 | 200 | 315 | 2,600 |
| Discount (%) | 0 | 0 | 6 | 10 | n/a | 51 |
| Weight (g) | 1 | 100 | 230 | 450 | n/a | 10,000 |

   "High MRP" = above P75 (₹200); "low discount" = below the median (6%); weight segments use the quartiles.

## Key insights
Product-level questions (Q1–Q3, Q6–Q8, Q10) use unique products. Category-level questions (Q4, Q5, Q9, Q11, Q12) describe category *listings* because labels overlap.

**Q1. Snapshot.** Of 1,800 unique products, 87.94% are in stock (about 1 in 8 is unavailable). The average discount is 7.72% against a maximum of 51%, and the average MRP is ₹153.16, with a maximum of ₹2,600.

**Q2. Best discounts.** The deepest discount is 51% (Dukes Waffy Wafers, ₹45 → ₹22), about 6.6× the average. The top 10 are all 50–51% and come from three brands (Dukes, RRO, Moi Soi), which suggests brand-level promotions rather than category-wide discounting.

**Q3. Premium items out of stock.** The priciest out-of-stock product is Patanjali Cow's Ghee (₹565), far below the catalog's top MRP of ₹2,600, so the most expensive items are all in stock. Meats, Fish & Eggs has 5 of the 20 priciest out-of-stock products, the most of any category despite being the smallest (63 products).

**Q4. Inventory value by category.** Category totals cannot be ranked reliably: Cooking Essentials and Munchies both show ₹337,369, Paan Corner and Personal Care both show ₹270,039, and three categories tie at ₹224,385, because the same products sit under several labels. Among categories with no twin, Home & Cleaning is highest at ₹122,661. Values are estimated inventory value, not revenue.

**Q5. Average discount by category.** Fruits & Vegetables has the highest average discount at 15.46%, about 2× the overall 7.72%. Meats, Fish & Eggs is next at 11.03%. Both have no twin category, so the result is reliable. Home & Cleaning is lowest at 5.70%.

**Q6. High MRP, low discount.** 153 unique products (8.5% of 1,800) have an MRP above ₹200 and a discount below 6%. The duplicated view gave 332, overstating the count by about 2.2×, which shows why deduplication mattered.

**Q7. Price per gram.** Fresh vegetables and staples are cheapest per gram: 12 of the cheapest 20 are fruit and vegetables and 5 are salt or atta. Three results are not real (Vicks cough drops at 1,160g for ₹20, Shubh kart dhoop, cotton wicks "1000n"), because `weight_g` holds a piece count for some non-weight items. Price per gram is only valid for items sold by weight.

**Q8. Pack-weight split.** Of 1,798 unique products with a known weight, the largest segment is 100–229g (555 products, 30.87%) and the smallest is 230–449g (20.47%). About half of all products (51%) weigh 100–449g. Products under 100g make up 22.25%, slightly below the 25% a quartile split predicts, so the quartile cutoffs from the full data broadly hold on unique products. Because the segments are quartile-based, a roughly even split is expected; the meaningful finding is that the typical pack is small to medium.

**Q9. In-stock rate by category.** Biscuits has the lowest in-stock rate at 71.43% (42 of 147 products out of stock), about 16.5 points below the 87.94% overall rate. Biscuits has no twin category, so this is a reliable signal; twinned categories such as Beverages and Dairy (both 78.29%) are one data point counted twice.

**Q10. No-discount products.** 536 of 1,800 products (about 30%) have a zero discount. The highest-MRP ones are cooking oils (Saffola Gold ₹1,240, Dhara ₹1,050), infant formula and L'Oreal hair color. Why these carry no discount cannot be determined without sales data.

**Q11. Price spread.** Among categories without a twin, Meats, Fish & Eggs has the highest average selling price (₹164.10) and Fruits & Vegetables the lowest (₹39.84). The widest spread is in Cooking Essentials and Munchies, where the maximum (₹1,399) is about 9.93× the average (₹140.83): a few premium items among cheap staples. Paan Corner and Personal Care show the same average (₹189.90) because both labels list the same 344 products.

**Q12. Inventory weight.** Cooking Essentials and Munchies both show 1,404.65 kg because they list the same products. Among categories with no twin, Home & Cleaning is heaviest at 373.16 kg and Meats, Fish & Eggs lightest at 48.02 kg. These weights are approximate, because `weight_g` holds a piece count for some non-weight items.

## Data-quality findings
- **Category duplication:** 3,212 of 3,732 rows repeat a product already listed under another category. Counting them inflates category totals by up to 3×.
- **Exact duplicates:** 2 pairs, flagged with `duplicate_flag` and excluded.
- **Zero MRP (1 row):** flagged `INVALID_MRP` and excluded from price analysis, not deleted.
- **Zero weight (4 rows):** flagged, not deleted, because their price, stock and discount data are still valid.
- **Weight column:** holds a piece count for some non-weight items (wicks, cough drops), which distorts price per gram and inventory weight.
- **Import:** the Workbench import wizard silently dropped 4 rows whose names are wrapped in doubled quotes (Maggi Magic Cubes). `LOAD DATA` handles them correctly.

## Limitations
- No sales, order or date data: no revenue, demand, trend or customer analysis.
- Category labels are unreliable, so category rankings are indicative only.
- `quantity` is retained without assuming its business meaning.
- Cutoffs (₹200, 6%, weight quartiles) are descriptive choices, not business rules.

## How to run
1. In MySQL Workbench run:
```sql
CREATE DATABASE IF NOT EXISTS zepto;
USE zepto;
CREATE TABLE zepto_raw (
    sku_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(120), name VARCHAR(200) NOT NULL,
    mrp_paise INT, discount_percent DECIMAL(5,2), available_quantity INT,
    selling_price_paise INT, weight_g INT, out_of_stock BOOLEAN, quantity INT,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```
2. Load the CSV with `LOAD DATA` (the Table Data Import Wizard drops rows with quoted names, and fails on the TRUE/FALSE column):
```sql
LOAD DATA LOCAL INFILE 'C:/path/to/zepto.csv'
INTO TABLE zepto_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(category, name, mrp_paise, discount_percent, available_quantity,
 selling_price_paise, weight_g, @oos, quantity)
SET out_of_stock = (UPPER(@oos) = 'TRUE');
SELECT COUNT(*) FROM zepto_raw;   -- expect 3732
```
3. Run `Zepto_final.sql` top to bottom. It builds the clean layer and both views, then runs the 12 queries.

## Files
- `zepto.csv`: original source data
- `Zepto.sql`: validation, clean layer, views and the 12 business queries
- `README.md`: this document
