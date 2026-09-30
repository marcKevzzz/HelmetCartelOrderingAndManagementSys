using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using HelmetCartelOrderingAndManagementSys.Constants;
using HelmetCartelOrderingAndManagementSys.Infrastructure;
using HelmetCartelOrderingAndManagementSys.Models.DTOs;
using HelmetCartelOrderingAndManagementSys.Repositories;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace HelmetCartelOrderingAndManagementSys.Admin
{
    public partial class CatalogItemPage : Page
    {
        private readonly IDbConnectionFactory _factory;
        private readonly AdminDataRepository _adminRepo;
        private readonly IProductRepository _productRepo;

        public bool IsDraft { get; set; } = true;
        public int ProductId { get; set; } = 0;

        public CatalogItemPage()
        {
            _factory = new DbConnectionFactory();
            _adminRepo = new AdminDataRepository(_factory);
            _productRepo = new ProductRepository(_factory);
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                string idStr = Request.QueryString["id"];
                if (int.TryParse(idStr, out int pid) && pid > 0)
                {
                    ProductId = pid;
                    hdnProductId.Value = pid.ToString();
                }

                RegisterAsyncTask(new PageAsyncTask(InitializePageDataAsync));
            }
        }

        private async Task InitializePageDataAsync()
        {
            try
            {
                // Populate Dropdowns
                var brands = await _productRepo.GetBrandsAsync().ConfigureAwait(false);
                var categories = await _productRepo.GetCategoriesAsync().ConfigureAwait(false);

                ddlBrand.Items.Clear();
                ddlBrand.Items.Add(new ListItem("Select Brand...", ""));
                foreach (var b in brands)
                {
                    ddlBrand.Items.Add(new ListItem(b.Name, b.Id.ToString()));
                }

                ddlCategory.Items.Clear();
                ddlCategory.Items.Add(new ListItem("Select Category...", ""));
                foreach (var c in categories)
                {
                    ddlCategory.Items.Add(new ListItem(c.Name, c.Id.ToString()));
                }

                if (ProductId > 0)
                {
                    // EDIT MODE: Load complete product details
                    var product = await _adminRepo.GetProductCompleteAsync(ProductId).ConfigureAwait(false);
                    if (product == null)
                    {
                        Response.Redirect("/Admin/Catalog.aspx?err=not_found", false);
                        Context.ApplicationInstance.CompleteRequest();
                        return;
                    }

                    txtHeaderTitle.InnerText = "Edit Helmet: " + product.Name;
                    Title = "Edit Helmet: " + product.Name;
                    IsDraft = !product.IsActive;
                    hdnIsActive.Value = product.IsActive ? "1" : "0";

                    // Basic Info
                    txtProductName.Text = product.Name;
                    txtSlug.Text = product.Slug;
                    txtDescription.Text = product.Description;
                    chkIsFeatured.Checked = product.IsFeatured;
                    ddlBrand.SelectedValue = product.BrandId.ToString();
                    ddlCategory.SelectedValue = product.CategoryId.ToString();

                    // Pricing & Discount
                    txtBasePrice.Text = product.BasePrice.ToString("0.00");
                    string dType = string.Equals(product.DiscountType, "FixedAmount", StringComparison.OrdinalIgnoreCase) ? "FixedAmount" : "Percentage";
                    hdnDiscountType.Value = dType;
                    ddlDiscountUnit.SelectedValue = dType;

                    if (dType == "FixedAmount")
                    {
                        txtDiscountValue.Text = product.DiscountAmount > 0 ? product.DiscountAmount.ToString("0.00") : "0";
                    }
                    else
                    {
                        txtDiscountValue.Text = product.DiscountPercentage.ToString();
                    }

                    hdnDiscountIsActive.Value = product.DiscountIsActive ? "Active" : "Inactive";
                    if (product.DiscountStartDate.HasValue)
                        txtDiscountStartDate.Text = product.DiscountStartDate.Value.ToString("yyyy-MM-dd");
                    if (product.DiscountEndDate.HasValue)
                        txtDiscountEndDate.Text = product.DiscountEndDate.Value.ToString("yyyy-MM-dd");

                    // Primary Image
                    txtMainImageUrl.Text = product.MainImageUrl;

                    // Serialize Collections for Client-Side JS
                    hdnSpecificationsJson.Value = JsonConvert.SerializeObject(product.Specifications);
                    hdnColorsJson.Value = JsonConvert.SerializeObject(product.Colors);
                    hdnVariantsJson.Value = JsonConvert.SerializeObject(product.Variants);
                    hdnGalleryJson.Value = JsonConvert.SerializeObject(product.GalleryImages);
                }
                else
                {
                    // CREATE MODE: Clean slate
                    txtHeaderTitle.InnerText = "New Helmet Model";
                    Title = "New Helmet Model";
                    IsDraft = true;
                    hdnIsActive.Value = "0";

                    // Explicitly reset form fields
                    txtProductName.Text = string.Empty;
                    txtSlug.Text = string.Empty;
                    txtDescription.Text = string.Empty;
                    txtBasePrice.Text = string.Empty;
                    txtDiscountValue.Text = "0";
                    txtMainImageUrl.Text = string.Empty;
                    txtDiscountStartDate.Text = string.Empty;
                    txtDiscountEndDate.Text = string.Empty;
                    chkIsFeatured.Checked = false;
                    if (ddlBrand.Items.Count > 0) ddlBrand.SelectedIndex = 0;
                    if (ddlCategory.Items.Count > 0) ddlCategory.SelectedIndex = 0;

                    // Clean initial JSON
                    hdnSpecificationsJson.Value = "[]";
                    hdnColorsJson.Value = "[]";
                    hdnVariantsJson.Value = "[]";
                    hdnGalleryJson.Value = "[]";
                }
            }
            catch (Exception ex)
            {
                ShowAlert("Failed to load product details: " + ex.Message);
            }
        }

        protected void btnSaveDraft_Click(object sender, EventArgs e)
        {
            hdnIsActive.Value = "0";
            RegisterAsyncTask(new PageAsyncTask(() => SaveProductAsync(false)));
        }

        protected void btnPublish_Click(object sender, EventArgs e)
        {
            hdnIsActive.Value = "1";
            RegisterAsyncTask(new PageAsyncTask(() => SaveProductAsync(true)));
        }

        private async Task SaveProductAsync(bool isActive)
        {
            try
            {
                // Basic validation
                string name = txtProductName.Text.Trim();
                if (string.IsNullOrWhiteSpace(name))
                {
                    if (isActive)
                    {
                        ShowAlert("Helmet model name is required.");
                        return;
                    }
                    name = "Untitled Helmet Draft";
                }

                int.TryParse(ddlBrand.SelectedValue, out int brandId);
                if (brandId <= 0)
                {
                    if (isActive)
                    {
                        ShowAlert("Please select a brand.");
                        return;
                    }
                    if (ddlBrand.Items.Count > 1 && int.TryParse(ddlBrand.Items[1].Value, out int fb))
                        brandId = fb;
                }

                int.TryParse(ddlCategory.SelectedValue, out int categoryId);
                if (categoryId <= 0)
                {
                    if (isActive)
                    {
                        ShowAlert("Please select a category.");
                        return;
                    }
                    if (ddlCategory.Items.Count > 1 && int.TryParse(ddlCategory.Items[1].Value, out int fc))
                        categoryId = fc;
                }

                string slug = string.IsNullOrWhiteSpace(txtSlug.Text) ? GenerateSlug(name) : GenerateSlug(txtSlug.Text.Trim());

                if (!decimal.TryParse(txtBasePrice.Text.Trim(), out decimal basePrice) || basePrice < 0)
                {
                    if (isActive)
                    {
                        ShowAlert("Please enter a valid base price.");
                        return;
                    }
                    basePrice = 0m;
                }

                string brandName = ddlBrand.SelectedItem != null ? ddlBrand.SelectedItem.Text : "general";

                // Save any base64 images in gallery JSON first so real web paths are generated
                string galleryJson = hdnGalleryJson.Value;
                var galleryList = (!string.IsNullOrWhiteSpace(galleryJson) && galleryJson != "[]")
                    ? (JsonConvert.DeserializeObject<List<JObject>>(galleryJson) ?? new List<JObject>())
                    : new List<JObject>();

                for (int i = 0; i < galleryList.Count; i++)
                {
                    var item = galleryList[i];
                    string url = item["imageUrl"] != null ? item["imageUrl"].Value<string>() : (item["url"] != null ? item["url"].Value<string>() : "");
                    if (!string.IsNullOrWhiteSpace(url) && url.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
                    {
                        string savedPath = SaveBase64ImageIfPresent(url, brandName, $"gallery_{i + 1}");
                        if (!string.IsNullOrWhiteSpace(savedPath))
                        {
                            if (item["imageUrl"] != null) item["imageUrl"] = savedPath;
                            if (item["url"] != null) item["url"] = savedPath;
                        }
                    }
                }

                string mainImage = txtMainImageUrl.Text.Trim();
                if (!string.IsNullOrWhiteSpace(mainImage) && mainImage.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
                {
                    // Reuse first gallery saved path if matching or available
                    if (galleryList.Count > 0)
                    {
                        string firstUrl = galleryList[0]["imageUrl"] != null ? galleryList[0]["imageUrl"].Value<string>() : (galleryList[0]["url"] != null ? galleryList[0]["url"].Value<string>() : "");
                        if (!string.IsNullOrWhiteSpace(firstUrl) && !firstUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
                        {
                            mainImage = firstUrl;
                        }
                        else
                        {
                            mainImage = SaveBase64ImageIfPresent(mainImage, brandName, "main");
                        }
                    }
                    else
                    {
                        mainImage = SaveBase64ImageIfPresent(mainImage, brandName, "main");
                    }
                }
                else if (string.IsNullOrWhiteSpace(mainImage) && galleryList.Count > 0)
                {
                    string firstUrl = galleryList[0]["imageUrl"] != null ? galleryList[0]["imageUrl"].Value<string>() : (galleryList[0]["url"] != null ? galleryList[0]["url"].Value<string>() : "");
                    if (!string.IsNullOrWhiteSpace(firstUrl) && !firstUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
                    {
                        mainImage = firstUrl;
                    }
                }

                if (string.IsNullOrWhiteSpace(mainImage))
                {
                    if (isActive)
                    {
                        ShowAlert("Primary thumbnail image URL is required.");
                        return;
                    }
                    mainImage = null; // Do NOT set to agv/images.jpg
                }

                // Discount parsing
                string discountType = string.Equals(hdnDiscountType.Value, "FixedAmount", StringComparison.OrdinalIgnoreCase) ||
                                      string.Equals(ddlDiscountUnit.SelectedValue, "FixedAmount", StringComparison.OrdinalIgnoreCase)
                                      ? "FixedAmount" : "Percentage";

                decimal.TryParse(txtDiscountValue.Text.Trim(), out decimal discountVal);
                int discountPct = 0;
                decimal discountAmt = 0m;

                if (discountType == "FixedAmount")
                {
                    discountAmt = Math.Max(0m, discountVal);
                }
                else
                {
                    discountPct = (int)Math.Min(100, Math.Max(0, discountVal));
                }

                DateTime? startDate = DateTime.TryParse(txtDiscountStartDate.Text, out var sd) ? (DateTime?)sd : null;
                DateTime? endDate = DateTime.TryParse(txtDiscountEndDate.Text, out var ed) ? (DateTime?)ed : null;
                bool discountIsActive = string.Equals(hdnDiscountIsActive.Value, "Active", StringComparison.OrdinalIgnoreCase) ||
                                        string.Equals(hdnDiscountIsActive.Value, "True", StringComparison.OrdinalIgnoreCase);

                int.TryParse(hdnProductId.Value, out int productId);

                // Save Product Header via dbo.sp_AdminSaveProduct
                using (var connection = (SqlConnection)_factory.CreateConnection())
                using (var command = new SqlCommand("dbo.sp_AdminSaveProduct", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = productId });
                    command.Parameters.Add(new SqlParameter("@CategoryId", SqlDbType.Int) { Value = categoryId });
                    command.Parameters.Add(new SqlParameter("@BrandId", SqlDbType.Int) { Value = brandId });
                    command.Parameters.Add(new SqlParameter("@Name", SqlDbType.NVarChar, 200) { Value = name });
                    command.Parameters.Add(new SqlParameter("@Slug", SqlDbType.NVarChar, 220) { Value = slug });
                    command.Parameters.Add(new SqlParameter("@Description", SqlDbType.NVarChar, -1) { Value = (object)txtDescription.Text.Trim() ?? DBNull.Value });
                    command.Parameters.Add(new SqlParameter("@RidingStyle", SqlDbType.NVarChar, 50) { Value = DBNull.Value });
                    command.Parameters.Add(new SqlParameter("@BasePrice", SqlDbType.Decimal) { Value = basePrice });
                    command.Parameters.Add(new SqlParameter("@DiscountPercentage", SqlDbType.Int) { Value = discountPct });
                    command.Parameters.Add(new SqlParameter("@DiscountType", SqlDbType.NVarChar, 20) { Value = discountType });
                    command.Parameters.Add(new SqlParameter("@DiscountAmount", SqlDbType.Decimal) { Value = discountAmt });
                    command.Parameters.Add(new SqlParameter("@DiscountStartDate", SqlDbType.DateTime2) { Value = (object)startDate ?? DBNull.Value });
                    command.Parameters.Add(new SqlParameter("@DiscountEndDate", SqlDbType.DateTime2) { Value = (object)endDate ?? DBNull.Value });
                    command.Parameters.Add(new SqlParameter("@MainImageUrl", SqlDbType.NVarChar, 500) { Value = (object)mainImage ?? DBNull.Value });
                    command.Parameters.Add(new SqlParameter("@IsFeatured", SqlDbType.Bit) { Value = chkIsFeatured.Checked });
                    command.Parameters.Add(new SqlParameter("@IsActive", SqlDbType.Bit) { Value = isActive });

                    await connection.OpenAsync().ConfigureAwait(false);
                    using (var reader = await command.ExecuteReaderAsync().ConfigureAwait(false))
                    {
                        if (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            productId = Convert.ToInt32(reader["Id"]);
                            hdnProductId.Value = productId.ToString();
                        }
                    }
                }

                if (productId <= 0)
                {
                    ShowAlert("Failed to save product record.");
                    return;
                }

                // 2. Save Technical Specifications
                string specsJson = hdnSpecificationsJson.Value;
                if (!string.IsNullOrWhiteSpace(specsJson) && specsJson != "[]")
                {
                    await _adminRepo.SaveProductSpecificationsAsync(productId, specsJson).ConfigureAwait(false);
                }

                // 3. Save Colors & Variants
                string colorsJson = hdnColorsJson.Value;
                string variantsJson = hdnVariantsJson.Value;
                await ProcessColorsAndVariantsAsync(productId, colorsJson, variantsJson).ConfigureAwait(false);

                // 4. Save Gallery Images
                await ProcessGalleryImagesListAsync(productId, galleryList).ConfigureAwait(false);

                // Redirect on success
                string customRedirect = hdnRedirectAfterSave.Value;
                if (!string.IsNullOrWhiteSpace(customRedirect))
                {
                    Response.Redirect(customRedirect, false);
                }
                else if (!isActive)
                {
                    Response.Redirect("/Admin/Catalog.aspx?msg=draft_saved", false);
                }
                else
                {
                    Response.Redirect("/Admin/Catalog.aspx?msg=published", false);
                }
                Context.ApplicationInstance.CompleteRequest();
            }
            catch (Exception ex)
            {
                ShowAlert("Error saving helmet model: " + ex.Message);
            }
        }

        private async Task ProcessColorsAndVariantsAsync(int productId, string colorsJson, string variantsJson)
        {
            if (string.IsNullOrWhiteSpace(colorsJson) || colorsJson == "[]") return;

            var colorsList = JsonConvert.DeserializeObject<List<JObject>>(colorsJson) ?? new List<JObject>();
            var variantsList = JsonConvert.DeserializeObject<List<JObject>>(variantsJson) ?? new List<JObject>();

            // Map color temp identifier to database ProductColorId
            var colorIdMap = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

            using (var connection = (SqlConnection)_factory.CreateConnection())
            {
                await connection.OpenAsync().ConfigureAwait(false);

                foreach (var c in colorsList)
                {
                    int colorId = c["id"] != null ? c["id"].Value<int>() : 0;
                    string colorName = c["color"] != null ? c["color"].Value<string>() : (c["name"] != null ? c["name"].Value<string>() : "Standard");
                    string cType = c["colorType"] != null ? c["colorType"].Value<string>() : "SOLID";
                    if (cType.IndexOf("GRADIENT", StringComparison.OrdinalIgnoreCase) >= 0) cType = "LINEAR_GRADIENT";
                    else cType = "SOLID";

                    string solidHex = c["solidHex"] != null ? c["solidHex"].Value<string>() : "#111827";
                    if (string.IsNullOrWhiteSpace(solidHex) || !solidHex.StartsWith("#")) solidHex = "#111827";

                    int? angle = c["gradientAngle"] != null ? c["gradientAngle"].Value<int?>() : 135;
                    var stops = c["stops"] != null ? c["stops"].ToObject<List<string>>() : null;
                    string stop1 = stops != null && stops.Count > 0 ? stops[0] : null;
                    string stop2 = stops != null && stops.Count > 1 ? stops[1] : null;

                    using (var cmd = new SqlCommand("dbo.sp_AdminSaveColor", connection))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = colorId });
                        cmd.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                        cmd.Parameters.Add(new SqlParameter("@Color", SqlDbType.NVarChar, 50) { Value = colorName });
                        cmd.Parameters.Add(new SqlParameter("@ColorType", SqlDbType.NVarChar, 20) { Value = cType });
                        cmd.Parameters.Add(new SqlParameter("@SolidHex", SqlDbType.NChar, 7) { Value = (object)solidHex ?? DBNull.Value });
                        cmd.Parameters.Add(new SqlParameter("@GradientAngle", SqlDbType.Int) { Value = (object)angle ?? DBNull.Value });
                        cmd.Parameters.Add(new SqlParameter("@Stop1", SqlDbType.NChar, 7) { Value = (object)stop1 ?? DBNull.Value });
                        cmd.Parameters.Add(new SqlParameter("@Stop2", SqlDbType.NChar, 7) { Value = (object)stop2 ?? DBNull.Value });
                        cmd.Parameters.Add(new SqlParameter("@Stop3", SqlDbType.NChar, 7) { Value = DBNull.Value });
                        cmd.Parameters.Add(new SqlParameter("@Stop4", SqlDbType.NChar, 7) { Value = DBNull.Value });

                        using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                        {
                            if (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                int savedColorId = Convert.ToInt32(reader["Id"]);
                                colorIdMap[colorName] = savedColorId;
                                if (colorId > 0) colorIdMap[colorId.ToString()] = savedColorId;
                            }
                        }
                    }
                }

                // Process Variants
                foreach (var v in variantsList)
                {
                    int variantId = v["id"] != null ? v["id"].Value<int>() : 0;
                    string cName = v["color"] != null ? v["color"].Value<string>() : "";
                    string size = v["size"] != null ? v["size"].Value<string>() : "M";
                    string sku = v["sku"] != null ? v["sku"].Value<string>() : "";
                    decimal priceAdj = v["priceAdjustment"] != null ? v["priceAdjustment"].Value<decimal>() : 0m;
                    int reorderPoint = v["reorderPoint"] != null ? v["reorderPoint"].Value<int>() : 3;
                    int initialStock = v["initialStock"] != null ? v["initialStock"].Value<int>() : (v["currentStock"] != null ? v["currentStock"].Value<int>() : 0);

                    int productColorId = 0;
                    if (v["productColorId"] != null && int.TryParse(v["productColorId"].ToString(), out int parsedPcId) && parsedPcId > 0)
                    {
                        productColorId = parsedPcId;
                    }
                    else if (colorIdMap.ContainsKey(cName))
                    {
                        productColorId = colorIdMap[cName];
                    }
                    else if (colorIdMap.Count > 0)
                    {
                        productColorId = colorIdMap.Values.First();
                    }

                    if (productColorId <= 0 || string.IsNullOrWhiteSpace(sku)) continue;

                    int savedVariantId = 0;
                    using (var cmd = new SqlCommand("dbo.sp_AdminSaveVariant", connection))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = variantId });
                        cmd.Parameters.Add(new SqlParameter("@ProductColorId", SqlDbType.Int) { Value = productColorId });
                        cmd.Parameters.Add(new SqlParameter("@SKU", SqlDbType.NVarChar, 100) { Value = sku });
                        cmd.Parameters.Add(new SqlParameter("@Size", SqlDbType.NVarChar, 20) { Value = size });
                        cmd.Parameters.Add(new SqlParameter("@PriceAdjustment", SqlDbType.Decimal) { Value = priceAdj });
                        cmd.Parameters.Add(new SqlParameter("@ReorderPoint", SqlDbType.Int) { Value = reorderPoint });
                        cmd.Parameters.Add(new SqlParameter("@IsActive", SqlDbType.Bit) { Value = true });

                        using (var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false))
                        {
                            if (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                savedVariantId = Convert.ToInt32(reader["Id"]);
                            }
                        }
                    }

                    // If new variant and initial stock specified, record initial stock
                    if (variantId == 0 && savedVariantId > 0 && initialStock > 0)
                    {
                        using (var cmdStock = new SqlCommand("dbo.sp_AdminAdjustStock", connection))
                        {
                            cmdStock.CommandType = CommandType.StoredProcedure;
                            cmdStock.Parameters.Add(new SqlParameter("@VariantId", SqlDbType.Int) { Value = savedVariantId });
                            cmdStock.Parameters.Add(new SqlParameter("@QuantityChanged", SqlDbType.Int) { Value = initialStock });
                            cmdStock.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = DBNull.Value });
                            cmdStock.Parameters.Add(new SqlParameter("@ReferenceNumber", SqlDbType.NVarChar, 100) { Value = "INITIAL_SETUP" });
                            cmdStock.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 500) { Value = "Initial stock entry on catalog creation" });
                            await cmdStock.ExecuteNonQueryAsync().ConfigureAwait(false);
                        }
                    }
                }
            }
        }

        private async Task ProcessGalleryImagesListAsync(int productId, List<JObject> galleryList)
        {
            using (var connection = (SqlConnection)_factory.CreateConnection())
            {
                await connection.OpenAsync().ConfigureAwait(false);

                // Clear existing gallery images first to prevent duplicate/unique constraint conflicts
                using (var cmdClear = new SqlCommand("dbo.sp_AdminClearProductGallery", connection))
                {
                    cmdClear.CommandType = CommandType.StoredProcedure;
                    cmdClear.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                    await cmdClear.ExecuteNonQueryAsync().ConfigureAwait(false);
                }

                if (galleryList == null || galleryList.Count == 0) return;

                int order = 1;
                foreach (var img in galleryList)
                {
                    string url = img["imageUrl"] != null ? img["imageUrl"].Value<string>() : (img["url"] != null ? img["url"].Value<string>() : "");
                    if (string.IsNullOrWhiteSpace(url)) continue;

                    string alt = img["altText"] != null ? img["altText"].Value<string>() : "";

                    using (var cmd = new SqlCommand("dbo.sp_AdminAddProductGalleryImage", connection))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add(new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId });
                        cmd.Parameters.Add(new SqlParameter("@ImageUrl", SqlDbType.NVarChar, 500) { Value = url });
                        cmd.Parameters.Add(new SqlParameter("@AltText", SqlDbType.NVarChar, 200) { Value = (object)alt ?? DBNull.Value });
                        cmd.Parameters.Add(new SqlParameter("@DisplayOrder", SqlDbType.Int) { Value = order++ });
                        await cmd.ExecuteNonQueryAsync().ConfigureAwait(false);
                    }
                }
            }
        }

        private string SaveBase64ImageIfPresent(string imagePathOrDataUrl, string brandName, string prefix = "img")
        {
            if (string.IsNullOrWhiteSpace(imagePathOrDataUrl)) return null;

            if (!imagePathOrDataUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
            {
                return imagePathOrDataUrl;
            }

            try
            {
                int commaIndex = imagePathOrDataUrl.IndexOf(',');
                if (commaIndex < 0) return null;

                string header = imagePathOrDataUrl.Substring(0, commaIndex);
                string base64Data = imagePathOrDataUrl.Substring(commaIndex + 1);

                string contentType = "image/jpeg";
                string ext = ".jpg";
                if (header.IndexOf("image/png", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    contentType = "image/png";
                    ext = ".png";
                }
                else if (header.IndexOf("image/webp", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    contentType = "image/webp";
                    ext = ".webp";
                }
                else if (header.IndexOf("image/gif", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    contentType = "image/gif";
                    ext = ".gif";
                }

                byte[] bytes = Convert.FromBase64String(base64Data);
                string filename = $"{prefix}_{Guid.NewGuid().ToString("N").Substring(0, 8)}{ext}";

                var result = ImageUploadHelper.SaveImageBytes(
                    imageBytes: bytes,
                    originalFileName: filename,
                    brand: string.IsNullOrWhiteSpace(brandName) ? "general" : brandName,
                    contentType: contentType,
                    prefix: prefix
                );

                if (result != null && result.Success && !string.IsNullOrWhiteSpace(result.FilePath))
                {
                    return result.FilePath;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Trace.TraceError("Failed to save base64 image: " + ex.Message);
            }

            return null;
        }

        private static string GenerateSlug(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return "helmet-" + Guid.NewGuid().ToString("N").Substring(0, 6);
            string str = text.ToLowerInvariant();
            str = Regex.Replace(str, @"[^a-z0-9\s-]", "");
            str = Regex.Replace(str, @"\s+", "-").Trim('-');
            return str;
        }

        private void ShowAlert(string message)
        {
            string cleanMsg = HttpUtility.JavaScriptStringEncode(message);
            ClientScript.RegisterStartupScript(this.GetType(), "serverAlertToast", $"showAdminToast('{cleanMsg}');", true);
        }
    }
}
