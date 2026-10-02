using System;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class ProductReviewDto
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public int? UserId { get; set; }
        public int? OrderId { get; set; }
        public string ReviewerName { get; set; }
        public int Rating { get; set; }
        public string Title { get; set; }
        public string Comment { get; set; }
        public bool IsVerifiedPurchase { get; set; }
        public int FlagCount { get; set; }
        public bool IsHidden { get; set; }
        public DateTime CreatedAt { get; set; }

        public string FormattedDate => CreatedAt.ToString("MMMM dd, yyyy");
    }

    public class ReportReviewRequestDto
    {
        public int ReviewId { get; set; }
        public string Reason { get; set; } // 'SPAM', 'OFFENSIVE', 'IRRELEVANT', 'FAKE'
        public string Notes { get; set; }
    }

    public class ReportReviewResultDto
    {
        public bool Success { get; set; }
        public string ErrorMessage { get; set; }
        public bool IsHidden { get; set; }
    }

    public class AddReviewRequestDto
    {
        public int ProductId { get; set; }
        public int? UserId { get; set; }
        public int? OrderId { get; set; }
        public string ReviewerName { get; set; }
        public int Rating { get; set; }
        public string Title { get; set; }
        public string Comment { get; set; }
    }

    public class AdminReviewDto : ProductReviewDto
    {
        public string ProductName { get; set; }
        public string BrandName { get; set; }
    }
}
