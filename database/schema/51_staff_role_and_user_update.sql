-- =========================================================================
-- Migration 51: Staff Role Authorization & User Updates
-- Description:
--   1. Creates sp_AdminUpdateUserRole for role assignment in Admin portal.
--   2. Promotes kevs@gmail.com and staffmember@helmetcartel.com to Staff (RoleId=2).
--   3. Creates new Staff user staff@gmail.com with password 'staff@gmail.com'.
-- =========================================================================

SET NOCOUNT ON;

-- 1. Create or Update sp_AdminUpdateUserRole Stored Procedure
IF OBJECT_ID(N'dbo.sp_AdminUpdateUserRole', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_AdminUpdateUserRole;
GO

CREATE PROCEDURE dbo.sp_AdminUpdateUserRole
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

-- 2. Promote kevs@gmail.com and staffmember@helmetcartel.com to Staff role
DECLARE @StaffRoleId INT;
SELECT @StaffRoleId = Id FROM dbo.Roles WHERE Name = N'Staff';

UPDATE dbo.Users
SET RoleId = @StaffRoleId,
    UpdatedAt = SYSUTCDATETIME()
WHERE Email IN (N'kevs@gmail.com', N'staffmember@helmetcartel.com');

-- 3. Create or update staff@gmail.com with password 'staff@gmail.com'
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'staff@gmail.com')
BEGIN
    INSERT INTO dbo.Users (
        RoleId,
        FirstName,
        LastName,
        Email,
        PasswordHash,
        Salt,
        PhoneNumber,
        IsActive,
        CreatedAt,
        UpdatedAt
    )
    VALUES (
        @StaffRoleId,
        N'Staff',
        N'Member',
        N'staff@gmail.com',
        N'3ddb6f2e7ad4a46f2fb203dae899952b78e3c1764fcf65fba6119ae4601ead51',
        N'dfa57c4161a93fca12ab6464fe712988',
        N'+639170009999',
        1,
        SYSUTCDATETIME(),
        SYSUTCDATETIME()
    );
END
ELSE
BEGIN
    UPDATE dbo.Users
    SET RoleId = @StaffRoleId,
        PasswordHash = N'3ddb6f2e7ad4a46f2fb203dae899952b78e3c1764fcf65fba6119ae4601ead51',
        Salt = N'dfa57c4161a93fca12ab6464fe712988',
        IsActive = 1,
        UpdatedAt = SYSUTCDATETIME()
    WHERE Email = N'staff@gmail.com';
END;
GO
