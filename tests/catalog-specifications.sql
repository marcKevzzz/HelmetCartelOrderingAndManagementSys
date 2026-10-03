-- Run against the current development schema. All fixture changes roll back.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @CategoryId INT = (SELECT TOP (1) Id FROM dbo.Categories ORDER BY Id);
    DECLARE @BrandId INT = (SELECT TOP (1) Id FROM dbo.Brands ORDER BY Id);
    DECLARE @Slug NVARCHAR(220) = N'spec-regression-' + CONVERT(NVARCHAR(36), NEWID());
    EXEC dbo.sp_AdminSaveProduct @Id=0, @CategoryId=@CategoryId, @BrandId=@BrandId,
        @Name=N'Specification regression fixture', @Slug=@Slug,
        @BasePrice=1000, @DiscountPercentage=10, @IsActive=0, @PublicationStatus=N'Draft';
    DECLARE @ProductId INT = (SELECT Id FROM dbo.Products WHERE Slug=@Slug);
    IF @ProductId IS NULL THROW 54101, 'Product header save failed.', 1;

    EXEC dbo.sp_AdminSaveProductSpecifications @ProductId,
        N'[{"key":"shell_material","name":"Shell Material","value":"Regression shell"},{"SpecificationKey":"regression_custom","DisplayName":"Regression custom","SpecificationValue":"Custom value"}]';
    IF (SELECT COUNT(*) FROM dbo.ProductSpecificationValues WHERE ProductId=@ProductId) <> 2
        THROW 54102, 'Standard/custom specifications did not persist.', 1;
    EXEC dbo.sp_AdminGetProductComplete @ProductId;
    EXEC dbo.sp_GetProductSpecifications @ProductId;

    EXEC dbo.sp_AdminSaveProduct @Id=@ProductId, @CategoryId=@CategoryId, @BrandId=@BrandId,
        @Name=N'Specification regression fixture', @Slug=@Slug,
        @BasePrice=1000, @DiscountPercentage=10, @IsActive=1, @PublicationStatus=N'Published';
    EXEC dbo.sp_AdminSaveProductSpecifications @ProductId,
        N'[{"key":"shell_material","name":"Shell Material","value":"Updated shell"}]';
    IF (SELECT COUNT(*) FROM dbo.ProductSpecificationValues WHERE ProductId=@ProductId) <> 1
        THROW 54103, 'Removed custom specification remained.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ProductSpecificationValues WHERE ProductId=@ProductId AND SpecificationValue=N'Updated shell')
        THROW 54104, 'Specification update did not persist.', 1;
    EXEC dbo.sp_AdminSaveProductSpecifications @ProductId, N'[]';
    IF EXISTS (SELECT 1 FROM dbo.ProductSpecificationValues WHERE ProductId=@ProductId)
        THROW 54105, 'Clearing specifications failed.', 1;
    ROLLBACK TRANSACTION;
    PRINT 'PASS: draft/create/publish product header, standard/custom specifications, edit/remove/clear; fixture rolled back.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
