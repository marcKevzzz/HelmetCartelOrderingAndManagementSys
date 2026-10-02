-- ============================================================================
-- Migration 27: Sales breakdown by brand and category
-- ============================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesByBrandAndCategory
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesLines TABLE
    (
        OrderId INT NOT NULL,
        Quantity INT NOT NULL,
        UnitPrice DECIMAL(18, 2) NOT NULL,
        BrandName NVARCHAR(100) NOT NULL,
        CategoryName NVARCHAR(100) NOT NULL
    );

    -- Resolve one completed payment timestamp per order so duplicate gateway
    -- notifications cannot multiply item sales in the report.
    INSERT @SalesLines (OrderId, Quantity, UnitPrice, BrandName, CategoryName)
    SELECT oi.OrderId,
           oi.Quantity,
           oi.UnitPrice,
           b.Name,
           c.Name
    FROM dbo.OrderItems oi
    INNER JOIN dbo.ProductVariants v ON v.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    INNER JOIN
    (
        SELECT OrderId, MAX(PaidAt) AS PaidAt
        FROM dbo.Payments
        WHERE Status = N'Completed'
          AND PaidAt IS NOT NULL
        GROUP BY OrderId
    ) completed ON completed.OrderId = oi.OrderId
    WHERE completed.PaidAt >= @StartDate
      AND completed.PaidAt < @EndDate;

    SELECT BrandName AS DimensionName,
           SUM(Quantity) AS UnitsSold,
           COUNT(DISTINCT OrderId) AS OrderCount,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice)) AS Revenue,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice) / NULLIF(SUM(Quantity), 0)) AS AverageUnitPrice
    FROM @SalesLines
    GROUP BY BrandName
    ORDER BY UnitsSold DESC, Revenue DESC, BrandName;

    SELECT CategoryName AS DimensionName,
           SUM(Quantity) AS UnitsSold,
           COUNT(DISTINCT OrderId) AS OrderCount,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice)) AS Revenue,
           CONVERT(DECIMAL(18, 2), SUM(Quantity * UnitPrice) / NULLIF(SUM(Quantity), 0)) AS AverageUnitPrice
    FROM @SalesLines
    GROUP BY CategoryName
    ORDER BY UnitsSold DESC, Revenue DESC, CategoryName;
END;
GO
