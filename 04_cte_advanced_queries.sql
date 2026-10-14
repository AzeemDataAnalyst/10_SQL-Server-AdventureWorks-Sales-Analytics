/*
=====================================================================
 04_cte_advanced_queries.sql
 Purpose: Multi-step CTEs for churn analysis, RFM-style segmentation,
          and average order value trends.
 Database: AdventureWorks2025
=====================================================================
*/

USE AdventureWorks2025;
GO

-- 1. Customers who have NOT ordered in the last 12 months (churn risk)
WITH LastOrderPerCustomer AS (
    SELECT
        CustomerID,
        MAX(OrderDate) AS LastOrderDate
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),
MostRecentDateInData AS (
    SELECT MAX(OrderDate) AS MaxDate FROM Sales.SalesOrderHeader
)
SELECT
    l.CustomerID,
    l.LastOrderDate,
    DATEDIFF(MONTH, l.LastOrderDate, m.MaxDate) AS MonthsSinceLastOrder
FROM LastOrderPerCustomer l
CROSS JOIN MostRecentDateInData m
WHERE DATEDIFF(MONTH, l.LastOrderDate, m.MaxDate) >= 12
ORDER BY MonthsSinceLastOrder DESC;
GO

-- 2. Simple customer value segmentation (RFM-lite: Recency + Monetary)
WITH CustomerStats AS (
    SELECT
        CustomerID,
        MAX(OrderDate) AS LastOrderDate,
        COUNT(SalesOrderID) AS OrderCount,
        SUM(TotalDue) AS TotalSpend
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),
MaxDate AS (
    SELECT MAX(OrderDate) AS MaxDate FROM Sales.SalesOrderHeader
)
SELECT
    cs.CustomerID,
    cs.TotalSpend,
    cs.OrderCount,
    DATEDIFF(MONTH, cs.LastOrderDate, m.MaxDate) AS MonthsSinceLastOrder,
    CASE
        WHEN cs.TotalSpend > 10000 AND DATEDIFF(MONTH, cs.LastOrderDate, m.MaxDate) <= 6 THEN 'VIP - Active'
        WHEN cs.TotalSpend > 10000 THEN 'VIP - At Risk'
        WHEN DATEDIFF(MONTH, cs.LastOrderDate, m.MaxDate) <= 6 THEN 'Regular - Active'
        ELSE 'Regular - Dormant'
    END AS CustomerSegment
FROM CustomerStats cs
CROSS JOIN MaxDate m
ORDER BY cs.TotalSpend DESC;
GO

-- 3. Average order value trend by quarter (CTE + DATEPART)
WITH QuarterlyOrders AS (
    SELECT
        YEAR(OrderDate) AS OrderYear,
        DATEPART(QUARTER, OrderDate) AS OrderQuarter,
        TotalDue
    FROM Sales.SalesOrderHeader
)
SELECT
    OrderYear,
    OrderQuarter,
    COUNT(*) AS TotalOrders,
    AVG(TotalDue) AS AvgOrderValue,
    SUM(TotalDue) AS TotalRevenue
FROM QuarterlyOrders
GROUP BY OrderYear, OrderQuarter
ORDER BY OrderYear, OrderQuarter;
GO
