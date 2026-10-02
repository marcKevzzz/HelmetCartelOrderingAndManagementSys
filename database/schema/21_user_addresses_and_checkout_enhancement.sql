-- =====================================================================================
-- 21_user_addresses_and_checkout_enhancement.sql
-- Helmet Cartel Ordering and Management System
-- Saved Customer Addresses for Faster Checkout and Multi-Address Management
-- =====================================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

USE HelmetCartelDB;
GO

-- 1. TABLE: dbo.UserAddresses
IF OBJECT_ID(N'dbo.UserAddresses', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserAddresses (
        Id INT IDENTITY(1,1) NOT NULL,
        UserId INT NOT NULL,
        AddressLabel NVARCHAR(50) NOT NULL CONSTRAINT DF_UserAddresses_AddressLabel DEFAULT (N'Home'),
        RecipientName NVARCHAR(150) NULL,
        PhoneNumber NVARCHAR(30) NULL,
        StreetAddress NVARCHAR(255) NOT NULL,
        Barangay NVARCHAR(100) NOT NULL,
        City NVARCHAR(100) NOT NULL,
        Province NVARCHAR(100) NOT NULL,
        PostalCode NVARCHAR(20) NOT NULL,
        DeliveryLandmark NVARCHAR(255) NULL,
        IsDefault BIT NOT NULL CONSTRAINT DF_UserAddresses_IsDefault DEFAULT (0),
        CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_UserAddresses_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_UserAddresses_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_UserAddresses PRIMARY KEY CLUSTERED (Id ASC),
        CONSTRAINT FK_UserAddresses_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE CASCADE
    );

    CREATE NONCLUSTERED INDEX IX_UserAddresses_UserId_IsDefault 
    ON dbo.UserAddresses (UserId ASC, IsDefault DESC, Id DESC);
END;
GO

-- 2. STORED PROCEDURE: sp_GetUserAddresses
IF OBJECT_ID(N'dbo.sp_GetUserAddresses', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_GetUserAddresses AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserAddresses
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Id,
        UserId,
        AddressLabel,
        RecipientName,
        PhoneNumber,
        StreetAddress,
        Barangay,
        City,
        Province,
        PostalCode,
        DeliveryLandmark,
        IsDefault,
        CreatedAt,
        UpdatedAt
    FROM dbo.UserAddresses
    WHERE UserId = @UserId
    ORDER BY IsDefault DESC, Id DESC;
END;
GO

-- 3. STORED PROCEDURE: sp_SaveUserAddress
IF OBJECT_ID(N'dbo.sp_SaveUserAddress', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_SaveUserAddress AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_SaveUserAddress
    @Id INT = NULL,
    @UserId INT,
    @AddressLabel NVARCHAR(50) = N'Home',
    @RecipientName NVARCHAR(150) = NULL,
    @PhoneNumber NVARCHAR(30) = NULL,
    @StreetAddress NVARCHAR(255),
    @Barangay NVARCHAR(100),
    @City NVARCHAR(100),
    @Province NVARCHAR(100),
    @PostalCode NVARCHAR(20),
    @DeliveryLandmark NVARCHAR(255) = NULL,
    @IsDefault BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1)
        THROW 53010, N'User account not found or inactive.', 1;

    -- If RecipientName is not supplied, fallback to user's registered name
    IF @RecipientName IS NULL OR LEN(LTRIM(RTRIM(@RecipientName))) = 0
    BEGIN
        SELECT @RecipientName = NULLIF(LTRIM(RTRIM(ISNULL(FirstName, N'') + N' ' + ISNULL(LastName, N''))), N'')
        FROM dbo.Users 
        WHERE Id = @UserId;

        IF @RecipientName IS NULL
            SET @RecipientName = N'Account Holder';
    END;

    -- If PhoneNumber is not supplied, fallback to user's registered phone
    IF @PhoneNumber IS NULL OR LEN(LTRIM(RTRIM(@PhoneNumber))) = 0
    BEGIN
        SELECT @PhoneNumber = PhoneNumber 
        FROM dbo.Users 
        WHERE Id = @UserId;
    END;

    IF @StreetAddress IS NULL OR LEN(LTRIM(RTRIM(@StreetAddress))) = 0
        THROW 53013, N'Street address is required.', 1;

    IF @Barangay IS NULL OR LEN(LTRIM(RTRIM(@Barangay))) = 0
        THROW 53014, N'Barangay is required.', 1;

    IF @City IS NULL OR LEN(LTRIM(RTRIM(@City))) = 0
        THROW 53015, N'City / Municipality is required.', 1;

    IF @Province IS NULL OR LEN(LTRIM(RTRIM(@Province))) = 0
        THROW 53016, N'Province is required.', 1;

    IF @PostalCode IS NULL OR LEN(LTRIM(RTRIM(@PostalCode))) = 0
        THROW 53017, N'Postal / ZIP code is required.', 1;

    -- If this is the user's first address, automatically make it default
    IF NOT EXISTS (SELECT 1 FROM dbo.UserAddresses WHERE UserId = @UserId)
    BEGIN
        SET @IsDefault = 1;
    END

    -- If marking as default, clear default flag from other addresses
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
        SET AddressLabel = ISNULL(NULLIF(LTRIM(RTRIM(@AddressLabel)), N''), N'Home'),
            RecipientName = LTRIM(RTRIM(@RecipientName)),
            PhoneNumber = LTRIM(RTRIM(@PhoneNumber)),
            StreetAddress = LTRIM(RTRIM(@StreetAddress)),
            Barangay = LTRIM(RTRIM(@Barangay)),
            City = LTRIM(RTRIM(@City)),
            Province = LTRIM(RTRIM(@Province)),
            PostalCode = LTRIM(RTRIM(@PostalCode)),
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
            @UserId, ISNULL(NULLIF(LTRIM(RTRIM(@AddressLabel)), N''), N'Home'),
            LTRIM(RTRIM(@RecipientName)), LTRIM(RTRIM(@PhoneNumber)),
            LTRIM(RTRIM(@StreetAddress)), LTRIM(RTRIM(@Barangay)),
            LTRIM(RTRIM(@City)), LTRIM(RTRIM(@Province)), LTRIM(RTRIM(@PostalCode)),
            NULLIF(LTRIM(RTRIM(@DeliveryLandmark)), N''), @IsDefault,
            SYSUTCDATETIME(), SYSUTCDATETIME()
        );

        SET @TargetId = SCOPE_IDENTITY();
    END

    SELECT 
        Id,
        UserId,
        AddressLabel,
        RecipientName,
        PhoneNumber,
        StreetAddress,
        Barangay,
        City,
        Province,
        PostalCode,
        DeliveryLandmark,
        IsDefault,
        CreatedAt,
        UpdatedAt
    FROM dbo.UserAddresses
    WHERE Id = @TargetId;
END;
GO

-- 4. STORED PROCEDURE: sp_DeleteUserAddress
IF OBJECT_ID(N'dbo.sp_DeleteUserAddress', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_DeleteUserAddress AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_DeleteUserAddress
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
