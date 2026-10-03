<# Creates and removes an isolated database; never inserts test records into HelmetCartelDB.
   Run using Windows PowerShell with local SQL Server access. #>
[CmdletBinding()]
param([string]$Server = '.\SQLEXPRESS')
$ErrorActionPreference = 'Stop'
$testDatabase = 'HelmetCartelVoucherTest_' + [Guid]::NewGuid().ToString('N')
$master = New-Object System.Data.SqlClient.SqlConnection "Data Source=$Server;Initial Catalog=master;Integrated Security=True;Encrypt=False"
$connection = New-Object System.Data.SqlClient.SqlConnection "Data Source=$Server;Initial Catalog=$testDatabase;Integrated Security=True;Encrypt=False"
$created = $false
function Query([string]$sql, $transaction = $null) {
    $command = $connection.CreateCommand()
    $command.CommandText = $sql
    $command.CommandTimeout = 30
    if ($transaction) { $command.Transaction = $transaction }
    try {
        $reader = $command.ExecuteReader()
        $table = New-Object System.Data.DataTable
        $table.Load($reader)
        $reader.Close()
        return ,$table
    } finally { $command.Dispose() }
}
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Case([string]$name, [scriptblock]$action) {
    $transaction = $connection.BeginTransaction()
    try { & $action $transaction; Write-Output "PASS: $name" }
    finally { try { $transaction.Rollback() } catch {} }
}
function ExpectError([string]$sql, [int]$number, $transaction) {
    try { [void](Query $sql $transaction) }
    catch { if ($_.Exception.InnerException.Number -eq $number) { return }; throw }
    throw "Expected SQL error $number."
}
$fixture = @'
INSERT dbo.Vouchers(Code, DiscountType, DiscountValue, MinimumSpend, UsageLimit)
VALUES (N'TEST-PERCENT', N'PERCENTAGE', 12.50, 100, 1);
INSERT dbo.Vouchers(Code, DiscountType, DiscountValue) VALUES (N'TEST-FIXED', N'FIXED_AMOUNT', 500);
INSERT dbo.Vouchers(Code, DiscountType, DiscountValue, ExpiresAt) VALUES (N'TEST-EXPIRED', N'PERCENTAGE', 10, DATEADD(DAY,-1,SYSUTCDATETIME()));
INSERT dbo.Vouchers(Code, DiscountType, DiscountValue, IsActive) VALUES (N'TEST-INACTIVE', N'PERCENTAGE', 10, 0);
INSERT dbo.Orders(OrderNumber, CustomerName, CustomerEmail, CustomerPhone, OrderSource, Status, Subtotal, ShippingFee)
VALUES (N'VOUCHER-TEST-ORDER', N'Test', N'test@example.invalid', N'000', N'ONLINE', N'PendingPayment', 1000, 150);
DECLARE @OrderId INT = SCOPE_IDENTITY(), @VariantId INT = (SELECT TOP 1 Id FROM dbo.ProductVariants ORDER BY Id);
EXEC dbo.sp_AddOrderItem @OrderId, @VariantId, 1, 1000, 1000;
'@
try {
    $master.Open()
    $installer = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'new_database_minimal.sql'))
    $installer = $installer.Replace('[HelmetCartelDB]', "[$testDatabase]").Replace("N'HelmetCartelDB'", "N'$testDatabase'")
    foreach ($batch in [regex]::Split($installer, '(?im)^\s*GO\s*$')) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $command = $master.CreateCommand(); $command.CommandText = $batch; $command.CommandTimeout = 120
        try { [void]$command.ExecuteNonQuery() } finally { $command.Dispose() }
        if ($master.Database -eq $testDatabase) { $created = $true }
    }
    $connection.Open()
    Write-Output 'PASS: current fresh installer, including voucher and specifications migrations'
    [void](Query $fixture)
    Case 'percentage calculation, rounding, normalization, shipping excluded' {
        param($tx)
        $row = (Query "DECLARE @id INT, @d DECIMAL(18,2); EXEC dbo.sp_CalculateVoucher N' test-percent ', 1000.05, 0, @id OUTPUT, @d OUTPUT; SELECT @d AS Discount;" $tx).Rows[0]
        Assert ($row.Discount -eq 125.01) 'Incorrect percentage rounding.'
        $row = (Query "DECLARE @o INT = (SELECT Id FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'); EXEC dbo.sp_ApplyOrderVoucher @o, N'test-percent';" $tx).Rows[0]
        Assert ($row.Code -eq 'TEST-PERCENT' -and $row.DiscountAmount -eq 125) 'Incorrect saved voucher.'
        Assert ((Query "SELECT TotalAmount FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'" $tx).Rows[0].TotalAmount -eq 1025) 'Shipping was discounted.'
    }
    Case 'fixed discount capped at merchandise subtotal' {
        param($tx)
        $row = (Query "DECLARE @id INT, @d DECIMAL(18,2); EXEC dbo.sp_CalculateVoucher N'TEST-FIXED', 100, 0, @id OUTPUT, @d OUTPUT; SELECT @d AS Discount;" $tx).Rows[0]
        Assert ($row.Discount -eq 100) 'Fixed discount was not capped.'
    }
    foreach ($item in @(@('unknown code', 'UNKNOWN', 1000, 54009), @('expired code', 'TEST-EXPIRED', 1000, 54011), @('inactive code', 'TEST-INACTIVE', 1000, 54010), @('minimum spend', 'TEST-PERCENT', 99, 54012))) {
        $caseCode = $item[1]; $caseSubtotal = $item[2]; $caseNumber = $item[3]
        Case $item[0] { param($tx); ExpectError "DECLARE @id INT, @d DECIMAL(18,2); EXEC dbo.sp_CalculateVoucher N'$caseCode', $caseSubtotal, 0, @id OUTPUT, @d OUTPUT;" $caseNumber $tx }
    }
    Case 'second redemption rejected' {
        param($tx)
        [void](Query "DECLARE @o INT = (SELECT Id FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'); EXEC dbo.sp_ApplyOrderVoucher @o, N'TEST-PERCENT';" $tx)
        ExpectError "DECLARE @id INT, @d DECIMAL(18,2); EXEC dbo.sp_CalculateVoucher N'TEST-PERCENT', 1000, 1, @id OUTPUT, @d OUTPUT;" 54013 $tx
    }
    Case 'cancellation releases once and preserves receipt snapshot' {
        param($tx)
        [void](Query "DECLARE @o INT = (SELECT Id FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'); EXEC dbo.sp_ApplyOrderVoucher @o, N'TEST-PERCENT'; UPDATE dbo.Orders SET Status=N'Cancelled' WHERE Id=@o; UPDATE dbo.Orders SET Status=N'Cancelled' WHERE Id=@o;" $tx)
        $row = (Query "SELECT COUNT(*) AS Released FROM dbo.VoucherRedemptions WHERE ReleasedAt IS NOT NULL;" $tx).Rows[0]
        Assert ($row.Released -eq 1) 'Redemption release failed.'
        $row = (Query "SELECT VoucherCode, DiscountAmount FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER';" $tx).Rows[0]
        Assert ($row.VoucherCode -eq 'TEST-PERCENT' -and $row.DiscountAmount -eq 125) 'Historical receipt changed.'
        [void](Query "DECLARE @id INT, @d DECIMAL(18,2); EXEC dbo.sp_CalculateVoucher N'TEST-PERCENT', 1000, 1, @id OUTPUT, @d OUTPUT;" $tx)
    }
    Case 'receipt snapshot survives discount edit' {
        param($tx)
        [void](Query "DECLARE @o INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'); EXEC dbo.sp_ApplyOrderVoucher @o, N'TEST-PERCENT'; DECLARE @id INT=(SELECT Id FROM dbo.Vouchers WHERE Code=N'TEST-PERCENT'); EXEC dbo.sp_AdminSaveVoucher @Id=@id, @Code=N'TEST-PERCENT', @DiscountType=N'FIXED_AMOUNT', @DiscountValue=50;" $tx)
        $row=(Query "SELECT VoucherCode, DiscountAmount FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER';" $tx).Rows[0]
        Assert ($row.VoucherCode -eq 'TEST-PERCENT' -and $row.DiscountAmount -eq 125) 'Voucher edit changed historical receipt.'
    }
    Case 'redeemed code cannot be renamed' {
        param($tx)
        [void](Query "DECLARE @o INT = (SELECT Id FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'); EXEC dbo.sp_ApplyOrderVoucher @o, N'TEST-PERCENT';" $tx)
        ExpectError "DECLARE @id INT = (SELECT Id FROM dbo.Vouchers WHERE Code=N'TEST-PERCENT'); EXEC dbo.sp_AdminSaveVoucher @Id=@id, @Code=N'RENAMED', @DiscountType=N'PERCENTAGE', @DiscountValue=10;" 54006 $tx
    }
    Case 'preview uses effective product discounts' {
        param($tx)
        [void](Query "UPDATE dbo.Products SET DiscountIsActive=1, DiscountType=N'FIXED_AMOUNT', DiscountAmount=100, DiscountPercentage=0, DiscountStartDate=NULL, DiscountEndDate=NULL;" $tx)
        $row = (Query "DECLARE @items dbo.SaleLineInput; INSERT @items SELECT TOP 1 v.Id, 1 FROM dbo.v_VisibleProductVariants v; EXEC dbo.sp_PreviewVoucher N'TEST-FIXED', @items;" $tx).Rows[0]
        Assert ($row.Subtotal -gt 0 -and $row.DiscountedSubtotal -eq $row.Subtotal - $row.DiscountAmount) 'Preview total mismatch.'
        $expected = (Query "SELECT TOP 1 CONVERT(DECIMAL(18,2), dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,p.DiscountPercentage,p.DiscountType,p.DiscountAmount,p.DiscountStartDate,p.DiscountEndDate,p.DiscountIsActive)) AS Price FROM dbo.v_VisibleProductVariants v JOIN dbo.ProductColors c ON c.Id=v.ProductColorId JOIN dbo.Products p ON p.Id=c.ProductId;" $tx).Rows[0].Price
        Assert ($row.Subtotal -eq $expected) 'Preview ignored existing promotion.'
    }
    Case 'duplicate preview items rejected' { param($tx); ExpectError "DECLARE @items dbo.SaleLineInput; DECLARE @v INT=(SELECT TOP 1 Id FROM dbo.v_VisibleProductVariants); INSERT @items VALUES(@v,1),(@v,1); EXEC dbo.sp_PreviewVoucher N'TEST-FIXED', @items;" 2627 $tx }
    Case 'past expiry rejected' { param($tx); ExpectError "DECLARE @expiry DATETIME2=DATEADD(DAY,-1,SYSUTCDATETIME()); EXEC dbo.sp_AdminSaveVoucher @Code=N'TEST-PAST', @DiscountType=N'PERCENTAGE', @DiscountValue=10, @ExpiresAt=@expiry;" 54003 $tx }
    Case 'percentage above 100 rejected' { param($tx); ExpectError "EXEC dbo.sp_AdminSaveVoucher @Code=N'TEST-OVER', @DiscountType=N'PERCENTAGE', @DiscountValue=101;" 54002 $tx }
    Case 'admin create/edit and unchanged expiry preserved' {
        param($tx)
        $new=(Query "EXEC dbo.sp_AdminSaveVoucher @Code=N' new-code ', @DiscountType=N'FIXED_AMOUNT', @DiscountValue=150, @MinimumSpend=500, @UsageLimit=5;" $tx).Rows[0].Id
        [void](Query "EXEC dbo.sp_AdminSaveVoucher @Id=$new, @Code=N'NEW-CODE', @DiscountType=N'PERCENTAGE', @DiscountValue=15, @MinimumSpend=500, @UsageLimit=6, @IsActive=0;" $tx)
        $value=(Query "SELECT Code, DiscountType, IsActive, UsageLimit FROM dbo.Vouchers WHERE Id=$new;" $tx).Rows[0]
        Assert ($value.Code -eq 'NEW-CODE' -and $value.DiscountType -eq 'PERCENTAGE' -and -not $value.IsActive -and $value.UsageLimit -eq 6) 'Admin save failed.'
        [void](Query "DECLARE @id INT=(SELECT Id FROM dbo.Vouchers WHERE Code=N'TEST-EXPIRED'), @expiry DATETIME2=(SELECT ExpiresAt FROM dbo.Vouchers WHERE Code=N'TEST-EXPIRED'); EXEC dbo.sp_AdminSaveVoucher @Id=@id, @Code=N'TEST-EXPIRED', @DiscountType=N'PERCENTAGE', @DiscountValue=10, @ExpiresAt=@expiry, @IsActive=0;" $tx)
    }
    Case 'invalid administration values rejected' { param($tx); ExpectError "EXEC dbo.sp_AdminSaveVoucher @Code=N'BAD%', @DiscountType=N'PERCENTAGE', @DiscountValue=10;" 54001 $tx }
    Case 'duplicate code rejected' { param($tx); ExpectError "EXEC dbo.sp_AdminSaveVoucher @Code=N'TEST-FIXED', @DiscountType=N'PERCENTAGE', @DiscountValue=10;" 54005 $tx }
    Case 'payment duplicate leaves one voucher redemption and stock deduction' {
        param($tx)
        [void](Query "DECLARE @o INT = (SELECT Id FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'); EXEC dbo.sp_ApplyOrderVoucher @o, N'TEST-PERCENT'; DECLARE @v INT=(SELECT VariantId FROM dbo.OrderItems WHERE OrderId=@o), @ok BIT, @error NVARCHAR(255); EXEC dbo.sp_ReserveStockAtomic @v, 1, N'VOUCHER-TEST-ORDER', @ok OUTPUT, @error OUTPUT; IF @ok=0 THROW 54100, N'Reservation failed', 1; EXEC dbo.sp_ConfirmHitPayOrder N'VOUCHER-TEST-ORDER', N'SIM-VOUCHER-TEST'; EXEC dbo.sp_ConfirmHitPayOrder N'VOUCHER-TEST-ORDER', N'SIM-VOUCHER-TEST';" $tx)
        Assert ((Query "SELECT COUNT(*) AS Uses FROM dbo.VoucherRedemptions;" $tx).Rows[0].Uses -eq 1) 'Payment retry added redemption.'
        Assert ((Query "SELECT COUNT(*) AS Payments FROM dbo.Payments WHERE GatewayReference=N'SIM-VOUCHER-TEST';" $tx).Rows[0].Payments -eq 1) 'Payment retry duplicated payment.'
    }
    # Exercise the actual C# repositories with committed orders in this disposable database.
    $appRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'HelmetCartelOrderingAndManagementSys'
    [void][Reflection.Assembly]::LoadFrom((Join-Path $appRoot 'bin/Newtonsoft.Json.dll'))
    [void][Reflection.Assembly]::LoadFrom((Join-Path $appRoot 'bin/HelmetCartelOrderingAndManagementSys.dll'))
    $factory = New-Object HelmetCartelOrderingAndManagementSys.Infrastructure.DbConnectionFactory $connection.ConnectionString
    $repo = New-Object HelmetCartelOrderingAndManagementSys.Repositories.OrderRepository $factory
    $users = New-Object HelmetCartelOrderingAndManagementSys.Repositories.UserRepository $factory
    $registration = $users.RegisterUserAsync('Voucher','Tester','voucher@example.invalid','test-hash','test-salt','09123456789','Customer').GetAwaiter().GetResult()
    Assert $registration.Item1 'Test customer registration failed.'
    $variant = (Query 'SELECT TOP 1 v.Id, i.CurrentStock, i.ReservedStock FROM dbo.v_VisibleProductVariants v JOIN dbo.Inventories i ON i.VariantId=v.Id WHERE i.CurrentStock-i.ReservedStock >= 4 ORDER BY v.Id;').Rows[0]
    $request = New-Object HelmetCartelOrderingAndManagementSys.Models.DTOs.CreateOrderRequestDto
    $request.CustomerName='Voucher Tester'; $request.CustomerEmail='voucher@example.invalid'; $request.CustomerPhone='09123456789'
    $request.PaymentMethod='Cash'; $request.VoucherCode='test-fixed'
    $line=New-Object HelmetCartelOrderingAndManagementSys.Models.DTOs.OrderItemRequestDto
    $line.VariantId=$variant.Id; $line.Quantity=1; $request.Items.Add($line)
    $saved=$repo.CreateOrderAsync($request,'VOUCHER-CSHARP-ORDER','ONLINE',$registration.Item2).GetAwaiter().GetResult()
    Assert ($saved.VoucherCode -eq 'TEST-FIXED' -and $saved.DiscountAmount -eq 500 -and $saved.TotalAmount -eq $saved.Subtotal - 500) 'C# order voucher calculation failed.'
    $receipt=$repo.GetOrderByIdAsync($saved.Id).GetAwaiter().GetResult()
    Assert ($receipt.TotalAmount -eq $saved.TotalAmount -and $receipt.VoucherCode -eq 'TEST-FIXED' -and $receipt.PaymentStatus -eq 'Pending') 'C# receipt differs from saved order/payment.'
    $customerReceipt=$users.GetUserOrderDetailsAsync($registration.Item2,$saved.Id,$null).GetAwaiter().GetResult()
    Assert ($customerReceipt.VoucherCode -eq 'TEST-FIXED' -and $customerReceipt.TotalAmount -eq $saved.TotalAmount) 'Customer receipt mapping failed.'
    $history=$users.GetUserOrdersAsync($registration.Item2).GetAwaiter().GetResult()
    Assert ($history[0].VoucherCode -eq 'TEST-FIXED') 'History voucher snapshot missing.'
    Write-Output 'PASS: C# online order, saved totals, pending payment, customer receipt and history mapping'
    $before=(Query 'SELECT COUNT(*) AS Uses FROM dbo.VoucherRedemptions;').Rows[0].Uses
    $line.Quantity=1000000
    try { $repo.CreateOrderAsync($request,'VOUCHER-STOCK-FAILURE','ONLINE',$registration.Item2).GetAwaiter().GetResult(); throw 'Oversized order unexpectedly succeeded.' }
    catch { Assert ($_.Exception.InnerException -is [System.InvalidOperationException]) 'Unexpected stock failure exception.' }
    Assert ((Query "SELECT COUNT(*) AS Orders FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-STOCK-FAILURE';").Rows[0].Orders -eq 0) 'Failed order did not roll back.'
    Assert ((Query 'SELECT COUNT(*) AS Uses FROM dbo.VoucherRedemptions;').Rows[0].Uses -eq $before) 'Stock failure consumed voucher.'
    $line.Quantity=1; $request.VoucherCode='UNKNOWN'
    $stockBefore=(Query "SELECT ReservedStock FROM dbo.Inventories WHERE VariantId=$($variant.Id);").Rows[0].ReservedStock
    try { $repo.CreateOrderAsync($request,'VOUCHER-INVALID-FAILURE','ONLINE',$registration.Item2).GetAwaiter().GetResult(); throw 'Unknown voucher unexpectedly succeeded.' }
    catch { Assert ($_.Exception.InnerException.Number -eq 54009) 'Unexpected voucher rejection.' }
    Assert ((Query "SELECT ReservedStock FROM dbo.Inventories WHERE VariantId=$($variant.Id);").Rows[0].ReservedStock -eq $stockBefore) 'Voucher failure did not roll back stock reservation.'
    Write-Output 'PASS: stock and invalid-voucher failures roll back order, stock reservation and redemption'
    $request.VoucherCode=$null; $request.CashTendered=100000
    $pos=$repo.CreatePhysicalSaleAsync($request,'VOUCHER-CSHARP-POS','INSTORE_POS','Completed','Completed',$null).GetAwaiter().GetResult()
    Assert ($pos.DiscountAmount -eq 0 -and $pos.TotalAmount -eq $pos.Subtotal -and $pos.CashTendered -eq 100000 -and $pos.PaymentStatus -eq 'Completed') 'POS totals/cash receipt regressed.'
    Write-Output 'PASS: POS pricing unchanged and cash tendered persisted for receipt'
    # Connection B must wait on A's voucher lock, then see A's committed use.
    $other = New-Object System.Data.SqlClient.SqlConnection $connection.ConnectionString
    $other.Open()
    $txA = $connection.BeginTransaction(); $txB = $other.BeginTransaction()
    try {
        [void](Query "DECLARE @o INT=(SELECT Id FROM dbo.Orders WHERE OrderNumber=N'VOUCHER-TEST-ORDER'); EXEC dbo.sp_ApplyOrderVoucher @o, N'TEST-PERCENT';" $txA)
        $commandB = $other.CreateCommand(); $commandB.Transaction=$txB; $commandB.CommandTimeout=10
        $commandB.CommandText="DECLARE @id INT, @d DECIMAL(18,2); EXEC dbo.sp_CalculateVoucher N'TEST-PERCENT', 1000, 1, @id OUTPUT, @d OUTPUT;"
        $taskB = $commandB.ExecuteNonQueryAsync()
        Assert (-not $taskB.Wait(250)) 'Concurrent redemption bypassed voucher lock.'
        $txA.Commit()
        try { $taskB.GetAwaiter().GetResult(); throw 'Second buyer unexpectedly received last voucher use.' }
        catch { Assert ($_.Exception.InnerException.Number -eq 54013) 'Second buyer did not receive usage-limit rejection.' }
        Write-Output 'PASS: concurrent last-use redemption serialized and second buyer rejected'
    } finally { try { $txA.Rollback() } catch {}; try { $txB.Rollback() } catch {}; $other.Dispose() }
    Write-Output 'All voucher checks passed.'
} finally {
    $connection.Dispose()
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    # The name is generated above, never supplied by the caller; fail closed on any unexpected target.
    if ($testDatabase -notmatch '^HelmetCartelVoucherTest_[a-f0-9]{32}$') { throw 'Unsafe test database cleanup target.' }
    if ($master.State -eq 'Open') {
        $master.ChangeDatabase('master')
        $command=$master.CreateCommand()
        $command.CommandText="IF DB_ID(N'$testDatabase') IS NOT NULL BEGIN ALTER DATABASE [$testDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$testDatabase]; END"
        try { [void]$command.ExecuteNonQuery(); Write-Output 'Isolated test database removed.' } finally { $command.Dispose() }
    }
    $master.Dispose()
}
