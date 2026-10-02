-- ============================================================================
-- Migration 30: Sales Performance Analytics & Hourly Sales Velocity
-- Description:
-- 1. sp_AdminSalesPerformance: Item, Brand, and Category sales metrics
--    (Units Sold, Orders, Revenue, Average Selling Price)
-- 2. sp_AdminSalesHourly: 24-hour hourly revenue breakdown for Dashboard
-- ============================================================================

USE [HelmetCartelDB];
GO

-- 1. Hourly Sales Velocity for Dashboard
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesHourly
    @TargetDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        DATEPART(HOUR, p.PaidAt) AS SaleHour,
        COUNT(DISTINCT o.Id) AS OrderCount,
        ISNULL(SUM(p.Amount), 0) AS Revenue
    FROM dbo.Payments p
    INNER JOIN dbo.Orders o ON o.Id = p.OrderId
    WHERE p.Status = N'Completed'
      AND o.Status IN (N'Completed', N'Delivered')
      AND CONVERT(DATE, p.PaidAt) = @TargetDate
    GROUP BY DATEPART(HOUR, p.PaidAt)
    ORDER BY SaleHour;
END;
GO

-- 2. Sales Performance Analytics by Item, Brand, and Category
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesPerformance
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.Id AS ProductId,
        p.Name AS ProductName,
        b.Id AS BrandId,
        b.Name AS BrandName,
        c.Id AS CategoryId,
        c.Name AS CategoryName,
        SUM(oi.Quantity) AS UnitsSold,
        COUNT(DISTINCT o.Id) AS OrderCount,
        CONVERT(DECIMAL(18, 2), SUM(oi.Quantity * oi.UnitPrice)) AS Revenue,
        CONVERT(DECIMAL(18, 2), SUM(oi.Quantity * oi.UnitPrice) / NULLIF(SUM(oi.Quantity), 0)) AS AverageSellingPrice
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
    INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    INNER JOIN
    (
        SELECT OrderId, MAX(PaidAt) AS PaidAt
        FROM dbo.Payments
        WHERE Status = N'Completed' AND PaidAt IS NOT NULL
        GROUP BY OrderId
    ) completed ON completed.OrderId = oi.OrderId
    WHERE o.Status IN (N'Completed', N'Delivered')
      AND completed.PaidAt >= @StartDate
      AND completed.PaidAt < @EndDate
    GROUP BY p.Id, p.Name, b.Id, b.Name, c.Id, c.Name
    ORDER BY UnitsSold DESC, Revenue DESC;
END;
GO
