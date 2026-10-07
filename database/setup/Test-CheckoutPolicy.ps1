[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$appRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'HelmetCartelOrderingAndManagementSys'
[void][Reflection.Assembly]::LoadFrom((Join-Path $appRoot 'bin/Newtonsoft.Json.dll'))
[void][Reflection.Assembly]::LoadFrom((Join-Path $appRoot 'bin/HelmetCartelOrderingAndManagementSys.dll'))
function Request([string]$method='Delivery',[string]$payment='CashOnDelivery',[string]$province='Metro Manila',[string]$city='Quezon City') {
    $order=New-Object HelmetCartelOrderingAndManagementSys.Models.DTOs.CreateOrderRequestDto
    $order.CustomerName='Presentation customer'; $order.CustomerEmail='customer@example.invalid'; $order.CustomerPhone='09990000001'
    $order.ShippingMethod=$method; $order.PaymentMethod=$payment; $order.ShippingAddress='Test street'; $order.ShippingCity=$city; $order.ShippingProvince=$province
    $order.ShippingFee=-999; $order.ShippingRegion='Client override'
    return $order
}
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
foreach ($shippingCase in @(
    @{Method='Pickup'; Payment='Cash'; Province=''; City=''; Fee=0},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province='Metro Manila'; City='Quezon City'; Fee=150},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province='Laguna'; City='San Pedro'; Fee=250},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province='Benguet'; City='Baguio'; Fee=350},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province='Cebu'; City='Cebu City'; Fee=450},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province='Misamis Oriental'; City='Cagayan de Oro'; Fee=500},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province='Batangas'; City='San Juan'; Fee=250}
)) {
    $order=Request $shippingCase.Method $shippingCase.Payment $shippingCase.Province $shippingCase.City
    [HelmetCartelOrderingAndManagementSys.Services.CheckoutPolicy]::ValidateAndPrice($order)
    Assert ($order.ShippingFee -eq $shippingCase.Fee -and $order.ShippingRegion -ne 'Client override') 'Server pricing accepted a client override or wrong region.'
    Write-Output "PASS: server shipping $($shippingCase.Method) $($shippingCase.Province) = $($shippingCase.Fee)"
}
foreach ($invalid in @(
    @{Method='Delivery'; Payment='Cash'; Province='Cebu'},
    @{Method='Pickup'; Payment='CashOnDelivery'; Province='Cebu'},
    @{Method='Delivery'; Payment='Card_POS'; Province='Cebu'},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province=''},
    @{Method='Delivery'; Payment='CashOnDelivery'; Province='Unknown province'}
)) {
    $order=Request $invalid.Method $invalid.Payment $invalid.Province
    $rejected=$false
    try { [HelmetCartelOrderingAndManagementSys.Services.CheckoutPolicy]::ValidateAndPrice($order) }
    catch { $rejected=$true }
    Assert $rejected 'Invalid checkout combination was accepted.'
    Write-Output "PASS: rejects $($invalid.Method) / $($invalid.Payment) / $($invalid.Province)"
}
Write-Output 'All checkout policy checks passed.'
