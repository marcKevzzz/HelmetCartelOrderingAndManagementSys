# Transactional regression checks; fixture deactivations are always rolled back.
$ErrorActionPreference = 'Stop'
$connection = New-Object System.Data.SqlClient.SqlConnection 'Server=.\SQLEXPRESS;Database=HelmetCartelDB;Integrated Security=True;TrustServerCertificate=True'
$connection.Open()
$transaction = $connection.BeginTransaction()
function Read-VisibilityData($text, $parameters = @{}, $storedProcedure = $false) {
    $command = $connection.CreateCommand()
    $command.Transaction = $transaction
    $command.CommandText = $text
    if ($storedProcedure) { $command.CommandType = [System.Data.CommandType]::StoredProcedure }
    foreach ($key in $parameters.Keys) { [void]$command.Parameters.AddWithValue($key, $parameters[$key]) }
    $data = New-Object System.Data.DataSet
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    [void]$adapter.Fill($data)
    return ,$data
}
try {
    $fixture = Read-VisibilityData 'SELECT TOP 1 p.Id ProductId, v.Id VariantId FROM dbo.Products p JOIN dbo.ProductColors c ON c.ProductId=p.Id JOIN dbo.ProductVariants v ON v.ProductColorId=c.Id WHERE p.IsActive=1 AND v.IsActive=1 ORDER BY p.Id,v.Id'
    $productId = [int]$fixture.Tables[0].Rows[0].ProductId
    $variantId = [int]$fixture.Tables[0].Rows[0].VariantId
    [void](Read-VisibilityData 'UPDATE dbo.Products SET IsActive=0 WHERE Id=@Id' @{ '@Id'=$productId })
    $draft = Read-VisibilityData 'dbo.sp_GetProductById' @{ '@Id'=$productId } $true
    if ($draft.Tables[0].Rows.Count -ne 0) { throw 'Draft product detail leaked.' }
    $expected = Read-VisibilityData 'SELECT ISNULL(SUM(i.CurrentStock),0) Total FROM dbo.Inventories i JOIN dbo.ProductVariants v ON v.Id=i.VariantId JOIN dbo.ProductColors c ON c.Id=v.ProductColorId JOIN dbo.Products p ON p.Id=c.ProductId WHERE p.IsActive=1 AND v.IsActive=1'
    $dashboard = Read-VisibilityData 'dbo.sp_AdminDashboard' @{} $true
    if ($dashboard.Tables[0].Rows[0].OnHandStock -ne $expected.Tables[0].Rows[0].Total) { throw 'Dashboard stock total includes hidden items.' }
    foreach ($name in @('sp_AdminCatalogProducts','sp_AdminInventoryProducts','sp_AdminInventoryVariants','sp_AdminSellableVariants','sp_AdminBrandInventoryDetails','sp_GetInventoryList')) {
        $result = Read-VisibilityData ('dbo.'+$name) @{} $true
        foreach ($row in $result.Tables[0].Rows) {
            if ($result.Tables[0].Columns.Contains('IsActive') -and -not $row.IsActive) { throw "$name returned a draft." }
            if ($result.Tables[0].Columns.Contains('ProductId') -and $row.ProductId -eq $productId) { throw "$name returned the draft fixture." }
            if ($result.Tables[0].Columns.Contains('VariantId')) {
                $eligible = Read-VisibilityData 'SELECT COUNT(*) Total FROM dbo.v_VisibleProductVariants WHERE Id=@Id' @{ '@Id'=[int]$row.VariantId }
                if ($eligible.Tables[0].Rows[0].Total -ne 1) { throw "$name returned an inactive variant." }
            }
        }
        Write-Output "$name passed ($($result.Tables[0].Rows.Count) rows)."
    }
    [void](Read-VisibilityData 'UPDATE dbo.Products SET IsActive=1 WHERE Id=@Id; UPDATE dbo.ProductVariants SET IsActive=0 WHERE Id=@VariantId' @{ '@Id'=$productId; '@VariantId'=$variantId })
    $detail = Read-VisibilityData 'dbo.sp_GetProductById' @{ '@Id'=$productId } $true
    foreach ($row in $detail.Tables[1].Rows) { if ($row.Id -eq $variantId) { throw 'Inactive detail variant leaked.' } }
    $history = Read-VisibilityData 'dbo.sp_AdminStockHistory' @{ '@VariantId'=$variantId } $true
    if ($history.Tables[0].Rows.Count -ne 0) { throw 'Inactive stock history leaked.' }
    $search = Read-VisibilityData 'dbo.sp_AdminGlobalSearch' @{ '@Query'='%'; '@Limit'=1000 } $true
    $inactiveSku = (Read-VisibilityData 'SELECT SKU FROM dbo.ProductVariants WHERE Id=@Id' @{ '@Id'=$variantId }).Tables[0].Rows[0].SKU
    foreach ($row in $search.Tables[0].Rows) {
        if ($row.Category -in @('Inventory','Point of Sale') -and $row.Subtitle.Contains('SKU: '+$inactiveSku)) { throw 'Inactive global search result leaked.' }
    }
    $trend = Read-VisibilityData 'dbo.sp_AdminInventoryTrend' @{ '@StartDate'=[datetime]::UtcNow.Date; '@EndDate'=[datetime]::UtcNow.Date } $true
    Write-Output 'Draft detail, inactive detail/history/search, dashboard totals, and analytics execution passed.'
} finally {
    $transaction.Rollback()
    $connection.Close()
}
