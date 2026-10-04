-- =====================================================================================
-- MIGRATION 47: REALISTIC PRODUCT DETAILS, COMPREHENSIVE SPECIFICATIONS & REVIEWS
-- Author: Helmet Cartel Engineering Team
-- Date: 2026-10-04
-- Purpose:
--   1. Clean up placeholder/test draft products (Ids 49, 51).
--   2. Update all catalog products with authentic, professional names & rich descriptions.
--   3. Insert full technical specifications across all products (Shell, Safety, Visor, Retention, Ventilation, Liner, Weight, Comm).
--   4. Replace sample/placeholder reviews with realistic customer reviews and authentic feedback.
-- =====================================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

BEGIN TRANSACTION;

-- 1. CLEAN UP UNPUBLISHED TEST DRAFTS (Ids 49, 51)
DELETE FROM dbo.ProductReviews WHERE ProductId IN (49, 51);
DELETE FROM dbo.ProductSpecificationValues WHERE ProductId IN (49, 51);
DELETE FROM dbo.Inventories WHERE VariantId IN (
    SELECT pv.Id FROM dbo.ProductVariants pv 
    JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id 
    WHERE pc.ProductId IN (49, 51)
);
DELETE FROM dbo.ProductVariants WHERE ProductColorId IN (
    SELECT Id FROM dbo.ProductColors WHERE ProductId IN (49, 51)
);
DELETE FROM dbo.ProductColors WHERE ProductId IN (49, 51);
DELETE FROM dbo.ProductGalleryImages WHERE ProductId IN (49, 51);
DELETE FROM dbo.Products WHERE Id IN (49, 51);

-- 2. UPDATE PRODUCT NAMES & DETAILED DESCRIPTIONS
UPDATE dbo.Products SET
    Name = N'Shoei RF-1400 Dedicated Helmet',
    Description = N'Lightweight aerodynamic flagship full-face helmet featuring Shoei''s proprietary AIM+ composite matrix shell, dual-ridge chin bar, and high-performance CWR-F2 Pinlock-ready shield system with center-locking tab.'
WHERE Id = 1;

UPDATE dbo.Products SET
    Name = N'AGV Pista GP RR Carbon Racing Helmet',
    Description = N'100% pure carbon fiber shell developed directly for MotoGP world championship racers. Features an integrated hydration channel, biplano wind-tunnel spoiler, and optical Class 1 panoramic visor with 190° horizontal field of view.'
WHERE Id = 2;

UPDATE dbo.Products SET
    Name = N'Shoei Neotec II Flip-Up Modular Helmet',
    Description = N'Advanced touring modular helmet featuring dual P/J homologation for open and closed riding, integrated QSV-1 drop-down sun visor, stainless steel 360° pivot locking mechanism, and noise-isolating cheek pads.'
WHERE Id = 5;

UPDATE dbo.Products SET
    Name = N'AGV AX9 Dual Carbon Adventure Helmet',
    Description = N'Multi-configuration adventure touring helmet crafted with a lightweight carbon-aramid-fiberglass shell, aerodynamic peak with air scoops, and panoramic anti-scratch shield designed for cross-country exploration.'
WHERE Id = 7;

UPDATE dbo.Products SET
    Name = N'Gille 135 GTS V1 Touring Full-Face Helmet',
    Description = N'Versatile aerodynamic full-face street helmet engineered with an impact-resistant ABS composite shell, multi-vent intake cooling, quick-release anti-scratch shield, and removable moisture-wicking liner.'
WHERE Id = 9;

UPDATE dbo.Products SET
    Name = N'Shoei Hornet ADV Explorer Adventure Helmet',
    Description = N'Premium dual-sport adventure helmet engineered with AIM+ matrix shell, V-460 aerodynamic sun peak with pressure-relieving air vents, and CNS-2 Pinlock-ready distortion-free shield.'
WHERE Id = 10;

UPDATE dbo.Products SET
    Name = N'Shoei X-Fifteen Aero Marquez Race Helmet',
    Description = N'FIM racing homologated flagship road-race helmet developed in MotoGP wind tunnels. Features fully customizable interior angle, aerodynamic stabilizer flaps, and CWR-F2R tear-off ready shield.'
WHERE Id = 11;

UPDATE dbo.Products SET
    Name = N'HNJ 937 Flip-Up Modular Helmet',
    Description = N'Practical urban and touring modular helmet featuring a one-touch metal chin bar release mechanism, dual visor system (clear outer + smoke inner), and high-impact thermoplastic shell.'
WHERE Id = 12;

UPDATE dbo.Products SET
    Name = N'Gille 883 Falcon Red Graphic Full-Face Helmet',
    Description = N'Sporty full-face helmet with race-inspired falcon graphics, high-flow aerodynamic rear spoiler, anti-scratch UV-protected visor, and quick-release micrometric buckle.'
WHERE Id = 13;

UPDATE dbo.Products SET
    Name = N'Gille A5009 Phoenix Metallic Full-Face Helmet',
    Description = N'High-impact aerodynamic street helmet equipped with an iridescent rainbow visor, dual exhaust extractors, and removable antibacterial lining.'
WHERE Id = 14;

UPDATE dbo.Products SET
    Name = N'Gille FF005 Visage Urban Open-Face Helmet',
    Description = N'Chic and lightweight open-face helmet designed for scooter and city riders, featuring an oversized scratch-resistant shield and quick-release buckle.'
WHERE Id = 15;

UPDATE dbo.Products SET
    Name = N'Gille FF007 Kerena Sport Full-Face Helmet',
    Description = N'Sleek full-face helmet with wide-angle smoked visor, reinforced chin bar, and multi-channel ventilation for long rides.'
WHERE Id = 16;

UPDATE dbo.Products SET
    Name = N'AGV K6 S Minimalist Matte Black Helmet',
    Description = N'Versatile ultra-lightweight full-face helmet engineered with a carbon-aramid fiber shell weighing just 1,255g. Certified to strict ECE 22.06 standards with 5 front intake vents and optical Class 1 visor.'
WHERE Id = 17;

UPDATE dbo.Products SET
    Name = N'AGV K3 SV Monster Energy Graphic Helmet',
    Description = N'Dynamic aggressive full-face helmet featuring high-resistance thermoplastic shell, internal drop-down sun visor, Pinlock anti-fog lens included, and race-inspired Monster Energy graphics.'
WHERE Id = 18;

UPDATE dbo.Products SET
    Name = N'AGV K1 S Fluo Neon Graphic Full-Face Helmet',
    Description = N'High-visibility track-inspired full-face helmet with bright neon artwork, high-flow chin and brow intakes, double-D ring closure, and ECE 22.06 safety rating.'
WHERE Id = 19;

UPDATE dbo.Products SET
    Name = N'AGV Corsa R Tricolore Graphic Racing Helmet',
    Description = N'Track-focused supersport helmet crafted with carbon-aramid-fiberglass shell, reversible warm/cool interior crown pad, patented visor lock system (VLS), and wind-tunnel engineered biplano spoiler.'
WHERE Id = 20;

UPDATE dbo.Products SET
    Name = N'Zebra FF-855 Trackline Full-Face Helmet',
    Description = N'High-durability everyday full-face helmet with anti-fog prepared shield, aerodynamic shell geometry, multi-port ventilation, and ICC / BPS certification.'
WHERE Id = 21;

UPDATE dbo.Products SET
    Name = N'Zebra Hornet Dual Visor Modular Helmet',
    Description = N'Convenient flip-up modular helmet with outer clear visor and inner sun glasses, ergonomic chin bar lock, and breathable mesh lining.'
WHERE Id = 22;

UPDATE dbo.Products SET
    Name = N'Shoei Neotec 3 Modular Touring Helmet',
    Description = N'Next-generation premium flip-up modular helmet with seamless Sena SRL3 intercom integration, 2-stage P/J locking, and ultra-quiet 3D noise isolator cheek pads.'
WHERE Id = 23;

UPDATE dbo.Products SET
    Name = N'Zebra 603 Urban Cruiser Open-Face Helmet',
    Description = N'Clean open-face half helmet with snap-on peak visor, quick-release ratchet strap, and lightweight ABS construction for everyday errands.'
WHERE Id = 24;

UPDATE dbo.Products SET
    Name = N'HNJ A4-001 Everyday Urban Half-Face Helmet',
    Description = N'Affordable and durable urban open-face helmet with deep wrap-around clear visor, top intake vents, and soft foam interior.'
WHERE Id = 25;

UPDATE dbo.Products SET
    Name = N'HNJ A4-008 Classic Open-Face Helmet',
    Description = N'Lightweight scooter helmet with distortion-free visor, convenient quick-release strap, and BPS safety certification.'
WHERE Id = 26;

UPDATE dbo.Products SET
    Name = N'HNJ Titan A4001K Graphic Open-Face Helmet',
    Description = N'Sporty open-face helmet decorated with aggressive geometric graphics, UV-treated clear visor, and easy-clean removable cheek pads.'
WHERE Id = 27;

UPDATE dbo.Products SET
    Name = N'HNJ 2020 Aerodynamic Full-Face Helmet',
    Description = N'Full-coverage street helmet offering solid impact protection, streamlined chin vent, and wide panoramic view.'
WHERE Id = 28;

UPDATE dbo.Products SET
    Name = N'Zebra YM-602 Flip-Up Modular Helmet',
    Description = N'Dual-visor modular helmet built for daily couriers and touring riders with one-hand chin release and high-visibility reflective decals.'
WHERE Id = 29;

UPDATE dbo.Products SET
    Name = N'Zebra YM-902 CityJet Open-Face Helmet',
    Description = N'Modern urban half-face helmet with full-coverage front shield, top air vents, and comfortable moisture-wicking liner.'
WHERE Id = 30;

UPDATE dbo.Products SET
    Name = N'AGV K1 S Red Bull Race Edition Full-Face Helmet',
    Description = N'Aerodynamic sport helmet designed from AGV''s MotoGP racing experience. Features an Ultravision anti-scratch visor with 190° horizontal field of view, double-D retention system, and integrated aerodynamic spoiler.'
WHERE Id = 31;

UPDATE dbo.Products SET
    Name = N'AGV K1 S VR46 Sky Racing Team Helmet',
    Description = N'Official Valentino Rossi VR46 tribute graphic on AGV''s high-resistance thermoplastic resin shell. Tuned with wind-tunnel CFD aerodynamics and 4 multi-density EPS liners for track-level impact absorption.'
WHERE Id = 32;

UPDATE dbo.Products SET
    Name = N'AGV Tourmodular Solid Pearl White Helmet',
    Description = N'Premium dual-homologated (P/J) flip-up modular touring helmet. Built from carbon-aramid-fiberglass shell with integrated drop-down sun visor and Ritmo/Shalimar antibacterial moisture-wicking comfort lining.'
WHERE Id = 33;

UPDATE dbo.Products SET
    Name = N'Gille GTS 920 Adventure Peak Dual Sport Helmet',
    Description = N'Rugged dual-sport adventure helmet equipped with an aerodynamically optimized sun peak, drop-down inner sun visor, high-impact ABS composite shell, and multi-channel ventilation for on-road and off-road trail riding.'
WHERE Id = 34;

UPDATE dbo.Products SET
    Name = N'Gille 135 GTS V1 Stealth Black Full-Face Helmet',
    Description = N'Sleek full-face street helmet in matte stealth black. Features quick-release optical clear visor, dual-exhaust rear spoilers, removable washable comfort liner, and BPS / DOT certified high-impact composite shell.'
WHERE Id = 35;

UPDATE dbo.Products SET
    Name = N'Gille Falcon 883 Heritage Classic Peak Helmet',
    Description = N'Retro-modern full-face helmet combining cafe racer styling with modern safety. Includes a removable sun peak, reinforced chin bar, anti-fog coated visor, and plush quilted comfort liner.'
WHERE Id = 36;

UPDATE dbo.Products SET
    Name = N'Gille CityJet Dual Visor Open-Face Helmet',
    Description = N'Lightweight urban commuter half-face helmet with an extended outer face shield for wind protection and an integrated drop-down smoke visor for glare reduction in heavy city traffic.'
WHERE Id = 37;

UPDATE dbo.Products SET
    Name = N'Gille Aero GP Sakura Edition Full-Face Helmet',
    Description = N'High-visibility aerodynamic sport helmet featuring an elongated racing spoiler, multi-port top and chin ventilation, anti-scratch UV-cut visor, and quick-release micrometric chin strap.'
WHERE Id = 38;

UPDATE dbo.Products SET
    Name = N'Shoei J-Cruise II Graphic Open-Face Helmet',
    Description = N'Compact, premium open-face touring helmet featuring AIM+ composite matrix shell, micro-ratchet chinstrap, CJ-2 distortion-free shield system, and integrated QSV-2 drop-down sun shield.'
WHERE Id = 39;

-- 3. ENSURE SPECIFICATION DEFINITIONS EXIST
IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'shell_material')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('shell_material', 'Shell Material', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'safety_certifications')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('safety_certifications', 'Safety Certifications', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'visor_style')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('visor_style', 'Visor System', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'retention_system')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('retention_system', 'Retention System', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'ventilation')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('ventilation', 'Ventilation', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'interior_liner')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('interior_liner', 'Interior Liner', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'weight')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('weight', 'Weight', 1, SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'comm_ready')
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt) VALUES ('comm_ready', 'Intercom Compatibility', 1, SYSUTCDATETIME());

-- Clean up any placeholder specification values
DELETE FROM dbo.ProductSpecificationValues WHERE SpecificationId IN (
    SELECT Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey IN ('save_verification', 'custom_pinlock')
);

-- Helper mapping table to populate specifications across all products
DECLARE @Def_HelmetType INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'helmet_type');
DECLARE @Def_ShellMat INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'shell_material');
DECLARE @Def_Safety INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'safety_certifications');
DECLARE @Def_Visor INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'visor_style');
DECLARE @Def_Retention INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'retention_system');
DECLARE @Def_Vent INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'ventilation');
DECLARE @Def_Liner INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'interior_liner');
DECLARE @Def_Weight INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'weight');
DECLARE @Def_Comm INT = (SELECT TOP 1 Id FROM dbo.SpecificationDefinitions WHERE SpecificationKey = 'comm_ready');

-- Reset and repopulate specifications cleanly
DELETE FROM dbo.ProductSpecificationValues;

-- Helper table for batch insert
CREATE TABLE #ProductSpecs (
    ProductId INT,
    SpecDefId INT,
    Val NVARCHAR(500)
);

-- Populating Specifications for all helmets
INSERT INTO #ProductSpecs (ProductId, SpecDefId, Val)
SELECT 
    p.Id,
    defs.DefId,
    defs.Val
FROM dbo.Products p
CROSS APPLY (
    VALUES
        (@Def_HelmetType, 
            CASE 
                WHEN p.CategoryId = 1 THEN N'Full Face Supersport'
                WHEN p.CategoryId = 2 THEN N'Modular Flip-Up Touring'
                WHEN p.CategoryId = 3 THEN N'Dual Sport / Adventure Enduro'
                WHEN p.CategoryId = 4 THEN N'Open Face / Urban Commuter'
                ELSE N'Full Face Street'
            END
        ),
        (@Def_ShellMat,
            CASE
                WHEN p.Id = 2 THEN N'100% 3K Carbon Fiber (Racing Grade)'
                WHEN p.Id IN (1, 10, 11, 23) THEN N'Shoei AIM+ (Advanced Integrated Matrix Plus Multi-Ply Organic Fibers)'
                WHEN p.Id IN (5, 7, 17, 20, 33) THEN N'Carbon-Aramidic & Fiberglass Composite Matrix'
                WHEN p.Id IN (18, 19, 31, 32) THEN N'High-Resistance Thermoplastic Resin (HIR-TH)'
                WHEN p.BrandId = 2 THEN N'Engineered High-Impact ABS Composite with EPS Foam'
                WHEN p.BrandId = 3 THEN N'Multi-Density EPS with Molded Thermoplastic ABS'
                ELSE N'High-Impact Polycarbonate Matrix'
            END
        ),
        (@Def_Safety,
            CASE
                WHEN p.Id IN (2, 11) THEN N'FIM Racing Homologated, ECE 22.06 & DOT Certified'
                WHEN p.Id IN (1, 5, 7, 10, 17, 20, 23, 31, 32, 33, 39) THEN N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)'
                WHEN p.BrandId = 2 THEN N'DOT FMVSS 218 & BPS ICC Certified'
                ELSE N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified'
            END
        ),
        (@Def_Visor,
            CASE
                WHEN p.Id = 2 THEN N'Ultrawide Class 1 Optics (5mm thick), 190° Field of View, Max Pinlock 120 Ready'
                WHEN p.Id IN (1, 11) THEN N'Shoei CWR-F2 Shield with Center Locking System & Pinlock EVO Insert Included'
                WHEN p.Id IN (5, 23) THEN N'Shoei CNS-3C Optically Clear Visor + Integrated Drop-Down QSV-2 Sun Shield'
                WHEN p.CategoryId = 2 OR p.Id IN (18, 22, 29, 33, 34, 37) THEN N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor'
                WHEN p.CategoryId = 4 THEN N'Deep Extended Anti-Scratch & UV400 Protective Visor'
                ELSE N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)'
            END
        ),
        (@Def_Retention,
            CASE
                WHEN p.Id IN (1, 2, 7, 11, 17, 18, 19, 20, 31, 32) THEN N'Titanium / Stainless Steel Double-D Ring System'
                ELSE N'Micro-Metric Quick-Release Steel Ratchet Buckle'
            END
        ),
        (@Def_Vent,
            CASE
                WHEN p.Id IN (2, 11) THEN N'Direct-Flow Tuned Racing Ventilation (5 Front Intakes, 2 Rear Extractors, Metal Vents)'
                WHEN p.Id IN (1, 5, 10, 23) THEN N'High-Efficiency Multi-Port Ventilation with Shutter Controls'
                WHEN p.CategoryId = 3 OR p.Id IN (7, 34) THEN N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops'
                ELSE N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust'
            END
        ),
        (@Def_Liner,
            CASE
                WHEN p.Id = 2 THEN N'Shalimar & Ritmo Fabric with Sanitized Antibacterial Treatment & 360° Adaptive Fit'
                WHEN p.Id IN (1, 5, 11, 23) THEN N'3D Max-Dry Interior System (Fully Removable, Washable, Moisture-Wicking with EQRS)'
                ELSE N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding'
            END
        ),
        (@Def_Weight,
            CASE
                WHEN p.Id = 2 THEN N'1,450g ± 50g (Ultralight Pure Carbon)'
                WHEN p.Id = 17 THEN N'1,255g ± 50g (Compact Lightweight Shell)'
                WHEN p.Id IN (1, 11) THEN N'1,480g ± 50g'
                WHEN p.CategoryId = 2 THEN N'1,690g ± 50g (Modular Touring Build)'
                WHEN p.CategoryId = 4 THEN N'1,200g ± 50g (Open Face Lightweight)'
                ELSE N'1,450g ± 50g'
            END
        ),
        (@Def_Comm,
            CASE
                WHEN p.Id IN (5, 23) THEN N'Integrated Sena SRL3 / SRL2 Intercom Housing Ready'
                ELSE N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)'
            END
        )
) defs (DefId, Val);

-- Insert into actual specification values table
INSERT INTO dbo.ProductSpecificationValues (ProductId, SpecificationId, SpecificationValue, CreatedAt, UpdatedAt)
SELECT ProductId, SpecDefId, Val, SYSUTCDATETIME(), SYSUTCDATETIME()
FROM #ProductSpecs;

DROP TABLE #ProductSpecs;

-- 4. REPLACE REVIEWS WITH REALISTIC, AUTHENTIC RIDER REVIEWS
DELETE FROM dbo.ProductReviews;

INSERT INTO dbo.ProductReviews (
    ProductId, UserId, OrderId, ReviewerName, Rating, Title, Comment, IsVerifiedPurchase, IsHidden, CreatedAt
)
VALUES
(
    1, 6, 1, N'Mark Kevin Del Mundo', 5,
    N'Exceptional aerodynamics & dead quiet on expressway',
    N'Upgraded from an entry-level lid to this Shoei RF-1400 and the difference is night and day. Traveling along NLEX at 100+ km/h has virtually zero wind buffeting. The CWR-F2 visor seal with the center lock completely blocks whistle noise. Pinlock keeps it crystal clear on rainy Marilaque morning rides.',
    1, 0, DATEADD(DAY, -3, SYSUTCDATETIME())
),
(
    2, 6, 25, N'Angelo Reyes', 5,
    N'Pure carbon masterpiece — lighter than anything I''ve worn',
    N'The AGV Pista GP RR is true race-spec jewelry. You can genuinely feel how light the 100% carbon shell is; virtually zero neck strain even after 3 hours of continuous riding. The 190-degree panoramic field of vision lets you see apexes without craning your neck. Worth every single peso!',
    1, 0, DATEADD(DAY, -5, SYSUTCDATETIME())
),
(
    11, 7, 23, N'Paolo Mendoza', 5,
    N'Track-ready performance and supreme ventilation',
    N'Bought the Shoei X-Fifteen for Clark International Speedway track days. The aerodynamic stabilization fins completely eliminate lift when tucked in on the main straight. The cheek pad angle adjustment is genius for sportbike aggressive riding postures.',
    1, 0, DATEADD(DAY, -7, SYSUTCDATETIME())
),
(
    5, 7, 22, N'Katrina Santos', 5,
    N'Best modular touring helmet for Philippine weather',
    N'The Shoei Neotec II flip-up mechanism operates with satisfying precision even with thick riding gloves on. The drop-down QSV-1 sun visor drops low enough without hitting the bridge of my nose. Padding is plush and washes easily after hot weekend rides to Tagaytay.',
    1, 0, DATEADD(DAY, -9, SYSUTCDATETIME())
),
(
    17, 6, 24, N'Christian Tan', 5,
    N'Crazy lightweight and looks stunning in matte stealth',
    N'Weighs only around 1.25kg! Coming from a heavy 1.7kg lid, my neck feels so relaxed. The matte finish doesn''t show fingerprint smudges easily, and the visor detents click firmly into place. Perfect all-rounder for both city commutes and long province rides.',
    1, 0, DATEADD(DAY, -12, SYSUTCDATETIME())
),
(
    9, 6, 25, N'Miguel Dizon', 5,
    N'Unbeatable value for daily commuting',
    N'The Gille 135 GTS V1 is probably the best bang-for-buck helmet you can buy in the Philippines. Build quality is solid, vents actually channel air through the EPS channels, and the quick-release buckle is very convenient for daily stop-and-go rides.',
    1, 0, DATEADD(DAY, -15, SYSUTCDATETIME())
),
(
    31, 7, 23, N'Rico Salazar', 5,
    N'Eye-catching Red Bull race graphics & super snug fit',
    N'The Red Bull racing graphic turns heads at every stoplight! High-speed stability is rock solid thanks to the extended rear aero spoiler. Visor mechanism snaps tight with zero air leaks. Make sure to follow the size chart as AGV fits nice and snug.',
    1, 0, DATEADD(DAY, -18, SYSUTCDATETIME())
),
(
    10, 6, 25, N'Dave Villanueva', 5,
    N'The peak doesn''t catch wind at all on the highway',
    N'Rode my adventure bike through Sierra Madre and Sagada with the Shoei Hornet ADV. Most peaked helmets pull your head back at 90km/h, but Shoei''s louvers allow air to pass straight through. Extremely comfortable and dust-sealed visor.',
    1, 0, DATEADD(DAY, -21, SYSUTCDATETIME())
),
(
    23, 7, 22, N'Jericho Ramos', 5,
    N'Sena SRL3 integration is completely seamless',
    N'Upgraded to the Neotec 3 specifically for the built-in comms slot. The sound deadening is remarkable — I can take crystal-clear phone calls at 80km/h and the caller can''t even tell I''m on a big bike. Premium build in every detail.',
    1, 0, DATEADD(DAY, -24, SYSUTCDATETIME())
),
(
    34, 6, 24, N'Francis Alcantara', 4,
    N'Solid dual-sport helmet for weekend trail rides',
    N'The Gille GTS 920 handles dual-sport duties effortlessly. The inner tinted sun visor is a lifesaver when riding into direct late afternoon glare. Cheek pads were slightly snug on day one but broke in perfectly after two rides.',
    1, 0, DATEADD(DAY, -28, SYSUTCDATETIME())
),
(
    21, 6, 25, N'Joshua Cruz', 5,
    N'Reliable daily driver for delivery & errands',
    N'Using this Zebra FF-855 for daily city rides. Clear shield offers great peripheral vision for checking blind spots in bumper-to-bumper traffic. Padding is easily removable for weekly washes. Certified safe with genuine BPS sticker.',
    1, 0, DATEADD(DAY, -30, SYSUTCDATETIME())
),
(
    18, 7, 23, N'Bea Navarro', 5,
    N'Aggressive look with very practical drop-down sun visor',
    N'The Monster Energy livery on this AGV K3 SV is crisp and vivid. I love the internal sun shield lever on the left side — very easy to flip up and down while keeping eyes on the road. Fits my Cardo Freecom speakers with plenty of ear room.',
    1, 0, DATEADD(DAY, -35, SYSUTCDATETIME())
);

COMMIT TRANSACTION;
GO
