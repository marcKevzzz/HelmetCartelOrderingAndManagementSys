/*
    Flexible category-aware product specifications.
    Run after 01_schema.sql and the existing catalog migrations.
*/
IF OBJECT_ID(N'dbo.SpecificationDefinitions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SpecificationDefinitions
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SpecificationDefinitions PRIMARY KEY,
        SpecificationKey NVARCHAR(80) NOT NULL,
        DisplayName NVARCHAR(120) NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_SpecificationDefinitions_IsActive DEFAULT (1),
        CreatedAt DATETIME2(7) NOT NULL CONSTRAINT DF_SpecificationDefinitions_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(7) NULL,
        CONSTRAINT UQ_SpecificationDefinitions_Key UNIQUE (SpecificationKey)
    );
END;
GO

IF OBJECT_ID(N'dbo.CategorySpecifications', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CategorySpecifications
    (
        CategoryId INT NOT NULL,
        SpecificationId INT NOT NULL,
        DisplayOrder INT NOT NULL CONSTRAINT DF_CategorySpecifications_DisplayOrder DEFAULT (0),
        IsRequired BIT NOT NULL CONSTRAINT DF_CategorySpecifications_IsRequired DEFAULT (0),
        CreatedAt DATETIME2(7) NOT NULL CONSTRAINT DF_CategorySpecifications_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_CategorySpecifications PRIMARY KEY (CategoryId, SpecificationId),
        CONSTRAINT FK_CategorySpecifications_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.Categories(Id),
        CONSTRAINT FK_CategorySpecifications_Definitions FOREIGN KEY (SpecificationId) REFERENCES dbo.SpecificationDefinitions(Id),
        CONSTRAINT CK_CategorySpecifications_DisplayOrder CHECK (DisplayOrder >= 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.ProductSpecificationValues', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ProductSpecificationValues
    (
        ProductId INT NOT NULL,
        SpecificationId INT NOT NULL,
        SpecificationValue NVARCHAR(1000) NOT NULL,
        CreatedAt DATETIME2(7) NOT NULL CONSTRAINT DF_ProductSpecificationValues_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(7) NULL,
        CONSTRAINT PK_ProductSpecificationValues PRIMARY KEY (ProductId, SpecificationId),
        CONSTRAINT FK_ProductSpecificationValues_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
        CONSTRAINT FK_ProductSpecificationValues_Definitions FOREIGN KEY (SpecificationId) REFERENCES dbo.SpecificationDefinitions(Id)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.ProductSpecificationValues') AND name = N'IX_ProductSpecificationValues_SpecificationId')
    CREATE INDEX IX_ProductSpecificationValues_SpecificationId ON dbo.ProductSpecificationValues(SpecificationId, ProductId);
GO
