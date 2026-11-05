# zepto-ecommerce-sql-project
Zepto E-Commerce SQL Analytics
Project overview
An exploratory SQL analytics project using a Zepto product and inventory snapshot. The objective is to assess product assortment, pricing, discounts, stock availability, and estimated inventory value.
Dataset profile
- 3,732 records and 9 source columns
- 14 product categories
- No NULL values in the supplied CSV
- 2 redundant exact duplicate rows (two duplicate pairs), flagged via `duplicate_flag` and excluded from the analytical view
- 1 record with zero MRP and zero selling price
- 4 records with zero weight
- Discount percentages agree with the MRP-to-selling-price calculation in the supplied data
- Stock status agrees with available quantity: out-of-stock rows have zero available quantity, and in-stock rows have positive available quantity
  
## Important interpretation
The source prices are stored in paise, so divide by 100 to express them in INR. The file is a catalog/inventory snapshot, not a sales transaction table. It does not contain order IDs, order dates, units sold, or customer records. Therefore, actual revenue, sales growth, customer behavior, and demand cannot be measured. selling price × available quantity is an estimate of current inventory value, not revenue.

Tools
- MySQL 8.0+
- CSV source data
  
Files
- zepto.csv — original source dataset
- Zepto_MySQL.sql — upgraded MySQL script with raw staging, validation, clean layer, analytical view, and business questions
- README.md — project documentation
  
How to run
1. Open MySQL Workbench and connect to your MySQL server.
2. Open Zepto_MySQL.sql and execute the setup section to create the database and zepto_raw table.
3. Use Table Data Import Wizard to import zepto.csv into zepto_raw. Map the nine CSV columns in their source order; do not map the generated sku_id or imported_at fields.
4. Execute the remaining SQL script sections in order.
5. Review the validation results, then run the business analysis queries.
The script drops and recreates its project tables and view at the beginning. Back up any work in tables with these names before rerunning it.

Business questions answered
1. What is the overall catalog and stock snapshot?
2. Which products have the highest discounts?
3. Which high-MRP products are out of stock?
4. Which categories hold the greatest estimated inventory value?
5. Which categories offer the highest average discounts?
6. Which products have high MRP but low discounts?
7. Which products offer the lowest price per gram?
8. How does the catalog split by product weight? (count and % per weight segment)
9. Which categories have the lowest in-stock rate?
10. Which high-MRP products have no discount?
11. How do selling prices vary by category?
12. Which categories have the greatest estimated inventory weight?

Method notes
- Thresholds in Q6 (high MRP, low discount) are chosen from the MRP and discount distributions (see the Q6-prep queries), not guessed.
- Duplicates are detected on all 9 source columns, never on product name alone.
