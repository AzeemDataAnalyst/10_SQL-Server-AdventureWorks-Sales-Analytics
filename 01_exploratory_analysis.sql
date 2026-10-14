/*
=====================================================================
 01_exploratory_analysis.sql
 Purpose: First-pass exploration of the AdventureWorks sales data
 Database: AdventureWorks2025
=====================================================================
*/

USE AdventureWorks2025;
GO

-- 1. Basic row counts to understand data volume
SELECT 'SalesOrderHeader' AS TableName, COUNT(*) AS [RowCount] FROM Sales.SalesOrderHeader
UNION ALL
SELECT 'SalesOrderDetail', COUNT(*) FROM Sales.SalesOrderDetail
UNION ALL
SELECT 'Product', COUNT(*) FROM Production.Product
UNION ALL
SELECT 'Customer', COUNT(*) FROM Sales.Customer;
GO

-- 2. Date range of the data
SELECT
    MIN(OrderDate) AS EarliestOrder,
    MAX(OrderDate) AS LatestOrder,
    DATEDIFF(DAY, MIN(OrderDate), MAX(OrderDate)) AS TotalDaysCovered
FROM Sales.SalesOrderHeader;
GO

-- 3. Check for NULLs in key columns (data quality check)
SELECT
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Null_CustomerID,
    SUM(CASE WHEN TerritoryID IS NULL THEN 1 ELSE 0 END) AS Null_TerritoryID,
    SUM(CASE WHEN TotalDue IS NULL THEN 1 ELSE 0 END) AS Null_TotalDue
FROM Sales.SalesOrderHeader;
GO

-- 4. Total revenue overview
SELECT
    COUNT(DISTINCT SalesOrderID) AS TotalOrders,
    COUNT(DISTINCT CustomerID)   AS TotalCustomers,
    SUM(TotalDue)                AS TotalRevenue,
    AVG(TotalDue)                AS AvgOrderValue
FROM Sales.SalesOrderHeader;
GO

-- 5. Orders by year (trend at a glance)
SELECT
    YEAR(OrderDate) AS OrderYear,
    COUNT(*) AS TotalOrders,
    SUM(TotalDue) AS TotalRevenue
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;
GO
