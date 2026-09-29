# Workflow: HitPay Payment Gateway Integration

This document outlines the payment transaction protocol with **HitPay**, covering payment link creation, customer redirection, asynchronous webhook processing, signature verification, and error reconciliation.

---

## 1. Overview & Credentials
- **Provider:** HitPay Payment Solutions (HitPay API v1)
- **Supported Payment Rails:** GCash, Maya, QR Ph, Credit/Debit Cards, Billease, GrabPay.
- **Environment Modes:** Sandbox (`https://api.sandbox.hit-pay.com/v1/`) and Production (`https://api.hit-pay.com/v1/`).
- **Configuration Keys:**
  - `HitPay:ApiKey` (API Key provided by merchant dashboard)
  - `HitPay:Salt` (Used to compute HMAC-SHA256 signature)
  - `HitPay:BaseUrl` (Gateway endpoint)

---

## 2. Payment Request Lifecycle

### Step 1: Create HitPay Checkout Request
When an order is created, the backend constructs an HTTP POST request to HitPay:
- **Endpoint:** `POST https://api.sandbox.hit-pay.com/v1/payment-requests`
- **Headers:**
  - `X-BUSINESS-API-KEY: {ApiKey}`
  - `Content-Type: application/x-www-form-urlencoded`
- **Payload Parameters:**
  - `amount`: Total order amount in decimal currency (e.g., `4500.00`).
  - `currency`: `PHP`.
  - `reference_number`: Unique Order Number (e.g., `HC-20260925-0012`).
  - `email`: Customer email.
  - `webhook`: `https://your-domain.com/api/v1/payments/hitpay-webhook`.
  - `redirect_url`: `https://your-domain.com/order-confirmation.html?orderId={orderId}`.

### Step 2: Webhook Processing & HMAC-SHA256 Signature Verification
When a payment changes status (completed, failed), HitPay posts payload fields to the webhook endpoint.
1. Extract all payload key-value pairs (excluding `hmac`).
2. Sort keys alphabetically.
3. Concatenate values with HitPay Salt into a signing string.
4. Calculate HMAC-SHA256 hash.
5. Perform a constant-time comparison against the received `hmac`.
6. If match fails:
   - Log warning to `database/query_logs/` and `HitPayWebhookLogs`.
   - Return HTTP `400 Bad Request`.
7. If match succeeds:
   - Check if the order is already marked as `Processing` or `Completed` (Idempotency check).
   - If already processed, return `200 OK` immediately.
   - If new, update `Payments` table, update `Orders` table, trigger stock deduction transaction, and fire SignalR notification to the staff dashboard.
