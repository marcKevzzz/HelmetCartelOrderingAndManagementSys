USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;
BEGIN TRANSACTION;

-- Only insert if Orders is currently empty
IF NOT EXISTS (SELECT 1 FROM dbo.Orders)
BEGIN
    -- 1. Completed In-Store POS Sale (Today)
    INSERT INTO dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt)
    VALUES (N'HC-20260928-1001', 2, N'Rico Manuel', N'rico.manuel@gmail.com', N'+639178881234', N'INSTORE_POS', N'Completed', 18500.00, 0, N'Walk-in purchase. Cash paid at counter.', SYSUTCDATETIME());
    DECLARE @O1 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@O1, 15, 1, 18500.00);

    INSERT INTO dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
    VALUES (@O1, N'Cash', N'POS-CASH-1001', 18500.00, N'Completed', SYSUTCDATETIME(), SYSUTCDATETIME());

    -- 2. Processing Online Order (Today)
    INSERT INTO dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt)
    VALUES (N'HC-20260928-1002', 3, N'Juan Dela Cruz', N'juan@rider.com', N'+639175556666', N'ONLINE', N'Processing', 24900.00, 0, N'Paid via HitPay. Preparing for packing.', SYSUTCDATETIME());
    DECLARE @O2 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@O2, 20, 1, 24900.00);

    INSERT INTO dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
    VALUES (@O2, N'HitPay', N'hp_pay_928_1002', 24900.00, N'Completed', SYSUTCDATETIME(), SYSUTCDATETIME());

    -- 3. Ready For Pickup Online Order (Today)
    INSERT INTO dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt)
    VALUES (N'HC-20260928-1003', NULL, N'Angelo Gomez', N'angelo.gomez@yahoo.com', N'+639184447788', N'ONLINE', N'ReadyForPickup', 32000.00, 0, N'Item boxed and placed at pickup station A1.', SYSUTCDATETIME());
    DECLARE @O3 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@O3, 16, 1, 32000.00);

    INSERT INTO dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
    VALUES (@O3, N'HitPay', N'hp_pay_928_1003', 32000.00, N'Completed', SYSUTCDATETIME(), SYSUTCDATETIME());

    -- 4. Pending Payment Online Order (Today)
    INSERT INTO dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt)
    VALUES (N'HC-20260928-1004', NULL, N'Carlos Mendoza', N'cmendoza@outlook.com', N'+639201113344', N'ONLINE', N'PendingPayment', 14500.00, 0, N'Awaiting HitPay payment confirmation.', SYSUTCDATETIME());
    DECLARE @O4 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@O4, 17, 1, 14500.00);

    INSERT INTO dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
    VALUES (@O4, N'HitPay', N'hp_pay_928_1004', 14500.00, N'Pending', NULL, SYSUTCDATETIME());

    -- 5. Completed Online Order (1 Day Ago)
    INSERT INTO dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt)
    VALUES (N'HC-20260927-1005', 3, N'Juan Dela Cruz', N'juan@rider.com', N'+639175556666', N'ONLINE', N'Completed', 43000.00, 0, N'Successfully picked up by customer.', DATEADD(day, -1, SYSUTCDATETIME()));
    DECLARE @O5 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@O5, 18, 1, 43000.00);

    INSERT INTO dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
    VALUES (@O5, N'HitPay', N'hp_pay_927_1005', 43000.00, N'Completed', DATEADD(day, -1, SYSUTCDATETIME()), DATEADD(day, -1, SYSUTCDATETIME()));

    -- 6. Completed In-Store Sale (2 Days Ago)
    INSERT INTO dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt)
    VALUES (N'HC-20260926-1006', 2, N'Derrick Santos', N'derrick.s@gmail.com', N'+639152229988', N'INSTORE_POS', N'Completed', 26500.00, 0, N'Card POS payment at register 1.', DATEADD(day, -2, SYSUTCDATETIME()));
    DECLARE @O6 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@O6, 15, 1, 26500.00);

    INSERT INTO dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
    VALUES (@O6, N'Card_POS', N'POS-CARD-1006', 26500.00, N'Completed', DATEADD(day, -2, SYSUTCDATETIME()), DATEADD(day, -2, SYSUTCDATETIME()));

    -- 7. Completed Online Order (3 Days Ago)
    INSERT INTO dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, DiscountAmount, Notes, CreatedAt)
    VALUES (N'HC-20260925-1007', NULL, N'Vincent Tan', N'vince.tan@gmail.com', N'+639179998877', N'ONLINE', N'Completed', 19800.00, 0, N'Pickup verified.', DATEADD(day, -3, SYSUTCDATETIME()));
    DECLARE @O7 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice)
    VALUES (@O7, 21, 1, 19800.00);

    INSERT INTO dbo.Payments (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt)
    VALUES (@O7, N'HitPay', N'hp_pay_925_1007', 19800.00, N'Completed', DATEADD(day, -3, SYSUTCDATETIME()), DATEADD(day, -3, SYSUTCDATETIME()));
END;

COMMIT TRANSACTION;
GO
