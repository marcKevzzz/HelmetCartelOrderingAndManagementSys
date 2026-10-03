-- Migration 35: Clear unintended default image on draft items
-- Draft items without images should have NULL MainImageUrl and display placeholder-helmet.png on UI

UPDATE dbo.Products
SET MainImageUrl = NULL
WHERE IsActive = 0
  AND MainImageUrl = '/Content/images/placeholder-helmet';
GO
