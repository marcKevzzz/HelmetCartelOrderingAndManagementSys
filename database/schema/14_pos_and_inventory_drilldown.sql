-- POS catalog, brand drill-down, and exact inventory links.
-- Run in the intended Helmet Cartel database after migration 13.

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = N'all',
    @ProductId INT = NULL,
    @VariantId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = N'all' SET @Brand = NULL;
    IF @Category = N'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = N'' SET @StockStatus = N'all';

    SELECT v.Id AS VariantId, p.Id AS ProductId, b.Name AS BrandName,
           p.Name AS ProductName, cat.Name AS CategoryName, c.Color, c.ColorHex,
           v.Size, ISNULL(i.CurrentStock, 0) AS CurrentStock,
           ISNULL(i.ReservedStock, 0) AS ReservedStock,
           ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
           ISNULL(i.ReorderPoint, 3) AS ReorderPoint,
           dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
               p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
               p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
           v.SKU, p.MainImageUrl,
           CASE WHEN ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= 0 THEN N'out_of_stock'
                WHEN ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= ISNULL(i.ReorderPoint, 3) THEN N'low_stock'
                ELSE N'in_stock' END AS StockStatus
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE v.IsActive = 1 AND p.IsActive = 1
      AND (@ProductId IS NULL OR p.Id = @ProductId)
      AND (@VariantId IS NULL OR v.Id = @VariantId)
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%'
           OR b.Name LIKE N'%' + @Search + N'%' OR cat.Name LIKE N'%' + @Search + N'%'
           OR v.SKU LIKE N'%' + @Search + N'%' OR c.Color LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name) LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name, N' ', c.Color) LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name, N' ', c.Color, N' ', v.Size) LIKE N'%' + @Search + N'%'
           OR CONCAT(p.Name, N' ', c.Color) LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category OR cat.Slug = @Category)
      AND (@StockStatus = N'all'
           OR (@StockStatus = N'in_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) > ISNULL(i.ReorderPoint, 3))
           OR (@StockStatus = N'low_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) BETWEEN 1 AND ISNULL(i.ReorderPoint, 3))
           OR (@StockStatus = N'out_of_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= 0))
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminBrandInventoryDetails
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.Name AS Brand, p.Id AS ProductId, v.Id AS VariantId,
           p.Name AS ProductName, cat.Name AS CategoryName, p.MainImageUrl,
           c.Color, v.Size, v.SKU, i.CurrentStock AS OnHandStock,
           i.CurrentStock - i.ReservedStock AS AvailableStock,
           i.ReorderPoint,
           CASE WHEN i.CurrentStock - i.ReservedStock <= 0 THEN N'out_of_stock'
                WHEN i.CurrentStock - i.ReservedStock <= i.ReorderPoint THEN N'low_stock'
                ELSE N'in_stock' END AS StockStatus
    FROM dbo.Inventories i
    JOIN dbo.ProductVariants v ON v.Id = i.VariantId
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AdminSellableVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    SELECT v.Id AS VariantId, p.Id AS ProductId, v.SKU,
           p.Name AS ProductName, b.Name AS Brand, cat.Name AS Category,
           p.MainImageUrl, c.Color, c.ColorHex, v.Size,
           i.CurrentStock - i.ReservedStock AS AvailableStock,
           dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
               p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
               p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS UnitPrice,
           CASE WHEN i.CurrentStock - i.ReservedStock <= 0 THEN N'out_of_stock'
                WHEN i.CurrentStock - i.ReservedStock <= i.ReorderPoint THEN N'low_stock'
                ELSE N'in_stock' END AS StockStatus
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE p.IsActive = 1 AND v.IsActive = 1
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%'
           OR b.Name LIKE N'%' + @Search + N'%'
           OR v.SKU LIKE N'%' + @Search + N'%'
           OR c.Color LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name) LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category)
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreatePhysicalSale
    @OrderNumber NVARCHAR(50), @ActorUserId INT = NULL,
    @CustomerName NVARCHAR(100), @CustomerEmail NVARCHAR(256), @CustomerPhone NVARCHAR(30),
    @OrderSource NVARCHAR(30), @OrderStatus NVARCHAR(50), @PaymentMethod NVARCHAR(50),
    @PaymentStatus NVARCHAR(50), @Notes NVARCHAR(500), @Items dbo.SaleLineInput READONLY,
    @CashTendered DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM @Items) OR EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0)
        THROW 52201, N'Sale needs positive item quantities.', 1;
    IF @PaymentMethod NOT IN (N'Cash', N'Card_POS') OR
       (@OrderSource = N'INSTORE_POS' AND (@OrderStatus <> N'Completed' OR @PaymentStatus <> N'Completed')) OR
       (@OrderSource = N'ONLINE' AND (@OrderStatus <> N'Processing' OR @PaymentStatus <> N'Pending')) OR
       @OrderSource NOT IN (N'INSTORE_POS', N'ONLINE')
        THROW 52202, N'Invalid physical sale options.', 1;

    DECLARE @Lines TABLE (VariantId INT PRIMARY KEY, Quantity INT, UnitPrice DECIMAL(18,2), OldStock INT);
    DECLARE @VariantId INT, @Quantity INT, @UnitPrice DECIMAL(18,2), @OldStock INT, @Reserved INT;
    DECLARE sale_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT VariantId, Quantity FROM @Items ORDER BY VariantId;
    BEGIN TRANSACTION;
    OPEN sale_cursor;
    FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @UnitPrice = dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
            p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
            p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)
        FROM dbo.ProductVariants v JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = c.ProductId
        WHERE v.Id = @VariantId AND v.IsActive = 1 AND p.IsActive = 1;
        SELECT @OldStock = CurrentStock, @Reserved = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @VariantId;
        IF @UnitPrice IS NULL OR @OldStock IS NULL OR @OldStock - @Reserved < @Quantity
            THROW 52203, N'Item unavailable or insufficient stock.', 1;
        INSERT @Lines VALUES (@VariantId, @Quantity, @UnitPrice, @OldStock);
        SET @UnitPrice = NULL;
        SET @OldStock = NULL;
        FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;
    END;
    CLOSE sale_cursor;
    DEALLOCATE sale_cursor;

    DECLARE @Subtotal DECIMAL(18,2) = (SELECT SUM(Quantity * UnitPrice) FROM @Lines);
    IF @OrderSource = N'INSTORE_POS' AND @PaymentMethod = N'Cash' AND
       (@CashTendered IS NULL OR @CashTendered < @Subtotal)
        THROW 52208, N'Cash tendered is less than the current sale total.', 1;
    INSERT dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, Notes)
    VALUES (@OrderNumber, CASE WHEN @OrderSource = N'ONLINE' THEN @ActorUserId ELSE NULL END,
        @CustomerName, @CustomerEmail, @CustomerPhone,
        @OrderSource, @OrderStatus, @Subtotal, 0, @Notes);
    DECLARE @OrderId INT = CONVERT(INT, SCOPE_IDENTITY());
    INSERT dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    SELECT @OrderId, VariantId, Quantity, UnitPrice FROM @Lines;
    UPDATE i SET CurrentStock = i.CurrentStock - l.Quantity, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId;
    INSERT dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber)
    SELECT VariantId, @ActorUserId, CASE WHEN @OrderSource = N'INSTORE_POS' THEN N'INSTORE_SALE' ELSE N'ONLINE_SALE' END,
           OldStock, -Quantity, @OrderNumber FROM @Lines;
    INSERT dbo.Payments (OrderId, PaymentGateway, Amount, Status, PaidAt)
    VALUES (@OrderId, @PaymentMethod, @Subtotal, @PaymentStatus,
        CASE WHEN @PaymentStatus = N'Completed' THEN SYSUTCDATETIME() ELSE NULL END);
    INSERT dbo.RestockAlerts (InventoryId, Severity)
    SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId
    WHERE i.IsLowStock = 1 AND NOT EXISTS
        (SELECT 1 FROM dbo.RestockAlerts a WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);
    COMMIT TRANSACTION;
    SELECT @OrderId AS Id;
END;
GO
