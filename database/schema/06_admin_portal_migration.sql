USE HelmetCartelDB;
GO

-- Run before deploying the admin portal. Existing FullName values remain available
-- while old clients migrate to FirstName and LastName.
IF COL_LENGTH(N'dbo.Users', N'FirstName') IS NULL
    ALTER TABLE dbo.Users ADD FirstName NVARCHAR(100) NULL;
IF COL_LENGTH(N'dbo.Users', N'LastName') IS NULL
    ALTER TABLE dbo.Users ADD LastName NVARCHAR(100) NULL;
GO
UPDATE dbo.Users
SET FirstName = CASE WHEN CHARINDEX(N' ', LTRIM(RTRIM(FullName))) > 0
                     THEN LEFT(LTRIM(RTRIM(FullName)), CHARINDEX(N' ', LTRIM(RTRIM(FullName))) - 1)
                     ELSE LTRIM(RTRIM(FullName)) END,
    LastName = CASE WHEN CHARINDEX(N' ', LTRIM(RTRIM(FullName))) > 0
                    THEN LTRIM(SUBSTRING(LTRIM(RTRIM(FullName)), CHARINDEX(N' ', LTRIM(RTRIM(FullName))) + 1, 100))
                    ELSE N'' END
WHERE FirstName IS NULL OR LastName IS NULL;
GO
ALTER TABLE dbo.Users ALTER COLUMN FirstName NVARCHAR(100) NOT NULL;
ALTER TABLE dbo.Users ALTER COLUMN LastName NVARCHAR(100) NOT NULL;
GO

-- The storefront can show extra images beyond its five thumbnail slots.
-- Widen the legacy ordinal before admin gallery editing is enabled.
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.ProductGalleryImages')
      AND name = N'DisplayOrder' AND system_type_id = TYPE_ID(N'tinyint')
)
BEGIN
    ALTER TABLE dbo.ProductGalleryImages DROP CONSTRAINT UQ_ProductGalleryImages_Product_DisplayOrder;
    ALTER TABLE dbo.ProductGalleryImages DROP CONSTRAINT CK_ProductGalleryImages_DisplayOrder;
    ALTER TABLE dbo.ProductGalleryImages ALTER COLUMN DisplayOrder INT NOT NULL;
    ALTER TABLE dbo.ProductGalleryImages ADD CONSTRAINT CK_ProductGalleryImages_DisplayOrder CHECK (DisplayOrder >= 1);
    ALTER TABLE dbo.ProductGalleryImages ADD CONSTRAINT UQ_ProductGalleryImages_Product_DisplayOrder UNIQUE (ProductId, DisplayOrder);
END;
GO

IF OBJECT_ID(N'dbo.CK_ProductColors_ColorHex', N'C') IS NOT NULL
    ALTER TABLE dbo.ProductColors DROP CONSTRAINT CK_ProductColors_ColorHex;
ALTER TABLE dbo.ProductColors ALTER COLUMN ColorHex NVARCHAR(255) NOT NULL;
IF COL_LENGTH(N'dbo.ProductColors', N'ColorType') IS NULL
    ALTER TABLE dbo.ProductColors ADD ColorType NVARCHAR(20) NOT NULL CONSTRAINT DF_ProductColors_ColorType DEFAULT N'SOLID';
IF COL_LENGTH(N'dbo.ProductColors', N'GradientAngle') IS NULL
    ALTER TABLE dbo.ProductColors ADD GradientAngle INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_ProductColors_ColorType')
    ALTER TABLE dbo.ProductColors ADD CONSTRAINT CK_ProductColors_ColorType CHECK (ColorType IN (N'SOLID', N'LINEAR_GRADIENT'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_ProductColors_GradientAngle')
    ALTER TABLE dbo.ProductColors ADD CONSTRAINT CK_ProductColors_GradientAngle CHECK (GradientAngle IS NULL OR GradientAngle BETWEEN 0 AND 359);
IF OBJECT_ID(N'dbo.ProductColorStops', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ProductColorStops (
        ProductColorId INT NOT NULL,
        StopOrder TINYINT NOT NULL CHECK (StopOrder BETWEEN 1 AND 4),
        ColorHex NCHAR(7) NOT NULL,
        CONSTRAINT PK_ProductColorStops PRIMARY KEY (ProductColorId, StopOrder),
        CONSTRAINT FK_ProductColorStops_ProductColors FOREIGN KEY (ProductColorId) REFERENCES dbo.ProductColors(Id) ON DELETE CASCADE,
        CONSTRAINT CK_ProductColorStops_Hex CHECK (ColorHex LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
    );
END;
GO

-- Normalize legacy linear-gradient CSS and comma-separated hex pairs into
-- ordered stops. The original ColorHex text is retained for old storefronts.
DECLARE @ColorId INT, @Css NVARCHAR(255), @Body NVARCHAR(255), @Token NVARCHAR(50);
DECLARE @Angle INT, @Comma INT, @StopOrder TINYINT, @Valid BIT;
DECLARE @Stops TABLE (StopOrder TINYINT PRIMARY KEY, ColorHex NCHAR(7) NOT NULL);
DECLARE color_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT Id, ColorHex FROM dbo.ProductColors
    WHERE ColorType = N'SOLID' AND (ColorHex LIKE N'linear-gradient(%' OR ColorHex LIKE N'%,%');
OPEN color_cursor;
FETCH NEXT FROM color_cursor INTO @ColorId, @Css;
WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM @Stops;
    SET @Valid = 1;
    SET @StopOrder = 0;
    SET @Angle = 90;
    SET @Body = LTRIM(RTRIM(@Css));
    IF @Body LIKE N'linear-gradient(%'
    BEGIN
        IF RIGHT(@Body, 1) <> N')' SET @Valid = 0;
        ELSE
        BEGIN
            SET @Body = SUBSTRING(@Body, LEN(N'linear-gradient(') + 1,
                LEN(@Body) - LEN(N'linear-gradient(') - 1);
            SET @Comma = CHARINDEX(N',', @Body);
            IF @Comma = 0 SET @Valid = 0;
            ELSE
            BEGIN
                SET @Token = LTRIM(RTRIM(LEFT(@Body, @Comma - 1)));
                IF RIGHT(@Token, 3) <> N'deg' SET @Valid = 0;
                ELSE SET @Angle = TRY_CONVERT(INT, LEFT(@Token, LEN(@Token) - 3));
                SET @Body = SUBSTRING(@Body, @Comma + 1, 255);
            END;
        END;
    END;
    IF @Angle NOT BETWEEN 0 AND 359 SET @Valid = 0;
    WHILE @Valid = 1 AND LEN(@Body) > 0 AND @StopOrder < 5
    BEGIN
        SET @Comma = CHARINDEX(N',', @Body);
        SET @Token = LTRIM(RTRIM(CASE WHEN @Comma = 0 THEN @Body ELSE LEFT(@Body, @Comma - 1) END));
        IF LEN(@Token) <> 7 OR @Token NOT LIKE N'#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'
            SET @Valid = 0;
        ELSE
        BEGIN
            SET @StopOrder = @StopOrder + 1;
            IF @StopOrder <= 4 INSERT @Stops (StopOrder, ColorHex) VALUES (@StopOrder, @Token);
            SET @Body = CASE WHEN @Comma = 0 THEN N'' ELSE SUBSTRING(@Body, @Comma + 1, 255) END;
        END;
    END;
    IF @Valid = 1 AND @StopOrder BETWEEN 2 AND 4 AND LEN(@Body) = 0
    BEGIN
        BEGIN TRANSACTION;
        UPDATE dbo.ProductColors SET ColorType = N'LINEAR_GRADIENT', GradientAngle = @Angle WHERE Id = @ColorId;
        INSERT dbo.ProductColorStops (ProductColorId, StopOrder, ColorHex)
        SELECT @ColorId, StopOrder, ColorHex FROM @Stops;
        COMMIT TRANSACTION;
    END;
    FETCH NEXT FROM color_cursor INTO @ColorId, @Css;
END;
CLOSE color_cursor;
DEALLOCATE color_cursor;
GO
