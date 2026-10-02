   -- ============================================================================
-- Migration 23: Restore RecipientName and PhoneNumber to dbo.UserAddresses
-- Helmet Cartel Ordering and Management System
-- Allows recipient contact details to be customized per delivery address.
-- ============================================================================

USE [HelmetCartelDB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Ensure RecipientName column exists on dbo.UserAddresses
IF COL_LENGTH(N'dbo.UserAddresses', N'RecipientName') IS NULL
BEGIN
    ALTER TABLE dbo.UserAddresses 
    ADD RecipientName NVARCHAR(100) NULL;
    PRINT 'Added RecipientName column to dbo.UserAddresses.';
END
ELSE
BEGIN
    PRINT 'RecipientName column already exists on dbo.UserAddresses.';
END
GO

-- 2. Ensure PhoneNumber column exists on dbo.UserAddresses
IF COL_LENGTH(N'dbo.UserAddresses', N'PhoneNumber') IS NULL
BEGIN
    ALTER TABLE dbo.UserAddresses 
    ADD PhoneNumber NVARCHAR(50) NULL;
    PRINT 'Added PhoneNumber column to dbo.UserAddresses.';
END
ELSE
BEGIN
    PRINT 'PhoneNumber column already exists on dbo.UserAddresses.';
END
GO

-- 3. Backfill existing records with user profile defaults if null
UPDATE a
SET a.RecipientName = ISNULL(NULLIF(LTRIM(RTRIM(a.RecipientName)), N''), CONCAT(u.FirstName, N' ', u.LastName)),
    a.PhoneNumber = ISNULL(NULLIF(LTRIM(RTRIM(a.PhoneNumber)), N''), u.PhoneNumber)
FROM dbo.UserAddresses a
INNER JOIN dbo.Users u ON a.UserId = u.Id
WHERE a.RecipientName IS NULL OR a.PhoneNumber IS NULL;
GO

-- 4. Update Stored Procedure: dbo.sp_SaveUserAddress
IF OBJECT_ID(N'dbo.sp_SaveUserAddress', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_SaveUserAddress AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_SaveUserAddress
    @Id INT = NULL,
    @UserId INT,
    @AddressLabel NVARCHAR(50) = N'Home',
    @RecipientName NVARCHAR(100) = NULL,
    @PhoneNumber NVARCHAR(50) = NULL,
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

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1)
        THROW 53010, N'User account not found or inactive.', 1;

    -- Fallback recipient name to user account if empty
    IF @RecipientName IS NULL OR LEN(LTRIM(RTRIM(@RecipientName))) = 0
    BEGIN
        SELECT @RecipientName = CONCAT(FirstName, N' ', LastName)
        FROM dbo.Users
        WHERE Id = @UserId;
    END

    -- Fallback phone number to user account if empty
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

    -- Defaults for optional fields
    SET @AddressLabel = ISNULL(NULLIF(LTRIM(RTRIM(@AddressLabel)), N''), N'Home');
    SET @RecipientName = ISNULL(NULLIF(LTRIM(RTRIM(@RecipientName)), N''), N'Account Holder');
    SET @PhoneNumber = ISNULL(NULLIF(LTRIM(RTRIM(@PhoneNumber)), N''), N'');
    SET @Barangay = ISNULL(NULLIF(LTRIM(RTRIM(@Barangay)), N''), N'');
    SET @PostalCode = ISNULL(NULLIF(LTRIM(RTRIM(@PostalCode)), N''), N'');

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

        SET @TargetId = SCOPE_IDENTITY();
    END

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

-- 5. Update Stored Procedure: dbo.sp_GetUserAddresses
IF OBJECT_ID(N'dbo.sp_GetUserAddresses', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_GetUserAddresses AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserAddresses
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

PRINT 'Migration 23 completed successfully: RecipientName and PhoneNumber restored to UserAddresses and stored procedures updated.';
GO
