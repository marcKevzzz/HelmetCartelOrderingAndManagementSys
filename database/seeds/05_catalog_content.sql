-- Catalog content from the five supplied Context brand folders.
-- Run after 03_helmet_catalog_seed.sql, 03_product_gallery.sql and
-- 04_product_specifications.sql. Prices and reviews are editable demo data.
-- Rerunnable: existing nonzero prices, custom descriptions, stock and reviews
-- are preserved. Ratings are calculated from ProductReviews by the read SPs.
USE HelmetCartelDB;
GO

IF OBJECT_ID(N'dbo.sp_SeedCatalogContent', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.sp_SeedCatalogContent AS BEGIN RETURN 0; END');
GO
ALTER PROCEDURE dbo.sp_SeedCatalogContent
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID(N'dbo.ProductGalleryImages', N'U') IS NULL OR
       OBJECT_ID(N'dbo.ProductSpecificationValues', N'U') IS NULL
        THROW 50100, 'Run the product gallery and specification schema scripts first.', 1;

    DECLARE @Catalog TABLE
    (
        Slug NVARCHAR(220) NOT NULL PRIMARY KEY,
        BrandName NVARCHAR(100) NOT NULL,
        CategorySlug NVARCHAR(100) NOT NULL,
        ProductName NVARCHAR(200) NOT NULL,
        Description NVARCHAR(500) NOT NULL,
        RidingStyle NVARCHAR(50) NOT NULL,
        BasePrice DECIMAL(18,2) NOT NULL,
        MainImageUrl NVARCHAR(500) NULL,
        HelmetType NVARCHAR(100) NOT NULL,
        Finish NVARCHAR(160) NOT NULL,
        Visor NVARCHAR(160) NOT NULL
    );
    INSERT @Catalog VALUES
    (N'zebra-ym-602-plain',N'Zebra',N'modular',N'Zebra YM-602 Plain Modular Helmet',N'Modular city helmet with a long clear visor, shown in several solid colors.',N'Casual/Urban',2759,NULL,N'Modular',N'Solid color options',N'Long clear face visor'),
    (N'zebra-ym-902',N'Zebra',N'open-face-urban',N'Zebra YM-902 Helmet',N'Open-face urban helmet with a clear face visor and rounded shell, shown in solid color options.',N'Casual/Urban',2395,NULL,N'Open face',N'Solid color options',N'Clear face visor'),
    (N'zebra-603',N'Zebra',N'open-face-urban',N'Zebra 603 Helmet',N'Open-face Zebra 603 with a red, white and black graphic and clear visor.',N'Casual/Urban',1890,NULL,N'Open face',N'Red and white graphic',N'Clear face visor'),
    (N'zebra-ff-855',N'Zebra',N'full-face',N'Zebra FF-855 Full-Face Helmet',N'Full-face helmet shown in gloss red and black finishes with a dark face shield.',N'Sport/Track',2490,NULL,N'Full face',N'Gloss red or black',N'Dark face shield shown'),
    (N'zebra-hornet-modular',N'Zebra',N'modular',N'Zebra Hornet Modular Helmet',N'Graphic modular helmet with a flip-up chin section and a long face visor.',N'Touring/Adventure',3499,NULL,N'Modular',N'Multicolor graphic options',N'Flip-up face visor'),
    (N'agv-matte-black-full-face',N'AGV',N'full-face',N'AGV Matte Black Full-Face Helmet',N'Matte black full-face helmet with sculpted chin vents and a low-profile rear spoiler. Model name is provisional.',N'Sport/Track',18990,NULL,N'Full face',N'Matte black',N'Dark face shield shown'),
    (N'agv-neon-graphic-full-face',N'AGV',N'full-face',N'AGV Neon Graphic Full-Face Helmet',N'Full-face racing graphic helmet with bright neon artwork. Model name is provisional.',N'Sport/Track',29990,NULL,N'Full face',N'Neon multicolor graphic',N'Dark face shield shown'),
    (N'agv-red-blue-graphic-full-face',N'AGV',N'full-face',N'AGV Red Blue Graphic Full-Face Helmet',N'Full-face helmet with red and blue racing artwork and a sculpted rear profile. Model name is provisional.',N'Sport/Track',28990,NULL,N'Full face',N'Red and blue graphic',N'Clear face shield shown'),
    (N'agv-monster-graphic-full-face',N'AGV',N'full-face',N'AGV Monster Graphic Full-Face Helmet',N'Full-face helmet with black, red and green race graphics. Model name is provisional.',N'Sport/Track',32990,NULL,N'Full face',N'Black and green race graphic',N'Clear face shield shown'),
    (N'gille-ff007-kerena',N'Gille',N'full-face',N'Gille FF007 Kerena Full-Face Helmet',N'Full-face Kerena helmet with a wide tinted visor, shown in white and pastel graphic finishes.',N'Sport/Track',3590,NULL,N'Full face',N'White and pastel colors',N'Tinted face shield shown'),
    (N'gille-a5009-phoenix',N'Gille',N'full-face',N'Gille A5009 Phoenix Helmet',N'Full-face Phoenix helmet with a rear spoiler and mirrored face visor, offered in several solid colors.',N'Casual/Urban',4290,NULL,N'Full face',N'Solid color options',N'Mirrored face shield shown'),
    (N'gille-ff005-visage',N'Gille',N'open-face-urban',N'Gille FF005 Visage Open-Face Helmet',N'Open-face Visage helmet in matte pink with a long clear visor and visible upper vent.',N'Casual/Urban',2690,NULL,N'Open face',N'Matte pink',N'Long clear face visor'),
    (N'gille-883-falcon',N'Gille',N'full-face',N'Gille 883 Falcon Full-Face Helmet',N'Full-face Falcon helmet with a bright red graphic, extended rear spoiler and clear shield.',N'Sport/Track',3790,NULL,N'Full face',N'Red graphic',N'Clear face shield'),
    (N'gille-135-gts-v1',N'Gille',N'full-face',N'Gille 135 GTS V1 Helmet',N'Full-face touring helmet shown in a two-tone black and grey finish with clear face shield.',N'Touring/Adventure',3990,NULL,N'Full face touring',N'Two-tone black and grey',N'Clear face shield'),
    (N'hnj-a4-001-plain',N'HNJ',N'open-face-urban',N'HNJ A4-001 Plain Helmet',N'Open-face A4-001 city helmet with a long visor, shown in multiple solid colors.',N'Casual/Urban',990,NULL,N'Open face',N'Solid color options',N'Long clear face visor'),
    (N'hnj-a4-008',N'HNJ',N'open-face-urban',N'HNJ A4-008 Helmet',N'Open-face A4-008 city helmet with a long visor, shown in black, white, pink and blue.',N'Casual/Urban',1090,NULL,N'Open face',N'Solid color options',N'Long clear face visor'),
    (N'hnj-2020',N'HNJ',N'full-face',N'HNJ 2020 Full-Face Helmet',N'Full-face city helmet with a clear visor, shown in solid and pastel finishes.',N'Casual/Urban',1699,NULL,N'Full face',N'Solid and pastel colors',N'Clear face visor'),
    (N'hnj-937',N'HNJ',N'modular',N'HNJ 937 Modular Helmet',N'Modular HNJ 937 with a compact shell profile and long visor, shown in several colors.',N'Casual/Urban',2249,NULL,N'Modular',N'Solid color options',N'Clear face visor'),
    (N'hnj-titan-a4001k',N'HNJ',N'open-face-urban',N'HNJ Titan A4001K Graphic Helmet',N'Open-face Titan A4001K with character graphics and clear visor, shown in several finishes.',N'Casual/Urban',1190,NULL,N'Open face',N'Character graphic options',N'Clear face visor'),
    (N'shoei-neotec-3',N'Shoei',N'modular',N'Shoei Neotec 3 Modular Helmet',N'Modular touring helmet with flip-up chin section, integrated visor and sculpted shell.',N'Touring/Adventure',37990,NULL,N'Modular',N'Multicolor graphic options',N'Clear face shield'),
    (N'shoei-hornet-adv',N'Shoei',N'dual-sport-adventure',N'Shoei Hornet ADV Helmet',N'Adventure helmet with a prominent peak and full face shield, shown in several graphic finishes.',N'Touring/Adventure',36990,NULL,N'Dual sport adventure',N'Graphic color options',N'Peak and clear face shield'),
    (N'shoei-x-fifteen',N'Shoei',N'full-face',N'Shoei X-Fifteen Graphic Helmet',N'Full-face race helmet with multiple graphic finishes and a sculpted aerodynamic profile.',N'Sport/Track',39990,NULL,N'Full face',N'Multicolor race graphics',N'Dark face shield shown'),
    (N'agv-white-modular',N'AGV',N'modular',N'AGV White Modular Helmet',N'White modular helmet with a flip-up chin section and dark visor. Model name is provisional.',N'Touring/Adventure',18990,N'/Content/images/products/helmets/agv/agv-white-modular-main-primary.jpg',N'Modular',N'Gloss white',N'Dark face shield shown'),
    (N'agv-vr46-graphic',N'AGV',N'full-face',N'AGV VR46 Graphic Full-Face Helmet',N'Full-face helmet with yellow, black and white VR46 graphics. Model name is provisional.',N'Sport/Track',29990,N'/Content/images/products/helmets/agv/agv-vr46-graphic-main-primary.jpg',N'Full face',N'Yellow and black race graphic',N'Clear face shield shown'),
    (N'agv-red-bull-graphic',N'AGV',N'full-face',N'AGV Red Bull Graphic Full-Face Helmet',N'Full-face helmet with orange and red racing graphics. Model name is provisional.',N'Sport/Track',32990,N'/Content/images/products/helmets/agv/agv-red-bull-graphic-main-primary.jpg',N'Full face',N'Orange racing graphic',N'Dark face shield shown'),
    (N'gille-dual-visor-open-face',N'Gille',N'open-face-urban',N'Gille Dual Visor Open-Face Helmet',N'Open-face helmet with long face visor and a second tinted visor visible in the supplied photos. Model name is provisional.',N'Casual/Urban',2990,N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-main-primary.jpg',N'Open face',N'Solid and graphic color options',N'Clear outer and tinted inner visors shown'),
    (N'gille-classic-peak-full-face',N'Gille',N'full-face',N'Gille Classic Peak Full-Face Helmet',N'Classic full-face silhouette with a short peak, shown in blue and white. Model name is provisional.',N'Casual/Urban',2990,N'/Content/images/products/helmets/gille/gille-classic-peak-full-face-main-primary.jpg',N'Full face',N'Blue or white',N'Short peak; eye opening shown'),
    (N'gille-adventure-peak',N'Gille',N'dual-sport-adventure',N'Gille Adventure Peak Helmet',N'Angular adventure helmet with raised peak and full face shield. Model name is provisional.',N'Touring/Adventure',4490,N'/Content/images/products/helmets/gille/gille-adventure-peak-main-primary.jpg',N'Dual sport adventure',N'Grey, white or black',N'Peak and clear face shield'),
    (N'gille-pink-aero-full-face',N'Gille',N'full-face',N'Gille Pink Aero Full-Face Helmet',N'Pink full-face helmet with rear aerodynamic extension. Model name is provisional.',N'Sport/Track',3290,N'/Content/images/products/helmets/gille/gille-pink-aero-full-face-main-primary.jpg',N'Full face',N'Gloss pink',N'Tinted face shield shown'),
    (N'gille-black-full-face',N'Gille',N'full-face',N'Gille Black Full-Face Helmet',N'Black full-face helmet with front vents and clear shield. Model name is provisional.',N'Casual/Urban',3290,N'/Content/images/products/helmets/gille/gille-black-full-face-main-primary.jpg',N'Full face',N'Black',N'Clear face shield'),
    (N'shoei-graphic-open-face',N'Shoei',N'open-face-urban',N'Shoei Graphic Open-Face Helmet',N'Open-face helmet with a wraparound visor, shown in blue and white graphics. Model name is provisional.',N'Casual/Urban',30990,N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-main-primary.jpg',N'Open face',N'Blue or white graphic',N'Wraparound face visor');

    DECLARE @NewColors TABLE (Slug NVARCHAR(220), Token NVARCHAR(30), Color NVARCHAR(50), ColorHex NVARCHAR(10));
    INSERT @NewColors VALUES
    (N'agv-white-modular',N'WHITE',N'White',N'#F5F5F5'),
    (N'agv-vr46-graphic',N'YELLOW',N'Yellow Black Graphic',N'#E7D315'),
    (N'agv-red-bull-graphic',N'ORANGE',N'Orange Red Graphic',N'#F06A00'),
    (N'gille-dual-visor-open-face',N'BLACK',N'Plain Black',N'#1F1F1F'),
    (N'gille-dual-visor-open-face',N'WHITE',N'Plain White',N'#F5F5F5'),
    (N'gille-dual-visor-open-face',N'PINK',N'Plain Pink',N'#E8A6B8'),
    (N'gille-dual-visor-open-face',N'BLUE',N'Plain Blue',N'#9BD7F0'),
    (N'gille-a5009-phoenix',N'BLUE',N'Blue',N'#3457A4'),
    (N'gille-classic-peak-full-face',N'BLUE',N'Blue',N'#55708A'),
    (N'gille-classic-peak-full-face',N'WHITE',N'White',N'#F5F5F5'),
    (N'gille-adventure-peak',N'GREY',N'Grey',N'#777777'),
    (N'gille-adventure-peak',N'WHITE',N'White',N'#F5F5F5'),
    (N'gille-adventure-peak',N'BLACK',N'Black',N'#1F1F1F'),
    (N'gille-pink-aero-full-face',N'PINK',N'Pink',N'#E8A6B8'),
    (N'gille-black-full-face',N'BLACK',N'Black',N'#1F1F1F'),
    (N'shoei-graphic-open-face',N'BLUE',N'Blue Graphic',N'#345F88'),
    (N'shoei-graphic-open-face',N'WHITE',N'White Graphic',N'#F5F5F5');

    DECLARE @Gallery TABLE (Slug NVARCHAR(220), DisplayOrder TINYINT, ImageUrl NVARCHAR(500));
    -- BEGIN GENERATED GALLERY ROWS
    INSERT @Gallery VALUES
    (N'agv-neon-graphic-full-face',1,N'/Content/images/products/helmets/agv/agv-neon-graphic-full-face-gallery-1.jpg'),
    (N'agv-neon-graphic-full-face',2,N'/Content/images/products/helmets/agv/agv-neon-graphic-full-face-gallery-2.jpg'),
    (N'agv-neon-graphic-full-face',3,N'/Content/images/products/helmets/agv/agv-neon-graphic-full-face-gallery-3.jpg'),
    (N'agv-red-blue-graphic-full-face',1,N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-1.jpg'),
    (N'agv-red-blue-graphic-full-face',2,N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-2.jpg'),
    (N'agv-red-blue-graphic-full-face',3,N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-3.jpg'),
    (N'agv-red-blue-graphic-full-face',4,N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-4.jpg'),
    (N'agv-monster-graphic-full-face',1,N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-1.jpg'),
    (N'agv-monster-graphic-full-face',2,N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-2.jpg'),
    (N'agv-monster-graphic-full-face',3,N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-3.jpg'),
    (N'agv-monster-graphic-full-face',4,N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-4.jpg'),
    (N'agv-monster-graphic-full-face',5,N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-5.jpg'),
    (N'agv-matte-black-full-face',1,N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-1.jpg'),
    (N'agv-matte-black-full-face',2,N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-2.jpg'),
    (N'agv-matte-black-full-face',3,N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-3.jpg'),
    (N'agv-matte-black-full-face',4,N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-4.jpg'),
    (N'agv-matte-black-full-face',5,N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-5.jpg'),
    (N'agv-white-modular',1,N'/Content/images/products/helmets/agv/agv-white-modular-gallery-1.jpg'),
    (N'agv-white-modular',2,N'/Content/images/products/helmets/agv/agv-white-modular-gallery-2.jpg'),
    (N'agv-white-modular',3,N'/Content/images/products/helmets/agv/agv-white-modular-gallery-3.jpg'),
    (N'agv-vr46-graphic',1,N'/Content/images/products/helmets/agv/agv-vr46-graphic-gallery-1.jpg'),
    (N'agv-vr46-graphic',2,N'/Content/images/products/helmets/agv/agv-vr46-graphic-gallery-2.jpg'),
    (N'agv-red-bull-graphic',1,N'/Content/images/products/helmets/agv/agv-red-bull-graphic-gallery-1.jpg'),
    (N'agv-red-bull-graphic',2,N'/Content/images/products/helmets/agv/agv-red-bull-graphic-gallery-2.jpg'),
    (N'gille-ff007-kerena',1,N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-1.jpg'),
    (N'gille-ff007-kerena',2,N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-2.jpg'),
    (N'gille-ff007-kerena',3,N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-3.jpg'),
    (N'gille-a5009-phoenix',1,N'/Content/images/products/helmets/gille/gille-a5009-phoenix-gallery-1.jpg'),
    (N'gille-ff005-visage',1,N'/Content/images/products/helmets/gille/gille-ff005-visage-gallery-1.jpg'),
    (N'gille-dual-visor-open-face',1,N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-1.jpg'),
    (N'gille-dual-visor-open-face',2,N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-2.jpg'),
    (N'gille-dual-visor-open-face',3,N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-3.jpg'),
    (N'gille-dual-visor-open-face',4,N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-4.jpg'),
    (N'gille-dual-visor-open-face',5,N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-5.jpg'),
    (N'gille-classic-peak-full-face',1,N'/Content/images/products/helmets/gille/gille-classic-peak-full-face-gallery-1.jpg'),
    (N'gille-adventure-peak',1,N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-1.jpg'),
    (N'gille-adventure-peak',2,N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-2.jpg'),
    (N'gille-adventure-peak',3,N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-3.jpg'),
    (N'hnj-a4-001-plain',1,N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-1.jpg'),
    (N'hnj-a4-001-plain',2,N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-2.jpg'),
    (N'hnj-a4-001-plain',3,N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-3.jpg'),
    (N'hnj-a4-001-plain',4,N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-4.jpg'),
    (N'hnj-a4-001-plain',5,N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-5.jpg'),
    (N'hnj-a4-008',1,N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-1.jpg'),
    (N'hnj-a4-008',2,N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-2.jpg'),
    (N'hnj-a4-008',3,N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-3.jpg'),
    (N'hnj-a4-008',4,N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-4.jpg'),
    (N'hnj-a4-008',5,N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-5.jpg'),
    (N'hnj-2020',1,N'/Content/images/products/helmets/hnj/hnj-2020-gallery-1.jpg'),
    (N'hnj-2020',2,N'/Content/images/products/helmets/hnj/hnj-2020-gallery-2.jpg'),
    (N'hnj-2020',3,N'/Content/images/products/helmets/hnj/hnj-2020-gallery-3.jpg'),
    (N'hnj-2020',4,N'/Content/images/products/helmets/hnj/hnj-2020-gallery-4.jpg'),
    (N'hnj-2020',5,N'/Content/images/products/helmets/hnj/hnj-2020-gallery-5.jpg'),
    (N'hnj-937',1,N'/Content/images/products/helmets/hnj/hnj-937-gallery-1.jpg'),
    (N'hnj-937',2,N'/Content/images/products/helmets/hnj/hnj-937-gallery-2.jpg'),
    (N'hnj-937',3,N'/Content/images/products/helmets/hnj/hnj-937-gallery-3.jpg'),
    (N'hnj-937',4,N'/Content/images/products/helmets/hnj/hnj-937-gallery-4.jpg'),
    (N'hnj-937',5,N'/Content/images/products/helmets/hnj/hnj-937-gallery-5.jpg'),
    (N'shoei-neotec-3',1,N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-1.jpg'),
    (N'shoei-neotec-3',2,N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-2.jpg'),
    (N'shoei-neotec-3',3,N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-3.jpg'),
    (N'shoei-neotec-3',4,N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-4.jpg'),
    (N'shoei-neotec-3',5,N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-5.jpg'),
    (N'shoei-hornet-adv',1,N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-1.jpg'),
    (N'shoei-hornet-adv',2,N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-2.jpg'),
    (N'shoei-hornet-adv',3,N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-3.jpg'),
    (N'shoei-hornet-adv',4,N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-4.jpg'),
    (N'shoei-hornet-adv',5,N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-5.jpg'),
    (N'shoei-x-fifteen',1,N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-1.jpg'),
    (N'shoei-x-fifteen',2,N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-2.jpg'),
    (N'shoei-x-fifteen',3,N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-3.jpg'),
    (N'shoei-x-fifteen',4,N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-4.jpg'),
    (N'shoei-x-fifteen',5,N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-5.jpg'),
    (N'shoei-graphic-open-face',1,N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-1.jpg'),
    (N'shoei-graphic-open-face',2,N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-2.jpg'),
    (N'shoei-graphic-open-face',3,N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-3.jpg'),
    (N'shoei-graphic-open-face',4,N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-4.jpg'),
    (N'shoei-graphic-open-face',5,N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-5.jpg'),
    (N'zebra-ym-602-plain',1,N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-1.jpg'),
    (N'zebra-ym-602-plain',2,N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-2.jpg'),
    (N'zebra-ym-602-plain',3,N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-3.jpg'),
    (N'zebra-ym-602-plain',4,N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-4.jpg'),
    (N'zebra-ym-602-plain',5,N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-5.jpg'),
    (N'zebra-ym-902',1,N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-1.jpg'),
    (N'zebra-ym-902',2,N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-2.jpg'),
    (N'zebra-ym-902',3,N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-3.jpg'),
    (N'zebra-ym-902',4,N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-4.jpg'),
    (N'zebra-ym-902',5,N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-5.jpg'),
    (N'zebra-603',1,N'/Content/images/products/helmets/zebra/zebra-603-gallery-1.jpg'),
    (N'zebra-ff-855',1,N'/Content/images/products/helmets/zebra/zebra-ff-855-gallery-1.jpg'),
    (N'zebra-ff-855',2,N'/Content/images/products/helmets/zebra/zebra-ff-855-gallery-2.jpg'),
    (N'zebra-hornet-modular',1,N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-1.jpg'),
    (N'zebra-hornet-modular',2,N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-2.jpg'),
    (N'zebra-hornet-modular',3,N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-3.jpg'),
    (N'zebra-hornet-modular',4,N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-4.jpg'),
    (N'zebra-hornet-modular',5,N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-5.jpg'),
    (N'gille-ff007-kerena',4,N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-4.webp'),
    (N'gille-ff007-kerena',5,N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-5.webp'),
    (N'gille-a5009-phoenix',2,N'/Content/images/products/helmets/gille/gille-a5009-phoenix-gallery-2.webp'),
    (N'gille-a5009-phoenix',3,N'/Content/images/products/helmets/gille/gille-a5009-phoenix-gallery-3.webp'),
    (N'hnj-titan-a4001k',1,N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-1.webp'),
    (N'hnj-titan-a4001k',2,N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-2.webp'),
    (N'hnj-titan-a4001k',3,N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-3.webp'),
    (N'hnj-titan-a4001k',4,N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-4.webp');
    -- END GENERATED GALLERY ROWS

    DECLARE @Reviews TABLE (Slug NVARCHAR(220), Rating INT, Title NVARCHAR(150), Comment NVARCHAR(500));
    INSERT @Reviews VALUES
    (N'zebra-ym-602-plain',4,N'[Sample] City riding option',N'Sample review for layout preview: the modular shape and long visor look suited to city rides. Check the size chart before ordering.'),
    (N'hnj-a4-001-plain',4,N'[Sample] Color selection',N'Sample review for layout preview: several colors make it easy to compare options. Check fit and stock before buying.'),
    (N'gille-ff007-kerena',5,N'[Sample] Visor styling',N'Sample review for layout preview: the tinted visor and clean shell shape stand out in the photos.'),
    (N'agv-matte-black-full-face',4,N'[Sample] Matte finish',N'Sample review for layout preview: the matte black finish and rear profile give this helmet a restrained look.'),
    (N'shoei-neotec-3',5,N'[Sample] Touring design',N'Sample review for layout preview: the modular layout and visor arrangement look useful for touring.'),
    (N'zebra-hornet-modular',4,N'[Sample] Graphics',N'Sample review for layout preview: the graphic finishes are easy to compare in the product gallery.'),
    (N'gille-adventure-peak',4,N'[Sample] Adventure shape',N'Sample review for layout preview: the peaked shell and face shield give it a distinctive adventure style.'),
    (N'hnj-937',4,N'[Sample] Everyday modular',N'Sample review for layout preview: the modular shell shape is easy to pair with daily riding gear.'),
    (N'agv-vr46-graphic',5,N'[Sample] Race graphic',N'Sample review for layout preview: the yellow and black artwork is highly visible in the photos.'),
    (N'shoei-x-fifteen',5,N'[Sample] Graphic options',N'Sample review for layout preview: the catalog gallery shows several bold graphic options.');

    IF EXISTS (SELECT 1 FROM @Catalog c LEFT JOIN dbo.Brands b ON b.Name = c.BrandName
               LEFT JOIN dbo.Categories cat ON cat.Slug = c.CategorySlug
               WHERE b.Id IS NULL OR cat.Id IS NULL)
        THROW 50101, 'A required catalog brand or category is missing. Run the earlier catalog seed first.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT dbo.Products (CategoryId, BrandId, Name, Slug, Description, RidingStyle, BasePrice, MainImageUrl)
        SELECT cat.Id, brand.Id, c.ProductName, c.Slug, c.Description, c.RidingStyle, c.BasePrice, c.MainImageUrl
        FROM @Catalog c
        JOIN dbo.Brands brand ON brand.Name = c.BrandName
        JOIN dbo.Categories cat ON cat.Slug = c.CategorySlug
        WHERE c.MainImageUrl IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo.Products p WITH (UPDLOCK, HOLDLOCK) WHERE p.Slug = c.Slug);

        IF EXISTS (SELECT 1 FROM @Catalog c LEFT JOIN dbo.Products p ON p.Slug = c.Slug WHERE p.Id IS NULL)
            THROW 50102, 'An expected helmet is missing. Run 03_helmet_catalog_seed.sql first.', 1;

        UPDATE p
        SET BasePrice = c.BasePrice, UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Products p JOIN @Catalog c ON c.Slug = p.Slug
        WHERE p.BasePrice = 0;

        UPDATE p
        SET Description = c.Description, UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Products p JOIN @Catalog c ON c.Slug = p.Slug
        WHERE p.Description LIKE N'%supplied product image%'
           OR p.Description LIKE N'%supplied product images%'
           OR p.Description LIKE N'%supplied AGV images%'
           OR p.Description LIKE N'%supplied product image.%'
           OR p.Description LIKE N'%Color options follow supplied%'
           OR p.Description LIKE N'%Color names describe visible image variants%'
           OR p.Description LIKE N'%based on supplied%'
           OR p.Description LIKE N'Provisional product name%';

        -- Correct previously misclassified helmet types using the supplied images.
        UPDATE p SET CategoryId = cat.Id, Name = c.ProductName, RidingStyle = c.RidingStyle, UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Products p
        JOIN @Catalog c ON c.Slug = p.Slug
        JOIN dbo.Categories cat ON cat.Slug = c.CategorySlug
        WHERE p.Slug IN (N'gille-ff005-visage', N'gille-135-gts-v1', N'zebra-ym-602-plain', N'hnj-2020', N'hnj-937')
          AND (p.CategoryId <> cat.Id OR p.Name <> c.ProductName);

        INSERT dbo.ProductColors (ProductId, Color, ColorHex)
        SELECT p.Id, c.Color, c.ColorHex
        FROM @NewColors c JOIN dbo.Products p ON p.Slug = c.Slug
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ProductColors existing WITH (UPDLOCK, HOLDLOCK)
                          WHERE existing.ProductId = p.Id AND existing.Color = c.Color);

        INSERT dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive)
        SELECT pc.Id, CONCAT(UPPER(REPLACE(c.Slug,N'-',N'')),N'-',c.Token,N'-',s.Size), s.Size, 0, 1
        FROM @NewColors c
        JOIN dbo.Products p ON p.Slug = c.Slug
        JOIN dbo.ProductColors pc ON pc.ProductId = p.Id AND pc.Color = c.Color
        CROSS JOIN (VALUES (N'S'),(N'M'),(N'L'),(N'XL'),(N'XXL')) s(Size)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ProductVariants v WITH (UPDLOCK, HOLDLOCK)
                          WHERE v.ProductColorId = pc.Id AND v.Size = s.Size);

        INSERT dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint)
        SELECT v.Id, 0, 0, 3
        FROM @NewColors c
        JOIN dbo.Products p ON p.Slug = c.Slug
        JOIN dbo.ProductColors pc ON pc.ProductId = p.Id AND pc.Color = c.Color
        JOIN dbo.ProductVariants v ON v.ProductColorId = pc.Id
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Inventories i WITH (UPDLOCK, HOLDLOCK) WHERE i.VariantId = v.Id);

        INSERT dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder)
        SELECT p.Id, g.ImageUrl, CONCAT(p.Name, N' - view ', g.DisplayOrder), g.DisplayOrder
        FROM @Gallery g JOIN dbo.Products p ON p.Slug = g.Slug
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ProductGalleryImages existing WITH (UPDLOCK, HOLDLOCK)
                          WHERE existing.ProductId = p.Id AND existing.DisplayOrder = g.DisplayOrder);

        INSERT dbo.SpecificationDefinitions (SpecificationKey, DisplayName)
        SELECT d.SpecificationKey, d.DisplayName
        FROM (VALUES (N'helmet_type',N'Helmet Type'),(N'visible_finish',N'Visible Finish'),(N'visor_style',N'Visor Style')) d(SpecificationKey,DisplayName)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.SpecificationDefinitions existing WITH (UPDLOCK, HOLDLOCK)
                          WHERE existing.SpecificationKey = d.SpecificationKey);

        INSERT dbo.CategorySpecifications (CategoryId, SpecificationId, DisplayOrder, IsRequired)
        SELECT DISTINCT cat.Id, d.Id,
            CASE d.SpecificationKey WHEN N'helmet_type' THEN 10 WHEN N'visible_finish' THEN 20 ELSE 30 END, 0
        FROM @Catalog c
        JOIN dbo.Categories cat ON cat.Slug = c.CategorySlug
        CROSS JOIN dbo.SpecificationDefinitions d
        WHERE d.SpecificationKey IN (N'helmet_type',N'visible_finish',N'visor_style')
          AND NOT EXISTS (SELECT 1 FROM dbo.CategorySpecifications existing WITH (UPDLOCK, HOLDLOCK)
                          WHERE existing.CategoryId = cat.Id AND existing.SpecificationId = d.Id);

        INSERT dbo.ProductSpecificationValues (ProductId, SpecificationId, SpecificationValue)
        SELECT p.Id, d.Id, spec.SpecificationValue
        FROM @Catalog c
        JOIN dbo.Products p ON p.Slug = c.Slug
        CROSS APPLY (VALUES (N'helmet_type',c.HelmetType),(N'visible_finish',c.Finish),(N'visor_style',c.Visor)) spec(SpecificationKey,SpecificationValue)
        JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = spec.SpecificationKey
        JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId AND cs.SpecificationId = d.Id
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ProductSpecificationValues existing WITH (UPDLOCK, HOLDLOCK)
                          WHERE existing.ProductId = p.Id AND existing.SpecificationId = d.Id);

        INSERT dbo.ProductReviews (ProductId, ReviewerName, Rating, Title, Comment, IsVerifiedPurchase, IsHidden)
        SELECT p.Id, N'Sample rider', r.Rating, r.Title, r.Comment, 0, 0
        FROM @Reviews r JOIN dbo.Products p ON p.Slug = r.Slug
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ProductReviews existing WITH (UPDLOCK, HOLDLOCK)
                          WHERE existing.ProductId = p.Id AND existing.Title = r.Title AND existing.ReviewerName = N'Sample rider');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
EXEC dbo.sp_SeedCatalogContent;
GO
