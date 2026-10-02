using System;

namespace HelmetCartelOrderingAndManagementSys.Models.Entities
{
    public class ReturnRequest
    {
        public int Id { get; set; }
        public string RmaNumber { get; set; }
        public int OrderId { get; set; }
        public int OrderItemId { get; set; }
        public int? UserId { get; set; }
        public string RequestType { get; set; } // 'RETURN', 'EXCHANGE'
        public string Reason { get; set; }      // 'DEFECTIVE', 'WRONG_SIZE', 'NOT_AS_DESCRIBED', 'CHANGED_MIND', 'OTHER'
        public int? ExchangeVariantId { get; set; }
        public string CustomerNotes { get; set; }
        public string Status { get; set; }      // 'Pending', 'Approved', 'Rejected', 'Received', 'Completed', 'Cancelled'
        public string ResolutionType { get; set; } // 'REFUND', 'REPLACEMENT', 'STORE_CREDIT'
        public decimal? RefundAmount { get; set; }
        public bool Restocked { get; set; }
        public string AdminNotes { get; set; }
        public int? ProcessedBy { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}
