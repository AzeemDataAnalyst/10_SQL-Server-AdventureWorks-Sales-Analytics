# 🏢 AdventureWorks Sales Analytics — SQL Server (T-SQL)

End-to-end SQL Server analytics project on Microsoft's official **AdventureWorks** sample database — covering data exploration, business-question-driven analysis, window functions, CTEs, stored procedures, and reporting views.



## 📌 Project Overview

I built this project to analyze AdventureWorks' sales, product, customer, and territory data the way a Sales Operations or BI team actually would — finding top products, comparing regional performance, tracking month-over-month growth, and ranking salespeople against quota. Beyond one-off SELECT statements, I also packaged the recurring logic into a parameterized stored procedure and a set of reporting views, so the work is reusable rather than throwaway.

## 🗃️ Dataset

**AdventureWorks2025** (Microsoft's official sample OLTP database for SQL Server).

Key tables used:

| Schema.Table | Purpose |
|---|---|
| `Sales.SalesOrderHeader` | Order-level data — order date, customer, territory, total due |
| `Sales.SalesOrderDetail` | Line-item data — product, quantity, unit price, line total |
| `Production.Product` | Product catalog — name, list price, standard cost, subcategory |
| `Production.ProductSubcategory` / `ProductCategory` | Product hierarchy |
| `Sales.Customer` | Links a customer to a person/store and territory |
| `Sales.SalesTerritory` | Region/country data, YTD sales |
| `Sales.SalesPerson` | Salesperson quota and performance |
| `Person.Person` | Customer and employee names |

**Download:** Microsoft's official backup file — [AdventureWorks sample databases](https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure).

## ⚙️ How to Run

1. Download `AdventureWorks2025.bak` (OLTP version — not the LT or DW editions) from the Microsoft link above.
2. In SSMS: right-click **Databases → Restore Database → Device →** select the `.bak` file → OK.
3. Open the scripts in `/scripts` in order (01 → 04) against the restored database. Run `05_validation_checks.sql` to re-verify the key claims below.
4. Run `/stored_procedures/sp_monthly_sales_report.sql` and `/views/reporting_views.sql` to create the reusable objects.

## 📂 Project Structure

```
AdventureWorks-SQL-Analytics/
│
├── README.md
├── scripts/
│   ├── 01_exploratory_analysis.sql
│   ├── 02_business_questions.sql
│   ├── 03_window_functions.sql
│   ├── 04_cte_advanced_queries.sql
│   └── 05_validation_checks.sql
├── stored_procedures/
│   └── sp_monthly_sales_report.sql
├── views/
│   └── reporting_views.sql
└── screenshots/
    └── (query result screenshots go here)
```

## ❓ Business Questions Answered

| # | Question | SQL Concept Used |
|---|---|---|
| 1 | What are total sales by year and by territory? | `GROUP BY`, `JOIN` |
| 2 | Who are the top 10 best-selling products? | `TOP N`, `ORDER BY`, `JOIN` |
| 3 | What is each product category's % contribution to product sales? | CTE, `SUM() OVER()` ratio |
| 4 | What is the month-over-month sales growth rate? | `LAG()` window function |
| 5 | How do salespeople rank by YTD sales (quota shown alongside)? | `DENSE_RANK()` |
| 6 | What is the running total of sales through the year? | `SUM() OVER()` |
| 7 | Which customers haven't ordered in the last 12 months? | CTE + `DATEDIFF` |
| 8 | What is the average order value trend over time? | CTE, `DATEPART` |

## 🛠️ Advanced SQL Concepts Demonstrated

- **Window Functions:** `RANK()`, `DENSE_RANK()`, `LAG()`, running totals with `SUM() OVER()`
- **CTEs (Common Table Expressions):** multi-step readable queries, customer churn analysis
- **Stored Procedures:** parameterized monthly sales report (`sp_monthly_sales_report`)
- **Views:** a reusable `vw_SalesSummary` and `vw_ProductPerformance` for reporting tools (Power BI/Excel) to connect to
- **Multi-table joins (up to 4 tables in one query):** orders, order details, products, categories, customers, territories

## 💡 Key Insights

Numbers below are from my actual run against AdventureWorks2025. *("2025" is the database version; the order data spans 2022-05-30 to 2025-06-29 — 31,465 orders, ~$123.2M total revenue, AOV ≈ $3,916.)*

- **Revenue is heavily concentrated in one territory.** Southwest alone brought in **$27.15M** (6,224 orders) — about 48% more than the #2 territory, Canada ($18.4M). The bottom territory, Germany, generated $5.48M — but Germany is individual-heavy (~$2K AOV), whereas Central/Northeast/Southeast earn ~$8M from only 350–490 large reseller orders each, so I'd compare territories by AOV and customer mix (not revenue alone) before calling any of them underperformers.
- **The business is almost entirely bike-driven.** The Bikes category alone accounts for **86.17% of product sales** ($94.65M of $109.85M line-item sales; before tax and freight), with Components a distant second at 10.74%. Clothing and Accessories combined are about 3% — a real concentration risk if bike demand ever softens.
- **Store/Reseller customers are far more valuable per order than individuals.** Resellers average **$23,850** per order (3,806 orders) vs. just **$1,173** for individual customers (27,659 orders) — nearly 20x higher AOV, confirming these two segments need to be reported and targeted separately.
- **Order volume grew sharply, but AOV dropped in a step, not gradually.** Quarterly orders grew from 264 (2022-Q2) to ~5,400–6,300 per quarter from 2024-Q3 onward. Average order value held at ~$7,500 through 2024-Q2, then fell to ~$2,700 in 2024-Q3 and ~$1,480 by 2025-Q2. This is consistent with a shift toward high-volume individual buyers, which `05_validation_checks.sql` (quarter × customer type) is designed to confirm.
- **1,075 customers (out of ~19,100) have gone quiet for 12+ months** — a concrete, ready-to-use churn/win-back list, with the most dormant customer not having ordered in 37 months.
- **2024 was the best full year**: 14,244 orders and ~$49.0M in revenue, +38% vs 2023 ($35.5M). (2022 is a partial year from 30 May, so a 2022→2024 "3x" comparison would be misleading.) Like-for-like, H1 2025 (~$22.4M) is only ~6% above H1 2024 (~$21.0M) even though order count roughly quadrupled — revenue growth has slowed because of the lower AOV.
- Month-over-month revenue growth swung as high as **+285%** (Jun 2022, off a base of only ~2 days of May data) and as low as **-98%** (Jun 2025). The data ends on 29 June, so June 2025 is nearly complete — the cause of that drop should be checked against daily order counts (see `05_validation_checks.sql`) before reacting to it.

- **The reporting views tie out exactly with the raw queries** — `vw_SalesSummary` returns exactly 31,465 rows (matching the raw order count) and `vw_ProductPerformance`'s top product matches the raw top-seller query dollar-for-dollar ($4.40M, Mountain-200 Black 38). This cross-checking is exactly what I'd do before handing a view off to a BI team.
- **Customer segmentation confirms the top-spender finding**: the highest-value customer under the VIP/Recency/Monetary segmentation is the same customer (ID 29818, $989,184 spend) identified independently in the top-10-customers query — a good consistency check between two different analyses.
- **The stored procedure's monthly breakdown works as designed**: for May 2022 (the first partial month in the data), Southeast led with 10 orders / $156,696.79, followed by Canada and Southwest — a good example of the report being usable even on a thin, early slice of data, not just full months.

## 🔗 Connect This to Power BI/Excel

The views in `/views/reporting_views.sql` are designed to be connected directly to Power BI or Excel as a data source — showing an end-to-end pipeline: **SQL Server (data) → Views (semantic layer) → Power BI/Excel (visualization)**.

## 📬 Author

**Azeem Khan** — Data Analyst
📧 azeemkhanmev2@gmail.com | 🔗 [LinkedIn](https://www.linkedin.com/in/azeem--khan/) | 💻 [GitHub](https://github.com/AzeemDataAnalyst)
