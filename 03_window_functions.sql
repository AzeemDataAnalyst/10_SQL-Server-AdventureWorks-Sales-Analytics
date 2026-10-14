/*
=====================================================================
 03_window_functions.sql
 Purpose: Demonstrate window functions - the #1 SQL skill interviewers
          look for in a Data Analyst. RANK, LAG/LEAD, running totals.
 Database: AdventureWorks2025
=====================================================================
*/

USE AdventureWorks2025;
GO

-- 1. Month-over-month sales growth (LAG)
WITH MonthlySales AS (
    SELECT
        YEAR(OrderDate)  AS SalesYear,
        MONTH(OrderDate) AS SalesMonth,
        SUM(TotalDue)    AS MonthlyRevenue
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    SalesYear,
    SalesMonth,
    MonthlyRevenue,
    LAG(MonthlyRevenue) OVER (ORDER BY SalesYear, SalesMonth) AS PrevMonthRevenue,
    CAST(
        (MonthlyRevenue - LAG(MonthlyRevenue) OVER (ORDER BY SalesYear, SalesMonth))
        * 100.0 / NULLIF(LAG(MonthlyRevenue) OVER (ORDER BY SalesYear, SalesMonth), 0)
    AS DECIMAL(6,2)) AS MoM_Growth_Pct
FROM MonthlySales
ORDER BY SalesYear, SalesMonth;
GO

-- 2. Running total of revenue through the year (SUM OVER)
SELECT
    YEAR(OrderDate)  AS SalesYear,
    MONTH(OrderDate) AS SalesMonth,
    SUM(TotalDue)    AS MonthlyRevenue,
    SUM(SUM(TotalDue)) OVER (
        PARTITION BY YEAR(OrderDate)
        ORDER BY MONTH(OrderDate)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningYearTotal
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY SalesYear, SalesMonth;
GO

-- 3. Top 3 products within each category by revenue (RANK via CTE)
WITH ProductRevenue AS (
    SELECT
        pc.Name AS Category,
        p.Name  AS Product,
        SUM(sod.LineTotal) AS Revenue
    FROM Sales.SalesOrderDetail sod
    JOIN Production.Product p ON sod.ProductID = p.ProductID
    JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
    GROUP BY pc.Name, p.Name
),
RankedProducts AS (
    SELECT
        Category, Product, Revenue,
        RANK() OVER (PARTITION BY Category ORDER BY Revenue DESC) AS RevenueRank
    FROM ProductRevenue
)
SELECT * FROM RankedProducts WHERE RevenueRank <= 3
ORDER BY Category, RevenueRank;
GO

-- 4. Salesperson ranking against quota (DENSE_RANK)
SELECT
    sp.BusinessEntityID,
    per.FirstName + ' ' + per.LastName AS SalesPersonName,
    sp.SalesYTD,
    sp.SalesQuota,
    DENSE_RANK() OVER (ORDER BY sp.SalesYTD DESC) AS PerformanceRank
FROM Sales.SalesPerson sp
JOIN Person.Person per ON sp.BusinessEntityID = per.BusinessEntityID
ORDER BY PerformanceRank;
GO
