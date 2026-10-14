/*
=====================================================================
 02_business_questions.sql
 Purpose: Answer real business questions using joins & aggregation
 Database: AdventureWorks2025
=====================================================================
*/

USE AdventureWorks2025;
GO

-- Q1: Total sales by territory
SELECT
    st.Name AS Territory,
    COUNT(DISTINCT soh.SalesOrderID) AS TotalOrders,
    SUM(soh.TotalDue) AS TotalRevenue
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY st.Name
ORDER BY TotalRevenue DESC;
GO

-- Q2: Top 10 best-selling products by revenue
SELECT TOP 10
    p.Name AS ProductName,
    SUM(sod.OrderQty) AS UnitsSold,
    SUM(sod.LineTotal) AS TotalRevenue
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.Name
ORDER BY TotalRevenue DESC;
GO

-- Q3: Revenue contribution % by product category
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
    CategoryTotal,
    CAST(CategoryTotal * 100.0 / SUM(CategoryTotal) OVER () AS DECIMAL(5,2)) AS PctOfTotalRevenue
FROM CategoryRevenue
ORDER BY CategoryTotal DESC;
GO

-- Q4: Average order value by customer type (Store vs Individual)
SELECT
    CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END AS CustomerType,
    COUNT(DISTINCT soh.SalesOrderID) AS TotalOrders,
    AVG(soh.TotalDue) AS AvgOrderValue
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
GROUP BY CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END;
GO

-- Q5: Top 10 customers by total spend
SELECT TOP 10
    soh.CustomerID,
    SUM(soh.TotalDue) AS TotalSpend,
    COUNT(soh.SalesOrderID) AS NumOrders
FROM Sales.SalesOrderHeader soh
GROUP BY soh.CustomerID
ORDER BY TotalSpend DESC;
GO
