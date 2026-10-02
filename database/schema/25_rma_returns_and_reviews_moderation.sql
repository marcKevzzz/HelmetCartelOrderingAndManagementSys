-- =====================================================================================
-- 25_rma_returns_and_reviews_moderation.sql
-- Returns & Exchanges (RMA) Module & Admin Reviews Moderation
-- =====================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. REVIEWS MODERATION STORED PROCEDURES
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_AdminGetReviews', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AdminGetReviews AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AdminGetReviews
    @Filter NVARCHAR(20) = N'ALL', -- 'ALL', 'PUBLISHED', 'HIDDEN', 'REPORTED'
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        r.Id,
        r.ProductId,
        p.Name AS ProductName,
        b.Name AS BrandName,
        r.UserId,
        r.OrderId,
        r.ReviewerName,
        r.Rating,
        r.Title,
        r.Comment,
        r.IsVerifiedPurchase,
        r.IsHidden,
        (SELECT COUNT(*) FROM dbo.ReviewReports rep WHERE rep.ReviewId = r.Id) AS FlagCount,
        r.CreatedAt
    FROM dbo.ProductReviews r
    INNER JOIN dbo.Products p ON p.Id = r.ProductId
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    WHERE (@Filter = N'ALL' OR
           (@Filter = N'PUBLISHED' AND r.IsHidden = 0) OR
           (@Filter = N'HIDDEN' AND r.IsHidden = 1) OR
           (@Filter = N'REPORTED' AND EXISTS (SELECT 1 FROM dbo.ReviewReports rep WHERE rep.ReviewId = r.Id)))
      AND (@Search IS NULL OR @Search = N'' OR 
           r.ReviewerName LIKE N'%' + @Search + N'%' OR 
           r.Title LIKE N'%' + @Search + N'%' OR 
           r.Comment LIKE N'%' + @Search + N'%' OR 
           p.Name LIKE N'%' + @Search + N'%')
    ORDER BY 
        CASE WHEN @Filter = N'REPORTED' THEN (SELECT COUNT(*) FROM dbo.ReviewReports rep WHERE rep.ReviewId = r.Id) ELSE 0 END DESC,
        r.CreatedAt DESC;
END;
GO

IF OBJECT_ID(N'dbo.sp_AdminToggleReviewVisibility', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AdminToggleReviewVisibility AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AdminToggleReviewVisibility
    @ReviewId INT,
    @NewIsHidden BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.ProductReviews WITH (UPDLOCK, ROWLOCK) WHERE Id = @ReviewId)
            THROW 51020, N'Review not found.', 1;

        UPDATE dbo.ProductReviews WITH (UPDLOCK, ROWLOCK)
        SET IsHidden = CASE WHEN IsHidden = 1 THEN 0 ELSE 1 END
        WHERE Id = @ReviewId;

        SELECT @NewIsHidden = IsHidden
        FROM dbo.ProductReviews
        WHERE Id = @ReviewId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 2. RETURNS & EXCHANGES (RMA) TABLE
-- =====================================================================================

IF OBJECT_ID(N'dbo.ReturnRequests', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ReturnRequests (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        RmaNumber NVARCHAR(30) NOT NULL UNIQUE,
        OrderId INT NOT NULL,
        OrderItemId INT NOT NULL,
        UserId INT NULL,
        RequestType NVARCHAR(20) NOT NULL, -- 'RETURN', 'EXCHANGE'
        Reason NVARCHAR(50) NOT NULL,      -- 'DEFECTIVE', 'WRONG_SIZE', 'NOT_AS_DESCRIBED', 'CHANGED_MIND', 'OTHER'
        ExchangeVariantId INT NULL,
        CustomerNotes NVARCHAR(1000) NULL,
        Status NVARCHAR(30) NOT NULL DEFAULT N'Pending', -- 'Pending', 'Approved', 'Rejected', 'Received', 'Completed', 'Cancelled'
        ResolutionType NVARCHAR(30) NULL,  -- 'REFUND', 'REPLACEMENT', 'STORE_CREDIT'
        RefundAmount DECIMAL(18,2) NULL,
        Restocked BIT NOT NULL DEFAULT 0,
        AdminNotes NVARCHAR(1000) NULL,
        ProcessedBy INT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_ReturnRequests_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id),
        CONSTRAINT FK_ReturnRequests_OrderItems FOREIGN KEY (OrderItemId) REFERENCES dbo.OrderItems(Id),
        CONSTRAINT FK_ReturnRequests_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
        CONSTRAINT FK_ReturnRequests_ExchangeVariant FOREIGN KEY (ExchangeVariantId) REFERENCES dbo.ProductVariants(Id),
        CONSTRAINT FK_ReturnRequests_ProcessedBy FOREIGN KEY (ProcessedBy) REFERENCES dbo.Users(Id),
        CONSTRAINT CK_ReturnRequests_RequestType CHECK (RequestType IN (N'RETURN', N'EXCHANGE')),
        CONSTRAINT CK_ReturnRequests_Status CHECK (Status IN (N'Pending', N'Approved', N'Rejected', N'Received', N'Completed', N'Cancelled'))
    );

    CREATE INDEX IX_ReturnRequests_OrderId ON dbo.ReturnRequests(OrderId);
    CREATE INDEX IX_ReturnRequests_UserId ON dbo.ReturnRequests(UserId);
    CREATE INDEX IX_ReturnRequests_Status ON dbo.ReturnRequests(Status);
    CREATE INDEX IX_ReturnRequests_CreatedAt ON dbo.ReturnRequests(CreatedAt DESC);
END;
GO

-- 3. STORED PROCEDURE: sp_CreateReturnRequest
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_CreateReturnRequest', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_CreateReturnRequest AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_CreateReturnRequest
    @OrderId INT,
    @OrderItemId INT,
    @UserId INT = NULL,
    @RequestType NVARCHAR(20),
    @Reason NVARCHAR(50),
    @ExchangeVariantId INT = NULL,
    @CustomerNotes NVARCHAR(1000) = NULL,
    @NewRmaId INT OUTPUT,
    @NewRmaNumber NVARCHAR(30) OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate order existence and status
        DECLARE @OrderStatus NVARCHAR(50);
        SELECT @OrderStatus = Status FROM dbo.Orders WHERE Id = @OrderId;

        IF @OrderStatus IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order does not exist.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @OrderStatus <> N'Completed'
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Only completed orders are eligible for return or exchange.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validate order item belongs to order
        IF NOT EXISTS (SELECT 1 FROM dbo.OrderItems WHERE Id = @OrderItemId AND OrderId = @OrderId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order item does not belong to this order.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Check if an active RMA already exists for this order item
        IF EXISTS (SELECT 1 FROM dbo.ReturnRequests WHERE OrderItemId = @OrderItemId AND Status NOT IN (N'Rejected', N'Cancelled'))
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'An active return or exchange request already exists for this item.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Generate unique RMA number (e.g. RMA-20261002-0001)
        DECLARE @DatePrefix NVARCHAR(12) = N'RMA-' + FORMAT(SYSUTCDATETIME(), N'yyyyMMdd') + N'-';
        DECLARE @NextSeq INT = 1;

        SELECT @NextSeq = ISNULL(MAX(CAST(RIGHT(RmaNumber, 4) AS INT)), 0) + 1
        FROM dbo.ReturnRequests
        WHERE RmaNumber LIKE @DatePrefix + N'%';

        SET @NewRmaNumber = @DatePrefix + RIGHT(N'0000' + CAST(@NextSeq AS NVARCHAR(10)), 4);

        INSERT INTO dbo.ReturnRequests (
            RmaNumber, OrderId, OrderItemId, UserId, RequestType, Reason,
            ExchangeVariantId, CustomerNotes, Status, Restocked
        )
        VALUES (
            @NewRmaNumber, @OrderId, @OrderItemId, @UserId, @RequestType, @Reason,
            @ExchangeVariantId, @CustomerNotes, N'Pending', 0
        );

        SET @NewRmaId = SCOPE_IDENTITY();
        SET @Success = 1;
        SET @ErrorMessage = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;
GO

-- 4. STORED PROCEDURE: sp_GetCustomerReturnRequests
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_GetCustomerReturnRequests', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_GetCustomerReturnRequests AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetCustomerReturnRequests
    @OrderId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        rma.Id,
        rma.RmaNumber,
        rma.OrderId,
        o.OrderNumber,
        rma.OrderItemId,
        oi.VariantId,
        p.Name AS ProductName,
        pc.Color AS ColorName,
        pv.Size,
        oi.Quantity,
        oi.UnitPrice,
        p.MainImageUrl,
        rma.UserId,
        rma.RequestType,
        rma.Reason,
        rma.ExchangeVariantId,
        rma.CustomerNotes,
        rma.Status,
        rma.ResolutionType,
        rma.RefundAmount,
        rma.Restocked,
        rma.AdminNotes,
        rma.CreatedAt,
        rma.UpdatedAt
    FROM dbo.ReturnRequests rma
    INNER JOIN dbo.Orders o ON o.Id = rma.OrderId
    INNER JOIN dbo.OrderItems oi ON oi.Id = rma.OrderItemId
    INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    WHERE (@OrderId IS NULL OR rma.OrderId = @OrderId)
      AND (@UserId IS NULL OR rma.UserId = @UserId)
    ORDER BY rma.CreatedAt DESC;
END;
GO

-- 5. STORED PROCEDURE: sp_AdminGetReturnRequests
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_AdminGetReturnRequests', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AdminGetReturnRequests AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AdminGetReturnRequests
    @Status NVARCHAR(30) = N'ALL',
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        rma.Id,
        rma.RmaNumber,
        rma.OrderId,
        o.OrderNumber,
        o.CustomerEmail,
        o.CustomerPhone,
        ISNULL(NULLIF(LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))), N''), ISNULL(o.CustomerName, N'Store Customer')) AS CustomerName,
        rma.OrderItemId,
        oi.VariantId,
        p.Name AS ProductName,
        pc.Color AS ColorName,
        pv.Size,
        oi.Quantity,
        oi.UnitPrice,
        rma.RequestType,
        rma.Reason,
        rma.ExchangeVariantId,
        rma.CustomerNotes,
        rma.Status,
        rma.ResolutionType,
        rma.RefundAmount,
        rma.Restocked,
        rma.AdminNotes,
        rma.ProcessedBy,
        LTRIM(RTRIM(CONCAT(pb.FirstName, N' ', pb.LastName))) AS ProcessedByName,
        rma.CreatedAt,
        rma.UpdatedAt
    FROM dbo.ReturnRequests rma
    INNER JOIN dbo.Orders o ON o.Id = rma.OrderId
    INNER JOIN dbo.OrderItems oi ON oi.Id = rma.OrderItemId
    INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    LEFT JOIN dbo.Users u ON u.Id = rma.UserId
    LEFT JOIN dbo.Users pb ON pb.Id = rma.ProcessedBy
    WHERE (@Status = N'ALL' OR rma.Status = @Status)
      AND (@Search IS NULL OR @Search = N'' OR 
           rma.RmaNumber LIKE N'%' + @Search + N'%' OR 
           o.OrderNumber LIKE N'%' + @Search + N'%' OR 
           o.CustomerEmail LIKE N'%' + @Search + N'%' OR 
           p.Name LIKE N'%' + @Search + N'%')
    ORDER BY 
        CASE WHEN rma.Status = N'Pending' THEN 0 ELSE 1 END,
        rma.CreatedAt DESC;
END;
GO

-- 6. STORED PROCEDURE: sp_AdminProcessReturnRequest
-- Atomic stock increment and audit logging on item restock
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_AdminProcessReturnRequest', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_AdminProcessReturnRequest AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AdminProcessReturnRequest
    @RmaId INT,
    @NewStatus NVARCHAR(30),
    @ResolutionType NVARCHAR(30) = NULL,
    @RefundAmount DECIMAL(18,2) = NULL,
    @RestockItem BIT = 0,
    @AdminNotes NVARCHAR(1000) = NULL,
    @ProcessedBy INT = NULL,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus NVARCHAR(30);
        DECLARE @CurrentRestocked BIT;
        DECLARE @OrderItemId INT;
        DECLARE @RmaNumber NVARCHAR(30);

        SELECT 
            @CurrentStatus = Status,
            @CurrentRestocked = Restocked,
            @OrderItemId = OrderItemId,
            @RmaNumber = RmaNumber
        FROM dbo.ReturnRequests WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @RmaId;

        IF @CurrentStatus IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'RMA Request not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- If restock is requested and not already restocked
        IF @RestockItem = 1 AND @CurrentRestocked = 0
        BEGIN
            DECLARE @VariantId INT;
            DECLARE @Quantity INT;

            SELECT @VariantId = VariantId, @Quantity = Quantity
            FROM dbo.OrderItems
            WHERE Id = @OrderItemId;

            IF @VariantId IS NOT NULL AND @Quantity > 0
            BEGIN
                DECLARE @PrevStock INT;
                SELECT @PrevStock = CurrentStock
                FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
                WHERE VariantId = @VariantId;

                IF @PrevStock IS NOT NULL
                BEGIN
                    -- Increment inventory stock atomically
                    UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK)
                    SET CurrentStock = CurrentStock + @Quantity,
                        UpdatedAt = SYSUTCDATETIME()
                    WHERE VariantId = @VariantId;

                    -- Record in StockAuditLogs
                    INSERT INTO dbo.StockAuditLogs (
                        VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes
                    )
                    VALUES (
                        @VariantId, @ProcessedBy, N'RETURN', @PrevStock, @Quantity, @RmaNumber,
                        CONCAT(N'Restocked from RMA: ', @RmaNumber)
                    );

                    SET @CurrentRestocked = 1;
                END
            END
        END

        -- Update ReturnRequest record
        UPDATE dbo.ReturnRequests WITH (UPDLOCK, ROWLOCK)
        SET Status = @NewStatus,
            ResolutionType = ISNULL(@ResolutionType, ResolutionType),
            RefundAmount = ISNULL(@RefundAmount, RefundAmount),
            Restocked = @CurrentRestocked,
            AdminNotes = ISNULL(@AdminNotes, AdminNotes),
            ProcessedBy = ISNULL(@ProcessedBy, ProcessedBy),
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @RmaId;

        SET @Success = 1;
        SET @ErrorMessage = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;
GO

-- 7. STORED PROCEDURE: sp_RecordPaymentFailure
-- =====================================================================================

IF OBJECT_ID(N'dbo.sp_RecordPaymentFailure', N'P') IS NULL EXEC(N'CREATE PROCEDURE dbo.sp_RecordPaymentFailure AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_RecordPaymentFailure
    @OrderNumber NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.Status = N'Failed'
    FROM dbo.Payments p
    JOIN dbo.Orders o ON o.Id = p.OrderId
    WHERE o.OrderNumber = @OrderNumber;
END;
GO

