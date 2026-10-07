<# Runs business regressions in a uniquely named disposable database. No presentation data is modified. #>
[CmdletBinding()]
param([string]$Server = '.\SQLEXPRESS')
$ErrorActionPreference = 'Stop'
$testDatabase = 'HelmetCartelBusinessTest_' + [Guid]::NewGuid().ToString('N')
$master = New-Object System.Data.SqlClient.SqlConnection "Data Source=$Server;Initial Catalog=master;Integrated Security=True;Encrypt=False"
$connection = New-Object System.Data.SqlClient.SqlConnection "Data Source=$Server;Initial Catalog=$testDatabase;Integrated Security=True;Encrypt=False"
function Query([string]$sql, $transaction = $null) {
    $command = $connection.CreateCommand(); $command.CommandText = $sql; $command.CommandTimeout = 30
    if ($transaction) { $command.Transaction = $transaction }
    try { $reader = $command.ExecuteReader(); $table = New-Object System.Data.DataTable; $table.Load($reader); $reader.Close(); return ,$table }
    finally { $command.Dispose() }
}
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Case([string]$name, [scriptblock]$action) {
    $tx = $connection.BeginTransaction()
    try { & $action $tx; Write-Output "PASS: $name" }
    finally { try { $tx.Rollback() } catch {} }
}
$fixture = @'
INSERT dbo.Users(RoleId,FirstName,LastName,Email,PasswordHash,Salt,PhoneNumber)
SELECT Id,N'Business',N'Owner',N'owner@example.invalid',N'test',N'test',N'09990000001' FROM dbo.Roles WHERE Name=N'Customer';
INSERT dbo.Users(RoleId,FirstName,LastName,Email,PasswordHash,Salt,PhoneNumber)
SELECT Id,N'Other',N'Customer',N'other@example.invalid',N'test',N'test',N'09990000002' FROM dbo.Roles WHERE Name=N'Customer';
INSERT dbo.Users(RoleId,FirstName,LastName,Email,PasswordHash,Salt,PhoneNumber)
SELECT Id,N'Test',N'Staff',N'staff@example.invalid',N'test',N'test',N'09990000003' FROM dbo.Roles WHERE Name=N'Staff';
DECLARE @User INT=(SELECT Id FROM dbo.Users WHERE Email=N'owner@example.invalid'),
 @Variant INT=(SELECT TOP 1 VariantId FROM dbo.Inventories ORDER BY VariantId);
UPDATE dbo.Inventories SET CurrentStock=3,ReservedStock=0 WHERE VariantId=@Variant;
INSERT dbo.Orders(OrderNumber,UserId,CustomerName,CustomerEmail,CustomerPhone,OrderSource,Status,Subtotal,ShippingMethod)
VALUES(N'BUSINESS-A',@User,N'Owner',N'owner@example.invalid',N'09990000001',N'ONLINE',N'Processing',1000,N'Pickup');
DECLARE @A INT=SCOPE_IDENTITY(); EXEC dbo.sp_AddOrderItem @A,@Variant,1,1000,1000;
INSERT dbo.Payments(OrderId,PaymentGateway,GatewayReference,Amount,Status,PaidAt)
VALUES(@A,N'HitPay',N'BUSINESS-PAID',1000,N'Completed',SYSUTCDATETIME());
INSERT dbo.StockAuditLogs(VariantId,UserId,ChangeType,PreviousStock,QuantityChanged,ReferenceNumber)
VALUES(@Variant,@User,N'ONLINE_SALE',3,-1,N'BUSINESS-A');
INSERT dbo.Orders(OrderNumber,UserId,CustomerName,CustomerEmail,CustomerPhone,OrderSource,Status,Subtotal,ShippingMethod)
VALUES(N'BUSINESS-B',@User,N'Owner',N'owner@example.invalid',N'09990000001',N'ONLINE',N'PendingPayment',1000,N'Pickup');
DECLARE @B INT=SCOPE_IDENTITY(); EXEC dbo.sp_AddOrderItem @B,@Variant,1,1000,1000;
UPDATE dbo.Inventories SET CurrentStock=2,ReservedStock=1 WHERE VariantId=@Variant;
'@
try {
    $master.Open()
    $installer = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'new_database_minimal.sql'))
    $installer = $installer.Replace('[HelmetCartelDB]', "[$testDatabase]").Replace("N'HelmetCartelDB'", "N'$testDatabase'")
    foreach ($batch in [regex]::Split($installer, '(?im)^\s*GO\s*$')) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $command = $master.CreateCommand(); $command.CommandText=$batch; $command.CommandTimeout=120
        try { [void]$command.ExecuteNonQuery() } finally { $command.Dispose() }
    }
    $connection.Open(); [void](Query $fixture)
    Write-Output 'PASS: complete fresh structural installer through migration 52'
    $variant = (Query "SELECT VariantId FROM dbo.OrderItems WHERE OrderId=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A')").Rows[0].VariantId
    Case 'paid fulfillment preserves another order reservation' {
        param($tx)
        [void](Query "DECLARE @a INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A'); EXEC dbo.sp_AdminUpdateOrderStatus @a,N'ReadyForPickup'; EXEC dbo.sp_AdminUpdateOrderStatus @a,N'Completed';" $tx)
        $stock=(Query "SELECT CurrentStock,ReservedStock FROM dbo.Inventories WHERE VariantId=$variant" $tx).Rows[0]
        Assert ($stock.CurrentStock -eq 2 -and $stock.ReservedStock -eq 1) 'Paid fulfillment consumed another reservation.'
    }
    Case 'paid cancellation restores only physical stock and keeps payment history' {
        param($tx)
        $result=Query "DECLARE @a INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A'),@u INT=(SELECT Id FROM dbo.Users WHERE Email=N'owner@example.invalid'),@ok BIT,@e NVARCHAR(255); EXEC dbo.sp_CustomerCancelOrder @a,@u,NULL,N'Test',@ok OUTPUT,@e OUTPUT; SELECT @ok AS Success;" $tx
        Assert $result.Rows[0].Success 'Owner cancellation failed.'
        $stock=(Query "SELECT CurrentStock,ReservedStock FROM dbo.Inventories WHERE VariantId=$variant" $tx).Rows[0]
        Assert ($stock.CurrentStock -eq 3 -and $stock.ReservedStock -eq 1) 'Cancellation consumed another reservation.'
        Assert ((Query "SELECT Status FROM dbo.Payments WHERE GatewayReference=N'BUSINESS-PAID'" $tx).Rows[0].Status -eq 'Completed') 'Cancellation claimed a gateway refund.'
    }
    foreach ($identity in @('NULL', "(SELECT Id FROM dbo.Users WHERE Email=N'other@example.invalid')")) {
            $result=Query "DECLARE @a INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A'),@u INT=$identity,@ok BIT,@e NVARCHAR(255); EXEC dbo.sp_CustomerCancelOrder @a,@u,NULL,N'Test',@ok OUTPUT,@e OUTPUT; SELECT @ok AS Success;"
            Assert (-not $result.Rows[0].Success) 'Unauthorized cancellation accepted.'
            Write-Output "PASS: cancellation rejects identity $identity"
    }
    Case 'cash pickup commits stock exactly once and records sale audit' {
        param($tx)
        [void](Query "DECLARE @b INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-B'); UPDATE dbo.Orders SET Status=N'Processing' WHERE Id=@b; INSERT dbo.Payments(OrderId,PaymentGateway,Amount,Status) VALUES(@b,N'Cash',1000,N'Pending'); EXEC dbo.sp_AdminUpdateOrderStatus @b,N'ReadyForPickup'; EXEC dbo.sp_AdminUpdateOrderStatus @b,N'Completed';" $tx)
        $stock=(Query "SELECT CurrentStock,ReservedStock FROM dbo.Inventories WHERE VariantId=$variant" $tx).Rows[0]
        Assert ($stock.CurrentStock -eq 1 -and $stock.ReservedStock -eq 0) 'Cash fulfillment stock is incorrect.'
        Assert ((Query "SELECT COUNT(*) AS N FROM dbo.StockAuditLogs WHERE ReferenceNumber=N'BUSINESS-B' AND ChangeType=N'ONLINE_SALE'" $tx).Rows[0].N -eq 1) 'Missing cash sale audit.'
    }
    Case 'pickup cannot enter shipping state' {
        param($tx)
        try { [void](Query "DECLARE @a INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A'); EXEC dbo.sp_AdminUpdateOrderStatus @a,N'Shipped',NULL,N'Courier',N'TEST';" $tx); throw 'Pickup shipped unexpectedly.' }
        catch { Assert ($_.Exception.InnerException.Number -eq 52002) 'Incorrect fulfillment rejection.' }
    }
    Case 'exchange and approval do not reduce settled revenue' {
        param($tx)
        [void](Query "DECLARE @a INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A'); DECLARE @item INT=(SELECT TOP 1 Id FROM dbo.OrderItems WHERE OrderId=@a); UPDATE dbo.Orders SET Status=N'Completed',DiscountAmount=100,ShippingFee=150 WHERE Id=@a; INSERT dbo.ReturnRequests(RmaNumber,OrderId,OrderItemId,UserId,RequestType,Reason,Status,ResolutionType,RefundAmount) SELECT N'BUSINESS-RMA',@a,@item,UserId,N'EXCHANGE',N'WRONG_SIZE',N'Completed',N'REPLACEMENT',1000 FROM dbo.Orders WHERE Id=@a;" $tx)
        Assert ((Query "SELECT Revenue FROM dbo.v_SettledOrderRevenue WHERE OrderId=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A')" $tx).Rows[0].Revenue -eq 900) 'Exchange reduced net merchandise revenue.'
        [void](Query "UPDATE dbo.ReturnRequests SET RequestType=N'RETURN',ResolutionType=N'REFUND',Status=N'Approved',RefundAmount=250 WHERE RmaNumber=N'BUSINESS-RMA'" $tx)
        Assert ((Query "SELECT Revenue FROM dbo.v_SettledOrderRevenue WHERE OrderId=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A')" $tx).Rows[0].Revenue -eq 900) 'Approval counted as completed refund.'
        [void](Query "UPDATE dbo.ReturnRequests SET Status=N'Completed' WHERE RmaNumber=N'BUSINESS-RMA'" $tx)
        Assert ((Query "SELECT Revenue FROM dbo.v_SettledOrderRevenue WHERE OrderId=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A')" $tx).Rows[0].Revenue -eq 650) 'Confirmed partial refund was not deducted.'
        Assert ((Query "SELECT Revenue FROM dbo.v_SettledSalesLines WHERE OrderId=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A')" $tx).Rows[0].Revenue -eq 650) 'Line and summary revenue disagree.'
    }
    Case 'manual return requires receipt, respects discount, and restocks once' {
        param($tx)
        [void](Query @'
DECLARE @a INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A');
UPDATE dbo.Orders SET Status=N'Completed',DiscountAmount=100 WHERE Id=@a;
INSERT dbo.ReturnRequests(RmaNumber,OrderId,OrderItemId,UserId,RequestType,Reason,Status)
SELECT N'BUSINESS-REFUND',@a,oi.Id,o.UserId,N'RETURN',N'DEFECTIVE',N'Pending'
FROM dbo.OrderItems oi JOIN dbo.Orders o ON o.Id=oi.OrderId WHERE o.Id=@a;
DECLARE @id INT=SCOPE_IDENTITY(),@staff INT=(SELECT Id FROM dbo.Users WHERE Email=N'staff@example.invalid'),@ok BIT,@error NVARCHAR(255);
EXEC dbo.sp_AdminProcessReturnRequest @id,N'Approved',@ProcessedBy=@staff,@Success=@ok OUTPUT,@ErrorMessage=@error OUTPUT;
IF @ok<>1 THROW 56001,N'Return approval failed.',1;
EXEC dbo.sp_AdminProcessReturnRequest @id,N'Received',@ProcessedBy=@staff,@Success=@ok OUTPUT,@ErrorMessage=@error OUTPUT;
IF @ok<>1 THROW 56002,N'Return receipt failed.',1;
'@ $tx)
        Assert ((Query "SELECT CurrentStock FROM dbo.Inventories WHERE VariantId=$variant" $tx).Rows[0].CurrentStock -eq 2) 'Approval or receipt restocked early.'
        [void](Query @'
DECLARE @id INT=(SELECT Id FROM dbo.ReturnRequests WHERE RmaNumber=N'BUSINESS-REFUND'),@staff INT=(SELECT Id FROM dbo.Users WHERE Email=N'staff@example.invalid'),@ok BIT,@error NVARCHAR(255);
EXEC dbo.sp_AdminProcessReturnRequest @id,N'Completed',@RestockItem=1,@AdminNotes=N'Manual refund receipt TEST-REFUND confirmed.',@ProcessedBy=@staff,@Success=@ok OUTPUT,@ErrorMessage=@error OUTPUT;
IF @ok<>1 THROW 56003,N'Manual return completion failed.',1;
'@ $tx)
        $rma=(Query "SELECT Status,RefundAmount,Restocked FROM dbo.ReturnRequests WHERE RmaNumber=N'BUSINESS-REFUND'" $tx).Rows[0]
        Assert ($rma.Status -eq 'Completed' -and $rma.RefundAmount -eq 900 -and $rma.Restocked) 'Refund ignored merchandise discount or inspection.'
        $stock=(Query "SELECT CurrentStock,ReservedStock FROM dbo.Inventories WHERE VariantId=$variant" $tx).Rows[0]
        Assert ($stock.CurrentStock -eq 3 -and $stock.ReservedStock -eq 1) 'Return changed another reservation.'
    }
    Case 'equal-price exchange deducts replacement availability and records handover' {
        param($tx)
        [void](Query @'
DECLARE @a INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'BUSINESS-A'),@replacement INT;
SELECT TOP 1 @replacement=v.Id FROM dbo.ProductVariants v JOIN dbo.ProductColors pc ON pc.Id=v.ProductColorId
JOIN dbo.ProductColors originalColor ON originalColor.ProductId=pc.ProductId
JOIN dbo.ProductVariants original ON original.ProductColorId=originalColor.Id
JOIN dbo.OrderItems oi ON oi.VariantId=original.Id WHERE oi.OrderId=@a AND v.Id<>original.Id ORDER BY v.Id;
IF @replacement IS NULL THROW 56004,N'Fixture needs another product variant.',1;
UPDATE dbo.Inventories SET CurrentStock=3,ReservedStock=1 WHERE VariantId=@replacement;
UPDATE oi SET UnitPrice=dbo.fn_CalculateEffectivePrice(p.BasePrice,v.PriceAdjustment,p.DiscountPercentage,p.DiscountType,p.DiscountAmount,p.DiscountStartDate,p.DiscountEndDate,p.DiscountIsActive)
FROM dbo.OrderItems oi CROSS JOIN dbo.ProductVariants v JOIN dbo.ProductColors pc ON pc.Id=v.ProductColorId JOIN dbo.Products p ON p.Id=pc.ProductId
WHERE oi.OrderId=@a AND v.Id=@replacement;
UPDATE dbo.Orders SET Status=N'Completed',Subtotal=(SELECT SUM(TotalPrice) FROM dbo.OrderItems WHERE OrderId=@a) WHERE Id=@a;
INSERT dbo.ReturnRequests(RmaNumber,OrderId,OrderItemId,UserId,RequestType,Reason,Status)
SELECT N'BUSINESS-EXCHANGE',@a,oi.Id,o.UserId,N'EXCHANGE',N'WRONG_SIZE',N'Received' FROM dbo.OrderItems oi JOIN dbo.Orders o ON o.Id=oi.OrderId WHERE o.Id=@a;
DECLARE @id INT=SCOPE_IDENTITY(),@staff INT=(SELECT Id FROM dbo.Users WHERE Email=N'staff@example.invalid'),@ok BIT,@error NVARCHAR(255);
EXEC dbo.sp_AdminReturnReplacements @id;
EXEC dbo.sp_AdminProcessReturnRequest @id,N'Completed',@AdminNotes=N'Replacement handover receipt TEST-EXCHANGE confirmed.',@ProcessedBy=@staff,@Success=@ok OUTPUT,@ErrorMessage=@error OUTPUT,@ExchangeVariantId=@replacement;
IF @ok<>1 THROW 56005,N'Exchange completion failed.',1;
'@ $tx)
        $rma=(Query "SELECT RefundAmount,ExchangeVariantId FROM dbo.ReturnRequests WHERE RmaNumber=N'BUSINESS-EXCHANGE'" $tx).Rows[0]
        Assert ($rma.RefundAmount -eq 0) 'Exchange falsely recorded a refund.'
        $stock=(Query "SELECT CurrentStock,ReservedStock FROM dbo.Inventories WHERE VariantId=$($rma.ExchangeVariantId)" $tx).Rows[0]
        Assert ($stock.CurrentStock -eq 2 -and $stock.ReservedStock -eq 1) 'Exchange did not deduct only available stock.'
        Assert ((Query "SELECT COUNT(*) N FROM dbo.StockAuditLogs WHERE ReferenceNumber=N'BUSINESS-EXCHANGE' AND QuantityChanged=-1" $tx).Rows[0].N -eq 1) 'Replacement audit missing.'
    }
    [void](Query "INSERT dbo.ReturnRequests(RmaNumber,OrderId,OrderItemId,UserId,RequestType,Reason,Status) SELECT N'BUSINESS-INVALID',o.Id,oi.Id,o.UserId,N'RETURN',N'DEFECTIVE',N'Pending' FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.OrderId=o.Id WHERE o.OrderNumber=N'BUSINESS-A';")
    foreach ($attempt in @(
        @{Name='return rejects customer processing'; Status='Approved'; Actor="owner@example.invalid"; Refund='NULL'; Notes="N'Test'"},
        @{Name='return rejects completion before receipt'; Status='Completed'; Actor="staff@example.invalid"; Refund='NULL'; Notes="N'Test'"},
        @{Name='return rejects refund above merchandise value'; Status='Approved'; Actor="staff@example.invalid"; Refund='1001'; Notes="N'Test'"}
    )) {
        $result=Query "DECLARE @id INT=(SELECT Id FROM dbo.ReturnRequests WHERE RmaNumber=N'BUSINESS-INVALID'),@actor INT=(SELECT Id FROM dbo.Users WHERE Email=N'$($attempt.Actor)'),@ok BIT,@e NVARCHAR(255); EXEC dbo.sp_AdminProcessReturnRequest @id,N'$($attempt.Status)',@RefundAmount=$($attempt.Refund),@AdminNotes=$($attempt.Notes),@ProcessedBy=@actor,@Success=@ok OUTPUT,@ErrorMessage=@e OUTPUT; SELECT @ok Success;"
        Assert (-not $result.Rows[0].Success) $attempt.Name
        Write-Output "PASS: $($attempt.Name)"
    }
    # Verify reporting procedure shapes through the actual C# data readers.
    $appRoot=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'HelmetCartelOrderingAndManagementSys'
    [void][Reflection.Assembly]::LoadFrom((Join-Path $appRoot 'bin/Newtonsoft.Json.dll'))
    [void][Reflection.Assembly]::LoadFrom((Join-Path $appRoot 'bin/HelmetCartelOrderingAndManagementSys.dll'))
    $factory=New-Object HelmetCartelOrderingAndManagementSys.Infrastructure.DbConnectionFactory $connection.ConnectionString
    $reports=New-Object HelmetCartelOrderingAndManagementSys.Repositories.AdminDataRepository $factory
    $start=[DateTime]::UtcNow.Date.AddYears(-10); $end=[DateTime]::UtcNow.Date.AddDays(1)
    $daily=$reports.GetDailySalesAsync($start,$end).GetAwaiter().GetResult()
    $hourly=$reports.GetHourlySalesAsync([DateTime]::UtcNow.Date).GetAwaiter().GetResult()
    $performance=$reports.GetSalesPerformanceAsync($start,$end).GetAwaiter().GetResult()
    $dimensions=$reports.GetSalesByBrandAndCategoryAsync($start,$end).GetAwaiter().GetResult()
    Assert ($daily.Count -gt 0 -and $performance.Count -gt 0 -and $dimensions.Brands.Count -gt 0 -and $dimensions.Categories.Count -gt 0) 'Fresh sample report mappings returned no data.'
    $returns=New-Object HelmetCartelOrderingAndManagementSys.Repositories.ReturnRepository $factory
    Assert ($returns.AdminGetReturnRequestsAsync().GetAwaiter().GetResult().Count -gt 0) 'Return administration mapping failed.'
    Write-Output 'PASS: C# daily/hourly/product/brand/category report and return data-reader contracts'
    # Two independent connections compete for the final unreserved unit.
    $other=New-Object System.Data.SqlClient.SqlConnection $connection.ConnectionString; $other.Open()
    $txA=$connection.BeginTransaction(); $txB=$other.BeginTransaction()
    try {
        [void](Query "DECLARE @ok BIT,@e NVARCHAR(255); EXEC dbo.sp_ReserveStockAtomic $variant,1,N'TEST-A',@ok OUTPUT,@e OUTPUT;" $txA)
        $commandB=$other.CreateCommand(); $commandB.Transaction=$txB; $commandB.CommandTimeout=10
        $commandB.CommandText="DECLARE @ok BIT,@e NVARCHAR(255); EXEC dbo.sp_ReserveStockAtomic $variant,1,N'TEST-B',@ok OUTPUT,@e OUTPUT; SELECT @ok;"
        $taskB=$commandB.ExecuteScalarAsync()
        Assert (-not $taskB.Wait(250)) 'Concurrent reservation bypassed row lock.'
        $txA.Commit(); Assert (-not $taskB.GetAwaiter().GetResult()) 'Second buyer received unavailable unit.'
        Write-Output 'PASS: concurrent last-unit reservation serializes and rejects second buyer'
    } finally { try {$txA.Rollback()} catch {}; try {$txB.Rollback()} catch {}; $other.Dispose() }
    Write-Output 'All business integrity checks passed.'
} finally {
    $connection.Dispose(); [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    if ($testDatabase -notmatch '^HelmetCartelBusinessTest_[a-f0-9]{32}$') { throw 'Unsafe test database cleanup target.' }
    if ($master.State -eq 'Open') {
        $master.ChangeDatabase('master'); $command=$master.CreateCommand()
        $command.CommandText="IF DB_ID(N'$testDatabase') IS NOT NULL BEGIN ALTER DATABASE [$testDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$testDatabase]; END"
        try {[void]$command.ExecuteNonQuery(); Write-Output 'Isolated test database removed.'} finally {$command.Dispose()}
    }
    $master.Dispose()
}
