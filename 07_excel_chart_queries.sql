/*
=====================================================================
 07_excel_chart_queries.sql
 Purpose: Reproduces, query by query, the five data tables behind the
          charts in AdventureWorks_Charts.xlsx (one query per sheet).
          Values, column names, row order and rounding are the same as
          in the workbook.
 Database: AdventureWorks2025

 HOW TO REFRESH THE WORKBOOK (SQL itself cannot draw charts):
   1. Run one query below in SSMS.
   2. In the Results grid: click the top-left corner, right-click,
      choose "Copy with Headers".
   3. In AdventureWorks_Charts.xlsx, paste into the cell given for
      that query. The chart on that sheet already points to those
      cells, so it updates by itself.
=====================================================================
*/

USE AdventureWorks2025;
GO

-- ---------------------------------------------------------------
-- Sheet 1_Rev_By_Territory  |  paste at cell A6 (headers in row 6)
-- Chart: Revenue by Territory (column chart)
-- ---------------------------------------------------------------
SELECT
    st.Name AS Territory,
    COUNT(DISTINCT soh.SalesOrderID) AS TotalOrders,
    CAST(ROUND(SUM(soh.TotalDue), 2) AS DECIMAL(18,2)) AS TotalRevenue
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY st.Name
ORDER BY SUM(soh.TotalDue) DESC;
GO

-- ---------------------------------------------------------------
-- Sheet 2_Rev_By_Product  |  paste at cell A7 (headers in row 7)
-- Chart: Share of product sales by category (donut chart)
-- PctOfTotal is a fraction (0.8617 = 86.17%), share of LineTotal
-- ---------------------------------------------------------------
WITH CategoryRevenue AS (
    SELECT
        pc.Name AS Category,
        SUM(sod.LineTotal) AS CategoryTotal
    FROM Sales.SalesOrderDetail sod
    JOIN Production.Product p ON sod.ProductID = p.ProductID
    JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
    GROUP BY pc.Name
)
SELECT
    Category,
    CAST(ROUND(CategoryTotal, 2) AS DECIMAL(18,2)) AS CategoryRevenue,
    CAST(ROUND(CategoryTotal / SUM(CategoryTotal) OVER (), 4) AS DECIMAL(6,4)) AS PctOfTotal
FROM CategoryRevenue
ORDER BY CategoryTotal DESC;
GO

-- ---------------------------------------------------------------
-- Sheet 3_Yearly_Revenue  |  paste at cell A8 (headers in row 8)
-- Chart: Yearly revenue trend (column chart)
-- A * after the year marks a partial year (first and last year of data)
-- ---------------------------------------------------------------
WITH Yearly AS (
    SELECT
        YEAR(OrderDate) AS OrderYear,
        COUNT(*)        AS TotalOrders,
        SUM(TotalDue)   AS TotalRevenue
    FROM Sales.SalesOrderHeader
    GROUP BY YEAR(OrderDate)
),
Bounds AS (
    SELECT YEAR(MIN(OrderDate)) AS FirstYear, YEAR(MAX(OrderDate)) AS LastYear
    FROM Sales.SalesOrderHeader
)
SELECT
    CAST(y.OrderYear AS VARCHAR(4))
        + CASE WHEN y.OrderYear IN (b.FirstYear, b.LastYear) THEN '*' ELSE '' END AS [Year],
    y.TotalOrders,
    CAST(ROUND(y.TotalRevenue, 2) AS DECIMAL(18,2)) AS TotalRevenue
FROM Yearly y
CROSS JOIN Bounds b
ORDER BY y.OrderYear;
GO

-- ---------------------------------------------------------------
-- Sheet 4_Order_vs_Avg  |  paste at cell A7 (headers in row 7)
-- Chart: Order volume (bars) vs average order value (line) by quarter
-- ---------------------------------------------------------------
WITH QuarterlyOrders AS (
    SELECT
        YEAR(OrderDate) AS OrderYear,
        DATEPART(QUARTER, OrderDate) AS OrderQuarter,
        TotalDue
    FROM Sales.SalesOrderHeader
)
SELECT
    CAST(OrderYear AS VARCHAR(4)) + '-Q' + CAST(OrderQuarter AS VARCHAR(1)) AS [Quarter],
    COUNT(*) AS OrderVolume,
    CAST(ROUND(AVG(TotalDue), 2) AS DECIMAL(18,2)) AS AvgOrderValue
FROM QuarterlyOrders
GROUP BY OrderYear, OrderQuarter
ORDER BY OrderYear, OrderQuarter;
GO

-- ---------------------------------------------------------------
-- Sheet 5_Avg_By_Customer  |  paste at cell A7 (headers in row 7)
-- Chart: Average order value, reseller vs individual (bar chart)
-- ---------------------------------------------------------------
SELECT
    CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END AS CustomerType,
    COUNT(DISTINCT soh.SalesOrderID) AS TotalOrders,
    CAST(ROUND(AVG(soh.TotalDue), 2) AS DECIMAL(18,2)) AS AvgOrderValue
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
GROUP BY CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END
ORDER BY AVG(soh.TotalDue) DESC;
GO
