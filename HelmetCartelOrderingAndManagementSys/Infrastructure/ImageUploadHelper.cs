using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Hosting;
using System.Web.UI.WebControls;

namespace HelmetCartelOrderingAndManagementSys.Infrastructure
{
    /// <summary>
    /// Result payload returned upon executing an image upload operation.
    /// </summary>
    public class ImageUploadResult
    {
        public bool Success { get; set; }
        public string FilePath { get; set; }         // Relative web URL (e.g. "/Content/images/products/helmets/shoei/rf1400.jpg")
        public string PhysicalPath { get; set; }     // Absolute local server disk path
        public string FileName { get; set; }         // File name stored on server
        public string Brand { get; set; }            // Associated brand folder (e.g. "shoei", "hnj", "gille")
        public long FileSizeBytes { get; set; }
        public string ContentType { get; set; }
        public string ErrorMessage { get; set; }

        public static ImageUploadResult Failed(string message)
        {
            return new ImageUploadResult
            {
                Success = false,
                ErrorMessage = message
            };
        }

        public static ImageUploadResult Succeeded(string virtualPath, string physicalPath, string fileName, string brand, long size, string contentType)
        {
            return new ImageUploadResult
            {
                Success = true,
                FilePath = virtualPath,
                PhysicalPath = physicalPath,
                FileName = fileName,
                Brand = brand,
                FileSizeBytes = size,
                ContentType = contentType
            };
        }
    }

    /// <summary>
    /// Production-grade helper for validating, storing, and organizing uploaded helmet images
    /// into brand-specific directories under "~/Content/images/products/helmets/{brand}/"
    /// (e.g. /hnj, /gille, /shoei, etc.) and returning database-ready web file paths.
    /// Supports ASP.NET FileUpload controls, HttpPostedFile, HttpPostedFileBase, and byte arrays.
    /// </summary>
    public static class ImageUploadHelper
    {
        // Base folder for all helmet product images
        public const string BaseHelmetImageFolder = "~/Content/images/products/helmets/";
        public const string DefaultProductImageFolder = "~/Content/images/products/helmets/";

        // Allowed image MIME types and extensions
        private static readonly HashSet<string> AllowedExtensions = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            ".jpg", ".jpeg", ".png", ".webp", ".gif"
        };

        private static readonly HashSet<string> AllowedMimeTypes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg", "image/pjpeg", "image/png", "image/x-png", "image/webp", "image/gif"
        };

        // Default maximum file size: 5 MB (5 * 1024 * 1024 bytes)
        public const long DefaultMaxFileSizeBytes = 5 * 1024 * 1024;

        /// <summary>
        /// Sanitizes a brand name into a clean, URL-safe and filesystem-safe folder slug.
        /// e.g. "Shoei Japan" -> "shoei-japan", "HNJ" -> "hnj", "AGV" -> "agv", "Gille" -> "gille"
        /// </summary>
        public static string CleanBrandSlug(string brand)
        {
            if (string.IsNullOrWhiteSpace(brand))
            {
                return string.Empty;
            }

            string cleaned = Regex.Replace(brand.Trim().ToLowerInvariant(), @"[^a-z0-9_-]", "-").Trim('-');
            return cleaned;
        }

        /// <summary>
        /// Resolves the brand-specific directory under "~/Content/images/products/helmets/{brand}/".
        /// e.g. "hnj"   -> "~/Content/images/products/helmets/hnj/"
        /// e.g. "gille" -> "~/Content/images/products/helmets/gille/"
        /// e.g. "shoei" -> "~/Content/images/products/helmets/shoei/"
        /// </summary>
        public static string GetBrandHelmetFolder(string brand = null)
        {
            string slug = CleanBrandSlug(brand);
            if (string.IsNullOrEmpty(slug))
            {
                return BaseHelmetImageFolder;
            }

            return $"{BaseHelmetImageFolder}{slug}/";
        }

        /// <summary>
        /// Resolves the final destination virtual folder considering brand and optional custom overrides.
        /// </summary>
        public static string ResolveDestinationFolder(string brand = null, string customFolder = null)
        {
            // If brand itself is passed as a virtual/physical path (e.g. "~/Content/..."), respect it directly
            if (!string.IsNullOrWhiteSpace(brand) && (brand.Contains("/") || brand.Contains("\\") || brand.StartsWith("~")))
            {
                return brand.EndsWith("/") ? brand : brand + "/";
            }

            if (!string.IsNullOrWhiteSpace(customFolder))
            {
                string baseCustom = customFolder.EndsWith("/") ? customFolder : customFolder + "/";
                string slug = CleanBrandSlug(brand);
                if (!string.IsNullOrEmpty(slug) && !baseCustom.ToLowerInvariant().Contains(slug))
                {
                    return $"{baseCustom}{slug}/";
                }
                return baseCustom;
            }

            return GetBrandHelmetFolder(brand);
        }

        /// <summary>
        /// Saves a helmet image uploaded via an ASP.NET <see cref="FileUpload"/> WebControl
        /// into the brand folder "~/Content/images/products/helmets/{brand}/" (e.g. /hnj, /gille, /shoei).
        /// </summary>
        /// <param name="fileUpload">The ASP.NET FileUpload control</param>
        /// <param name="brand">The helmet brand (e.g. "hnj", "gille", "shoei", "agv")</param>
        /// <param name="prefix">Optional custom prefix or slug to incorporate into the file name</param>
        /// <param name="targetVirtualFolder">Optional custom folder override</param>
        /// <param name="maxSizeBytes">Maximum allowed file size in bytes</param>
        /// <returns>ImageUploadResult with status and database-ready relative web path</returns>
        public static ImageUploadResult SaveUploadedImage(
            FileUpload fileUpload,
            string brand = null,
            string prefix = null,
            string targetVirtualFolder = null,
            long maxSizeBytes = DefaultMaxFileSizeBytes)
        {
            if (fileUpload == null)
            {
                return ImageUploadResult.Failed("FileUpload control is null.");
            }

            if (!fileUpload.HasFile || fileUpload.PostedFile == null)
            {
                return ImageUploadResult.Failed("No file was selected for upload.");
            }

            string destinationFolder = ResolveDestinationFolder(brand, targetVirtualFolder);
            return SaveUploadedFileInternal(fileUpload.PostedFile, destinationFolder, brand, prefix, maxSizeBytes);
        }

        /// <summary>
        /// Saves a helmet image from an <see cref="HttpPostedFile"/> instance into "~/Content/images/products/helmets/{brand}/".
        /// </summary>
        public static ImageUploadResult SaveUploadedImage(
            HttpPostedFile postedFile,
            string brand = null,
            string prefix = null,
            string targetVirtualFolder = null,
            long maxSizeBytes = DefaultMaxFileSizeBytes)
        {
            if (postedFile == null || postedFile.ContentLength == 0)
            {
                return ImageUploadResult.Failed("Uploaded file is empty or missing.");
            }

            string destinationFolder = ResolveDestinationFolder(brand, targetVirtualFolder);
            return SaveUploadedFileInternal(postedFile, destinationFolder, brand, prefix, maxSizeBytes);
        }

        /// <summary>
        /// Saves a helmet image from raw bytes with a specified original filename into "~/Content/images/products/helmets/{brand}/".
        /// </summary>
        public static ImageUploadResult SaveImageBytes(
            byte[] imageBytes,
            string originalFileName,
            string brand = null,
            string contentType = "image/jpeg",
            string prefix = null,
            string targetVirtualFolder = null,
            long maxSizeBytes = DefaultMaxFileSizeBytes)
        {
            if (imageBytes == null || imageBytes.Length == 0)
            {
                return ImageUploadResult.Failed("Image byte payload is empty.");
            }

            string extension = Path.GetExtension(originalFileName)?.ToLowerInvariant();
            if (!IsValidImage(extension, contentType, imageBytes.Length, maxSizeBytes, out string validationError))
            {
                return ImageUploadResult.Failed(validationError);
            }

            try
            {
                string destinationFolder = ResolveDestinationFolder(brand, targetVirtualFolder);
                string physicalDir = ResolvePhysicalDirectory(destinationFolder);
                if (!Directory.Exists(physicalDir))
                {
                    Directory.CreateDirectory(physicalDir);
                }

                string uniqueFileName = GenerateUniqueFileName(originalFileName, prefix);
                string physicalPath = Path.Combine(physicalDir, uniqueFileName);

                File.WriteAllBytes(physicalPath, imageBytes);

                string relativeWebPath = BuildRelativeWebPath(destinationFolder, uniqueFileName);
                CatalogImageHelper.CreateThumbnail(physicalPath, relativeWebPath);

                return ImageUploadResult.Succeeded(
                    virtualPath: relativeWebPath,
                    physicalPath: physicalPath,
                    fileName: uniqueFileName,
                    brand: CleanBrandSlug(brand),
                    size: imageBytes.Length,
                    contentType: contentType
                );
            }
            catch (Exception ex)
            {
                return ImageUploadResult.Failed($"Error saving image bytes to disk: {ex.Message}");
            }
        }

        /// <summary>
        /// Internal worker that validates, resolves physical path, saves, and creates response metadata.
        /// </summary>
        private static ImageUploadResult SaveUploadedFileInternal(
            HttpPostedFile postedFile,
            string targetVirtualFolder,
            string brand,
            string prefix,
            long maxSizeBytes)
        {
            string originalFileName = Path.GetFileName(postedFile.FileName);
            string extension = Path.GetExtension(originalFileName)?.ToLowerInvariant();

            if (!IsValidImage(extension, postedFile.ContentType, postedFile.ContentLength, maxSizeBytes, out string validationError))
            {
                return ImageUploadResult.Failed(validationError);
            }

            try
            {
                string physicalDir = ResolvePhysicalDirectory(targetVirtualFolder);
                if (!Directory.Exists(physicalDir))
                {
                    Directory.CreateDirectory(physicalDir);
                }

                string uniqueFileName = GenerateUniqueFileName(originalFileName, prefix);
                string physicalPath = Path.Combine(physicalDir, uniqueFileName);

                postedFile.SaveAs(physicalPath);

                string relativeWebPath = BuildRelativeWebPath(targetVirtualFolder, uniqueFileName);
                CatalogImageHelper.CreateThumbnail(physicalPath, relativeWebPath);

                return ImageUploadResult.Succeeded(
                    virtualPath: relativeWebPath,
                    physicalPath: physicalPath,
                    fileName: uniqueFileName,
                    brand: CleanBrandSlug(brand),
                    size: postedFile.ContentLength,
                    contentType: postedFile.ContentType
                );
            }
            catch (Exception ex)
            {
                return ImageUploadResult.Failed($"Error saving image to disk: {ex.Message}");
            }
        }

        /// <summary>
        /// Safely deletes a previously uploaded image file from the server disk.
        /// </summary>
        /// <param name="relativeOrVirtualPath">Relative path e.g. "/Content/images/products/helmets/shoei/abc.jpg"</param>
        /// <returns>True if deleted or file was already absent; False on error.</returns>
        public static bool DeleteImage(string relativeOrVirtualPath)
        {
            if (string.IsNullOrWhiteSpace(relativeOrVirtualPath))
            {
                return false;
            }

            try
            {
                string physicalPath = ResolvePhysicalPath(relativeOrVirtualPath);
                if (File.Exists(physicalPath))
                {
                    File.Delete(physicalPath);
                    return true;
                }
                return false;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ImageUploadHelper] Failed to delete image '{relativeOrVirtualPath}': {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Validates extension, MIME type, and size against security policies.
        /// </summary>
        public static bool IsValidImage(
            string extension,
            string contentType,
            long sizeBytes,
            long maxSizeBytes,
            out string errorMessage)
        {
            errorMessage = null;

            if (string.IsNullOrWhiteSpace(extension) || !AllowedExtensions.Contains(extension))
            {
                errorMessage = $"Invalid file format '{extension}'. Allowed formats: {string.Join(", ", AllowedExtensions)}";
                return false;
            }

            if (!string.IsNullOrWhiteSpace(contentType) && !AllowedMimeTypes.Contains(contentType))
            {
                errorMessage = $"Invalid MIME content type '{contentType}'. Only legitimate image files are permitted.";
                return false;
            }

            if (sizeBytes <= 0)
            {
                errorMessage = "File cannot be 0 bytes.";
                return false;
            }

            if (sizeBytes > maxSizeBytes)
            {
                long maxMb = maxSizeBytes / (1024 * 1024);
                errorMessage = $"File size ({sizeBytes / 1024} KB) exceeds the maximum limit of {maxMb} MB.";
                return false;
            }

            return true;
        }

        /// <summary>
        /// Generates a sanitized, collision-free unique file name.
        /// Format: [prefix_]yyyyMMdd_HHmmss_[shortguid].[ext]
        /// </summary>
        public static string GenerateUniqueFileName(string originalFileName, string prefix = null)
        {
            string ext = Path.GetExtension(originalFileName)?.ToLowerInvariant() ?? ".jpg";
            string timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
            string shortGuid = Guid.NewGuid().ToString("N").Substring(0, 6);

            string cleanPrefix = string.Empty;
            if (!string.IsNullOrWhiteSpace(prefix))
            {
                cleanPrefix = Regex.Replace(prefix.Trim().ToLowerInvariant(), @"[^a-z0-9_-]", "-");
                if (cleanPrefix.Length > 30) cleanPrefix = cleanPrefix.Substring(0, 30);
                cleanPrefix += "_";
            }

            return $"{cleanPrefix}{timestamp}_{shortGuid}{ext}";
        }

        /// <summary>
        /// Determines the application root physical directory across both hosted (IIS / ASP.NET)
        /// and unhosted (CLI / Test / Background job) environments.
        /// </summary>
        private static string GetApplicationRootPath()
        {
            if (HttpContext.Current != null)
            {
                return HttpContext.Current.Server.MapPath("~/");
            }

            string mapped = HostingEnvironment.MapPath("~/");
            if (!string.IsNullOrEmpty(mapped))
            {
                return mapped;
            }

            // Fallback: check assembly location to find web project root (parent of bin directory)
            try
            {
                string asmLocation = typeof(ImageUploadHelper).Assembly.Location;
                if (!string.IsNullOrEmpty(asmLocation))
                {
                    string asmDir = Path.GetDirectoryName(asmLocation);
                    if (asmDir != null && asmDir.EndsWith("bin", StringComparison.OrdinalIgnoreCase))
                    {
                        string projectRoot = Directory.GetParent(asmDir)?.FullName;
                        if (!string.IsNullOrEmpty(projectRoot) && Directory.Exists(projectRoot))
                        {
                            return projectRoot;
                        }
                    }
                }
            }
            catch
            {
                // Fallback to BaseDirectory
            }

            return AppDomain.CurrentDomain.BaseDirectory;
        }

        /// <summary>
        /// Resolves a physical directory from a virtual path (e.g. "~/Content/images/products/helmets/hnj/") or rooted disk path.
        /// </summary>
        private static string ResolvePhysicalDirectory(string virtualFolder)
        {
            if (string.IsNullOrWhiteSpace(virtualFolder))
            {
                virtualFolder = BaseHelmetImageFolder;
            }

            if (Path.IsPathRooted(virtualFolder))
            {
                return virtualFolder;
            }

            if (HttpContext.Current != null)
            {
                return HttpContext.Current.Server.MapPath(virtualFolder);
            }

            string mapped = HostingEnvironment.MapPath(virtualFolder);
            if (!string.IsNullOrEmpty(mapped))
            {
                return mapped;
            }

            // Fallback for non-hosted contexts or tests
            string relative = virtualFolder.TrimStart('~', '/').Replace('/', Path.DirectorySeparatorChar);
            return Path.Combine(GetApplicationRootPath(), relative);
        }

        /// <summary>
        /// Resolves a physical file path from a virtual or relative path or rooted disk path.
        /// </summary>
        private static string ResolvePhysicalPath(string virtualOrRelativePath)
        {
            if (string.IsNullOrWhiteSpace(virtualOrRelativePath))
            {
                return string.Empty;
            }

            if (Path.IsPathRooted(virtualOrRelativePath))
            {
                return virtualOrRelativePath;
            }

            string clean = virtualOrRelativePath.Trim();
            if (clean.StartsWith("/"))
            {
                clean = "~" + clean;
            }

            if (HttpContext.Current != null)
            {
                return HttpContext.Current.Server.MapPath(clean);
            }

            string mapped = HostingEnvironment.MapPath(clean);
            if (!string.IsNullOrEmpty(mapped))
            {
                return mapped;
            }

            string relative = clean.TrimStart('~', '/').Replace('/', Path.DirectorySeparatorChar);
            return Path.Combine(GetApplicationRootPath(), relative);
        }

        /// <summary>
        /// Constructs a client-accessible relative URL path.
        /// e.g. "~/Content/images/products/helmets/hnj/" + "sample.jpg" -> "/Content/images/products/helmets/hnj/sample.jpg"
        /// </summary>
        private static string BuildRelativeWebPath(string virtualFolder, string fileName)
        {
            string relativeDir = virtualFolder.Replace("~", "").TrimEnd('/') + "/";
            if (!relativeDir.StartsWith("/"))
            {
                relativeDir = "/" + relativeDir;
            }
            return relativeDir + fileName;
        }
    }
}
