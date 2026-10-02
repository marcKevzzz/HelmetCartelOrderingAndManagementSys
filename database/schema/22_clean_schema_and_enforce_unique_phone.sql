-- =====================================================================================
-- 22_clean_schema_and_enforce_unique_phone.sql
-- Helmet Cartel Ordering and Management System
-- Schema Cleanup:
-- 1. Keep FullName as a computed compatibility column for existing readers.
-- 2. Require phones for new writes; preserve unknown legacy phones and enforce unique known numbers.
-- 3. Preserve address-specific RecipientName and PhoneNumber values.
-- 4. Update all affected Stored Procedures
-- =====================================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

USE HelmetCartelDB;
GO

-- Stop before changing anything if normalization would produce duplicate phones.
IF EXISTS (SELECT 1 FROM dbo.Users WHERE NULLIF(LTRIM(RTRIM(PhoneNumber)), N'') IS NOT NULL
           GROUP BY LTRIM(RTRIM(PhoneNumber)) HAVING COUNT(*) > 1)
    THROW 53030, N'Duplicate phone numbers must be resolved before migration 22.', 1;

-- Do not replace an existing name with a different derived name silently.
IF COL_LENGTH(N'dbo.Users', N'FullName') IS NOT NULL
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE LTRIM(RTRIM(FullName)) <> CONCAT(LTRIM(RTRIM(FirstName)), N' ', LTRIM(RTRIM(LastName))))
        THROW 53031, N'Existing full names differ from first/last names; review before migration 22.', 1;
GO

-- 2. Drop redundant FullName column from dbo.Users if it exists
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Users') AND name = N'FullName' AND is_computed = 0)
BEGIN
    ALTER TABLE dbo.Users DROP COLUMN FullName;
END;
GO
IF COL_LENGTH(N'dbo.Users', N'FullName') IS NULL
    ALTER TABLE dbo.Users ADD FullName AS CONVERT(NVARCHAR(200), CONCAT(LTRIM(RTRIM(FirstName)), N' ', LTRIM(RTRIM(LastName)))) PERSISTED;
GO

-- 3. Enforce PhoneNumber NOT NULL and UNIQUE on dbo.Users
-- Legacy unknown numbers remain NULL until their owners provide real numbers.
UPDATE dbo.Users SET PhoneNumber = NULLIF(LTRIM(RTRIM(PhoneNumber)), N'');
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_Users_PhoneNumber' AND object_id = OBJECT_ID(N'dbo.Users'))
BEGIN
    CREATE UNIQUE INDEX UQ_Users_PhoneNumber ON dbo.Users(PhoneNumber) WHERE PhoneNumber IS NOT NULL;
    PRINT 'Added filtered unique index UQ_Users_PhoneNumber';
END;
GO

-- 4. Address contact columns are intentionally preserved; migration 23 uses them.

-- 5. UPDATE STORED PROCEDURE: sp_RegisterUser
IF OBJECT_ID(N'dbo.sp_RegisterUser', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_RegisterUser AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_RegisterUser
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

-- 6. UPDATE STORED PROCEDURE: sp_GetUserByEmail
IF OBJECT_ID(N'dbo.sp_GetUserByEmail', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_GetUserByEmail AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserByEmail
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

-- 7. UPDATE STORED PROCEDURE: sp_GetUserProfile
IF OBJECT_ID(N'dbo.sp_GetUserProfile', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_GetUserProfile AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_GetUserProfile
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

-- 8. UPDATE STORED PROCEDURE: sp_UpdateUserProfile
IF OBJECT_ID(N'dbo.sp_UpdateUserProfile', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_UpdateUserProfile AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_UpdateUserProfile
    @UserId INT,
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @PhoneNumber NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @UserId AND IsActive = 1)
        THROW 53001, N'User account not found or inactive.', 1;

    IF @FirstName IS NULL OR LEN(LTRIM(RTRIM(@FirstName))) = 0
        THROW 53002, N'First name is required.', 1;

    IF @LastName IS NULL OR LEN(LTRIM(RTRIM(@LastName))) = 0
        THROW 53003, N'Last name is required.', 1;

    IF @PhoneNumber IS NULL OR LEN(LTRIM(RTRIM(@PhoneNumber))) = 0
        THROW 53004, N'Mobile phone number is required.', 1;

    SET @PhoneNumber = LTRIM(RTRIM(@PhoneNumber));

    -- Check if another user already has this phone number
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE PhoneNumber = @PhoneNumber AND Id <> @UserId)
        THROW 53005, N'This mobile phone number is already registered to another account.', 1;

    UPDATE dbo.Users
    SET FirstName = LTRIM(RTRIM(@FirstName)),
        LastName = LTRIM(RTRIM(@LastName)),
        PhoneNumber = @PhoneNumber,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Id = @UserId;

    SELECT 
        u.Id,
        r.Name AS RoleName,
        u.FirstName,
        u.LastName,
        CONCAT(u.FirstName, N' ', u.LastName) AS FullName,
        u.Email,
        u.PhoneNumber,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.Id
    WHERE u.Id = @UserId;
END;
GO

-- 9. UPDATE STORED PROCEDURE: sp_AdminUpdateUser
IF OBJECT_ID(N'dbo.sp_AdminUpdateUser', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_AdminUpdateUser AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_AdminUpdateUser
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

-- 10. UPDATE STORED PROCEDURE: sp_GetUserAddresses
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
        CONCAT(u.FirstName, N' ', u.LastName) AS RecipientName,
        u.PhoneNumber AS PhoneNumber,
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

-- 12. UPDATE STORED PROCEDURE: sp_SaveUserAddress
IF OBJECT_ID(N'dbo.sp_SaveUserAddress', N'P') IS NULL 
    EXEC(N'CREATE PROCEDURE dbo.sp_SaveUserAddress AS BEGIN RETURN 0; END');
GO

ALTER PROCEDURE dbo.sp_SaveUserAddress
    @Id INT = NULL,
    @UserId INT,
    @AddressLabel NVARCHAR(50) = N'Home',
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
            UserId, AddressLabel,
            StreetAddress, Barangay, City, Province, PostalCode,
            DeliveryLandmark, IsDefault, CreatedAt, UpdatedAt
        )
        VALUES (
            @UserId, ISNULL(NULLIF(LTRIM(RTRIM(@AddressLabel)), N''), N'Home'),
            LTRIM(RTRIM(@StreetAddress)), LTRIM(RTRIM(@Barangay)),
            LTRIM(RTRIM(@City)), LTRIM(RTRIM(@Province)), LTRIM(RTRIM(@PostalCode)),
            NULLIF(LTRIM(RTRIM(@DeliveryLandmark)), N''), @IsDefault,
            SYSUTCDATETIME(), SYSUTCDATETIME()
        );

        SET @TargetId = SCOPE_IDENTITY();
    END

    SELECT 
        a.Id,
        a.UserId,
        a.AddressLabel,
        CONCAT(u.FirstName, N' ', u.LastName) AS RecipientName,
        u.PhoneNumber AS PhoneNumber,
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
    WHERE a.Id = @TargetId;
END;
GO

PRINT 'Migration 22: Schema clean and unique phone enforcement completed successfully.';
GO
