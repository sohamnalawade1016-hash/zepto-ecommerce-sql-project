# Zepto E-Commerce Product & Inventory Analytics

An end-to-end analytics project using **MySQL 8.0+ and Power BI** to
explore a Zepto product-catalog and inventory snapshot. The project
covers data validation, cleaning, reusable analytical views, SQL
business questions, and an interactive Power BI dashboard.

> **Scope note:** This is a catalog/inventory snapshot, not a
> transaction or sales dataset. It supports product, pricing, discount,
> stock-availability and estimated-inventory analysis. It does not
> support actual revenue, demand, customer or time-trend analysis.

## Project at a glance

  -----------------------------------------------------------------------
  Area                                Details
  ----------------------------------- -----------------------------------
  Database                            MySQL 8.0+

  Visualization                       Microsoft Power BI

  Query language                      SQL

  Dashboard calculations              DAX

  SQL techniques                      CTEs, window functions,
                                      aggregations, CASE expressions,
                                      views

  Dataset                             3,732 source rows and 9 columns
  -----------------------------------------------------------------------

## Repository structure

``` text
Zepto-Ecommerce-Analytics/
├── Dataset/
│   └── zepto.csv
├── SQL/
│   └── Zepto.sql
├── PowerBI/
│   ├── Zepto_Ecommerce_Analytics.pbix
│   └── Dashboard_Screenshot.png
└── README.md
```

The filenames above are suggested repository names. Rename your local
files to match them before uploading, or update the paths in this
README. Only include the original CSV if its source permits
redistribution; otherwise provide instructions or a source link instead.

## Dataset profile and interpretation

The supplied CSV contains **3,732 rows and 9 columns**, with no missing
values in the uploaded copy.

The source includes category, product name, MRP, discount percentage,
available quantity, selling price, weight, out-of-stock status and a
`quantity` field. Prices in the SQL raw table are stored in paise and
converted to INR in the clean layer.

An important feature of this dataset is that category labels overlap:
the same products can appear under multiple category labels. Therefore
the SQL project creates two analytical views:

-   `vw_zepto_analytics`: valid, exact-duplicate-free **category
    listings**. This view contains 3,729 rows.
-   `vw_zepto_unique_products`: one row per unique product after
    ignoring category. This view contains 1,800 rows.

Use listing-level figures when describing category listings, and
unique-product figures when describing the deduplicated catalog. Do not
compare the two without stating which counting level is being used.

## Data preparation and SQL methodology

The SQL script (`Zepto.sql`) is organized into four practical stages:

1.  **Data validation and exploration** --- row counts, previews, NULL
    checks, category counts, stock checks, repeated names, exact
    duplicates and suspicious values.
2.  **Clean layer** --- preserves the raw table, trims text, converts
    paise to INR, adds data-quality flags and flags exact duplicate rows
    using `ROW_NUMBER()`.
3.  **Analytical views** --- creates reusable listing-level and
    unique-product views.
4.  **Business analysis and quality checks** --- runs 12 business
    questions and validates row counts and duplicate flags.

### Data-quality decisions

-   Exact duplicate rows are identified across all nine source fields;
    later copies are flagged and excluded from the analytical view.
-   Rows with invalid MRP are flagged and excluded from the valid
    analytical view.
-   Zero or missing weights are flagged; they are not automatically
    deleted because price and stock information may still be useful.
-   Product names appearing in multiple categories are not automatically
    treated as exact duplicates.
-   The source `quantity` field is retained without assigning it an
    assumed business meaning.

## Key findings

The project intentionally uses both unique-product and category-listing
views. The figures below are tied to their respective level.

### Unique-product findings

-   The cleaned unique-product view contains **1,800 products**.
-   **87.94%** of unique products are in stock.
-   Average discount is **7.72%**; the maximum discount is 51%.
-   **536 of 1,800** unique products have no discount.
-   Fruits & Vegetables has the highest average discount at **15.46%**.
-   Biscuits has the lowest in-stock rate at **71.43%**.

### Category-listing and dashboard findings

The Power BI dashboard uses the 3,729-row `vw_zepto_analytics`
listing-level view:

  KPI / finding              Dashboard result
  ------------------------ ------------------
  Total product listings                3,729
  In-stock listings                     3,276
  Out-of-stock listings                   453
  Out-of-stock share                   12.15%
  Average discount                      7.62%
  Category labels                          14

Additional category-level observations:

-   Fruits & Vegetables has the highest average discount at **15.46%**.
-   Cooking Essentials and Munchies each show an estimated inventory
    value of approximately **₹337K**.
-   Cooking Essentials and Munchies each contain **514 listings**.

**Category caveat:** The source contains overlapping category lists.
Cooking Essentials and Munchies contain the same 514-product list, so
their matching counts and estimated inventory values are not independent
category inventories. Category comparisons should be interpreted
cautiously.

## Power BI dashboard

The Power BI report contains two pages:

### Page 1 --- Zepto E-Commerce Analytics

-   KPI cards for total categories, total product listings, in-stock
    listings, out-of-stock listings and average discount.
-   Product listings by category.
-   Stock availability distribution with readable "In Stock" and "Out of
    Stock" labels.
-   Average discount by category.
-   Estimated inventory value by category.
-   Category slicer to interactively filter the report.

### Page 2 --- Business Insights

-   Key findings from the analysis.
-   Business recommendations based on stock availability, discounting
    and inventory.
-   Page navigation between the dashboard and insights page.

The dashboard's 3,729 total is a **listing count**, not a count of
unique products. Its 87.85% in-stock share and 7.62% average discount
are calculated at listing level. The README's 87.94% and 7.72% figures
are calculated at unique-product level; both sets can be correct because
they use different views.

## Business recommendations

1.  Investigate out-of-stock listings and establish appropriate
    minimum-stock thresholds.
2.  Review discount effectiveness in Fruits & Vegetables before changing
    pricing. Discount percentage alone does not establish profitability
    or sales impact.
3.  Monitor inventory value across categories, while accounting for
    overlapping category lists.
4.  Consider reorder alerts for products with low availability, once
    operational reorder rules are defined.

These are recommendations suggested by the snapshot, not proven causes
or measured sales outcomes.

## Limitations

-   No order IDs, transaction dates, units sold or customer records are
    present.
-   Actual revenue, demand, customer behaviour, sales trends and
    profitability cannot be calculated.
-   Category labels overlap and are not reliable independent product
    groups.
-   `estimated_inventory_value_inr` is calculated as selling price
    multiplied by available quantity. It is an estimated inventory
    value, **not revenue**.
-   `weight_g` contains piece counts for some non-weight products, so
    price-per-gram and inventory-weight results require caution.
-   The meaning of the source `quantity` field is not assumed.
-   The dashboard and unique-product README metrics use different
    counting levels; always label the level.

## How to run the SQL project

The uploaded `Zepto.sql` script expects a MySQL database named `zepto`
and a preloaded `zepto_raw` table with 3,732 source rows. The raw table
must include a `sku_id` primary key and the fields referenced in the
script.

1.  Create/select the database:

``` sql
CREATE DATABASE IF NOT EXISTS zepto;
USE zepto;
```

2.  Create and load `zepto_raw` using the supplied CSV. The raw table
    needs these columns:

``` text
sku_id, category, name, mrp_paise, discount_percent,
available_quantity, selling_price_paise, weight_g,
out_of_stock, quantity
```

The CSV uses different header names (`Category`, `mrp`,
`discountPercent`, `availableQuantity`, `discountedSellingPrice`,
`weightInGms`, `outOfStock`). Map those source fields to the raw-table
columns during import. Convert source prices to paise if the CSV prices
are in rupees; confirm the source units before loading.

3.  Confirm the import:

``` sql
SELECT COUNT(*) AS raw_rows FROM zepto_raw;
```

The expected source row count is **3,732**.

4.  Open `SQL/Zepto.sql` and run it from top to bottom. It begins with
    `USE zepto;` and expects the raw table to exist. The script rebuilds
    `zepto_clean` and the two analytical views; it does not create or
    import the raw table.

5.  Connect Power BI to the MySQL analytical view used for the dashboard
    and refresh the report. Keep the listing-level versus unique-product
    distinction clear in labels and documentation.

## Files

-   `Dataset/zepto.csv` --- original source dataset, only if
    redistribution is permitted.
-   `SQL/Zepto.sql` --- validation, cleaning, analytical views, 12
    business queries and quality checks.
-   `PowerBI/Zepto_Ecommerce_Analytics.pbix` --- interactive Power BI
    report.
-   `PowerBI/Dashboard_Screenshot.png` --- exported screenshot of the
    report.
-   `README.md` --- project overview, methodology, findings and
    limitations.
