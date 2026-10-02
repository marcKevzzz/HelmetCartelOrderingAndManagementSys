-- ============================================================================
-- Script: Truncate All Orders, OrderItems, Payments, ReturnRequests
-- Reseeds IDs and resets ReservedStock in Inventories to 0
-- ============================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRANSACTION;

-- 1. Delete Return Requests
DELETE FROM dbo.ReturnRequests;

-- 2. Clear any Review order references
UPDATE dbo.ProductReviews SET OrderId = NULL WHERE OrderId IS NOT NULL;

-- 3. Delete Order Items
DELETE FROM dbo.OrderItems;

-- 4. Delete Payments
DELETE FROM dbo.Payments;

-- 5. Delete Orders
DELETE FROM dbo.Orders;

-- 6. Delete Stock Audit Logs (Recent Activity Feed)
DELETE FROM dbo.StockAuditLogs;

-- 7. Reset ReservedStock in Inventories to 0
UPDATE dbo.Inventories SET ReservedStock = 0;

-- 8. Reseed identities so next inserted IDs start from 1
DBCC CHECKIDENT ('dbo.ReturnRequests', RESEED, 0);
DBCC CHECKIDENT ('dbo.Payments', RESEED, 0);
DBCC CHECKIDENT ('dbo.OrderItems', RESEED, 0);
DBCC CHECKIDENT ('dbo.Orders', RESEED, 0);
DBCC CHECKIDENT ('dbo.StockAuditLogs', RESEED, 0);

COMMIT TRANSACTION;
GO

-- Verification
SELECT COUNT(*) AS OrdersCount FROM dbo.Orders;
SELECT COUNT(*) AS PaymentsCount FROM dbo.Payments;
SELECT COUNT(*) AS OrderItemsCount FROM dbo.OrderItems;
SELECT COUNT(*) AS ReturnRequestsCount FROM dbo.ReturnRequests;
SELECT COUNT(*) AS StockAuditLogsCount FROM dbo.StockAuditLogs;
SELECT SUM(ReservedStock) AS TotalReservedStock FROM dbo.Inventories;
GO
