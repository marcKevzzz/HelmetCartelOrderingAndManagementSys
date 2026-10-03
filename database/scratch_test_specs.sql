DECLARE @json NVARCHAR(MAX) = N'[{"key":"shell_material","name":"Shell Material","value":"Advanced Polycarbonate"},{"key":"weight","name":"Weight","value":"1450g"}]';
EXEC dbo.sp_AdminSaveProductSpecifications @ProductId = 51, @SpecsJson = @json;
SELECT * FROM dbo.ProductSpecificationValues WHERE ProductId = 51;
