/*
=====================================================================
 06_advanced_analysis.sql
 Purpose: Business-impact analysis that goes beyond revenue totals:
          profitability, customer concentration, retention,
          segmentation, growth, discounts, channels and seasonality.
 Database: AdventureWorks2025
 Notes:
   - Q21 to Q32 continue the numbering of the project report.
   - Data-quality rules learned in 05_validation_checks.sql:
       * 2022-05 holds only 2 days of data (30-31 May)
       * from 30 May 2025 order values collapse
     so TREND queries (Q31, Q32) exclude those periods, and
     year comparisons (Q27) use the two complete years 2023 and 2024.
   - Cost uses Production.Product.StandardCost (current standard cost,
     not historical), so margins are indicative.
=====================================================================
*/

USE AdventureWorks2025;
GO

-- Q21: Executive KPI summary (one row for the whole business)
SELECT
    COUNT(*)                        AS TotalOrders,
    COUNT(DISTINCT CustomerID)      AS TotalCustomers,
    SUM(SubTotal)                   AS ProductSales,
    SUM(TaxAmt + Freight)           AS TaxAndFreight,
    SUM(TotalDue)                   AS TotalRevenue,
    AVG(TotalDue)                   AS AvgOrderValue
FROM Sales.SalesOrderHeader;
GO

-- Q22: Gross profit and margin by product category
SELECT
    pc.Name AS Category,
    SUM(sod.LineTotal)                                        AS ProductSales,
    SUM(sod.OrderQty * p.StandardCost)                        AS ProductCost,
    SUM(sod.LineTotal - sod.OrderQty * p.StandardCost)        AS GrossProfit,
    CAST(100.0 * SUM(sod.LineTotal - sod.OrderQty * p.StandardCost)
         / NULLIF(SUM(sod.LineTotal), 0) AS DECIMAL(6,2))     AS GrossMarginPct
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.Name
ORDER BY GrossProfit DESC;
GO

-- Q23: Customer concentration (Pareto): revenue share by spend decile
WITH CustomerSpend AS (
    SELECT CustomerID, SUM(TotalDue) AS Spend
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),
Deciles AS (
    SELECT CustomerID, Spend,
           NTILE(10) OVER (ORDER BY Spend DESC) AS SpendDecile
    FROM CustomerSpend
)
SELECT
    SpendDecile,
    COUNT(*)   AS Customers,
    SUM(Spend) AS Revenue,
    CAST(100.0 * SUM(Spend) / SUM(SUM(Spend)) OVER () AS DECIMAL(5,2)) AS PctOfRevenue,
    CAST(100.0 * SUM(SUM(Spend)) OVER (ORDER BY SpendDecile)
         / SUM(SUM(Spend)) OVER () AS DECIMAL(5,2))                  AS CumulativePct
FROM Deciles
GROUP BY SpendDecile
ORDER BY SpendDecile;
GO

-- Q24: Repeat purchase rate by customer type
WITH CustomerOrders AS (
    SELECT
        soh.CustomerID,
        CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END AS CustomerType,
        COUNT(*) AS Orders
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    GROUP BY soh.CustomerID,
             CASE WHEN c.StoreID IS NOT NULL THEN 'Store/Reseller' ELSE 'Individual' END
)
SELECT
    CustomerType,
    COUNT(*) AS Customers,
    SUM(CASE WHEN Orders >= 2 THEN 1 ELSE 0 END) AS RepeatCustomers,
    CAST(100.0 * SUM(CASE WHEN Orders >= 2 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS RepeatRatePct,
    CAST(AVG(Orders * 1.0) AS DECIMAL(6,2)) AS AvgOrdersPerCustomer
FROM CustomerOrders
GROUP BY CustomerType
ORDER BY CustomerType;
GO

-- Q25: Cohort retention: customers by first-order year, and how many ordered again in later years
WITH FirstOrder AS (
    SELECT CustomerID, MIN(YEAR(OrderDate)) AS CohortYear
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),
CohortSize AS (
    SELECT CohortYear, COUNT(*) AS CohortCustomers
    FROM FirstOrder
    GROUP BY CohortYear
),
Activity AS (
    SELECT DISTINCT CustomerID, YEAR(OrderDate) AS ActiveYear
    FROM Sales.SalesOrderHeader
)
SELECT
    f.CohortYear,
    a.ActiveYear,
    cs.CohortCustomers,
    COUNT(DISTINCT a.CustomerID) AS ActiveCustomers,
    CAST(100.0 * COUNT(DISTINCT a.CustomerID) / cs.CohortCustomers AS DECIMAL(5,2)) AS RetentionPct
FROM FirstOrder f
JOIN Activity a   ON a.CustomerID = f.CustomerID
JOIN CohortSize cs ON cs.CohortYear = f.CohortYear
GROUP BY f.CohortYear, a.ActiveYear, cs.CohortCustomers
ORDER BY f.CohortYear, a.ActiveYear;
GO

-- Q26: Full RFM segmentation (Recency quartile, Frequency band, Monetary quartile)
WITH CustomerStats AS (
    SELECT
        CustomerID,
        MAX(OrderDate)  AS LastOrderDate,
        COUNT(*)        AS OrderCount,
        SUM(TotalDue)   AS TotalSpend
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),
Scored AS (
    SELECT
        CustomerID, OrderCount, TotalSpend,
        NTILE(4) OVER (ORDER BY LastOrderDate ASC) AS R_Score,   -- 4 = most recent
        CASE WHEN OrderCount = 1 THEN 1
             WHEN OrderCount = 2 THEN 2
             WHEN OrderCount <= 4 THEN 3
             ELSE 4 END                            AS F_Score,
        NTILE(4) OVER (ORDER BY TotalSpend ASC)    AS M_Score    -- 4 = highest spend
    FROM CustomerStats
),
Segmented AS (
    SELECT *,
        CASE
            WHEN R_Score = 4 AND F_Score >= 3 AND M_Score = 4 THEN 'Champions'
            WHEN R_Score >= 3 AND F_Score >= 3                THEN 'Loyal'
            WHEN R_Score >= 3 AND F_Score <= 2                THEN 'Recent / Potential'
            WHEN R_Score <= 2 AND F_Score >= 3                THEN 'At Risk'
            ELSE 'Lost / Low value'
        END AS Segment
    FROM Scored
)
SELECT
    Segment,
    COUNT(*)        AS Customers,
    SUM(TotalSpend) AS TotalSpend,
    CAST(AVG(TotalSpend) AS DECIMAL(12,2)) AS AvgSpend,
    CAST(100.0 * SUM(TotalSpend) / SUM(SUM(TotalSpend)) OVER () AS DECIMAL(5,2)) AS PctOfRevenue
FROM Segmented
GROUP BY Segment
ORDER BY TotalSpend DESC;
GO

-- Q27: Territory growth, 2023 vs 2024 (the two complete years)
WITH TerritoryYear AS (
    SELECT st.Name AS Territory, YEAR(soh.OrderDate) AS Yr, SUM(soh.TotalDue) AS Revenue
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
    WHERE YEAR(soh.OrderDate) IN (2023, 2024)
    GROUP BY st.Name, YEAR(soh.OrderDate)
),
Pivoted AS (
    SELECT Territory,
           SUM(CASE WHEN Yr = 2023 THEN Revenue ELSE 0 END) AS Revenue2023,
           SUM(CASE WHEN Yr = 2024 THEN Revenue ELSE 0 END) AS Revenue2024
    FROM TerritoryYear
    GROUP BY Territory
)
SELECT
    Territory,
    Revenue2023,
    Revenue2024,
    CAST(100.0 * (Revenue2024 - Revenue2023) / NULLIF(Revenue2023, 0) AS DECIMAL(7,2)) AS GrowthPct,
    RANK() OVER (ORDER BY (Revenue2024 - Revenue2023) / NULLIF(Revenue2023, 0) DESC)  AS GrowthRank
FROM Pivoted
ORDER BY GrowthRank;
GO

-- Q28: Discount impact by product category
SELECT
    pc.Name AS Category,
    SUM(sod.OrderQty * sod.UnitPrice)                              AS GrossSales,
    SUM(sod.OrderQty * sod.UnitPrice * sod.UnitPriceDiscount)      AS DiscountGiven,
    CAST(100.0 * SUM(sod.OrderQty * sod.UnitPrice * sod.UnitPriceDiscount)
         / NULLIF(SUM(sod.OrderQty * sod.UnitPrice), 0) AS DECIMAL(5,2)) AS DiscountPct
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.Name
ORDER BY DiscountGiven DESC;
GO

-- Q29: Sales channel: online orders vs sales-rep orders
SELECT
    CASE WHEN OnlineOrderFlag = 1 THEN 'Online' ELSE 'Sales rep (offline)' END AS Channel,
    COUNT(*)          AS Orders,
    SUM(TotalDue)     AS Revenue,
    AVG(TotalDue)     AS AvgOrderValue,
    CAST(100.0 * SUM(TotalDue) / SUM(SUM(TotalDue)) OVER () AS DECIMAL(5,2)) AS PctOfRevenue
FROM Sales.SalesOrderHeader
GROUP BY CASE WHEN OnlineOrderFlag = 1 THEN 'Online' ELSE 'Sales rep (offline)' END
ORDER BY Revenue DESC;
GO

-- Q30: Market basket: which product subcategories are bought together most often?
WITH OrderSubcategories AS (
    SELECT DISTINCT sod.SalesOrderID, p.ProductSubcategoryID
    FROM Sales.SalesOrderDetail sod
    JOIN Production.Product p ON sod.ProductID = p.ProductID
    WHERE p.ProductSubcategoryID IS NOT NULL
)
SELECT TOP 10
    s1.Name AS Subcategory_A,
    s2.Name AS Subcategory_B,
    COUNT(*) AS OrdersTogether
FROM OrderSubcategories a
JOIN OrderSubcategories b
     ON a.SalesOrderID = b.SalesOrderID
    AND a.ProductSubcategoryID < b.ProductSubcategoryID
JOIN Production.ProductSubcategory s1 ON a.ProductSubcategoryID = s1.ProductSubcategoryID
JOIN Production.ProductSubcategory s2 ON b.ProductSubcategoryID = s2.ProductSubcategoryID
GROUP BY s1.Name, s2.Name
ORDER BY OrdersTogether DESC;
GO

-- Q31: Seasonality index by calendar month (complete years 2023 and 2024 only; 100 = average month)
WITH MonthlyRevenue AS (
    SELECT YEAR(OrderDate) AS Yr, MONTH(OrderDate) AS Mth, SUM(TotalDue) AS Revenue
    FROM Sales.SalesOrderHeader
    WHERE OrderDate >= '2023-01-01' AND OrderDate < '2025-01-01'
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    Mth,
    AVG(Revenue) AS AvgMonthlyRevenue,
    CAST(100.0 * AVG(Revenue) / AVG(AVG(Revenue)) OVER () AS DECIMAL(6,1)) AS SeasonalIndex
FROM MonthlyRevenue
GROUP BY Mth
ORDER BY Mth;
GO

-- Q32: 3-month moving average of revenue (Jun 2022 to Apr 2025: excludes the 2-day May 2022
--      stub and the unreliable May-Jun 2025 period)
WITH MonthlyRevenue AS (
    SELECT YEAR(OrderDate) AS Yr, MONTH(OrderDate) AS Mth, SUM(TotalDue) AS Revenue
    FROM Sales.SalesOrderHeader
    WHERE OrderDate >= '2022-06-01' AND OrderDate < '2025-05-01'
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    Yr, Mth, Revenue,
    CAST(AVG(Revenue) OVER (ORDER BY Yr, Mth ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DECIMAL(14,2)) AS MovingAvg3M
FROM MonthlyRevenue
ORDER BY Yr, Mth;
GO
