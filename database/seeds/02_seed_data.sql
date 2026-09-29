-- =====================================================================================
-- DATABASE: Helmet Cartel Ordering and Management System
-- SCRIPT: 02_seed_data.sql - High Quality Initial Seed Data
-- =====================================================================================

USE HelmetCartelDB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. SEED ROLES
SET IDENTITY_INSERT dbo.Roles ON;
INSERT INTO dbo.Roles (Id, Name, Description) VALUES
(1, N'Admin', N'Full administrative and reporting access'),
(2, N'Staff', N'Inventory operations, order fulfillment, and walk-in sales'),
(3, N'Customer', N'Online storefront registered shopper');
SET IDENTITY_INSERT dbo.Roles OFF;

-- 2. SEED USERS (Passwords hashed using PBKDF2 / SHA256 test standard)
-- Password for all local seed users is: password. Change before deployment.
SET IDENTITY_INSERT dbo.Users ON;
INSERT INTO dbo.Users (Id, RoleId, FirstName, LastName, FullName, Email, PasswordHash, Salt, PhoneNumber) VALUES
(1, 1, N'Helmet', N'Cartel Admin', N'Helmet Cartel Admin', N'admin@helmetcartel.com', N'5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'c2FsdF9zZWVkXzEyMw==', N'+639171112222'),
(2, 2, N'Store', N'Staff User', N'Store Staff User', N'staff@helmetcartel.com', N'5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'c2FsdF9zZWVkXzEyMw==', N'+639173334444'),
(3, 3, N'Juan', N'Dela Cruz', N'Juan Dela Cruz', N'juan@rider.com', N'5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'c2FsdF9zZWVkXzEyMw==', N'+639175556666');
SET IDENTITY_INSERT dbo.Users OFF;

-- 3. SEED BRANDS
SET IDENTITY_INSERT dbo.Brands ON;
INSERT INTO dbo.Brands (Id, Name, LogoUrl, Website) VALUES
(1, N'Shoei', N'/Content/images/brands/shoei.png', N'https://www.shoei-helmets.com'),
(2, N'AGV', N'/Content/images/brands/agv.png', N'https://www.agv.com'),
(7, N'HNJ', N'/Content/images/brands/hnj.png', N'https://www.hnjhelmets.com');
SET IDENTITY_INSERT dbo.Brands OFF;

-- 4. SEED CATEGORIES
SET IDENTITY_INSERT dbo.Categories ON;
INSERT INTO dbo.Categories (Id, Name, Slug, Description, DisplayOrder) VALUES
(1, N'Full Face', N'full-face', N'Maximum protection racing and street helmets with chin bar coverage.', 1),
(2, N'Modular', N'modular', N'Flip-up chin bar helmets combining full-face safety with open-face convenience.', 2),
(3, N'Open Face / Urban', N'open-face-urban', N'Retro and commuter classic helmets offering wide peripheral vision.', 3),
(4, N'Off-Road / Motocross', N'off-road-motocross', N'High-ventilation dirt and motocross helmets with extended sun visor and roost guard.', 4),
(5, N'Dual Sport / Adventure', N'dual-sport-adventure', N'Versatile hybrid helmets engineered for tarmac touring and rugged trails.', 5);
SET IDENTITY_INSERT dbo.Categories OFF;

-- 5. SEED PRODUCTS
SET IDENTITY_INSERT dbo.Products ON;
INSERT INTO dbo.Products (Id, CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice, DiscountPercentage, MainImageUrl, IsFeatured) VALUES
(1, 1, 1, N'Shoei RF-1400 Dedicated Helmet', N'shoei-rf-1400-dedicated', N'Lightweight aerodynamic flagship full-face helmet featuring AIM+ composite matrix shell and CWR-F2 Pinlock-ready shield system.', N'Sport/Track', 34500.00, 10, N'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500&auto=format&fit=crop&q=80', 1),
(2, 1, 2, N'AGV Pista GP RR Carbon Racing Helmet', N'agv-pista-gp-rr-carbon', N'100% pure carbon fiber shell identical to MotoGP riders gear with biplano aerodynamic spoiler and 190 degree panoramic visor.', N'Sport/Track', 78000.00, 15, N'https://images.unsplash.com/photo-1558980664-3a031cf67ea8?w=500&auto=format&fit=crop&q=80', 1),
(5, 2, 1, N'Shoei Neotec II Flip-Up Modular Helmet', N'shoei-neotec-2-modular', N'Advanced touring modular helmet with dual P/J homologation, integrated QSV-1 sun visor, and noise-isolating cheek pads.', N'Touring/Adventure', 42000.00, 10, N'https://images.unsplash.com/photo-1615172282427-9a57ef2d142e?w=500&auto=format&fit=crop&q=80', 0),
(7, 5, 2, N'AGV AX9 Dual Carbon Adventure Helmet', N'agv-ax9-dual-carbon', N'Multi-configuration modular peak and panoramic visor system crafted in lightweight carbon-aramid-fiberglass for world touring.', N'Touring/Adventure', 38000.00, 12, N'https://images.unsplash.com/photo-1616422285623-13ff0162193c?w=500&auto=format&fit=crop&q=80', 0);
SET IDENTITY_INSERT dbo.Products OFF;

-- 6. SEED PRODUCT VARIANTS
INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex) VALUES
(1, N'Matte Deep Black', N'#1B1B1B'),
(1, N'Pearl Glacier White', N'#F8F9FA'),
(1, N'Racing Gloss Red', N'#D90429'),
(2, N'Gloss Carbon Weave', N'#2B2D42'),
(5, N'Anthracite Metallic', N'#495057'),
(7, N'Alpine Touring White', N'#E9ECEF');

SET IDENTITY_INSERT dbo.ProductVariants ON;
INSERT INTO dbo.ProductVariants (Id, ProductColorId, SKU, Size, PriceAdjustment)
SELECT seed.Id, pc.Id, seed.SKU, seed.Size, seed.PriceAdjustment
FROM (VALUES
-- Shoei RF-1400 (Id: 1)
(1, 1, N'SHO-RF14-BLK-M', N'M', N'Matte Deep Black', N'#1B1B1B', 0.00),
(2, 1, N'SHO-RF14-BLK-L', N'L', N'Matte Deep Black', N'#1B1B1B', 0.00),
(3, 1, N'SHO-RF14-WHT-L', N'L', N'Pearl Glacier White', N'#F8F9FA', 0.00),
(4, 1, N'SHO-RF14-RED-XL', N'XL', N'Racing Gloss Red', N'#D90429', 500.00),

-- AGV Pista GP RR (Id: 2)
(5, 2, N'AGV-PIST-CRB-M', N'M', N'Gloss Carbon Weave', N'#2B2D42', 0.00),
(6, 2, N'AGV-PIST-CRB-L', N'L', N'Gloss Carbon Weave', N'#2B2D42', 0.00),

-- Shoei Neotec II (Id: 5)
(11, 5, N'SHO-NEO2-SLV-L', N'L', N'Anthracite Metallic', N'#495057', 0.00),

-- AGV AX9 (Id: 7)
(13, 7, N'AGV-AX9-WHT-L', N'L', N'Alpine Touring White', N'#E9ECEF', 0.00)
) AS seed(Id, ProductId, SKU, Size, Color, ColorHex, PriceAdjustment)
JOIN dbo.ProductColors pc ON pc.ProductId = seed.ProductId AND pc.Color = seed.Color;
SET IDENTITY_INSERT dbo.ProductVariants OFF;

-- 7. SEED INVENTORY (CurrentStock, ReorderPoint, IsLowStock computed automatically)
SET IDENTITY_INSERT dbo.Inventories ON;
INSERT INTO dbo.Inventories (Id, VariantId, CurrentStock, ReservedStock, ReorderPoint, LastRestockedAt) VALUES
(1, 1, 8, 0, 3, SYSUTCDATETIME()),
(2, 2, 2, 0, 3, SYSUTCDATETIME()), -- LOW STOCK (triggers amber alert)
(3, 3, 5, 0, 3, SYSUTCDATETIME()),
(4, 4, 1, 0, 3, SYSUTCDATETIME()), -- CRITICAL LOW STOCK
(5, 5, 4, 0, 2, SYSUTCDATETIME()),
(6, 6, 3, 0, 2, SYSUTCDATETIME()),
(11, 11, 4, 0, 3, SYSUTCDATETIME()),
(13, 13, 3, 0, 3, SYSUTCDATETIME()); -- LOW STOCK
SET IDENTITY_INSERT dbo.Inventories OFF;

-- 8. SEED INITIAL AUDIT LOGS
INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes) VALUES
(1, 1, N'RESTOCK', 0, 8, N'PO-INIT-2026-001', N'Initial stock load for Shoei RF-1400 M'),
(2, 1, N'RESTOCK', 0, 2, N'PO-INIT-2026-001', N'Initial stock load for Shoei RF-1400 L');

-- 9. SEED FAQS (Global & Product-Specific)
INSERT INTO dbo.Faqs (ProductId, Question, Answer, DisplayOrder, IsActive) VALUES
(NULL, N'How does Cash on In-Store Pickup work?', N'Select Cash as your payment method during checkout. Your item is immediately deducted from inventory and held for you. Simply present your Order Reference Number (e.g. HC-2026-XXXX) at our store cashier to pay in cash and collect your gear.', 1, 1),
(NULL, N'How do I measure my head for an accurate helmet fit?', N'Wrap a flexible measuring tape around the widest part of your head—approximately 1 inch (2.5 cm) above your eyebrows and just above your ears. Compare your measurement in centimeters against the sizing chart on each product page.', 2, 1),
(NULL, N'What is your return or size exchange policy?', N'We offer a 3-day size exchange guarantee for in-store pickups provided the helmet is completely unused, unmounted, and returned with its original box, tags, and protective shield film intact.', 3, 1),
(NULL, N'Are all helmets sold genuine and certified?', N'Yes, 100% of our inventory consists of authentic products sourced directly from licensed brand distributors, certified under official DOT, ECE 22.06, or SNELL safety standards.', 4, 1),
(1, N'Does the Shoei RF-1400 include a Pinlock anti-fog lens in the box?', N'Yes, every authentic Shoei RF-1400 includes a clear Pinlock EVO fog-resistant insert, silicone pins, breath guard, and chin curtain in the factory packaging.', 1, 1),
(2, N'Is the biplano aerodynamic spoiler on the AGV Pista replaceable?', N'Yes, the biplano rear spoiler is engineered to detach in a crash to minimize rotational forces and can be individually replaced if damaged.', 1, 1);

-- 10. SEED PRODUCT REVIEWS (Instant Published Reviews)
INSERT INTO dbo.ProductReviews (ProductId, UserId, OrderId, ReviewerName, Rating, Title, Comment, IsVerifiedPurchase, IsHidden) VALUES
(1, NULL, NULL, N'Mark Anthony R.', 5, N'Substantial wind noise reduction!', N'Upgraded from an older helmet. The RF-1400 is visibly quieter at highway cruising speeds and the central shield latch is rock solid.', 0, 0),
(1, NULL, NULL, N'Paolo S.', 5, N'Flawless finish and lightweight balance', N'Handcrafted Japanese fiberglass shell. Snug cheek pads and supreme airflow through the front brow vents. Worth every peso.', 0, 0),
(1, NULL, NULL, N'Samantha D.', 5, N'Aerodynamics are whisper quiet on highways', N'I absolutely love this helmet! Upgraded from an older lid. The aerodynamics are quiet, and the interior padding feels so plush. Excellent Japanese craftsmanship.', 0, 0),
(1, NULL, NULL, N'Alex M.', 4, N'Top-notch ventilation and optics, snug initial fit', N'Being an everyday commuter, I am picky about ventilation. Airflow through the chin and brow vents is fantastic. Takes roughly two weeks to break in the cheek pads.', 0, 0),
(1, NULL, NULL, N'Ethan R.', 4, N'Quality engineering with rock-solid visor seal', N'The visor mechanism clicks into place with authority and the Pinlock EVO insert completely eliminates fogging in morning downpours. Very satisfied with the build.', 0, 0),
(1, NULL, NULL, N'Olivia P.', 3, N'Great safety pedigree but slightly snug for rounder heads', N'Japanese shell finish is second to none and Snell M2020D cert gives total confidence. However, if you have an intermediate-to-round head shape, you may need thinner cheek pads.', 0, 0),
(1, NULL, NULL, N'Liam K.', 5, N'Emergency release system gives track coaches confidence', N'This helmet is a fusion of comfort and aerodynamic stability. The emergency quick release system (E.Q.R.S.) gave my instructors total peace of mind on race day.', 0, 0),
(2, NULL, NULL, N'Kenji T.', 5, N'Absolute track weapon', N'100% pure carbon fiber shell identical to MotoGP gear. Visor panoramic field of view is unmatched when tucked into the tank.', 0, 0);
GO
