/*
    Product detail gallery support.
    Run after 01_schema.sql and 02_3nf_integrity_migration.sql, before
    database/queries/03_procedures_and_queries.sql.

    Products.MainImageUrl remains the primary image. Five thumbnails appear
    in the detail rail; further gallery images appear in its extra-images modal.
*/
IF OBJECT_ID(N'dbo.ProductGalleryImages', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ProductGalleryImages
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProductGalleryImages PRIMARY KEY,
        ProductId INT NOT NULL,
        ImageUrl NVARCHAR(500) NOT NULL,
        AltText NVARCHAR(200) NULL,
        DisplayOrder INT NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_ProductGalleryImages_IsActive DEFAULT (1),
        CreatedAt DATETIME2(7) NOT NULL CONSTRAINT DF_ProductGalleryImages_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(7) NULL,
        CONSTRAINT FK_ProductGalleryImages_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
        CONSTRAINT CK_ProductGalleryImages_DisplayOrder CHECK (DisplayOrder >= 1),
        CONSTRAINT UQ_ProductGalleryImages_Product_DisplayOrder UNIQUE (ProductId, DisplayOrder)
    );
END;
GO
