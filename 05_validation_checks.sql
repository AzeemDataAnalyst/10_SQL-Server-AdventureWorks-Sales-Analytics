/*
=====================================================================
 05_validation_checks.sql
 Purpose: Validate the claims made in the report / README before
          presenting them. Each check says which claim it supports.
 Database: AdventureWorks2025
 Run these in SSMS and update the report with the ACTUAL results.
=====================================================================
*/

USE AdventureWorks2025;
GO

-- 0. Which SQL Server version is actually running? (use this in the report's "Tools" line)
SELECT @@VERSION AS SqlServerVersion;
GO

-- 1. Data period (the answer to "why is a 2025 project showing older dates?")
--    AdventureWorks2025 = database VERSION. Order data period = result of this query.
SELECT MIN(OrderDate) AS FirstOrder, MAX(OrderDate) AS LastOrder
FROM Sales.SalesOrderHeader;
GO

-- 2. Is June 2025 really incomplete? Orders per day in the last month of data.
--    (Supports/rejects the "-97.5% MoM in Jun 2025 is a partial month" explanation.)
SELECT CAST(OrderDate AS DATE) AS OrderDay, COUNT(*) AS Orders, SUM(TotalDue) AS Revenue
FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2025-05-01'
GROUP BY CAST(OrderDate AS DATE)
ORDER BY OrderDay;
GO

-- 3. Monthly orders for the last 8 months (see where the drop starts)
SELECT YEAR(OrderDate) AS Yr, MONTH(OrderDate) AS Mth,
       COUNT(*) AS Orders, SUM(TotalDue) AS Revenue
FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2024-11-01'
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY Yr, Mth;
GO

-- 4. Quarter x Customer type: did the AOV drop come from a shift in customer mix?
--    (Supports/rejects Finding 4 - "growth is coming from individual buyers".)
SELECT
    YEAR(soh.OrderDate) AS OrderYear,
    DATEPART(QUARTER, soh.OrderDate) AS OrderQuarter,
    CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END AS CustomerType,
    COUNT(*) AS Orders,
    AVG(soh.TotalDue) AS AvgOrderValue,
    SUM(soh.TotalDue) AS Revenue
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
GROUP BY YEAR(soh.OrderDate), DATEPART(QUARTER, soh.OrderDate),
         CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END
ORDER BY OrderYear, OrderQuarter, CustomerType;
GO

-- 5. Like-for-like growth: Jan-Jun 2024 vs Jan-Jun 2025
SELECT
    YEAR(OrderDate) AS OrderYear,
    COUNT(*) AS Orders,
    SUM(TotalDue) AS Revenue
FROM Sales.SalesOrderHeader
WHERE (OrderDate >= '2024-01-01' AND OrderDate < '2024-07-01')
   OR (OrderDate >= '2025-01-01' AND OrderDate < '2025-07-01')
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;
GO

-- 6. Territory view with AOV and customer mix
--    (Germany vs Northeast/Central/Southeast: low revenue can just mean a different customer mix.)
SELECT
    st.Name AS Territory,
    COUNT(*) AS Orders,
    SUM(soh.TotalDue) AS Revenue,
    AVG(soh.TotalDue) AS AvgOrderValue,
    SUM(CASE WHEN c.StoreID IS NOT NULL THEN 1 ELSE 0 END) AS ResellerOrders,
    CAST(100.0 * SUM(CASE WHEN c.StoreID IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS ResellerOrderPct
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
GROUP BY st.Name
ORDER BY Revenue DESC;
GO

-- 7. Which "revenue" are we using? TotalDue includes tax + freight; LineTotal does not.
--    The category % (Bikes 86.17%) is based on LineTotal, so state it as "% of product sales".
SELECT
    (SELECT SUM(TotalDue)  FROM Sales.SalesOrderHeader) AS TotalDue_Revenue,
    (SELECT SUM(SubTotal)  FROM Sales.SalesOrderHeader) AS SubTotal_ProductSales,
    (SELECT SUM(LineTotal) FROM Sales.SalesOrderDetail) AS LineTotal_ProductSales;
GO
