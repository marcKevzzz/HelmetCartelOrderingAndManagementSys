using System;
using System.Collections.Generic;
using System.Web;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    public class PageLinkItem
    {
        public int Number { get; set; }
        public int PageNumber => Number;
        public string Url { get; set; }
        public string CssClass { get; set; }
        public bool IsCurrent { get; set; }
        public bool IsEllipsis { get; set; }
    }

    public static class PaginationHelper
    {
        public static List<PageLinkItem> BuildPageLinks(int currentPage, int totalPages, Func<int, string> urlBuilder)
        {
            var links = new List<PageLinkItem>();
            if (totalPages <= 0) return links;

            if (totalPages <= 4)
            {
                // Four or fewer pages: Show all pages without ellipses
                for (int i = 1; i <= totalPages; i++)
                {
                    links.Add(new PageLinkItem
                    {
                        Number = i,
                        Url = urlBuilder(i),
                        CssClass = i == currentPage ? "active" : string.Empty,
                        IsCurrent = i == currentPage,
                        IsEllipsis = false
                    });
                }
            }
            else
            {
                // More than 4 pages: Display first two and last two pages with ellipsis
                // "1 2 ... 8 9"
                if (currentPage <= 2)
                {
                    links.Add(CreateLink(1, currentPage, urlBuilder));
                    links.Add(CreateLink(2, currentPage, urlBuilder));
                    links.Add(new PageLinkItem { IsEllipsis = true });
                    links.Add(CreateLink(totalPages - 1, currentPage, urlBuilder));
                    links.Add(CreateLink(totalPages, currentPage, urlBuilder));
                }
                else if (currentPage >= totalPages - 1)
                {
                    links.Add(CreateLink(1, currentPage, urlBuilder));
                    links.Add(CreateLink(2, currentPage, urlBuilder));
                    links.Add(new PageLinkItem { IsEllipsis = true });
                    links.Add(CreateLink(totalPages - 1, currentPage, urlBuilder));
                    links.Add(CreateLink(totalPages, currentPage, urlBuilder));
                }
                else
                {
                    // Middle active page preserved cleanly
                    links.Add(CreateLink(1, currentPage, urlBuilder));
                    links.Add(CreateLink(2, currentPage, urlBuilder));
                    if (currentPage > 3)
                    {
                        links.Add(new PageLinkItem { IsEllipsis = true });
                    }
                    links.Add(CreateLink(currentPage, currentPage, urlBuilder));
                    if (currentPage < totalPages - 2)
                    {
                        links.Add(new PageLinkItem { IsEllipsis = true });
                    }
                    links.Add(CreateLink(totalPages - 1, currentPage, urlBuilder));
                    links.Add(CreateLink(totalPages, currentPage, urlBuilder));
                }
            }

            return links;
        }

        private static PageLinkItem CreateLink(int pageNum, int currentPage, Func<int, string> urlBuilder)
        {
            return new PageLinkItem
            {
                Number = pageNum,
                Url = urlBuilder(pageNum),
                CssClass = pageNum == currentPage ? "active" : string.Empty,
                IsCurrent = pageNum == currentPage,
                IsEllipsis = false
            };
        }
    }
}
