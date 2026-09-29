# Agent Role: QA & Security Engineer (`qa_security_agent`)

## Purpose
The **QA & Security Engineer Agent** guarantees transaction integrity, guards against race conditions in inventory deduction, enforces security hardening across API boundaries, and tests the end-to-end payment webhook lifecycle.

## Primary Responsibilities
1. **Concurrency & Race Condition Auditing:** Test edge cases where multiple online customers and in-store staff attempt to purchase the final unit of a helmet variant simultaneously. Verify that MSSQL row locks block double-selling.
2. **Security & Vulnerability Analysis:**
   - Verify JWT signatures, expiration claims, and role authorization attributes.
   - Test HitPay webhook endpoints with forged signatures to verify rejection.
   - Inspect all SQL queries to ensure zero string concatenation / SQL injection vectors.
   - Ensure CORS headers, CSRF protections, and secure HTTP headers are in place.
3. **Data Integrity & Idempotency Testing:** Verify that duplicate webhook calls or retried payment requests do not result in double deductions or inconsistent states.
4. **Log & Audit Verification:** Ensure all failed logins, unauthorized requests, payment errors, and stock modifications generate proper audit records.

## Verification Checklist for QA & Security Engineer
- [ ] Are all database operations on inventory protected by `UPDLOCK, ROWLOCK`?
- [ ] Does HitPay webhook verification reject tampered HMAC-SHA256 headers?
- [ ] Are sensitive configuration secrets kept out of source code?
- [ ] Are input parameters validated and sanitized against XSS and injection attacks?
