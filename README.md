# Zepto E-Commerce Product & Inventory Analytics

An end-to-end analytics project using **MySQL 8.0+ and Microsoft Power
BI** to explore a Zepto product-catalog and inventory snapshot. The
project covers data validation, data cleaning, reusable analytical
views, SQL-based business analysis, and an interactive Power BI report.

> **Scope note:** This is a product-catalog and inventory snapshot, not
> a transaction or sales dataset. It supports product, pricing,
> discount, stock-availability, and estimated-inventory analysis. It
> does not support actual revenue, demand, customer, or time-trend
> analysis.

## Project at a glance

  -----------------------------------------------------------------------
  Area                                Details
  ----------------------------------- -----------------------------------
  Database                            MySQL 8.0+

  Visualization                       Microsoft Power BI

  Query language                      SQL

  Dashboard calculations              DAX

  SQL concepts                        Data validation, cleaning, CTEs,
                                      window functions, aggregations,
                                      CASE expressions, and views

  Source dataset                      3,732 rows and 9 columns
  -----------------------------------------------------------------------

## Repository structure

``` text
zepto-ecommerce-sql-project/
├── Dataset/
│   └── zepto.csv
├── SQL/
│   └── Zepto.sql
├── Power BI/
│   ├── Business Insights.png
│   ├── Zepto E-Commerce Analytics.png
│   └── zepto.pbix
└── README.md
```

## Dataset overview

The uploaded source CSV contains **3,732 rows and 9 columns**, with no
missing values in the inspected copy.

The dataset includes product category and name, MRP, discount
percentage, available quantity, selling price, weight, out-of-stock
status, and a `quantity` field. The SQL workflow converts price values
from paise to INR in the clean layer.

### Important counting distinction

The project uses two analytical levels:

-   `vw_zepto_analytics`: valid category listings, containing **3,729
    rows**.
-   `vw_zepto_unique_products`: unique products after removing repeated
    product names across categories, containing **1,800 rows**.

The same product can appear in more than one category. Therefore,
category-listing counts and unique-product counts are different and
should always be labelled clearly.

## SQL workflow

The SQL work is organized into four stages:

1.  **Data validation and exploration** --- checks row counts, NULL
    values, categories, stock status, repeated product names, exact
    duplicates, and suspicious values.
2.  **Data cleaning** --- preserves the raw data, cleans text fields,
    converts prices to INR, adds data-quality flags, and identifies
    exact duplicate rows.
3.  **Analytical views** --- creates reusable listing-level and
    unique-product views.
4.  **Business analysis and quality checks** --- answers business
    questions using SQL and checks the resulting data.

### Data-quality decisions

-   Exact duplicate rows are identified across the source fields and
    flagged.
-   Rows with invalid MRP are excluded from the valid analytical view.
-   Zero or missing weights are flagged rather than automatically
    deleted.
-   Products appearing in multiple categories are not automatically
    treated as exact duplicates.
-   The meaning of the source `quantity` field is not assumed.

## Key findings

### Category-listing level --- Power BI dashboard

The main dashboard uses the 3,729-row listing-level view.

  KPI                        Result
  ------------------------ --------
  Total product listings      3,729
  In-stock listings           3,276
  Out-of-stock listings         453
  Out-of-stock share         12.15%
  Average discount            7.62%
  Categories                     14

Additional observations:

-   Fruits & Vegetables has the highest average discount at **15.46%**.
-   Cooking Essentials and Munchies each show an estimated inventory
    value of approximately **₹337K**.
-   Cooking Essentials and Munchies each contain **514 product
    listings**.

### Unique-product level --- SQL analysis

The unique-product view contains **1,800 products**.

-   **87.94%** of unique products are in stock.
-   Average discount is **7.72%**.
-   **536 of 1,800** unique products have no discount.
-   Fruits & Vegetables has the highest average discount at **15.46%**.
-   Biscuits has the lowest in-stock rate at **71.43%**.

The listing-level and unique-product percentages differ because they are
calculated using different views. Both should be reported with their
counting level.

### Category interpretation caveat

The source contains overlapping category lists. Cooking Essentials and
Munchies contain the same 514-product list, so their matching counts and
estimated inventory values should not be interpreted as two independent
inventories. Category comparisons require this limitation to be kept in
mind.

## Power BI dashboard

The Power BI report contains two pages.

### Page 1 --- Zepto E-Commerce Analytics

-   KPI cards for total categories, total product listings, in-stock
    listings, out-of-stock listings, and average discount.
-   Product listings by category.
-   Stock availability distribution.
-   Average discount by category.
-   Estimated inventory value by category.
-   Category slicer to filter the report interactively.

### Page 2 --- Business Insights

-   Key findings from the analysis.
-   Business recommendations related to stock availability, discounts,
    and inventory.
-   Separate report page for presenting the main takeaways.

### Dashboard Preview

![Zepto Analytics
Dashboard](Power%20BI/Zepto%20E-Commerce%20Analytics.png)

### Business Insights

![Business Insights](Power%20BI/Business%20Insights.png)

## Business recommendations

1.  Investigate out-of-stock listings and establish appropriate
    minimum-stock thresholds.
2.  Review discount effectiveness in Fruits & Vegetables before changing
    pricing. Discount percentage alone does not establish profitability
    or sales impact.
3.  Monitor estimated inventory value across categories while accounting
    for overlapping category lists.
4.  Consider reorder alerts for products with low availability once
    operational reorder rules are defined.

These recommendations are based on the available catalog and inventory
snapshot. They are not proof of sales impact or the causes of stockouts.

## Project limitations

-   The dataset does not contain order IDs, transaction dates, units
    sold, or customer records.
-   Actual revenue, demand, customer behaviour, sales trends, and
    profitability cannot be calculated.
-   Category labels overlap and should not be treated as independent
    product groups.
-   Estimated inventory value is calculated from selling price and
    available quantity. It is **not revenue**.
-   Some values in the weight field may represent piece counts rather
    than physical weight.
-   The source `quantity` field is retained without assuming its
    business meaning.
-   Dashboard metrics use category listings, while some SQL metrics use
    unique products. The counting level must be stated.

## How to run the SQL project

The SQL script is intended for MySQL and expects a database named
`zepto` and a preloaded `zepto_raw` table. The script does not create or
import the original raw table.

1.  Create and select the database:

``` sql
CREATE DATABASE IF NOT EXISTS zepto;
USE zepto;
```

2.  Import the CSV into a table named `zepto_raw`. Map the source CSV
    headers to the column names expected by the SQL script. Confirm the
    expected column names by reviewing the `CREATE TABLE` assumptions
    and column references in the script.

3.  Check the imported row count:

``` sql
SELECT COUNT(*) AS raw_rows
FROM zepto_raw;
```

The original CSV contains **3,732 rows**.

4.  Open the SQL script in the `SQL` folder and execute it in the order
    written. It creates the clean table and analytical views used for
    the analysis.

5.  Connect Power BI to the relevant MySQL analytical view and refresh
    the report.

## Tools used

-   **MySQL** --- data validation, cleaning, querying, and analytical
    views.
-   **Power BI** --- interactive dashboard and business insights.
-   **DAX** --- measures and KPI calculations.

------------------------------------------------------------------------

*This project demonstrates a practical SQL-to-Power-BI analytics
workflow using a product and inventory dataset.*
