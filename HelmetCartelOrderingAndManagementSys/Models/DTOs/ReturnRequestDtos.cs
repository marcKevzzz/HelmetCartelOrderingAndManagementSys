using System;

namespace HelmetCartelOrderingAndManagementSys.Models.DTOs
{
    public class CreateReturnRequestDto
    {
        public int OrderId { get; set; }
        public int OrderItemId { get; set; }
        public int? UserId { get; set; }
        public string RequestType { get; set; } // 'RETURN', 'EXCHANGE'
        public string Reason { get; set; }      // 'DEFECTIVE', 'WRONG_SIZE', 'NOT_AS_DESCRIBED', 'CHANGED_MIND', 'OTHER'
        public int? ExchangeVariantId { get; set; }
        public string CustomerNotes { get; set; }
    }

    public class ReturnRequestDto
    {
        public int Id { get; set; }
        public string RmaNumber { get; set; }
        public int OrderId { get; set; }
        public string OrderNumber { get; set; }
        public int OrderItemId { get; set; }
        public int VariantId { get; set; }
        public string ProductName { get; set; }
        public string ColorName { get; set; }
        public string Size { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public string MainImageUrl { get; set; }
        public int? UserId { get; set; }
        public string RequestType { get; set; }
        public string Reason { get; set; }
        public int? ExchangeVariantId { get; set; }
        public string CustomerNotes { get; set; }
        public string Status { get; set; }
        public string ResolutionType { get; set; }
        public decimal? RefundAmount { get; set; }
        public bool Restocked { get; set; }
        public string AdminNotes { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        public string FormattedDate => CreatedAt.ToString("MMM dd, yyyy");
    }

    public class AdminReturnRequestDto : ReturnRequestDto
    {
        public string CustomerName { get; set; }
        public string CustomerEmail { get; set; }
        public string CustomerPhone { get; set; }
        public int? ProcessedBy { get; set; }
        public string ProcessedByName { get; set; }
    }

    public class ProcessReturnRequestDto
    {
        public string NewStatus { get; set; } // 'Approved', 'Rejected', 'Received', 'Completed', 'Cancelled'
        public string ResolutionType { get; set; } // 'REFUND', 'REPLACEMENT', 'STORE_CREDIT'
        public decimal? RefundAmount { get; set; }
        public bool RestockItem { get; set; }
        public string AdminNotes { get; set; }
    }

    public class ReturnOperationResultDto
    {
        public bool Success { get; set; }
        public string ErrorMessage { get; set; }
        public int? RmaId { get; set; }
        public string RmaNumber { get; set; }
    }
}
