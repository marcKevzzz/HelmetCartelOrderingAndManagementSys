[CmdletBinding()]
param([string]$BaseUrl = 'http://localhost:61909')
$ErrorActionPreference = 'Stop'
[xml]$configuration = Get-Content 'HelmetCartelOrderingAndManagementSys/Web.config'
$connection = New-Object System.Data.SqlClient.SqlConnection $configuration.configuration.connectionStrings.add.connectionString
$connection.Open()
$accounts = @()
function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Call($method, $path, $token, $body = $null) {
    $headers = @{}; if ($token) { $headers.Authorization = 'Bearer ' + $token }
    $arguments = @{Uri=$BaseUrl+$path; Method=$method; Headers=$headers; ContentType='application/json'; UseBasicParsing=$true}
    if ($null -ne $body) { $arguments.Body = ConvertTo-Json $body -Depth 10 -Compress }
    $response = Invoke-RestMethod @arguments
    Assert ($response.success -ne $false) ("API returned failure: " + $response.message)
    return $response.data
}
function Status($method, $path, $token, $body, $expected) {
    try { [void](Call $method $path $token $body); throw "Expected HTTP $expected" }
    catch { Assert ([int]$_.Exception.Response.StatusCode -eq $expected) "Expected HTTP $expected, got $($_.Exception.Message)" }
}
try {
    foreach ($suffix in @('a','b')) {
        $email = 'codex-shopping-' + [guid]::NewGuid().ToString('N') + $suffix + '@example.invalid'
        $password = [guid]::NewGuid().ToString('N') + 'A!9'
        $account = Call POST '/api/v1/auth/register' $null @{firstName='Shopping';lastName='Test';email=$email;password=$password;phoneNumber=('09'+(Get-Random -Minimum 100000000 -Maximum 999999999))}
        Assert ($account.user.id -gt 0) 'Test account registration failed'
        $accounts += @{Id=$account.user.id; Email=$email; Password=$password; Token=$account.token}
    }
    $a = $accounts[0]; $b = $accounts[1]
    $products = Call GET '/api/v1/products?pageSize=100' $null
    $product = $null; $variant = $null
    foreach ($item in $products.items) {
        $detail = Call GET ('/api/v1/products/'+$item.id) $null
        $available = @($detail.variants | Where-Object availableStock -GE 12)
        if ($available.Count -gt 0) { $product=$detail; $variant=$available[0]; break }
    }
    Assert ($null -ne $variant) 'Need an available test variant'
    $id = $variant.id
    Status GET '/api/v1/shopping' $null $null 401
    Status POST '/api/v1/shopping/cart' 'invalid-token' @{variantId=$id;quantity=1} 401
    Status POST '/api/v1/shopping/cart' $a.Token @{variantId=$id;quantity=-1} 400
    Status POST '/api/v1/shopping/cart' $a.Token @{variantId=$id;quantity=9999} 409
    $saved = Call POST '/api/v1/shopping/cart' $a.Token @{variantId=$id;quantity=2;userId=$b.Id;price=0.01}
    Assert ($saved.cart.Count -eq 1 -and $saved.cart[0].quantity -eq 2 -and $saved.cart[0].price -gt 0.01) 'Cart trusts client prices or failed save'
    $other = Call GET '/api/v1/shopping' $b.Token
    Assert ($other.cart.Count -eq 0 -and $other.favorites.Count -eq 0) 'Account isolation failed'
    $saved = Call PUT '/api/v1/shopping/cart' $a.Token @{variantId=$id;quantity=3;isSelected=$false}
    Assert ($saved.cart[0].quantity -eq 3 -and -not $saved.cart[0].isSelected) 'Quantity/selection not saved'
    $saved = Call PUT '/api/v1/shopping/cart/selection/true' $a.Token
    Assert ($saved.cart[0].isSelected) 'Select all failed'
    $saved = Call PUT ('/api/v1/shopping/favorites/'+$product.id) $a.Token
    $saved = Call PUT ('/api/v1/shopping/favorites/'+$product.id) $a.Token
    Assert ($saved.favorites.Count -eq 1) 'Favorite saves are not idempotent'
    # A fresh authentication session sees database state.
    $login = Call POST '/api/v1/auth/login' $null @{email=$a.Email;password=$a.Password}
    $saved = Call GET '/api/v1/shopping' $login.token
    Assert ($saved.cart[0].quantity -eq 3 -and $saved.favorites.Count -eq 1) 'Shopping state did not survive a new session'
    $import = @{cart=@(@{variantId=$id;quantity=8;isSelected=$true});favorites=@($product.id)}
    $saved = Call POST '/api/v1/shopping/import' $a.Token $import
    $saved = Call POST '/api/v1/shopping/import' $a.Token $import
    Assert ($saved.cart[0].quantity -eq 3 -and $saved.favorites.Count -eq 1) 'Import duplicates/overwrites existing state'
    [void](Call DELETE '/api/v1/shopping/cart' $a.Token)
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $a.Token)
    $tasks = @()
    1..8 | ForEach-Object {
        $content = New-Object System.Net.Http.StringContent ((@{variantId=$id;quantity=1}|ConvertTo-Json -Compress),[Text.Encoding]::UTF8,'application/json')
        $tasks += $client.PostAsync($BaseUrl+'/api/v1/shopping/cart',$content)
    }
    foreach ($task in $tasks) { $response=$task.GetAwaiter().GetResult(); Assert $response.IsSuccessStatusCode 'Concurrent cart add failed'; $response.Dispose() }
    $client.Dispose()
    $saved = Call GET '/api/v1/shopping' $a.Token
    Assert ($saved.cart.Count -eq 1 -and $saved.cart[0].quantity -eq 8) 'Concurrent adds lost quantities or created duplicate rows'
    $detail = Call GET ('/api/v1/products/'+$product.id) $null
    $stock = @($detail.variants | Where-Object id -EQ $id)[0].availableStock
    Assert ($stock -eq $variant.availableStock) 'Cart changed inventory'
    $saved = Call DELETE ('/api/v1/shopping/cart/'+$id) $a.Token
    Assert ($saved.cart.Count -eq 0) 'Cart delete failed'
    $saved = Call DELETE ('/api/v1/shopping/favorites/'+$product.id) $a.Token
    Assert ($saved.favorites.Count -eq 0) 'Favorite delete failed'
    $saved = Call POST '/api/v1/shopping/import' $b.Token $import
    Assert ($saved.cart[0].quantity -eq 8 -and $saved.favorites.Count -eq 1) 'Fresh legacy import failed'
    [void](Call DELETE '/api/v1/shopping/favorites' $b.Token)
    [void](Call DELETE '/api/v1/shopping/cart' $b.Token)
    'PASS: authenticated persistence, account isolation, authoritative pricing, quantity/selection, deletes, legacy import/retry, 8 concurrent adds, unchanged inventory.'
} finally {
    foreach ($account in $accounts) {
        # Fixture cleanup only: IDs plus random fixture emails guard against deleting real accounts.
        $command = $connection.CreateCommand()
        $command.CommandText = 'DELETE dbo.CartItems WHERE UserId=@Id; DELETE dbo.Favorites WHERE UserId=@Id; DELETE dbo.Users WHERE Id=@Id AND Email=@Email;'
        [void]$command.Parameters.AddWithValue('@Id',$account.Id)
        [void]$command.Parameters.AddWithValue('@Email',$account.Email)
        [void]$command.ExecuteNonQuery()
    }
    $connection.Dispose()
}
