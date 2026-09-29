-- =====================================================================================
-- DATABASE: Helmet Cartel Ordering and Management System
-- SCRIPT: 03_helmet_catalog_seed.sql - Image-based helmet catalog seed
-- New database: run after 01_schema.sql and 02_seed_data.sql.
-- Existing database: run 02_3nf_integrity_migration.sql and 03_procedures_and_queries.sql first.
-- Re-running this script adds only missing catalog rows and never resets stock or prices.
-- =====================================================================================

USE HelmetCartelDB;
GO

IF OBJECT_ID(N'dbo.sp_SeedHelmetCatalog', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.sp_SeedHelmetCatalog AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_SeedHelmetCatalog
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID(N'dbo.ProductColors', N'U') IS NULL
    BEGIN
        RAISERROR(N'ProductColors missing. Run database/schema/02_3nf_integrity_migration.sql first.', 16, 1);
        RETURN;
    END;

    DECLARE @Brands TABLE
    (
        Name NVARCHAR(100) NOT NULL PRIMARY KEY,
        LogoUrl NVARCHAR(255) NOT NULL
    );
    INSERT INTO @Brands (Name, LogoUrl) VALUES
        (N'Zebra', N'/Content/images/zebra.png'),
        (N'AGV', N'/Content/images/agv.png'),
        (N'Gille', N'/Content/images/gille.png'),
        (N'HNJ', N'/Content/images/hnj.png'),
        (N'Shoei', N'/Content/images/shoei.png');

    DECLARE @Products TABLE
    (
        BrandName NVARCHAR(100) NOT NULL,
        CategorySlug NVARCHAR(100) NOT NULL,
        Name NVARCHAR(200) NOT NULL,
        Slug NVARCHAR(220) NOT NULL PRIMARY KEY,
        Description NVARCHAR(500) NOT NULL,
        RidingStyle NVARCHAR(50) NOT NULL,
        MainImageUrl NVARCHAR(500) NOT NULL
    );
    INSERT INTO @Products (BrandName, CategorySlug, Name, Slug, Description, RidingStyle, MainImageUrl) VALUES
        (N'Zebra', N'open-face-urban', N'Zebra YM-602 Plain Helmet', N'zebra-ym-602-plain', N'Open-face Zebra YM-602 helmet. Color names describe visible image variants.', N'Casual/Urban', N'/Content/images/products/helmets/zebra/zebra-ym-602.jpg'),
        (N'Zebra', N'open-face-urban', N'Zebra YM-902 Helmet', N'zebra-ym-902', N'Open-face Zebra YM-902 helmet. Color names describe visible image variants.', N'Casual/Urban', N'/Content/images/products/helmets/zebra/zebra-ym-902.jpg'),
        (N'Zebra', N'open-face-urban', N'Zebra 603 Helmet', N'zebra-603', N'Open-face Zebra 603 graphic helmet based on supplied product image.', N'Casual/Urban', N'/Content/images/products/helmets/zebra/zebra-603.jpg'),
        (N'Zebra', N'full-face', N'Zebra FF-855 Full-Face Helmet', N'zebra-ff-855', N'Full-face Zebra FF-855 helmet based on supplied product image.', N'Sport/Track', N'/Content/images/products/helmets/zebra/zebra-ff-855.jpg'),
        (N'Zebra', N'modular', N'Zebra Hornet Modular Helmet', N'zebra-hornet-modular', N'Modular Zebra Hornet helmet with dual visor, based on supplied product images.', N'Touring/Adventure', N'/Content/images/products/helmets/zebra/zebra-hornet.jpg'),
        (N'AGV', N'full-face', N'AGV Matte Black Full-Face Helmet', N'agv-matte-black-full-face', N'Provisional product name. Matte black full-face helmet shown in supplied AGV images.', N'Sport/Track', N'/Content/images/products/helmets/agv/agv-matte-black.jpg'),
        (N'AGV', N'full-face', N'AGV Neon Graphic Full-Face Helmet', N'agv-neon-graphic-full-face', N'Provisional product name. Neon graphic full-face helmet shown in supplied AGV images.', N'Sport/Track', N'/Content/images/products/helmets/agv/agv-neon-graphic.jpg'),
        (N'AGV', N'full-face', N'AGV Red Blue Graphic Full-Face Helmet', N'agv-red-blue-graphic-full-face', N'Provisional product name. Red and blue graphic full-face helmet shown in supplied AGV images.', N'Sport/Track', N'/Content/images/products/helmets/agv/agv-red-blue-graphic.jpg'),
        (N'AGV', N'full-face', N'AGV Monster Graphic Full-Face Helmet', N'agv-monster-graphic-full-face', N'Provisional product name. Black and green racing graphic full-face helmet shown in supplied AGV images.', N'Sport/Track', N'/Content/images/products/helmets/agv/agv-monster-graphic.jpg'),
        (N'Gille', N'full-face', N'Gille FF007 Kerena Full-Face Helmet', N'gille-ff007-kerena', N'Gille FF007 Kerena full-face helmet. Color options follow supplied product images.', N'Sport/Track', N'/Content/images/products/helmets/gille/gille-ff007-kerena.webp'),
        (N'Gille', N'full-face', N'Gille A5009 Phoenix Helmet', N'gille-a5009-phoenix', N'Gille A5009 Phoenix helmet. Color options follow supplied product images.', N'Casual/Urban', N'/Content/images/products/helmets/gille/gille-a5009-phoenix.webp'),
        (N'Gille', N'full-face', N'Gille FF005 Visage Full-Face Helmet', N'gille-ff005-visage', N'Gille FF005 Visage plain full-face helmet shown in supplied product image.', N'Sport/Track', N'/Content/images/products/helmets/gille/gille-ff005-visage.webp'),
        (N'Gille', N'full-face', N'Gille 883 Falcon Full-Face Helmet', N'gille-883-falcon', N'Gille 883 Falcon DC Flash Red graphic helmet shown in supplied product image.', N'Sport/Track', N'/Content/images/products/helmets/gille/gille-883-falcon.webp'),
        (N'Gille', N'dual-sport-adventure', N'Gille 135 GTS V1 Helmet', N'gille-135-gts-v1', N'Gille 135 GTS V1 two-tone matte black and grey helmet shown in supplied product image.', N'Touring/Adventure', N'/Content/images/products/helmets/gille/gille-135-gts-v1.webp'),
        (N'HNJ', N'open-face-urban', N'HNJ A4-001 Plain Helmet', N'hnj-a4-001-plain', N'Open-face HNJ A4-001 plain helmet. Color options follow supplied product images.', N'Casual/Urban', N'/Content/images/products/helmets/hnj/hnj-a4-001.jpg'),
        (N'HNJ', N'open-face-urban', N'HNJ A4-008 Helmet', N'hnj-a4-008', N'Open-face HNJ A4-008 helmet. Color options follow supplied product images.', N'Casual/Urban', N'/Content/images/products/helmets/hnj/hnj-a4-008.jpg'),
        (N'HNJ', N'open-face-urban', N'HNJ 2020 Helmet', N'hnj-2020', N'Open-face HNJ 2020 helmet. Color options follow supplied product images.', N'Casual/Urban', N'/Content/images/products/helmets/hnj/hnj-2020.jpg'),
        (N'HNJ', N'full-face', N'HNJ 937 Full-Face Helmet', N'hnj-937', N'HNJ 937 helmet shown in supplied product images. Product name follows visible image label.', N'Casual/Urban', N'/Content/images/products/helmets/hnj/hnj-937.jpg'),
        (N'HNJ', N'open-face-urban', N'HNJ Titan A4001K Graphic Helmet', N'hnj-titan-a4001k', N'HNJ Titan A4001K graphic helmet. Mario and Hello Kitty color names follow supplied product images.', N'Casual/Urban', N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-mario-white.webp'),
        (N'Shoei', N'modular', N'Shoei Neotec 3 Modular Helmet', N'shoei-neotec-3', N'Shoei Neotec 3 modular helmet shown in supplied product image.', N'Touring/Adventure', N'/Content/images/products/helmets/shoei/shoei-neotec-3.jpg'),
        (N'Shoei', N'dual-sport-adventure', N'Shoei Hornet ADV Helmet', N'shoei-hornet-adv', N'Shoei Hornet ADV helmet. TC-5 and TC-7 graphics are visible in supplied product images.', N'Touring/Adventure', N'/Content/images/products/helmets/shoei/shoei-hornet-adv.jpg'),
        (N'Shoei', N'full-face', N'Shoei X-Fifteen Graphic Helmet', N'shoei-x-fifteen', N'Shoei X-Fifteen helmet with racing graphics shown in supplied product images.', N'Sport/Track', N'/Content/images/products/helmets/shoei/shoei-x-fifteen.jpg');

    DECLARE @Colors TABLE
    (
        ProductSlug NVARCHAR(220) NOT NULL,
        SkuToken NVARCHAR(40) NOT NULL,
        Color NVARCHAR(50) NOT NULL,
        ColorHex NVARCHAR(10) NOT NULL,
        PRIMARY KEY (ProductSlug, SkuToken)
    );
    INSERT INTO @Colors (ProductSlug, SkuToken, Color, ColorHex) VALUES
        (N'zebra-ym-602-plain', N'MATTE-BLACK', N'Matte Black', N'#1F1F1F'),
        (N'zebra-ym-602-plain', N'GLOSS-BLACK', N'Gloss Black', N'#111111'),
        (N'zebra-ym-602-plain', N'WHITE', N'White', N'#F5F5F5'),
        (N'zebra-ym-602-plain', N'GREY', N'Grey', N'#777777'),
        (N'zebra-ym-602-plain', N'AQUA', N'Aqua', N'#67D9D0'),
        (N'zebra-ym-902', N'WHITE', N'White', N'#F5F5F5'),
        (N'zebra-ym-902', N'GREY', N'Grey', N'#777777'),
        (N'zebra-ym-902', N'BLACK', N'Black', N'#1F1F1F'),
        (N'zebra-ym-902', N'AQUA', N'Aqua', N'#67D9D0'),
        (N'zebra-603', N'RED-GRAPHIC', N'Red Graphic', N'#D90429'),
        (N'zebra-ff-855', N'RED', N'Gloss Red', N'#D90429'),
        (N'zebra-ff-855', N'BLACK', N'Black', N'#1F1F1F'),
        (N'zebra-hornet-modular', N'BLACK-RED', N'Gloss Black Red', N'#B00020'),
        (N'zebra-hornet-modular', N'WHITE-BLUE', N'White Blue Graphic', N'#1F66D1'),
        (N'zebra-hornet-modular', N'BLACK-ORANGE', N'Black Orange Graphic', N'#F06A00'),
        (N'zebra-hornet-modular', N'PINK', N'Pink Graphic', N'#E76F9A'),
        (N'agv-matte-black-full-face', N'MATTE-BLACK', N'Matte Black', N'#1F1F1F'),
        (N'agv-neon-graphic-full-face', N'NEON-GRAPHIC', N'Neon Multi-Color Graphic', N'#B5E61D'),
        (N'agv-red-blue-graphic-full-face', N'RED-BLUE-GRAPHIC', N'Red Blue Graphic', N'#D7263D'),
        (N'agv-monster-graphic-full-face', N'BLACK-GREEN-GRAPHIC', N'Black Green Graphic', N'#3A7D44'),
        (N'gille-ff007-kerena', N'WHITE', N'White', N'#F5F5F5'),
        (N'gille-ff007-kerena', N'LIGHT-BLUE', N'Light Blue', N'#9BD7F0'),
        (N'gille-ff007-kerena', N'MATTE-PINK', N'Matte Pink', N'#E8A6B8'),
        (N'gille-a5009-phoenix', N'GREY', N'Grey', N'#777777'),
        (N'gille-a5009-phoenix', N'LAKE-GREEN', N'Lake Green', N'#70B7A1'),
        (N'gille-a5009-phoenix', N'PINK', N'Pink', N'#E8A6B8'),
        (N'gille-ff005-visage', N'MATTE-PINK', N'Matte Pink', N'#E8A6B8'),
        (N'gille-883-falcon', N'DC-FLASH-RED', N'DC Flash Red Graphic', N'#D90429'),
        (N'gille-135-gts-v1', N'MATTE-BLACK-GREY', N'Two-Tone Matte Black Grey', N'#525252'),
        (N'hnj-a4-001-plain', N'WHITE', N'White', N'#F5F5F5'),
        (N'hnj-a4-001-plain', N'PINK', N'Gloss Pink', N'#E76F9A'),
        (N'hnj-a4-001-plain', N'BLUE', N'Gloss Blue', N'#1877C9'),
        (N'hnj-a4-001-plain', N'PURPLE', N'Purple', N'#7542A6'),
        (N'hnj-a4-001-plain', N'BLACK', N'Black', N'#1F1F1F'),
        (N'hnj-a4-001-plain', N'GREY', N'Grey', N'#777777'),
        (N'hnj-a4-001-plain', N'MINT', N'Mint Green', N'#73D6C4'),
        (N'hnj-a4-008', N'WHITE', N'White', N'#F5F5F5'),
        (N'hnj-a4-008', N'PINK', N'Gloss Pink', N'#E76F9A'),
        (N'hnj-a4-008', N'BLUE', N'Gloss Blue', N'#1877C9'),
        (N'hnj-a4-008', N'BLACK', N'Black', N'#1F1F1F'),
        (N'hnj-2020', N'RED', N'Red', N'#D90429'),
        (N'hnj-2020', N'PINK', N'Pink', N'#E76F9A'),
        (N'hnj-2020', N'GREY', N'Grey', N'#777777'),
        (N'hnj-2020', N'BLUE', N'Blue', N'#1877C9'),
        (N'hnj-2020', N'MINT', N'Mint Green', N'#73D6C4'),
        (N'hnj-2020', N'BLACK', N'Black', N'#1F1F1F'),
        (N'hnj-937', N'GREY', N'Grey', N'#777777'),
        (N'hnj-937', N'RED', N'Red', N'#D90429'),
        (N'hnj-937', N'WHITE', N'White', N'#F5F5F5'),
        (N'hnj-937', N'BLACK', N'Black', N'#1F1F1F'),
        (N'hnj-937', N'PINK', N'Pink', N'#E76F9A'),
        (N'hnj-937', N'MINT', N'Mint Green', N'#73D6C4'),
        (N'hnj-titan-a4001k', N'MARIO-WHITE', N'Mario White', N'#F5F5F5'),
        (N'hnj-titan-a4001k', N'MARIO-PINK', N'Mario Pink', N'#E8A6B8'),
        (N'hnj-titan-a4001k', N'MARIO-BLACK', N'Mario Black', N'#1F1F1F'),
        (N'hnj-titan-a4001k', N'HELLO-KITTY-CREAM', N'Hello Kitty Cream', N'#F3E6C8'),
        (N'hnj-titan-a4001k', N'HELLO-KITTY-BLACK', N'Hello Kitty Black', N'#1F1F1F'),
        (N'shoei-neotec-3', N'RED-WHITE', N'Red White Graphic', N'#D90429'),
        (N'shoei-neotec-3', N'BLUE-RED', N'Blue Red Graphic', N'#1877C9'),
        (N'shoei-hornet-adv', N'TC-5', N'Invigorate TC-5', N'#4A4A4A'),
        (N'shoei-hornet-adv', N'TC-7', N'Invigorate TC-7', N'#49B8D1'),
        (N'shoei-x-fifteen', N'ALEX-MARQUEZ-73-V3', N'Alex Marquez 73 V3', N'#1F66D1'),
        (N'shoei-x-fifteen', N'MARQUEZ-9', N'Marquez 9', N'#D90429');

    DECLARE @Sizes TABLE (Size NVARCHAR(20) NOT NULL PRIMARY KEY);
    INSERT INTO @Sizes (Size) VALUES (N'S'), (N'M'), (N'L'), (N'XL'), (N'XXL');

    IF EXISTS
    (
        SELECT 1
        FROM @Products p
        LEFT JOIN dbo.Categories c ON c.Slug = p.CategorySlug
        WHERE c.Id IS NULL
    )
    BEGIN
        RAISERROR(N'Required helmet category missing. Run database/seeds/02_seed_data.sql first.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Brands (Name, LogoUrl)
        SELECT s.Name, s.LogoUrl
        FROM @Brands s
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Brands b WHERE b.Name = s.Name);

        UPDATE b
        SET LogoUrl = s.LogoUrl
        FROM dbo.Brands b
        INNER JOIN @Brands s ON s.Name = b.Name
        WHERE ISNULL(b.LogoUrl, N'') <> s.LogoUrl;

        INSERT INTO dbo.Products
            (CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice, MainImageUrl)
        SELECT c.Id, b.Id, p.Name, p.Slug, p.Description, p.RidingStyle, 0.00, p.MainImageUrl
        FROM @Products p
        INNER JOIN dbo.Brands b ON b.Name = p.BrandName
        INNER JOIN dbo.Categories c ON c.Slug = p.CategorySlug
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Products existing WHERE existing.Slug = p.Slug);

        INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex)
        SELECT p.Id, c.Color, c.ColorHex
        FROM @Colors c
        INNER JOIN dbo.Products p ON p.Slug = c.ProductSlug
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.ProductColors existing
            WHERE existing.ProductId = p.Id AND existing.Color = c.Color
        );

        INSERT INTO dbo.ProductVariants
            (ProductColorId, SKU, Size, PriceAdjustment)
        SELECT pc.Id,
               CONCAT(REPLACE(c.ProductSlug, N'-', N''), N'-', c.SkuToken, N'-', s.Size),
               s.Size, 0.00
        FROM @Colors c
        INNER JOIN dbo.Products p ON p.Slug = c.ProductSlug
        INNER JOIN dbo.ProductColors pc ON pc.ProductId = p.Id AND pc.Color = c.Color
        CROSS JOIN @Sizes s
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.ProductVariants existing
            WHERE existing.SKU = CONCAT(REPLACE(c.ProductSlug, N'-', N''), N'-', c.SkuToken, N'-', s.Size)
        );

        INSERT INTO dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint)
        SELECT v.Id, 0, 0, 3
        FROM dbo.ProductVariants v
        INNER JOIN @Colors c
            ON v.SKU LIKE CONCAT(REPLACE(c.ProductSlug, N'-', N''), N'-', c.SkuToken, N'-%')
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Inventories i WHERE i.VariantId = v.Id);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;
        SELECT @ErrorMessage = ERROR_MESSAGE(),
               @ErrorSeverity = ERROR_SEVERITY(),
               @ErrorState = ERROR_STATE();
        RAISERROR(N'%s', @ErrorSeverity, @ErrorState, @ErrorMessage);
    END CATCH
END;
GO

EXEC dbo.sp_SeedHelmetCatalog;
GO
