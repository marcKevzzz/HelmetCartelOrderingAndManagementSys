-- =====================================================================================
-- 60_standardize_2xl_and_rma_sequence.sql
-- 1. Standardizes size 'XXL' to '2XL' across dbo.ProductVariants and dbo.OrderItems,
--    including updating SKU suffixes from -XXL to -2XL.
-- 2. Ensures dbo.Seq_RmaNumber exists for atomic RMA generation.
-- 3. Updates dbo.sp_CreateReturnRequest to be safe and resilient.
-- =====================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Standardize XXL -> 2XL in dbo.ProductVariants
UPDATE dbo.ProductVariants
SET Size = N'2XL',
    SKU = REPLACE(SKU, N'-XXL', N'-2XL')
WHERE Size = N'XXL' OR Size = N'xxl';
GO

-- 2. Standardize XXL -> 2XL in dbo.OrderItems
UPDATE dbo.OrderItems
SET Size = N'2XL',
    SKU = REPLACE(SKU, N'-XXL', N'-2XL')
WHERE Size = N'XXL' OR Size = N'xxl';
GO

-- 3. Create dbo.Seq_RmaNumber if missing
IF OBJECT_ID(N'dbo.Seq_RmaNumber', N'SO') IS NULL
BEGIN
    DECLARE @MaxRmaVal INT = 1000;
    SELECT @MaxRmaVal = ISNULL(MAX(TRY_CAST(RIGHT(RmaNumber, 4) AS INT)), 1000)
    FROM dbo.ReturnRequests;
    IF @MaxRmaVal < 1000 SET @MaxRmaVal = 1000;
    SET @MaxRmaVal = @MaxRmaVal + 1;

    DECLARE @SqlSeq NVARCHAR(MAX) = N'CREATE SEQUENCE dbo.Seq_RmaNumber START WITH ' + CAST(@MaxRmaVal AS NVARCHAR(20)) + N' INCREMENT BY 1 MINVALUE 1;';
    EXEC sp_executesql @SqlSeq;
END;
GO

-- 4. Update dbo.sp_CreateReturnRequest with resilient RMA sequence generation
CREATE OR ALTER PROCEDURE dbo.sp_CreateReturnRequest
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

        DECLARE @OrderStatus NVARCHAR(50);
        SELECT @OrderStatus = Status FROM dbo.Orders WHERE Id = @OrderId;

        IF @OrderStatus IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order does not exist.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @OrderStatus NOT IN (N'Completed', N'Delivered')
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Only delivered or completed orders are eligible for return or exchange.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.OrderItems WHERE Id = @OrderItemId AND OrderId = @OrderId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order item does not belong to this order.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Concurrency locking on item active returns
        IF EXISTS (SELECT 1 FROM dbo.ReturnRequests WITH (UPDLOCK, HOLDLOCK) WHERE OrderItemId = @OrderItemId AND Status NOT IN (N'Rejected', N'Cancelled'))
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'An active return or exchange request already exists for this item.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Safe sequence generation with fallback
        DECLARE @DatePrefix NVARCHAR(16) = N'RMA-' + FORMAT(SYSUTCDATETIME(), N'yyyyMMdd') + N'-';
        DECLARE @NextSeq BIGINT;
        
        BEGIN TRY
            SET @NextSeq = NEXT VALUE FOR dbo.Seq_RmaNumber;
        END TRY
        BEGIN CATCH
            -- In case sequence is temporarily unavailable, use fallback counter
            SELECT @NextSeq = ISNULL(MAX(Id), 1000) + 1 FROM dbo.ReturnRequests;
        END CATCH

        SET @NewRmaNumber = @DatePrefix + RIGHT(N'0000' + CAST((@NextSeq % 10000) AS NVARCHAR(10)), 4);

        INSERT INTO dbo.ReturnRequests (
            RmaNumber,
            OrderId,
            OrderItemId,
            UserId,
            RequestType,
            Reason,
            ExchangeVariantId,
            CustomerNotes,
            Status,
            Restocked,
            CreatedAt,
            UpdatedAt
        )
        VALUES (
            @NewRmaNumber,
            @OrderId,
            @OrderItemId,
            @UserId,
            @RequestType,
            @Reason,
            @ExchangeVariantId,
            @CustomerNotes,
            N'Pending',
            0,
            SYSUTCDATETIME(),
            SYSUTCDATETIME()
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
        SET @NewRmaId = NULL;
        SET @NewRmaNumber = NULL;
    END CATCH;
END;
GO
