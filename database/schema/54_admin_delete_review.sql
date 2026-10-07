-- Migration 54: Admin Delete Review Stored Procedure
-- Encapsulates permanent deletion of a customer review and associated flags/reports.
-- Strictly invoked for administrative moderation with audit readiness.
-- =====================================================================================

CREATE OR ALTER PROCEDURE dbo.sp_AdminDeleteReview
    @ReviewId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.ProductReviews WHERE Id = @ReviewId)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 52008, N'Review not found.', 1;
    END;

    -- Explicitly remove community report logs first
    DELETE FROM dbo.ReviewReports WHERE ReviewId = @ReviewId;

    -- Permanently delete the review
    DELETE FROM dbo.ProductReviews WHERE Id = @ReviewId;

    COMMIT TRANSACTION;

    SELECT @ReviewId AS DeletedReviewId;
END;
GO
