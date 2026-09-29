using System;
using System.Web;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    public static class TrendHelper
    {
        /// <summary>
        /// Renders a simple, accessible SVG trend badge (up, down, or neutral).
        /// </summary>
        public static string RenderSimpleBadge(string direction, string text, string title = null)
        {
            string dir = (direction ?? "neutral").ToLowerInvariant();
            string trendClass = "admin-trend--neutral";
            string svgIcon = @"<svg class=""admin-trend-icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor""><line x1=""5"" y1=""12"" x2=""19"" y2=""12""></line></svg>";

            if (dir == "up")
            {
                trendClass = "admin-trend--up";
                svgIcon = @"<svg class=""admin-trend-icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor""><polyline points=""18 15 12 9 6 15""></polyline></svg>";
            }
            else if (dir == "down")
            {
                trendClass = "admin-trend--down";
                svgIcon = @"<svg class=""admin-trend-icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor""><polyline points=""6 9 12 15 18 9""></polyline></svg>";
            }

            string textEscaped = HttpUtility.HtmlEncode(text ?? string.Empty);
            string titleAttr = !string.IsNullOrEmpty(title) ? $@" title=""{HttpUtility.HtmlAttributeEncode(title)}""" : "";

            return $@"<span class=""admin-trend-badge {trendClass}""{titleAttr} aria-label=""{HttpUtility.HtmlAttributeEncode(text)}"">
                {svgIcon}
                <span>{textEscaped}</span>
            </span>";
        }

        /// <summary>
        /// Renders an accessible, colored SVG trend indicator comparing current value against a previous period.
        /// Returns empty string if previous value is null (prevents misleading indicators).
        /// Displays clear percentages and directions without misleading comparison text.
        /// </summary>
        public static string RenderTrend(decimal current, decimal? previous, string comparisonPeriodLabel = null, bool isCurrency = false, bool invertSentiment = false)
        {
            if (!previous.HasValue)
            {
                return string.Empty;
            }

            decimal prev = previous.Value;
            string labelEscaped = !string.IsNullOrWhiteSpace(comparisonPeriodLabel) ? HttpUtility.HtmlEncode(comparisonPeriodLabel) : "previous period";

            // Neutral case: both are zero or exactly equal
            if (prev == 0 && current == 0)
            {
                return $@"<span class=""admin-trend-badge admin-trend--neutral"" title=""No change compared to {labelEscaped}"" aria-label=""No change"">
                    <svg class=""admin-trend-icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor""><line x1=""5"" y1=""12"" x2=""19"" y2=""12""></line></svg>
                    <span>0.0%</span>
                </span>";
            }

            decimal diff = current - prev;
            decimal pct = prev != 0 ? (diff / Math.Abs(prev)) * 100m : (current > 0 ? 100m : -100m);

            if (Math.Abs(pct) < 0.05m)
            {
                return $@"<span class=""admin-trend-badge admin-trend--neutral"" title=""No change compared to {labelEscaped}"" aria-label=""No change"">
                    <svg class=""admin-trend-icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor""><line x1=""5"" y1=""12"" x2=""19"" y2=""12""></line></svg>
                    <span>0.0%</span>
                </span>";
            }

            bool isPositive = diff > 0;
            // invertSentiment: when higher is worse (e.g. low stock warnings)
            bool isGood = isPositive ^ invertSentiment;
            string trendClass = isGood ? "admin-trend--up" : "admin-trend--down";
            string sign = isPositive ? "+" : "";

            string diffFormatted = isCurrency ? $"&#8369;{diff:N2}" : diff.ToString("N0");
            string titleText = $"{sign}{pct:F1}% ({diffFormatted}) compared to {labelEscaped}";
            string titleEscaped = HttpUtility.HtmlAttributeEncode(titleText);
            string ariaEscaped = HttpUtility.HtmlAttributeEncode($"{sign}{pct:F1}%");

            string svgIcon = isPositive
                ? @"<svg class=""admin-trend-icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor""><polyline points=""18 15 12 9 6 15""></polyline></svg>"
                : @"<svg class=""admin-trend-icon"" viewBox=""0 0 24 24"" fill=""none"" stroke=""currentColor""><polyline points=""6 9 12 15 18 9""></polyline></svg>";

            return $@"<span class=""admin-trend-badge {trendClass}"" title=""{titleEscaped}"" aria-label=""{ariaEscaped}"">
                {svgIcon}
                <span>{sign}{pct:F1}%</span>
            </span>";
        }
    }
}
