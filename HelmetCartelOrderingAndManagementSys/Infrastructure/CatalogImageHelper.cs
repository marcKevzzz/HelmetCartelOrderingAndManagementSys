using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    public static class CatalogImageHelper
    {
        private const string Folder = "/Content/images/catalog/";
        private static string ThumbnailUrl(string url)
        {
            using (var hash = SHA256.Create())
                return Folder + BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(url))).Replace("-", "").ToLowerInvariant() + ".jpg";
        }

        public static string GetUrl(string url)
        {
            if (string.IsNullOrWhiteSpace(url) || !url.StartsWith("/Content/images/", StringComparison.OrdinalIgnoreCase)) return url;
            url = url.Replace("/Content/images/helmets/", "/Content/images/products/helmets/");
            var thumbnail = ThumbnailUrl(url);
            return File.Exists(System.Web.Hosting.HostingEnvironment.MapPath("~" + thumbnail)) ? thumbnail : url;
        }

        // Uploaded images keep their originals; catalog cards use a smaller derivative when possible.
        public static void CreateThumbnail(string physicalPath, string url)
        {
            try
            {
                using (var image = Image.FromFile(physicalPath))
                {
                    var ratio = Math.Min(1d, 600d / Math.Max(image.Width, image.Height));
                    using (var bitmap = new Bitmap(Math.Max(1, (int)(image.Width * ratio)), Math.Max(1, (int)(image.Height * ratio))))
                    {
                        using (var graphics = Graphics.FromImage(bitmap))
                        {
                            graphics.Clear(Color.White);
                            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                            graphics.DrawImage(image, 0, 0, bitmap.Width, bitmap.Height);
                        }
                        var destination = System.Web.Hosting.HostingEnvironment.MapPath("~" + ThumbnailUrl(url));
                        Directory.CreateDirectory(Path.GetDirectoryName(destination));
                        using (var parameters = new EncoderParameters(1))
                        {
                            parameters.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 82L);
                            bitmap.Save(destination, ImageCodecInfo.GetImageEncoders().First(codec => codec.MimeType == "image/jpeg"), parameters);
                        }
                        if (new FileInfo(destination).Length >= new FileInfo(physicalPath).Length) File.Delete(destination);
                    }
                }
            }
            catch (Exception ex)
            {
                // Unsupported codecs (including WebP in GDI+) retain the original URL.
                System.Diagnostics.Trace.TraceWarning("Catalog thumbnail unavailable: " + ex.Message);
            }
        }
    }
}
