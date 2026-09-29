# Rule 05: Security, Authentication & Payment Gateway Standards

## 1. Authentication & Authorization
- **Token Format:** Signed JSON Web Tokens (JWT) using HMAC-SHA256 (`HS256`).
- **OWIN Middleware:** Use `OAuthAuthorizationServer` / custom JWT Bearer token authentication in `Startup.cs`.
- **Claims Architecture:**
  - `sub`: User unique identifier (User Id).
  - `email`: User email address.
  - `role`: Role claim (`Admin`, `Staff`, `Customer`).
  - `jti`: Unique token identifier for token invalidation.
- **Role Enforcement:** Protect endpoints with `[Authorize(Roles = AppConstants.Roles.Admin)]` or composite permissions. Never trust client-supplied role parameters.

## 2. HitPay Payment Gateway Integration
- **Direct Redirection:** Generate secure HitPay checkout sessions from the backend with server-side validation of order items and pricing.
- **Webhook Signature Verification (HMAC-SHA256):**
  - HitPay webhooks send an `X-Hitpay-Signature` header (or HMAC parameter).
  - The backend MUST compute the HMAC-SHA256 hash using the configured `HitPaySalt` and verify equality using a constant-time comparison before processing payment status updates.
  - Reject any webhook request failing signature verification with `400 Bad Request` or `401 Unauthorized` and log to `HitPayWebhookLogs`.
- **Idempotency:** Webhook handlers must be idempotent; multiple notifications for the same payment reference must not double-process orders or deduct stock twice.

## 3. Data Protection & Secrets Management
- Sensitive values (`JwtSecret`, `HitPayApiKey`, `HitPaySalt`, `SqlConnectionString`) must be stored in `Web.config` appSettings or environment variables and NEVER committed in cleartext to public repositories.
- Passwords must be hashed using a secure adaptive hashing algorithm (PBKDF2 with SHA-256 and unique cryptographic salt per user, minimum 10,000 iterations, or BCrypt).
