/*
========================================================================================
Helmet Cartel Ordering and Management System - Complete Database Script
Schema, Active Seed Data, Functions, Views, and Active Stored Procedures
Target Database: HelmetCartelDB
Generated: 2026-10-07 18:40:55
========================================================================================
*/

USE [master];
GO

IF DB_ID(N'HelmetCartelDB') IS NULL
BEGIN
    PRINT N'Creating database HelmetCartelDB...';
    CREATE DATABASE [HelmetCartelDB];
END;
GO

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT N'Database context set to HelmetCartelDB.';
GO
-- =====================================================================================
-- SECTION 1: USER-DEFINED TABLE TYPES
-- =====================================================================================
IF NOT EXISTS (SELECT 1 FROM sys.table_types WHERE name = 'SaleLineInput' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TYPE [dbo].[SaleLineInput] AS TABLE (
        [VariantId] [int] NOT NULL,
        [Quantity] [int] NOT NULL
    );
END;
GO
-- =====================================================================================
-- SECTION 2: SCALAR FUNCTIONS
-- =====================================================================================
-- Function: fn_BaseColorFromHex
-- 1. REFINED COLOR FAMILY HELPER
CREATE   FUNCTION dbo.fn_BaseColorFromHex(@ColorHex NVARCHAR(255))
RETURNS NVARCHAR(20)
AS
BEGIN
    IF @ColorHex IS NULL OR LEN(LTRIM(RTRIM(@ColorHex))) = 0
        RETURN NULL;

    DECLARE @CleanHex NVARCHAR(255) = LTRIM(RTRIM(@ColorHex));

    DECLARE @HashIdx INT = CHARINDEX(N'#', @CleanHex);
    IF @HashIdx > 0 AND LEN(@CleanHex) >= @HashIdx + 6
    BEGIN
        SET @CleanHex = SUBSTRING(@CleanHex, @HashIdx, 7);
    END
    ELSE
    BEGIN
        RETURN N'Multi';
    END

    IF LEN(@CleanHex) <> 7 OR LEFT(@CleanHex, 1) <> N'#'
        RETURN N'Multi';

    DECLARE @Hex NVARCHAR(16) = N'0123456789ABCDEF';
    DECLARE @R INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 2, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 3, 1)), @Hex) - 1;
    DECLARE @G INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 4, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 5, 1)), @Hex) - 1;
    DECLARE @B INT = (CHARINDEX(UPPER(SUBSTRING(@CleanHex, 6, 1)), @Hex) - 1) * 16
                   + CHARINDEX(UPPER(SUBSTRING(@CleanHex, 7, 1)), @Hex) - 1;

    IF @R < 0 OR @G < 0 OR @B < 0 RETURN N'Multi';

    DECLARE @MaxChannel INT = CASE
        WHEN @R >= @G AND @R >= @B THEN @R
        WHEN @G >= @B THEN @G
        ELSE @B
    END;
    DECLARE @MinChannel INT = CASE
        WHEN @R <= @G AND @R <= @B THEN @R
        WHEN @G <= @B THEN @G
        ELSE @B
    END;
    DECLARE @Delta DECIMAL(10,4) = @MaxChannel - @MinChannel;
    DECLARE @Hue DECIMAL(10,4);

    IF @MaxChannel <= 64 RETURN N'Black';
    IF @MinChannel >= 200 RETURN N'White';
    IF @Delta <= 32 RETURN N'Grey';

    SET @Hue = CASE
        WHEN @MaxChannel = @R THEN 60.0 * (@G - @B) / @Delta
        WHEN @MaxChannel = @G THEN 60.0 * ((@B - @R) / @Delta + 2)
        ELSE 60.0 * ((@R - @G) / @Delta + 4)
    END;
    IF @Hue < 0 SET @Hue = @Hue + 360;

    IF @Hue < 15 OR @Hue >= 345 RETURN N'Red';
    IF @Hue < 45 RETURN N'Orange';
    IF @Hue < 70 RETURN N'Yellow';
    IF @Hue < 165 RETURN N'Green';
    IF @Hue < 195 RETURN N'Cyan';
    IF @Hue < 255 RETURN N'Blue';
    IF @Hue < 315 RETURN N'Purple';
    RETURN N'Pink';
END;

GO

-- Function: fn_CalculateEffectivePrice
-- 3. FUNCTION TO SECURELY CALCULATE EFFECTIVE DISCOUNTED PRICE
CREATE   FUNCTION dbo.fn_CalculateEffectivePrice
(
    @BasePrice DECIMAL(18,2),
    @PriceAdjustment DECIMAL(18,2),
    @DiscountPercentage INT,
    @DiscountType NVARCHAR(20),
    @DiscountAmount DECIMAL(18,2),
    @StartDate DATETIME2,
    @EndDate DATETIME2,
    @IsActive BIT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @GrossPrice DECIMAL(18,2) = @BasePrice + ISNULL(@PriceAdjustment, 0.00);
    IF @GrossPrice <= 0 RETURN 0.00;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();
    DECLARE @IsDiscountValid BIT = 0;

    IF ISNULL(@IsActive, 1) = 1
       AND (@StartDate IS NULL OR @StartDate <= @Now)
       AND (@EndDate IS NULL OR @EndDate >= @Now)
    BEGIN
        SET @IsDiscountValid = 1;
    END;

    IF @IsDiscountValid = 0
    BEGIN
        -- Check if legacy DiscountPercentage is set without dates
        IF @DiscountPercentage > 0 AND @DiscountPercentage <= 100 AND @StartDate IS NULL AND @EndDate IS NULL
        BEGIN
            RETURN CONVERT(DECIMAL(18,2), @GrossPrice * (1.0 - (@DiscountPercentage / 100.0)));
        END;
        RETURN @GrossPrice;
    END;

    DECLARE @Effective DECIMAL(18,2) = @GrossPrice;

    IF @DiscountType = N'FIXED_AMOUNT' AND @DiscountAmount > 0
    BEGIN
        SET @Effective = @GrossPrice - @DiscountAmount;
    END
    ELSE IF @DiscountPercentage > 0
    BEGIN
        SET @Effective = @GrossPrice * (1.0 - (@DiscountPercentage / 100.0));
    END;

    IF @Effective < 0 SET @Effective = 0.00;
    RETURN CONVERT(DECIMAL(18,2), @Effective);
END;

GO

-- =====================================================================================
-- SECTION 3: TABLES, PRIMARY KEYS, INDEXES, AND CONSTRAINTS
-- =====================================================================================
-- Table: [dbo].[Roles]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Roles](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Description] [nvarchar](255) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Roles] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[Users]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Users](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RoleId] [int] NOT NULL,
	[Email] [nvarchar](256) NOT NULL,
	[PasswordHash] [nvarchar](512) NOT NULL,
	[Salt] [nvarchar](128) NOT NULL,
	[PhoneNumber] [nvarchar](30) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[FirstName] [nvarchar](100) NOT NULL,
	[LastName] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Users_RoleId] ON [dbo].[Users]
(
	[RoleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

SET ANSI_PADDING ON
GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_Users_PhoneNumber] ON [dbo].[Users]
(
	[PhoneNumber] ASC
)
WHERE ([PhoneNumber] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Users] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[Users] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[UserAddresses]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[UserAddresses](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[AddressLabel] [nvarchar](50) NOT NULL,
	[RecipientName] [nvarchar](150) NULL,
	[PhoneNumber] [nvarchar](50) NULL,
	[StreetAddress] [nvarchar](255) NOT NULL,
	[Barangay] [nvarchar](100) NOT NULL,
	[City] [nvarchar](100) NOT NULL,
	[Province] [nvarchar](100) NOT NULL,
	[PostalCode] [nvarchar](20) NOT NULL,
	[DeliveryLandmark] [nvarchar](255) NULL,
	[IsDefault] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_UserAddresses] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_UserAddresses_UserId_IsDefault] ON [dbo].[UserAddresses]
(
	[UserId] ASC,
	[IsDefault] DESC,
	[Id] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_UserAddresses_UserDefault] ON [dbo].[UserAddresses]
(
	[UserId] ASC
)
WHERE ([IsDefault]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[UserAddresses] ADD  CONSTRAINT [DF_UserAddresses_AddressLabel]  DEFAULT (N'Home') FOR [AddressLabel]
GO

ALTER TABLE [dbo].[UserAddresses] ADD  CONSTRAINT [DF_UserAddresses_IsDefault]  DEFAULT ((0)) FOR [IsDefault]
GO

ALTER TABLE [dbo].[UserAddresses] ADD  CONSTRAINT [DF_UserAddresses_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[UserAddresses] ADD  CONSTRAINT [DF_UserAddresses_UpdatedAt]  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO

-- Table: [dbo].[Categories]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Categories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Slug] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](500) NULL,
	[DisplayOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Slug] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Categories] ADD  DEFAULT ((0)) FOR [DisplayOrder]
GO

ALTER TABLE [dbo].[Categories] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[Categories] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[Brands]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Brands](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[LogoUrl] [nvarchar](255) NULL,
	[Website] [nvarchar](255) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Brands] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[Brands] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[SpecificationDefinitions]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SpecificationDefinitions](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[SpecificationKey] [nvarchar](80) NOT NULL,
	[DisplayName] [nvarchar](120) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
 CONSTRAINT [PK_SpecificationDefinitions] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SpecificationDefinitions_Key] UNIQUE NONCLUSTERED 
(
	[SpecificationKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[SpecificationDefinitions] ADD  CONSTRAINT [DF_SpecificationDefinitions_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[SpecificationDefinitions] ADD  CONSTRAINT [DF_SpecificationDefinitions_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[CategorySpecifications]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[CategorySpecifications](
	[CategoryId] [int] NOT NULL,
	[SpecificationId] [int] NOT NULL,
	[DisplayOrder] [int] NOT NULL,
	[IsRequired] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_CategorySpecifications] PRIMARY KEY CLUSTERED 
(
	[CategoryId] ASC,
	[SpecificationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[CategorySpecifications] ADD  CONSTRAINT [DF_CategorySpecifications_DisplayOrder]  DEFAULT ((0)) FOR [DisplayOrder]
GO

ALTER TABLE [dbo].[CategorySpecifications] ADD  CONSTRAINT [DF_CategorySpecifications_IsRequired]  DEFAULT ((0)) FOR [IsRequired]
GO

ALTER TABLE [dbo].[CategorySpecifications] ADD  CONSTRAINT [DF_CategorySpecifications_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[CategorySpecifications]  WITH CHECK ADD  CONSTRAINT [CK_CategorySpecifications_DisplayOrder] CHECK  (([DisplayOrder]>=(0)))
GO

ALTER TABLE [dbo].[CategorySpecifications] CHECK CONSTRAINT [CK_CategorySpecifications_DisplayOrder]
GO

-- Table: [dbo].[Products]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Products](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CategoryId] [int] NOT NULL,
	[BrandId] [int] NOT NULL,
	[Name] [nvarchar](200) NOT NULL,
	[Slug] [nvarchar](220) NOT NULL,
	[Description] [nvarchar](max) NULL,
	[BasePrice] [decimal](18, 2) NOT NULL,
	[DiscountPercentage] [int] NOT NULL,
	[MainImageUrl] [nvarchar](500) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[DiscountType] [nvarchar](20) NOT NULL,
	[DiscountAmount] [decimal](18, 2) NOT NULL,
	[DiscountStartDate] [datetime2](7) NULL,
	[DiscountEndDate] [datetime2](7) NULL,
	[DiscountIsActive] [bit] NOT NULL,
	[PublicationStatus] [nvarchar](20) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Slug] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Products_BrandId] ON [dbo].[Products]
(
	[BrandId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Products_CategoryId] ON [dbo].[Products]
(
	[CategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Products] ADD  DEFAULT ((0)) FOR [DiscountPercentage]
GO

ALTER TABLE [dbo].[Products] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[Products] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[Products] ADD  CONSTRAINT [DF_Products_DiscountType]  DEFAULT (N'PERCENTAGE') FOR [DiscountType]
GO

ALTER TABLE [dbo].[Products] ADD  CONSTRAINT [DF_Products_DiscountAmount]  DEFAULT ((0.00)) FOR [DiscountAmount]
GO

ALTER TABLE [dbo].[Products] ADD  CONSTRAINT [DF_Products_DiscountIsActive]  DEFAULT ((1)) FOR [DiscountIsActive]
GO

ALTER TABLE [dbo].[Products] ADD  CONSTRAINT [DF_Products_PublicationStatus]  DEFAULT (N'Draft') FOR [PublicationStatus]
GO

ALTER TABLE [dbo].[Products]  WITH CHECK ADD CHECK  (([BasePrice]>=(0)))
GO

ALTER TABLE [dbo].[Products]  WITH CHECK ADD CHECK  (([DiscountPercentage]>=(0) AND [DiscountPercentage]<=(100)))
GO

ALTER TABLE [dbo].[Products]  WITH CHECK ADD  CONSTRAINT [CK_Products_PublicationStatus] CHECK  (([PublicationStatus]=N'Archived' OR [PublicationStatus]=N'Published' OR [PublicationStatus]=N'Draft'))
GO

ALTER TABLE [dbo].[Products] CHECK CONSTRAINT [CK_Products_PublicationStatus]
GO

-- Table: [dbo].[ProductColors]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ProductColors](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ProductId] [int] NOT NULL,
	[Color] [nvarchar](50) NOT NULL,
	[ColorHex] [nvarchar](255) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[ColorType] [nvarchar](20) NOT NULL,
	[GradientAngle] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ProductColors_Product_Color] UNIQUE NONCLUSTERED 
(
	[ProductId] ASC,
	[Color] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ProductColors] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[ProductColors] ADD  CONSTRAINT [DF_ProductColors_ColorType]  DEFAULT (N'SOLID') FOR [ColorType]
GO

ALTER TABLE [dbo].[ProductColors]  WITH CHECK ADD  CONSTRAINT [CK_ProductColors_ColorType] CHECK  (([ColorType]=N'LINEAR_GRADIENT' OR [ColorType]=N'SOLID'))
GO

ALTER TABLE [dbo].[ProductColors] CHECK CONSTRAINT [CK_ProductColors_ColorType]
GO

ALTER TABLE [dbo].[ProductColors]  WITH CHECK ADD  CONSTRAINT [CK_ProductColors_GradientAngle] CHECK  (([GradientAngle] IS NULL OR [GradientAngle]>=(0) AND [GradientAngle]<=(359)))
GO

ALTER TABLE [dbo].[ProductColors] CHECK CONSTRAINT [CK_ProductColors_GradientAngle]
GO

-- Table: [dbo].[ProductColorStops]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ProductColorStops](
	[ProductColorId] [int] NOT NULL,
	[StopOrder] [tinyint] NOT NULL,
	[ColorHex] [nchar](7) NOT NULL,
 CONSTRAINT [PK_ProductColorStops] PRIMARY KEY CLUSTERED 
(
	[ProductColorId] ASC,
	[StopOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ProductColorStops]  WITH CHECK ADD CHECK  (([StopOrder]>=(1) AND [StopOrder]<=(4)))
GO

ALTER TABLE [dbo].[ProductColorStops]  WITH CHECK ADD  CONSTRAINT [CK_ProductColorStops_Hex] CHECK  (([ColorHex] like N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'))
GO

ALTER TABLE [dbo].[ProductColorStops] CHECK CONSTRAINT [CK_ProductColorStops_Hex]
GO

-- Table: [dbo].[ProductVariants]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ProductVariants](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[SKU] [nvarchar](100) NOT NULL,
	[Size] [nvarchar](20) NOT NULL,
	[PriceAdjustment] [decimal](18, 2) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[ProductColorId] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[SKU] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ProductVariants_Color_Size] UNIQUE NONCLUSTERED 
(
	[ProductColorId] ASC,
	[Size] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ProductVariants] ADD  DEFAULT ((0.00)) FOR [PriceAdjustment]
GO

ALTER TABLE [dbo].[ProductVariants] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[ProductVariants] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[ProductGalleryImages]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ProductGalleryImages](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ProductId] [int] NOT NULL,
	[ImageUrl] [nvarchar](500) NOT NULL,
	[AltText] [nvarchar](200) NULL,
	[DisplayOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
 CONSTRAINT [PK_ProductGalleryImages] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ProductGalleryImages_Product_DisplayOrder] UNIQUE NONCLUSTERED 
(
	[ProductId] ASC,
	[DisplayOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ProductGalleryImages] ADD  CONSTRAINT [DF_ProductGalleryImages_IsActive]  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[ProductGalleryImages] ADD  CONSTRAINT [DF_ProductGalleryImages_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[ProductGalleryImages]  WITH CHECK ADD  CONSTRAINT [CK_ProductGalleryImages_DisplayOrder] CHECK  (([DisplayOrder]>=(1)))
GO

ALTER TABLE [dbo].[ProductGalleryImages] CHECK CONSTRAINT [CK_ProductGalleryImages_DisplayOrder]
GO

-- Table: [dbo].[ProductSpecificationValues]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ProductSpecificationValues](
	[ProductId] [int] NOT NULL,
	[SpecificationId] [int] NOT NULL,
	[SpecificationValue] [nvarchar](1000) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
 CONSTRAINT [PK_ProductSpecificationValues] PRIMARY KEY CLUSTERED 
(
	[ProductId] ASC,
	[SpecificationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_ProductSpecificationValues_SpecificationId] ON [dbo].[ProductSpecificationValues]
(
	[SpecificationId] ASC,
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ProductSpecificationValues] ADD  CONSTRAINT [DF_ProductSpecificationValues_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[Inventories]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Inventories](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VariantId] [int] NOT NULL,
	[CurrentStock] [int] NOT NULL,
	[ReservedStock] [int] NOT NULL,
	[ReorderPoint] [int] NOT NULL,
	[LastRestockedAt] [datetime2](7) NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
	[IsLowStock]  AS (case when ([CurrentStock]-[ReservedStock])<=[ReorderPoint] then (1) else (0) end) PERSISTED NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[VariantId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO

CREATE NONCLUSTERED INDEX [IX_Inventories_IsLowStock] ON [dbo].[Inventories]
(
	[IsLowStock] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Inventories] ADD  DEFAULT ((0)) FOR [ReservedStock]
GO

ALTER TABLE [dbo].[Inventories] ADD  DEFAULT ((3)) FOR [ReorderPoint]
GO

ALTER TABLE [dbo].[Inventories] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO

ALTER TABLE [dbo].[Inventories]  WITH CHECK ADD CHECK  (([CurrentStock]>=(0)))
GO

ALTER TABLE [dbo].[Inventories]  WITH CHECK ADD CHECK  (([ReorderPoint]>=(0)))
GO

ALTER TABLE [dbo].[Inventories]  WITH CHECK ADD CHECK  (([ReservedStock]>=(0)))
GO

ALTER TABLE [dbo].[Inventories]  WITH CHECK ADD  CONSTRAINT [CK_Inventories_ReservedWithinStock] CHECK  (([ReservedStock]<=[CurrentStock]))
GO

ALTER TABLE [dbo].[Inventories] CHECK CONSTRAINT [CK_Inventories_ReservedWithinStock]
GO

-- Table: [dbo].[StockAuditLogs]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[StockAuditLogs](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[VariantId] [int] NOT NULL,
	[UserId] [int] NULL,
	[ChangeType] [nvarchar](50) NOT NULL,
	[PreviousStock] [int] NOT NULL,
	[QuantityChanged] [int] NOT NULL,
	[ReferenceNumber] [nvarchar](100) NULL,
	[Notes] [nvarchar](500) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[NewStock]  AS ([PreviousStock]+[QuantityChanged]) PERSISTED,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_StockAuditLogs_VariantId_CreatedAt] ON [dbo].[StockAuditLogs]
(
	[VariantId] ASC,
	[CreatedAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[StockAuditLogs] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[StockAuditLogs]  WITH CHECK ADD  CONSTRAINT [CK_StockAuditLogs_ChangeType] CHECK  (([ChangeType]=N'RETURN' OR [ChangeType]=N'ADJUSTMENT' OR [ChangeType]=N'RESTOCK' OR [ChangeType]=N'INSTORE_SALE' OR [ChangeType]=N'ONLINE_SALE'))
GO

ALTER TABLE [dbo].[StockAuditLogs] CHECK CONSTRAINT [CK_StockAuditLogs_ChangeType]
GO

ALTER TABLE [dbo].[StockAuditLogs]  WITH CHECK ADD  CONSTRAINT [CK_StockAuditLogs_StockNonnegative] CHECK  (([PreviousStock]>=(0) AND [NewStock]>=(0)))
GO

ALTER TABLE [dbo].[StockAuditLogs] CHECK CONSTRAINT [CK_StockAuditLogs_StockNonnegative]
GO

-- Table: [dbo].[RestockAlerts]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[RestockAlerts](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[InventoryId] [int] NOT NULL,
	[Severity] [nvarchar](20) NOT NULL,
	[IsDismissed] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[DismissedAt] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_RestockAlerts_OpenInventory] ON [dbo].[RestockAlerts]
(
	[InventoryId] ASC
)
WHERE ([IsDismissed]=(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[RestockAlerts] ADD  DEFAULT ((0)) FOR [IsDismissed]
GO

ALTER TABLE [dbo].[RestockAlerts] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[RestockAlerts]  WITH CHECK ADD  CONSTRAINT [CK_RestockAlerts_Severity] CHECK  (([Severity]=N'CRITICAL_ZERO' OR [Severity]=N'LOW_STOCK'))
GO

ALTER TABLE [dbo].[RestockAlerts] CHECK CONSTRAINT [CK_RestockAlerts_Severity]
GO

-- Table: [dbo].[Vouchers]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Vouchers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Code] [nvarchar](30) NOT NULL,
	[DiscountType] [nvarchar](20) NOT NULL,
	[DiscountValue] [decimal](18, 2) NOT NULL,
	[MinimumSpend] [decimal](18, 2) NOT NULL,
	[ExpiresAt] [datetime2](7) NULL,
	[UsageLimit] [int] NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Vouchers] ADD  DEFAULT ((0)) FOR [MinimumSpend]
GO

ALTER TABLE [dbo].[Vouchers] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[Vouchers] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[Vouchers]  WITH CHECK ADD  CONSTRAINT [CK_Vouchers_Code] CHECK  ((len([Code])>=(3) AND len([Code])<=(30) AND NOT ([Code]) collate Latin1_General_100_BIN2 like N'%[^A-Z0-9-]%'))
GO

ALTER TABLE [dbo].[Vouchers] CHECK CONSTRAINT [CK_Vouchers_Code]
GO

ALTER TABLE [dbo].[Vouchers]  WITH CHECK ADD  CONSTRAINT [CK_Vouchers_Discount] CHECK  (([DiscountType]=N'FREE_SHIPPING' AND [DiscountValue]>=(0) OR [DiscountValue]>(0) AND ([DiscountType]=N'FIXED_AMOUNT' OR [DiscountType]=N'PERCENTAGE' AND [DiscountValue]<=(100))))
GO

ALTER TABLE [dbo].[Vouchers] CHECK CONSTRAINT [CK_Vouchers_Discount]
GO

ALTER TABLE [dbo].[Vouchers]  WITH CHECK ADD  CONSTRAINT [CK_Vouchers_Limits] CHECK  (([MinimumSpend]>=(0) AND ([UsageLimit] IS NULL OR [UsageLimit]>(0))))
GO

ALTER TABLE [dbo].[Vouchers] CHECK CONSTRAINT [CK_Vouchers_Limits]
GO

-- Table: [dbo].[Orders]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Orders](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrderNumber] [nvarchar](50) NOT NULL,
	[UserId] [int] NULL,
	[CustomerName] [nvarchar](100) NOT NULL,
	[CustomerEmail] [nvarchar](256) NOT NULL,
	[CustomerPhone] [nvarchar](30) NOT NULL,
	[OrderSource] [nvarchar](30) NOT NULL,
	[Status] [nvarchar](50) NOT NULL,
	[Subtotal] [decimal](18, 2) NOT NULL,
	[DiscountAmount] [decimal](18, 2) NOT NULL,
	[Notes] [nvarchar](500) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
	[ShippingMethod] [nvarchar](50) NOT NULL,
	[ShippingFee] [decimal](18, 2) NOT NULL,
	[ShippingRegion] [nvarchar](100) NULL,
	[ShippingAddress] [nvarchar](300) NULL,
	[ShippingBarangay] [nvarchar](100) NULL,
	[ShippingCity] [nvarchar](100) NULL,
	[ShippingProvince] [nvarchar](100) NULL,
	[ShippingPostalCode] [nvarchar](20) NULL,
	[Courier] [nvarchar](50) NULL,
	[TrackingNumber] [nvarchar](100) NULL,
	[DeliveryNotes] [nvarchar](500) NULL,
	[TotalAmount]  AS (CONVERT([decimal](18,2),([Subtotal]-[DiscountAmount])+[ShippingFee])) PERSISTED,
	[VoucherCode] [nvarchar](30) NULL,
	[CashTendered] [decimal](18, 2) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[OrderNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Orders_CreatedAt] ON [dbo].[Orders]
(
	[CreatedAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

SET ANSI_PADDING ON
GO

CREATE NONCLUSTERED INDEX [IX_Orders_Status] ON [dbo].[Orders]
(
	[Status] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Orders_UserId] ON [dbo].[Orders]
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Orders] ADD  DEFAULT ((0.00)) FOR [DiscountAmount]
GO

ALTER TABLE [dbo].[Orders] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[Orders] ADD  CONSTRAINT [DF_Orders_ShippingMethod]  DEFAULT ('Pickup') FOR [ShippingMethod]
GO

ALTER TABLE [dbo].[Orders] ADD  CONSTRAINT [DF_Orders_ShippingFee]  DEFAULT ((0.00)) FOR [ShippingFee]
GO

ALTER TABLE [dbo].[Orders]  WITH CHECK ADD CHECK  (([DiscountAmount]>=(0)))
GO

ALTER TABLE [dbo].[Orders]  WITH CHECK ADD CHECK  (([Subtotal]>=(0)))
GO

ALTER TABLE [dbo].[Orders]  WITH CHECK ADD  CONSTRAINT [CK_Orders_Amounts] CHECK  (([DiscountAmount]<=[Subtotal]))
GO

ALTER TABLE [dbo].[Orders] CHECK CONSTRAINT [CK_Orders_Amounts]
GO

ALTER TABLE [dbo].[Orders]  WITH CHECK ADD  CONSTRAINT [CK_Orders_Source] CHECK  (([OrderSource]=N'INSTORE_POS' OR [OrderSource]=N'ONLINE'))
GO

ALTER TABLE [dbo].[Orders] CHECK CONSTRAINT [CK_Orders_Source]
GO

ALTER TABLE [dbo].[Orders]  WITH CHECK ADD  CONSTRAINT [CK_Orders_Status] CHECK  (([Status]=N'Cancelled' OR [Status]=N'Completed' OR [Status]=N'Delivered' OR [Status]=N'Shipped' OR [Status]=N'ReadyForPickup' OR [Status]=N'Processing' OR [Status]=N'PendingPayment'))
GO

ALTER TABLE [dbo].[Orders] CHECK CONSTRAINT [CK_Orders_Status]
GO

-- Table: [dbo].[OrderItems]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[OrderItems](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrderId] [int] NOT NULL,
	[VariantId] [int] NOT NULL,
	[Quantity] [int] NOT NULL,
	[UnitPrice] [decimal](18, 2) NOT NULL,
	[TotalPrice]  AS (CONVERT([decimal](18,2),[Quantity]*[UnitPrice])) PERSISTED,
	[ProductName] [nvarchar](200) NULL,
	[SKU] [nvarchar](100) NULL,
	[ColorName] [nvarchar](100) NULL,
	[Size] [nvarchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_OrderItems_OrderId] ON [dbo].[OrderItems]
(
	[OrderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_OrderItems_VariantId_OrderId] ON [dbo].[OrderItems]
(
	[VariantId] ASC,
	[OrderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[OrderItems]  WITH CHECK ADD CHECK  (([Quantity]>(0)))
GO

ALTER TABLE [dbo].[OrderItems]  WITH CHECK ADD CHECK  (([UnitPrice]>=(0)))
GO

-- Table: [dbo].[Payments]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Payments](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[OrderId] [int] NOT NULL,
	[PaymentGateway] [nvarchar](50) NOT NULL,
	[GatewayReference] [nvarchar](100) NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[Status] [nvarchar](50) NOT NULL,
	[PaidAt] [datetime2](7) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Payments_OrderId] ON [dbo].[Payments]
(
	[OrderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

SET ANSI_PADDING ON
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_Payments_GatewayReference] ON [dbo].[Payments]
(
	[PaymentGateway] ASC,
	[GatewayReference] ASC
)
WHERE ([GatewayReference] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Payments] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[Payments]  WITH CHECK ADD CHECK  (([Amount]>=(0)))
GO

ALTER TABLE [dbo].[Payments]  WITH CHECK ADD  CONSTRAINT [CK_Payments_Gateway] CHECK  (([PaymentGateway]=N'CashOnDelivery' OR [PaymentGateway]=N'Card_POS' OR [PaymentGateway]=N'Cash' OR [PaymentGateway]=N'HitPay'))
GO

ALTER TABLE [dbo].[Payments] CHECK CONSTRAINT [CK_Payments_Gateway]
GO

ALTER TABLE [dbo].[Payments]  WITH CHECK ADD  CONSTRAINT [CK_Payments_Status] CHECK  (([Status]=N'Cancelled' OR [Status]=N'Refunded' OR [Status]=N'Failed' OR [Status]=N'Completed' OR [Status]=N'Pending'))
GO

ALTER TABLE [dbo].[Payments] CHECK CONSTRAINT [CK_Payments_Status]
GO

-- Table: [dbo].[ReturnRequests]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ReturnRequests](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[RmaNumber] [nvarchar](30) NOT NULL,
	[OrderId] [int] NOT NULL,
	[OrderItemId] [int] NOT NULL,
	[UserId] [int] NULL,
	[RequestType] [nvarchar](20) NOT NULL,
	[Reason] [nvarchar](50) NOT NULL,
	[ExchangeVariantId] [int] NULL,
	[CustomerNotes] [nvarchar](1000) NULL,
	[Status] [nvarchar](30) NOT NULL,
	[ResolutionType] [nvarchar](30) NULL,
	[RefundAmount] [decimal](18, 2) NULL,
	[Restocked] [bit] NOT NULL,
	[AdminNotes] [nvarchar](1000) NULL,
	[ProcessedBy] [int] NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[RmaNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_ReturnRequests_CreatedAt] ON [dbo].[ReturnRequests]
(
	[CreatedAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_ReturnRequests_OrderId] ON [dbo].[ReturnRequests]
(
	[OrderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

SET ANSI_PADDING ON
GO

CREATE NONCLUSTERED INDEX [IX_ReturnRequests_Status] ON [dbo].[ReturnRequests]
(
	[Status] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_ReturnRequests_UserId] ON [dbo].[ReturnRequests]
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_ReturnRequests_ActiveItem] ON [dbo].[ReturnRequests]
(
	[OrderItemId] ASC
)
WHERE ([Status]<>N'Rejected' AND [Status]<>N'Cancelled')
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ReturnRequests] ADD  DEFAULT (N'Pending') FOR [Status]
GO

ALTER TABLE [dbo].[ReturnRequests] ADD  DEFAULT ((0)) FOR [Restocked]
GO

ALTER TABLE [dbo].[ReturnRequests] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[ReturnRequests] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO

ALTER TABLE [dbo].[ReturnRequests]  WITH CHECK ADD  CONSTRAINT [CK_ReturnRequests_RequestType] CHECK  (([RequestType]=N'EXCHANGE' OR [RequestType]=N'RETURN'))
GO

ALTER TABLE [dbo].[ReturnRequests] CHECK CONSTRAINT [CK_ReturnRequests_RequestType]
GO

ALTER TABLE [dbo].[ReturnRequests]  WITH CHECK ADD  CONSTRAINT [CK_ReturnRequests_Status] CHECK  (([Status]=N'Cancelled' OR [Status]=N'Completed' OR [Status]=N'Received' OR [Status]=N'Rejected' OR [Status]=N'Approved' OR [Status]=N'Pending'))
GO

ALTER TABLE [dbo].[ReturnRequests] CHECK CONSTRAINT [CK_ReturnRequests_Status]
GO

-- Table: [dbo].[VoucherRedemptions]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[VoucherRedemptions](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[VoucherId] [int] NOT NULL,
	[OrderId] [int] NOT NULL,
	[DiscountAmount] [decimal](18, 2) NOT NULL,
	[ReleasedAt] [datetime2](7) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[OrderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_VoucherRedemptions_Usage] ON [dbo].[VoucherRedemptions]
(
	[VoucherId] ASC,
	[ReleasedAt] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[VoucherRedemptions] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[VoucherRedemptions]  WITH CHECK ADD CHECK  (([DiscountAmount]>=(0)))
GO

-- Table: [dbo].[ProductReviews]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ProductReviews](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ProductId] [int] NOT NULL,
	[UserId] [int] NULL,
	[OrderId] [int] NULL,
	[ReviewerName] [nvarchar](100) NOT NULL,
	[Rating] [int] NOT NULL,
	[Title] [nvarchar](150) NULL,
	[Comment] [nvarchar](max) NOT NULL,
	[IsVerifiedPurchase] [bit] NOT NULL,
	[IsHidden] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_ProductReviews_ProductId_CreatedAt] ON [dbo].[ProductReviews]
(
	[ProductId] ASC,
	[CreatedAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ProductReviews] ADD  DEFAULT ((0)) FOR [IsVerifiedPurchase]
GO

ALTER TABLE [dbo].[ProductReviews] ADD  DEFAULT ((0)) FOR [IsHidden]
GO

ALTER TABLE [dbo].[ProductReviews] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[ProductReviews]  WITH CHECK ADD CHECK  (([Rating]>=(1) AND [Rating]<=(5)))
GO

ALTER TABLE [dbo].[ProductReviews]  WITH CHECK ADD  CONSTRAINT [CK_ProductReviews_VerifiedLink] CHECK  (([IsVerifiedPurchase]=(0) OR [OrderId] IS NOT NULL))
GO

ALTER TABLE [dbo].[ProductReviews] CHECK CONSTRAINT [CK_ProductReviews_VerifiedLink]
GO

-- Table: [dbo].[ReviewReports]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ReviewReports](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ReviewId] [int] NOT NULL,
	[UserId] [int] NULL,
	[IpAddress] [nvarchar](45) NULL,
	[Reason] [nvarchar](50) NOT NULL,
	[Notes] [nvarchar](255) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_ReviewReports_ReviewId] ON [dbo].[ReviewReports]
(
	[ReviewId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_ReviewReports_Review_User] ON [dbo].[ReviewReports]
(
	[ReviewId] ASC,
	[UserId] ASC
)
WHERE ([UserId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ReviewReports] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[ReviewReports]  WITH CHECK ADD  CONSTRAINT [CK_ReviewReports_Reason] CHECK  (([Reason]=N'FAKE' OR [Reason]=N'IRRELEVANT' OR [Reason]=N'OFFENSIVE' OR [Reason]=N'SPAM'))
GO

ALTER TABLE [dbo].[ReviewReports] CHECK CONSTRAINT [CK_ReviewReports_Reason]
GO

-- Table: [dbo].[CartItems]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[CartItems](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[VariantId] [int] NOT NULL,
	[Quantity] [int] NOT NULL,
	[IsSelected] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_CartItems_UserVariant] UNIQUE NONCLUSTERED 
(
	[UserId] ASC,
	[VariantId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[CartItems] ADD  DEFAULT ((1)) FOR [IsSelected]
GO

ALTER TABLE [dbo].[CartItems] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[CartItems]  WITH CHECK ADD CHECK  (([Quantity]>=(1) AND [Quantity]<=(9999)))
GO

-- Table: [dbo].[Favorites]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Favorites](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[ProductId] [int] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Favorites_UserProduct] UNIQUE NONCLUSTERED 
(
	[UserId] ASC,
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Favorites] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[Faqs]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Faqs](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ProductId] [int] NULL,
	[Question] [nvarchar](300) NOT NULL,
	[Answer] [nvarchar](max) NOT NULL,
	[DisplayOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Faqs_DisplayOrder] ON [dbo].[Faqs]
(
	[DisplayOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Faqs_ProductId] ON [dbo].[Faqs]
(
	[ProductId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Faqs] ADD  DEFAULT ((0)) FOR [DisplayOrder]
GO

ALTER TABLE [dbo].[Faqs] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[Faqs] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

-- Table: [dbo].[HitPayWebhookLogs]
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[HitPayWebhookLogs](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[HitPayPaymentId] [nvarchar](100) NULL,
	[ReferenceNumber] [nvarchar](100) NULL,
	[RawPayload] [nvarchar](max) NOT NULL,
	[SignatureReceived] [nvarchar](256) NULL,
	[IsSignatureValid] [bit] NOT NULL,
	[ProcessingStatus] [nvarchar](50) NOT NULL,
	[ErrorMessage] [nvarchar](1000) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

SET ANSI_PADDING ON
GO

CREATE NONCLUSTERED INDEX [IX_HitPayWebhookLogs_ReferenceNumber] ON [dbo].[HitPayWebhookLogs]
(
	[ReferenceNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

ALTER TABLE [dbo].[HitPayWebhookLogs] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[HitPayWebhookLogs]  WITH CHECK ADD  CONSTRAINT [CK_HitPayWebhookLogs_ProcessingStatus] CHECK  (([ProcessingStatus]=N'Duplicate' OR [ProcessingStatus]=N'Rejected' OR [ProcessingStatus]=N'Processed'))
GO

ALTER TABLE [dbo].[HitPayWebhookLogs] CHECK CONSTRAINT [CK_HitPayWebhookLogs_ProcessingStatus]
GO

-- =====================================================================================
-- SECTION 4: ACTIVE APPLICATION SEED DATA
-- =====================================================================================
-- Data: [dbo].[Roles] (3 rows)
SET IDENTITY_INSERT dbo.[Roles] ON;
INSERT INTO dbo.[Roles] ([Id], [Name], [Description], [CreatedAt]) VALUES
  (1, N'Admin', N'Full administrative and reporting access', N'2026-09-27 02:59:06.4211106'),
  (2, N'Staff', N'Inventory operations, order fulfillment, and walk-in sales', N'2026-09-27 02:59:06.4211106'),
  (3, N'Customer', N'Online storefront registered shopper', N'2026-09-27 02:59:06.4211106');
SET IDENTITY_INSERT dbo.[Roles] OFF;
GO

-- Data: [dbo].[Users] (8 rows)
SET IDENTITY_INSERT dbo.[Users] ON;
INSERT INTO dbo.[Users] ([Id], [RoleId], [Email], [PasswordHash], [Salt], [PhoneNumber], [IsActive], [CreatedAt], [UpdatedAt], [FirstName], [LastName]) VALUES
  (1, 1, N'admin@helmetcartel.com', N'5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'c2FsdF9zZWVkXzEyMw==', N'+639171112222', 1, N'2026-09-27 02:59:06.4211106', NULL, N'Helmet', N'Cartel Admin'),
  (2, 2, N'staff@helmetcartel.com', N'5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'c2FsdF9zZWVkXzEyMw==', N'+639173334444', 1, N'2026-09-27 02:59:06.4211106', N'2026-09-30 10:15:08.6558637', N'Store', N'Staff User'),
  (3, 3, N'juan@rider.com', N'5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', N'c2FsdF9zZWVkXzEyMw==', N'+639175556666', 1, N'2026-09-27 02:59:06.4211106', N'2026-09-30 10:17:42.4202324', N'Juan', N'Dela Cruz'),
  (4, 1, N'marckevindelmundo@gmail.com', N'bca87663c89eab1768856eff03aa4c38794cb695ceed03cd0b89e3bb5f721656', N'98f6adc0daa7ced5885bc97d669b0969', N'+639155473200', 1, N'2026-09-28 13:05:42.3915260', N'2026-10-04 09:57:07.6757743', N'Marc kevin', N'Del Mundo'),
  (5, 2, N'staffmember@helmetcartel.com', N'bc9268176ad66ba7674c42d97bbbf75421b464822d9ac17aad75dcab1a866423', N'c63fbef5af4a4b2be0263a8c690e73b8', N'09911111111', 1, N'2026-09-30 08:18:02.0909690', N'2026-10-07 09:03:49.1653836', N'Staff', N'User'),
  (6, 3, N'kevs@gmail.com', N'774d3724ab4736440cc7eb0fc385a91fcec925b0a8c6d7f094a5016fdf8ddb81', N'f4b1f2669540bba6ef3cfb18c7ff12f2', N'09949500374', 1, N'2026-10-02 03:29:42.8255926', N'2026-10-07 09:22:06.9818562', N'kevss', N'kevs'),
  (12, 3, N'picardochristopherjohnoleo1@gmail.com', N'1bcf52a47f233f61b83ee28af631ee277904cf39bf8072a17bd4a5e0448c00f0', N'8392308da6037fc09c24e5433f7aa6d7', N'+639694607854', 1, N'2026-10-04 08:26:05.8674957', N'2026-10-04 08:26:47.9548883', N'Christopher', N'Picardo'),
  (13, 2, N'staff@gmail.com', N'3ddb6f2e7ad4a46f2fb203dae899952b78e3c1764fcf65fba6119ae4601ead51', N'dfa57c4161a93fca12ab6464fe712988', N'+639170009999', 1, N'2026-10-07 09:03:49.1663830', N'2026-10-07 09:03:49.1663830', N'Staff', N'Member');
SET IDENTITY_INSERT dbo.[Users] OFF;
GO

-- Data: [dbo].[UserAddresses] (2 rows)
SET IDENTITY_INSERT dbo.[UserAddresses] ON;
INSERT INTO dbo.[UserAddresses] ([Id], [UserId], [AddressLabel], [RecipientName], [PhoneNumber], [StreetAddress], [Barangay], [City], [Province], [PostalCode], [DeliveryLandmark], [IsDefault], [CreatedAt], [UpdatedAt]) VALUES
  (2, 6, N'Home', N'Marc kevin Ferolino Del Mundo', N'09949500374', N'Emerald street', N'Quezon City', N'Quezon City', N'Metro Manila', N'1123', NULL, 1, N'2026-10-02 03:30:12.7096308', N'2026-10-02 03:30:12.7096308'),
  (3, 12, N'Hh', N'Christopher John Picardo', N'+639694607854', N'2123', N'Commonwelatw', N'Quezon City', N'Metro Manila', N'1121', N'Nearss', 1, N'2026-10-04 08:36:22.3527935', N'2026-10-04 08:36:31.3935731');
SET IDENTITY_INSERT dbo.[UserAddresses] OFF;
GO

-- Data: [dbo].[Categories] (5 rows)
SET IDENTITY_INSERT dbo.[Categories] ON;
INSERT INTO dbo.[Categories] ([Id], [Name], [Slug], [Description], [DisplayOrder], [IsActive], [CreatedAt]) VALUES
  (1, N'Full Face', N'full-face', N'Maximum protection racing and street helmets with chin bar coverage.', 1, 1, N'2026-09-27 02:59:06.4221107'),
  (2, N'Modular', N'modular', N'Flip-up chin bar helmets combining full-face safety with open-face convenience.', 2, 1, N'2026-09-27 02:59:06.4221107'),
  (3, N'Open Face / Urban', N'open-face-urban', N'Retro and commuter classic helmets offering wide peripheral vision.', 3, 1, N'2026-09-27 02:59:06.4221107'),
  (4, N'Off-Road / Motocross', N'off-road-motocross', N'High-ventilation dirt and motocross helmets with extended sun visor and roost guard.', 4, 1, N'2026-09-27 02:59:06.4221107'),
  (5, N'Dual Sport / Adventure', N'dual-sport-adventure', N'Versatile hybrid helmets engineered for tarmac touring and rugged trails.', 5, 1, N'2026-09-27 02:59:06.4221107');
SET IDENTITY_INSERT dbo.[Categories] OFF;
GO

-- Data: [dbo].[Brands] (5 rows)
SET IDENTITY_INSERT dbo.[Brands] ON;
INSERT INTO dbo.[Brands] ([Id], [Name], [LogoUrl], [Website], [IsActive], [CreatedAt]) VALUES
  (1, N'Shoei', N'/Content/images/shoei.png', N'https://www.shoei-helmets.com', 1, N'2026-09-27 02:59:06.4221107'),
  (2, N'AGV', N'/Content/images/agv.png', N'https://www.agv.com', 1, N'2026-09-27 02:59:06.4221107'),
  (7, N'HNJ', N'/Content/images/hnj.png', N'https://www.hnjhelmets.com', 1, N'2026-09-27 02:59:06.4221107'),
  (8, N'Gille', N'/Content/images/gille.png', NULL, 1, N'2026-09-27 08:53:03.8273510'),
  (9, N'Zebra', N'/Content/images/zebra.png', NULL, 1, N'2026-09-27 08:53:03.8273510');
SET IDENTITY_INSERT dbo.[Brands] OFF;
GO

-- Data: [dbo].[SpecificationDefinitions] (13 rows)
SET IDENTITY_INSERT dbo.[SpecificationDefinitions] ON;
INSERT INTO dbo.[SpecificationDefinitions] ([Id], [SpecificationKey], [DisplayName], [IsActive], [CreatedAt], [UpdatedAt]) VALUES
  (1, N'helmet_type', N'Helmet Type', 1, N'2026-09-27 13:57:50.4094414', NULL),
  (2, N'visible_finish', N'Visible Finish', 1, N'2026-09-27 13:57:50.4094414', NULL),
  (3, N'visor_style', N'Visor Style', 1, N'2026-09-27 13:57:50.4094414', NULL),
  (4, N'retention_system', N'Retention System', 1, N'2026-09-30 08:48:49.5650439', NULL),
  (5, N'safety_certifications', N'Safety Certifications', 1, N'2026-09-30 08:48:49.5650439', NULL),
  (6, N'shell_material', N'Shell Material', 1, N'2026-09-30 08:48:49.5650439', NULL),
  (7, N'weight', N'Weight', 1, N'2026-09-30 08:48:49.5650439', NULL),
  (8, N'custom_pinlock', N'Custom Pinlock', 1, N'2026-10-03 06:40:29.6248093', NULL),
  (9, N'save_verification', N'Save verification', 1, N'2026-10-03 08:34:00.8463033', NULL),
  (11, N'ventilation', N'Ventilation', 1, N'2026-10-04 07:15:44.1032162', NULL),
  (12, N'interior_liner', N'Interior Liner', 1, N'2026-10-04 07:15:44.1042162', NULL),
  (13, N'comm_ready', N'Intercom Compatibility', 1, N'2026-10-04 07:15:44.1042162', NULL),
  (14, N'visor', N'Visor System', 1, N'2026-10-07 09:25:56.6879924', NULL);
SET IDENTITY_INSERT dbo.[SpecificationDefinitions] OFF;
GO

-- Data: [dbo].[CategorySpecifications] (26 rows)
INSERT INTO dbo.[CategorySpecifications] ([CategoryId], [SpecificationId], [DisplayOrder], [IsRequired], [CreatedAt]) VALUES
  (1, 1, 10, 0, N'2026-09-27 13:57:50.4204404'),
  (1, 2, 20, 0, N'2026-09-27 13:57:50.4204404'),
  (1, 3, 30, 0, N'2026-09-27 13:57:50.4204404'),
  (1, 4, 4, 0, N'2026-10-02 03:42:54.9796277'),
  (1, 5, 2, 0, N'2026-09-30 09:05:49.0463337'),
  (1, 6, 1, 0, N'2026-09-30 09:05:49.0463337'),
  (1, 7, 3, 0, N'2026-09-30 09:05:49.0463337'),
  (1, 8, 5, 0, N'2026-10-03 06:40:29.6463973'),
  (2, 1, 10, 0, N'2026-09-27 13:57:50.4204404'),
  (2, 2, 20, 0, N'2026-09-27 13:57:50.4204404'),
  (2, 3, 30, 0, N'2026-09-27 13:57:50.4204404'),
  (2, 4, 4, 0, N'2026-09-30 08:48:49.5720546'),
  (2, 5, 2, 0, N'2026-09-30 08:48:49.5720546'),
  (2, 6, 1, 0, N'2026-09-30 08:48:49.5720546'),
  (2, 7, 3, 0, N'2026-09-30 08:48:49.5720546'),
  (2, 9, 2, 0, N'2026-10-03 08:34:00.8561340'),
  (3, 1, 10, 0, N'2026-09-27 13:57:50.4204404'),
  (3, 2, 20, 0, N'2026-09-27 13:57:50.4204404'),
  (3, 3, 30, 0, N'2026-09-27 13:57:50.4204404'),
  (3, 5, 2, 0, N'2026-10-07 09:25:56.6970069'),
  (3, 6, 1, 0, N'2026-10-07 09:25:56.6970069'),
  (3, 7, 3, 0, N'2026-10-07 09:25:56.6970069'),
  (3, 14, 4, 0, N'2026-10-07 09:25:56.6970069'),
  (5, 1, 10, 0, N'2026-09-27 13:57:50.4204404'),
  (5, 2, 20, 0, N'2026-09-27 13:57:50.4204404'),
  (5, 3, 30, 0, N'2026-09-27 13:57:50.4204404');
GO

-- Data: [dbo].[Products] (36 rows)
SET IDENTITY_INSERT dbo.[Products] ON;
INSERT INTO dbo.[Products] ([Id], [CategoryId], [BrandId], [Name], [Slug], [Description], [BasePrice], [DiscountPercentage], [MainImageUrl], [IsActive], [CreatedAt], [UpdatedAt], [DiscountType], [DiscountAmount], [DiscountStartDate], [DiscountEndDate], [DiscountIsActive], [PublicationStatus]) VALUES
  (1, 1, 1, N'Shoei RF-1400 Dedicated Helmet', N'shoei-rf-1400-dedicated', N'Lightweight aerodynamic flagship full-face helmet featuring Shoei''s proprietary AIM+ composite matrix shell, dual-ridge chin bar, and high-performance CWR-F2 Pinlock-ready shield system with center-locking tab.', 34500.00, 10, N'/Content/images/products/helmets/shoei/images-2.jpg', 1, N'2026-09-27 02:59:06.4221107', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (2, 1, 2, N'AGV Pista GP RR Carbon Racing Helmet', N'agv-pista-gp-rr-carbon', N'100% pure carbon fiber shell developed directly for MotoGP world championship racers. Features an integrated hydration channel, biplano wind-tunnel spoiler, and optical Class 1 panoramic visor with 190Â° horizontal field of view.', 78000.00, 15, N'/Content/images/products/helmets/agv/pistagprrgc7.webp', 1, N'2026-09-27 02:59:06.4221107', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (5, 2, 1, N'Shoei Neotec II Flip-Up Modular Helmet', N'shoei-neotec-2-modular', N'Advanced touring modular helmet featuring dual P/J homologation for open and closed riding, integrated QSV-1 drop-down sun visor, stainless steel 360Â° pivot locking mechanism, and noise-isolating cheek pads.', 42000.00, 10, N'/Content/images/products/helmets/shoei/images-6.jpg', 1, N'2026-09-27 02:59:06.4221107', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (7, 5, 2, N'AGV AX9 Dual Carbon Adventure Helmet', N'agv-ax9-dual-carbon', N'Multi-configuration adventure touring helmet crafted with a lightweight carbon-aramid-fiberglass shell, aerodynamic peak with air scoops, and panoramic anti-scratch shield designed for cross-country exploration.', 38000.00, 12, N'https://images.unsplash.com/photo-1616422285623-13ff0162193c?w=500&auto=format&fit=crop&q=80', 1, N'2026-09-27 02:59:06.4221107', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (9, 1, 8, N'Gille 135 GTS V1 Touring Full-Face Helmet', N'gille-135-gts-v1', N'Versatile aerodynamic full-face street helmet engineered with an impact-resistant ABS composite shell, multi-vent intake cooling, quick-release anti-scratch shield, and removable moisture-wicking liner.', 3990.00, 0, N'/Content/images/products/helmets/gille/gille-135-gts-v1.webp', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3574409', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (10, 5, 1, N'Shoei Hornet ADV Explorer Adventure Helmet', N'shoei-hornet-adv', N'Premium dual-sport adventure helmet engineered with AIM+ matrix shell, V-460 aerodynamic sun peak with pressure-relieving air vents, and CNS-2 Pinlock-ready distortion-free shield.', 36990.00, 0, N'/Content/images/products/helmets/shoei/shoei-hornet-adv.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (11, 1, 1, N'Shoei X-Fifteen Aero Marquez Race Helmet', N'shoei-x-fifteen', N'FIM racing homologated flagship road-race helmet developed in MotoGP wind tunnels. Features fully customizable interior angle, aerodynamic stabilizer flaps, and CWR-F2R tear-off ready shield.', 39990.00, 0, N'/Content/images/products/helmets/shoei/shoei-x-fifteen.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (12, 2, 7, N'HNJ 937 Flip-Up Modular Helmet', N'hnj-937', N'Practical urban and touring modular helmet featuring a one-touch metal chin bar release mechanism, dual visor system (clear outer + smoke inner), and high-impact thermoplastic shell.', 2249.00, 0, N'/Content/images/products/helmets/hnj/hnj-937.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3574409', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (13, 1, 8, N'Gille 883 Falcon Red Graphic Full-Face Helmet', N'gille-883-falcon', N'Sporty full-face helmet with race-inspired falcon graphics, high-flow aerodynamic rear spoiler, anti-scratch UV-protected visor, and quick-release micrometric buckle.', 3790.00, 0, N'/Content/images/products/helmets/gille/gille-883-falcon.webp', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (14, 1, 8, N'Gille A5009 Phoenix Metallic Full-Face Helmet', N'gille-a5009-phoenix', N'High-impact aerodynamic street helmet equipped with an iridescent rainbow visor, dual exhaust extractors, and removable antibacterial lining.', 4290.00, 0, N'/Content/images/products/helmets/gille/gille-a5009-phoenix.webp', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (15, 3, 8, N'Gille FF005 Visage Urban Open-Face Helmet', N'gille-ff005-visage', N'Chic and lightweight open-face helmet designed for scooter and city riders, featuring an oversized scratch-resistant shield and quick-release buckle.', 2690.00, 0, N'/Content/images/products/helmets/gille/gille-ff005-visage.webp', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3574409', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (16, 1, 8, N'Gille FF007 Kerena Sport Full-Face Helmet', N'gille-ff007-kerena', N'Sleek full-face helmet with wide-angle smoked visor, reinforced chin bar, and multi-channel ventilation for long rides.', 3590.00, 0, N'/Content/images/products/helmets/gille/gille-ff007-kerena.webp', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (17, 1, 2, N'AGV K6 S Minimalist Matte Black Helmet', N'agv-matte-black-full-face', N'Versatile ultra-lightweight full-face helmet engineered with a carbon-aramid fiber shell weighing just 1,255g. Certified to strict ECE 22.06 standards with 5 front intake vents and optical Class 1 visor.', 18990.00, 0, N'/Content/images/products/helmets/agv/agv-matte-black.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (18, 1, 2, N'AGV K3 SV Monster Energy Graphic Helmet', N'agv-monster-graphic-full-face', N'Dynamic aggressive full-face helmet featuring high-resistance thermoplastic shell, internal drop-down sun visor, Pinlock anti-fog lens included, and race-inspired Monster Energy graphics.', 32990.00, 0, N'/Content/images/products/helmets/agv/agv-monster-graphic.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (19, 1, 2, N'AGV K1 S Fluo Neon Graphic Full-Face Helmet', N'agv-neon-graphic-full-face', N'High-visibility track-inspired full-face helmet with bright neon artwork, high-flow chin and brow intakes, double-D ring closure, and ECE 22.06 safety rating.', 29990.00, 0, N'/Content/images/products/helmets/agv/agv-neon-graphic.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (20, 1, 2, N'AGV Corsa R Tricolore Graphic Racing Helmet', N'agv-red-blue-graphic-full-face', N'Track-focused supersport helmet crafted with carbon-aramid-fiberglass shell, reversible warm/cool interior crown pad, patented visor lock system (VLS), and wind-tunnel engineered biplano spoiler.', 28990.00, 0, N'/Content/images/products/helmets/agv/agv-red-blue-graphic.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (21, 1, 9, N'Zebra FF-855 Trackline Full-Face Helmet', N'zebra-ff-855', N'High-durability everyday full-face helmet with anti-fog prepared shield, aerodynamic shell geometry, multi-port ventilation, and ICC / BPS certification.', 2490.00, 0, N'/Content/images/products/helmets/zebra/zebra-ff-855.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (22, 2, 9, N'Zebra Hornet Dual Visor Modular Helmet', N'zebra-hornet-modular', N'Convenient flip-up modular helmet with outer clear visor and inner sun glasses, ergonomic chin bar lock, and breathable mesh lining.', 3499.00, 0, N'/Content/images/products/helmets/zebra/zebra-hornet.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (23, 2, 1, N'Shoei Neotec 3 Modular Touring Helmet', N'shoei-neotec-3', N'Next-generation premium flip-up modular helmet with seamless Sena SRL3 intercom integration, 2-stage P/J locking, and ultra-quiet 3D noise isolator cheek pads.', 37990.00, 0, N'/Content/images/products/helmets/shoei/shoei-neotec-3.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (24, 3, 9, N'Zebra 603 Urban Cruiser Open-Face Helmet', N'zebra-603', N'Clean open-face half helmet with snap-on peak visor, quick-release ratchet strap, and lightweight ABS construction for everyday errands.', 1890.00, 0, N'/Content/images/products/helmets/zebra/zebra-603-gallery-1.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-10-03 08:11:31.8569421', N'Percentage', 0.00, NULL, NULL, 0, N'Published'),
  (25, 3, 7, N'HNJ A4-001 Everyday Urban Half-Face Helmet', N'hnj-a4-001-plain', N'Affordable and durable urban open-face helmet with deep wrap-around clear visor, top intake vents, and soft foam interior.', 990.00, 0, N'/Content/images/products/helmets/hnj/hnj-a4-001.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (26, 3, 7, N'HNJ A4-008 Classic Open-Face Helmet', N'hnj-a4-008', N'Lightweight scooter helmet with distortion-free visor, convenient quick-release strap, and BPS safety certification.', 1090.00, 0, N'/Content/images/products/helmets/hnj/hnj-a4-008.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (27, 3, 7, N'HNJ Titan A4001K Graphic Open-Face Helmet', N'hnj-titan-a4001k', N'Sporty open-face helmet decorated with aggressive geometric graphics, UV-treated clear visor, and easy-clean removable cheek pads.', 1190.00, 0, N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-mario-white.webp', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (28, 1, 7, N'HNJ 2020 Aerodynamic Full-Face Helmet', N'hnj-2020', N'Full-coverage street helmet offering solid impact protection, streamlined chin vent, and wide panoramic view.', 1699.00, 0, N'/Content/images/products/helmets/hnj/hnj-2020.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3574409', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (29, 2, 9, N'Zebra YM-602 Flip-Up Modular Helmet', N'zebra-ym-602-plain', N'Dual-visor modular helmet built for daily couriers and touring riders with one-hand chin release and high-visibility reflective decals.', 2759.00, 0, N'/Content/images/products/helmets/zebra/zebra-ym-602.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3574409', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (30, 3, 9, N'Zebra YM-902 CityJet Open-Face Helmet', N'zebra-ym-902', N'Modern urban half-face helmet with full-coverage front shield, top air vents, and comfortable moisture-wicking liner.', 2395.00, 0, N'/Content/images/products/helmets/zebra/zebra-ym-902.jpg', 1, N'2026-09-27 08:53:03.8428941', N'2026-09-27 13:57:50.3514416', N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (31, 1, 2, N'AGV K1 S Red Bull Race Edition Full-Face Helmet', N'agv-red-bull-graphic', N'Aerodynamic sport helmet designed from AGV''s MotoGP racing experience. Features an Ultravision anti-scratch visor with 190Â° horizontal field of view, double-D retention system, and integrated aerodynamic spoiler.', 32990.00, 0, N'/Content/images/products/helmets/agv/agv-red-bull-graphic-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (32, 1, 2, N'AGV K1 S VR46 Sky Racing Team Helmet', N'agv-vr46-graphic', N'Official Valentino Rossi VR46 tribute graphic on AGV''s high-resistance thermoplastic resin shell. Tuned with wind-tunnel CFD aerodynamics and 4 multi-density EPS liners for track-level impact absorption.', 29990.00, 0, N'/Content/images/products/helmets/agv/agv-vr46-graphic-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (33, 2, 2, N'AGV Tourmodular Solid Pearl White Helmet', N'agv-white-modular', N'Premium dual-homologated (P/J) flip-up modular touring helmet. Built from carbon-aramid-fiberglass shell with integrated drop-down sun visor and Ritmo/Shalimar antibacterial moisture-wicking comfort lining.', 18990.00, 0, N'/Content/images/products/helmets/agv/agv-white-modular-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (34, 5, 8, N'Gille GTS 920 Adventure Peak Dual Sport Helmet', N'gille-adventure-peak', N'Rugged dual-sport adventure helmet equipped with an aerodynamically optimized sun peak, drop-down inner sun visor, high-impact ABS composite shell, and multi-channel ventilation for on-road and off-road trail riding.', 4490.00, 0, N'/Content/images/products/helmets/gille/gille-adventure-peak-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (35, 1, 8, N'Gille 135 GTS V1 Stealth Black Full-Face Helmet', N'gille-black-full-face', N'Sleek full-face street helmet in matte stealth black. Features quick-release optical clear visor, dual-exhaust rear spoilers, removable washable comfort liner, and BPS / DOT certified high-impact composite shell.', 3290.00, 0, N'/Content/images/products/helmets/gille/gille-black-full-face-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (36, 1, 8, N'Gille Falcon 883 Heritage Classic Peak Helmet', N'gille-classic-peak-full-face', N'Retro-modern full-face helmet combining cafe racer styling with modern safety. Includes a removable sun peak, reinforced chin bar, anti-fog coated visor, and plush quilted comfort liner.', 2990.00, 0, N'/Content/images/products/helmets/gille/gille-classic-peak-full-face-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (37, 3, 8, N'Gille CityJet Dual Visor Open-Face Helmet', N'gille-dual-visor-open-face', N'Lightweight urban commuter half-face helmet with an extended outer face shield for wind protection and an integrated drop-down smoke visor for glare reduction in heavy city traffic.', 2990.00, 0, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (38, 1, 8, N'Gille Aero GP Sakura Edition Full-Face Helmet', N'gille-pink-aero-full-face', N'High-visibility aerodynamic sport helmet featuring an elongated racing spoiler, multi-port top and chin ventilation, anti-scratch UV-cut visor, and quick-release micrometric chin strap.', 3290.00, 0, N'/Content/images/products/helmets/gille/gille-pink-aero-full-face-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (39, 3, 1, N'Shoei J-Cruise II Graphic Open-Face Helmet', N'shoei-graphic-open-face', N'Compact, premium open-face touring helmet featuring AIM+ composite matrix shell, micro-ratchet chinstrap, CJ-2 distortion-free shield system, and integrated QSV-2 drop-down sun shield.', 30990.00, 0, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-main-primary.jpg', 1, N'2026-09-27 13:57:50.3434410', NULL, N'PERCENTAGE', 0.00, NULL, NULL, 1, N'Published'),
  (53, 3, 2, N'weqw', N'weqw', N'asdas', 0.00, 0, NULL, 0, N'2026-10-07 09:25:56.6604309', N'2026-10-07 09:25:56.6604309', N'Percentage', 0.00, NULL, NULL, 0, N'Draft');
SET IDENTITY_INSERT dbo.[Products] OFF;
GO

-- Data: [dbo].[ProductColors] (90 rows)
SET IDENTITY_INSERT dbo.[ProductColors] ON;
INSERT INTO dbo.[ProductColors] ([Id], [ProductId], [Color], [ColorHex], [CreatedAt], [ColorType], [GradientAngle]) VALUES
  (1, 1, N'Matte Deep Black', N'#1B1B1B', N'2026-09-27 08:52:34.5923917', N'SOLID', NULL),
  (2, 1, N'Pearl Glacier White', N'#F8F9FA', N'2026-09-27 08:52:34.5923917', N'SOLID', NULL),
  (3, 1, N'Racing Gloss Red', N'#D90429', N'2026-09-27 08:52:34.5923917', N'SOLID', NULL),
  (4, 2, N'Gloss Carbon Weave', N'#2B2D42', N'2026-09-27 08:52:34.5923917', N'SOLID', NULL),
  (7, 5, N'Anthracite Metallic', N'#495057', N'2026-09-27 08:52:34.5923917', N'SOLID', NULL),
  (9, 7, N'Alpine Touring White', N'#E9ECEF', N'2026-09-27 08:52:34.5923917', N'SOLID', NULL),
  (11, 9, N'Two-Tone Matte Black Grey', N'#525252', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (12, 10, N'Invigorate TC-5', N'#4A4A4A', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (13, 10, N'Invigorate TC-7', N'#49B8D1', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (14, 11, N'Alex Marquez 73 V3', N'#1F66D1', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (15, 11, N'Marquez 9', N'#D90429', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (16, 12, N'Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (17, 12, N'Grey', N'#777777', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (18, 12, N'Mint Green', N'#73D6C4', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (19, 12, N'Pink', N'#E76F9A', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (20, 12, N'Red', N'#D90429', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (21, 12, N'White', N'#F5F5F5', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (22, 13, N'DC Flash Red Graphic', N'#D90429', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (23, 14, N'Grey', N'#777777', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (24, 14, N'Lake Green', N'#70B7A1', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (25, 14, N'Pink', N'#E8A6B8', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (26, 15, N'Matte Pink', N'#E8A6B8', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (27, 16, N'Light Blue', N'#9BD7F0', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (28, 16, N'Matte Pink', N'#E8A6B8', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (29, 16, N'White', N'#F5F5F5', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (30, 17, N'Matte Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (31, 18, N'Black Green Graphic', N'#3A7D44', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (32, 19, N'Neon Multi-Color Graphic', N'#B5E61D', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (33, 20, N'Red Blue Graphic', N'#D7263D', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (34, 21, N'Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (35, 21, N'Gloss Red', N'#D90429', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (36, 22, N'Black Orange Graphic', N'#F06A00', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (37, 22, N'Gloss Black Red', N'#B00020', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (38, 22, N'Pink Graphic', N'#E76F9A', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (39, 22, N'White Blue Graphic', N'#1F66D1', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (40, 23, N'Blue Red Graphic', N'#1877C9', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (41, 23, N'Red White Graphic', N'#D90429', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (42, 24, N'Red Graphic', N'#D90429', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (43, 25, N'Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (44, 25, N'Gloss Blue', N'#1877C9', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (45, 25, N'Grey', N'#777777', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (46, 25, N'Mint Green', N'#73D6C4', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (47, 25, N'Gloss Pink', N'#E76F9A', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (48, 25, N'Purple', N'#7542A6', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (49, 25, N'White', N'#F5F5F5', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (50, 26, N'Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (51, 26, N'Gloss Blue', N'#1877C9', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (52, 26, N'Gloss Pink', N'#E76F9A', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (53, 26, N'White', N'#F5F5F5', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (54, 27, N'Hello Kitty Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL);
INSERT INTO dbo.[ProductColors] ([Id], [ProductId], [Color], [ColorHex], [CreatedAt], [ColorType], [GradientAngle]) VALUES
  (55, 27, N'Hello Kitty Cream', N'#F3E6C8', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (56, 27, N'Mario Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (57, 27, N'Mario Pink', N'#E8A6B8', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (58, 27, N'Mario White', N'#F5F5F5', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (59, 28, N'Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (60, 28, N'Blue', N'#1877C9', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (61, 28, N'Grey', N'#777777', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (62, 28, N'Mint Green', N'#73D6C4', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (63, 28, N'Pink', N'#E76F9A', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (64, 28, N'Red', N'#D90429', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (65, 29, N'Aqua', N'#67D9D0', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (66, 29, N'Gloss Black', N'#111111', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (67, 29, N'Grey', N'#777777', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (68, 29, N'Matte Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (69, 29, N'White', N'#F5F5F5', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (70, 30, N'Aqua', N'#67D9D0', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (71, 30, N'Black', N'#1F1F1F', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (72, 30, N'Grey', N'#777777', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (73, 30, N'White', N'#F5F5F5', N'2026-09-27 08:53:03.8529155', N'SOLID', NULL),
  (74, 33, N'White', N'#F5F5F5', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (75, 32, N'Yellow Black Graphic', N'#E7D315', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (76, 31, N'Orange Red Graphic', N'#F06A00', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (77, 37, N'Plain Black', N'#1F1F1F', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (78, 37, N'Plain White', N'#F5F5F5', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (79, 37, N'Plain Pink', N'#E8A6B8', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (80, 37, N'Plain Blue', N'#9BD7F0', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (81, 14, N'Blue', N'#3457A4', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (82, 36, N'Blue', N'#55708A', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (83, 36, N'White', N'#F5F5F5', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (84, 34, N'Grey', N'#777777', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (85, 34, N'White', N'#F5F5F5', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (86, 34, N'Black', N'#1F1F1F', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (87, 38, N'Pink', N'#E8A6B8', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (88, 35, N'Black', N'#1F1F1F', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (89, 39, N'Blue Graphic', N'#345F88', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (90, 39, N'White Graphic', N'#F5F5F5', N'2026-09-27 13:57:50.3614410', N'SOLID', NULL),
  (91, 10, N'Solar Flare Gradient', N'linear-gradient(135deg, #FF416C, #8A2387)', N'2026-09-28 03:49:06.0868928', N'LINEAR_GRADIENT', 135),
  (92, 10, N'Cyber Sunrise', N'#00F2FE, #4FACFE', N'2026-09-28 03:50:22.3110856', N'LINEAR_GRADIENT', 90),
  (102, 53, N'Deep Navy', N'#0F368A', N'2026-10-07 09:25:56.7376280', N'SOLID', NULL),
  (103, 53, N'Neon Chartreuse', N'#1EFF00', N'2026-10-07 09:25:56.7381336', N'SOLID', NULL);
SET IDENTITY_INSERT dbo.[ProductColors] OFF;
GO

-- Data: [dbo].[ProductColorStops] (4 rows)
INSERT INTO dbo.[ProductColorStops] ([ProductColorId], [StopOrder], [ColorHex]) VALUES
  (91, 1, N'#FF416C'),
  (91, 2, N'#8A2387'),
  (92, 1, N'#00F2FE'),
  (92, 2, N'#4FACFE');
GO

-- Data: [dbo].[ProductVariants] (440 rows)
SET IDENTITY_INSERT dbo.[ProductVariants] ON;
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (15, N'agvmatteblackfullface-MATTE-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 30),
  (16, N'agvmatteblackfullface-MATTE-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 30),
  (17, N'agvmatteblackfullface-MATTE-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 30),
  (18, N'agvmatteblackfullface-MATTE-BLACK-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 30),
  (19, N'agvmatteblackfullface-MATTE-BLACK-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 30),
  (20, N'agvmonstergraphicfullface-BLACK-GREEN-GRAPHIC-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 31),
  (21, N'agvmonstergraphicfullface-BLACK-GREEN-GRAPHIC-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 31),
  (22, N'agvmonstergraphicfullface-BLACK-GREEN-GRAPHIC-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 31),
  (23, N'agvmonstergraphicfullface-BLACK-GREEN-GRAPHIC-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 31),
  (24, N'agvmonstergraphicfullface-BLACK-GREEN-GRAPHIC-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 31),
  (25, N'agvneongraphicfullface-NEON-GRAPHIC-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 32),
  (26, N'agvneongraphicfullface-NEON-GRAPHIC-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 32),
  (27, N'agvneongraphicfullface-NEON-GRAPHIC-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 32),
  (28, N'agvneongraphicfullface-NEON-GRAPHIC-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 32),
  (29, N'agvneongraphicfullface-NEON-GRAPHIC-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 32),
  (30, N'agvredbluegraphicfullface-RED-BLUE-GRAPHIC-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 33),
  (31, N'agvredbluegraphicfullface-RED-BLUE-GRAPHIC-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 33),
  (32, N'agvredbluegraphicfullface-RED-BLUE-GRAPHIC-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 33),
  (33, N'agvredbluegraphicfullface-RED-BLUE-GRAPHIC-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 33),
  (34, N'agvredbluegraphicfullface-RED-BLUE-GRAPHIC-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 33),
  (35, N'gille135gtsv1-MATTE-BLACK-GREY-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 11),
  (36, N'gille135gtsv1-MATTE-BLACK-GREY-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 11),
  (37, N'gille135gtsv1-MATTE-BLACK-GREY-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 11),
  (38, N'gille135gtsv1-MATTE-BLACK-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 11),
  (39, N'gille135gtsv1-MATTE-BLACK-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 11),
  (40, N'gille883falcon-DC-FLASH-RED-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 22),
  (41, N'gille883falcon-DC-FLASH-RED-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 22),
  (42, N'gille883falcon-DC-FLASH-RED-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 22),
  (43, N'gille883falcon-DC-FLASH-RED-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 22),
  (44, N'gille883falcon-DC-FLASH-RED-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 22),
  (45, N'gillea5009phoenix-GREY-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 23),
  (46, N'gillea5009phoenix-GREY-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 23),
  (47, N'gillea5009phoenix-GREY-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 23),
  (48, N'gillea5009phoenix-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 23),
  (49, N'gillea5009phoenix-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 23),
  (50, N'gillea5009phoenix-LAKE-GREEN-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 24),
  (51, N'gillea5009phoenix-LAKE-GREEN-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 24),
  (52, N'gillea5009phoenix-LAKE-GREEN-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 24),
  (53, N'gillea5009phoenix-LAKE-GREEN-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 24),
  (54, N'gillea5009phoenix-LAKE-GREEN-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 24),
  (55, N'gillea5009phoenix-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 25),
  (56, N'gillea5009phoenix-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 25),
  (57, N'gillea5009phoenix-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 25),
  (58, N'gillea5009phoenix-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 25),
  (59, N'gillea5009phoenix-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 25),
  (60, N'gilleff005visage-MATTE-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 26),
  (61, N'gilleff005visage-MATTE-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 26),
  (62, N'gilleff005visage-MATTE-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 26),
  (63, N'gilleff005visage-MATTE-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 26),
  (64, N'gilleff005visage-MATTE-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 26);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (65, N'gilleff007kerena-LIGHT-BLUE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 27),
  (66, N'gilleff007kerena-LIGHT-BLUE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 27),
  (67, N'gilleff007kerena-LIGHT-BLUE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 27),
  (68, N'gilleff007kerena-LIGHT-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 27),
  (69, N'gilleff007kerena-LIGHT-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 27),
  (70, N'gilleff007kerena-MATTE-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 28),
  (71, N'gilleff007kerena-MATTE-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 28),
  (72, N'gilleff007kerena-MATTE-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 28),
  (73, N'gilleff007kerena-MATTE-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 28),
  (74, N'gilleff007kerena-MATTE-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 28),
  (75, N'gilleff007kerena-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 29),
  (76, N'gilleff007kerena-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 29),
  (77, N'gilleff007kerena-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 29),
  (78, N'gilleff007kerena-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 29),
  (79, N'gilleff007kerena-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 29),
  (80, N'hnj2020-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 59),
  (81, N'hnj2020-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 59),
  (82, N'hnj2020-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 59),
  (83, N'hnj2020-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 59),
  (84, N'hnj2020-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 59),
  (85, N'hnj2020-BLUE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 60),
  (86, N'hnj2020-BLUE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 60),
  (87, N'hnj2020-BLUE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 60),
  (88, N'hnj2020-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 60),
  (89, N'hnj2020-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 60),
  (90, N'hnj2020-GREY-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 61),
  (91, N'hnj2020-GREY-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 61),
  (92, N'hnj2020-GREY-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 61),
  (93, N'hnj2020-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 61),
  (94, N'hnj2020-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 61),
  (95, N'hnj2020-MINT-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 62),
  (96, N'hnj2020-MINT-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 62),
  (97, N'hnj2020-MINT-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 62),
  (98, N'hnj2020-MINT-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 62),
  (99, N'hnj2020-MINT-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 62),
  (100, N'hnj2020-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 63),
  (101, N'hnj2020-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 63),
  (102, N'hnj2020-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 63),
  (103, N'hnj2020-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 63),
  (104, N'hnj2020-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 63),
  (105, N'hnj2020-RED-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 64),
  (106, N'hnj2020-RED-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 64),
  (107, N'hnj2020-RED-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 64),
  (108, N'hnj2020-RED-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 64),
  (109, N'hnj2020-RED-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 64),
  (110, N'hnj937-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 16),
  (111, N'hnj937-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 16),
  (112, N'hnj937-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 16),
  (113, N'hnj937-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 16),
  (114, N'hnj937-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 16);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (115, N'hnj937-GREY-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 17),
  (116, N'hnj937-GREY-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 17),
  (117, N'hnj937-GREY-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 17),
  (118, N'hnj937-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 17),
  (119, N'hnj937-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 17),
  (120, N'hnj937-MINT-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 18),
  (121, N'hnj937-MINT-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 18),
  (122, N'hnj937-MINT-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 18),
  (123, N'hnj937-MINT-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 18),
  (124, N'hnj937-MINT-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 18),
  (125, N'hnj937-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 19),
  (126, N'hnj937-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 19),
  (127, N'hnj937-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 19),
  (128, N'hnj937-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 19),
  (129, N'hnj937-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 19),
  (130, N'hnj937-RED-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 20),
  (131, N'hnj937-RED-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 20),
  (132, N'hnj937-RED-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 20),
  (133, N'hnj937-RED-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 20),
  (134, N'hnj937-RED-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 20),
  (135, N'hnj937-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 21),
  (136, N'hnj937-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 21),
  (137, N'hnj937-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 21),
  (138, N'hnj937-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 21),
  (139, N'hnj937-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 21),
  (140, N'hnja4001plain-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 43),
  (141, N'hnja4001plain-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 43),
  (142, N'hnja4001plain-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 43),
  (143, N'hnja4001plain-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 43),
  (144, N'hnja4001plain-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 43),
  (145, N'hnja4001plain-BLUE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 44),
  (146, N'hnja4001plain-BLUE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 44),
  (147, N'hnja4001plain-BLUE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 44),
  (148, N'hnja4001plain-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 44),
  (149, N'hnja4001plain-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 44),
  (150, N'hnja4001plain-GREY-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 45),
  (151, N'hnja4001plain-GREY-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 45),
  (152, N'hnja4001plain-GREY-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 45),
  (153, N'hnja4001plain-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 45),
  (154, N'hnja4001plain-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 45),
  (155, N'hnja4001plain-MINT-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 46),
  (156, N'hnja4001plain-MINT-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 46),
  (157, N'hnja4001plain-MINT-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 46),
  (158, N'hnja4001plain-MINT-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 46),
  (159, N'hnja4001plain-MINT-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 46),
  (160, N'hnja4001plain-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 47),
  (161, N'hnja4001plain-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 47),
  (162, N'hnja4001plain-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 47),
  (163, N'hnja4001plain-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 47),
  (164, N'hnja4001plain-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 47);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (165, N'hnja4001plain-PURPLE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 48),
  (166, N'hnja4001plain-PURPLE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 48),
  (167, N'hnja4001plain-PURPLE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 48),
  (168, N'hnja4001plain-PURPLE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 48),
  (169, N'hnja4001plain-PURPLE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 48),
  (170, N'hnja4001plain-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 49),
  (171, N'hnja4001plain-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 49),
  (172, N'hnja4001plain-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 49),
  (173, N'hnja4001plain-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 49),
  (174, N'hnja4001plain-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 49),
  (175, N'hnja4008-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 50),
  (176, N'hnja4008-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 50),
  (177, N'hnja4008-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 50),
  (178, N'hnja4008-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 50),
  (179, N'hnja4008-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 50),
  (180, N'hnja4008-BLUE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 51),
  (181, N'hnja4008-BLUE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 51),
  (182, N'hnja4008-BLUE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 51),
  (183, N'hnja4008-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 51),
  (184, N'hnja4008-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 51),
  (185, N'hnja4008-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 52),
  (186, N'hnja4008-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 52),
  (187, N'hnja4008-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 52),
  (188, N'hnja4008-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 52),
  (189, N'hnja4008-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 52),
  (190, N'hnja4008-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 53),
  (191, N'hnja4008-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 53),
  (192, N'hnja4008-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 53),
  (193, N'hnja4008-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 53),
  (194, N'hnja4008-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 53),
  (195, N'hnjtitana4001k-HELLO-KITTY-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 54),
  (196, N'hnjtitana4001k-HELLO-KITTY-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 54),
  (197, N'hnjtitana4001k-HELLO-KITTY-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 54),
  (198, N'hnjtitana4001k-HELLO-KITTY-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 54),
  (199, N'hnjtitana4001k-HELLO-KITTY-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 54),
  (200, N'hnjtitana4001k-HELLO-KITTY-CREAM-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 55),
  (201, N'hnjtitana4001k-HELLO-KITTY-CREAM-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 55),
  (202, N'hnjtitana4001k-HELLO-KITTY-CREAM-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 55),
  (203, N'hnjtitana4001k-HELLO-KITTY-CREAM-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 55),
  (204, N'hnjtitana4001k-HELLO-KITTY-CREAM-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 55),
  (205, N'hnjtitana4001k-MARIO-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 56),
  (206, N'hnjtitana4001k-MARIO-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 56),
  (207, N'hnjtitana4001k-MARIO-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 56),
  (208, N'hnjtitana4001k-MARIO-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 56),
  (209, N'hnjtitana4001k-MARIO-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 56),
  (210, N'hnjtitana4001k-MARIO-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 57),
  (211, N'hnjtitana4001k-MARIO-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 57),
  (212, N'hnjtitana4001k-MARIO-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 57),
  (213, N'hnjtitana4001k-MARIO-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 57),
  (214, N'hnjtitana4001k-MARIO-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 57);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (215, N'hnjtitana4001k-MARIO-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 58),
  (216, N'hnjtitana4001k-MARIO-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 58),
  (217, N'hnjtitana4001k-MARIO-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 58),
  (218, N'hnjtitana4001k-MARIO-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 58),
  (219, N'hnjtitana4001k-MARIO-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 58),
  (220, N'shoeihornetadv-TC-5-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 12),
  (221, N'shoeihornetadv-TC-5-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 12),
  (222, N'shoeihornetadv-TC-5-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 12),
  (223, N'shoeihornetadv-TC-5-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 12),
  (224, N'shoeihornetadv-TC-5-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 12),
  (225, N'shoeihornetadv-TC-7-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 13),
  (226, N'shoeihornetadv-TC-7-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 13),
  (227, N'shoeihornetadv-TC-7-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 13),
  (228, N'shoeihornetadv-TC-7-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 13),
  (229, N'shoeihornetadv-TC-7-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 13),
  (230, N'shoeineotec3-BLUE-RED-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 40),
  (231, N'shoeineotec3-BLUE-RED-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 40),
  (232, N'shoeineotec3-BLUE-RED-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 40),
  (233, N'shoeineotec3-BLUE-RED-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 40),
  (234, N'shoeineotec3-BLUE-RED-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 40),
  (235, N'shoeineotec3-RED-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 41),
  (236, N'shoeineotec3-RED-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 41),
  (237, N'shoeineotec3-RED-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 41),
  (238, N'shoeineotec3-RED-WHITE-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 41),
  (239, N'shoeineotec3-RED-WHITE-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 41),
  (240, N'shoeixfifteen-ALEX-MARQUEZ-73-V3-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 14),
  (241, N'shoeixfifteen-ALEX-MARQUEZ-73-V3-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 14),
  (242, N'shoeixfifteen-ALEX-MARQUEZ-73-V3-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 14),
  (243, N'shoeixfifteen-ALEX-MARQUEZ-73-V3-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 14),
  (244, N'shoeixfifteen-ALEX-MARQUEZ-73-V3-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 14),
  (245, N'shoeixfifteen-MARQUEZ-9-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 15),
  (246, N'shoeixfifteen-MARQUEZ-9-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 15),
  (247, N'shoeixfifteen-MARQUEZ-9-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 15),
  (248, N'shoeixfifteen-MARQUEZ-9-XL', N'XL', 500.00, 1, N'2026-09-27 08:53:03.8694750', 15),
  (249, N'shoeixfifteen-MARQUEZ-9-XXL', N'XXL', 1000.00, 1, N'2026-09-27 08:53:03.8694750', 15),
  (250, N'zebra603-RED-GRAPHIC-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 42),
  (251, N'zebra603-RED-GRAPHIC-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 42),
  (252, N'zebra603-RED-GRAPHIC-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 42),
  (253, N'zebra603-RED-GRAPHIC-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 42),
  (254, N'zebra603-RED-GRAPHIC-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 42),
  (255, N'zebraff855-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 34),
  (256, N'zebraff855-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 34),
  (257, N'zebraff855-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 34),
  (258, N'zebraff855-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 34),
  (259, N'zebraff855-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 34),
  (260, N'zebraff855-RED-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 35),
  (261, N'zebraff855-RED-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 35),
  (262, N'zebraff855-RED-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 35),
  (263, N'zebraff855-RED-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 35),
  (264, N'zebraff855-RED-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 35);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (265, N'zebrahornetmodular-BLACK-ORANGE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 36),
  (266, N'zebrahornetmodular-BLACK-ORANGE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 36),
  (267, N'zebrahornetmodular-BLACK-ORANGE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 36),
  (268, N'zebrahornetmodular-BLACK-ORANGE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 36),
  (269, N'zebrahornetmodular-BLACK-ORANGE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 36),
  (270, N'zebrahornetmodular-BLACK-RED-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 37),
  (271, N'zebrahornetmodular-BLACK-RED-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 37),
  (272, N'zebrahornetmodular-BLACK-RED-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 37),
  (273, N'zebrahornetmodular-BLACK-RED-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 37),
  (274, N'zebrahornetmodular-BLACK-RED-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 37),
  (275, N'zebrahornetmodular-PINK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 38),
  (276, N'zebrahornetmodular-PINK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 38),
  (277, N'zebrahornetmodular-PINK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 38),
  (278, N'zebrahornetmodular-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 38),
  (279, N'zebrahornetmodular-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 38),
  (280, N'zebrahornetmodular-WHITE-BLUE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 39),
  (281, N'zebrahornetmodular-WHITE-BLUE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 39),
  (282, N'zebrahornetmodular-WHITE-BLUE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 39),
  (283, N'zebrahornetmodular-WHITE-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 39),
  (284, N'zebrahornetmodular-WHITE-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 39),
  (285, N'zebraym602plain-AQUA-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 65),
  (286, N'zebraym602plain-AQUA-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 65),
  (287, N'zebraym602plain-AQUA-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 65),
  (288, N'zebraym602plain-AQUA-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 65),
  (289, N'zebraym602plain-AQUA-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 65),
  (290, N'zebraym602plain-GLOSS-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 66),
  (291, N'zebraym602plain-GLOSS-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 66),
  (292, N'zebraym602plain-GLOSS-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 66),
  (293, N'zebraym602plain-GLOSS-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 66),
  (294, N'zebraym602plain-GLOSS-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 66),
  (295, N'zebraym602plain-GREY-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 67),
  (296, N'zebraym602plain-GREY-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 67),
  (297, N'zebraym602plain-GREY-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 67),
  (298, N'zebraym602plain-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 67),
  (299, N'zebraym602plain-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 67),
  (300, N'zebraym602plain-MATTE-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 68),
  (301, N'zebraym602plain-MATTE-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 68),
  (302, N'zebraym602plain-MATTE-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 68),
  (303, N'zebraym602plain-MATTE-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 68),
  (304, N'zebraym602plain-MATTE-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 68),
  (305, N'zebraym602plain-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 69),
  (306, N'zebraym602plain-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 69),
  (307, N'zebraym602plain-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 69),
  (308, N'zebraym602plain-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 69),
  (309, N'zebraym602plain-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 69),
  (310, N'zebraym902-AQUA-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 70),
  (311, N'zebraym902-AQUA-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 70),
  (312, N'zebraym902-AQUA-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 70),
  (313, N'zebraym902-AQUA-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 70),
  (314, N'zebraym902-AQUA-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 70);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (315, N'zebraym902-BLACK-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 71),
  (316, N'zebraym902-BLACK-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 71),
  (317, N'zebraym902-BLACK-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 71),
  (318, N'zebraym902-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 71),
  (319, N'zebraym902-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 71),
  (320, N'zebraym902-GREY-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 72),
  (321, N'zebraym902-GREY-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 72),
  (322, N'zebraym902-GREY-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 72),
  (323, N'zebraym902-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 72),
  (324, N'zebraym902-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 72),
  (325, N'zebraym902-WHITE-L', N'L', 0.00, 1, N'2026-09-27 08:53:03.8694750', 73),
  (326, N'zebraym902-WHITE-M', N'M', 0.00, 1, N'2026-09-27 08:53:03.8694750', 73),
  (327, N'zebraym902-WHITE-S', N'S', 0.00, 1, N'2026-09-27 08:53:03.8694750', 73),
  (328, N'zebraym902-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 08:53:03.8694750', 73),
  (329, N'zebraym902-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 08:53:03.8694750', 73),
  (330, N'AGVWHITEMODULAR-WHITE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 74),
  (331, N'AGVWHITEMODULAR-WHITE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 74),
  (332, N'AGVWHITEMODULAR-WHITE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 74),
  (333, N'AGVWHITEMODULAR-WHITE-XL', N'XL', 500.00, 1, N'2026-09-27 13:57:50.3794391', 74),
  (334, N'AGVWHITEMODULAR-WHITE-XXL', N'XXL', 1000.00, 1, N'2026-09-27 13:57:50.3794391', 74),
  (335, N'AGVVR46GRAPHIC-YELLOW-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 75),
  (336, N'AGVVR46GRAPHIC-YELLOW-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 75),
  (337, N'AGVVR46GRAPHIC-YELLOW-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 75),
  (338, N'AGVVR46GRAPHIC-YELLOW-XL', N'XL', 500.00, 1, N'2026-09-27 13:57:50.3794391', 75),
  (339, N'AGVVR46GRAPHIC-YELLOW-XXL', N'XXL', 1000.00, 1, N'2026-09-27 13:57:50.3794391', 75),
  (340, N'AGVREDBULLGRAPHIC-ORANGE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 76),
  (341, N'AGVREDBULLGRAPHIC-ORANGE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 76),
  (342, N'AGVREDBULLGRAPHIC-ORANGE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 76),
  (343, N'AGVREDBULLGRAPHIC-ORANGE-XL', N'XL', 500.00, 1, N'2026-09-27 13:57:50.3794391', 76),
  (344, N'AGVREDBULLGRAPHIC-ORANGE-XXL', N'XXL', 1000.00, 1, N'2026-09-27 13:57:50.3794391', 76),
  (345, N'GILLEDUALVISOROPENFACE-BLACK-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 77),
  (346, N'GILLEDUALVISOROPENFACE-BLACK-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 77),
  (347, N'GILLEDUALVISOROPENFACE-BLACK-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 77),
  (348, N'GILLEDUALVISOROPENFACE-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 77),
  (349, N'GILLEDUALVISOROPENFACE-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 77),
  (350, N'GILLEDUALVISOROPENFACE-WHITE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 78),
  (351, N'GILLEDUALVISOROPENFACE-WHITE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 78),
  (352, N'GILLEDUALVISOROPENFACE-WHITE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 78),
  (353, N'GILLEDUALVISOROPENFACE-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 78),
  (354, N'GILLEDUALVISOROPENFACE-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 78),
  (355, N'GILLEDUALVISOROPENFACE-PINK-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 79),
  (356, N'GILLEDUALVISOROPENFACE-PINK-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 79),
  (357, N'GILLEDUALVISOROPENFACE-PINK-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 79),
  (358, N'GILLEDUALVISOROPENFACE-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 79),
  (359, N'GILLEDUALVISOROPENFACE-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 79),
  (360, N'GILLEDUALVISOROPENFACE-BLUE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 80),
  (361, N'GILLEDUALVISOROPENFACE-BLUE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 80),
  (362, N'GILLEDUALVISOROPENFACE-BLUE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 80),
  (363, N'GILLEDUALVISOROPENFACE-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 80),
  (364, N'GILLEDUALVISOROPENFACE-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 80);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (365, N'GILLEA5009PHOENIX-BLUE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 81),
  (366, N'GILLEA5009PHOENIX-BLUE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 81),
  (367, N'GILLEA5009PHOENIX-BLUE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 81),
  (368, N'GILLEA5009PHOENIX-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 81),
  (369, N'GILLEA5009PHOENIX-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 81),
  (370, N'GILLECLASSICPEAKFULLFACE-BLUE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 82),
  (371, N'GILLECLASSICPEAKFULLFACE-BLUE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 82),
  (372, N'GILLECLASSICPEAKFULLFACE-BLUE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 82),
  (373, N'GILLECLASSICPEAKFULLFACE-BLUE-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 82),
  (374, N'GILLECLASSICPEAKFULLFACE-BLUE-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 82),
  (375, N'GILLECLASSICPEAKFULLFACE-WHITE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 83),
  (376, N'GILLECLASSICPEAKFULLFACE-WHITE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 83),
  (377, N'GILLECLASSICPEAKFULLFACE-WHITE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 83),
  (378, N'GILLECLASSICPEAKFULLFACE-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 83),
  (379, N'GILLECLASSICPEAKFULLFACE-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 83),
  (380, N'GILLEADVENTUREPEAK-GREY-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 84),
  (381, N'GILLEADVENTUREPEAK-GREY-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 84),
  (382, N'GILLEADVENTUREPEAK-GREY-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 84),
  (383, N'GILLEADVENTUREPEAK-GREY-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 84),
  (384, N'GILLEADVENTUREPEAK-GREY-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 84),
  (385, N'GILLEADVENTUREPEAK-WHITE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 85),
  (386, N'GILLEADVENTUREPEAK-WHITE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 85),
  (387, N'GILLEADVENTUREPEAK-WHITE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 85),
  (388, N'GILLEADVENTUREPEAK-WHITE-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 85),
  (389, N'GILLEADVENTUREPEAK-WHITE-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 85),
  (390, N'GILLEADVENTUREPEAK-BLACK-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 86),
  (391, N'GILLEADVENTUREPEAK-BLACK-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 86),
  (392, N'GILLEADVENTUREPEAK-BLACK-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 86),
  (393, N'GILLEADVENTUREPEAK-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 86),
  (394, N'GILLEADVENTUREPEAK-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 86),
  (395, N'GILLEPINKAEROFULLFACE-PINK-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 87),
  (396, N'GILLEPINKAEROFULLFACE-PINK-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 87),
  (397, N'GILLEPINKAEROFULLFACE-PINK-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 87),
  (398, N'GILLEPINKAEROFULLFACE-PINK-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 87),
  (399, N'GILLEPINKAEROFULLFACE-PINK-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 87),
  (400, N'GILLEBLACKFULLFACE-BLACK-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 88),
  (401, N'GILLEBLACKFULLFACE-BLACK-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 88),
  (402, N'GILLEBLACKFULLFACE-BLACK-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 88),
  (403, N'GILLEBLACKFULLFACE-BLACK-XL', N'XL', 75.00, 1, N'2026-09-27 13:57:50.3794391', 88),
  (404, N'GILLEBLACKFULLFACE-BLACK-XXL', N'XXL', 150.00, 1, N'2026-09-27 13:57:50.3794391', 88),
  (405, N'SHOEIGRAPHICOPENFACE-BLUE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 89),
  (406, N'SHOEIGRAPHICOPENFACE-BLUE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 89),
  (407, N'SHOEIGRAPHICOPENFACE-BLUE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 89),
  (408, N'SHOEIGRAPHICOPENFACE-BLUE-XL', N'XL', 500.00, 1, N'2026-09-27 13:57:50.3794391', 89),
  (409, N'SHOEIGRAPHICOPENFACE-BLUE-XXL', N'XXL', 1000.00, 1, N'2026-09-27 13:57:50.3794391', 89),
  (410, N'SHOEIGRAPHICOPENFACE-WHITE-L', N'L', 0.00, 1, N'2026-09-27 13:57:50.3794391', 90),
  (411, N'SHOEIGRAPHICOPENFACE-WHITE-M', N'M', 0.00, 1, N'2026-09-27 13:57:50.3794391', 90),
  (412, N'SHOEIGRAPHICOPENFACE-WHITE-S', N'S', 0.00, 1, N'2026-09-27 13:57:50.3794391', 90),
  (413, N'SHOEIGRAPHICOPENFACE-WHITE-XL', N'XL', 500.00, 1, N'2026-09-27 13:57:50.3794391', 90),
  (414, N'SHOEIGRAPHICOPENFACE-WHITE-XXL', N'XXL', 1000.00, 1, N'2026-09-27 13:57:50.3794391', 90);
INSERT INTO dbo.[ProductVariants] ([Id], [SKU], [Size], [PriceAdjustment], [IsActive], [CreatedAt], [ProductColorId]) VALUES
  (415, N'SHO-HORNET-SFG-L', N'L', 0.00, 1, N'2026-09-28 03:49:06.0898940', 91),
  (416, N'SHO-HORNET-SFG-M', N'M', 0.00, 1, N'2026-09-28 03:49:06.0924016', 91),
  (417, N'HC-P1-C1-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 1),
  (418, N'HC-P1-C1-M', N'M', 0.00, 1, N'2026-09-28 05:04:30.5953170', 1),
  (419, N'HC-P1-C1-L', N'L', 0.00, 1, N'2026-09-28 05:04:30.5953170', 1),
  (420, N'HC-P1-C1-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 1),
  (421, N'HC-P1-C1-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 1),
  (422, N'HC-P1-C2-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 2),
  (423, N'HC-P1-C2-M', N'M', 0.00, 1, N'2026-09-28 05:04:30.5953170', 2),
  (424, N'HC-P1-C2-L', N'L', 0.00, 1, N'2026-09-28 05:04:30.5953170', 2),
  (425, N'HC-P1-C2-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 2),
  (426, N'HC-P1-C2-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 2),
  (427, N'HC-P1-C3-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 3),
  (428, N'HC-P1-C3-M', N'M', 0.00, 1, N'2026-09-28 05:04:30.5953170', 3),
  (429, N'HC-P1-C3-L', N'L', 0.00, 1, N'2026-09-28 05:04:30.5953170', 3),
  (430, N'HC-P1-C3-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 3),
  (431, N'HC-P1-C3-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 3),
  (432, N'HC-P2-C4-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 4),
  (433, N'HC-P2-C4-M', N'M', 0.00, 1, N'2026-09-28 05:04:30.5953170', 4),
  (434, N'HC-P2-C4-L', N'L', 0.00, 1, N'2026-09-28 05:04:30.5953170', 4),
  (435, N'HC-P2-C4-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 4),
  (436, N'HC-P2-C4-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 4),
  (437, N'HC-P5-C7-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 7),
  (438, N'HC-P5-C7-M', N'M', 0.00, 1, N'2026-09-28 05:04:30.5953170', 7),
  (439, N'HC-P5-C7-L', N'L', 0.00, 1, N'2026-09-28 05:04:30.5953170', 7),
  (440, N'HC-P5-C7-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 7),
  (441, N'HC-P5-C7-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 7),
  (442, N'HC-P7-C9-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 9),
  (443, N'HC-P7-C9-M', N'M', 0.00, 1, N'2026-09-28 05:04:30.5953170', 9),
  (444, N'HC-P7-C9-L', N'L', 0.00, 1, N'2026-09-28 05:04:30.5953170', 9),
  (445, N'HC-P7-C9-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 9),
  (446, N'HC-P7-C9-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 9),
  (447, N'HC-P10-C91-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 91),
  (448, N'HC-P10-C91-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 91),
  (449, N'HC-P10-C91-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 91),
  (450, N'HC-P10-C92-S', N'S', 0.00, 1, N'2026-09-28 05:04:30.5953170', 92),
  (451, N'HC-P10-C92-M', N'M', 0.00, 1, N'2026-09-28 05:04:30.5953170', 92),
  (452, N'HC-P10-C92-L', N'L', 0.00, 1, N'2026-09-28 05:04:30.5953170', 92),
  (453, N'HC-P10-C92-XL', N'XL', 500.00, 1, N'2026-09-28 05:04:30.5953170', 92),
  (454, N'HC-P10-C92-XXL', N'XXL', 1000.00, 1, N'2026-09-28 05:04:30.5953170', 92);
SET IDENTITY_INSERT dbo.[ProductVariants] OFF;
GO

-- Data: [dbo].[ProductGalleryImages] (111 rows)
SET IDENTITY_INSERT dbo.[ProductGalleryImages] ON;
INSERT INTO dbo.[ProductGalleryImages] ([Id], [ProductId], [ImageUrl], [AltText], [DisplayOrder], [IsActive], [CreatedAt], [UpdatedAt]) VALUES
  (1, 10, N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-1.jpg', N'Shoei Hornet ADV Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (2, 10, N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-2.jpg', N'Shoei Hornet ADV Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (3, 10, N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-3.jpg', N'Shoei Hornet ADV Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (4, 10, N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-4.jpg', N'Shoei Hornet ADV Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (5, 10, N'/Content/images/products/helmets/shoei/shoei-hornet-adv-gallery-5.jpg', N'Shoei Hornet ADV Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (6, 11, N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-1.jpg', N'Shoei X-Fifteen Graphic Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (7, 11, N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-2.jpg', N'Shoei X-Fifteen Graphic Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (8, 11, N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-3.jpg', N'Shoei X-Fifteen Graphic Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (9, 11, N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-4.jpg', N'Shoei X-Fifteen Graphic Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (10, 11, N'/Content/images/products/helmets/shoei/shoei-x-fifteen-gallery-5.jpg', N'Shoei X-Fifteen Graphic Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (11, 12, N'/Content/images/products/helmets/hnj/hnj-937-gallery-1.jpg', N'HNJ 937 Modular Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (12, 12, N'/Content/images/products/helmets/hnj/hnj-937-gallery-2.jpg', N'HNJ 937 Modular Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (13, 12, N'/Content/images/products/helmets/hnj/hnj-937-gallery-3.jpg', N'HNJ 937 Modular Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (14, 12, N'/Content/images/products/helmets/hnj/hnj-937-gallery-4.jpg', N'HNJ 937 Modular Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (15, 12, N'/Content/images/products/helmets/hnj/hnj-937-gallery-5.jpg', N'HNJ 937 Modular Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (16, 14, N'/Content/images/products/helmets/gille/gille-a5009-phoenix-gallery-1.jpg', N'Gille A5009 Phoenix Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (17, 14, N'/Content/images/products/helmets/gille/gille-a5009-phoenix-gallery-2.webp', N'Gille A5009 Phoenix Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (18, 14, N'/Content/images/products/helmets/gille/gille-a5009-phoenix-gallery-3.webp', N'Gille A5009 Phoenix Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (19, 15, N'/Content/images/products/helmets/gille/gille-ff005-visage-gallery-1.jpg', N'Gille FF005 Visage Open-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (20, 16, N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-1.jpg', N'Gille FF007 Kerena Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (21, 16, N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-2.jpg', N'Gille FF007 Kerena Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (22, 16, N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-3.jpg', N'Gille FF007 Kerena Full-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (23, 16, N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-4.webp', N'Gille FF007 Kerena Full-Face Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (24, 16, N'/Content/images/products/helmets/gille/gille-ff007-kerena-gallery-5.webp', N'Gille FF007 Kerena Full-Face Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (25, 17, N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-1.jpg', N'AGV Matte Black Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (26, 17, N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-2.jpg', N'AGV Matte Black Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (27, 17, N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-3.jpg', N'AGV Matte Black Full-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (28, 17, N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-4.jpg', N'AGV Matte Black Full-Face Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (29, 17, N'/Content/images/products/helmets/agv/agv-matte-black-full-face-gallery-5.jpg', N'AGV Matte Black Full-Face Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (30, 18, N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-1.jpg', N'AGV Monster Graphic Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (31, 18, N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-2.jpg', N'AGV Monster Graphic Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (32, 18, N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-3.jpg', N'AGV Monster Graphic Full-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (33, 18, N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-4.jpg', N'AGV Monster Graphic Full-Face Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (34, 18, N'/Content/images/products/helmets/agv/agv-monster-graphic-full-face-gallery-5.jpg', N'AGV Monster Graphic Full-Face Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (35, 19, N'/Content/images/products/helmets/agv/agv-neon-graphic-full-face-gallery-1.jpg', N'AGV Neon Graphic Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (36, 19, N'/Content/images/products/helmets/agv/agv-neon-graphic-full-face-gallery-2.jpg', N'AGV Neon Graphic Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (37, 19, N'/Content/images/products/helmets/agv/agv-neon-graphic-full-face-gallery-3.jpg', N'AGV Neon Graphic Full-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (38, 20, N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-1.jpg', N'AGV Red Blue Graphic Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (39, 20, N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-2.jpg', N'AGV Red Blue Graphic Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (40, 20, N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-3.jpg', N'AGV Red Blue Graphic Full-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (41, 20, N'/Content/images/products/helmets/agv/agv-red-blue-graphic-full-face-gallery-4.jpg', N'AGV Red Blue Graphic Full-Face Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (42, 21, N'/Content/images/products/helmets/zebra/zebra-ff-855-gallery-1.jpg', N'Zebra FF-855 Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (43, 21, N'/Content/images/products/helmets/zebra/zebra-ff-855-gallery-2.jpg', N'Zebra FF-855 Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (44, 22, N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-1.jpg', N'Zebra Hornet Modular Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (45, 22, N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-2.jpg', N'Zebra Hornet Modular Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (46, 22, N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-3.jpg', N'Zebra Hornet Modular Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (47, 22, N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-4.jpg', N'Zebra Hornet Modular Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (48, 22, N'/Content/images/products/helmets/zebra/zebra-hornet-modular-gallery-5.jpg', N'Zebra Hornet Modular Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (49, 23, N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-1.jpg', N'Shoei Neotec 3 Modular Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (50, 23, N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-2.jpg', N'Shoei Neotec 3 Modular Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL);
INSERT INTO dbo.[ProductGalleryImages] ([Id], [ProductId], [ImageUrl], [AltText], [DisplayOrder], [IsActive], [CreatedAt], [UpdatedAt]) VALUES
  (51, 23, N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-3.jpg', N'Shoei Neotec 3 Modular Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (52, 23, N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-4.jpg', N'Shoei Neotec 3 Modular Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (53, 23, N'/Content/images/products/helmets/shoei/shoei-neotec-3-gallery-5.jpg', N'Shoei Neotec 3 Modular Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (54, 24, N'/Content/images/products/helmets/zebra/zebra-603-gallery-1.jpg', N'Zebra 603 Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (55, 25, N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-1.jpg', N'HNJ A4-001 Plain Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (56, 25, N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-2.jpg', N'HNJ A4-001 Plain Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (57, 25, N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-3.jpg', N'HNJ A4-001 Plain Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (58, 25, N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-4.jpg', N'HNJ A4-001 Plain Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (59, 25, N'/Content/images/products/helmets/hnj/hnj-a4-001-plain-gallery-5.jpg', N'HNJ A4-001 Plain Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (60, 26, N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-1.jpg', N'HNJ A4-008 Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (61, 26, N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-2.jpg', N'HNJ A4-008 Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (62, 26, N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-3.jpg', N'HNJ A4-008 Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (63, 26, N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-4.jpg', N'HNJ A4-008 Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (64, 26, N'/Content/images/products/helmets/hnj/hnj-a4-008-gallery-5.jpg', N'HNJ A4-008 Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (65, 27, N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-1.webp', N'HNJ Titan A4001K Graphic Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (66, 27, N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-2.webp', N'HNJ Titan A4001K Graphic Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (67, 27, N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-3.webp', N'HNJ Titan A4001K Graphic Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (68, 27, N'/Content/images/products/helmets/hnj/hnj-titan-a4001k-gallery-4.webp', N'HNJ Titan A4001K Graphic Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (69, 28, N'/Content/images/products/helmets/hnj/hnj-2020-gallery-1.jpg', N'HNJ 2020 Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (70, 28, N'/Content/images/products/helmets/hnj/hnj-2020-gallery-2.jpg', N'HNJ 2020 Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (71, 28, N'/Content/images/products/helmets/hnj/hnj-2020-gallery-3.jpg', N'HNJ 2020 Full-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (72, 28, N'/Content/images/products/helmets/hnj/hnj-2020-gallery-4.jpg', N'HNJ 2020 Full-Face Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (73, 28, N'/Content/images/products/helmets/hnj/hnj-2020-gallery-5.jpg', N'HNJ 2020 Full-Face Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (74, 29, N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-1.jpg', N'Zebra YM-602 Plain Modular Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (75, 29, N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-2.jpg', N'Zebra YM-602 Plain Modular Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (76, 29, N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-3.jpg', N'Zebra YM-602 Plain Modular Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (77, 29, N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-4.jpg', N'Zebra YM-602 Plain Modular Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (78, 29, N'/Content/images/products/helmets/zebra/zebra-ym-602-plain-gallery-5.jpg', N'Zebra YM-602 Plain Modular Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (79, 30, N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-1.jpg', N'Zebra YM-902 Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (80, 30, N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-2.jpg', N'Zebra YM-902 Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (81, 30, N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-3.jpg', N'Zebra YM-902 Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (82, 30, N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-4.jpg', N'Zebra YM-902 Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (83, 30, N'/Content/images/products/helmets/zebra/zebra-ym-902-gallery-5.jpg', N'Zebra YM-902 Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (84, 31, N'/Content/images/products/helmets/agv/agv-red-bull-graphic-gallery-1.jpg', N'AGV Red Bull Graphic Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (85, 31, N'/Content/images/products/helmets/agv/agv-red-bull-graphic-gallery-2.jpg', N'AGV Red Bull Graphic Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (86, 32, N'/Content/images/products/helmets/agv/agv-vr46-graphic-gallery-1.jpg', N'AGV VR46 Graphic Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (87, 32, N'/Content/images/products/helmets/agv/agv-vr46-graphic-gallery-2.jpg', N'AGV VR46 Graphic Full-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (88, 33, N'/Content/images/products/helmets/agv/agv-white-modular-gallery-1.jpg', N'AGV White Modular Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (89, 33, N'/Content/images/products/helmets/agv/agv-white-modular-gallery-2.jpg', N'AGV White Modular Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (90, 33, N'/Content/images/products/helmets/agv/agv-white-modular-gallery-3.jpg', N'AGV White Modular Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (91, 34, N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-1.jpg', N'Gille Adventure Peak Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (92, 34, N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-2.jpg', N'Gille Adventure Peak Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (93, 34, N'/Content/images/products/helmets/gille/gille-adventure-peak-gallery-3.jpg', N'Gille Adventure Peak Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (94, 36, N'/Content/images/products/helmets/gille/gille-classic-peak-full-face-gallery-1.jpg', N'Gille Classic Peak Full-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (95, 37, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-1.jpg', N'Gille Dual Visor Open-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (96, 37, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-2.jpg', N'Gille Dual Visor Open-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (97, 37, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-3.jpg', N'Gille Dual Visor Open-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (98, 37, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-4.jpg', N'Gille Dual Visor Open-Face Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (99, 37, N'/Content/images/products/helmets/gille/gille-dual-visor-open-face-gallery-5.jpg', N'Gille Dual Visor Open-Face Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (100, 39, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-1.jpg', N'Shoei Graphic Open-Face Helmet - view 1', 1, 1, N'2026-09-27 13:57:50.4074406', NULL);
INSERT INTO dbo.[ProductGalleryImages] ([Id], [ProductId], [ImageUrl], [AltText], [DisplayOrder], [IsActive], [CreatedAt], [UpdatedAt]) VALUES
  (101, 39, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-2.jpg', N'Shoei Graphic Open-Face Helmet - view 2', 2, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (102, 39, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-3.jpg', N'Shoei Graphic Open-Face Helmet - view 3', 3, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (103, 39, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-4.jpg', N'Shoei Graphic Open-Face Helmet - view 4', 4, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (104, 39, N'/Content/images/products/helmets/shoei/shoei-graphic-open-face-gallery-5.jpg', N'Shoei Graphic Open-Face Helmet - view 5', 5, 1, N'2026-09-27 13:57:50.4074406', NULL),
  (109, 1, N'/Content/images/products/helmets/shoei/images-2.jpg', N'Shoei RF-1400 Dedicated Helmet', 1, 1, N'2026-09-28 04:10:35.6292899', NULL),
  (110, 1, N'/Content/images/products/helmets/shoei/images-4.jpg', N'Shoei RF-1400 Dedicated Helmet', 2, 1, N'2026-09-28 04:13:14.6960238', NULL),
  (111, 2, N'/Content/images/products/helmets/agv/images-1.jpg', N'AGV PISTA GP RR CARBON', 1, 1, N'2026-09-28 04:33:43.6663008', NULL),
  (114, 2, N'/Content/images/products/helmets/agv/images-2.jpg', N'AGV PISTA GP RR CARBON RACING HELMET', 2, 1, N'2026-09-28 04:34:19.8706926', NULL),
  (121, 5, N'/Content/images/products/helmets/shoei/images-3.jpg', N'Shoei Neotec II Flip-Up Modular Helmet', 1, 1, N'2026-09-28 04:37:50.2572282', NULL),
  (122, 5, N'/Content/images/products/helmets/shoei/images-5.jpg', N'Shoei Neotec II Flip-Up Modular Helmet', 2, 1, N'2026-09-28 04:38:10.1301832', NULL),
  (123, 5, N'/Content/images/products/helmets/shoei/images-8.jpg', N'Shoei Neotec II Flip-Up Modular Helmet', 3, 1, N'2026-09-28 04:38:26.9770470', NULL);
SET IDENTITY_INSERT dbo.[ProductGalleryImages] OFF;
GO

-- Data: [dbo].[ProductSpecificationValues] (319 rows)
INSERT INTO dbo.[ProductSpecificationValues] ([ProductId], [SpecificationId], [SpecificationValue], [CreatedAt], [UpdatedAt]) VALUES
  (1, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 3, N'Shoei CWR-F2 Shield with Center Locking System & Pinlock EVO Insert Included', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 6, N'Shoei AIM+ (Advanced Integrated Matrix Plus Multi-Ply Organic Fibers)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 7, N'1,480g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 11, N'High-Efficiency Multi-Port Ventilation with Shutter Controls', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 12, N'3D Max-Dry Interior System (Fully Removable, Washable, Moisture-Wicking with EQRS)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (1, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 3, N'Ultrawide Class 1 Optics (5mm thick), 190Â° Field of View, Max Pinlock 120 Ready', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 5, N'FIM Racing Homologated, ECE 22.06 & DOT Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 6, N'100% 3K Carbon Fiber (Racing Grade)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 7, N'1,450g Â± 50g (Ultralight Pure Carbon)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 11, N'Direct-Flow Tuned Racing Ventilation (5 Front Intakes, 2 Rear Extractors, Metal Vents)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 12, N'Shalimar & Ritmo Fabric with Sanitized Antibacterial Treatment & 360Â° Adaptive Fit', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (2, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 1, N'Modular Flip-Up Touring', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 3, N'Shoei CNS-3C Optically Clear Visor + Integrated Drop-Down QSV-2 Sun Shield', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 6, N'Carbon-Aramidic & Fiberglass Composite Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 7, N'1,690g Â± 50g (Modular Touring Build)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 11, N'High-Efficiency Multi-Port Ventilation with Shutter Controls', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 12, N'3D Max-Dry Interior System (Fully Removable, Washable, Moisture-Wicking with EQRS)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (5, 13, N'Integrated Sena SRL3 / SRL2 Intercom Housing Ready', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 1, N'Full Face Street', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 6, N'Carbon-Aramidic & Fiberglass Composite Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (7, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (9, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 1, N'Full Face Street', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 6, N'Shoei AIM+ (Advanced Integrated Matrix Plus Multi-Ply Organic Fibers)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253');
INSERT INTO dbo.[ProductSpecificationValues] ([ProductId], [SpecificationId], [SpecificationValue], [CreatedAt], [UpdatedAt]) VALUES
  (10, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 11, N'High-Efficiency Multi-Port Ventilation with Shutter Controls', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (10, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 3, N'Shoei CWR-F2 Shield with Center Locking System & Pinlock EVO Insert Included', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 5, N'FIM Racing Homologated, ECE 22.06 & DOT Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 6, N'Shoei AIM+ (Advanced Integrated Matrix Plus Multi-Ply Organic Fibers)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 7, N'1,480g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 11, N'Direct-Flow Tuned Racing Ventilation (5 Front Intakes, 2 Rear Extractors, Metal Vents)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 12, N'3D Max-Dry Interior System (Fully Removable, Washable, Moisture-Wicking with EQRS)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (11, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 1, N'Modular Flip-Up Touring', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 3, N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 7, N'1,690g Â± 50g (Modular Touring Build)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (12, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (13, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (14, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (15, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253');
INSERT INTO dbo.[ProductSpecificationValues] ([ProductId], [SpecificationId], [SpecificationValue], [CreatedAt], [UpdatedAt]) VALUES
  (16, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (16, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 6, N'Carbon-Aramidic & Fiberglass Composite Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 7, N'1,255g Â± 50g (Compact Lightweight Shell)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (17, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 3, N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 5, N'DOT FMVSS 218 & BPS ICC Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 6, N'High-Resistance Thermoplastic Resin (HIR-TH)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (18, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 5, N'DOT FMVSS 218 & BPS ICC Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 6, N'High-Resistance Thermoplastic Resin (HIR-TH)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (19, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 6, N'Carbon-Aramidic & Fiberglass Composite Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (20, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253');
INSERT INTO dbo.[ProductSpecificationValues] ([ProductId], [SpecificationId], [SpecificationValue], [CreatedAt], [UpdatedAt]) VALUES
  (21, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (21, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 1, N'Modular Flip-Up Touring', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 3, N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 7, N'1,690g Â± 50g (Modular Touring Build)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (22, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 1, N'Modular Flip-Up Touring', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 3, N'Shoei CNS-3C Optically Clear Visor + Integrated Drop-Down QSV-2 Sun Shield', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 6, N'Shoei AIM+ (Advanced Integrated Matrix Plus Multi-Ply Organic Fibers)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 7, N'1,690g Â± 50g (Modular Touring Build)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 11, N'High-Efficiency Multi-Port Ventilation with Shutter Controls', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 12, N'3D Max-Dry Interior System (Fully Removable, Washable, Moisture-Wicking with EQRS)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (23, 13, N'Integrated Sena SRL3 / SRL2 Intercom Housing Ready', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (24, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (25, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (26, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253');
INSERT INTO dbo.[ProductSpecificationValues] ([ProductId], [SpecificationId], [SpecificationValue], [CreatedAt], [UpdatedAt]) VALUES
  (27, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (27, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (28, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 1, N'Modular Flip-Up Touring', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 3, N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 7, N'1,690g Â± 50g (Modular Touring Build)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (29, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (30, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 6, N'High-Resistance Thermoplastic Resin (HIR-TH)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (31, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 4, N'Titanium / Stainless Steel Double-D Ring System', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 6, N'High-Resistance Thermoplastic Resin (HIR-TH)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253');
INSERT INTO dbo.[ProductSpecificationValues] ([ProductId], [SpecificationId], [SpecificationValue], [CreatedAt], [UpdatedAt]) VALUES
  (32, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (32, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 1, N'Modular Flip-Up Touring', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 3, N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 6, N'Carbon-Aramidic & Fiberglass Composite Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 7, N'1,690g Â± 50g (Modular Touring Build)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (33, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 1, N'Full Face Street', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 3, N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (34, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (35, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (36, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 3, N'Dual Visor System: Anti-Scratch Outer Clear + Drop-Down Inner Sun Visor', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (37, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 1, N'Full Face Supersport', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253');
INSERT INTO dbo.[ProductSpecificationValues] ([ProductId], [SpecificationId], [SpecificationValue], [CreatedAt], [UpdatedAt]) VALUES
  (38, 5, N'DOT FMVSS 218 Compliant & Philippine BPS Quality Certified', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 11, N'Adjustable Front Brow & Chin Intakes with Aerodynamic Rear Exhaust', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (38, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 1, N'Dual Sport / Adventure Enduro', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 3, N'Anti-Scratch, Quick-Release Optical Shield (Pinlock Prepared)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 4, N'Micro-Metric Quick-Release Steel Ratchet Buckle', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 5, N'ECE 22.06 & DOT FMVSS 218 Approved (BPS Certified)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 6, N'High-Impact Polycarbonate Matrix', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 7, N'1,450g Â± 50g', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 11, N'Adventure High-Flow Chin Vent with Dirt Filter & Dual Exhaust Scoops', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 12, N'Breathable, Antibacterial, Fully Removable & Washable Comfort Padding', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (39, 13, N'Pre-Molded Speaker Pockets for Bluetooth Intercoms (Cardo / Sena Compatible)', N'2026-10-04 07:18:12.2021253', N'2026-10-04 07:18:12.2021253'),
  (53, 5, N'sd', N'2026-10-07 09:25:56.7085484', NULL),
  (53, 6, N'asd', N'2026-10-07 09:25:56.7085484', NULL),
  (53, 7, N'sd', N'2026-10-07 09:25:56.7085484', NULL),
  (53, 14, N'sd', N'2026-10-07 09:25:56.7085484', NULL);
GO

-- Data: [dbo].[Inventories] (440 rows)
SET IDENTITY_INSERT dbo.[Inventories] ON;
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (15, 15, 15, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-02 03:22:04.4481054'),
  (16, 16, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5324785'),
  (17, 17, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5324785'),
  (18, 18, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5324785'),
  (19, 19, 5, 0, 3, N'2026-09-30 10:17:23.4389867', N'2026-10-02 10:12:21.3327488'),
  (20, 20, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5324785'),
  (21, 21, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5334791'),
  (22, 22, 5, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-07 10:14:34.1690407'),
  (23, 23, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5334791'),
  (24, 24, 7, 0, 3, N'2026-09-30 10:15:39.5563889', N'2026-09-30 10:15:39.5563889'),
  (25, 25, 19, 0, 3, N'2026-10-07 08:39:52.3680397', N'2026-10-07 08:39:52.3680397'),
  (26, 26, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5344791'),
  (27, 27, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5344791'),
  (28, 28, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5344791'),
  (29, 29, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (30, 30, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5344791'),
  (31, 31, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5354797'),
  (32, 32, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (33, 33, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (34, 34, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (35, 35, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-03 09:12:12.6199110'),
  (36, 36, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5354797'),
  (37, 37, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5354797'),
  (38, 38, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-04 08:41:03.9000777'),
  (39, 39, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-02 05:38:49.5018471'),
  (40, 40, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5369847'),
  (41, 41, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5369847'),
  (42, 42, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5369847'),
  (43, 43, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5369847'),
  (44, 44, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (45, 45, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5379905'),
  (46, 46, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-07 07:06:26.8406444'),
  (47, 47, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5379905'),
  (48, 48, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5389970'),
  (49, 49, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5389970'),
  (50, 50, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5389970'),
  (51, 51, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5389970'),
  (52, 52, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5400034'),
  (53, 53, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5400034'),
  (54, 54, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5400034'),
  (55, 55, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5410030'),
  (56, 56, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5410030'),
  (57, 57, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5410030'),
  (58, 58, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5410030'),
  (59, 59, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5420017'),
  (60, 60, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5430038'),
  (61, 61, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5430038'),
  (62, 62, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5440017'),
  (63, 63, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5440017'),
  (64, 64, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (65, 65, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5440017'),
  (66, 66, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5440017'),
  (67, 67, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5450035'),
  (68, 68, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5450035'),
  (69, 69, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5450035'),
  (70, 70, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5450035'),
  (71, 71, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5460020'),
  (72, 72, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5460020'),
  (73, 73, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5460020'),
  (74, 74, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5460020'),
  (75, 75, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5470019'),
  (76, 76, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5475062'),
  (77, 77, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5475062'),
  (78, 78, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5475062'),
  (79, 79, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (80, 80, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (81, 81, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (82, 82, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (83, 83, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (84, 84, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (85, 85, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (86, 86, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (87, 87, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (88, 88, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (89, 89, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (90, 90, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (91, 91, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (92, 92, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (93, 93, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (94, 94, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (95, 95, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (96, 96, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (97, 97, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (98, 98, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (99, 99, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (100, 100, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (101, 101, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (102, 102, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (103, 103, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (104, 104, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (105, 105, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (106, 106, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (107, 107, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (108, 108, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (109, 109, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (110, 110, 20, 1, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-03 08:57:15.1711463'),
  (111, 111, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5510155'),
  (112, 112, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5510155'),
  (113, 113, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5520212'),
  (114, 114, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5520212');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (115, 115, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5520212'),
  (116, 116, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5520212'),
  (117, 117, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5530217'),
  (118, 118, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5530217'),
  (119, 119, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5530217'),
  (120, 120, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5530217'),
  (121, 121, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5540209'),
  (122, 122, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5540209'),
  (123, 123, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5540209'),
  (124, 124, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5540209'),
  (125, 125, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5550211'),
  (126, 126, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5550211'),
  (127, 127, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5550211'),
  (128, 128, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5550211'),
  (129, 129, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5560217'),
  (130, 130, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5560217'),
  (131, 131, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5560217'),
  (132, 132, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5560217'),
  (133, 133, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5570214'),
  (134, 134, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5570214'),
  (135, 135, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5575261'),
  (136, 136, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5575261'),
  (137, 137, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5575261'),
  (138, 138, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5575261'),
  (139, 139, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (140, 140, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5585345'),
  (141, 141, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5585345'),
  (142, 142, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5585345'),
  (143, 143, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5595390'),
  (144, 144, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5595390'),
  (145, 145, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5595390'),
  (146, 146, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5595390'),
  (147, 147, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5595390'),
  (148, 148, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5605380'),
  (149, 149, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5605380'),
  (150, 150, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5605380'),
  (151, 151, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5615402'),
  (152, 152, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5615402'),
  (153, 153, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5615402'),
  (154, 154, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5615402'),
  (155, 155, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5625398'),
  (156, 156, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5625398'),
  (157, 157, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5625398'),
  (158, 158, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5625398'),
  (159, 159, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5635417'),
  (160, 160, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5635417'),
  (161, 161, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5635417'),
  (162, 162, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5635417'),
  (163, 163, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5645399'),
  (164, 164, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5645399');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (165, 165, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5645399'),
  (166, 166, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5645399'),
  (167, 167, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5655395'),
  (168, 168, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5655395'),
  (169, 169, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5655395'),
  (170, 170, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5655395'),
  (171, 171, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5655395'),
  (172, 172, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5655395'),
  (173, 173, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5670440'),
  (174, 174, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (175, 175, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5670440'),
  (176, 176, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5670440'),
  (177, 177, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5670440'),
  (178, 178, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5680495'),
  (179, 179, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5680495'),
  (180, 180, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5680495'),
  (181, 181, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5690550'),
  (182, 182, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (183, 183, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (184, 184, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (185, 185, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (186, 186, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (187, 187, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (188, 188, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (189, 189, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (190, 190, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (191, 191, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (192, 192, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (193, 193, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (194, 194, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (195, 195, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (196, 196, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (197, 197, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (198, 198, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (199, 199, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (200, 200, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (201, 201, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (202, 202, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (203, 203, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (204, 204, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (205, 205, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (206, 206, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (207, 207, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (208, 208, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (209, 209, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (210, 210, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (211, 211, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (212, 212, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (213, 213, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (214, 214, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (215, 215, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (216, 216, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (217, 217, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (218, 218, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (219, 219, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (220, 220, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5735645'),
  (221, 221, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5735645'),
  (222, 222, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5735645'),
  (223, 223, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5735645'),
  (224, 224, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5745697'),
  (225, 225, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5745697'),
  (226, 226, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5745697'),
  (227, 227, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5755690'),
  (228, 228, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5755690'),
  (229, 229, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5755690'),
  (230, 230, 13, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-03 09:05:55.8413557'),
  (231, 231, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (232, 232, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (233, 233, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (234, 234, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (235, 235, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (236, 236, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (237, 237, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (238, 238, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (239, 239, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (240, 240, 13, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-02 03:48:36.7988529'),
  (241, 241, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (242, 242, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (243, 243, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (244, 244, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (245, 245, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (246, 246, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (247, 247, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (248, 248, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (249, 249, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (250, 250, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5855866'),
  (251, 251, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5855866'),
  (252, 252, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5855866'),
  (253, 253, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5855866'),
  (254, 254, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (255, 255, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5780795'),
  (256, 256, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5790797'),
  (257, 257, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-06 07:40:11.5543373'),
  (258, 258, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5790797'),
  (259, 259, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5790797'),
  (260, 260, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5800787'),
  (261, 261, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5800787'),
  (262, 262, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5805824'),
  (263, 263, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5805824'),
  (264, 264, 4, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-07 07:01:29.4661869');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (265, 265, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5805824'),
  (266, 266, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5805824'),
  (267, 267, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5805824'),
  (268, 268, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5815860'),
  (269, 269, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5815860'),
  (270, 270, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5815860'),
  (271, 271, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5815860'),
  (272, 272, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5825867'),
  (273, 273, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5825867'),
  (274, 274, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5825867'),
  (275, 275, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5825867'),
  (276, 276, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5835868'),
  (277, 277, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5835868'),
  (278, 278, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5835868'),
  (279, 279, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5835868'),
  (280, 280, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5845863'),
  (281, 281, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5845863'),
  (282, 282, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5845863'),
  (283, 283, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5845863'),
  (284, 284, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (285, 285, 19, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-03 08:28:45.5147036'),
  (286, 286, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5855866'),
  (287, 287, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5870903'),
  (288, 288, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5870903'),
  (289, 289, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5870903'),
  (290, 290, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5870903'),
  (291, 291, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5880947'),
  (292, 292, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5880947'),
  (293, 293, 6, 1, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-02 08:07:12.4153372'),
  (294, 294, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (295, 295, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (296, 296, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (297, 297, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (298, 298, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (299, 299, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (300, 300, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (301, 301, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (302, 302, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (303, 303, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (304, 304, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (305, 305, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (306, 306, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (307, 307, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (308, 308, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (309, 309, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (310, 310, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (311, 311, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (312, 312, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (313, 313, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (314, 314, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (315, 315, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (316, 316, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (317, 317, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (318, 318, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (319, 319, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (320, 320, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (321, 321, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (322, 322, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (323, 323, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (324, 324, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (325, 325, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (326, 326, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (327, 327, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (328, 328, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (329, 329, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (330, 330, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (331, 331, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (332, 332, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (333, 333, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (334, 334, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (335, 335, 14, 14, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-02 08:36:19.9435467'),
  (336, 336, 11, 3, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-03 08:57:03.7292517'),
  (337, 337, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (338, 338, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (339, 339, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (340, 340, 12, 1, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-04 08:46:26.4951559'),
  (341, 341, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (342, 342, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (343, 343, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (344, 344, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (345, 345, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (346, 346, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (347, 347, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (348, 348, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (349, 349, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (350, 350, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (351, 351, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (352, 352, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (353, 353, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (354, 354, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (355, 355, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (356, 356, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (357, 357, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (358, 358, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (359, 359, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (360, 360, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (361, 361, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (362, 362, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (363, 363, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (364, 364, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (365, 365, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5420017'),
  (366, 366, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5420017'),
  (367, 367, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5420017'),
  (368, 368, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5430038'),
  (369, 369, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (370, 370, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (371, 371, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (372, 372, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (373, 373, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (374, 374, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (375, 375, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (376, 376, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (377, 377, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (378, 378, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (379, 379, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (380, 380, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5475062'),
  (381, 381, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5485133'),
  (382, 382, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5485133'),
  (383, 383, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5485133'),
  (384, 384, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5495109'),
  (385, 385, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5495109'),
  (386, 386, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5495109'),
  (387, 387, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5495109'),
  (388, 388, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (389, 389, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (390, 390, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (391, 391, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (392, 392, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (393, 393, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (394, 394, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (395, 395, 20, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (396, 396, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (397, 397, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (398, 398, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (399, 399, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (400, 400, 20, 1, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-03 08:56:10.7975779'),
  (401, 401, 18, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (402, 402, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (403, 403, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (404, 404, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (405, 405, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (406, 406, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (407, 407, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (408, 408, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (409, 409, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (410, 410, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (411, 411, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (412, 412, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (413, 413, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (414, 414, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462');
INSERT INTO dbo.[Inventories] ([Id], [VariantId], [CurrentStock], [ReservedStock], [ReorderPoint], [LastRestockedAt], [UpdatedAt]) VALUES
  (415, 415, 8, 0, 2, NULL, N'2026-09-30 08:08:49.5755690'),
  (416, 416, 6, 0, 2, NULL, N'2026-09-30 08:08:49.5755690'),
  (417, 417, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-04 09:20:16.6130153'),
  (418, 418, 24, 0, 3, N'2026-10-03 09:37:29.2496261', N'2026-10-03 09:37:29.3750504'),
  (419, 419, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5690550'),
  (420, 420, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5700599'),
  (421, 421, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5700599'),
  (422, 422, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5700599'),
  (423, 423, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5700599'),
  (424, 424, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5710601'),
  (425, 425, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5710601'),
  (426, 426, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5710601'),
  (427, 427, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5710601'),
  (428, 428, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5720600'),
  (429, 429, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5720600'),
  (430, 430, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5720600'),
  (431, 431, 3, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-02 03:48:36.7988529'),
  (432, 432, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5284736'),
  (433, 433, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5294795'),
  (434, 434, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5304798'),
  (435, 435, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5304798'),
  (436, 436, 5, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-10-02 03:48:36.7988529'),
  (437, 437, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5720600'),
  (438, 438, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5720600'),
  (439, 439, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5730603'),
  (440, 440, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5730603'),
  (441, 441, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (442, 442, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5304798'),
  (443, 443, 12, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5314792'),
  (444, 444, 14, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5314792'),
  (445, 445, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5314792'),
  (446, 446, 12, 0, 3, N'2026-09-30 10:11:02.1467370', N'2026-09-30 10:11:02.1467370'),
  (447, 450, 14, 0, 3, N'2026-09-29 02:49:37.6859583', N'2026-09-30 08:08:49.5780795'),
  (448, 451, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5780795'),
  (449, 452, 15, 0, 3, N'2026-09-29 02:49:37.6839491', N'2026-09-29 02:49:37.6839491'),
  (450, 453, 9, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-29 02:49:37.6859583'),
  (451, 454, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-28 05:04:30.6641462'),
  (452, 447, 8, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5770737'),
  (453, 448, 10, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5770737'),
  (454, 449, 6, 0, 3, N'2026-09-28 05:04:30.6641462', N'2026-09-30 08:08:49.5770737');
SET IDENTITY_INSERT dbo.[Inventories] OFF;
GO

-- Data: [dbo].[StockAuditLogs] (27 rows)
SET IDENTITY_INSERT dbo.[StockAuditLogs] ON;
INSERT INTO dbo.[StockAuditLogs] ([Id], [VariantId], [UserId], [ChangeType], [PreviousStock], [QuantityChanged], [ReferenceNumber], [Notes], [CreatedAt]) VALUES
  (1, 340, 6, N'ONLINE_SALE', 14, -1, N'HC-20261002-D66C27DBA1', NULL, N'2026-10-02 06:58:43.7398559'),
  (2, 264, 6, N'ONLINE_SALE', 8, -1, N'HC-20261002-5C8A3E0D72', N'Stock deducted via ONLINE_SALE', N'2026-10-02 07:32:59.7995252'),
  (3, 264, 6, N'ONLINE_SALE', 7, -1, N'HC-20261002-A92DF4D67F', N'Stock deducted via ONLINE_SALE', N'2026-10-02 08:06:48.3988405'),
  (4, 293, 6, N'ONLINE_SALE', 7, -1, N'HC-20261002-AFD7796432', NULL, N'2026-10-02 08:07:12.4194755'),
  (5, 336, 6, N'ONLINE_SALE', 12, -2, N'HC-20261002-697229162A', N'Stock deducted via ONLINE_SALE', N'2026-10-02 08:38:57.8439758'),
  (6, 19, 4, N'INSTORE_SALE', 6, -1, N'HC-20261002-46A73882B4', NULL, N'2026-10-02 10:12:21.3402805'),
  (7, 285, 6, N'ONLINE_SALE', 20, -1, N'HC-20261003-87A8E90DB0', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 08:28:45.5192132'),
  (8, 336, 6, N'ONLINE_SALE', 12, -1, N'HC-20261003-ADE8AFE0DB', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 08:57:03.7342691'),
  (9, 417, 6, N'ONLINE_SALE', 8, -1, N'HC-20261003-7F71C5308F', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 09:00:48.0946072'),
  (10, 230, 6, N'ONLINE_SALE', 14, -1, N'HC-20261003-43F7C64E01', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 09:05:55.8448619'),
  (11, 35, 6, N'ONLINE_SALE', 20, -1, N'HC-20261003-1FF3C2CC1C', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 09:11:48.5649535'),
  (12, 418, 3, N'ONLINE_SALE', 12, -1, N'HC-20261003-7C3951A361', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 09:35:52.8426169'),
  (13, 418, 3, N'ONLINE_SALE', 11, -1, N'HC-20261003-A661B7CBEE', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 09:36:28.8390727'),
  (14, 418, 3, N'ONLINE_SALE', 10, -1, N'HC-20261003-1D4B398207', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 09:36:54.6440341'),
  (15, 418, 1, N'RESTOCK', 9, 10, N'PO-DIST-2026-X1', N'Simulated supplier batch restock', N'2026-10-03 09:36:54.8196018'),
  (16, 418, 1, N'INSTORE_SALE', 19, -2, N'HC-20261003-E0F2B6D05E', NULL, N'2026-10-03 09:36:54.8835924'),
  (17, 418, 3, N'ONLINE_SALE', 17, -1, N'HC-20261003-B38D94224C', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-03 09:37:28.9520636'),
  (18, 418, 1, N'RESTOCK', 16, 10, N'PO-DIST-2026-X1', N'Simulated supplier batch restock', N'2026-10-03 09:37:29.2511411'),
  (19, 418, 1, N'INSTORE_SALE', 26, -2, N'HC-20261003-A1585882DD', NULL, N'2026-10-03 09:37:29.3810794'),
  (20, 38, 12, N'ONLINE_SALE', 14, -14, N'HC-20261004-4705E18EDE', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-04 08:37:55.8028803'),
  (21, 38, NULL, N'RETURN', 0, 14, N'RMA-202610041001', N'Restocked from RMA: RMA-202610041001', N'2026-10-04 08:41:03.9000777'),
  (22, 417, 6, N'ONLINE_SALE', 7, -1, N'HC-20261004-08085E1B2A', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-04 09:20:16.6170275'),
  (23, 257, 6, N'ONLINE_SALE', 12, -2, N'HC-20261006-0A32C0EAD7', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-06 07:40:11.5588517'),
  (25, 46, 6, N'ONLINE_SALE', 18, -2, N'HC-20261007-BD1B48AA68', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-07 07:06:05.4540257'),
  (26, 46, 6, N'ONLINE_SALE', 16, -2, N'HC-20261007-F09017DA15', N'HitPay payment confirmed; reservation converted to sale.', N'2026-10-07 07:06:26.8406444'),
  (27, 25, NULL, N'RESTOCK', 14, 5, N'STOCK-IN', N'Stock In (Supplier Shipment): STOCK-IN', N'2026-10-07 08:39:52.3690472'),
  (28, 22, 6, N'ONLINE_SALE', 8, -3, N'HC-20261007-5CCE19001A', N'Cash/COD reservation converted to physical sale.', N'2026-10-07 10:14:34.1700398');
SET IDENTITY_INSERT dbo.[StockAuditLogs] OFF;
GO

-- Data: [dbo].[RestockAlerts] (2 rows)
SET IDENTITY_INSERT dbo.[RestockAlerts] ON;
INSERT INTO dbo.[RestockAlerts] ([Id], [InventoryId], [Severity], [IsDismissed], [CreatedAt], [DismissedAt]) VALUES
  (1, 431, N'LOW_STOCK', 0, N'2026-10-02 03:48:36.8213658', NULL),
  (2, 293, N'LOW_STOCK', 0, N'2026-10-02 05:38:49.5023550', NULL);
SET IDENTITY_INSERT dbo.[RestockAlerts] OFF;
GO

-- Data: [dbo].[Vouchers] (2 rows)
SET IDENTITY_INSERT dbo.[Vouchers] ON;
INSERT INTO dbo.[Vouchers] ([Id], [Code], [DiscountType], [DiscountValue], [MinimumSpend], [ExpiresAt], [UsageLimit], [IsActive], [CreatedAt], [UpdatedAt]) VALUES
  (1, N'CARTEL10', N'PERCENTAGE', 10.00, 1500.00, N'2027-01-03 16:00:19.0000000', 100, 1, N'2026-10-03 08:00:19.9064618', NULL),
  (2, N'RIDER500', N'FIXED_AMOUNT', 500.00, 3000.00, N'2026-10-17 16:00:19.0000000', 50, 1, N'2026-10-03 08:00:19.9196685', N'2026-10-03 08:14:35.4650464');
SET IDENTITY_INSERT dbo.[Vouchers] OFF;
GO

-- Data: [dbo].[Orders] (31 rows)
SET IDENTITY_INSERT dbo.[Orders] ON;
INSERT INTO dbo.[Orders] ([Id], [OrderNumber], [UserId], [CustomerName], [CustomerEmail], [CustomerPhone], [OrderSource], [Status], [Subtotal], [DiscountAmount], [Notes], [CreatedAt], [UpdatedAt], [ShippingMethod], [ShippingFee], [ShippingRegion], [ShippingAddress], [ShippingBarangay], [ShippingCity], [ShippingProvince], [ShippingPostalCode], [Courier], [TrackingNumber], [DeliveryNotes], [VoucherCode], [CashTendered]) VALUES
  (1, N'HC-20261002-D66C27DBA1', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Completed', 32990.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-02 06:58:40.9673123', N'2026-10-02 08:03:59.8955308', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (2, N'HC-20261002-5C8A3E0D72', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Completed', 2640.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-02 07:32:59.7645025', N'2026-10-07 07:01:29.4586683', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (3, N'HC-20261002-A92DF4D67F', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Completed', 2640.00, 0.00, N'', N'2026-10-02 08:06:48.3678859', N'2026-10-02 08:21:20.2235376', N'Delivery', 150.00, N'Metro Manila (NCR)', N'Emerald street', N'Quezon City', N'Quezon City', N'Metro Manila', N'1123', N'J&T Express', N'34324234', NULL, NULL, NULL),
  (4, N'HC-20261002-AFD7796432', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 2834.00, 0.00, N'Door-to-Door Delivery (Metro Manila (NCR))', N'2026-10-02 08:07:09.9539948', N'2026-10-02 08:07:12.4194755', N'Delivery', 150.00, N'Metro Manila (NCR)', N'Emerald street', N'Quezon City', N'Quezon City', N'Metro Manila', N'1123', NULL, NULL, NULL, NULL, NULL),
  (5, N'HC-20261002-C22A3ADDCD', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 419860.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-02 08:36:19.9350359', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (6, N'HC-20261002-697229162A', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 59980.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-02 08:38:57.8145994', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (7, N'HC-20261002-46A73882B4', NULL, N'Walk-in Retail Customer', N'store@helmetcartel.com', N'N/A', N'INSTORE_POS', N'Completed', 19990.00, 0.00, NULL, N'2026-10-02 10:12:21.3216925', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (8, N'HC-20261003-D8E4B5A4B8', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 29990.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-03 08:24:10.4876431', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (9, N'HC-20261003-87A8E90DB0', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 2759.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-03 08:28:40.2162212', N'2026-10-03 08:28:45.5217245', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (10, N'HC-20261003-65E658AD9A', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'PendingPayment', 3290.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-03 08:56:10.7849607', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (11, N'HC-20261003-ADE8AFE0DB', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 29990.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-03 08:57:01.4630628', N'2026-10-03 08:57:03.7362686', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (12, N'HC-20261003-88E2286C79', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 2249.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-03 08:57:15.1590979', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (13, N'HC-20261003-7F71C5308F', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 31050.00, 500.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-03 09:00:13.1529951', N'2026-10-03 09:00:48.0946072', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'RIDER500', NULL),
  (14, N'HC-20261003-43F7C64E01', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 37990.00, 3799.00, N'Door-to-Door Delivery (Metro Manila (NCR))', N'2026-10-03 09:05:52.4441898', N'2026-10-03 09:05:55.8448619', N'Delivery', 150.00, N'Metro Manila (NCR)', N'Emerald street', N'Quezon City', N'Quezon City', N'Metro Manila', N'1123', NULL, NULL, NULL, N'CARTEL10', NULL),
  (15, N'HC-20261003-1FF3C2CC1C', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Cancelled', 3990.00, 0.00, N'Door-to-Door Delivery (Metro Manila (NCR)) | Cancelled by customer: Ordered wrong helmet size / color', N'2026-10-03 09:11:47.4220012', N'2026-10-03 09:12:12.6143791', N'Delivery', 150.00, N'Metro Manila (NCR)', N'Emerald street', N'Quezon City', N'Quezon City', N'Metro Manila', N'1123', NULL, NULL, NULL, NULL, NULL),
  (16, N'HC-20261003-7C3951A361', 3, N'Juan Dela Cruz', N'juan@rider.com', N'+639175556666', N'ONLINE', N'Processing', 31050.00, 3105.00, NULL, N'2026-10-03 09:35:52.7108927', N'2026-10-03 09:35:52.8446173', N'Delivery', 150.00, N'NCR', N'Unit 101, Katipunan Ave', N'Diliman', N'Quezon City', N'Metro Manila', N'1101', NULL, NULL, N'Handle with care, call upon arrival', N'CARTEL10', NULL),
  (17, N'HC-20261003-A661B7CBEE', 3, N'Juan Dela Cruz', N'juan@rider.com', N'+639175556666', N'ONLINE', N'Processing', 31050.00, 3105.00, NULL, N'2026-10-03 09:36:28.7639379', N'2026-10-03 09:36:28.8390727', N'Delivery', 150.00, N'NCR', N'Unit 101, Katipunan Ave', N'Diliman', N'Quezon City', N'Metro Manila', N'1101', NULL, NULL, N'Handle with care, call upon arrival', N'CARTEL10', NULL),
  (18, N'HC-20261003-1D4B398207', 3, N'Juan Dela Cruz', N'juan@rider.com', N'+639175556666', N'ONLINE', N'Completed', 31050.00, 3105.00, N'Delivered and received by customer', N'2026-10-03 09:36:54.6276334', N'2026-10-03 09:36:54.6840343', N'Delivery', 150.00, N'NCR', N'Unit 101, Katipunan Ave', N'Diliman', N'Quezon City', N'Metro Manila', N'1101', N'Lalamove Express', N'LLM-2026-998811', N'Handle with care, call upon arrival', N'CARTEL10', NULL),
  (19, N'HC-20261003-E0F2B6D05E', NULL, N'Walk-in Rider Customer', N'pos.customer@gmail.com', N'+639180009999', N'INSTORE_POS', N'Completed', 62100.00, 0.00, N'In-store cash purchase at POS counter', N'2026-10-03 09:36:54.8690061', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 70000.00),
  (20, N'HC-20261003-B38D94224C', 3, N'Juan Dela Cruz', N'juan@rider.com', N'+639175556666', N'ONLINE', N'Completed', 31050.00, 3105.00, N'Delivered and received by customer', N'2026-10-03 09:37:28.8809282', N'2026-10-03 09:37:29.0932361', N'Delivery', 150.00, N'NCR', N'Unit 101, Katipunan Ave', N'Diliman', N'Quezon City', N'Metro Manila', N'1101', N'Lalamove Express', N'LLM-2026-998811', N'Handle with care, call upon arrival', N'CARTEL10', NULL),
  (21, N'HC-20261003-A1585882DD', NULL, N'Walk-in Rider Customer', N'pos.customer@gmail.com', N'+639180009999', N'INSTORE_POS', N'Completed', 62100.00, 0.00, N'In-store cash purchase at POS counter', N'2026-10-03 09:37:29.3549833', NULL, N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 70000.00),
  (22, N'HC-20261004-20EF13BB83', 12, N'Christopher Picardo', N'picardochristopherjohnoleo1@gmail.com', N'+639694607854', N'ONLINE', N'Cancelled', 20325.00, 2032.50, N'Store Pickup at Flagship Hub (QC) | Cancelled by customer: Delivery time too long - wewe', N'2026-10-04 08:33:11.7788291', N'2026-10-04 08:35:35.2454923', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'CARTEL10', NULL),
  (23, N'HC-20261004-4705E18EDE', 12, N'Christopher John Picardo', N'picardochristopherjohnoleo1@gmail.com', N'+639694607854', N'ONLINE', N'Completed', 56910.00, 0.00, N'picarding', N'2026-10-04 08:37:52.0917606', N'2026-10-04 08:39:26.4381312', N'Delivery', 150.00, N'Metro Manila (NCR)', N'2123', N'Commonwelatw', N'Quezon City', N'Metro Manila', N'1121', N'J&T Express', N'JT997283366697', N'Nearss', NULL, NULL),
  (24, N'HC-20261004-5BAD5FABC3', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 32990.00, 0.00, N'Door-to-Door Delivery (Metro Manila (NCR))', N'2026-10-04 08:46:26.4856190', NULL, N'Delivery', 150.00, N'Metro Manila (NCR)', N'Emerald street', N'Quezon City', N'Quezon City', N'Metro Manila', N'1123', NULL, NULL, NULL, NULL, NULL),
  (25, N'HC-20261004-E501B5506C', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Cancelled', 31050.00, 0.00, N'Store Pickup at Flagship Hub (QC) | Cancelled by customer: Customer cancelled QRPh payment during checkout.', N'2026-10-04 09:20:03.6926535', N'2026-10-04 09:20:08.4788641', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (26, N'HC-20261004-A4FEF1C7EA', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Cancelled', 31050.00, 0.00, N'Store Pickup at Flagship Hub (QC) | Cancelled by customer: Customer cancelled QRPh payment during checkout.', N'2026-10-04 09:20:12.5186601', N'2026-10-04 09:20:14.1616377', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (27, N'HC-20261004-08085E1B2A', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 31050.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-04 09:20:15.5926922', N'2026-10-04 09:20:16.6180259', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (28, N'HC-20261006-0A32C0EAD7', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 4980.00, 0.00, N'Door-to-Door Delivery (Metro Manila (NCR))', N'2026-10-06 07:40:10.2025210', N'2026-10-06 07:40:11.5608499', N'Delivery', 150.00, N'Metro Manila (NCR)', N'Emerald street', N'Quezon City', N'Quezon City', N'Metro Manila', N'1123', NULL, NULL, NULL, NULL, NULL),
  (29, N'HC-20261007-BD1B48AA68', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 8580.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-07 06:59:21.5955776', N'2026-10-07 07:06:05.4540257', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (30, N'HC-20261007-F09017DA15', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Processing', 8580.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-07 07:06:25.7627053', N'2026-10-07 07:06:26.8406444', N'Pickup', 0.00, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  (31, N'HC-20261007-5CCE19001A', 6, N'Marc kevin Ferolino Del Mundo', N'kevs@gmail.com', N'09949500374', N'ONLINE', N'Completed', 98970.00, 0.00, N'Store Pickup at Flagship Hub (QC)', N'2026-10-07 09:58:31.6836046', N'2026-10-07 10:14:34.1715477', N'Pickup', 0.00, N'Pickup', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
SET IDENTITY_INSERT dbo.[Orders] OFF;
GO

-- Data: [dbo].[OrderItems] (31 rows)
SET IDENTITY_INSERT dbo.[OrderItems] ON;
INSERT INTO dbo.[OrderItems] ([Id], [OrderId], [VariantId], [Quantity], [UnitPrice], [ProductName], [SKU], [ColorName], [Size]) VALUES
  (1, 1, 340, 1, 32990.00, N'AGV Red Bull Graphic Full-Face Helmet', N'AGVREDBULLGRAPHIC-ORANGE-L', N'Orange Red Graphic', N'L'),
  (2, 2, 264, 1, 2640.00, N'Zebra FF-855 Full-Face Helmet', N'zebraff855-RED-XXL', N'Gloss Red', N'XXL'),
  (3, 3, 264, 1, 2640.00, N'Zebra FF-855 Full-Face Helmet', N'zebraff855-RED-XXL', N'Gloss Red', N'XXL'),
  (4, 4, 293, 1, 2834.00, N'Zebra YM-602 Plain Modular Helmet', N'zebraym602plain-GLOSS-BLACK-XL', N'Gloss Black', N'XL'),
  (5, 5, 335, 14, 29990.00, N'AGV VR46 Graphic Full-Face Helmet', N'AGVVR46GRAPHIC-YELLOW-L', N'Yellow Black Graphic', N'L'),
  (6, 6, 336, 2, 29990.00, N'AGV VR46 Graphic Full-Face Helmet', N'AGVVR46GRAPHIC-YELLOW-M', N'Yellow Black Graphic', N'M'),
  (7, 7, 19, 1, 19990.00, N'AGV Matte Black Full-Face Helmet', N'agvmatteblackfullface-MATTE-BLACK-XXL', N'Matte Black', N'XXL'),
  (8, 8, 336, 1, 29990.00, N'AGV VR46 Graphic Full-Face Helmet', N'AGVVR46GRAPHIC-YELLOW-M', N'Yellow Black Graphic', N'M'),
  (9, 9, 285, 1, 2759.00, N'Zebra YM-602 Plain Modular Helmet', N'zebraym602plain-AQUA-L', N'Aqua', N'L'),
  (10, 10, 400, 1, 3290.00, N'Gille Black Full-Face Helmet', N'GILLEBLACKFULLFACE-BLACK-L', N'Black', N'L'),
  (11, 11, 336, 1, 29990.00, N'AGV VR46 Graphic Full-Face Helmet', N'AGVVR46GRAPHIC-YELLOW-M', N'Yellow Black Graphic', N'M'),
  (12, 12, 110, 1, 2249.00, N'HNJ 937 Modular Helmet', N'hnj937-BLACK-L', N'Black', N'L'),
  (13, 13, 417, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-S', N'Matte Deep Black', N'S'),
  (14, 14, 230, 1, 37990.00, N'Shoei Neotec 3 Modular Helmet', N'shoeineotec3-BLUE-RED-L', N'Blue Red Graphic', N'L'),
  (15, 15, 35, 1, 3990.00, N'Gille 135 GTS V1 Helmet', N'gille135gtsv1-MATTE-BLACK-GREY-L', N'Two-Tone Matte Black Grey', N'L'),
  (16, 16, 418, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-M', N'Matte Deep Black', N'M'),
  (17, 17, 418, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-M', N'Matte Deep Black', N'M'),
  (18, 18, 418, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-M', N'Matte Deep Black', N'M'),
  (19, 19, 418, 2, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-M', N'Matte Deep Black', N'M'),
  (20, 20, 418, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-M', N'Matte Deep Black', N'M'),
  (21, 21, 418, 2, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-M', N'Matte Deep Black', N'M'),
  (22, 22, 38, 5, 4065.00, N'Gille 135 GTS V1 Touring Full-Face Helmet', N'gille135gtsv1-MATTE-BLACK-GREY-XL', N'Two-Tone Matte Black Grey', N'XL'),
  (23, 23, 38, 14, 4065.00, N'Gille 135 GTS V1 Touring Full-Face Helmet', N'gille135gtsv1-MATTE-BLACK-GREY-XL', N'Two-Tone Matte Black Grey', N'XL'),
  (24, 24, 340, 1, 32990.00, N'AGV K1 S Red Bull Race Edition Full-Face Helmet', N'AGVREDBULLGRAPHIC-ORANGE-L', N'Orange Red Graphic', N'L'),
  (25, 25, 417, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-S', N'Matte Deep Black', N'S'),
  (26, 26, 417, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-S', N'Matte Deep Black', N'S'),
  (27, 27, 417, 1, 31050.00, N'Shoei RF-1400 Dedicated Helmet', N'HC-P1-C1-S', N'Matte Deep Black', N'S'),
  (28, 28, 257, 2, 2490.00, N'Zebra FF-855 Trackline Full-Face Helmet', N'zebraff855-BLACK-S', N'Black', N'S'),
  (29, 29, 46, 2, 4290.00, N'Gille A5009 Phoenix Metallic Full-Face Helmet', N'gillea5009phoenix-GREY-M', N'Grey', N'M'),
  (30, 30, 46, 2, 4290.00, N'Gille A5009 Phoenix Metallic Full-Face Helmet', N'gillea5009phoenix-GREY-M', N'Grey', N'M'),
  (31, 31, 22, 3, 32990.00, N'AGV K3 SV Monster Energy Graphic Helmet', N'agvmonstergraphicfullface-BLACK-GREEN-GRAPHIC-S', N'Black Green Graphic', N'S');
SET IDENTITY_INSERT dbo.[OrderItems] OFF;
GO

-- Data: [dbo].[Payments] (26 rows)
SET IDENTITY_INSERT dbo.[Payments] ON;
INSERT INTO dbo.[Payments] ([Id], [OrderId], [PaymentGateway], [GatewayReference], [Amount], [Status], [PaidAt], [CreatedAt]) VALUES
  (1, 1, N'HitPay', N'SIM-QRPH-5B25DAA0', 32990.00, N'Completed', N'2026-10-02 06:58:43.7408536', N'2026-10-02 06:58:43.7408536'),
  (2, 2, N'Cash', NULL, 2640.00, N'Completed', N'2026-10-07 07:01:29.4661869', N'2026-10-02 07:32:59.7834947'),
  (3, 3, N'CashOnDelivery', NULL, 2790.00, N'Completed', N'2026-10-02 08:21:20.2235376', N'2026-10-02 08:06:48.3820818'),
  (4, 4, N'HitPay', N'SIM-QRPH-CAA3C258', 2984.00, N'Completed', N'2026-10-02 08:07:12.4194755', N'2026-10-02 08:07:12.4194755'),
  (5, 5, N'Cash', NULL, 419860.00, N'Pending', NULL, N'2026-10-02 08:36:19.9525525'),
  (6, 6, N'Cash', NULL, 59980.00, N'Pending', NULL, N'2026-10-02 08:38:57.8296350'),
  (7, 7, N'Cash', NULL, 19990.00, N'Completed', N'2026-10-02 10:12:21.3422791', N'2026-10-02 10:12:21.3422791'),
  (8, 8, N'Cash', NULL, 29990.00, N'Pending', NULL, N'2026-10-03 08:24:10.5107162'),
  (9, 9, N'HitPay', N'SIM-QRPH-CB41C821', 2759.00, N'Completed', N'2026-10-03 08:28:45.5217245', N'2026-10-03 08:28:45.5217245'),
  (10, 11, N'HitPay', N'SIM-QRPH-817DA32C', 29990.00, N'Completed', N'2026-10-03 08:57:03.7352678', N'2026-10-03 08:57:03.7352678'),
  (11, 12, N'Cash', NULL, 2249.00, N'Pending', NULL, N'2026-10-03 08:57:15.1801777'),
  (12, 13, N'HitPay', N'SIM-QRPH-3B9ED992', 30550.00, N'Completed', N'2026-10-03 09:00:48.0946072', N'2026-10-03 09:00:48.0946072'),
  (13, 14, N'HitPay', N'SIM-QRPH-A602E1A6', 34341.00, N'Completed', N'2026-10-03 09:05:55.8448619', N'2026-10-03 09:05:55.8448619'),
  (14, 15, N'HitPay', N'SIM-QRPH-CDEC1308', 4140.00, N'Refunded', N'2026-10-03 09:11:48.5649535', N'2026-10-03 09:11:48.5649535'),
  (15, 16, N'HitPay', N'SIM-GCASH-FEE9B84B', 28095.00, N'Completed', N'2026-10-03 09:35:52.8436174', N'2026-10-03 09:35:52.8436174'),
  (16, 17, N'HitPay', N'SIM-GCASH-FFCD8E20', 28095.00, N'Completed', N'2026-10-03 09:36:28.8390727', N'2026-10-03 09:36:28.8390727'),
  (17, 18, N'HitPay', N'SIM-GCASH-C8C82C20', 28095.00, N'Completed', N'2026-10-03 09:36:54.6445581', N'2026-10-03 09:36:54.6445581'),
  (18, 19, N'Cash', NULL, 62100.00, N'Completed', N'2026-10-03 09:36:54.8835924', N'2026-10-03 09:36:54.8835924'),
  (19, 20, N'HitPay', N'SIM-GCASH-635D4132', 28095.00, N'Completed', N'2026-10-03 09:37:28.9520636', N'2026-10-03 09:37:28.9520636'),
  (20, 21, N'Cash', NULL, 62100.00, N'Completed', N'2026-10-03 09:37:29.3810794', N'2026-10-03 09:37:29.3810794'),
  (21, 23, N'HitPay', N'SIM-QRPH-672531B7', 57060.00, N'Completed', N'2026-10-04 08:37:55.8049602', N'2026-10-04 08:37:55.8049602'),
  (22, 27, N'HitPay', N'SIM-QRPH-BBABB655', 31050.00, N'Completed', N'2026-10-04 09:20:16.6170275', N'2026-10-04 09:20:16.6170275'),
  (23, 28, N'HitPay', N'SIM-QRPH-12D45853', 5130.00, N'Completed', N'2026-10-06 07:40:11.5598490', N'2026-10-06 07:40:11.5598490'),
  (25, 29, N'HitPay', N'SIM-QR_PH-C6CD3650', 8580.00, N'Completed', N'2026-10-07 07:06:05.4540257', N'2026-10-07 07:06:05.4540257'),
  (26, 30, N'HitPay', N'SIM-QRPH-F0AD8C80', 8580.00, N'Completed', N'2026-10-07 07:06:26.8406444', N'2026-10-07 07:06:26.8406444'),
  (27, 31, N'Cash', NULL, 98970.00, N'Completed', N'2026-10-07 10:14:34.1715477', N'2026-10-07 09:58:31.7051691');
SET IDENTITY_INSERT dbo.[Payments] OFF;
GO

-- Data: [dbo].[ReturnRequests] (2 rows)
SET IDENTITY_INSERT dbo.[ReturnRequests] ON;
INSERT INTO dbo.[ReturnRequests] ([Id], [RmaNumber], [OrderId], [OrderItemId], [UserId], [RequestType], [Reason], [ExchangeVariantId], [CustomerNotes], [Status], [ResolutionType], [RefundAmount], [Restocked], [AdminNotes], [ProcessedBy], [CreatedAt], [UpdatedAt]) VALUES
  (1, N'RMA-202610020001', 3, 3, NULL, N'RETURN', N'WRONG_SIZE', NULL, NULL, N'Pending', NULL, NULL, 0, NULL, NULL, N'2026-10-02 10:04:12.2997533', N'2026-10-02 10:04:12.2997533'),
  (2, N'RMA-202610041001', 23, 23, NULL, N'RETURN', N'WRONG_SIZE', NULL, N'Weee', N'Completed', N'REFUND', 56910.00, 1, NULL, NULL, N'2026-10-04 08:39:52.0973354', N'2026-10-04 08:42:10.4608413');
SET IDENTITY_INSERT dbo.[ReturnRequests] OFF;
GO

-- Data: [dbo].[VoucherRedemptions] (7 rows)
SET IDENTITY_INSERT dbo.[VoucherRedemptions] ON;
INSERT INTO dbo.[VoucherRedemptions] ([Id], [VoucherId], [OrderId], [DiscountAmount], [ReleasedAt], [CreatedAt], [UpdatedAt]) VALUES
  (1, 2, 13, 500.00, NULL, N'2026-10-03 09:00:13.1750569', NULL),
  (2, 1, 14, 3799.00, NULL, N'2026-10-03 09:05:52.4916897', NULL),
  (3, 1, 16, 3105.00, NULL, N'2026-10-03 09:35:52.7349341', NULL),
  (4, 1, 17, 3105.00, NULL, N'2026-10-03 09:36:28.7819772', NULL),
  (5, 1, 18, 3105.00, NULL, N'2026-10-03 09:36:54.6286648', NULL),
  (6, 1, 20, 3105.00, NULL, N'2026-10-03 09:37:28.8994980', NULL),
  (7, 1, 22, 2032.50, N'2026-10-04 08:35:35.2515366', N'2026-10-04 08:33:11.8069903', N'2026-10-04 08:35:35.2515366');
SET IDENTITY_INSERT dbo.[VoucherRedemptions] OFF;
GO

-- Data: [dbo].[ProductReviews] (13 rows)
SET IDENTITY_INSERT dbo.[ProductReviews] ON;
INSERT INTO dbo.[ProductReviews] ([Id], [ProductId], [UserId], [OrderId], [ReviewerName], [Rating], [Title], [Comment], [IsVerifiedPurchase], [IsHidden], [CreatedAt]) VALUES
  (28, 1, 6, 13, N'Mark Kevin Del Mundo', 5, N'Exceptional aerodynamics & dead quiet on expressway', N'Upgraded from an entry-level lid to this Shoei RF-1400 and the difference is night and day. Traveling along NLEX at 100+ km/h has virtually zero wind buffeting. The CWR-F2 visor seal with the center lock completely blocks whistle noise. Pinlock keeps it crystal clear on rainy Marilaque morning rides.', 1, 0, N'2026-10-01 07:18:12.2051232'),
  (29, 2, 6, 1, N'Angelo Reyes', 5, N'Pure carbon masterpiece â€” lighter than anything I''ve worn', N'The AGV Pista GP RR is true race-spec jewelry. You can genuinely feel how light the 100% carbon shell is; virtually zero neck strain even after 3 hours of continuous riding. The 190-degree panoramic field of vision lets you see apexes without craning your neck. Worth every single peso!', 1, 0, N'2026-09-29 07:18:12.2051232'),
  (30, 11, 3, 8, N'Paolo Mendoza', 5, N'Track-ready performance and supreme ventilation', N'Bought the Shoei X-Fifteen for Clark International Speedway track days. The aerodynamic stabilization fins completely eliminate lift when tucked in on the main straight. The cheek pad angle adjustment is genius for sportbike aggressive riding postures.', 1, 0, N'2026-09-27 07:18:12.2051232'),
  (31, 5, NULL, 3, N'Katrina Santos', 5, N'Best modular touring helmet for Philippine weather', N'The Shoei Neotec II flip-up mechanism operates with satisfying precision even with thick riding gloves on. The drop-down QSV-1 sun visor drops low enough without hitting the bridge of my nose. Padding is plush and washes easily after hot weekend rides to Tagaytay.', 1, 0, N'2026-09-25 07:18:12.2051232'),
  (32, 17, 6, 7, N'Christian Tan', 5, N'Crazy lightweight and looks stunning in matte stealth', N'Weighs only around 1.25kg! Coming from a heavy 1.7kg lid, my neck feels so relaxed. The matte finish doesn''t show fingerprint smudges easily, and the visor detents click firmly into place. Perfect all-rounder for both city commutes and long province rides.', 1, 0, N'2026-09-22 07:18:12.2051232'),
  (33, 9, 6, 15, N'Miguel Dizon', 5, N'Unbeatable value for daily commuting', N'The Gille 135 GTS V1 is probably the best bang-for-buck helmet you can buy in the Philippines. Build quality is solid, vents actually channel air through the EPS channels, and the quick-release buckle is very convenient for daily stop-and-go rides.', 1, 0, N'2026-09-19 07:18:12.2051232'),
  (34, 31, NULL, 1, N'Rico Salazar', 5, N'Eye-catching Red Bull race graphics & super snug fit', N'The Red Bull racing graphic turns heads at every stoplight! High-speed stability is rock solid thanks to the extended rear aero spoiler. Visor mechanism snaps tight with zero air leaks. Make sure to follow the size chart as AGV fits nice and snug.', 1, 0, N'2026-09-16 07:18:12.2051232'),
  (35, 10, 3, 16, N'Dave Villanueva', 5, N'The peak doesn''t catch wind at all on the highway', N'Rode my adventure bike through Sierra Madre and Sagada with the Shoei Hornet ADV. Most peaked helmets pull your head back at 90km/h, but Shoei''s louvers allow air to pass straight through. Extremely comfortable and dust-sealed visor.', 1, 0, N'2026-09-13 07:18:12.2051232'),
  (36, 23, NULL, 14, N'Jericho Ramos', 5, N'Sena SRL3 integration is completely seamless', N'Upgraded to the Neotec 3 specifically for the built-in comms slot. The sound deadening is remarkable â€” I can take crystal-clear phone calls at 80km/h and the caller can''t even tell I''m on a big bike. Premium build in every detail.', 1, 0, N'2026-09-10 07:18:12.2051232'),
  (37, 34, 6, 5, N'Francis Alcantara', 4, N'Solid dual-sport helmet for weekend trail rides', N'The Gille GTS 920 handles dual-sport duties effortlessly. The inner tinted sun visor is a lifesaver when riding into direct late afternoon glare. Cheek pads were slightly snug on day one but broke in perfectly after two rides.', 1, 0, N'2026-09-06 07:18:12.2051232'),
  (38, 21, 6, 2, N'Joshua Cruz', 5, N'Reliable daily driver for delivery & errands', N'Using this Zebra FF-855 for daily city rides. Clear shield offers great peripheral vision for checking blind spots in bumper-to-bumper traffic. Padding is easily removable for weekly washes. Certified safe with genuine BPS sticker.', 1, 0, N'2026-09-04 07:18:12.2051232'),
  (39, 18, NULL, 6, N'Bea Navarro', 5, N'Aggressive look with very practical drop-down sun visor', N'The Monster Energy livery on this AGV K3 SV is crisp and vivid. I love the internal sun shield lever on the left side â€” very easy to flip up and down while keeping eyes on the road. Fits my Cardo Freecom speakers with plenty of ear room.', 1, 0, N'2026-08-30 07:18:12.2051232'),
  (40, 21, 6, NULL, N'yow', 5, N'yow', N'yow', 0, 0, N'2026-10-06 07:39:03.2664175');
SET IDENTITY_INSERT dbo.[ProductReviews] OFF;
GO

-- Data: [dbo].[ReviewReports] (0 rows)
-- (Table is empty)

-- Data: [dbo].[CartItems] (2 rows)
SET IDENTITY_INSERT dbo.[CartItems] ON;
INSERT INTO dbo.[CartItems] ([Id], [UserId], [VariantId], [Quantity], [IsSelected], [CreatedAt], [UpdatedAt]) VALUES
  (8, 4, 380, 1, 1, N'2026-10-04 08:04:31.8539140', NULL),
  (10, 6, 255, 2, 0, N'2026-10-07 07:27:24.1822150', N'2026-10-07 09:58:22.3075387');
SET IDENTITY_INSERT dbo.[CartItems] OFF;
GO

-- Data: [dbo].[Favorites] (0 rows)
-- (Table is empty)

-- Data: [dbo].[Faqs] (6 rows)
SET IDENTITY_INSERT dbo.[Faqs] ON;
INSERT INTO dbo.[Faqs] ([Id], [ProductId], [Question], [Answer], [DisplayOrder], [IsActive], [CreatedAt]) VALUES
  (1, NULL, N'How does Cash on In-Store Pickup work?', N'Select Cash as your payment method during checkout. Your item is immediately deducted from inventory and held for you. Simply present your Order Reference Number (e.g. HC-2026-XXXX) at our store cashier to pay in cash and collect your gear.', 1, 1, N'2026-09-27 02:59:06.4256165'),
  (2, NULL, N'How do I measure my head for an accurate helmet fit?', N'Wrap a flexible measuring tape around the widest part of your headâ€”approximately 1 inch (2.5 cm) above your eyebrows and just above your ears. Compare your measurement in centimeters against the sizing chart on each product page.', 2, 1, N'2026-09-27 02:59:06.4256165'),
  (3, NULL, N'What is your return or size exchange policy?', N'We offer a 3-day size exchange guarantee for in-store pickups provided the helmet is completely unused, unmounted, and returned with its original box, tags, and protective shield film intact.', 3, 1, N'2026-09-27 02:59:06.4256165'),
  (4, NULL, N'Are all helmets sold genuine and certified?', N'Yes, 100% of our inventory consists of authentic products sourced directly from licensed brand distributors, certified under official DOT, ECE 22.06, or SNELL safety standards.', 4, 1, N'2026-09-27 02:59:06.4256165'),
  (5, 1, N'Does the Shoei RF-1400 include a Pinlock anti-fog lens in the box?', N'Yes, every authentic Shoei RF-1400 includes a clear Pinlock EVO fog-resistant insert, silicone pins, breath guard, and chin curtain in the factory packaging.', 1, 1, N'2026-09-27 02:59:06.4256165'),
  (6, 2, N'Is the biplano aerodynamic spoiler on the AGV Pista replaceable?', N'Yes, the biplano rear spoiler is engineered to detach in a crash to minimize rotational forces and can be individually replaced if damaged.', 1, 1, N'2026-09-27 02:59:06.4256165');
SET IDENTITY_INSERT dbo.[Faqs] OFF;
GO

-- Data: [dbo].[HitPayWebhookLogs] (0 rows)
-- (Table is empty)

-- =====================================================================================
-- SECTION 5: FOREIGN KEY CONSTRAINTS
-- =====================================================================================
-- Foreign Keys for [dbo].[Users]
ALTER TABLE [dbo].[Users]  WITH CHECK ADD  CONSTRAINT [FK_Users_Roles] FOREIGN KEY([RoleId])
REFERENCES [dbo].[Roles] ([Id])
ALTER TABLE [dbo].[Users] CHECK CONSTRAINT [FK_Users_Roles]
GO

-- Foreign Keys for [dbo].[UserAddresses]
ALTER TABLE [dbo].[UserAddresses]  WITH CHECK ADD  CONSTRAINT [FK_UserAddresses_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE CASCADE
ALTER TABLE [dbo].[UserAddresses] CHECK CONSTRAINT [FK_UserAddresses_Users]
GO

-- Foreign Keys for [dbo].[CategorySpecifications]
ALTER TABLE [dbo].[CategorySpecifications]  WITH CHECK ADD  CONSTRAINT [FK_CategorySpecifications_Categories] FOREIGN KEY([CategoryId])
REFERENCES [dbo].[Categories] ([Id])
ALTER TABLE [dbo].[CategorySpecifications] CHECK CONSTRAINT [FK_CategorySpecifications_Categories]
ALTER TABLE [dbo].[CategorySpecifications]  WITH CHECK ADD  CONSTRAINT [FK_CategorySpecifications_Definitions] FOREIGN KEY([SpecificationId])
REFERENCES [dbo].[SpecificationDefinitions] ([Id])
ALTER TABLE [dbo].[CategorySpecifications] CHECK CONSTRAINT [FK_CategorySpecifications_Definitions]
GO

-- Foreign Keys for [dbo].[Products]
ALTER TABLE [dbo].[Products]  WITH CHECK ADD  CONSTRAINT [FK_Products_Brands] FOREIGN KEY([BrandId])
REFERENCES [dbo].[Brands] ([Id])
ALTER TABLE [dbo].[Products] CHECK CONSTRAINT [FK_Products_Brands]
ALTER TABLE [dbo].[Products]  WITH CHECK ADD  CONSTRAINT [FK_Products_Categories] FOREIGN KEY([CategoryId])
REFERENCES [dbo].[Categories] ([Id])
ALTER TABLE [dbo].[Products] CHECK CONSTRAINT [FK_Products_Categories]
GO

-- Foreign Keys for [dbo].[ProductColors]
ALTER TABLE [dbo].[ProductColors]  WITH CHECK ADD  CONSTRAINT [FK_ProductColors_Products] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
ALTER TABLE [dbo].[ProductColors] CHECK CONSTRAINT [FK_ProductColors_Products]
GO

-- Foreign Keys for [dbo].[ProductColorStops]
ALTER TABLE [dbo].[ProductColorStops]  WITH CHECK ADD  CONSTRAINT [FK_ProductColorStops_ProductColors] FOREIGN KEY([ProductColorId])
REFERENCES [dbo].[ProductColors] ([Id])
ON DELETE CASCADE
ALTER TABLE [dbo].[ProductColorStops] CHECK CONSTRAINT [FK_ProductColorStops_ProductColors]
GO

-- Foreign Keys for [dbo].[ProductVariants]
ALTER TABLE [dbo].[ProductVariants]  WITH CHECK ADD  CONSTRAINT [FK_ProductVariants_ProductColors] FOREIGN KEY([ProductColorId])
REFERENCES [dbo].[ProductColors] ([Id])
ALTER TABLE [dbo].[ProductVariants] CHECK CONSTRAINT [FK_ProductVariants_ProductColors]
GO

-- Foreign Keys for [dbo].[ProductGalleryImages]
ALTER TABLE [dbo].[ProductGalleryImages]  WITH CHECK ADD  CONSTRAINT [FK_ProductGalleryImages_Products] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
ALTER TABLE [dbo].[ProductGalleryImages] CHECK CONSTRAINT [FK_ProductGalleryImages_Products]
GO

-- Foreign Keys for [dbo].[ProductSpecificationValues]
ALTER TABLE [dbo].[ProductSpecificationValues]  WITH CHECK ADD  CONSTRAINT [FK_ProductSpecificationValues_Definitions] FOREIGN KEY([SpecificationId])
REFERENCES [dbo].[SpecificationDefinitions] ([Id])
ALTER TABLE [dbo].[ProductSpecificationValues] CHECK CONSTRAINT [FK_ProductSpecificationValues_Definitions]
ALTER TABLE [dbo].[ProductSpecificationValues]  WITH CHECK ADD  CONSTRAINT [FK_ProductSpecificationValues_Products] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
ALTER TABLE [dbo].[ProductSpecificationValues] CHECK CONSTRAINT [FK_ProductSpecificationValues_Products]
GO

-- Foreign Keys for [dbo].[Inventories]
ALTER TABLE [dbo].[Inventories]  WITH CHECK ADD  CONSTRAINT [FK_Inventories_ProductVariants] FOREIGN KEY([VariantId])
REFERENCES [dbo].[ProductVariants] ([Id])
ALTER TABLE [dbo].[Inventories] CHECK CONSTRAINT [FK_Inventories_ProductVariants]
GO

-- Foreign Keys for [dbo].[StockAuditLogs]
ALTER TABLE [dbo].[StockAuditLogs]  WITH CHECK ADD  CONSTRAINT [FK_StockAuditLogs_ProductVariants] FOREIGN KEY([VariantId])
REFERENCES [dbo].[ProductVariants] ([Id])
ALTER TABLE [dbo].[StockAuditLogs] CHECK CONSTRAINT [FK_StockAuditLogs_ProductVariants]
ALTER TABLE [dbo].[StockAuditLogs]  WITH CHECK ADD  CONSTRAINT [FK_StockAuditLogs_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ALTER TABLE [dbo].[StockAuditLogs] CHECK CONSTRAINT [FK_StockAuditLogs_Users]
GO

-- Foreign Keys for [dbo].[RestockAlerts]
ALTER TABLE [dbo].[RestockAlerts]  WITH CHECK ADD  CONSTRAINT [FK_RestockAlerts_Inventories] FOREIGN KEY([InventoryId])
REFERENCES [dbo].[Inventories] ([Id])
ALTER TABLE [dbo].[RestockAlerts] CHECK CONSTRAINT [FK_RestockAlerts_Inventories]
GO

-- Foreign Keys for [dbo].[Orders]
ALTER TABLE [dbo].[Orders]  WITH CHECK ADD  CONSTRAINT [FK_Orders_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ALTER TABLE [dbo].[Orders] CHECK CONSTRAINT [FK_Orders_Users]
GO

-- Foreign Keys for [dbo].[OrderItems]
ALTER TABLE [dbo].[OrderItems]  WITH CHECK ADD  CONSTRAINT [FK_OrderItems_Orders] FOREIGN KEY([OrderId])
REFERENCES [dbo].[Orders] ([Id])
ON DELETE CASCADE
ALTER TABLE [dbo].[OrderItems] CHECK CONSTRAINT [FK_OrderItems_Orders]
ALTER TABLE [dbo].[OrderItems]  WITH CHECK ADD  CONSTRAINT [FK_OrderItems_ProductVariants] FOREIGN KEY([VariantId])
REFERENCES [dbo].[ProductVariants] ([Id])
ALTER TABLE [dbo].[OrderItems] CHECK CONSTRAINT [FK_OrderItems_ProductVariants]
GO

-- Foreign Keys for [dbo].[Payments]
ALTER TABLE [dbo].[Payments]  WITH CHECK ADD  CONSTRAINT [FK_Payments_Orders] FOREIGN KEY([OrderId])
REFERENCES [dbo].[Orders] ([Id])
ALTER TABLE [dbo].[Payments] CHECK CONSTRAINT [FK_Payments_Orders]
GO

-- Foreign Keys for [dbo].[ReturnRequests]
ALTER TABLE [dbo].[ReturnRequests]  WITH CHECK ADD  CONSTRAINT [FK_ReturnRequests_ExchangeVariant] FOREIGN KEY([ExchangeVariantId])
REFERENCES [dbo].[ProductVariants] ([Id])
ALTER TABLE [dbo].[ReturnRequests] CHECK CONSTRAINT [FK_ReturnRequests_ExchangeVariant]
ALTER TABLE [dbo].[ReturnRequests]  WITH CHECK ADD  CONSTRAINT [FK_ReturnRequests_OrderItems] FOREIGN KEY([OrderItemId])
REFERENCES [dbo].[OrderItems] ([Id])
ALTER TABLE [dbo].[ReturnRequests] CHECK CONSTRAINT [FK_ReturnRequests_OrderItems]
ALTER TABLE [dbo].[ReturnRequests]  WITH CHECK ADD  CONSTRAINT [FK_ReturnRequests_Orders] FOREIGN KEY([OrderId])
REFERENCES [dbo].[Orders] ([Id])
ALTER TABLE [dbo].[ReturnRequests] CHECK CONSTRAINT [FK_ReturnRequests_Orders]
ALTER TABLE [dbo].[ReturnRequests]  WITH CHECK ADD  CONSTRAINT [FK_ReturnRequests_ProcessedBy] FOREIGN KEY([ProcessedBy])
REFERENCES [dbo].[Users] ([Id])
ALTER TABLE [dbo].[ReturnRequests] CHECK CONSTRAINT [FK_ReturnRequests_ProcessedBy]
ALTER TABLE [dbo].[ReturnRequests]  WITH CHECK ADD  CONSTRAINT [FK_ReturnRequests_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ALTER TABLE [dbo].[ReturnRequests] CHECK CONSTRAINT [FK_ReturnRequests_Users]
GO

-- Foreign Keys for [dbo].[VoucherRedemptions]
ALTER TABLE [dbo].[VoucherRedemptions]  WITH CHECK ADD FOREIGN KEY([OrderId])
REFERENCES [dbo].[Orders] ([Id])
ALTER TABLE [dbo].[VoucherRedemptions]  WITH CHECK ADD FOREIGN KEY([VoucherId])
REFERENCES [dbo].[Vouchers] ([Id])
GO

-- Foreign Keys for [dbo].[ProductReviews]
ALTER TABLE [dbo].[ProductReviews]  WITH CHECK ADD  CONSTRAINT [FK_ProductReviews_Orders] FOREIGN KEY([OrderId])
REFERENCES [dbo].[Orders] ([Id])
ALTER TABLE [dbo].[ProductReviews] CHECK CONSTRAINT [FK_ProductReviews_Orders]
ALTER TABLE [dbo].[ProductReviews]  WITH CHECK ADD  CONSTRAINT [FK_ProductReviews_Products] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
ON DELETE CASCADE
ALTER TABLE [dbo].[ProductReviews] CHECK CONSTRAINT [FK_ProductReviews_Products]
ALTER TABLE [dbo].[ProductReviews]  WITH CHECK ADD  CONSTRAINT [FK_ProductReviews_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ON DELETE SET NULL
ALTER TABLE [dbo].[ProductReviews] CHECK CONSTRAINT [FK_ProductReviews_Users]
GO

-- Foreign Keys for [dbo].[ReviewReports]
ALTER TABLE [dbo].[ReviewReports]  WITH CHECK ADD  CONSTRAINT [FK_ReviewReports_ProductReviews] FOREIGN KEY([ReviewId])
REFERENCES [dbo].[ProductReviews] ([Id])
ON DELETE CASCADE
ALTER TABLE [dbo].[ReviewReports] CHECK CONSTRAINT [FK_ReviewReports_ProductReviews]
ALTER TABLE [dbo].[ReviewReports]  WITH CHECK ADD  CONSTRAINT [FK_ReviewReports_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ALTER TABLE [dbo].[ReviewReports] CHECK CONSTRAINT [FK_ReviewReports_Users]
GO

-- Foreign Keys for [dbo].[CartItems]
ALTER TABLE [dbo].[CartItems]  WITH CHECK ADD FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
ALTER TABLE [dbo].[CartItems]  WITH CHECK ADD FOREIGN KEY([VariantId])
REFERENCES [dbo].[ProductVariants] ([Id])
GO

-- Foreign Keys for [dbo].[Favorites]
ALTER TABLE [dbo].[Favorites]  WITH CHECK ADD FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
ALTER TABLE [dbo].[Favorites]  WITH CHECK ADD FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([Id])
GO

-- Foreign Keys for [dbo].[Faqs]
ALTER TABLE [dbo].[Faqs]  WITH CHECK ADD  CONSTRAINT [FK_Faqs_Products] FOREIGN KEY([ProductId])
REFERENCES [dbo].[Products] ([Id])
ON DELETE CASCADE
ALTER TABLE [dbo].[Faqs] CHECK CONSTRAINT [FK_Faqs_Products]
GO

-- =====================================================================================
-- SECTION 6: VIEWS
-- =====================================================================================
-- View: v_VisibleProducts
-- ----------------------------------------------------------------------------
-- 3. Update View: dbo.v_VisibleProducts
-- ----------------------------------------------------------------------------
CREATE   VIEW dbo.v_VisibleProducts
AS
SELECT 
    p.Id,
    p.CategoryId,
    p.BrandId,
    p.Name,
    p.Slug,
    p.Description,
    p.BasePrice,
    p.DiscountPercentage,
    p.DiscountType,
    p.DiscountAmount,
    p.DiscountStartDate,
    p.DiscountEndDate,
    p.DiscountIsActive,
    p.MainImageUrl,
    p.IsActive,
    p.PublicationStatus,
    p.CreatedAt,
    p.UpdatedAt
FROM dbo.Products p
WHERE p.IsActive = 1
  AND (p.PublicationStatus IS NULL OR p.PublicationStatus = N'Published');

GO

-- View: v_VisibleProductVariants
CREATE OR ALTER VIEW dbo.v_VisibleProductVariants AS
SELECT v.* FROM dbo.ProductVariants v
JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
WHERE v.IsActive = 1;

GO

-- View: v_VisibleProductColors
CREATE OR ALTER VIEW dbo.v_VisibleProductColors AS
SELECT c.* FROM dbo.ProductColors c
JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
WHERE EXISTS (SELECT 1 FROM dbo.v_VisibleProductVariants v WHERE v.ProductColorId = c.Id);

GO

-- View: v_VisibleInventories
CREATE OR ALTER VIEW dbo.v_VisibleInventories AS
SELECT i.* FROM dbo.Inventories i
JOIN dbo.v_VisibleProductVariants v ON v.Id = i.VariantId;

GO

-- View: v_VisibleStockAuditLogs
CREATE OR ALTER VIEW dbo.v_VisibleStockAuditLogs AS
SELECT l.* FROM dbo.StockAuditLogs l
JOIN dbo.v_VisibleProductVariants v ON v.Id = l.VariantId;

GO

-- View: v_SettledOrderRevenue
CREATE OR ALTER VIEW dbo.v_SettledOrderRevenue AS
SELECT o.Id AS OrderId, o.OrderSource, paid.PaidAt,
    CONVERT(DECIMAL(18,2), CASE WHEN o.Subtotal - o.DiscountAmount > ISNULL(refunds.Amount, 0)
        THEN o.Subtotal - o.DiscountAmount - ISNULL(refunds.Amount, 0) ELSE 0 END) AS Revenue
FROM dbo.Orders o
JOIN (SELECT OrderId, MAX(PaidAt) AS PaidAt FROM dbo.Payments WHERE Status = N'Completed' GROUP BY OrderId) paid ON paid.OrderId = o.Id
OUTER APPLY (SELECT SUM(rr.RefundAmount) AS Amount FROM dbo.ReturnRequests rr
    WHERE rr.OrderId = o.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed') refunds
WHERE o.Status IN (N'Completed', N'Delivered');

GO

-- View: v_SettledSalesLines
CREATE OR ALTER VIEW dbo.v_SettledSalesLines AS
SELECT oi.OrderId, pv.Id AS VariantId, p.Id AS ProductId, p.Name AS ProductName,
    b.Id AS BrandId, b.Name AS BrandName, c.Id AS CategoryId, c.Name AS CategoryName, settled.PaidAt,
    CASE WHEN refunds.HasReturn = 1 THEN 0 ELSE oi.Quantity END AS UnitsSold,
    CONVERT(DECIMAL(28,8), CASE WHEN allocation.Amount > ISNULL(refunds.Amount, 0)
        THEN allocation.Amount - ISNULL(refunds.Amount, 0) ELSE 0 END) AS Revenue
FROM dbo.OrderItems oi JOIN dbo.Orders o ON o.Id = oi.OrderId
JOIN dbo.v_SettledOrderRevenue settled ON settled.OrderId = o.Id
JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
JOIN dbo.Products p ON p.Id = pc.ProductId
JOIN dbo.Brands b ON b.Id = p.BrandId JOIN dbo.Categories c ON c.Id = p.CategoryId
CROSS APPLY (SELECT CONVERT(DECIMAL(28,8), oi.TotalPrice) * (o.Subtotal - o.DiscountAmount) / NULLIF(o.Subtotal, 0) AS Amount) allocation
OUTER APPLY (SELECT SUM(rr.RefundAmount) AS Amount, MAX(1) AS HasReturn FROM dbo.ReturnRequests rr
    WHERE rr.OrderItemId = oi.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed') refunds;

GO

-- =====================================================================================
-- SECTION 7: TRIGGERS
-- =====================================================================================
-- Trigger: tr_Orders_ReleaseVoucher
-- Releases usage in the same transaction for every cancellation path, exactly once.
CREATE   TRIGGER dbo.tr_Orders_ReleaseVoucher ON dbo.Orders AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE r SET ReleasedAt = SYSUTCDATETIME(), UpdatedAt = SYSUTCDATETIME()
    FROM dbo.VoucherRedemptions r JOIN inserted i ON i.Id = r.OrderId
    JOIN deleted d ON d.Id = i.Id
    WHERE i.Status = N'Cancelled' AND d.Status <> N'Cancelled' AND r.ReleasedAt IS NULL;
END;

GO

-- =====================================================================================
-- SECTION 8: STORED PROCEDURES (ACTIVE ONLY)
-- =====================================================================================
-- Stored Procedure (1): sp_AddOrderItem
-- ----------------------------------------------------------------------------
-- 7. Procedure: dbo.sp_AddOrderItem (Captures Catalog Snapshots in SQL)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AddOrderItem
    @OrderId INT,
    @VariantId INT,
    @Quantity INT,
    @UnitPrice DECIMAL(18,2),
    @TotalPrice DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Quantity IS NULL OR @Quantity <= 0 OR @UnitPrice IS NULL OR @UnitPrice < 0
       OR @TotalPrice IS NULL OR @TotalPrice <> CONVERT(DECIMAL(18,2), @Quantity * @UnitPrice)
        THROW 51013, N'Order item amount is inconsistent.', 1;

    DECLARE @ProductName NVARCHAR(200),
            @SKU NVARCHAR(100),
            @ColorName NVARCHAR(100),
            @Size NVARCHAR(20);

    SELECT 
        @ProductName = p.Name,
        @SKU = v.SKU,
        @ColorName = c.Color,
        @Size = v.Size
    FROM dbo.ProductVariants v
    INNER JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = c.ProductId
    WHERE v.Id = @VariantId;

    INSERT INTO dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice, ProductName, SKU, ColorName, Size)
    VALUES (@OrderId, @VariantId, @Quantity, @UnitPrice, @ProductName, @SKU, @ColorName, @Size);
END;

GO

-- Stored Procedure (2): sp_AddProductColor
CREATE OR ALTER PROCEDURE dbo.sp_AddProductColor
    @ProductId INT,
    @Color NVARCHAR(50),
    @ColorHex NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.ProductColors WHERE ProductId = @ProductId AND Color = @Color)
    BEGIN
        UPDATE dbo.ProductColors
        SET ColorHex = @ColorHex
        WHERE ProductId = @ProductId AND Color = @Color;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex)
        VALUES (@ProductId, @Color, @ColorHex);
    END

    SELECT Id, ProductId, Color, ColorHex, CreatedAt
    FROM dbo.ProductColors
    WHERE ProductId = @ProductId AND Color = @Color;
END;

GO

-- Stored Procedure (3): sp_AddProductReview
CREATE OR ALTER PROCEDURE dbo.sp_AddProductReview
    @ProductId INT,
    @UserId INT = NULL,
    @OrderId INT = NULL,
    @ReviewerName NVARCHAR(100),
    @Rating INT,
    @Title NVARCHAR(150) = NULL,
    @Comment NVARCHAR(MAX),
    @IsVerifiedPurchase BIT = 0,
    @NewReviewId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Verified BIT = 0;
        IF @UserId IS NOT NULL AND @OrderId IS NOT NULL AND EXISTS
        (
            SELECT 1
            FROM dbo.Orders o
            JOIN dbo.OrderItems oi ON oi.OrderId = o.Id
            JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE o.Id = @OrderId AND o.UserId = @UserId
              AND o.Status = N'Completed' AND pc.ProductId = @ProductId
        )
            SET @Verified = 1;

        IF (@OrderId IS NOT NULL OR @IsVerifiedPurchase = 1) AND @Verified = 0
            THROW 51014, N'Linked completed purchase not found.', 1;

        INSERT INTO dbo.ProductReviews (
            ProductId, UserId, OrderId, ReviewerName, Rating, Title, Comment, IsVerifiedPurchase, IsHidden
        )
        VALUES (
            @ProductId, @UserId, @OrderId, @ReviewerName, @Rating, @Title, @Comment, @Verified, 0
        );

        SET @NewReviewId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

GO

-- Stored Procedure (4): sp_AdminAddProductGalleryImage
-- 2. Add Stored Procedure for Product Gallery Image
CREATE OR ALTER PROCEDURE dbo.sp_AdminAddProductGalleryImage
    @ProductId INT,
    @ImageUrl NVARCHAR(500),
    @AltText NVARCHAR(200) = NULL,
    @DisplayOrder INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Id = @ProductId)
        THROW 52107, N'Invalid product ID for gallery.', 1;

    INSERT INTO dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder)
    VALUES (@ProductId, @ImageUrl, @AltText, @DisplayOrder);

    SELECT SCOPE_IDENTITY() AS GalleryImageId;
END;

GO

-- Stored Procedure (5): sp_AdminAdjustStock
CREATE OR ALTER PROCEDURE dbo.sp_AdminAdjustStock
    @VariantId INT,
    @QuantityChanged INT,
    @UserId INT = NULL,
    @ReferenceNumber NVARCHAR(100),
    @Notes NVARCHAR(500),
    @NewStock INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @QuantityChanged <= 0
        THROW 52004, N'Stock In quantity must be a positive integer greater than zero.', 1;
    IF NULLIF(LTRIM(RTRIM(@Notes)), N'') IS NULL
        THROW 52005, N'A reference note or reason is required for stock addition.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldStock INT, @Reserved INT, @Reorder INT, @InventoryId INT;
        SELECT
            @OldStock = CurrentStock,
            @Reserved = ReservedStock,
            @Reorder = ReorderPoint,
            @InventoryId = Id
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        IF @OldStock IS NULL
            THROW 52006, N'Inventory record not found for variant.', 1;

        SET @NewStock = @OldStock + @QuantityChanged;

        UPDATE dbo.Inventories
        SET CurrentStock = @NewStock,
            LastRestockedAt = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @InventoryId;

        INSERT dbo.StockAuditLogs
            (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
        VALUES
            (@VariantId, @UserId, N'RESTOCK', @OldStock, @QuantityChanged, @ReferenceNumber, @Notes);

        IF @NewStock - @Reserved > @Reorder
        BEGIN
            UPDATE dbo.RestockAlerts
            SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
            WHERE InventoryId = @InventoryId AND IsDismissed = 0;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

-- Stored Procedure (6): sp_AdminBrandInventoryDetails
CREATE OR ALTER PROCEDURE dbo.sp_AdminBrandInventoryDetails
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.Name AS Brand, p.Id AS ProductId, v.Id AS VariantId,
           p.Name AS ProductName, cat.Name AS CategoryName, p.MainImageUrl,
           c.Color, v.Size, v.SKU, i.CurrentStock AS OnHandStock,
           i.CurrentStock - i.ReservedStock AS AvailableStock,
           i.ReorderPoint,
           CASE WHEN i.CurrentStock - i.ReservedStock <= 0 THEN N'out_of_stock'
                WHEN i.CurrentStock - i.ReservedStock <= i.ReorderPoint THEN N'low_stock'
                ELSE N'in_stock' END AS StockStatus
    FROM dbo.v_VisibleInventories i
    JOIN dbo.v_VisibleProductVariants v ON v.Id = i.VariantId
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;

GO

-- Stored Procedure (7): sp_AdminBrands
CREATE OR ALTER PROCEDURE dbo.sp_AdminBrands
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name, LogoUrl, Website, IsActive FROM dbo.Brands ORDER BY Name;
END;

GO

-- Stored Procedure (8): sp_AdminCatalogProducts
CREATE OR ALTER PROCEDURE dbo.sp_AdminCatalogProducts
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');

    SELECT 
        p.Id, 
        p.Name, 
        p.Slug, 
        p.Description, 
        p.CategoryId, 
        c.Name AS Category,
        p.BrandId, 
        b.Name AS Brand, 
        p.BasePrice, 
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        p.DiscountIsActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        p.MainImageUrl, 
        p.IsActive, 
        p.PublicationStatus,
        p.CreatedAt,
        (
            SELECT COUNT(*) 
            FROM dbo.ProductVariants v 
            JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId 
            WHERE pc.ProductId = p.Id AND v.IsActive = 1
        ) AS VariantCount
    FROM dbo.Products p 
    JOIN dbo.Categories c ON c.Id = p.CategoryId 
    JOIN dbo.Brands b ON b.Id = p.BrandId
    WHERE @Search IS NULL 
       OR p.Name LIKE N'%' + @Search + N'%' 
       OR p.Slug LIKE N'%' + @Search + N'%'
       OR b.Name LIKE N'%' + @Search + N'%'
       OR c.Name LIKE N'%' + @Search + N'%'
       OR EXISTS (
           SELECT 1 
           FROM dbo.ProductVariants v 
           JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId 
           WHERE pc.ProductId = p.Id AND v.SKU LIKE N'%' + @Search + N'%'
       )
    ORDER BY p.Id DESC;
END;

GO

-- Stored Procedure (9): sp_AdminCategories
CREATE OR ALTER PROCEDURE dbo.sp_AdminCategories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Name, Slug, Description, DisplayOrder, IsActive FROM dbo.Categories ORDER BY DisplayOrder, Name;
END;

GO

-- Stored Procedure (10): sp_AdminClearProductGallery
-- 4. Clear Product Gallery Images
CREATE OR ALTER PROCEDURE dbo.sp_AdminClearProductGallery
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.ProductGalleryImages WHERE ProductId = @ProductId;
END;

GO

-- Stored Procedure (11): sp_AdminColors
-- 2. Retrieve product colors for admin API
CREATE OR ALTER PROCEDURE dbo.sp_AdminColors
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.Id, c.ProductId, c.Color, c.ColorHex, c.ColorType, c.GradientAngle,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 1) AS Stop1,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 2) AS Stop2,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 3) AS Stop3,
           (SELECT ColorHex FROM dbo.ProductColorStops WHERE ProductColorId = c.Id AND StopOrder = 4) AS Stop4
    FROM dbo.ProductColors c
    WHERE c.ProductId = @ProductId
    ORDER BY c.Color;
END;

GO

-- Stored Procedure (12): sp_AdminCreateProductWithVariants
-- ----------------------------------------------------------------------------
-- 14. Update Procedure: dbo.sp_AdminCreateProductWithVariants
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminCreateProductWithVariants
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX),
    @RidingStyle NVARCHAR(50) = NULL, -- Deprecated, kept optional
    @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT = 0,
    @DiscountType NVARCHAR(20) = N'PERCENTAGE',
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @DiscountStartDate DATETIME2 = NULL,
    @DiscountEndDate DATETIME2 = NULL,
    @MainImageUrl NVARCHAR(500),
    @VariantsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0
        THROW 52301, N'Invalid product basic details.', 1;

    BEGIN TRANSACTION;

    INSERT INTO dbo.Products (
        CategoryId, BrandId, Name, Slug, Description, BasePrice,
        DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
        MainImageUrl, IsActive, PublicationStatus, CreatedAt, UpdatedAt
    )
    VALUES (
        @CategoryId, @BrandId, @Name, @Slug, @Description, @BasePrice,
        ISNULL(@DiscountPercentage, 0), ISNULL(@DiscountType, N'PERCENTAGE'), ISNULL(@DiscountAmount, 0.00),
        @DiscountStartDate, @DiscountEndDate, 1,
        @MainImageUrl, 1, N'Published', SYSUTCDATETIME(), SYSUTCDATETIME()
    );

    DECLARE @ProductId INT = SCOPE_IDENTITY();

    -- Parse and insert variants JSON if provided
    DECLARE @ParsedVariants TABLE (
        Color NVARCHAR(100),
        ColorHex NVARCHAR(20),
        Size NVARCHAR(20),
        SKU NVARCHAR(100),
        PriceAdjustment DECIMAL(18,2),
        Stock INT,
        ReorderPoint INT
    );

    IF @VariantsJson IS NOT NULL AND ISJSON(@VariantsJson) = 1
    BEGIN
        INSERT INTO @ParsedVariants (Color, ColorHex, Size, SKU, PriceAdjustment, Stock, ReorderPoint)
        SELECT 
            Color,
            ColorHex,
            Size,
            SKU,
            ISNULL(PriceAdjustment, 0.00),
            ISNULL(Stock, 0),
            ISNULL(ReorderPoint, 5)
        FROM OPENJSON(@VariantsJson)
        WITH (
            Color NVARCHAR(100) '$.Color',
            ColorHex NVARCHAR(20) '$.ColorHex',
            Size NVARCHAR(20) '$.Size',
            SKU NVARCHAR(100) '$.SKU',
            PriceAdjustment DECIMAL(18,2) '$.PriceAdjustment',
            Stock INT '$.Stock',
            ReorderPoint INT '$.ReorderPoint'
        );
    END;

    -- Color deduplication mapping
    DECLARE @ColorMap TABLE (Color NVARCHAR(100), ColorHex NVARCHAR(20), ColorId INT);

    INSERT INTO dbo.ProductColors (ProductId, Color, ColorHex)
    OUTPUT inserted.Color, inserted.ColorHex, inserted.Id INTO @ColorMap (Color, ColorHex, ColorId)
    SELECT DISTINCT @ProductId, Color, ColorHex
    FROM @ParsedVariants;

    -- Insert variants and stock
    DECLARE @VariantId INT, @Size NVARCHAR(20), @SKU NVARCHAR(100), @Adj DECIMAL(18,2), @Stock INT, @Reorder INT, @MappedColorId INT;

    DECLARE cur_vars CURSOR LOCAL FAST_FORWARD FOR 
        SELECT m.ColorId, v.Size, v.SKU, v.PriceAdjustment, v.Stock, v.ReorderPoint
        FROM @ParsedVariants v
        JOIN @ColorMap m ON m.Color = v.Color;

    OPEN cur_vars;
    FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive)
        VALUES (@MappedColorId, @SKU, @Size, @Adj, 1);
        SET @VariantId = SCOPE_IDENTITY();

        INSERT INTO dbo.Inventories (VariantId, CurrentStock, ReservedStock, ReorderPoint, LastRestockedAt)
        VALUES (@VariantId, @Stock, 0, @Reorder, SYSUTCDATETIME());

        IF @Stock > 0
        BEGIN
            INSERT INTO dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
            VALUES (@VariantId, 1, 'STOCK_IN', 0, @Stock, 'INIT-CATALOG', 'Initial stock on product creation');
        END;

        FETCH NEXT FROM cur_vars INTO @MappedColorId, @Size, @SKU, @Adj, @Stock, @Reorder;
    END;

    CLOSE cur_vars;
    DEALLOCATE cur_vars;

    COMMIT TRANSACTION;

    SELECT @ProductId AS Id;
END;

GO

-- Stored Procedure (13): sp_AdminDailySettledOrders
-- 2. STORED PROCEDURE: sp_AdminDailySettledOrders
-- Updated: ItemCount uses SUM(oi.Quantity)
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_AdminDailySettledOrders
    @TargetDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH OrderSales AS (
        SELECT 
            o.Id,
            o.OrderNumber,
            o.CustomerName,
            o.CustomerEmail,
            o.CustomerPhone,
            o.OrderSource,
            o.Status,
            (o.Subtotal - o.DiscountAmount) - ISNULL(
                (SELECT SUM(ISNULL(rr.RefundAmount, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed'), 0.00
            ) AS NetMerchandiseRevenue,
            o.CreatedAt,
            o.ShippingMethod,
            o.ShippingFee,
            o.ShippingRegion,
            o.ShippingAddress,
            o.ShippingBarangay,
            o.ShippingCity,
            o.ShippingProvince,
            o.ShippingPostalCode,
            o.Courier,
            o.TrackingNumber,
            o.DeliveryNotes,
            ISNULL((SELECT SUM(oi.Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id), 0) AS ItemCount,
            p.Status AS PaymentStatus,
            p.PaymentGateway AS PaymentMethod,
            p.PaidAt
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY OrderId ORDER BY PaidAt DESC, Id DESC) AS PaymentRank
            FROM dbo.Payments WHERE Status = N'Completed') p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE p.PaymentRank = 1
          AND o.Status IN (N'Completed', N'Delivered')
          AND CONVERT(DATE, p.PaidAt) = @TargetDate
    )
    SELECT 
        Id,
        OrderNumber,
        CustomerName,
        CustomerEmail,
        CustomerPhone,
        OrderSource,
        Status,
        NetMerchandiseRevenue AS TotalAmount,
        CreatedAt,
        ShippingMethod,
        ShippingFee,
        ShippingRegion,
        ShippingAddress,
        ShippingBarangay,
        ShippingCity,
        ShippingProvince,
        ShippingPostalCode,
        Courier,
        TrackingNumber,
        DeliveryNotes,
        ItemCount,
        PaymentStatus,
        PaymentMethod
    FROM OrderSales
    ORDER BY PaidAt DESC, Id DESC;
END;

GO

-- Stored Procedure (14): sp_AdminDashboard
CREATE OR ALTER PROCEDURE dbo.sp_AdminDashboard
    @IncludeRevenue BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodayStart DATETIME2 = CONVERT(DATETIME2, CONVERT(DATE, SYSUTCDATETIME()));
    DECLARE @TomorrowStart DATETIME2 = DATEADD(DAY, 1, @TodayStart);
    DECLARE @YesterdayStart DATETIME2 = DATEADD(DAY, -1, @TodayStart);

    ;WITH StockAtTodayStart AS
    (
        SELECT
            i.Id,
            i.ReservedStock,
            i.ReorderPoint,
            CASE
                WHEN v.CreatedAt >= @TodayStart THEN 0
                ELSE i.CurrentStock - ISNULL(SUM(CASE WHEN l.CreatedAt >= @TodayStart THEN l.QuantityChanged ELSE 0 END), 0)
            END AS PreviousStock
        FROM dbo.v_VisibleInventories i
        JOIN dbo.v_VisibleProductVariants v ON v.Id = i.VariantId
        LEFT JOIN dbo.v_VisibleStockAuditLogs l ON l.VariantId = i.VariantId
        GROUP BY i.Id, i.CurrentStock, i.ReservedStock, i.ReorderPoint, v.CreatedAt
    ),
    OrderSales AS (
        SELECT 
            p.PaidAt,
            -- Merchandise sales exclude shipping and completed manual refunds.
            (o.Subtotal - o.DiscountAmount) - ISNULL(
                (SELECT SUM(ISNULL(rr.RefundAmount, 0.00))
                 FROM dbo.ReturnRequests rr
                 JOIN dbo.OrderItems oi ON rr.OrderItemId = oi.Id
                 WHERE rr.OrderId = o.Id AND rr.RequestType = N'RETURN' AND rr.ResolutionType = N'REFUND' AND rr.Status = N'Completed'), 0.00
            ) AS NetRevenue
        FROM (SELECT OrderId, MAX(PaidAt) AS PaidAt FROM dbo.Payments WHERE Status = N'Completed' GROUP BY OrderId) p
        JOIN dbo.Orders o ON o.Id = p.OrderId
        WHERE 1 = 1
          AND o.Status IN (N'Completed', N'Delivered')
    )
    SELECT
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.v_VisibleInventories) AS OnHandStock,
        (SELECT ISNULL(SUM(CurrentStock - ReservedStock), 0) FROM dbo.v_VisibleInventories) AS AvailableStock,
        (SELECT COUNT(*) FROM dbo.v_VisibleInventories WHERE IsLowStock = 1) AS LowStockCount,
        (SELECT COUNT(*) FROM dbo.v_VisibleInventories WHERE CurrentStock - ReservedStock = 0) AS OutOfStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE Status IN (N'PendingPayment', N'Processing', N'ReadyForPickup')) AS ActiveOrders,
        (SELECT ISNULL(SUM(PreviousStock), 0) FROM StockAtTodayStart) AS YesterdayOnHandStock,
        (SELECT ISNULL(SUM(CASE WHEN PreviousStock > ReservedStock THEN PreviousStock - ReservedStock ELSE 0 END), 0)
         FROM StockAtTodayStart) AS YesterdayAvailableStock,
        (SELECT COUNT(*) FROM StockAtTodayStart WHERE PreviousStock > 0 AND PreviousStock - ReservedStock <= ReorderPoint) AS YesterdayLowStockCount,
        (SELECT COUNT(*) FROM dbo.Orders WHERE CreatedAt >= @YesterdayStart AND CreatedAt < @TodayStart) AS YesterdayOrdersCount,
        CASE WHEN @IncludeRevenue = 1 THEN
            ISNULL((SELECT SUM(CASE WHEN NetRevenue > 0 THEN NetRevenue ELSE 0.00 END) 
                    FROM OrderSales 
                    WHERE PaidAt >= @TodayStart AND PaidAt < @TomorrowStart), 0.00)
        ELSE NULL END AS TodayRevenue,
        CASE WHEN @IncludeRevenue = 1 THEN
            ISNULL((SELECT SUM(CASE WHEN NetRevenue > 0 THEN NetRevenue ELSE 0.00 END) 
                    FROM OrderSales 
                    WHERE PaidAt >= @YesterdayStart AND PaidAt < @TodayStart), 0.00)
        ELSE NULL END AS YesterdayRevenue;
END;

GO

-- Stored Procedure (15): sp_AdminDeleteProduct
-- ----------------------------------------------------------------------------
-- 12. Update Procedure: dbo.sp_AdminDeleteProduct
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminDeleteProduct
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Id = @ProductId)
    BEGIN
        THROW 52020, N'Product not found.', 1;
    END

    BEGIN TRANSACTION;

    DECLARE @ProductName NVARCHAR(200);
    SELECT @ProductName = Name FROM dbo.Products WHERE Id = @ProductId;

    -- Check if product variants have historical customer orders
    DECLARE @HasOrders BIT = 0;
    IF EXISTS (
        SELECT 1 
        FROM dbo.OrderItems oi
        JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId
    )
    BEGIN
        SET @HasOrders = 1;
    END

    IF @HasOrders = 1
    BEGIN
        -- Soft delete: Deactivate the product and its variants to preserve financial order history
        UPDATE dbo.Products 
        SET IsActive = 0, 
            PublicationStatus = N'Archived',
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @ProductId;

        UPDATE pv
        SET pv.IsActive = 0
        FROM dbo.ProductVariants pv
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId;

        COMMIT TRANSACTION;

        SELECT 
            @ProductId AS ProductId,
            @ProductName AS ProductName,
            N'SoftDeleted' AS Status,
            N'Product has historical order transactions. It has been deactivated and archived.' AS Message;
    END
    ELSE
    BEGIN
        -- Hard delete: No order history exists, safely remove child records in dependency order
        DELETE FROM dbo.StockAuditLogs 
        WHERE VariantId IN (
            SELECT pv.Id 
            FROM dbo.ProductVariants pv
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE pc.ProductId = @ProductId
        );

        DELETE FROM dbo.Inventories 
        WHERE VariantId IN (
            SELECT pv.Id 
            FROM dbo.ProductVariants pv
            JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
            WHERE pc.ProductId = @ProductId
        );

        DELETE FROM dbo.ProductGalleryImages 
        WHERE ProductId = @ProductId;

        DELETE FROM dbo.ProductSpecificationValues 
        WHERE ProductId = @ProductId;

        DELETE pv
        FROM dbo.ProductVariants pv
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        WHERE pc.ProductId = @ProductId;

        DELETE FROM dbo.ProductColorStops
        WHERE ProductColorId IN (SELECT Id FROM dbo.ProductColors WHERE ProductId = @ProductId);

        DELETE FROM dbo.ProductColors 
        WHERE ProductId = @ProductId;

        DELETE FROM dbo.Products 
        WHERE Id = @ProductId;

        COMMIT TRANSACTION;

        SELECT 
            @ProductId AS ProductId,
            @ProductName AS ProductName,
            N'Deleted' AS Status,
            N'Product and its configuration were successfully deleted.' AS Message;
    END
END;

GO

-- Stored Procedure (16): sp_AdminGallery
CREATE OR ALTER PROCEDURE dbo.sp_AdminGallery @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, ProductId, ImageUrl, AltText, DisplayOrder, IsActive
    FROM dbo.ProductGalleryImages WHERE ProductId = @ProductId ORDER BY DisplayOrder;
END;

GO

-- Stored Procedure (17): sp_AdminGetProductComplete
CREATE OR ALTER PROCEDURE dbo.sp_AdminGetProductComplete
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result 1: Product Header Info
    SELECT p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description,
           p.BasePrice, p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
           p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
           p.MainImageUrl, p.IsActive, p.PublicationStatus,
           b.Name AS BrandName, c.Name AS CategoryName
    FROM dbo.Products p
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    WHERE p.Id = @ProductId;

    -- Result 2: Product Specifications
    SELECT d.SpecificationKey, d.DisplayName, v.SpecificationValue,
           ISNULL(cs.DisplayOrder, 99) AS DisplayOrder
    FROM dbo.ProductSpecificationValues v
    INNER JOIN dbo.SpecificationDefinitions d ON d.Id = v.SpecificationId
    LEFT JOIN dbo.CategorySpecifications cs ON cs.SpecificationId = d.Id AND cs.CategoryId = (SELECT CategoryId FROM dbo.Products WHERE Id = @ProductId)
    WHERE v.ProductId = @ProductId
    ORDER BY ISNULL(cs.DisplayOrder, 99) ASC, d.DisplayName ASC;

    -- Result 3: Product Colors
    SELECT Id, Color, ColorHex, ColorType, GradientAngle
    FROM dbo.ProductColors
    WHERE ProductId = @ProductId
    ORDER BY Id ASC;

    -- Result 4: Product Variants
    SELECT pv.Id, pv.Id AS VariantId, pv.ProductColorId, pc.Color, pc.ColorHex, pv.SKU, pv.Size, pv.PriceAdjustment,
           ISNULL(i.CurrentStock, 0) AS CurrentStock,
           ISNULL(i.ReorderPoint, 5) AS ReorderPoint,
           pv.IsActive
    FROM dbo.ProductVariants pv
    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    LEFT JOIN dbo.Inventories i ON i.VariantId = pv.Id
    WHERE pc.ProductId = @ProductId
    ORDER BY pv.Id ASC;

    -- Result 5: Gallery Images
    SELECT Id, ImageUrl, AltText, DisplayOrder, IsActive
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @ProductId
    ORDER BY DisplayOrder ASC, Id ASC;
END;

GO

-- Stored Procedure (18): sp_AdminGetReturnRequests
CREATE OR ALTER PROCEDURE dbo.sp_AdminGetReturnRequests
    @Status NVARCHAR(30) = N'ALL',
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        rma.Id,
        rma.RmaNumber,
        rma.OrderId,
        o.OrderNumber,
        o.CustomerEmail,
        o.CustomerPhone,
        ISNULL(NULLIF(LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))), N''), ISNULL(o.CustomerName, N'Store Customer')) AS CustomerName,
        rma.OrderItemId,
        oi.VariantId,
        p.Name AS ProductName,
        pc.Color AS ColorName,
        pv.Size,
        oi.Quantity,
        oi.UnitPrice,
        rma.RequestType,
        rma.Reason,
        rma.ExchangeVariantId,
        rma.CustomerNotes,
        rma.Status,
        rma.ResolutionType,
        rma.RefundAmount,
        rma.Restocked,
        rma.AdminNotes,
        rma.ProcessedBy,
        LTRIM(RTRIM(CONCAT(pb.FirstName, N' ', pb.LastName))) AS ProcessedByName,
        rma.CreatedAt,
        rma.UpdatedAt
    FROM dbo.ReturnRequests rma
    INNER JOIN dbo.Orders o ON o.Id = rma.OrderId
    INNER JOIN dbo.OrderItems oi ON oi.Id = rma.OrderItemId
    INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    LEFT JOIN dbo.Users u ON u.Id = rma.UserId
    LEFT JOIN dbo.Users pb ON pb.Id = rma.ProcessedBy
    WHERE (@Status = N'ALL' OR rma.Status = @Status)
      AND (@Search IS NULL OR @Search = N'' OR 
           rma.RmaNumber LIKE N'%' + @Search + N'%' OR 
           o.OrderNumber LIKE N'%' + @Search + N'%' OR 
           o.CustomerEmail LIKE N'%' + @Search + N'%' OR 
           p.Name LIKE N'%' + @Search + N'%')
    ORDER BY 
        CASE WHEN rma.Status = N'Pending' THEN 0 ELSE 1 END,
        rma.CreatedAt DESC;
END;

GO

-- Stored Procedure (19): sp_AdminGetReviews
CREATE OR ALTER PROCEDURE dbo.sp_AdminGetReviews
    @Filter NVARCHAR(20) = N'ALL', -- 'ALL', 'PUBLISHED', 'HIDDEN', 'REPORTED'
    @Search NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        r.Id,
        r.ProductId,
        p.Name AS ProductName,
        b.Name AS BrandName,
        r.UserId,
        r.OrderId,
        r.ReviewerName,
        r.Rating,
        r.Title,
        r.Comment,
        r.IsVerifiedPurchase,
        r.IsHidden,
        (SELECT COUNT(*) FROM dbo.ReviewReports rep WHERE rep.ReviewId = r.Id) AS FlagCount,
        r.CreatedAt
    FROM dbo.ProductReviews r
    INNER JOIN dbo.Products p ON p.Id = r.ProductId
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    WHERE (@Filter = N'ALL' OR
           (@Filter = N'PUBLISHED' AND r.IsHidden = 0) OR
           (@Filter = N'HIDDEN' AND r.IsHidden = 1) OR
           (@Filter = N'REPORTED' AND EXISTS (SELECT 1 FROM dbo.ReviewReports rep WHERE rep.ReviewId = r.Id)))
      AND (@Search IS NULL OR @Search = N'' OR 
           r.ReviewerName LIKE N'%' + @Search + N'%' OR 
           r.Title LIKE N'%' + @Search + N'%' OR 
           r.Comment LIKE N'%' + @Search + N'%' OR 
           p.Name LIKE N'%' + @Search + N'%')
    ORDER BY 
        CASE WHEN @Filter = N'REPORTED' THEN (SELECT COUNT(*) FROM dbo.ReviewReports rep WHERE rep.ReviewId = r.Id) ELSE 0 END DESC,
        r.CreatedAt DESC;
END;

GO

-- Stored Procedure (20): sp_AdminGlobalSearch
CREATE OR ALTER PROCEDURE dbo.sp_AdminGlobalSearch
    @Query NVARCHAR(100),
    @Limit INT = 8
AS
BEGIN
    SET NOCOUNT ON;
    SET @Query = LTRIM(RTRIM(@Query));
    IF @Query IS NULL OR LEN(@Query) < 1
    BEGIN
        SELECT TOP 0 '' AS Category, '' AS Title, '' AS Subtitle, '' AS Url, '' AS Badge;
        RETURN;
    END;

    -- 1. Point of Sale (Direct POS Action for sellable in-stock items)
    SELECT TOP (@Limit)
        'Point of Sale' AS Category,
        CONCAT(b.Name, ' ', p.Name, ' (', c.Color, ' - ', v.Size, ')') AS Title,
        CONCAT(NCHAR(8369), FORMAT(dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive), 'N2'), NCHAR(32), NCHAR(8226), NCHAR(32), ISNULL(i.CurrentStock, 0), ' in stock', NCHAR(32), NCHAR(8226), NCHAR(32), 'SKU: ', v.SKU) AS Subtitle,
        CONCAT('/Pages/Admin/POS/POS.aspx?search=', v.SKU) AS Url,
        'Sell in POS' AS Badge
    FROM dbo.v_VisibleProductVariants v
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.v_VisibleInventories i ON i.VariantId = v.Id
    WHERE v.IsActive = 1 AND p.IsActive = 1 AND ISNULL(i.CurrentStock, 0) > 0
      AND (
          p.Name LIKE '%' + @Query + '%'
          OR b.Name LIKE '%' + @Query + '%'
          OR CONCAT(b.Name, ' ', p.Name) LIKE '%' + @Query + '%'
          OR CONCAT(b.Name, ' ', p.Name, ' ', c.Color) LIKE '%' + @Query + '%'
          OR v.SKU LIKE '%' + @Query + '%'
          OR c.Color LIKE '%' + @Query + '%'
      )

    UNION ALL

    -- 2. Brands Matching Query
    SELECT TOP (@Limit)
        'Brands' AS Category,
        b.Name AS Title,
        CONCAT((SELECT COUNT(*) FROM dbo.v_VisibleProducts p WHERE p.BrandId = b.Id), ' Helmet Models in Catalog') AS Subtitle,
        CONCAT('/Pages/Admin/Inventory/Inventory.aspx?brand=', b.Name) AS Url,
        'Brand' AS Badge
    FROM dbo.Brands b
    WHERE b.Name LIKE '%' + @Query + '%'

    UNION ALL

    -- 3. Catalog Models
    SELECT TOP (@Limit)
        'Catalog' AS Category,
        CONCAT(b.Name, ' ', p.Name) AS Title,
        CONCAT(cat.Name, NCHAR(32), NCHAR(8226), NCHAR(32), 'Base: ', NCHAR(8369), FORMAT(p.BasePrice, 'N2')) AS Subtitle,
        CONCAT('/Pages/Admin/Catalog/Catalog.aspx?id=', p.Id) AS Url,
        b.Name AS Badge
    FROM dbo.v_VisibleProducts p
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    WHERE p.Name LIKE '%' + @Query + '%'
       OR b.Name LIKE '%' + @Query + '%'
       OR CONCAT(b.Name, ' ', p.Name) LIKE '%' + @Query + '%'

    UNION ALL

    -- 4. Inventory Variants (Color, Size, SKU)
    SELECT TOP (@Limit)
        'Inventory' AS Category,
        CONCAT(b.Name, ' ', p.Name, ' (', c.Color, ' - ', v.Size, ')') AS Title,
        CONCAT('Stock: ', ISNULL(i.CurrentStock,0), ' units', NCHAR(32), NCHAR(8226), NCHAR(32), 'SKU: ', v.SKU) AS Subtitle,
        CONCAT('/Pages/Admin/Inventory/Inventory.aspx?q=', v.SKU) AS Url,
        CASE WHEN ISNULL(i.CurrentStock,0) <= 0 THEN 'Out of Stock' 
             WHEN ISNULL(i.CurrentStock,0) <= ISNULL(i.ReorderPoint,3) THEN 'Low Stock' 
             ELSE 'In Stock' END AS Badge
    FROM dbo.v_VisibleProductVariants v
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.v_VisibleInventories i ON i.VariantId = v.Id
    WHERE p.Name LIKE '%' + @Query + '%'
       OR b.Name LIKE '%' + @Query + '%'
       OR CONCAT(b.Name, ' ', p.Name) LIKE '%' + @Query + '%'
       OR CONCAT(b.Name, ' ', p.Name, ' ', c.Color) LIKE '%' + @Query + '%'
       OR v.SKU LIKE '%' + @Query + '%'
       OR c.Color LIKE '%' + @Query + '%'

    UNION ALL

    -- 5. Orders
    SELECT TOP (@Limit)
        'Orders' AS Category,
        CONCAT(o.OrderNumber, ' - ', o.CustomerName) AS Title,
        CONCAT(NCHAR(8369), FORMAT(o.TotalAmount, 'N2'), NCHAR(32), NCHAR(8226), NCHAR(32), o.Status, NCHAR(32), NCHAR(8226), NCHAR(32), o.OrderSource) AS Subtitle,
        CONCAT('/Pages/Admin/Orders/Orders.aspx?q=', o.OrderNumber) AS Url,
        o.Status AS Badge
    FROM dbo.Orders o
    WHERE o.OrderNumber LIKE '%' + @Query + '%'
       OR o.CustomerName LIKE '%' + @Query + '%'
       OR o.CustomerEmail LIKE '%' + @Query + '%'
       OR o.CustomerPhone LIKE '%' + @Query + '%'

    UNION ALL

    -- 6. Users
    SELECT TOP (@Limit)
        'Users' AS Category,
        CONCAT(u.FirstName, N' ', u.LastName) AS Title,
        CONCAT(u.Email, NCHAR(32), NCHAR(8226), NCHAR(32), ISNULL(u.PhoneNumber, 'No phone')) AS Subtitle,
        CONCAT('/Pages/Admin/Users/Users.aspx?q=', u.Email) AS Url,
        r.Name AS Badge
    FROM dbo.Users u
    JOIN dbo.Roles r ON r.Id = u.RoleId
    WHERE CONCAT(u.FirstName, N' ', u.LastName) LIKE '%' + @Query + '%'
       OR u.Email LIKE '%' + @Query + '%'
       OR u.PhoneNumber LIKE '%' + @Query + '%'

    UNION ALL

    -- 7. Vouchers
    SELECT TOP (@Limit)
        'Vouchers' AS Category,
        v.Code AS Title,
        CONCAT(
            CASE WHEN v.DiscountType = 'PERCENTAGE' THEN CONCAT(FORMAT(v.DiscountValue, 'G29'), '% OFF')
                 ELSE CONCAT(NCHAR(8369), FORMAT(v.DiscountValue, 'N2'), ' OFF') END,
            NCHAR(32), NCHAR(8226), NCHAR(32),
            (SELECT COUNT(*) FROM dbo.VoucherRedemptions r WHERE r.VoucherId = v.Id AND r.ReleasedAt IS NULL), ' redeemed',
            CASE WHEN v.MinimumSpend > 0 THEN CONCAT(NCHAR(32), NCHAR(8226), NCHAR(32), 'Min. ', NCHAR(8369), FORMAT(v.MinimumSpend, 'N2')) ELSE '' END
        ) AS Subtitle,
        CONCAT('/Pages/Admin/Vouchers/Vouchers.aspx?q=', v.Code) AS Url,
        CASE WHEN v.IsActive = 1 AND (v.ExpiresAt IS NULL OR v.ExpiresAt > SYSUTCDATETIME()) AND (v.UsageLimit IS NULL OR (SELECT COUNT(*) FROM dbo.VoucherRedemptions r WHERE r.VoucherId = v.Id AND r.ReleasedAt IS NULL) < v.UsageLimit) THEN 'Active'
             ELSE 'Inactive' END AS Badge
    FROM dbo.Vouchers v
    WHERE v.Code LIKE '%' + @Query + '%'
       OR v.DiscountType LIKE '%' + @Query + '%'
       OR CAST(v.DiscountValue AS NVARCHAR(20)) LIKE '%' + @Query + '%'

    UNION ALL

    -- 8. Reviews
    SELECT TOP (@Limit)
        'Reviews' AS Category,
        CONCAT(r.ReviewerName, ' - ', p.Name, ' (', r.Rating, NCHAR(9733), ')') AS Title,
        CONCAT(
            ISNULL(r.Title, 'Review'), NCHAR(32), NCHAR(8226), NCHAR(32),
            SUBSTRING(r.Comment, 1, 60),
            CASE WHEN LEN(r.Comment) > 60 THEN '...' ELSE '' END
        ) AS Subtitle,
        CONCAT('/Pages/Admin/Reviews/Reviews.aspx?q=', r.ReviewerName) AS Url,
        CASE WHEN r.IsHidden = 1 THEN 'Hidden'
             ELSE 'Published' END AS Badge
    FROM dbo.ProductReviews r
    JOIN dbo.Products p ON p.Id = r.ProductId
    WHERE r.ReviewerName LIKE '%' + @Query + '%'
       OR p.Name LIKE '%' + @Query + '%'
       OR ISNULL(r.Title, '') LIKE '%' + @Query + '%'
       OR r.Comment LIKE '%' + @Query + '%'

    UNION ALL

    -- 9. Returns
    SELECT TOP (@Limit)
        'Returns' AS Category,
        CONCAT(ret.RmaNumber, ' - ', o.CustomerName) AS Title,
        CONCAT(
            ret.RequestType, NCHAR(32), NCHAR(8226), NCHAR(32),
            ret.Reason, NCHAR(32), NCHAR(8226), NCHAR(32),
            o.OrderNumber
        ) AS Subtitle,
        CONCAT('/Pages/Admin/Returns/Returns.aspx?q=', ret.RmaNumber) AS Url,
        ret.Status AS Badge
    FROM dbo.ReturnRequests ret
    JOIN dbo.Orders o ON o.Id = ret.OrderId
    WHERE ret.RmaNumber LIKE '%' + @Query + '%'
       OR o.CustomerName LIKE '%' + @Query + '%'
       OR o.OrderNumber LIKE '%' + @Query + '%'
       OR ret.Reason LIKE '%' + @Query + '%'
       OR ret.RequestType LIKE '%' + @Query + '%';
END;

GO

-- Stored Procedure (21): sp_AdminInventoryProducts
-- ----------------------------------------------------------------------------
-- 10. Update Procedure: dbo.sp_AdminInventoryProducts
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryProducts
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = 'all'
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = 'all' SET @Brand = NULL;
    IF @Category = 'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = '' SET @StockStatus = 'all';

    SELECT 
        p.Id AS ProductId,
        p.Name AS ProductName,
        p.Slug,
        b.Id AS BrandId,
        b.Name AS BrandName,
        c.Id AS CategoryId,
        c.Name AS CategoryName,
        p.BasePrice,
        p.DiscountPercentage,
        CAST(p.BasePrice * (1.0 - (p.DiscountPercentage / 100.0)) AS DECIMAL(18,2)) AS EffectivePrice,
        p.MainImageUrl,
        p.IsActive,
        ISNULL(SUM(i.CurrentStock), 0) AS TotalStock,
        ISNULL(SUM(i.ReservedStock), 0) AS ReservedStock,
        ISNULL(SUM(i.CurrentStock), 0) - ISNULL(SUM(i.ReservedStock), 0) AS AvailableStock,
        COUNT(DISTINCT pv.Id) AS VariantCount,
        ISNULL(MIN(pv.SKU), N'HC-DEFAULT') AS SampleSKU,
        CASE 
            WHEN ISNULL(SUM(i.CurrentStock), 0) <= 0 THEN 'out_of_stock'
            WHEN ISNULL(SUM(i.CurrentStock), 0) <= 15 THEN 'low_stock'
            ELSE 'in_stock'
        END AS StockStatus
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    LEFT JOIN dbo.v_VisibleProductColors pc ON pc.ProductId = p.Id
    LEFT JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id AND pv.IsActive = 1
    LEFT JOIN dbo.v_VisibleInventories i ON i.VariantId = pv.Id
    WHERE (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%' OR b.Name LIKE N'%' + @Search + N'%' OR pv.SKU LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR c.Name = @Category OR c.Slug = @Category)
    GROUP BY p.Id, p.Name, p.Slug, b.Id, b.Name, c.Id, c.Name, p.BasePrice, p.DiscountPercentage, p.MainImageUrl, p.IsActive
    HAVING (@StockStatus = 'all')
        OR (@StockStatus = 'in_stock' AND ISNULL(SUM(i.CurrentStock), 0) > 15)
        OR (@StockStatus = 'low_stock' AND ISNULL(SUM(i.CurrentStock), 0) > 0 AND ISNULL(SUM(i.CurrentStock), 0) <= 15)
        OR (@StockStatus = 'out_of_stock' AND ISNULL(SUM(i.CurrentStock), 0) <= 0)
    ORDER BY p.Id ASC;
END;

GO

-- Stored Procedure (22): sp_AdminInventoryReport
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryReport
AS
BEGIN
    SET NOCOUNT ON;
    SELECT b.Name AS Brand, COUNT(*) AS VariantCount, SUM(i.CurrentStock) AS OnHandStock,
           SUM(i.CurrentStock - i.ReservedStock) AS AvailableStock,
           SUM(CASE WHEN i.IsLowStock = 1 THEN 1 ELSE 0 END) AS LowStockCount
    FROM dbo.v_VisibleInventories i JOIN dbo.v_VisibleProductVariants v ON v.Id = i.VariantId
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId JOIN dbo.Brands b ON b.Id = p.BrandId
    GROUP BY b.Name ORDER BY b.Name;
END;

GO

-- Stored Procedure (23): sp_AdminInventoryTrend
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryTrend
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartCutoff DATETIME2 = CONVERT(DATETIME2, CONVERT(DATE, @StartDate));
    DECLARE @EndExclusive DATETIME2 = DATEADD(DAY, 1, CONVERT(DATETIME2, CONVERT(DATE, @EndDate)));

    IF @StartCutoff >= @EndExclusive
        THROW 52130, N'The inventory trend start date must be on or before the end date.', 1;

    ;WITH InventorySnapshots AS
    (
        SELECT
            i.VariantId,
            v.CreatedAt,
            p.IsActive AS ProductIsActive,
            v.IsActive AS VariantIsActive,
            CASE WHEN v.CreatedAt >= @StartCutoff THEN 0
                 ELSE i.CurrentStock - ISNULL(SUM(CASE WHEN l.CreatedAt >= @StartCutoff THEN l.QuantityChanged ELSE 0 END), 0)
            END AS StartStock,
            CASE WHEN v.CreatedAt >= @EndExclusive THEN 0
                 ELSE i.CurrentStock - ISNULL(SUM(CASE WHEN l.CreatedAt >= @EndExclusive THEN l.QuantityChanged ELSE 0 END), 0)
            END AS EndStock
        FROM dbo.v_VisibleInventories i
        JOIN dbo.v_VisibleProductVariants v ON v.Id = i.VariantId
        JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
        JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
        LEFT JOIN dbo.v_VisibleStockAuditLogs l ON l.VariantId = i.VariantId
        GROUP BY i.VariantId, i.CurrentStock, v.CreatedAt, p.IsActive, v.IsActive
    )
    SELECT
        CONVERT(INT, ISNULL(SUM(StartStock), 0)) AS StartTotalUnits,
        CONVERT(INT, ISNULL(SUM(EndStock), 0)) AS EndTotalUnits,
        CONVERT(INT, ISNULL(SUM(CASE WHEN CreatedAt < @StartCutoff AND ProductIsActive = 1 AND VariantIsActive = 1 THEN 1 ELSE 0 END), 0)) AS StartActiveSkus,
        CONVERT(INT, ISNULL(SUM(CASE WHEN CreatedAt < @EndExclusive AND ProductIsActive = 1 AND VariantIsActive = 1 THEN 1 ELSE 0 END), 0)) AS EndActiveSkus
    FROM InventorySnapshots;
END;

GO

-- Stored Procedure (24): sp_AdminInventoryVariants
-- ----------------------------------------------------------------------------
-- 1. Procedure: dbo.sp_AdminInventoryVariants
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminInventoryVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL,
    @StockStatus NVARCHAR(50) = N'all',
    @ProductId INT = NULL,
    @VariantId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    IF @Brand = N'all' SET @Brand = NULL;
    IF @Category = N'all' SET @Category = NULL;
    IF @StockStatus IS NULL OR LTRIM(RTRIM(@StockStatus)) = N'' SET @StockStatus = N'all';

    SELECT 
        v.Id AS VariantId, 
        p.Id AS ProductId, 
        b.Name AS BrandName,
        p.Name AS ProductName, 
        cat.Name AS CategoryName, 
        c.Color, 
        c.ColorHex,
        v.Size, 
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.ReservedStock, 0) AS ReservedStock,
        ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
        ISNULL(i.ReorderPoint, 3) AS ReorderPoint,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
            p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
            p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        v.SKU, 
        p.MainImageUrl,
        CASE 
            WHEN ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= 0 THEN N'out_of_stock'
            WHEN ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= ISNULL(i.ReorderPoint, 3) THEN N'low_stock'
            ELSE N'in_stock' 
        END AS StockStatus,
        v.IsActive,
        p.IsActive AS ProductIsActive,
        p.PublicationStatus
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.Products p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE (@ProductId IS NULL OR p.Id = @ProductId)
      AND (@VariantId IS NULL OR v.Id = @VariantId)
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%'
           OR b.Name LIKE N'%' + @Search + N'%' OR cat.Name LIKE N'%' + @Search + N'%'
           OR v.SKU LIKE N'%' + @Search + N'%' OR c.Color LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name) LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name, N' ', c.Color) LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name, N' ', c.Color, N' ', v.Size) LIKE N'%' + @Search + N'%'
           OR CONCAT(p.Name, N' ', c.Color) LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category OR cat.Slug = @Category)
      AND (
           (@StockStatus = N'all')
           OR (@StockStatus = N'active' AND v.IsActive = 1)
           OR (@StockStatus = N'inactive' AND v.IsActive = 0)
           OR (@StockStatus = N'in_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) > ISNULL(i.ReorderPoint, 3))
           OR (@StockStatus = N'low_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) BETWEEN 1 AND ISNULL(i.ReorderPoint, 3))
           OR (@StockStatus = N'out_of_stock' AND ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) <= 0)
      )
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;

GO

-- Stored Procedure (25): sp_AdminModerateReview
CREATE OR ALTER PROCEDURE dbo.sp_AdminModerateReview @ReviewId INT, @IsHidden BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.ProductReviews SET IsHidden = @IsHidden WHERE Id = @ReviewId;
    IF @@ROWCOUNT = 0 THROW 52007, N'Review not found.', 1;
    SELECT @ReviewId AS Id, @IsHidden AS IsHidden;
END;

GO

-- Stored Procedure (26): sp_AdminOrders
-- 1. STORED PROCEDURE: sp_AdminOrders
-- Updated: ItemCount uses SUM(oi.Quantity)
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_AdminOrders
    @Search NVARCHAR(100) = NULL,
    @Status NVARCHAR(50) = NULL,
    @Source NVARCHAR(30) = NULL,
    @Limit INT = 100,
    @OrderDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Limit)
        o.Id,
        o.OrderNumber,
        o.CustomerName,
        o.CustomerEmail,
        o.CustomerPhone,
        o.OrderSource,
        o.Status,
        o.TotalAmount,
        o.CreatedAt,
        o.ShippingMethod,
        o.ShippingFee,
        o.ShippingRegion,
        o.ShippingAddress,
        o.ShippingBarangay,
        o.ShippingCity,
        o.ShippingProvince,
        o.ShippingPostalCode,
        o.Courier,
        o.TrackingNumber,
        o.DeliveryNotes,
        ISNULL((SELECT SUM(oi.Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id), 0) AS ItemCount,
        (SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaymentStatus,
        (SELECT TOP 1 p.PaymentGateway FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaymentMethod
    FROM dbo.Orders o
    WHERE (@Status IS NULL OR o.Status = @Status)
      AND (@Source IS NULL OR o.OrderSource = @Source)
      AND (@OrderDate IS NULL OR (o.CreatedAt >= @OrderDate AND o.CreatedAt < DATEADD(DAY, 1, @OrderDate)))
      AND (@Search IS NULL OR o.OrderNumber LIKE N'%' + @Search + N'%'
           OR o.CustomerName LIKE N'%' + @Search + N'%'
           OR o.CustomerEmail LIKE N'%' + @Search + N'%'
           OR o.TrackingNumber LIKE N'%' + @Search + N'%'
           OR o.ShippingCity LIKE N'%' + @Search + N'%'
           OR EXISTS (SELECT 1 FROM dbo.Payments py WHERE py.OrderId = o.Id AND py.GatewayReference LIKE N'%' + @Search + N'%'))
    ORDER BY o.CreatedAt DESC, o.Id DESC;
END;

GO

-- Stored Procedure (27): sp_AdminPayments
CREATE OR ALTER PROCEDURE dbo.sp_AdminPayments @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) p.Id, o.OrderNumber, p.PaymentGateway, p.GatewayReference,
           p.Amount, p.Status, p.PaidAt, p.CreatedAt
    FROM dbo.Payments p JOIN dbo.Orders o ON o.Id = p.OrderId
    ORDER BY p.CreatedAt DESC, p.Id DESC;
END;

GO

-- Stored Procedure (28): sp_AdminProcessReturnRequest
CREATE OR ALTER PROCEDURE dbo.sp_AdminProcessReturnRequest
    @RmaId INT, @NewStatus NVARCHAR(30), @ResolutionType NVARCHAR(30) = NULL,
    @RefundAmount DECIMAL(18,2) = NULL, @RestockItem BIT = 0, @AdminNotes NVARCHAR(1000) = NULL,
    @ProcessedBy INT = NULL, @Success BIT OUTPUT, @ErrorMessage NVARCHAR(255) OUTPUT,
    @ExchangeVariantId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId
            WHERE u.Id = @ProcessedBy AND u.IsActive = 1 AND r.Name IN (N'Admin', N'Staff'))
            THROW 55010, N'Staff authorization is required.', 1;
        DECLARE @OldStatus NVARCHAR(30), @Type NVARCHAR(20), @ItemId INT, @OrderId INT, @Restocked BIT,
            @Number NVARCHAR(30), @VariantId INT, @ReplacementId INT, @Quantity INT, @OldStock INT, @NetItem DECIMAL(18,2);
        SELECT @OldStatus = Status, @Type = RequestType, @ItemId = OrderItemId, @OrderId = OrderId,
            @Restocked = Restocked, @Number = RmaNumber, @ReplacementId = ExchangeVariantId
        FROM dbo.ReturnRequests WITH (UPDLOCK, ROWLOCK) WHERE Id = @RmaId;
        IF @OldStatus IS NULL THROW 55011, N'Return request not found.', 1;
        SET @ReplacementId = COALESCE(@ExchangeVariantId, @ReplacementId);
        IF NOT ((@OldStatus = N'Pending' AND @NewStatus IN (N'Approved', N'Rejected', N'Cancelled')) OR
            (@OldStatus = N'Approved' AND @NewStatus IN (N'Received', N'Rejected', N'Cancelled')) OR
            (@OldStatus = N'Received' AND @NewStatus IN (N'Completed', N'Rejected', N'Cancelled')))
            THROW 55012, N'Approve and receive the item before completing its resolution.', 1;
        SELECT @VariantId = oi.VariantId, @Quantity = oi.Quantity,
            @NetItem = ROUND(oi.TotalPrice * (o.Subtotal - o.DiscountAmount) / NULLIF(o.Subtotal, 0), 2)
        FROM dbo.OrderItems oi JOIN dbo.Orders o ON o.Id = oi.OrderId WHERE oi.Id = @ItemId;
        SET @ResolutionType = COALESCE(@ResolutionType, CASE WHEN @Type = N'EXCHANGE' THEN N'REPLACEMENT' ELSE N'REFUND' END);
        IF (@Type = N'EXCHANGE' AND @ResolutionType <> N'REPLACEMENT') OR (@Type = N'RETURN' AND @ResolutionType <> N'REFUND')
            THROW 55013, N'Use replacement for exchanges and refund for returns.', 1;
        SET @RefundAmount = CASE WHEN @Type = N'EXCHANGE' THEN 0 ELSE COALESCE(@RefundAmount, @NetItem, 0) END;
        IF @RefundAmount < 0 OR @RefundAmount > ISNULL(@NetItem, 0)
            THROW 55014, N'Refund cannot exceed the discounted item amount.', 1;
        IF @RestockItem = 1 AND @NewStatus <> N'Completed'
            THROW 55015, N'Restock only after inspection when completing the resolution.', 1;
        IF @NewStatus = N'Completed' AND NULLIF(LTRIM(RTRIM(@AdminNotes)), N'') IS NULL
            THROW 55016, N'Record manual refund or replacement handover confirmation in notes.', 1;
        IF @NewStatus = N'Completed'
        BEGIN
            -- Lock both variants in a stable order for concurrent exchanges.
            SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
            WHERE VariantId = CASE WHEN @ReplacementId < @VariantId THEN @ReplacementId ELSE @VariantId END;
            IF @ReplacementId IS NOT NULL
                SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
                WHERE VariantId = CASE WHEN @ReplacementId < @VariantId THEN @VariantId ELSE @ReplacementId END;
            IF @RestockItem = 1 AND @Restocked = 0
            BEGIN
                SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @VariantId;
                IF @OldStock IS NULL THROW 55017, N'Return inventory is missing.', 1;
                UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK) SET CurrentStock = CurrentStock + @Quantity, UpdatedAt = SYSUTCDATETIME() WHERE VariantId = @VariantId;
                INSERT dbo.StockAuditLogs(VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
                VALUES(@VariantId, @ProcessedBy, N'RETURN', @OldStock, @Quantity, @Number, N'Inspected merchandise returned to sellable inventory.');
                SET @Restocked = 1;
            END;
            IF @Type = N'EXCHANGE'
            BEGIN
                IF @ReplacementId IS NULL THROW 55018, N'Choose a replacement variant before completing the exchange.', 1;
                IF NOT EXISTS (SELECT 1 FROM dbo.v_VisibleProductVariants v JOIN dbo.v_VisibleProductColors pc ON pc.Id = v.ProductColorId
                    JOIN dbo.v_VisibleProducts p ON p.Id = pc.ProductId JOIN dbo.OrderItems oi ON oi.Id = @ItemId
                    WHERE v.Id = @ReplacementId AND dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage,
                        p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) = oi.UnitPrice
                    AND p.Id = (SELECT originalColor.ProductId FROM dbo.ProductVariants original
                        JOIN dbo.ProductColors originalColor ON originalColor.Id = original.ProductColorId WHERE original.Id = @VariantId))
                    THROW 55019, N'This academic workflow supports equal-price replacements only.', 1;
                SELECT @OldStock = CurrentStock FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK) WHERE VariantId = @ReplacementId;
                UPDATE dbo.Inventories WITH (UPDLOCK, ROWLOCK) SET CurrentStock = CurrentStock - @Quantity, UpdatedAt = SYSUTCDATETIME()
                WHERE VariantId = @ReplacementId AND CurrentStock - ReservedStock >= @Quantity;
                IF @@ROWCOUNT <> 1 THROW 55020, N'Replacement has insufficient available stock.', 1;
                INSERT dbo.StockAuditLogs(VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
                VALUES(@ReplacementId, @ProcessedBy, N'ADJUSTMENT', @OldStock, -@Quantity, @Number, N'Equal-price exchange replacement handed over.');
            END;
        END;
        UPDATE dbo.ReturnRequests SET Status = @NewStatus, ResolutionType = @ResolutionType, RefundAmount = @RefundAmount,
            ExchangeVariantId = CASE WHEN @Type = N'EXCHANGE' THEN @ReplacementId ELSE NULL END,
            Restocked = @Restocked, AdminNotes = @AdminNotes, ProcessedBy = @ProcessedBy, UpdatedAt = SYSUTCDATETIME() WHERE Id = @RmaId;
        IF @NewStatus = N'Completed' AND @ReplacementId IS NOT NULL
        BEGIN
            UPDATE a SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
            FROM dbo.RestockAlerts a JOIN dbo.Inventories i ON i.Id = a.InventoryId
            WHERE i.VariantId = @ReplacementId AND a.IsDismissed = 0 AND i.IsLowStock = 0;
            INSERT dbo.RestockAlerts(InventoryId, Severity)
            SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock <= 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
            FROM dbo.Inventories i WITH (UPDLOCK, ROWLOCK) WHERE i.VariantId = @ReplacementId AND i.IsLowStock = 1
                AND NOT EXISTS (SELECT 1 FROM dbo.RestockAlerts a WITH (UPDLOCK, HOLDLOCK) WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);
        END;
        EXEC dbo.sp_RefreshOrderStockAlerts @OrderId;
        COMMIT TRANSACTION;
        SET @Success = 1; SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0; SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;

GO

-- Stored Procedure (29): sp_AdminRecentActivity
-- 3. STORED PROCEDURE: sp_AdminRecentActivity
-- Updates Review reference format to REV-<ReviewId> for targeted modal redirection
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_AdminRecentActivity 
    @Limit INT = 8,
    @Offset INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ActivityType, Reference, Detail, Actor, ActorRole, CreatedAt
    FROM (
        -- 1. Orders Placed & Status Updates
        SELECT 
            N'Order' AS ActivityType,
            o.OrderNumber AS Reference,
            CONCAT(
                CASE 
                    WHEN o.Status = N'PendingPayment' THEN N'Awaiting payment for '
                    WHEN o.Status = N'Processing' THEN N'Placed order for '
                    WHEN o.Status = N'ReadyForPickup' THEN N'Ready for pickup: '
                    WHEN o.Status = N'Shipped' THEN N'Dispatched for delivery: '
                    WHEN o.Status = N'Delivered' THEN N'Delivered to customer: '
                    WHEN o.Status = N'Completed' THEN N'Completed order: '
                    WHEN o.Status = N'Cancelled' THEN N'Cancelled order: '
                    ELSE CONCAT(o.Status, N': ')
                END,
                ISNULL((
                    SELECT STRING_AGG(CONCAT(p.Name, N' (', pc.Color, N', ', pv.Size, N') x', oi.Quantity), N', ')
                    FROM dbo.OrderItems oi
                    JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
                    JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
                    JOIN dbo.Products p ON p.Id = pc.ProductId
                    WHERE oi.OrderId = o.Id
                ), N'Items'),
                N' &bull; ',
                CASE WHEN o.ShippingMethod = N'Pickup' THEN N'Store Pickup' ELSE N'Door-to-Door Delivery' END,
                N' &bull; ',
                CASE 
                    WHEN pay.Status = N'Completed' THEN CONCAT(N'Paid via ', CASE WHEN UPPER(ISNULL(pay.PaymentGateway, N'')) = N'HITPAY' THEN N'QRPh' ELSE ISNULL(pay.PaymentGateway, N'Online Payment') END, N' (PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                    WHEN pay.PaymentGateway = N'CashOnDelivery' THEN CONCAT(N'Cash on Delivery (Pending, PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                    ELSE CONCAT(CASE WHEN UPPER(ISNULL(pay.PaymentGateway, N'')) = N'HITPAY' THEN N'QRPh' ELSE ISNULL(pay.PaymentGateway, N'Payment') END, N' (PHP ', FORMAT(o.TotalAmount, N'N2'), N')')
                END
            ) AS Detail,
            ISNULL(NULLIF(o.CustomerName, N''), N'Store Customer') AS Actor,
            CASE 
                WHEN o.OrderSource IN (N'INSTORE_POS', N'IN_STORE') THEN N'Staff'
                WHEN r.Name = N'Admin' THEN N'Admin'
                WHEN r.Name = N'Staff' THEN N'Staff'
                ELSE N'Customer'
            END AS ActorRole,
            COALESCE(o.UpdatedAt, o.CreatedAt) AS CreatedAt
        FROM dbo.Orders o
        LEFT JOIN dbo.Users u ON u.Id = o.UserId
        LEFT JOIN dbo.Roles r ON r.Id = u.RoleId
        LEFT JOIN (
            SELECT OrderId, PaymentGateway, Status,
                   ROW_NUMBER() OVER(PARTITION BY OrderId ORDER BY Id DESC) as rn
            FROM dbo.Payments
        ) pay ON pay.OrderId = o.Id AND pay.rn = 1

        UNION ALL

        -- 2. Stock Movements (Restocks, manual adjustments, damaged stock write-offs)
        SELECT 
            N'Stock' AS ActivityType,
            COALESCE(l.ReferenceNumber, v.SKU) AS Reference,
            CONCAT(
                CASE 
                    WHEN l.ChangeType = N'RESTOCK' THEN N'Restocked '
                    WHEN l.ChangeType = N'ADJUSTMENT' AND l.QuantityChanged >= 0 THEN N'Stock increased (+ '
                    WHEN l.ChangeType = N'ADJUSTMENT' AND l.QuantityChanged < 0 THEN N'Stock adjusted (- '
                    WHEN l.ChangeType = N'DAMAGED' THEN N'Stock written off (- '
                    WHEN l.ChangeType = N'RETURN' THEN N'Returned stock incremented (+ '
                    ELSE CONCAT(l.ChangeType, N' ')
                END,
                p.Name, N' (', pc.Color, N', ', v.Size, N')',
                N' &bull; Change: ',
                CASE WHEN l.QuantityChanged > 0 THEN CONCAT(N'+', l.QuantityChanged) ELSE CAST(l.QuantityChanged AS NVARCHAR(10)) END,
                N' &bull; Current Level: ',
                l.PreviousStock + l.QuantityChanged, N' units'
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Staff') AS Actor,
            CASE 
                WHEN r.Name = N'Admin' THEN N'Admin'
                WHEN r.Name = N'Customer' THEN N'Customer'
                ELSE N'Staff'
            END AS ActorRole,
            l.CreatedAt
        FROM dbo.StockAuditLogs l
        JOIN dbo.ProductVariants v ON v.Id = l.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        LEFT JOIN dbo.Users u ON u.Id = l.UserId
        LEFT JOIN dbo.Roles r ON r.Id = u.RoleId
        WHERE l.ChangeType IN (N'RESTOCK', N'ADJUSTMENT', N'DAMAGED', N'RETURN')

        UNION ALL

        -- 3. Return & Exchange RMAs (Submitted by Customer)
        SELECT 
            N'RMA' AS ActivityType,
            rma.RmaNumber AS Reference,
            CONCAT(
                N'Submitted ', 
                CASE WHEN rma.RequestType = N'RETURN' THEN N'Return request for refund' ELSE N'Exchange request' END,
                N' on Order #', o.OrderNumber,
                N' &bull; Item: ', p.Name, N' (', pc.Color, N', ', pv.Size, N')',
                N' &bull; Reason: ', rma.Reason,
                CASE WHEN rma.CustomerNotes IS NOT NULL AND LEN(rma.CustomerNotes) > 0 THEN CONCAT(N' &bull; Note: "', LEFT(rma.CustomerNotes, 50), N'..."') ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(o.CustomerName, N''), NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Customer') AS Actor,
            N'Customer' AS ActorRole,
            rma.CreatedAt
        FROM dbo.ReturnRequests rma
        JOIN dbo.Orders o ON o.Id = rma.OrderId
        JOIN dbo.OrderItems oi ON oi.Id = rma.OrderItemId
        JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        JOIN dbo.Products p ON p.Id = pc.ProductId
        LEFT JOIN dbo.Users u ON u.Id = rma.UserId

        UNION ALL

        -- 4. Return & Exchange RMAs (Resolved by Staff/Admin)
        SELECT 
            N'RMA' AS ActivityType,
            rma.RmaNumber AS Reference,
            CONCAT(
                N'Processed RMA: ', rma.Status,
                CASE 
                    WHEN rma.ResolutionType IS NOT NULL THEN CONCAT(N' (Resolution: ', rma.ResolutionType, N')') 
                    ELSE N'' 
                END,
                CASE 
                    WHEN rma.RefundAmount IS NOT NULL AND rma.RefundAmount > 0 THEN CONCAT(N' &bull; Refund: PHP ', FORMAT(rma.RefundAmount, N'N2')) 
                    ELSE N'' 
                END,
                N' on Order #', o.OrderNumber,
                CASE WHEN rma.Restocked = 1 THEN N' &bull; Item Restocked' ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(pb.FirstName, N' ', pb.LastName), N' '), N'Staff Member') AS Actor,
            CASE WHEN pbr.Name = N'Admin' THEN N'Admin' ELSE N'Staff' END AS ActorRole,
            rma.UpdatedAt AS CreatedAt
        FROM dbo.ReturnRequests rma
        JOIN dbo.Orders o ON o.Id = rma.OrderId
        LEFT JOIN dbo.Users pb ON pb.Id = rma.ProcessedBy
        LEFT JOIN dbo.Roles pbr ON pbr.Id = pb.RoleId
        WHERE rma.Status IN (N'Approved', N'Rejected', N'Completed', N'Received')
          AND rma.ProcessedBy IS NOT NULL

        UNION ALL

        -- 5. Customer Product Reviews (Reference explicitly formatted as REV-<Id>)
        SELECT 
            N'Review' AS ActivityType,
            CONCAT(N'REV-', pr.Id) AS Reference,
            CONCAT(
                N'Reviewed ', p.Name,
                N' (', pr.Rating, N'/5 stars)',
                CASE WHEN pr.Title IS NOT NULL AND LEN(pr.Title) > 0 THEN CONCAT(N' &bull; "', pr.Title, N'"') ELSE N'' END,
                CASE WHEN pr.IsVerifiedPurchase = 1 THEN N' &bull; Verified Purchase' ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(pr.ReviewerName, N''), N'Customer') AS Actor,
            N'Customer' AS ActorRole,
            pr.CreatedAt
        FROM dbo.ProductReviews pr
        JOIN dbo.Products p ON p.Id = pr.ProductId

        UNION ALL

        -- 6. Moderation Review Reports (Reference explicitly includes review id)
        SELECT 
            N'Review' AS ActivityType,
            CONCAT(N'Report #', rep.Id, N' (REV-', pr.Id, N')') AS Reference,
            CONCAT(
                N'Flagged review on ', p.Name,
                N' &bull; Reason: ', rep.Reason,
                CASE WHEN rep.Notes IS NOT NULL AND LEN(rep.Notes) > 0 THEN CONCAT(N' &bull; "', LEFT(rep.Notes, 40), N'..."') ELSE N'' END
            ) AS Detail,
            COALESCE(NULLIF(CONCAT(u.FirstName, N' ', u.LastName), N' '), N'Community Member') AS Actor,
            N'Customer' AS ActorRole,
            rep.CreatedAt
        FROM dbo.ReviewReports rep
        JOIN dbo.ProductReviews pr ON pr.Id = rep.ReviewId
        JOIN dbo.Products p ON p.Id = pr.ProductId
        LEFT JOIN dbo.Users u ON u.Id = rep.UserId

        UNION ALL

        -- 7. Payment Transactions (Completed payments and refunds) - labeled QRPh instead of HitPay
        SELECT 
            N'Payment' AS ActivityType,
            COALESCE(py.GatewayReference, o.OrderNumber) AS Reference,
            CONCAT(
                CASE 
                    WHEN py.Status = N'Completed' THEN N'Payment received via '
                    WHEN py.Status = N'Refunded' THEN N'Refund issued via '
                    WHEN py.Status = N'Failed' THEN N'Payment attempt failed on '
                    ELSE N'Payment updated on '
                END,
                CASE WHEN UPPER(ISNULL(py.PaymentGateway, N'')) = N'HITPAY' THEN N'QRPh' ELSE ISNULL(py.PaymentGateway, N'Payment Gateway') END,
                N' for Order #', o.OrderNumber,
                N' &bull; PHP ', FORMAT(py.Amount, N'N2'),
                N' &bull; Status: ', py.Status
            ) AS Detail,
            ISNULL(NULLIF(o.CustomerName, N''), N'Store Customer') AS Actor,
            CASE 
                WHEN o.OrderSource IN (N'INSTORE_POS', N'IN_STORE') THEN N'Staff'
                WHEN r.Name = N'Admin' THEN N'Admin'
                WHEN r.Name = N'Staff' THEN N'Staff'
                ELSE N'Customer'
            END AS ActorRole,
            COALESCE(py.PaidAt, py.CreatedAt) AS CreatedAt
        FROM dbo.Payments py
        JOIN dbo.Orders o ON o.Id = py.OrderId
        LEFT JOIN dbo.Users u ON u.Id = o.UserId
        LEFT JOIN dbo.Roles r ON r.Id = u.RoleId
    ) act
    ORDER BY act.CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @Limit ROWS ONLY;
END;

GO

-- Stored Procedure (30): sp_AdminReturnReplacements
CREATE OR ALTER PROCEDURE dbo.sp_AdminReturnReplacements @RmaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Id AS variantId, v.SKU AS sku, pc.Color AS color, v.Size AS size,
        i.CurrentStock - i.ReservedStock AS availableStock
    FROM dbo.ReturnRequests rr JOIN dbo.OrderItems oi ON oi.Id = rr.OrderItemId
    JOIN dbo.ProductVariants original ON original.Id = oi.VariantId
    JOIN dbo.ProductColors originalColor ON originalColor.Id = original.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = originalColor.ProductId
    JOIN dbo.v_VisibleProductColors pc ON pc.ProductId = p.Id
    JOIN dbo.v_VisibleProductVariants v ON v.ProductColorId = pc.Id
    JOIN dbo.v_VisibleInventories i ON i.VariantId = v.Id
    WHERE rr.Id = @RmaId AND rr.RequestType = N'EXCHANGE'
        AND dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage,
            p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) = oi.UnitPrice
    ORDER BY pc.Color, v.Size;
END;

GO

-- Stored Procedure (31): sp_AdminReviews
CREATE OR ALTER PROCEDURE dbo.sp_AdminReviews @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) r.Id, p.Name AS ProductName, r.ProductId, r.ReviewerName, r.Rating,
           r.Title, r.Comment, r.IsVerifiedPurchase, r.IsHidden, r.CreatedAt,
           (SELECT COUNT(*) FROM dbo.ReviewReports rr WHERE rr.ReviewId = r.Id) AS ReportCount
    FROM dbo.ProductReviews r JOIN dbo.v_VisibleProducts p ON p.Id = r.ProductId
    ORDER BY (SELECT COUNT(*) FROM dbo.ReviewReports rr WHERE rr.ReviewId = r.Id) DESC, r.CreatedAt DESC;
END;

GO

-- Stored Procedure (32): sp_AdminSalesByBrandAndCategory
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesByBrandAndCategory @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT BrandName AS DimensionName, SUM(UnitsSold) AS UnitsSold, COUNT(DISTINCT OrderId) AS OrderCount,
        CONVERT(DECIMAL(18,2), SUM(Revenue)) AS Revenue,
        ISNULL(CONVERT(DECIMAL(18,2), SUM(Revenue) / NULLIF(SUM(UnitsSold), 0)), 0) AS AverageUnitPrice
    FROM dbo.v_SettledSalesLines WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY BrandName ORDER BY UnitsSold DESC, Revenue DESC;
    SELECT CategoryName AS DimensionName, SUM(UnitsSold) AS UnitsSold, COUNT(DISTINCT OrderId) AS OrderCount,
        CONVERT(DECIMAL(18,2), SUM(Revenue)) AS Revenue,
        ISNULL(CONVERT(DECIMAL(18,2), SUM(Revenue) / NULLIF(SUM(UnitsSold), 0)), 0) AS AverageUnitPrice
    FROM dbo.v_SettledSalesLines WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY CategoryName ORDER BY UnitsSold DESC, Revenue DESC;
END;

GO

-- Stored Procedure (33): sp_AdminSalesDaily
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesDaily @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(DATE, PaidAt) AS SalesDate, COUNT(*) AS PaymentCount, SUM(Revenue) AS Revenue
    FROM dbo.v_SettledOrderRevenue WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY CONVERT(DATE, PaidAt) ORDER BY SalesDate;
END;

GO

-- Stored Procedure (34): sp_AdminSalesHourly
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesHourly @TargetDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DATEPART(HOUR, PaidAt) AS SaleHour, COUNT(*) AS OrderCount, SUM(Revenue) AS Revenue
    FROM dbo.v_SettledOrderRevenue WHERE PaidAt >= @TargetDate AND PaidAt < DATEADD(DAY, 1, @TargetDate)
    GROUP BY DATEPART(HOUR, PaidAt) ORDER BY SaleHour;
END;

GO

-- Stored Procedure (35): sp_AdminSalesPerformance
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesPerformance @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductId, ProductName, BrandId, BrandName, CategoryId, CategoryName,
        SUM(UnitsSold) AS UnitsSold, COUNT(DISTINCT OrderId) AS OrderCount,
        CONVERT(DECIMAL(18,2), SUM(Revenue)) AS Revenue,
        CONVERT(DECIMAL(18,2), SUM(Revenue) / NULLIF(SUM(UnitsSold), 0)) AS AverageSellingPrice
    FROM dbo.v_SettledSalesLines WHERE PaidAt >= @StartDate AND PaidAt < @EndDate
    GROUP BY ProductId, ProductName, BrandId, BrandName, CategoryId, CategoryName
    ORDER BY UnitsSold DESC, Revenue DESC;
END;

GO

-- Stored Procedure (36): sp_AdminSalesReport
CREATE OR ALTER PROCEDURE dbo.sp_AdminSalesReport @StartDate DATETIME2, @EndDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS PaymentCount, ISNULL(SUM(Revenue), 0) AS Revenue,
        ISNULL(SUM(CASE WHEN OrderSource = N'ONLINE' THEN Revenue ELSE 0 END), 0) AS OnlineRevenue,
        ISNULL(SUM(CASE WHEN OrderSource = N'INSTORE_POS' THEN Revenue ELSE 0 END), 0) AS InStoreRevenue
    FROM dbo.v_SettledOrderRevenue WHERE PaidAt >= @StartDate AND PaidAt < @EndDate;
END;

GO

-- Stored Procedure (37): sp_AdminSaveBrand
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveBrand
    @Id INT, @Name NVARCHAR(100), @LogoUrl NVARCHAR(255), @Website NVARCHAR(255), @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL THROW 52105, N'Brand name is required.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.Brands (Name, LogoUrl, Website, IsActive) VALUES (@Name, @LogoUrl, @Website, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Brands SET Name = @Name, LogoUrl = @LogoUrl, Website = @Website, IsActive = @IsActive WHERE Id = @Id;
        IF @@ROWCOUNT = 0 THROW 52106, N'Brand not found.', 1;
    END;
    SELECT @Id AS Id;
END;

GO

-- Stored Procedure (38): sp_AdminSaveCategory
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveCategory
    @Id INT, @Name NVARCHAR(100), @Slug NVARCHAR(100), @Description NVARCHAR(500), @DisplayOrder INT, @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
        THROW 52103, N'Category name and slug are required.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.Categories (Name, Slug, Description, DisplayOrder, IsActive)
        VALUES (@Name, @Slug, @Description, @DisplayOrder, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Categories SET Name = @Name, Slug = @Slug, Description = @Description,
            DisplayOrder = @DisplayOrder, IsActive = @IsActive WHERE Id = @Id;
        IF @@ROWCOUNT = 0 THROW 52104, N'Category not found.', 1;
    END;
    SELECT @Id AS Id;
END;

GO

-- Stored Procedure (39): sp_AdminSaveColor
-- 5. Upsert-safe Save Color Procedure
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveColor
    @Id INT, @ProductId INT, @Color NVARCHAR(50), @ColorType NVARCHAR(20), @SolidHex NCHAR(7),
    @GradientAngle INT, @Stop1 NCHAR(7), @Stop2 NCHAR(7), @Stop3 NCHAR(7), @Stop4 NCHAR(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Color)), N'') IS NULL THROW 52107, N'Color name is required.', 1;
    IF @ColorType NOT IN (N'SOLID', N'LINEAR_GRADIENT') THROW 52108, N'Invalid color type.', 1;
    IF @ColorType = N'SOLID' AND (@SolidHex IS NULL OR @SolidHex NOT LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
        THROW 52109, N'Solid color must use six-digit hex.', 1;
    IF @ColorType = N'LINEAR_GRADIENT' AND (@GradientAngle NOT BETWEEN 0 AND 359 OR @Stop1 IS NULL OR @Stop2 IS NULL)
        THROW 52110, N'Gradient needs angle and at least two stops.', 1;
    IF @ColorType = N'LINEAR_GRADIENT' AND @Stop4 IS NOT NULL AND @Stop3 IS NULL
        THROW 52117, N'Gradient stops must be ordered.', 1;
    IF @ColorType = N'LINEAR_GRADIENT' AND EXISTS
       (SELECT 1 FROM (VALUES (@Stop1), (@Stop2), (@Stop3), (@Stop4)) AS s(Hex)
        WHERE s.Hex IS NOT NULL AND s.Hex NOT LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
        THROW 52111, N'Gradient stops must use six-digit hex.', 1;
    DECLARE @Value NVARCHAR(255) = @SolidHex;
    IF @ColorType = N'LINEAR_GRADIENT'
        SET @Value = CONCAT(N'linear-gradient(', @GradientAngle, N'deg, ', @Stop1, N', ', @Stop2,
                            CASE WHEN @Stop3 IS NULL THEN N'' ELSE CONCAT(N', ', @Stop3) END,
                            CASE WHEN @Stop4 IS NULL THEN N'' ELSE CONCAT(N', ', @Stop4) END, N')');

    -- Auto-resolve existing color by ProductId and Color if @Id = 0
    IF @Id = 0
    BEGIN
        SELECT @Id = Id FROM dbo.ProductColors WHERE ProductId = @ProductId AND Color = @Color;
        IF @Id IS NULL SET @Id = 0;
    END;

    BEGIN TRANSACTION;
    IF @Id = 0
    BEGIN
        INSERT dbo.ProductColors (ProductId, Color, ColorHex, ColorType, GradientAngle)
        VALUES (@ProductId, @Color, @Value, @ColorType, CASE WHEN @ColorType = N'SOLID' THEN NULL ELSE @GradientAngle END);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.ProductColors SET Color = @Color, ColorHex = @Value, ColorType = @ColorType,
            GradientAngle = CASE WHEN @ColorType = N'SOLID' THEN NULL ELSE @GradientAngle END
        WHERE Id = @Id AND ProductId = @ProductId;
        IF @@ROWCOUNT = 0 THROW 52112, N'Product color not found.', 1;
    END;
    DELETE dbo.ProductColorStops WHERE ProductColorId = @Id;
    IF @ColorType = N'LINEAR_GRADIENT'
        INSERT dbo.ProductColorStops (ProductColorId, StopOrder, ColorHex)
        SELECT @Id, s.StopOrder, s.Hex FROM (VALUES (1, @Stop1), (2, @Stop2), (3, @Stop3), (4, @Stop4)) s(StopOrder, Hex)
        WHERE s.Hex IS NOT NULL;
    COMMIT TRANSACTION;
    SELECT @Id AS Id, @Value AS ColorHex;
END;

GO

-- Stored Procedure (40): sp_AdminSaveGallery
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveGallery
    @Id INT, @ProductId INT, @ImageUrl NVARCHAR(500), @AltText NVARCHAR(200), @DisplayOrder INT, @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@ImageUrl)), N'') IS NULL OR @DisplayOrder < 1
        THROW 52115, N'Image and positive display order are required.', 1;
    IF @Id = 0
    BEGIN
        INSERT dbo.ProductGalleryImages (ProductId, ImageUrl, AltText, DisplayOrder, IsActive)
        VALUES (@ProductId, @ImageUrl, @AltText, @DisplayOrder, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.ProductGalleryImages SET ImageUrl = @ImageUrl, AltText = @AltText,
            DisplayOrder = @DisplayOrder, IsActive = @IsActive, UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND ProductId = @ProductId;
        IF @@ROWCOUNT = 0 THROW 52116, N'Gallery image not found.', 1;
    END;
    SELECT @Id AS Id;
END;

GO

-- Stored Procedure (41): sp_AdminSaveProduct
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveProduct
    @Id INT,
    @CategoryId INT,
    @BrandId INT,
    @Name NVARCHAR(200),
    @Slug NVARCHAR(220),
    @Description NVARCHAR(MAX) = NULL,
    @RidingStyle NVARCHAR(50) = NULL,
    @BasePrice DECIMAL(18,2),
    @DiscountPercentage INT = 0,
    @DiscountType NVARCHAR(20) = N'PERCENTAGE',
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @DiscountStartDate DATETIME2 = NULL,
    @DiscountEndDate DATETIME2 = NULL,
    @MainImageUrl NVARCHAR(500) = NULL,
    @IsFeatured BIT = 0,
    @IsActive BIT = 1,
    @PublicationStatus NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Name)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Slug)), N'') IS NULL
       OR @BasePrice < 0 OR @DiscountPercentage NOT BETWEEN 0 AND 100
        THROW 52101, N'Invalid product details.', 1;

    -- Resolve PublicationStatus: if omitted, derive from IsActive
    IF @PublicationStatus IS NULL OR @PublicationStatus NOT IN (N'Draft', N'Published', N'Archived')
    BEGIN
        SET @PublicationStatus = CASE WHEN @IsActive = 1 THEN N'Published' ELSE N'Draft' END;
    END;

    DECLARE @UniqueSlug NVARCHAR(220) = @Slug;
    DECLARE @SlugCounter INT = 1;
    WHILE EXISTS (SELECT 1 FROM dbo.Products WHERE Slug = @UniqueSlug AND Id <> @Id)
    BEGIN
        SET @SlugCounter = @SlugCounter + 1;
        SET @UniqueSlug = SUBSTRING(@Slug, 1, 200) + N'-' + CAST(@SlugCounter AS NVARCHAR(10));
    END;
    SET @Slug = @UniqueSlug;

    IF @Id = 0
    BEGIN
        INSERT INTO dbo.Products (
            CategoryId, BrandId, Name, Slug, Description, BasePrice,
            DiscountPercentage, DiscountType, DiscountAmount, DiscountStartDate, DiscountEndDate, DiscountIsActive,
            MainImageUrl, IsActive, PublicationStatus, CreatedAt, UpdatedAt
        )
        VALUES (
            @CategoryId, @BrandId, @Name, @Slug, @Description, @BasePrice,
            @DiscountPercentage, @DiscountType, @DiscountAmount, @DiscountStartDate, @DiscountEndDate,
            CASE WHEN (@DiscountPercentage > 0 OR @DiscountAmount > 0) THEN 1 ELSE 0 END,
            NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''), @IsActive, @PublicationStatus,
            SYSUTCDATETIME(), SYSUTCDATETIME()
        );

        SET @Id = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.Products
        SET CategoryId = @CategoryId,
            BrandId = @BrandId,
            Name = @Name,
            Slug = @Slug,
            Description = @Description,
            BasePrice = @BasePrice,
            DiscountPercentage = @DiscountPercentage,
            DiscountType = @DiscountType,
            DiscountAmount = @DiscountAmount,
            DiscountStartDate = @DiscountStartDate,
            DiscountEndDate = @DiscountEndDate,
            DiscountIsActive = CASE WHEN (@DiscountPercentage > 0 OR @DiscountAmount > 0) THEN 1 ELSE 0 END,
            MainImageUrl = NULLIF(LTRIM(RTRIM(@MainImageUrl)), N''),
            IsActive = @IsActive,
            PublicationStatus = @PublicationStatus,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;
    END;

    SELECT 
        p.Id, p.CategoryId, p.BrandId, p.Name, p.Slug, p.Description, p.BasePrice,
        p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive,
        p.MainImageUrl, p.IsActive, p.PublicationStatus,
        c.Name AS CategoryName, b.Name AS BrandName,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice
    FROM dbo.Products p
    LEFT JOIN dbo.Categories c ON c.Id = p.CategoryId
    LEFT JOIN dbo.Brands b ON b.Id = p.BrandId
    WHERE p.Id = @Id;
END;

GO

-- Stored Procedure (42): sp_AdminSaveProductSpecifications
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveProductSpecifications
    @ProductId INT,
    @SpecsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Id = @ProductId)
        THROW 52120, N'Product not found.', 1;

    DECLARE @CategoryId INT;
    SELECT @CategoryId = CategoryId FROM dbo.Products WHERE Id = @ProductId;

    -- If null, empty string, or empty array, remove all specifications for this product
    IF @SpecsJson IS NULL OR LTRIM(RTRIM(@SpecsJson)) = N'' OR @SpecsJson = N'[]'
    BEGIN
        DELETE FROM dbo.ProductSpecificationValues WHERE ProductId = @ProductId;
        RETURN;
    END;

    BEGIN TRANSACTION;

    DECLARE @ParsedSpecs TABLE (
        SpecKey NVARCHAR(80),
        DisplayName NVARCHAR(120),
        SpecValue NVARCHAR(1000),
        DisplayOrder INT IDENTITY(1,1)
    );

    INSERT INTO @ParsedSpecs (SpecKey, DisplayName, SpecValue)
    SELECT 
        LOWER(LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.key'), JSON_VALUE(s.value, '$.SpecificationKey'), JSON_VALUE(s.value, '$.specificationKey'))))),
        LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.name'), JSON_VALUE(s.value, '$.DisplayName'), JSON_VALUE(s.value, '$.displayName'), JSON_VALUE(s.value, '$.key'), JSON_VALUE(s.value, '$.SpecificationKey')))),
        LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.value'), JSON_VALUE(s.value, '$.SpecificationValue'), JSON_VALUE(s.value, '$.specificationValue'))))
    FROM OPENJSON(@SpecsJson) AS s
    WHERE NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.key'), JSON_VALUE(s.value, '$.SpecificationKey'), JSON_VALUE(s.value, '$.specificationKey')))), N'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(COALESCE(JSON_VALUE(s.value, '$.value'), JSON_VALUE(s.value, '$.SpecificationValue'), JSON_VALUE(s.value, '$.specificationValue')))), N'') IS NOT NULL;

    -- Ensure definition entries exist (deduplicated by SpecKey)
    INSERT INTO dbo.SpecificationDefinitions (SpecificationKey, DisplayName, IsActive, CreatedAt)
    SELECT p.SpecKey, MAX(ISNULL(NULLIF(p.DisplayName, N''), p.SpecKey)), 1, SYSUTCDATETIME()
    FROM @ParsedSpecs p
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.SpecificationDefinitions d
        WHERE d.SpecificationKey = p.SpecKey
    )
    GROUP BY p.SpecKey;

    -- Ensure category mapping exists
    IF @CategoryId IS NOT NULL
    BEGIN
        INSERT INTO dbo.CategorySpecifications (CategoryId, SpecificationId, DisplayOrder, IsRequired)
        SELECT @CategoryId, d.Id, MIN(p.DisplayOrder), 0
        FROM @ParsedSpecs p
        INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = p.SpecKey
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.CategorySpecifications cs
            WHERE cs.CategoryId = @CategoryId AND cs.SpecificationId = d.Id
        )
        GROUP BY d.Id;
    END;

    -- Upsert ProductSpecificationValues and purge removed specifications
    MERGE dbo.ProductSpecificationValues AS target
    USING (
        SELECT d.Id AS SpecificationId, MAX(p.SpecValue) AS SpecValue
        FROM @ParsedSpecs p
        INNER JOIN dbo.SpecificationDefinitions d ON d.SpecificationKey = p.SpecKey
        GROUP BY d.Id
    ) AS source
    ON (target.ProductId = @ProductId AND target.SpecificationId = source.SpecificationId)
    WHEN MATCHED THEN
        UPDATE SET target.SpecificationValue = source.SpecValue,
                   target.UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ProductId, SpecificationId, SpecificationValue, CreatedAt)
        VALUES (@ProductId, source.SpecificationId, source.SpecValue, SYSUTCDATETIME())
    WHEN NOT MATCHED BY SOURCE AND target.ProductId = @ProductId THEN
        DELETE;

    COMMIT TRANSACTION;
END;

GO

-- Stored Procedure (43): sp_AdminSaveVariant
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveVariant @Id INT, @ProductColorId INT, @SKU NVARCHAR(100), @Size NVARCHAR(20), @PriceAdjustment DECIMAL(18,2), @ReorderPoint INT, @IsActive BIT = 1 AS BEGIN SET NOCOUNT ON; SET XACT_ABORT ON; IF @IsActive IS NULL SET @IsActive = 1; IF NULLIF(LTRIM(RTRIM(@SKU)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@Size)), N'') IS NULL OR @ReorderPoint < 0 THROW 52113, N'Invalid variant details.', 1; IF @Id = 0 BEGIN SELECT @Id = Id FROM dbo.ProductVariants WHERE ProductColorId = @ProductColorId AND Size = @Size; IF @Id IS NULL OR @Id = 0 SELECT @Id = Id FROM dbo.ProductVariants WHERE SKU = @SKU; IF @Id IS NULL SET @Id = 0; END; BEGIN TRANSACTION; IF @Id = 0 BEGIN INSERT dbo.ProductVariants (ProductColorId, SKU, Size, PriceAdjustment, IsActive) VALUES (@ProductColorId, @SKU, @Size, @PriceAdjustment, @IsActive); SET @Id = CONVERT(INT, SCOPE_IDENTITY()); INSERT dbo.Inventories (VariantId, CurrentStock, ReorderPoint) VALUES (@Id, 0, @ReorderPoint); END ELSE BEGIN IF EXISTS (SELECT 1 FROM dbo.OrderItems oi JOIN dbo.ProductVariants v WITH (UPDLOCK, ROWLOCK) ON v.Id = oi.VariantId WHERE oi.VariantId = @Id AND (v.ProductColorId <> @ProductColorId OR v.SKU <> @SKU OR v.Size <> @Size)) THROW 52118, N'Cannot change color, SKU, or size of a variant linked to an order.', 1; UPDATE dbo.ProductVariants SET ProductColorId = @ProductColorId, SKU = @SKU, Size = @Size, PriceAdjustment = @PriceAdjustment, IsActive = @IsActive WHERE Id = @Id; IF @@ROWCOUNT = 0 THROW 52114, N'Variant not found.', 1; UPDATE dbo.Inventories SET ReorderPoint = @ReorderPoint, UpdatedAt = SYSUTCDATETIME() WHERE VariantId = @Id; END; COMMIT TRANSACTION; SELECT @Id AS Id; END;

GO

-- Stored Procedure (44): sp_AdminSaveVoucher
-- 2. Procedure: dbo.sp_AdminSaveVoucher
CREATE OR ALTER PROCEDURE dbo.sp_AdminSaveVoucher
    @Id INT = 0, 
    @Code NVARCHAR(30), 
    @DiscountType NVARCHAR(20),
    @DiscountValue DECIMAL(18,2), 
    @MinimumSpend DECIMAL(18,2) = 0,
    @ExpiresAt DATETIME2 = NULL, 
    @UsageLimit INT = NULL, 
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Code = UPPER(LTRIM(RTRIM(@Code)));

    IF @Code IS NULL OR LEN(@Code) NOT BETWEEN 3 AND 30 OR
       @Code COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Z0-9-]%'
        THROW 54001, N'Use 3-30 letters, numbers or hyphens for the voucher code.', 1;

    IF @DiscountType IS NULL OR @DiscountType NOT IN (N'PERCENTAGE', N'FIXED_AMOUNT', N'FREE_SHIPPING') OR
       @DiscountValue IS NULL OR
       (@DiscountType <> N'FREE_SHIPPING' AND @DiscountValue <= 0) OR
       (@DiscountType = N'FREE_SHIPPING' AND @DiscountValue < 0) OR
       (@DiscountType = N'PERCENTAGE' AND @DiscountValue > 100) OR
       @MinimumSpend IS NULL OR @MinimumSpend < 0 OR @UsageLimit <= 0
        THROW 54002, N'Check the discount, minimum spend and usage limit.', 1;

    -- Past dates are allowed only when retaining an existing expiry
    IF @ExpiresAt <= SYSUTCDATETIME() AND NOT EXISTS
        (SELECT 1 FROM dbo.Vouchers WHERE Id = @Id AND ExpiresAt = @ExpiresAt)
        THROW 54003, N'Choose a future expiry date.', 1;

    BEGIN TRANSACTION;
    IF @Id <> 0 AND NOT EXISTS (SELECT 1 FROM dbo.Vouchers WITH (UPDLOCK, ROWLOCK) WHERE Id = @Id)
        THROW 54004, N'Voucher not found.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Vouchers WHERE Code = @Code AND Id <> @Id)
        THROW 54005, N'This voucher code already exists.', 1;

    IF EXISTS (SELECT 1 FROM dbo.VoucherRedemptions WHERE VoucherId = @Id) AND
       EXISTS (SELECT 1 FROM dbo.Vouchers WHERE Id = @Id AND Code <> @Code)
        THROW 54006, N'A redeemed voucher code cannot be renamed.', 1;

    IF @UsageLimit < (SELECT COUNT(*) FROM dbo.VoucherRedemptions WHERE VoucherId = @Id AND ReleasedAt IS NULL)
        THROW 54007, N'Usage limit cannot be lower than current usage.', 1;

    IF @Id = 0
    BEGIN
        INSERT dbo.Vouchers(Code, DiscountType, DiscountValue, MinimumSpend, ExpiresAt, UsageLimit, IsActive)
        VALUES (@Code, @DiscountType, @DiscountValue, @MinimumSpend, @ExpiresAt, @UsageLimit, @IsActive);
        SET @Id = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Vouchers 
        SET Code = @Code, 
            DiscountType = @DiscountType, 
            DiscountValue = @DiscountValue,
            MinimumSpend = @MinimumSpend, 
            ExpiresAt = @ExpiresAt, 
            UsageLimit = @UsageLimit,
            IsActive = @IsActive, 
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @Id;
    END

    COMMIT TRANSACTION;
    SELECT @Id AS Id;
END;

GO

-- Stored Procedure (45): sp_AdminSellableVariants
CREATE OR ALTER PROCEDURE dbo.sp_AdminSellableVariants
    @Search NVARCHAR(200) = NULL,
    @Brand NVARCHAR(100) = NULL,
    @Category NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Category = NULLIF(LTRIM(RTRIM(@Category)), N'');
    SELECT v.Id AS VariantId, p.Id AS ProductId, v.SKU,
           p.Name AS ProductName, b.Name AS Brand, cat.Name AS Category,
           p.MainImageUrl, c.Color, c.ColorHex, v.Size,
           i.CurrentStock - i.ReservedStock AS AvailableStock,
           dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
               p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
               p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS UnitPrice,
           CASE WHEN i.CurrentStock - i.ReservedStock <= 0 THEN N'out_of_stock'
                WHEN i.CurrentStock - i.ReservedStock <= i.ReorderPoint THEN N'low_stock'
                ELSE N'in_stock' END AS StockStatus
    FROM dbo.v_VisibleProductVariants v
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    JOIN dbo.Categories cat ON cat.Id = p.CategoryId
    JOIN dbo.v_VisibleInventories i ON i.VariantId = v.Id
    WHERE p.IsActive = 1 AND v.IsActive = 1
      AND (@Search IS NULL OR p.Name LIKE N'%' + @Search + N'%'
           OR b.Name LIKE N'%' + @Search + N'%'
           OR v.SKU LIKE N'%' + @Search + N'%'
           OR c.Color LIKE N'%' + @Search + N'%'
           OR CONCAT(b.Name, N' ', p.Name) LIKE N'%' + @Search + N'%')
      AND (@Brand IS NULL OR b.Name = @Brand)
      AND (@Category IS NULL OR cat.Name = @Category)
    ORDER BY b.Name, p.Name, c.Color, v.Size;
END;

GO

-- Stored Procedure (46): sp_AdminSpecifications
CREATE OR ALTER PROCEDURE dbo.sp_AdminSpecifications @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.SpecificationKey, d.DisplayName, cs.DisplayOrder, cs.IsRequired,
           v.SpecificationValue
    FROM dbo.Products p JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId
    JOIN dbo.SpecificationDefinitions d ON d.Id = cs.SpecificationId AND d.IsActive = 1
    LEFT JOIN dbo.ProductSpecificationValues v ON v.ProductId = p.Id AND v.SpecificationId = d.Id
    WHERE p.Id = @ProductId ORDER BY cs.DisplayOrder, d.DisplayName;
END;

GO

-- Stored Procedure (47): sp_AdminStockAuditLogs
CREATE OR ALTER PROCEDURE dbo.sp_AdminStockAuditLogs
    @VariantId INT = NULL,
    @Search NVARCHAR(200) = NULL,
    @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');

    SELECT TOP (@Limit)
        l.Id,
        l.VariantId,
        b.Name AS BrandName,
        p.Id AS ProductId,
        p.Name AS ProductName,
        c.Color,
        v.Size,
        v.SKU,
        l.ChangeType,
        l.PreviousStock,
        l.QuantityChanged,
        l.NewStock,
        l.ReferenceNumber,
        l.Notes,
        l.CreatedAt,
        ISNULL(NULLIF(LTRIM(RTRIM(CONCAT(u.FirstName, N' ', u.LastName))), N''), N'Staff Admin') AS PerformedBy
    FROM dbo.v_VisibleStockAuditLogs l
    JOIN dbo.v_VisibleProductVariants v ON v.Id = l.VariantId
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId
    JOIN dbo.Brands b ON b.Id = p.BrandId
    LEFT JOIN dbo.Users u ON u.Id = l.UserId
    WHERE (@VariantId IS NULL OR l.VariantId = @VariantId)
      AND (
          @Search IS NULL
          OR b.Name LIKE N'%' + @Search + N'%'
          OR p.Name LIKE N'%' + @Search + N'%'
          OR v.SKU LIKE N'%' + @Search + N'%'
          OR c.Color LIKE N'%' + @Search + N'%'
          OR l.ReferenceNumber LIKE N'%' + @Search + N'%'
      )
    ORDER BY l.CreatedAt DESC, l.Id DESC;
END;

GO

-- Stored Procedure (48): sp_AdminStockHistory
CREATE OR ALTER PROCEDURE dbo.sp_AdminStockHistory @VariantId INT, @Limit INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) l.Id, l.VariantId, l.ChangeType, l.PreviousStock, l.QuantityChanged,
           l.NewStock, l.ReferenceNumber, l.Notes, l.CreatedAt,
           CONCAT(u.FirstName, N' ', u.LastName) AS PerformedBy
    FROM dbo.v_VisibleStockAuditLogs l LEFT JOIN dbo.Users u ON u.Id = l.UserId
    WHERE l.VariantId = @VariantId ORDER BY l.CreatedAt DESC, l.Id DESC;
END;

GO

-- Stored Procedure (49): sp_AdminToggleReviewVisibility
CREATE OR ALTER PROCEDURE dbo.sp_AdminToggleReviewVisibility
    @ReviewId INT,
    @NewIsHidden BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.ProductReviews WITH (UPDLOCK, ROWLOCK) WHERE Id = @ReviewId)
            THROW 51020, N'Review not found.', 1;

        UPDATE dbo.ProductReviews WITH (UPDLOCK, ROWLOCK)
        SET IsHidden = CASE WHEN IsHidden = 1 THEN 0 ELSE 1 END
        WHERE Id = @ReviewId;

        SELECT @NewIsHidden = IsHidden
        FROM dbo.ProductReviews
        WHERE Id = @ReviewId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

GO

-- Stored Procedure (50): sp_AdminToggleVariantActive
-- ----------------------------------------------------------------------------
-- 2. Procedure: dbo.sp_AdminToggleVariantActive
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_AdminToggleVariantActive
    @VariantId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @VariantId IS NULL OR @VariantId <= 0
    BEGIN
        THROW 52120, N'Invalid variant ID.', 1;
    END;

    BEGIN TRANSACTION;

    DECLARE @NewStatus BIT;

    UPDATE dbo.ProductVariants WITH (UPDLOCK, ROWLOCK)
    SET IsActive = CASE WHEN IsActive = 1 THEN 0 ELSE 1 END
    WHERE Id = @VariantId;

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52119, N'Variant not found.', 1;
    END;

    SELECT @NewStatus = IsActive
    FROM dbo.ProductVariants
    WHERE Id = @VariantId;

    COMMIT TRANSACTION;

    SELECT @VariantId AS VariantId, @NewStatus AS IsActive;
END;

GO

-- Stored Procedure (51): sp_AdminUpdateOrderStatus
CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateOrderStatus
    @OrderId INT, @NewStatus NVARCHAR(50), @Notes NVARCHAR(500) = NULL,
    @Courier NVARCHAR(100) = NULL, @TrackingNumber NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @OldStatus NVARCHAR(50), @Method NVARCHAR(50), @Number NVARCHAR(50), @UserId INT, @Committed BIT;
        SELECT @OldStatus = Status, @Method = ShippingMethod, @Number = OrderNumber, @UserId = UserId
        FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @OrderId;
        IF @OldStatus IS NULL THROW 52001, N'Order not found.', 1;
        IF NOT (
            (@OldStatus = N'Processing' AND @NewStatus = N'ReadyForPickup' AND @Method = N'Pickup') OR
            (@OldStatus = N'Processing' AND @NewStatus = N'Shipped' AND @Method = N'Delivery') OR
            (@OldStatus = N'ReadyForPickup' AND @NewStatus = N'Completed' AND @Method = N'Pickup') OR
            (@OldStatus = N'Shipped' AND @NewStatus IN (N'Delivered', N'Completed') AND @Method = N'Delivery') OR
            (@OldStatus = N'Delivered' AND @NewStatus = N'Completed' AND @Method = N'Delivery') OR
            (@OldStatus IN (N'PendingPayment', N'Processing') AND @NewStatus = N'Cancelled'))
            THROW 52002, N'Invalid transition for this fulfillment method.', 1;
        IF @NewStatus = N'Shipped' AND (NULLIF(LTRIM(RTRIM(@Courier)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@TrackingNumber)), N'') IS NULL)
            THROW 55006, N'Courier and tracking number are required.', 1;
        IF @NewStatus <> N'Cancelled' AND NOT EXISTS (
            SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND
            (Status = N'Completed' OR (Status = N'Pending' AND PaymentGateway IN (N'Cash', N'CashOnDelivery'))))
            THROW 52003, N'Order requires a valid payment record.', 1;
        SET @Committed = CASE WHEN EXISTS (SELECT 1 FROM dbo.StockAuditLogs WHERE ReferenceNumber = @Number AND ChangeType = N'ONLINE_SALE' AND QuantityChanged < 0) THEN 1 ELSE 0 END;
        IF @NewStatus IN (N'Shipped', N'Completed') AND @Committed = 0
            EXEC dbo.sp_ChangeOrderInventory @OrderId, N'COMMIT', @UserId;
        IF @NewStatus = N'Cancelled'
        BEGIN
            IF @Committed = 1 EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RESTORE', @UserId;
            ELSE EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RELEASE', @UserId;
            UPDATE dbo.Payments SET Status = N'Cancelled' WHERE OrderId = @OrderId AND Status IN (N'Pending', N'Failed');
            IF EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND Status = N'Completed')
                SET @Notes = LEFT(CONCAT(@Notes, N' | Refund pending manual confirmation.'), 500);
        END;
        IF @NewStatus IN (N'Completed', N'Delivered')
            UPDATE dbo.Payments SET Status = N'Completed', PaidAt = SYSUTCDATETIME()
            WHERE OrderId = @OrderId AND Status = N'Pending' AND PaymentGateway IN (N'Cash', N'CashOnDelivery');
        UPDATE dbo.Orders SET Status = @NewStatus, Notes = COALESCE(@Notes, Notes),
            Courier = COALESCE(@Courier, Courier), TrackingNumber = COALESCE(@TrackingNumber, TrackingNumber), UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @OrderId;
        EXEC dbo.sp_RefreshOrderStockAlerts @OrderId;
        COMMIT TRANSACTION;
        SELECT @OrderId AS Id, @NewStatus AS Status, @Courier AS Courier, @TrackingNumber AS TrackingNumber;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO

-- Stored Procedure (52): sp_AdminUpdateUser
CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateUser
    @UserId INT,
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @PhoneNumber NVARCHAR(30),
    @RoleName NVARCHAR(50),
    @IsActive BIT,
    @ActorUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@FirstName)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@LastName)), N'') IS NULL
        THROW 52008, N'First and last name are required.', 1;

    IF NULLIF(LTRIM(RTRIM(@PhoneNumber)), N'') IS NULL
        THROW 52012, N'Phone number is required.', 1;

    BEGIN TRANSACTION;

    DECLARE @RoleId INT, @OldRole NVARCHAR(50), @OldActive BIT;
    SELECT @RoleId = Id FROM dbo.Roles WHERE Name = @RoleName;
    SELECT @OldRole = r.Name, @OldActive = u.IsActive
    FROM dbo.Users u WITH (UPDLOCK, ROWLOCK) JOIN dbo.Roles r ON r.Id = u.RoleId WHERE u.Id = @UserId;

    IF @RoleId IS NULL OR @OldRole IS NULL THROW 52009, N'User or role not found.', 1;

    IF @UserId = @ActorUserId AND (@RoleName <> N'Admin' OR @IsActive = 0)
        THROW 52010, N'You cannot remove your own admin access.', 1;

    IF @OldRole = N'Admin' AND @OldActive = 1 AND (@RoleName <> N'Admin' OR @IsActive = 0)
       AND (SELECT COUNT(*) FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId WHERE r.Name = N'Admin' AND u.IsActive = 1) <= 1
        THROW 52011, N'At least one active admin is required.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE PhoneNumber = LTRIM(RTRIM(@PhoneNumber)) AND Id <> @UserId)
        THROW 52013, N'This phone number is already registered to another account.', 1;

    UPDATE dbo.Users 
    SET FirstName = LTRIM(RTRIM(@FirstName)), 
        LastName = LTRIM(RTRIM(@LastName)),
        PhoneNumber = LTRIM(RTRIM(@PhoneNumber)), 
        RoleId = @RoleId, 
        IsActive = @IsActive, 
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    COMMIT TRANSACTION;

    SELECT @UserId AS Id;
END;

GO

-- Stored Procedure (53): sp_AdminUpdateUserRole
CREATE OR ALTER PROCEDURE dbo.sp_AdminUpdateUserRole
    @UserId INT,
    @RoleName NVARCHAR(50),
    @ActorUserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DECLARE @RoleId INT, @OldRole NVARCHAR(50), @OldActive BIT;
    SELECT @RoleId = Id FROM dbo.Roles WHERE Name = @RoleName;
    SELECT @OldRole = r.Name, @OldActive = u.IsActive
    FROM dbo.Users u WITH (UPDLOCK, ROWLOCK) 
    JOIN dbo.Roles r ON r.Id = u.RoleId 
    WHERE u.Id = @UserId;

    IF @RoleId IS NULL OR @OldRole IS NULL 
        THROW 52009, N'User or target role not found.', 1;

    -- Prevent self-demotion from Admin
    IF @UserId = @ActorUserId AND @RoleName <> N'Admin'
        THROW 52010, N'You cannot remove your own admin access.', 1;

    -- Guard against removing the last active Admin
    IF @OldRole = N'Admin' AND @OldActive = 1 AND @RoleName <> N'Admin'
       AND (SELECT COUNT(*) FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId WHERE r.Name = N'Admin' AND u.IsActive = 1) <= 1
        THROW 52011, N'At least one active admin is required in the system.', 1;

    UPDATE dbo.Users 
    SET RoleId = @RoleId, 
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    COMMIT TRANSACTION;

    SELECT @UserId AS Id, @RoleName AS NewRole;
END;

GO

-- Stored Procedure (54): sp_AdminUsers
CREATE OR ALTER PROCEDURE dbo.sp_AdminUsers @Limit INT = 200
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) u.Id, u.FirstName, u.LastName, u.Email, u.PhoneNumber,
           r.Name AS Role, u.IsActive, u.CreatedAt
    FROM dbo.Users u JOIN dbo.Roles r ON r.Id = u.RoleId
    ORDER BY u.CreatedAt DESC, u.Id DESC;
END;

GO

-- Stored Procedure (55): sp_AdminVariants
-- 3. Retrieve product variants for admin API
CREATE OR ALTER PROCEDURE dbo.sp_AdminVariants
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.Id, v.ProductColorId, c.Color, v.SKU, v.Size, v.PriceAdjustment, v.IsActive,
           ISNULL(i.CurrentStock, 0) AS CurrentStock,
           ISNULL(i.ReservedStock, 0) AS ReservedStock,
           ISNULL(i.ReorderPoint, 3) AS ReorderPoint
    FROM dbo.ProductVariants v
    JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
    WHERE c.ProductId = @ProductId
    ORDER BY c.Color, v.Size;
END;

GO

-- Stored Procedure (56): sp_AdminVouchers
CREATE OR ALTER PROCEDURE dbo.sp_AdminVouchers
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.*, (SELECT COUNT(*) FROM dbo.VoucherRedemptions r
        WHERE r.VoucherId = v.Id AND r.ReleasedAt IS NULL) AS UsageCount,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM dbo.VoucherRedemptions r WHERE r.VoucherId = v.Id)
            THEN 1 ELSE 0 END AS BIT) AS HasRedemptions
    FROM dbo.Vouchers v ORDER BY v.CreatedAt DESC, v.Id DESC;
END;

GO

-- Stored Procedure (57): sp_AdminWebhookEvents
CREATE OR ALTER PROCEDURE dbo.sp_AdminWebhookEvents @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit) Id, HitPayPaymentId, ReferenceNumber, IsSignatureValid,
           ProcessingStatus, ErrorMessage, CreatedAt
    FROM dbo.HitPayWebhookLogs ORDER BY CreatedAt DESC, Id DESC;
END;

GO

-- Stored Procedure (58): sp_ApplyOrderVoucher
-- 3. UPDATE STORED PROCEDURE: sp_ApplyOrderVoucher (Enforce One-Time Use Per Customer)
CREATE OR ALTER PROCEDURE dbo.sp_ApplyOrderVoucher
    @OrderId INT, 
    @Code NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 THROW 54008, N'Voucher redemption requires an order transaction.', 1;

    DECLARE @Subtotal DECIMAL(18,2), @Id INT, @Discount DECIMAL(18,2), @Type NVARCHAR(20);
    DECLARE @CustomerId INT, @CustomerEmail NVARCHAR(255);

    SELECT 
        @CustomerId = UserId, 
        @CustomerEmail = LTRIM(RTRIM(CustomerEmail))
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
    WHERE Id = @OrderId AND OrderSource = N'ONLINE' AND Status IN (N'PendingPayment', N'Processing');

    IF @@ROWCOUNT = 0
        THROW 54015, N'This order cannot accept a voucher.', 1;

    IF EXISTS (SELECT 1 FROM dbo.VoucherRedemptions WHERE OrderId = @OrderId)
        THROW 54016, N'This order already has a voucher.', 1;

    SELECT @Subtotal = SUM(TotalPrice) FROM dbo.OrderItems WHERE OrderId = @OrderId;

    EXEC dbo.sp_CalculateVoucher @Code, @Subtotal, 1, @Id OUTPUT, @Discount OUTPUT, @Type OUTPUT;

    -- Strict One-Time Use Per Customer Check
    IF EXISTS (
        SELECT 1 
        FROM dbo.VoucherRedemptions vr
        JOIN dbo.Orders o ON vr.OrderId = o.Id
        WHERE vr.VoucherId = @Id 
          AND vr.OrderId <> @OrderId
          AND vr.ReleasedAt IS NULL
          AND o.Status <> N'Cancelled'
          AND (
              (@CustomerId IS NOT NULL AND o.UserId = @CustomerId)
              OR (@CustomerEmail IS NOT NULL AND LEN(@CustomerEmail) > 0 
                  AND LOWER(LTRIM(RTRIM(o.CustomerEmail))) = LOWER(@CustomerEmail))
          )
    )
    BEGIN
        THROW 54017, N'You have already used this voucher code. Vouchers are limited to one use per customer.', 1;
    END

    IF @Type = N'FREE_SHIPPING'
    BEGIN
        DECLARE @SavedShippingFee DECIMAL(18,2) = 0.00;
        SELECT @SavedShippingFee = ISNULL(ShippingFee, 0.00) FROM dbo.Orders WHERE Id = @OrderId;

        INSERT dbo.VoucherRedemptions(VoucherId, OrderId, DiscountAmount) 
        VALUES (@Id, @OrderId, @SavedShippingFee);

        UPDATE dbo.Orders 
        SET VoucherCode = UPPER(LTRIM(RTRIM(@Code))), 
            DiscountAmount = 0.00,
            ShippingFee = 0.00,
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @OrderId;
    END
    ELSE
    BEGIN
        INSERT dbo.VoucherRedemptions(VoucherId, OrderId, DiscountAmount) 
        VALUES (@Id, @OrderId, @Discount);

        UPDATE dbo.Orders 
        SET VoucherCode = UPPER(LTRIM(RTRIM(@Code))), 
            DiscountAmount = @Discount,
            UpdatedAt = SYSUTCDATETIME() 
        WHERE Id = @OrderId;
    END

    SELECT 
        VoucherCode AS Code, 
        Subtotal, 
        DiscountAmount, 
        Subtotal - DiscountAmount AS DiscountedSubtotal,
        @Type AS DiscountType
    FROM dbo.Orders 
    WHERE Id = @OrderId;
END;

GO

-- Stored Procedure (59): sp_ChangeShoppingState
CREATE OR ALTER PROCEDURE dbo.sp_ChangeShoppingState
    @UserId INT, @Operation NVARCHAR(30), @Id INT = NULL,
    @Quantity INT = NULL, @IsSelected BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Serialize changes per account, including inserts into initially empty collections.
        DECLARE @Owner INT;
        SELECT @Owner = Id FROM dbo.Users WITH (UPDLOCK, ROWLOCK) WHERE Id = @UserId AND IsActive = 1;
        IF @Owner IS NULL THROW 53048, 'Account is unavailable.', 1;

        IF @Operation IN (N'AddCart', N'SetCart')
        BEGIN
            IF @Quantity IS NOT NULL AND (@Quantity < 0 OR @Quantity > 9999)
                THROW 53048, 'Quantity must be between 0 and 9999.', 1;
            IF @Operation = N'AddCart' AND (@Quantity IS NULL OR @Quantity = 0)
                THROW 53048, 'Quantity must be positive.', 1;
            DECLARE @Existing INT, @Next INT, @Stock INT;
            SELECT @Existing = Quantity FROM dbo.CartItems WITH (UPDLOCK, ROWLOCK)
                WHERE UserId = @UserId AND VariantId = @Id;
            SET @Next = CASE WHEN @Operation = N'AddCart' THEN ISNULL(@Existing, 0) + @Quantity
                             ELSE COALESCE(@Quantity, @Existing) END;
            IF @Next IS NULL THROW 53048, 'Cart item no longer exists.', 1;
            IF @Quantity IS NOT NULL AND @Next > 0
            BEGIN
                SELECT @Stock = i.CurrentStock - i.ReservedStock
                FROM dbo.v_VisibleProductVariants v
                JOIN dbo.Inventories i ON i.VariantId = v.Id
                WHERE v.Id = @Id;
                IF @Stock IS NULL OR @Next > @Stock OR @Next > 9999
                    THROW 53048, 'Requested quantity is unavailable.', 1;
            END;
            IF @Next = 0 DELETE dbo.CartItems WHERE UserId = @UserId AND VariantId = @Id;
            ELSE IF @Existing IS NULL
                INSERT dbo.CartItems(UserId, VariantId, Quantity, IsSelected)
                VALUES (@UserId, @Id, @Next, ISNULL(@IsSelected, 1));
            ELSE UPDATE dbo.CartItems SET Quantity = @Next, IsSelected = COALESCE(@IsSelected, IsSelected),
                UpdatedAt = SYSUTCDATETIME() WHERE UserId = @UserId AND VariantId = @Id;
        END
        ELSE IF @Operation = N'RemoveCart'
            DELETE dbo.CartItems WHERE UserId = @UserId AND VariantId = @Id;
        ELSE IF @Operation = N'ClearCart'
            DELETE dbo.CartItems WHERE UserId = @UserId;
        ELSE IF @Operation = N'SelectCart'
            UPDATE dbo.CartItems SET IsSelected = ISNULL(@IsSelected, 0), UpdatedAt = SYSUTCDATETIME() WHERE UserId = @UserId;
        ELSE IF @Operation = N'SaveFavorite'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.v_VisibleProducts WHERE Id = @Id)
                THROW 53048, 'Product is unavailable.', 1;
            IF NOT EXISTS (SELECT 1 FROM dbo.Favorites WHERE UserId = @UserId AND ProductId = @Id)
                INSERT dbo.Favorites(UserId, ProductId) VALUES (@UserId, @Id);
        END
        ELSE IF @Operation = N'RemoveFavorite'
            DELETE dbo.Favorites WHERE UserId = @UserId AND ProductId = @Id;
        ELSE IF @Operation = N'ClearFavorites'
            DELETE dbo.Favorites WHERE UserId = @UserId;
        ELSE THROW 53048, 'Unsupported shopping operation.', 1;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
    -- Cart changes never reserve or decrement inventory; checkout owns allocation.
    EXEC dbo.sp_GetShoppingState @UserId;
END;

GO

-- Stored Procedure (60): sp_ChangeUserPassword
CREATE OR ALTER PROCEDURE dbo.sp_ChangeUserPassword
    @UserId INT,
    @NewPasswordHash NVARCHAR(512),
    @NewSalt NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1)
        THROW 53004, N'User account not found or inactive.', 1;

    IF @NewPasswordHash IS NULL OR LEN(@NewPasswordHash) = 0
        THROW 53005, N'Password hash is required.', 1;

    UPDATE dbo.Users
    SET PasswordHash = @NewPasswordHash,
        Salt = @NewSalt,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    SELECT 1 AS Success;
END;

GO

-- Stored Procedure (61): sp_ConfirmHitPayOrder
-- ----------------------------------------------------------------------------
-- 9. Procedure: dbo.sp_ConfirmHitPayOrder (Reservation-Aware Stock Verification)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_ConfirmHitPayOrder
    @OrderNumber NVARCHAR(50),
    @GatewayReference NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@GatewayReference)), N'') IS NULL
        THROW 52204, N'Payment reference is required.', 1;

    BEGIN TRANSACTION;

    DECLARE @OrderId INT,
            @Status NVARCHAR(50),
            @Total DECIMAL(18,2),
            @CustomerUserId INT;

    SELECT @OrderId = Id,
           @Status = Status,
           @Total = TotalAmount,
           @CustomerUserId = UserId
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK)
    WHERE OrderNumber = @OrderNumber AND OrderSource = N'ONLINE';

    IF @OrderId IS NULL
        THROW 52205, N'Online order not found.', 1;

    IF @Status = N'Processing' AND EXISTS
    (
        SELECT 1
        FROM dbo.Payments
        WHERE OrderId = @OrderId
          AND PaymentGateway = N'HitPay'
          AND GatewayReference = @GatewayReference
          AND Status = N'Completed'
    )
    BEGIN
        COMMIT TRANSACTION;
        SELECT @OrderId AS Id, CONVERT(BIT, 0) AS Processed;
        RETURN;
    END;

    IF @Status <> N'PendingPayment'
        THROW 52206, N'Order cannot accept this payment.', 1;

    DECLARE @Lines TABLE
    (
        VariantId INT PRIMARY KEY,
        Quantity INT NOT NULL,
        OldStock INT NOT NULL,
        OldReservedStock INT NOT NULL
    );

    DECLARE @VariantId INT,
            @Quantity INT,
            @OldStock INT,
            @OldReservedStock INT;

    DECLARE line_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT VariantId, SUM(Quantity)
        FROM dbo.OrderItems
        WHERE OrderId = @OrderId
        GROUP BY VariantId
        ORDER BY VariantId;

    OPEN line_cursor;
    FETCH NEXT FROM line_cursor INTO @VariantId, @Quantity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @OldStock = CurrentStock,
               @OldReservedStock = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        -- Stock was already reserved for this order during checkout (via sp_ReserveStockAtomic).
        -- Physical stock must be sufficient to fulfill the quantity.
        IF @OldStock IS NULL OR @OldStock < @Quantity
            THROW 52207, N'Paid order has insufficient physical stock; manual resolution required.', 1;

        INSERT @Lines (VariantId, Quantity, OldStock, OldReservedStock)
        VALUES (@VariantId, @Quantity, @OldStock, @OldReservedStock);

        SET @OldStock = NULL;
        SET @OldReservedStock = NULL;
        FETCH NEXT FROM line_cursor INTO @VariantId, @Quantity;
    END;

    CLOSE line_cursor;
    DEALLOCATE line_cursor;

    -- Deduct physical stock and consume the reservation
    UPDATE i
    SET CurrentStock = i.CurrentStock - l.Quantity,
        ReservedStock = CASE
            WHEN i.ReservedStock >= l.Quantity THEN i.ReservedStock - l.Quantity
            ELSE 0
        END,
        UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Inventories i
    INNER JOIN @Lines l ON l.VariantId = i.VariantId;

    INSERT dbo.StockAuditLogs
        (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes)
    SELECT VariantId, @CustomerUserId, N'ONLINE_SALE', OldStock, -Quantity,
           @OrderNumber, N'HitPay payment confirmed; reservation converted to sale.'
    FROM @Lines;

    INSERT dbo.Payments
        (OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt)
    VALUES
        (@OrderId, N'HitPay', @GatewayReference, @Total, N'Completed', SYSUTCDATETIME());

    UPDATE dbo.Orders
    SET Status = N'Processing', UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @OrderId;

    COMMIT TRANSACTION;
    SELECT @OrderId AS Id, CONVERT(BIT, 1) AS Processed;
END;

GO

-- Stored Procedure (62): sp_CreateOrder
-- 5. Stored Procedure: sp_CreateOrder (Updated for Delivery, Fees, and Address)
CREATE OR ALTER PROCEDURE dbo.sp_CreateOrder
    @OrderNumber NVARCHAR(50),
    @UserId INT = NULL,
    @CustomerName NVARCHAR(100),
    @CustomerEmail NVARCHAR(256),
    @CustomerPhone NVARCHAR(30),
    @OrderSource NVARCHAR(30) = 'ONLINE',
    @Status NVARCHAR(50) = 'Processing',
    @Subtotal DECIMAL(18,2),
    @DiscountAmount DECIMAL(18,2) = 0.00,
    @TotalAmount DECIMAL(18,2),
    @Notes NVARCHAR(500) = NULL,
    @ShippingMethod NVARCHAR(50) = 'Pickup',
    @ShippingFee DECIMAL(18,2) = 0.00,
    @ShippingRegion NVARCHAR(100) = NULL,
    @ShippingAddress NVARCHAR(300) = NULL,
    @ShippingBarangay NVARCHAR(100) = NULL,
    @ShippingCity NVARCHAR(100) = NULL,
    @ShippingProvince NVARCHAR(100) = NULL,
    @ShippingPostalCode NVARCHAR(20) = NULL,
    @DeliveryNotes NVARCHAR(500) = NULL,
    @NewOrderId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @ShippingFee IS NULL SET @ShippingFee = 0.00;
    IF @ShippingMethod IS NULL SET @ShippingMethod = 'Pickup';

    IF @Subtotal IS NULL OR @DiscountAmount IS NULL OR @TotalAmount IS NULL
       OR @Subtotal < 0 OR @DiscountAmount < 0 OR @DiscountAmount > @Subtotal
       OR @ShippingFee < 0
       OR @TotalAmount <> CONVERT(DECIMAL(18,2), @Subtotal - @DiscountAmount + @ShippingFee)
        THROW 51012, N'Order amounts are inconsistent.', 1;

    INSERT INTO dbo.Orders (
        OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, Notes,
        ShippingMethod, ShippingFee, ShippingRegion, ShippingAddress,
        ShippingBarangay, ShippingCity, ShippingProvince, ShippingPostalCode,
        DeliveryNotes, CreatedAt
    ) VALUES (
        @OrderNumber, @UserId, @CustomerName, @CustomerEmail, @CustomerPhone,
        @OrderSource, @Status, @Subtotal, @DiscountAmount, @Notes,
        @ShippingMethod, @ShippingFee, @ShippingRegion, @ShippingAddress,
        @ShippingBarangay, @ShippingCity, @ShippingProvince, @ShippingPostalCode,
        @DeliveryNotes, SYSUTCDATETIME()
    );

    SET @NewOrderId = SCOPE_IDENTITY();
END;

GO

-- Stored Procedure (63): sp_CreatePhysicalSale
CREATE OR ALTER PROCEDURE dbo.sp_CreatePhysicalSale
    @OrderNumber NVARCHAR(50), 
    @ActorUserId INT = NULL,
    @CustomerName NVARCHAR(100), 
    @CustomerEmail NVARCHAR(256), 
    @CustomerPhone NVARCHAR(30),
    @OrderSource NVARCHAR(30), 
    @OrderStatus NVARCHAR(50), 
    @PaymentMethod NVARCHAR(50),
    @PaymentStatus NVARCHAR(50), 
    @Notes NVARCHAR(500), 
    @Items dbo.SaleLineInput READONLY,
    @CashTendered DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM @Items) OR EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0)
        THROW 52201, N'Sale needs positive item quantities.', 1;

    IF @PaymentMethod NOT IN (N'Cash', N'Card_POS') OR
       (@OrderSource = N'INSTORE_POS' AND (@OrderStatus <> N'Completed' OR @PaymentStatus <> N'Completed')) OR
       (@OrderSource = N'ONLINE' AND (@OrderStatus <> N'Processing' OR @PaymentStatus <> N'Pending')) OR
       @OrderSource NOT IN (N'INSTORE_POS', N'ONLINE')
        THROW 52202, N'Invalid physical sale options.', 1;

    BEGIN TRANSACTION;

    DECLARE @Lines TABLE (VariantId INT PRIMARY KEY, Quantity INT, UnitPrice DECIMAL(18,2), OldStock INT);
    DECLARE @VariantId INT, @Quantity INT, @UnitPrice DECIMAL(18,2), @OldStock INT;
    DECLARE sale_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT VariantId, SUM(Quantity) FROM @Items GROUP BY VariantId;
    OPEN sale_cursor;
    FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @OldStock = CurrentStock - ReservedStock,
               @UnitPrice = dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
                    p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
                    p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)
        FROM dbo.Inventories i WITH (UPDLOCK, ROWLOCK)
        JOIN dbo.ProductVariants v ON v.Id = i.VariantId
        JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
        JOIN dbo.Products p ON p.Id = c.ProductId
        WHERE i.VariantId = @VariantId AND p.IsActive = 1 AND v.IsActive = 1;

        IF @OldStock IS NULL OR @OldStock < @Quantity
            THROW 52203, N'Insufficient stock available for physical sale.', 1;

        INSERT @Lines VALUES (@VariantId, @Quantity, @UnitPrice, @OldStock);
        SET @UnitPrice = NULL;
        SET @OldStock = NULL;
        FETCH NEXT FROM sale_cursor INTO @VariantId, @Quantity;
    END;
    CLOSE sale_cursor;
    DEALLOCATE sale_cursor;

    DECLARE @Subtotal DECIMAL(18,2) = (SELECT SUM(Quantity * UnitPrice) FROM @Lines);
    IF @OrderSource = N'INSTORE_POS' AND @PaymentMethod = N'Cash' AND
       (@CashTendered IS NULL OR @CashTendered < @Subtotal)
        THROW 52208, N'Cash tendered is less than the current sale total.', 1;

    INSERT dbo.Orders (OrderNumber, UserId, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, Notes)
    VALUES (@OrderNumber, CASE WHEN @OrderSource = N'ONLINE' THEN @ActorUserId ELSE NULL END,
        @CustomerName, @CustomerEmail, @CustomerPhone,
        @OrderSource, @OrderStatus, @Subtotal, 0, @Notes);

    DECLARE @OrderId INT = CONVERT(INT, SCOPE_IDENTITY());
    UPDATE dbo.Orders SET CashTendered = @CashTendered WHERE Id = @OrderId;

    -- Capture snapshots inside SQL
    INSERT dbo.OrderItems (OrderId, VariantId, Quantity, UnitPrice, ProductName, SKU, ColorName, Size)
    SELECT 
        @OrderId, 
        l.VariantId, 
        l.Quantity, 
        l.UnitPrice,
        p.Name,
        v.SKU,
        c.Color,
        v.Size
    FROM @Lines l
    INNER JOIN dbo.ProductVariants v ON v.Id = l.VariantId
    INNER JOIN dbo.ProductColors c ON c.Id = v.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = c.ProductId;

    UPDATE i SET CurrentStock = i.CurrentStock - l.Quantity, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId;

    INSERT dbo.StockAuditLogs (VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber)
    SELECT VariantId, @ActorUserId, CASE WHEN @OrderSource = N'INSTORE_POS' THEN N'INSTORE_SALE' ELSE N'ONLINE_SALE' END,
           OldStock, -Quantity, @OrderNumber FROM @Lines;

    INSERT dbo.Payments (OrderId, PaymentGateway, Amount, Status, PaidAt)
    VALUES (@OrderId, @PaymentMethod, @Subtotal, @PaymentStatus,
        CASE WHEN @PaymentStatus = N'Completed' THEN SYSUTCDATETIME() ELSE NULL END);

    INSERT dbo.RestockAlerts (InventoryId, Severity)
    SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i JOIN @Lines l ON l.VariantId = i.VariantId
    WHERE i.IsLowStock = 1 AND NOT EXISTS
        (SELECT 1 FROM dbo.RestockAlerts a WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);

    COMMIT TRANSACTION;
    SELECT @OrderId AS Id;
END;

GO

-- Stored Procedure (64): sp_CreateReturnRequest
-- ----------------------------------------------------------------------------
-- 10. Procedure: dbo.sp_CreateReturnRequest (Safe Concurrency & Sequence)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CreateReturnRequest
    @OrderId INT,
    @OrderItemId INT,
    @UserId INT = NULL,
    @RequestType NVARCHAR(20),
    @Reason NVARCHAR(50),
    @ExchangeVariantId INT = NULL,
    @CustomerNotes NVARCHAR(1000) = NULL,
    @NewRmaId INT OUTPUT,
    @NewRmaNumber NVARCHAR(30) OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OrderStatus NVARCHAR(50);
        SELECT @OrderStatus = Status FROM dbo.Orders WHERE Id = @OrderId;

        IF @OrderStatus IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order does not exist.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @OrderStatus NOT IN (N'Completed', N'Delivered')
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Only delivered or completed orders are eligible for return or exchange.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.OrderItems WHERE Id = @OrderItemId AND OrderId = @OrderId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Order item does not belong to this order.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Concurrency locking on item active returns
        IF EXISTS (SELECT 1 FROM dbo.ReturnRequests WITH (UPDLOCK, HOLDLOCK) WHERE OrderItemId = @OrderItemId AND Status NOT IN (N'Rejected', N'Cancelled'))
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'An active return or exchange request already exists for this item.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Safe atomic sequence generation
        DECLARE @DatePrefix NVARCHAR(12) = N'RMA-' + FORMAT(SYSUTCDATETIME(), N'yyyyMMdd') + N'-';
        DECLARE @NextSeq BIGINT = NEXT VALUE FOR dbo.Seq_RmaNumber;
        SET @NewRmaNumber = @DatePrefix + RIGHT(N'0000' + CAST((@NextSeq % 10000) AS NVARCHAR(10)), 4);

        INSERT INTO dbo.ReturnRequests (
            RmaNumber,
            OrderId,
            OrderItemId,
            UserId,
            RequestType,
            Reason,
            ExchangeVariantId,
            CustomerNotes,
            Status,
            Restocked
        )
        VALUES (
            @NewRmaNumber,
            @OrderId,
            @OrderItemId,
            @UserId,
            @RequestType,
            @Reason,
            @ExchangeVariantId,
            @CustomerNotes,
            N'Pending',
            0
        );

        SET @NewRmaId = CONVERT(INT, SCOPE_IDENTITY());
        SET @Success = 1;
        SET @ErrorMessage = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;

GO

-- Stored Procedure (65): sp_CustomerCancelOrder
CREATE OR ALTER PROCEDURE dbo.sp_CustomerCancelOrder
    @OrderId INT, @UserId INT = NULL, @UserEmail NVARCHAR(256) = NULL,
    @Reason NVARCHAR(255) = N'Customer requested cancellation', @Success BIT OUTPUT, @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @OwnerId INT, @Status NVARCHAR(50), @Number NVARCHAR(50), @Committed BIT;
        SELECT @OwnerId = UserId, @Status = Status, @Number = OrderNumber
        FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @OrderId;
        IF @UserId IS NULL OR @OwnerId IS NULL OR @OwnerId <> @UserId
            THROW 52302, N'You are not authorized to cancel this order.', 1;
        IF @Status NOT IN (N'PendingPayment', N'Processing') THROW 52303, N'This order can no longer be cancelled.', 1;
        SET @Committed = CASE WHEN EXISTS (SELECT 1 FROM dbo.StockAuditLogs WHERE ReferenceNumber = @Number AND ChangeType = N'ONLINE_SALE' AND QuantityChanged < 0) THEN 1 ELSE 0 END;
        IF @Committed = 1 EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RESTORE', @UserId;
        ELSE EXEC dbo.sp_ChangeOrderInventory @OrderId, N'RELEASE', @UserId;
        UPDATE dbo.Orders SET Status = N'Cancelled',
            Notes = LEFT(CONCAT(Notes, N' | Cancelled by customer: ', @Reason,
                CASE WHEN EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderId = @OrderId AND Status = N'Completed') THEN N' | Refund pending manual confirmation.' ELSE N'' END), 500),
            UpdatedAt = SYSUTCDATETIME() WHERE Id = @OrderId;
        -- Keep completed payment history intact. Cancellation alone does not prove a refund.
        UPDATE dbo.Payments SET Status = N'Cancelled' WHERE OrderId = @OrderId AND Status IN (N'Pending', N'Failed');
        EXEC dbo.sp_RefreshOrderStockAlerts @OrderId;
        COMMIT TRANSACTION;
        SET @Success = 1; SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0; SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;

GO

-- Stored Procedure (66): sp_DeductStockAtomic
CREATE OR ALTER PROCEDURE dbo.sp_DeductStockAtomic
    @VariantId INT,
    @Quantity INT,
    @UserId INT = NULL,
    @ChangeType NVARCHAR(50), -- 'ONLINE_SALE' or 'INSTORE_SALE'
    @OrderNumber NVARCHAR(100),
    @RemainingStock INT OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Success = 0;
    SET @RemainingStock = NULL;
    SET @ErrorMessage = NULL;
    IF @Quantity IS NULL OR @Quantity <= 0
    BEGIN
        SET @ErrorMessage = N'Quantity must be greater than zero.';
        RETURN;
    END;
    IF @ChangeType NOT IN (N'ONLINE_SALE', N'INSTORE_SALE') OR @ChangeType IS NULL
    BEGIN
        SET @ErrorMessage = N'Invalid sale change type.';
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStock INT, @ReservedStock INT;

        -- Pessimistic locking of the inventory row
        SELECT @CurrentStock = CurrentStock, @ReservedStock = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        IF @CurrentStock IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = 'Variant inventory record not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @CurrentStock - @ReservedStock < @Quantity
        BEGIN
            SET @Success = 0;
            SET @RemainingStock = @CurrentStock;
            SET @ErrorMessage = CONCAT('Insufficient stock. Available: ', @CurrentStock - @ReservedStock, ', Requested: ', @Quantity);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Perform atomic deduction
        UPDATE dbo.Inventories
        SET CurrentStock = CurrentStock - @Quantity,
            UpdatedAt = SYSUTCDATETIME()
        WHERE VariantId = @VariantId AND CurrentStock - ReservedStock >= @Quantity;

        IF @@ROWCOUNT <> 1
            THROW 51010, N'Inventory changed during deduction.', 1;

        SET @RemainingStock = @CurrentStock - @Quantity;

        -- Record in audit log
        INSERT INTO dbo.StockAuditLogs (
            VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes
        ) VALUES (
            @VariantId, @UserId, @ChangeType, @CurrentStock, -@Quantity, @OrderNumber, 
            CONCAT('Stock deducted via ', @ChangeType)
        );

        -- If remaining stock reaches or falls below reorder point, trigger alert
        DECLARE @ReorderPoint INT, @InvId INT;
        SELECT @InvId = Id, @ReorderPoint = ReorderPoint FROM dbo.Inventories WHERE VariantId = @VariantId;

        IF @RemainingStock - @ReservedStock <= @ReorderPoint
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.RestockAlerts WHERE InventoryId = @InvId AND IsDismissed = 0)
                UPDATE dbo.RestockAlerts
                SET Severity = CASE WHEN @RemainingStock - @ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
                WHERE InventoryId = @InvId AND IsDismissed = 0;
            ELSE
                INSERT INTO dbo.RestockAlerts (InventoryId, Severity)
                VALUES (@InvId, CASE WHEN @RemainingStock - @ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END);
        END

        COMMIT TRANSACTION;

        SET @Success = 1;
        SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;

GO

-- Stored Procedure (67): sp_DeleteUserAddress
CREATE OR ALTER PROCEDURE dbo.sp_DeleteUserAddress
    @Id INT,
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.UserAddresses
    WHERE Id = @Id AND UserId = @UserId;

    -- If deleted address was default, set the newest remaining address as default
    IF NOT EXISTS (SELECT 1 FROM dbo.UserAddresses WHERE UserId = @UserId AND IsDefault = 1)
    BEGIN
        DECLARE @NewDefaultId INT;
        SELECT TOP 1 @NewDefaultId = Id 
        FROM dbo.UserAddresses 
        WHERE UserId = @UserId 
        ORDER BY Id DESC;

        IF @NewDefaultId IS NOT NULL
        BEGIN
            UPDATE dbo.UserAddresses
            SET IsDefault = 1,
                UpdatedAt = SYSUTCDATETIME()
            WHERE Id = @NewDefaultId;
        END
    END

    SELECT 1 AS Success;
END;

GO

-- Stored Procedure (68): sp_GetBrands
CREATE OR ALTER PROCEDURE dbo.sp_GetBrands
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        b.Id,
        b.Name,
        b.LogoUrl,
        b.Website,
        COUNT(p.Id) AS ProductCount
    FROM dbo.Brands b
    LEFT JOIN dbo.v_VisibleProducts p ON b.Id = p.BrandId AND p.IsActive = 1
        AND EXISTS (
            SELECT 1 FROM dbo.v_VisibleProductColors pc
            JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
            WHERE pc.ProductId = p.Id AND pv.IsActive = 1
        )
    WHERE b.IsActive = 1
    GROUP BY b.Id, b.Name, b.LogoUrl, b.Website
    HAVING COUNT(p.Id) > 0
    ORDER BY b.Name ASC;
END;

GO

-- Stored Procedure (69): sp_GetCategories
CREATE OR ALTER PROCEDURE dbo.sp_GetCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        c.Id,
        c.Name,
        c.Slug,
        c.Description,
        c.DisplayOrder,
        COUNT(p.Id) AS ProductCount
    FROM dbo.Categories c
    LEFT JOIN dbo.v_VisibleProducts p ON c.Id = p.CategoryId AND p.IsActive = 1
        AND EXISTS (
            SELECT 1 FROM dbo.v_VisibleProductColors pc
            JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
            WHERE pc.ProductId = p.Id AND pv.IsActive = 1
        )
    GROUP BY c.Id, c.Name, c.Slug, c.Description, c.DisplayOrder
    ORDER BY c.DisplayOrder ASC;
END;

GO

-- Stored Procedure (70): sp_GetCustomerReturnRequests
CREATE OR ALTER PROCEDURE dbo.sp_GetCustomerReturnRequests
    @OrderId INT = NULL,
    @UserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        rma.Id,
        rma.RmaNumber,
        rma.OrderId,
        o.OrderNumber,
        rma.OrderItemId,
        oi.VariantId,
        p.Name AS ProductName,
        pc.Color AS ColorName,
        pv.Size,
        oi.Quantity,
        oi.UnitPrice,
        p.MainImageUrl,
        rma.UserId,
        rma.RequestType,
        rma.Reason,
        rma.ExchangeVariantId,
        rma.CustomerNotes,
        rma.Status,
        rma.ResolutionType,
        rma.RefundAmount,
        rma.Restocked,
        rma.AdminNotes,
        rma.CreatedAt,
        rma.UpdatedAt
    FROM dbo.ReturnRequests rma
    INNER JOIN dbo.Orders o ON o.Id = rma.OrderId
    INNER JOIN dbo.OrderItems oi ON oi.Id = rma.OrderItemId
    INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
    INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
    INNER JOIN dbo.Products p ON p.Id = pc.ProductId
    WHERE (@OrderId IS NULL OR rma.OrderId = @OrderId)
      AND (@UserId IS NULL OR rma.UserId = @UserId)
    ORDER BY rma.CreatedAt DESC;
END;

GO

-- Stored Procedure (71): sp_GetInventoryList
CREATE OR ALTER PROCEDURE dbo.sp_GetInventoryList
    @LowStockOnly BIT = 0,
    @Search NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.Id AS InventoryId,
        pv.Id AS VariantId,
        p.Name AS ProductName,
        b.Name AS Brand,
        pv.SKU,
        pv.Size,
        pc.Color,
        i.CurrentStock,
        i.ReservedStock,
        i.ReorderPoint,
        i.IsLowStock,
        i.LastRestockedAt
    FROM dbo.v_VisibleInventories i
    INNER JOIN dbo.v_VisibleProductVariants pv ON i.VariantId = pv.Id
    INNER JOIN dbo.v_VisibleProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.v_VisibleProducts p ON pc.ProductId = p.Id
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    WHERE (@LowStockOnly = 0 OR i.IsLowStock = 1)
      AND (@Search IS NULL OR p.Name LIKE '%' + @Search + '%' OR pv.SKU LIKE '%' + @Search + '%')
    ORDER BY i.IsLowStock DESC, i.CurrentStock ASC;
END;

GO

-- Stored Procedure (72): sp_GetInventoryStatusByVariantId
CREATE OR ALTER PROCEDURE dbo.sp_GetInventoryStatusByVariantId
    @VariantId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.Id AS InventoryId,
        pv.Id AS VariantId,
        p.Name AS ProductName,
        b.Name AS Brand,
        pv.SKU,
        pv.Size,
        pc.Color,
        i.CurrentStock,
        i.ReservedStock,
        i.ReorderPoint,
        i.IsLowStock,
        i.LastRestockedAt
    FROM dbo.v_VisibleInventories i
    INNER JOIN dbo.v_VisibleProductVariants pv ON i.VariantId = pv.Id
    INNER JOIN dbo.v_VisibleProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.v_VisibleProducts p ON pc.ProductId = p.Id
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    WHERE pv.Id = @VariantId;
END;

GO

-- Stored Procedure (73): sp_GetOrderDetails
-- 1. STORED PROCEDURE: sp_GetOrderDetails
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetOrderDetails
    @OrderNumber NVARCHAR(100) = NULL,
    @OrderId INT = NULL,
    @PaymentReference NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedId INT;

    IF @OrderId IS NOT NULL
        SET @ResolvedId = @OrderId;
    ELSE IF @OrderNumber IS NOT NULL
    BEGIN
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber;
        -- Fallback: check if @OrderNumber is a HitPay / Payment GatewayReference
        IF @ResolvedId IS NULL
        BEGIN
            SELECT TOP 1 @ResolvedId = p.OrderId 
            FROM dbo.Payments p 
            WHERE p.GatewayReference = @OrderNumber
            ORDER BY p.Id DESC;
        END
    END
    ELSE IF @PaymentReference IS NOT NULL
    BEGIN
        SELECT TOP 1 @ResolvedId = p.OrderId 
        FROM dbo.Payments p 
        WHERE p.GatewayReference = @PaymentReference
        ORDER BY p.Id DESC;
    END

    IF @ResolvedId IS NULL
        THROW 51018, N'Order not found.', 1;

    -- Result Set 1: Order Header
    SELECT
        o.Id,
        o.OrderNumber,
        o.UserId,
        o.CustomerName,
        o.CustomerEmail,
        o.CustomerPhone,
        o.OrderSource,
        o.Status,
        o.Subtotal,
        o.DiscountAmount,
        o.VoucherCode,
        o.CashTendered,
        o.TotalAmount,
        o.ShippingMethod,
        o.ShippingFee,
        o.ShippingRegion,
        o.ShippingAddress,
        o.ShippingBarangay,
        o.ShippingCity,
        o.ShippingProvince,
        o.ShippingPostalCode,
        o.Courier,
        o.TrackingNumber,
        o.DeliveryNotes,
        o.Notes,
        o.CreatedAt,
        o.UpdatedAt,
        (SELECT COUNT(*) FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id) AS RmaCount,
        (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaType,
        (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaStatus,
        (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaResolution
    FROM dbo.Orders o
    WHERE o.Id = @ResolvedId;

    -- Result Set 2: Order Items
    SELECT
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        c.ProductId AS ProductId,
        oi.Quantity,
        oi.UnitPrice,
        oi.TotalPrice,
        ISNULL(NULLIF(oi.ProductName, N''), p.Name) AS ProductName,
        p.Slug AS ProductSlug,
        p.MainImageUrl,
        ISNULL(NULLIF(oi.ColorName, N''), c.Color) AS Color,
        ISNULL(NULLIF(oi.Size, N''), v.Size) AS Size,
        ISNULL(NULLIF(oi.SKU, N''), v.SKU) AS SKU,
        (SELECT TOP 1 rr.Id FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaId,
        (SELECT TOP 1 rr.RmaNumber FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaNumber,
        (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaType,
        (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaStatus,
        (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaResolution,
        (SELECT TOP 1 pr.Id FROM dbo.ProductReviews pr WHERE pr.OrderId = oi.OrderId AND pr.ProductId = c.ProductId) AS ReviewId
    FROM dbo.OrderItems oi
    LEFT JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
    LEFT JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
    LEFT JOIN dbo.Products p ON c.ProductId = p.Id
    WHERE oi.OrderId = @ResolvedId;

    -- Result Set 3: Payments
    SELECT
        py.Id,
        py.OrderId,
        py.PaymentGateway,
        py.GatewayReference,
        py.Amount,
        py.Status,
        py.PaidAt,
        py.CreatedAt
    FROM dbo.Payments py
    WHERE py.OrderId = @ResolvedId 
    ORDER BY py.Id DESC;
END;

GO

-- Stored Procedure (74): sp_GetProductById
-- ----------------------------------------------------------------------------
-- 5. Update Procedure: dbo.sp_GetProductById
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetProductById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    SELECT
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.BasePrice,
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        CASE
            WHEN ISNULL(p.DiscountIsActive, 1) = 1
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
            THEN 1 ELSE 0
        END AS IsDiscountActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage,
            p.DiscountType, p.DiscountAmount, p.DiscountStartDate,
            p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        orders.OrderCount,
        p.MainImageUrl,
        p.Description,
        p.PublicationStatus
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    OUTER APPLY
    (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    OUTER APPLY
    (
        SELECT COUNT(DISTINCT oi.OrderId) AS OrderCount
        FROM dbo.v_VisibleProductColors pc
        INNER JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
        INNER JOIN dbo.OrderItems oi ON oi.VariantId = pv.Id
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        WHERE pc.ProductId = p.Id AND o.Status <> N'Cancelled'
    ) orders
    WHERE p.Id = @Id AND p.IsActive = 1;

    SELECT
        pv.Id,
        pc.ProductId,
        pv.SKU,
        pv.Size,
        pc.Color,
        pc.ColorHex,
        pv.PriceAdjustment,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, pv.PriceAdjustment,
            p.DiscountPercentage, p.DiscountType, p.DiscountAmount,
            p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        ISNULL(i.CurrentStock, 0) AS CurrentStock,
        ISNULL(i.ReservedStock, 0) AS ReservedStock,
        ISNULL(i.CurrentStock, 0) - ISNULL(i.ReservedStock, 0) AS AvailableStock,
        ISNULL(i.IsLowStock, 0) AS IsLowStock
    FROM dbo.v_VisibleProductVariants pv
    INNER JOIN dbo.v_VisibleProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.v_VisibleProducts p ON pc.ProductId = p.Id
    LEFT JOIN dbo.v_VisibleInventories i ON pv.Id = i.VariantId
    WHERE pc.ProductId = @Id AND pv.IsActive = 1
    ORDER BY pv.Id ASC;

    SELECT ImageUrl,
           COALESCE(AltText, N'Product view') AS AltText,
           CONVERT(INT, DisplayOrder) AS DisplayOrder
    FROM dbo.ProductGalleryImages
    WHERE ProductId = @Id AND IsActive = 1
    ORDER BY DisplayOrder ASC, Id ASC;
END;

GO

-- Stored Procedure (75): sp_GetProductBySlug
-- ----------------------------------------------------------------------------
-- 6. Update Procedure: dbo.sp_GetProductBySlug
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetProductBySlug
    @Slug NVARCHAR(220)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Id INT;
    SELECT @Id = Id FROM dbo.v_VisibleProducts WHERE Slug = @Slug;

    IF @Id IS NULL
    BEGIN
        SELECT TOP 0 1 AS ProductNotFound;
        RETURN;
    END

    EXEC dbo.sp_GetProductById @Id = @Id;
END;

GO

-- Stored Procedure (76): sp_GetProductReviews
-- 1. STORED PROCEDURE: sp_GetProductReviews
-- Allows logged-in users to view their own reviews even if hidden (@CurrentUserId)
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetProductReviews
    @ProductId INT,
    @IncludeHidden BIT = 0,
    @CurrentUserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        reviews.Id,
        reviews.ProductId,
        reviews.UserId,
        reviews.OrderId,
        reviews.ReviewerName,
        reviews.Rating,
        reviews.Title,
        reviews.Comment,
        reviews.IsVerifiedPurchase,
        (SELECT COUNT(*) FROM dbo.ReviewReports reports WHERE reports.ReviewId = reviews.Id) AS FlagCount,
        reviews.IsHidden,
        reviews.CreatedAt
    FROM dbo.ProductReviews reviews
    WHERE reviews.ProductId = @ProductId
      AND (
          @IncludeHidden = 1 
          OR reviews.IsHidden = 0 
          OR (reviews.UserId IS NOT NULL AND @CurrentUserId IS NOT NULL AND reviews.UserId = @CurrentUserId)
      )
    ORDER BY 
        -- If current user review is hidden, float it to top so user sees their own review status
        CASE WHEN reviews.UserId = @CurrentUserId AND reviews.IsHidden = 1 THEN 0 ELSE 1 END,
        reviews.CreatedAt DESC;
END;

GO

-- Stored Procedure (77): sp_GetProductsPaged
-- ----------------------------------------------------------------------------
-- 4. Update Procedure: dbo.sp_GetProductsPaged
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetProductsPaged
    @CategoryId INT = NULL,
    @BrandId INT = NULL,
    @Brand NVARCHAR(200) = NULL,
    @Category NVARCHAR(100) = NULL,
    @RidingStyle NVARCHAR(50) = NULL, -- Deprecated, kept for backward compatibility
    @Search NVARCHAR(200) = NULL,
    @OnSale BIT = 0,
    @MinPrice DECIMAL(18,2) = NULL,
    @MaxPrice DECIMAL(18,2) = NULL,
    @Colors NVARCHAR(200) = NULL,
    @Sizes NVARCHAR(100) = NULL,
    @SortBy NVARCHAR(50) = 'popular',
    @PageNumber INT = 1,
    @PageSize INT = 9,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), N'');
    SET @Brand = NULLIF(LTRIM(RTRIM(@Brand)), N'');
    SET @Colors = NULLIF(LTRIM(RTRIM(@Colors)), N'');
    SET @Sizes = NULLIF(LTRIM(RTRIM(@Sizes)), N'');
    IF @PageNumber IS NULL OR @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 9;
    IF @PageSize > 100 SET @PageSize = 100;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    -- Calculate total count
    SELECT @TotalCount = COUNT(*)
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON p.CategoryId = c.Id
    WHERE p.IsActive = 1
      AND (
          ISNULL(@OnSale, 0) = 0 
          OR (
              (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
              AND ISNULL(p.DiscountIsActive, 1) = 1
              AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
              AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
          )
      )
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand OR CHARINDEX(N',' + UPPER(b.Name) + N',', N',' + UPPER(@Brand) + N',') > 0)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.Description LIKE N'%' + @Search + N'%'
          OR EXISTS (
              SELECT 1 
              FROM dbo.v_VisibleProductColors pc_s
              JOIN dbo.v_VisibleProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.v_VisibleProductColors pc
          JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
            AND (@Colors IS NULL OR CHARINDEX(N',' + UPPER(dbo.fn_BaseColorFromHex(pc.ColorHex)) + N',', N',' + UPPER(@Colors) + N',') > 0)
            AND (@Sizes IS NULL OR CHARINDEX(N',' + UPPER(pv.Size) + N',', N',' + UPPER(@Sizes) + N',') > 0)
      );

    -- Paged rows
    SELECT 
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.BasePrice,
        p.DiscountPercentage,
        p.DiscountType,
        p.DiscountAmount,
        p.DiscountStartDate,
        p.DiscountEndDate,
        CASE 
            WHEN ISNULL(p.DiscountIsActive, 1) = 1 
                 AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
                 AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
                 AND (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
            THEN 1 
            ELSE 0 
        END AS IsDiscountActive,
        dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        p.MainImageUrl,
        p.Description,
        p.PublicationStatus,
        sales.UnitsSold
    FROM dbo.v_VisibleProducts p
    INNER JOIN dbo.Brands b ON p.BrandId = b.Id
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    OUTER APPLY (
        SELECT ISNULL(SUM(oi.Quantity), 0) AS UnitsSold
        FROM dbo.OrderItems oi
        INNER JOIN dbo.ProductVariants pv ON pv.Id = oi.VariantId
        INNER JOIN dbo.ProductColors pc ON pc.Id = pv.ProductColorId
        INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
        WHERE pc.ProductId = p.Id
          AND o.Status NOT IN (N'Cancelled', N'Refunded', N'PendingPayment')
    ) sales
    WHERE p.IsActive = 1
      AND (
          ISNULL(@OnSale, 0) = 0 
          OR (
              (p.DiscountPercentage > 0 OR (p.DiscountType = N'FIXED_AMOUNT' AND p.DiscountAmount > 0))
              AND ISNULL(p.DiscountIsActive, 1) = 1
              AND (p.DiscountStartDate IS NULL OR p.DiscountStartDate <= @Now)
              AND (p.DiscountEndDate IS NULL OR p.DiscountEndDate >= @Now)
          )
      )
      AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
      AND (@BrandId IS NULL OR p.BrandId = @BrandId)
      AND (@Brand IS NULL OR @Brand = 'all' OR b.Name = @Brand OR CHARINDEX(N',' + UPPER(b.Name) + N',', N',' + UPPER(@Brand) + N',') > 0)
      AND (@Category IS NULL OR @Category = 'all' OR c.Slug = @Category OR c.Name LIKE '%' + @Category + '%')
      AND (
          @Search IS NULL 
          OR p.Name LIKE N'%' + @Search + N'%'
          OR b.Name LIKE N'%' + @Search + N'%'
          OR c.Name LIKE N'%' + @Search + N'%'
          OR p.Description LIKE N'%' + @Search + N'%'
          OR EXISTS (
              SELECT 1 
              FROM dbo.v_VisibleProductColors pc_s
              JOIN dbo.v_VisibleProductVariants pv_s ON pv_s.ProductColorId = pc_s.Id
              WHERE pc_s.ProductId = p.Id AND pv_s.SKU LIKE N'%' + @Search + N'%'
          )
      )
      AND (@MinPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) >= @MinPrice)
      AND (@MaxPrice IS NULL OR dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) <= @MaxPrice)
      AND EXISTS
      (
          SELECT 1
          FROM dbo.v_VisibleProductColors pc
          JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
            AND (@Colors IS NULL OR CHARINDEX(N',' + UPPER(dbo.fn_BaseColorFromHex(pc.ColorHex)) + N',', N',' + UPPER(@Colors) + N',') > 0)
            AND (@Sizes IS NULL OR CHARINDEX(N',' + UPPER(pv.Size) + N',', N',' + UPPER(@Sizes) + N',') > 0)
      )
    ORDER BY 
        CASE WHEN @SortBy = 'top_selling' THEN sales.UnitsSold END DESC,
        CASE WHEN @SortBy = 'price_asc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END ASC,
        CASE WHEN @SortBy = 'price_desc' THEN dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) END DESC,
        CASE WHEN @SortBy = 'newest' THEN p.CreatedAt END DESC,
        CASE WHEN @SortBy = 'rating' THEN review.Rating END DESC,
        CASE WHEN @SortBy = 'popular' OR @SortBy IS NULL THEN review.ReviewCount END DESC,
        p.CreatedAt DESC,
        p.Id ASC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END;

GO

-- Stored Procedure (78): sp_GetProductSpecifications
CREATE OR ALTER PROCEDURE dbo.sp_GetProductSpecifications
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.SpecificationKey,
           d.DisplayName,
           v.SpecificationValue,
           ISNULL(cs.DisplayOrder, 99) AS DisplayOrder
    FROM dbo.Products p
    INNER JOIN dbo.ProductSpecificationValues v ON v.ProductId = p.Id
    INNER JOIN dbo.SpecificationDefinitions d ON d.Id = v.SpecificationId AND d.IsActive = 1
    LEFT JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId AND cs.SpecificationId = d.Id
    WHERE p.Id = @ProductId
    ORDER BY ISNULL(cs.DisplayOrder, 99), d.DisplayName;
END;

GO

-- Stored Procedure (79): sp_GetRecentOrders
CREATE OR ALTER PROCEDURE dbo.sp_GetRecentOrders
    @Limit INT = 20,
    @Status NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Limit)
        Id, OrderNumber, CustomerName, CustomerEmail, CustomerPhone,
        OrderSource, Status, Subtotal, DiscountAmount, TotalAmount, CreatedAt
    FROM dbo.Orders
    WHERE (@Status IS NULL OR Status = @Status)
    ORDER BY CreatedAt DESC;
END;

GO

-- Stored Procedure (80): sp_GetRelatedProducts
-- ----------------------------------------------------------------------------
-- 7. Update Procedure: dbo.sp_GetRelatedProducts
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_GetRelatedProducts
    @ProductId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (4)
        p.Id,
        p.Name,
        p.Slug,
        b.Name AS Brand,
        c.Name AS Category,
        p.BasePrice,
        p.DiscountPercentage,
        CAST(p.BasePrice * (1.0 - p.DiscountPercentage / 100.0) AS DECIMAL(18,2)) AS EffectivePrice,
        review.Rating,
        review.ReviewCount,
        p.MainImageUrl,
        p.Description,
        p.PublicationStatus
    FROM dbo.v_VisibleProducts sourceProduct
    INNER JOIN dbo.v_VisibleProducts p ON p.Id <> sourceProduct.Id AND p.IsActive = 1
    INNER JOIN dbo.Brands b ON b.Id = p.BrandId
    INNER JOIN dbo.Categories c ON c.Id = p.CategoryId
    OUTER APPLY (
        SELECT CAST(COALESCE(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
               COUNT(*) AS ReviewCount
        FROM dbo.ProductReviews r
        WHERE r.ProductId = p.Id AND r.IsHidden = 0
    ) review
    WHERE sourceProduct.Id = @ProductId AND sourceProduct.IsActive = 1
      AND EXISTS (
          SELECT 1 FROM dbo.v_VisibleProductColors pc
          INNER JOIN dbo.v_VisibleProductVariants pv ON pv.ProductColorId = pc.Id
          WHERE pc.ProductId = p.Id AND pv.IsActive = 1
      )
    ORDER BY CASE
                 WHEN p.CategoryId = sourceProduct.CategoryId AND p.BrandId = sourceProduct.BrandId THEN 0
                 WHEN p.CategoryId = sourceProduct.CategoryId THEN 1
                 WHEN p.BrandId = sourceProduct.BrandId THEN 2
                 ELSE 3
             END,
             review.Rating DESC,
             review.ReviewCount DESC,
             p.CreatedAt DESC,
             p.Id ASC;
END;

GO

-- Stored Procedure (81): sp_GetShoppingState
CREATE OR ALTER PROCEDURE dbo.sp_GetShoppingState @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    -- One round trip returns current prices, visibility, stock, and reviews for both collections.
    SELECT (
        SELECT JSON_QUERY((
            SELECT ci.VariantId AS variantId, pc.ProductId AS productId,
                ci.Quantity AS quantity, ci.IsSelected AS isSelected,
                p.Name AS name, b.Name AS brand, v.Size AS size, pc.Color AS color,
                p.MainImageUrl AS imageUrl,
                dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment, p.DiscountPercentage,
                    p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS price,
                CASE WHEN vp.Id IS NULL OR vv.Id IS NULL THEN 0
                     ELSE ISNULL(i.CurrentStock - i.ReservedStock, 0) END AS availableStock
            FROM dbo.CartItems ci
            JOIN dbo.ProductVariants v ON v.Id = ci.VariantId
            JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
            JOIN dbo.Products p ON p.Id = pc.ProductId
            JOIN dbo.Brands b ON b.Id = p.BrandId
            LEFT JOIN dbo.v_VisibleProducts vp ON vp.Id = p.Id
            LEFT JOIN dbo.v_VisibleProductVariants vv ON vv.Id = v.Id
            LEFT JOIN dbo.Inventories i ON i.VariantId = v.Id
            WHERE ci.UserId = @UserId
            ORDER BY ci.Id
            FOR JSON PATH
        )) AS cart,
        JSON_QUERY((
            SELECT f.ProductId AS productId, p.Name AS name, b.Name AS brand, c.Name AS category,
                p.MainImageUrl AS imageUrl, p.BasePrice AS originalPrice,
                dbo.fn_CalculateEffectivePrice(p.BasePrice, 0, p.DiscountPercentage,
                    p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive) AS price,
                p.DiscountPercentage AS discountPercentage,
                review.Rating AS rating, review.ReviewCount AS reviewCount,
                CAST(CASE WHEN NOT EXISTS (
                    SELECT 1 FROM dbo.v_VisibleProductVariants v
                    JOIN dbo.ProductColors pc ON pc.Id = v.ProductColorId
                    JOIN dbo.Inventories i ON i.VariantId = v.Id
                    WHERE pc.ProductId = p.Id AND i.CurrentStock > i.ReservedStock
                ) THEN 1 ELSE 0 END AS BIT) AS isOutOfStock
            FROM dbo.Favorites f
            JOIN dbo.v_VisibleProducts p ON p.Id = f.ProductId
            JOIN dbo.Brands b ON b.Id = p.BrandId
            JOIN dbo.Categories c ON c.Id = p.CategoryId
            OUTER APPLY (
                SELECT CAST(ISNULL(AVG(CAST(r.Rating AS DECIMAL(9,2))), 0) AS DECIMAL(3,2)) AS Rating,
                    COUNT(*) AS ReviewCount
                FROM dbo.ProductReviews r WHERE r.ProductId = p.Id AND r.IsHidden = 0
            ) review
            WHERE f.UserId = @UserId
            ORDER BY f.Id
            FOR JSON PATH
        )) AS favorites
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS ShoppingState;
END;

GO

-- Stored Procedure (82): sp_GetStorefrontStats
CREATE OR ALTER PROCEDURE dbo.sp_GetStorefrontStats
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TotalBrands INT;
    DECLARE @TotalProducts INT;
    DECLARE @CompletedOrders INT;

    SELECT @TotalBrands = COUNT(*) FROM dbo.Brands;
    SELECT @TotalProducts = COUNT(*) FROM dbo.Products;
    SELECT @CompletedOrders = COUNT(*) FROM dbo.Orders WHERE Status = 'Completed';

    SELECT 
        @TotalBrands AS TotalBrands,
        @TotalProducts AS TotalProducts,
        @CompletedOrders AS CompletedOrders;
END;

GO

-- Stored Procedure (83): sp_GetTopCustomerReviews
CREATE OR ALTER PROCEDURE dbo.sp_GetTopCustomerReviews
    @Limit INT = 6
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@Limit)
        r.Id,
        r.ProductId,
        r.ReviewerName,
        r.Rating,
        r.Title,
        r.Comment,
        r.IsVerifiedPurchase,
        r.CreatedAt,
        p.Name AS ProductName,
        p.Slug AS ProductSlug
    FROM dbo.ProductReviews r
    INNER JOIN dbo.Products p ON r.ProductId = p.Id
    WHERE r.IsHidden = 0
    ORDER BY r.Rating DESC, r.CreatedAt DESC, r.Id DESC;
END;

GO

-- Stored Procedure (84): sp_GetUserAddresses
CREATE OR ALTER PROCEDURE dbo.sp_GetUserAddresses
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        a.Id,
        a.UserId,
        a.AddressLabel,
        ISNULL(NULLIF(LTRIM(RTRIM(a.RecipientName)), N''), CONCAT(u.FirstName, N' ', u.LastName)) AS RecipientName,
        ISNULL(NULLIF(LTRIM(RTRIM(a.PhoneNumber)), N''), u.PhoneNumber) AS PhoneNumber,
        a.StreetAddress,
        a.Barangay,
        a.City,
        a.Province,
        a.PostalCode,
        a.DeliveryLandmark,
        a.IsDefault,
        a.CreatedAt,
        a.UpdatedAt
    FROM dbo.UserAddresses a
    INNER JOIN dbo.Users u ON a.UserId = u.Id
    WHERE a.UserId = @UserId
    ORDER BY a.IsDefault DESC, a.Id DESC;
END;

GO

-- Stored Procedure (85): sp_GetUserByEmail
CREATE OR ALTER PROCEDURE dbo.sp_GetUserByEmail
    @Email NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.Id,
        u.RoleId,
        r.Name AS RoleName,
        u.FirstName,
        u.LastName,
        CONCAT(u.FirstName, N' ', u.LastName) AS FullName,
        u.Email,
        u.PasswordHash,
        u.Salt,
        u.PhoneNumber,
        u.IsActive,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.Id
    WHERE u.Email = LOWER(LTRIM(RTRIM(@Email))) AND u.IsActive = 1;
END;

GO

-- Stored Procedure (86): sp_GetUserOrderDetails
-- 5. STORED PROCEDURE: sp_GetUserOrderDetails
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetUserOrderDetails
    @UserId INT,
    @OrderId INT = NULL,
    @OrderNumber NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserId IS NULL
        THROW 52001, N'User identifier is required.', 1;

    DECLARE @ResolvedId INT;

    IF @OrderId IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE Id = @OrderId AND UserId = @UserId;
    ELSE IF @OrderNumber IS NOT NULL
        SELECT @ResolvedId = Id FROM dbo.Orders WHERE OrderNumber = @OrderNumber AND UserId = @UserId;

    IF @ResolvedId IS NULL
        THROW 52002, N'Order not found or access denied.', 1;

    -- Result Set 1: Order Header
    SELECT
        o.Id,
        o.OrderNumber,
        o.UserId,
        o.CustomerName,
        o.CustomerEmail,
        o.CustomerPhone,
        o.OrderSource,
        o.Status,
        o.Subtotal,
        o.DiscountAmount,
        o.VoucherCode,
        o.CashTendered,
        o.ShippingFee,
        o.TotalAmount,
        o.ShippingMethod,
        o.ShippingRegion,
        o.ShippingAddress,
        o.ShippingBarangay,
        o.ShippingCity,
        o.ShippingProvince,
        o.ShippingPostalCode,
        o.Courier,
        o.TrackingNumber,
        o.DeliveryNotes,
        o.Notes,
        o.CreatedAt,
        o.UpdatedAt,
        ISNULL((SELECT TOP 1 p.PaymentGateway FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'HitPay') AS PaymentMethod,
        ISNULL((SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'Pending') AS PaymentStatus,
        (SELECT TOP 1 p.GatewayReference FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS GatewayReference,
        (SELECT TOP 1 p.PaidAt FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS PaidAt,
        (SELECT COUNT(*) FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id) AS RmaCount,
        (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaType,
        (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaStatus,
        (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaResolution
    FROM dbo.Orders o
    WHERE o.Id = @ResolvedId;

    -- Result Set 2: Order Items
    SELECT
        oi.Id,
        oi.OrderId,
        oi.VariantId,
        c.ProductId AS ProductId,
        oi.Quantity,
        oi.UnitPrice,
        oi.TotalPrice,
        ISNULL(NULLIF(oi.ProductName, N''), p.Name) AS ProductName,
        p.Slug AS ProductSlug,
        p.MainImageUrl,
        ISNULL(NULLIF(oi.ColorName, N''), c.Color) AS Color,
        ISNULL(NULLIF(oi.Size, N''), v.Size) AS Size,
        ISNULL(NULLIF(oi.SKU, N''), v.SKU) AS SKU,
        (SELECT TOP 1 rr.Id FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaId,
        (SELECT TOP 1 rr.RmaNumber FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaNumber,
        (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaType,
        (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaStatus,
        (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaResolution,
        (SELECT TOP 1 pr.Id FROM dbo.ProductReviews pr WHERE pr.OrderId = oi.OrderId AND pr.ProductId = c.ProductId) AS ReviewId
    FROM dbo.OrderItems oi
    LEFT JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
    LEFT JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
    LEFT JOIN dbo.Products p ON c.ProductId = p.Id
    WHERE oi.OrderId = @ResolvedId;

    -- Result Set 3: Payments
    SELECT
        py.Id,
        py.OrderId,
        py.PaymentGateway,
        py.GatewayReference,
        py.Amount,
        py.Status,
        py.PaidAt,
        py.CreatedAt
    FROM dbo.Payments py
    WHERE py.OrderId = @ResolvedId ORDER BY py.Id DESC;
END;

GO

-- Stored Procedure (87): sp_GetUserOrders
-- 3. STORED PROCEDURE: sp_GetUserOrders
-- Updated: ItemCount uses SUM(oi.Quantity)
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetUserOrders
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserEmail NVARCHAR(256);
    SELECT @UserEmail = Email FROM dbo.Users WHERE Id = @UserId;

    SELECT
        o.Id,
        o.OrderNumber,
        o.CustomerName,
        o.CustomerEmail,
        o.CustomerPhone,
        o.Subtotal,
        o.DiscountAmount,
        o.VoucherCode,
        o.ShippingFee,
        o.TotalAmount,
        o.Status AS OrderStatus,
        o.OrderSource,
        o.ShippingMethod,
        o.ShippingRegion,
        o.ShippingAddress,
        o.ShippingBarangay,
        o.ShippingCity,
        o.ShippingProvince,
        o.ShippingPostalCode,
        o.Courier,
        o.TrackingNumber,
        o.DeliveryNotes,
        o.Notes,
        o.CreatedAt,
        o.UpdatedAt,
        ISNULL((SELECT TOP 1 p.PaymentGateway FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'HitPay') AS PaymentGateway,
        ISNULL((SELECT TOP 1 p.Status FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC), 'Pending') AS PaymentStatus,
        (SELECT TOP 1 p.GatewayReference FROM dbo.Payments p WHERE p.OrderId = o.Id ORDER BY p.Id DESC) AS GatewayReference,
        ISNULL((SELECT SUM(oi.Quantity) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id), 0) AS ItemCount,
        (SELECT COUNT(*) FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id) AS RmaCount,
        (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaType,
        (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaStatus,
        (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderId = o.Id ORDER BY rr.Id DESC) AS LatestRmaResolution,
        (SELECT STRING_AGG(p.MainImageUrl, ';')
         FROM (
             SELECT TOP 3 p.MainImageUrl
             FROM dbo.OrderItems oi
             JOIN dbo.ProductVariants pv ON oi.VariantId = pv.Id
             JOIN dbo.ProductColors pc ON pv.ProductColorId = pc.Id
             JOIN dbo.Products p ON pc.ProductId = p.Id
             WHERE oi.OrderId = o.Id
             ORDER BY oi.Id ASC
         ) p) AS PreviewImages,
        (SELECT 
            oi.Id AS Id,
            oi.Id AS OrderItemId,
            oi.OrderId,
            oi.VariantId,
            c.ProductId,
            oi.Quantity,
            oi.UnitPrice,
            oi.TotalPrice,
            ISNULL(NULLIF(oi.ProductName, N''), p.Name) AS ProductName,
            p.Slug AS ProductSlug,
            p.MainImageUrl,
            ISNULL(NULLIF(oi.ColorName, N''), c.Color) AS Color,
            ISNULL(NULLIF(oi.Size, N''), v.Size) AS Size,
            ISNULL(NULLIF(oi.SKU, N''), v.SKU) AS SKU,
            (SELECT TOP 1 rr.Id FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaId,
            (SELECT TOP 1 rr.RmaNumber FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaNumber,
            (SELECT TOP 1 rr.RequestType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaType,
            (SELECT TOP 1 rr.Status FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaStatus,
            (SELECT TOP 1 rr.ResolutionType FROM dbo.ReturnRequests rr WHERE rr.OrderItemId = oi.Id ORDER BY rr.Id DESC) AS RmaResolution,
            (SELECT TOP 1 pr.Id FROM dbo.ProductReviews pr WHERE pr.OrderId = oi.OrderId AND pr.ProductId = c.ProductId) AS ReviewId
         FROM dbo.OrderItems oi
         LEFT JOIN dbo.ProductVariants v ON oi.VariantId = v.Id
         LEFT JOIN dbo.ProductColors c ON v.ProductColorId = c.Id
         LEFT JOIN dbo.Products p ON c.ProductId = p.Id
         WHERE oi.OrderId = o.Id
         FOR JSON PATH) AS ItemsJson
    FROM dbo.Orders o
    WHERE o.UserId = @UserId OR (o.UserId IS NULL AND o.CustomerEmail = @UserEmail)
    ORDER BY o.CreatedAt DESC;
END;

GO

-- Stored Procedure (88): sp_GetUserPayments
CREATE OR ALTER PROCEDURE dbo.sp_GetUserPayments
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserEmail NVARCHAR(256);
    SELECT @UserEmail = Email FROM dbo.Users WHERE Id = @UserId;

    SELECT 
        py.Id AS PaymentId,
        py.OrderId,
        o.OrderNumber,
        py.PaymentGateway,
        py.GatewayReference,
        py.Amount,
        py.Status AS PaymentStatus,
        py.PaidAt,
        py.CreatedAt AS PaymentCreatedAt,
        o.CustomerName,
        o.CustomerEmail,
        o.ShippingMethod,
        o.TotalAmount AS OrderTotalAmount,
        (SELECT COUNT(*) FROM dbo.OrderItems oi WHERE oi.OrderId = o.Id) AS ItemCount
    FROM dbo.Payments py
    INNER JOIN dbo.Orders o ON py.OrderId = o.Id
    WHERE o.UserId = @UserId OR (o.UserId IS NULL AND o.CustomerEmail = @UserEmail)
    ORDER BY ISNULL(py.PaidAt, py.CreatedAt) DESC, py.Id DESC;
END;

GO

-- Stored Procedure (89): sp_GetUserProfile
CREATE OR ALTER PROCEDURE dbo.sp_GetUserProfile
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.Id,
        u.RoleId,
        r.Name AS RoleName,
        u.FirstName,
        u.LastName,
        CONCAT(u.FirstName, N' ', u.LastName) AS FullName,
        u.Email,
        u.PhoneNumber,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.Id
    WHERE u.Id = @UserId AND u.IsActive = 1;
END;

GO

-- Stored Procedure (90): sp_GetVariantPriceInfo
CREATE OR ALTER PROCEDURE dbo.sp_GetVariantPriceInfo
    @VariantId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        pv.Id AS VariantId,
        pc.ProductId,
        p.Name AS ProductName,
        pv.SKU,
        pv.Size,
        pc.Color,
        CONVERT(DECIMAL(18,2), dbo.fn_CalculateEffectivePrice(p.BasePrice, pv.PriceAdjustment, p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)) AS UnitPrice
    FROM dbo.v_VisibleProductVariants pv
    INNER JOIN dbo.v_VisibleProductColors pc ON pv.ProductColorId = pc.Id
    INNER JOIN dbo.v_VisibleProducts p ON pc.ProductId = p.Id
    WHERE pv.Id = @VariantId AND pv.IsActive = 1 AND p.IsActive = 1;
END;

GO

-- Stored Procedure (91): sp_ImportShoppingState
-- Existing SQL rows win; import retries cannot add quantity twice.
CREATE OR ALTER PROCEDURE dbo.sp_ImportShoppingState
    @UserId INT, @Cart NVARCHAR(MAX), @Favorites NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Owner INT;
        SELECT @Owner = Id FROM dbo.Users WITH (UPDLOCK, ROWLOCK) WHERE Id = @UserId AND IsActive = 1;
        IF @Owner IS NULL THROW 53048, 'Account is unavailable.', 1;
        INSERT dbo.CartItems(UserId, VariantId, Quantity, IsSelected)
        SELECT @UserId, saved.VariantId,
            CASE WHEN saved.Quantity > i.CurrentStock - i.ReservedStock THEN i.CurrentStock - i.ReservedStock ELSE saved.Quantity END,
            saved.IsSelected
        FROM (
            SELECT VariantId, MAX(Quantity) AS Quantity, CONVERT(BIT, MAX(CONVERT(INT, ISNULL(IsSelected, 1)))) AS IsSelected
            FROM OPENJSON(@Cart) WITH (VariantId INT, Quantity INT, IsSelected BIT)
            WHERE VariantId > 0 AND Quantity BETWEEN 1 AND 9999 GROUP BY VariantId
        ) saved
        JOIN dbo.v_VisibleProductVariants v ON v.Id = saved.VariantId
        JOIN dbo.Inventories i ON i.VariantId = v.Id AND i.CurrentStock > i.ReservedStock
        WHERE NOT EXISTS (SELECT 1 FROM dbo.CartItems WHERE UserId = @UserId AND VariantId = saved.VariantId);
        INSERT dbo.Favorites(UserId, ProductId)
        SELECT @UserId, p.Id FROM dbo.v_VisibleProducts p
        WHERE p.Id IN (SELECT TRY_CONVERT(INT, value) FROM OPENJSON(@Favorites))
            AND NOT EXISTS (SELECT 1 FROM dbo.Favorites WHERE UserId = @UserId AND ProductId = p.Id);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
    EXEC dbo.sp_GetShoppingState @UserId;
END;

GO

-- Stored Procedure (92): sp_LogHitPayWebhook
CREATE OR ALTER PROCEDURE dbo.sp_LogHitPayWebhook
    @HitPayPaymentId NVARCHAR(100), @ReferenceNumber NVARCHAR(100), @RawPayload NVARCHAR(MAX),
    @SignatureReceived NVARCHAR(256), @IsSignatureValid BIT,
    @ProcessingStatus NVARCHAR(50), @ErrorMessage NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.HitPayWebhookLogs (HitPayPaymentId, ReferenceNumber, RawPayload, SignatureReceived,
        IsSignatureValid, ProcessingStatus, ErrorMessage)
    VALUES (@HitPayPaymentId, @ReferenceNumber, @RawPayload, @SignatureReceived,
        @IsSignatureValid, @ProcessingStatus, @ErrorMessage);
END;

GO

-- Stored Procedure (93): sp_PreviewVoucher
-- 2. UPDATE STORED PROCEDURE: sp_PreviewVoucher (Enforce One-Time Use Per Customer)
CREATE OR ALTER PROCEDURE dbo.sp_PreviewVoucher
    @Code NVARCHAR(30), 
    @Items dbo.SaleLineInput READONLY,
    @CustomerEmail NVARCHAR(255) = NULL,
    @CustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM @Items) OR EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0) OR
       EXISTS (SELECT VariantId FROM @Items GROUP BY VariantId HAVING COUNT(*) > 1)
        THROW 54014, N'Choose valid, distinct merchandise items.', 1;

    DECLARE @Subtotal DECIMAL(18,2), @Count INT;
    SELECT @Subtotal = SUM(CONVERT(DECIMAL(18,2), dbo.fn_CalculateEffectivePrice(p.BasePrice, v.PriceAdjustment,
        p.DiscountPercentage, p.DiscountType, p.DiscountAmount, p.DiscountStartDate, p.DiscountEndDate, p.DiscountIsActive)) * l.Quantity),
        @Count = COUNT(*)
    FROM @Items l JOIN dbo.v_VisibleProductVariants v ON v.Id = l.VariantId
    JOIN dbo.v_VisibleProductColors c ON c.Id = v.ProductColorId
    JOIN dbo.v_VisibleProducts p ON p.Id = c.ProductId;

    IF @Count <> (SELECT COUNT(*) FROM @Items) THROW 54014, N'An item is no longer available.', 1;

    DECLARE @Id INT, @Discount DECIMAL(18,2), @Type NVARCHAR(20);
    EXEC dbo.sp_CalculateVoucher @Code, @Subtotal, 0, @Id OUTPUT, @Discount OUTPUT, @Type OUTPUT;

    -- Check if this customer has already used this voucher
    IF (@CustomerId IS NOT NULL OR (@CustomerEmail IS NOT NULL AND LEN(LTRIM(RTRIM(@CustomerEmail))) > 0))
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM dbo.VoucherRedemptions vr
            JOIN dbo.Orders o ON vr.OrderId = o.Id
            WHERE vr.VoucherId = @Id 
              AND vr.ReleasedAt IS NULL
              AND o.Status <> N'Cancelled'
              AND (
                  (@CustomerId IS NOT NULL AND o.UserId = @CustomerId)
                  OR (@CustomerEmail IS NOT NULL AND LEN(LTRIM(RTRIM(@CustomerEmail))) > 0 
                      AND LOWER(LTRIM(RTRIM(o.CustomerEmail))) = LOWER(LTRIM(RTRIM(@CustomerEmail))))
              )
        )
        BEGIN
            THROW 54017, N'You have already used this voucher code. Vouchers are limited to one use per customer.', 1;
        END
    END

    SELECT 
        UPPER(LTRIM(RTRIM(@Code))) AS Code, 
        @Subtotal AS Subtotal,
        @Discount AS DiscountAmount, 
        @Subtotal - @Discount AS DiscountedSubtotal,
        @Type AS DiscountType;
END;

GO

-- Stored Procedure (94): sp_RecordPayment
CREATE OR ALTER PROCEDURE dbo.sp_RecordPayment
    @OrderId INT,
    @PaymentGateway NVARCHAR(50),
    @GatewayReference NVARCHAR(100) = NULL,
    @Amount DECIMAL(18,2),
    @Status NVARCHAR(50) = 'Pending',
    @PaidAt DATETIME2 = NULL,
    @PaymentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;
        SET @PaymentId = NULL;

        IF @GatewayReference IS NOT NULL
        BEGIN
            SELECT @PaymentId = Id
            FROM dbo.Payments WITH (UPDLOCK, HOLDLOCK)
            WHERE PaymentGateway = @PaymentGateway AND GatewayReference = @GatewayReference;

            IF @PaymentId IS NOT NULL
            BEGIN
                IF EXISTS (SELECT 1 FROM dbo.Payments WHERE Id = @PaymentId AND (OrderId <> @OrderId OR Amount <> @Amount))
                    THROW 51016, N'Gateway reference belongs to another payment.', 1;
                COMMIT TRANSACTION;
                RETURN;
            END;
        END;

        INSERT INTO dbo.Payments (
            OrderId, PaymentGateway, GatewayReference, Amount, Status, PaidAt, CreatedAt
        ) VALUES (
            @OrderId, @PaymentGateway, @GatewayReference, @Amount, @Status, @PaidAt, SYSUTCDATETIME()
        );

        SET @PaymentId = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

GO

-- Stored Procedure (95): sp_RecordPaymentFailure
CREATE OR ALTER PROCEDURE dbo.sp_RecordPaymentFailure
    @OrderNumber NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.Status = N'Failed'
    FROM dbo.Payments p
    JOIN dbo.Orders o ON o.Id = p.OrderId
    WHERE o.OrderNumber = @OrderNumber;
END;

GO

-- Stored Procedure (96): sp_RefreshOrderStockAlerts
CREATE OR ALTER PROCEDURE dbo.sp_RefreshOrderStockAlerts @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    UPDATE a SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
    FROM dbo.RestockAlerts a JOIN dbo.Inventories i ON i.Id = a.InventoryId
    WHERE a.IsDismissed = 0 AND i.IsLowStock = 0
      AND EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.OrderId = @OrderId AND oi.VariantId = i.VariantId);
    INSERT dbo.RestockAlerts(InventoryId, Severity)
    SELECT i.Id, CASE WHEN i.CurrentStock - i.ReservedStock = 0 THEN N'CRITICAL_ZERO' ELSE N'LOW_STOCK' END
    FROM dbo.Inventories i WITH (UPDLOCK, ROWLOCK)
    WHERE i.IsLowStock = 1
      AND EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.OrderId = @OrderId AND oi.VariantId = i.VariantId)
      AND NOT EXISTS (SELECT 1 FROM dbo.RestockAlerts a WITH (UPDLOCK, HOLDLOCK) WHERE a.InventoryId = i.Id AND a.IsDismissed = 0);
    COMMIT TRANSACTION;
END;

GO

-- Stored Procedure (97): sp_RegisterUser
CREATE OR ALTER PROCEDURE dbo.sp_RegisterUser
    @FirstName     NVARCHAR(100),
    @LastName      NVARCHAR(100),
    @Email         NVARCHAR(256),
    @PasswordHash  NVARCHAR(512),
    @Salt          NVARCHAR(128),
    @PhoneNumber   NVARCHAR(30),
    @RoleName      NVARCHAR(50) = N'Customer',
    @NewUserId     INT OUTPUT,
    @Success       BIT OUTPUT,
    @ErrorMessage  NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @FirstName = LTRIM(RTRIM(@FirstName));
        SET @LastName  = LTRIM(RTRIM(@LastName));
        SET @Email     = LOWER(LTRIM(RTRIM(@Email)));
        SET @PhoneNumber = LTRIM(RTRIM(@PhoneNumber));

        -- 1. Input Validations
        IF @FirstName IS NULL OR LEN(@FirstName) = 0
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'First name is required.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @LastName IS NULL OR LEN(@LastName) = 0
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Last name is required.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @Email IS NULL OR LEN(@Email) = 0
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Email address is required.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        IF @PhoneNumber IS NULL OR LEN(@PhoneNumber) = 0
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Mobile phone number is required.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 2. Duplicate Email Check
        IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'An account with this email address already exists.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 3. Duplicate Phone Number Check
        IF EXISTS (SELECT 1 FROM dbo.Users WHERE PhoneNumber = @PhoneNumber)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'An account with this mobile phone number already exists.';
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 4. Role lookup
        DECLARE @RoleId INT;
        SELECT @RoleId = Id FROM dbo.Roles WHERE Name = @RoleName;

        IF @RoleId IS NULL
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = CONCAT(N'Specified role "', @RoleName, N'" was not found.');
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 5. Insert normalized user record (without redundant FullName)
        INSERT INTO dbo.Users (
            RoleId, FirstName, LastName, Email, PasswordHash, Salt, PhoneNumber, IsActive, CreatedAt
        ) VALUES (
            @RoleId, @FirstName, @LastName, @Email, @PasswordHash, @Salt, @PhoneNumber, 1, SYSUTCDATETIME()
        );

        SET @NewUserId = SCOPE_IDENTITY();
        SET @Success = 1;
        SET @ErrorMessage = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;

GO

-- Stored Procedure (98): sp_ReportReview
-- 2. STORED PROCEDURE: sp_ReportReview
-- Prevents users from reporting their own reviews
-- =====================================================================================
CREATE OR ALTER PROCEDURE dbo.sp_ReportReview
    @ReviewId INT,
    @UserId INT = NULL,
    @IpAddress NVARCHAR(45) = NULL,
    @Reason NVARCHAR(50), -- 'SPAM', 'OFFENSIVE', 'IRRELEVANT', 'FAKE'
    @Notes NVARCHAR(255) = NULL,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ReviewAuthorId INT;

        SELECT @ReviewAuthorId = UserId
        FROM dbo.ProductReviews WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ReviewId;

        IF @ReviewAuthorId IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductReviews WHERE Id = @ReviewId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'Review not found.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Disallow reporting own reviews
        IF @UserId IS NOT NULL AND @ReviewAuthorId IS NOT NULL AND @UserId = @ReviewAuthorId
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You cannot report your own review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Check duplicate report by user
        IF @UserId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.ReviewReports WHERE ReviewId = @ReviewId AND UserId = @UserId)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You have already reported this review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        -- Check duplicate report by IP if guest
        ELSE IF @UserId IS NULL AND @IpAddress IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.ReviewReports WHERE ReviewId = @ReviewId AND IpAddress = @IpAddress)
        BEGIN
            SET @Success = 0;
            SET @ErrorMessage = N'You have already reported this review.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO dbo.ReviewReports (ReviewId, UserId, IpAddress, Reason, Notes)
        VALUES (@ReviewId, @UserId, @IpAddress, @Reason, @Notes);

        -- Auto-hide after three stored reports.
        UPDATE dbo.ProductReviews
        SET 
            IsHidden = CASE WHEN (SELECT COUNT(*) FROM dbo.ReviewReports WHERE ReviewId = @ReviewId) >= 3 THEN 1 ELSE IsHidden END
        WHERE Id = @ReviewId;

        COMMIT TRANSACTION;

        SET @Success = 1;
        SET @ErrorMessage = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END;

GO

-- Stored Procedure (99): sp_ReserveStockAtomic
CREATE OR ALTER PROCEDURE dbo.sp_ReserveStockAtomic
    @VariantId INT,
    @Quantity INT,
    @OrderNumber NVARCHAR(50),
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentStock INT, @ReservedStock INT;

    SELECT @CurrentStock = CurrentStock, @ReservedStock = ReservedStock
    FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
    WHERE VariantId = @VariantId;

    IF @CurrentStock IS NULL
    BEGIN
        SET @Success = 0;
        SET @ErrorMessage = N'Inventory record not found for variant.';
        RETURN;
    END;

    IF @CurrentStock - @ReservedStock < @Quantity
    BEGIN
        SET @Success = 0;
        SET @ErrorMessage = CONCAT(N'Insufficient available stock. Available: ', @CurrentStock - @ReservedStock, N', Requested: ', @Quantity);
        RETURN;
    END;

    UPDATE dbo.Inventories
    SET ReservedStock = ReservedStock + @Quantity,
        UpdatedAt = SYSUTCDATETIME()
    WHERE VariantId = @VariantId;

    SET @Success = 1;
    SET @ErrorMessage = NULL;
END;

GO

-- Stored Procedure (100): sp_RestockInventory
CREATE OR ALTER PROCEDURE dbo.sp_RestockInventory
    @VariantId INT,
    @RestockQuantity INT,
    @UserId INT,
    @SupplierInvoice NVARCHAR(100),
    @Notes NVARCHAR(500),
    @NewStock INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RestockQuantity IS NULL OR @RestockQuantity <= 0
        THROW 51011, N'Restock quantity must be greater than zero.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldStock INT, @ReservedStock INT;

        SELECT @OldStock = CurrentStock, @ReservedStock = ReservedStock
        FROM dbo.Inventories WITH (UPDLOCK, ROWLOCK)
        WHERE VariantId = @VariantId;

        IF @OldStock IS NULL
        BEGIN
            RAISERROR('Variant inventory not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE dbo.Inventories
        SET CurrentStock = CurrentStock + @RestockQuantity,
            LastRestockedAt = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME()
        WHERE VariantId = @VariantId;

        SET @NewStock = @OldStock + @RestockQuantity;

        INSERT INTO dbo.StockAuditLogs (
            VariantId, UserId, ChangeType, PreviousStock, QuantityChanged, ReferenceNumber, Notes
        ) VALUES (
            @VariantId, @UserId, N'RESTOCK', @OldStock, @RestockQuantity, @SupplierInvoice, @Notes
        );

        -- Dismiss open alerts for this inventory if stock is now healthy
        DECLARE @InvId INT, @ReorderPoint INT;
        SELECT @InvId = Id, @ReorderPoint = ReorderPoint FROM dbo.Inventories WHERE VariantId = @VariantId;

        IF @NewStock - @ReservedStock > @ReorderPoint
        BEGIN
            UPDATE dbo.RestockAlerts
            SET IsDismissed = 1, DismissedAt = SYSUTCDATETIME()
            WHERE InventoryId = @InvId AND IsDismissed = 0;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

GO

-- Stored Procedure (101): sp_SaveUserAddress
-- ----------------------------------------------------------------------------
-- 6. Procedure: dbo.sp_SaveUserAddress (Transactional)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_SaveUserAddress
    @Id INT = NULL,
    @UserId INT,
    @AddressLabel NVARCHAR(50) = NULL,
    @RecipientName NVARCHAR(100) = NULL,
    @PhoneNumber NVARCHAR(30) = NULL,
    @StreetAddress NVARCHAR(255),
    @Barangay NVARCHAR(100) = NULL,
    @City NVARCHAR(100),
    @Province NVARCHAR(100),
    @PostalCode NVARCHAR(20) = NULL,
    @DeliveryLandmark NVARCHAR(255) = NULL,
    @IsDefault BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @UserId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId)
        THROW 53011, N'User not found.', 1;

    IF @RecipientName IS NULL OR LEN(LTRIM(RTRIM(@RecipientName))) = 0
    BEGIN
        SELECT @RecipientName = LTRIM(RTRIM(CONCAT(FirstName, N' ', LastName)))
        FROM dbo.Users
        WHERE Id = @UserId;
    END

    IF @PhoneNumber IS NULL OR LEN(LTRIM(RTRIM(@PhoneNumber))) = 0
    BEGIN
        SELECT @PhoneNumber = PhoneNumber
        FROM dbo.Users
        WHERE Id = @UserId;
    END

    IF @StreetAddress IS NULL OR LEN(LTRIM(RTRIM(@StreetAddress))) = 0
        THROW 53013, N'Street address is required.', 1;

    IF @City IS NULL OR LEN(LTRIM(RTRIM(@City))) = 0
        THROW 53015, N'City / Municipality is required.', 1;

    IF @Province IS NULL OR LEN(LTRIM(RTRIM(@Province))) = 0
        THROW 53016, N'Province is required.', 1;

    SET @AddressLabel = ISNULL(NULLIF(LTRIM(RTRIM(@AddressLabel)), N''), N'Home');
    SET @RecipientName = ISNULL(NULLIF(LTRIM(RTRIM(@RecipientName)), N''), N'Account Holder');
    SET @PhoneNumber = ISNULL(NULLIF(LTRIM(RTRIM(@PhoneNumber)), N''), N'');
    SET @Barangay = ISNULL(NULLIF(LTRIM(RTRIM(@Barangay)), N''), N'');
    SET @PostalCode = ISNULL(NULLIF(LTRIM(RTRIM(@PostalCode)), N''), N'');

    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.UserAddresses WHERE UserId = @UserId)
    BEGIN
        SET @IsDefault = 1;
    END

    IF @IsDefault = 1
    BEGIN
        UPDATE dbo.UserAddresses
        SET IsDefault = 0,
            UpdatedAt = SYSUTCDATETIME()
        WHERE UserId = @UserId;
    END

    DECLARE @TargetId INT = @Id;

    IF @TargetId IS NOT NULL AND @TargetId > 0 AND EXISTS (SELECT 1 FROM dbo.UserAddresses WHERE Id = @TargetId AND UserId = @UserId)
    BEGIN
        UPDATE dbo.UserAddresses
        SET AddressLabel = @AddressLabel,
            RecipientName = @RecipientName,
            PhoneNumber = @PhoneNumber,
            StreetAddress = LTRIM(RTRIM(@StreetAddress)),
            Barangay = @Barangay,
            City = LTRIM(RTRIM(@City)),
            Province = LTRIM(RTRIM(@Province)),
            PostalCode = @PostalCode,
            DeliveryLandmark = NULLIF(LTRIM(RTRIM(@DeliveryLandmark)), N''),
            IsDefault = @IsDefault,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @TargetId AND UserId = @UserId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.UserAddresses (
            UserId, AddressLabel, RecipientName, PhoneNumber,
            StreetAddress, Barangay, City, Province, PostalCode,
            DeliveryLandmark, IsDefault, CreatedAt, UpdatedAt
        )
        VALUES (
            @UserId, @AddressLabel, @RecipientName, @PhoneNumber,
            LTRIM(RTRIM(@StreetAddress)), @Barangay,
            LTRIM(RTRIM(@City)), LTRIM(RTRIM(@Province)), @PostalCode,
            NULLIF(LTRIM(RTRIM(@DeliveryLandmark)), N''), @IsDefault,
            SYSUTCDATETIME(), SYSUTCDATETIME()
        );

        SET @TargetId = CONVERT(INT, SCOPE_IDENTITY());
    END

    COMMIT TRANSACTION;

    SELECT 
        a.Id,
        a.UserId,
        a.AddressLabel,
        a.RecipientName,
        a.PhoneNumber,
        a.StreetAddress,
        a.Barangay,
        a.City,
        a.Province,
        a.PostalCode,
        a.DeliveryLandmark,
        a.IsDefault,
        a.CreatedAt,
        a.UpdatedAt
    FROM dbo.UserAddresses a
    WHERE a.Id = @TargetId;
END;

GO

-- Stored Procedure (102): sp_UpdateUserProfile
CREATE OR ALTER PROCEDURE dbo.sp_UpdateUserProfile @UserId INT, @FirstName NVARCHAR(100), @LastName NVARCHAR(100), @PhoneNumber NVARCHAR(30) = NULL AS BEGIN SET NOCOUNT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1) THROW 53001, N'User account not found or inactive.', 1; IF @FirstName IS NULL OR LEN(LTRIM(RTRIM(@FirstName))) = 0 THROW 53002, N'First name is required.', 1; IF @LastName IS NULL OR LEN(LTRIM(RTRIM(@LastName))) = 0 THROW 53003, N'Last name is required.', 1; IF @PhoneNumber IS NOT NULL AND LEN(LTRIM(RTRIM(@PhoneNumber))) > 0 BEGIN SET @PhoneNumber = LTRIM(RTRIM(@PhoneNumber)); IF EXISTS (SELECT 1 FROM dbo.Users WHERE PhoneNumber = @PhoneNumber AND Id <> @UserId) THROW 53005, N'This mobile phone number is already registered to another account.', 1; END ELSE BEGIN SELECT @PhoneNumber = PhoneNumber FROM dbo.Users WHERE Id = @UserId; END; UPDATE dbo.Users SET FirstName = LTRIM(RTRIM(@FirstName)), LastName = LTRIM(RTRIM(@LastName)), PhoneNumber = @PhoneNumber, UpdatedAt = SYSUTCDATETIME() WHERE Id = @UserId; SELECT u.Id, r.Name AS RoleName, u.FirstName, u.LastName, CONCAT(u.FirstName, N' ', u.LastName) AS FullName, u.Email, u.PhoneNumber, u.CreatedAt FROM dbo.Users u INNER JOIN dbo.Roles r ON u.RoleId = r.Id WHERE u.Id = @UserId; END;

GO

-- Stored Procedure (103): sp_UpsertProductSpecificationValue
CREATE OR ALTER PROCEDURE dbo.sp_UpsertProductSpecificationValue
    @ProductId INT,
    @SpecificationKey NVARCHAR(80),
    @SpecificationValue NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SpecificationId INT;
    SELECT @SpecificationId = d.Id
    FROM dbo.SpecificationDefinitions d
    INNER JOIN dbo.Products p ON p.Id = @ProductId AND p.IsActive = 1
    INNER JOIN dbo.CategorySpecifications cs ON cs.CategoryId = p.CategoryId AND cs.SpecificationId = d.Id
    WHERE d.SpecificationKey = @SpecificationKey AND d.IsActive = 1;

    IF @SpecificationId IS NULL
        THROW 50012, 'Specification is not configured for this product category.', 1;
    IF NULLIF(LTRIM(RTRIM(@SpecificationValue)), N'') IS NULL
        THROW 50013, 'Specification value is required.', 1;

    BEGIN TRANSACTION;
    UPDATE dbo.ProductSpecificationValues WITH (UPDLOCK, SERIALIZABLE)
       SET SpecificationValue = LTRIM(RTRIM(@SpecificationValue)),
           UpdatedAt = SYSUTCDATETIME()
     WHERE ProductId = @ProductId AND SpecificationId = @SpecificationId;

    IF @@ROWCOUNT = 0
        INSERT dbo.ProductSpecificationValues (ProductId, SpecificationId, SpecificationValue)
        VALUES (@ProductId, @SpecificationId, LTRIM(RTRIM(@SpecificationValue)));
    COMMIT TRANSACTION;
END;

GO

-- Stored Procedure (104): sp_ValidateOrderTotals
CREATE OR ALTER PROCEDURE dbo.sp_ValidateOrderTotals
    @OrderId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Subtotal DECIMAL(18,2), @LineTotal DECIMAL(18,2), @LineCount INT;
    SELECT @Subtotal = Subtotal FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE Id = @OrderId;
    SELECT @LineTotal = SUM(TotalPrice), @LineCount = COUNT(*)
    FROM dbo.OrderItems WHERE OrderId = @OrderId;

    IF @Subtotal IS NULL OR @LineCount = 0 OR @LineTotal <> @Subtotal
        THROW 51017, N'Order subtotal does not match its items.', 1;
END;

GO

-- Stored Procedure (105): sp_AdminDeleteReview
CREATE OR ALTER PROCEDURE dbo.sp_AdminDeleteReview
    @ReviewId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.ProductReviews WHERE Id = @ReviewId)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52008, N'Review not found.', 1;
    END;

    -- Explicitly remove community report logs first
    DELETE FROM dbo.ReviewReports WHERE ReviewId = @ReviewId;

    -- Permanently delete the review
    DELETE FROM dbo.ProductReviews WHERE Id = @ReviewId;

    COMMIT TRANSACTION;

    SELECT @ReviewId AS DeletedReviewId;
END;
GO

PRINT N'====================================================================================';
PRINT N'HelmetCartelDB setup script completed successfully!';
PRINT N'Active tables: 28';
PRINT N'Active stored procedures: 105';
PRINT N'All seed catalog products, inventory, users, roles, and schema are ready.';
PRINT N'====================================================================================';
GO
