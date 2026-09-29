# REST API Specification: Helmet Cartel System

**Base URL:** `/api/v1`  
**Standard Headers:**  
- `Content-Type: application/json`
- `Authorization: Bearer <JWT_TOKEN>` (for protected endpoints)

---

## 1. Authentication Endpoints (`/api/v1/auth`)

### 1.1. Login
- **Endpoint:** `POST /api/v1/auth/login`
- **Access:** Public
- **Request Body:**
  ```json
  {
    "email": "staff@helmetcartel.com",
    "password": "SecurePassword123!"
  }
  ```
- **Response `200 OK`:**
  ```json
  {
    "success": true,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600,
    "user": {
      "id": 1,
      "fullName": "Staff Member",
      "email": "staff@helmetcartel.com",
      "role": "Staff"
    }
  }
  ```

### 1.2. Register (Customer)
- **Endpoint:** `POST /api/v1/auth/register`
- **Access:** Public
- **Request Body:**
  ```json
  {
    "fullName": "Juan Dela Cruz",
    "email": "juan@example.com",
    "password": "Password123!",
    "phoneNumber": "+639171234567"
  }
  ```

---

## 2. Product Catalog Endpoints (`/api/v1/products`)

### 2.1. List Products
- **Endpoint:** `GET /api/v1/products`
- **Access:** Public
- **Query Parameters:**
  - `page` (default: 1), `pageSize` (default: 12)
  - `categoryId` (int, optional)
  - `brandId` (int, optional)
  - `search` (string, optional)
  - `ridingStyle` (string: "Casual", "Formal", "Party", "Gym" or "Full Face", "Modular", "Urban", "Adventure")
  - `minPrice`, `maxPrice` (decimal, optional)
  - `sortBy` ("price_asc", "price_desc", "rating", "newest")
- **Response `200 OK`:**
  ```json
  {
    "totalCount": 48,
    "page": 1,
    "pageSize": 12,
    "items": [
      {
        "id": 1,
        "name": "Shoei RF-1400 Dedicated Full Face Helmet",
        "brand": "Shoei",
        "category": "Full Face",
        "basePrice": 32500.00,
        "discountPrice": 29250.00,
        "discountPercentage": 10,
        "rating": 4.8,
        "reviewCount": 142,
        "imageUrl": "/Content/images/helmets/shoei-rf1400.jpg",
        "variants": [
          { "id": 101, "size": "M", "color": "Matte Black", "colorHex": "#1F1F1F", "stock": 5 },
          { "id": 102, "size": "L", "color": "Matte Black", "colorHex": "#1F1F1F", "stock": 2 }
        ]
      }
    ]
  }
  ```

### 2.2. Get Product Details by ID
- **Endpoint:** `GET /api/v1/products/{id}`
- **Access:** Public

---

## 3. Inventory Management Endpoints (`/api/v1/inventory`)

### 3.1. Get Live Stock Status
- **Endpoint:** `GET /api/v1/inventory`
- **Access:** Staff, Admin
- **Query Parameters:** `lowStockOnly=true|false`, `search=string`
- **Response `200 OK`:** Returns variant stock levels, reorder points, and low-stock alerts.

### 3.2. Restock Inventory
- **Endpoint:** `POST /api/v1/inventory/restock`
- **Access:** Staff, Admin
- **Request Body:**
  ```json
  {
    "variantId": 102,
    "quantityAdded": 10,
    "supplierInvoice": "INV-SHOEI-2026-88",
    "unitCost": 22000.00,
    "notes": "Monthly batch restock"
  }
  ```

---

## 4. Order Management Endpoints (`/api/v1/orders`)

### 4.1. Place Online Order
- **Endpoint:** `POST /api/v1/orders`
- **Access:** Customer, Guest
- **Request Body:**
  ```json
  {
    "customerName": "Juan Dela Cruz",
    "customerEmail": "juan@example.com",
    "customerPhone": "+639171234567",
    "paymentMethod": "HitPay",
    "items": [
      { "variantId": 101, "quantity": 1 }
    ]
  }
  ```
- **Response `201 Created`:** Returns `orderId`, `orderNumber`, and `checkoutUrl` for HitPay redirection.

### 4.2. In-Store POS Walk-in Sale
- **Endpoint:** `POST /api/v1/orders/in-store`
- **Access:** Staff, Admin
- **Request Body:**
  ```json
  {
    "paymentMethod": "Cash",
    "notes": "Walk-in retail customer",
    "items": [
      { "variantId": 101, "quantity": 1 }
    ]
  }
  ```
- **Response `200 OK`:** Stock decremented immediately, returns completed order receipt.

### 4.3. Update Order Status
- **Endpoint:** `PUT /api/v1/orders/{orderId}/status`
- **Access:** Staff, Admin
- **Request Body:**
  ```json
  {
    "status": "ReadyForPickup"
  }
  ```

---

## 5. Payments & HitPay Webhook (`/api/v1/payments`)

### 5.1. HitPay Webhook Handler
- **Endpoint:** `POST /api/v1/payments/hitpay-webhook`
- **Access:** Public (Verified via HMAC-SHA256 signature)
- **Response:** `200 OK` (when valid) or `400 Bad Request` (when signature invalid or payload corrupted).

---

## 6. Reports Endpoints (`/api/v1/reports`)

### 6.1. Sales & Revenue Summary
- **Endpoint:** `GET /api/v1/reports/sales-summary?startDate=2026-09-01&endDate=2026-09-30`
- **Access:** Admin

### 6.2. Low-Stock & Inventory Valuation
- **Endpoint:** `GET /api/v1/reports/inventory-valuation`
- **Access:** Admin, Staff
