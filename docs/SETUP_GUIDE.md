# Developer Setup Guide: Helmet Cartel System

Follow this step-by-step guide to configure, build, and run the Helmet Cartel Ordering and Management System on your local development machine.

---

## 1. System Requirements & Prerequisites
- **Operating System:** Windows 10/11 or Windows Server.
- **IDE:** Visual Studio 2019/2022 with:
  - *.NET desktop development*
  - *ASP.NET and web development* workload
  - *.NET Framework 4.7.2 targeting pack*
- **Database Server:** Microsoft SQL Server 2017+ (Express, Developer, or Enterprise edition) or LocalDB.
- **Tools:** SQL Server Management Studio (SSMS) or Azure Data Studio.

---

## 2. Database Initialization
1. Open SSMS or your preferred SQL tool and connect to your local MSSQL instance (e.g., `(localdb)\MSSQLLocalDB` or `localhost`).
2. On a new database, run `database/schema/01_schema.sql` to create tables, constraints, and indexes.
3. Run `database/schema/03_product_gallery.sql` before installing procedures to add the optional product gallery table.
4. Run `database/schema/04_product_specifications.sql` to create category-aware product specification tables.
5. Run the seed data script:
   - Execute `database/seeds/02_seed_data.sql` (Inserts roles, admin & staff users, brands, categories, sample helmets, variants, and stock counts).
6. Run the stored procedures script:
   - Execute `database/queries/03_procedures_and_queries.sql` (Installs atomic stock decrement procedures, reporting functions).
7. Run `database/seeds/03_helmet_catalog_seed.sql` to add the image-based helmet catalog.
8. On an existing database seeded with the old demo catalog, run `database/seeds/04_remove_unrequested_demo_brands.sql` to remove only the four unused demo brands and products. It stops if those products have order or stock audit history.
9. Run `database/queries/04_product_specification_procedures.sql`, then execute `EXEC dbo.sp_SeedShoeiRf1400Specifications;` to add the supplied technical specifications for the Shoei RF-1400.
10. Run `database/seeds/05_catalog_content.sql` to add selected gallery photos, missing helmets, editable price estimates, visible specifications, and ten clearly labeled sample reviews. The selected files are already copied into `Content/images/products/helmets/` and included in the web project; `database/seeds/catalog_image_manifest.csv` records each original Context source. If source photos change later, rerun `python database/seeds/build_catalog_images.py` from the repository root before rerunning the SQL seed.
11. Run `database/seeds/06_sample_catalog_availability.sql` to add missing S–XXL variants and inventory, sample opening stock with audit entries, XL/XXL price adjustments, and specifications for the four original five-brand products. This seed is rerunnable and preserves existing nonzero stock, price adjustments, and specification values.
12. For a local/demo dashboard, run `database/seeds/07_dashboard_audit_samples.sql` to add four rerunnable restock, count-correction, return, and in-store sale audit events.

For an existing database, run `database/schema/02_3nf_integrity_migration.sql`, `database/schema/03_product_gallery.sql`, `database/schema/04_product_specifications.sql`, and `database/schema/05_product_order_count_index.sql`; then run `database/queries/03_procedures_and_queries.sql`, the catalog seed/cleanup scripts as applicable, `database/queries/04_product_specification_procedures.sql`, `EXEC dbo.sp_SeedShoeiRf1400Specifications;`, `database/seeds/05_catalog_content.sql`, and finally `database/seeds/06_sample_catalog_availability.sql`. Do not rerun the fresh-install schema or initial demo seed. The migrations are rerunnable; the 3NF migration stops if conflicting colors or inconsistent historical totals need correction.

After updating product detail code on an existing installation, install `database/schema/04_product_specifications.sql` and run `database/queries/04_product_specification_procedures.sql`. The detail page shows only specifications configured for that product category and populated for that product. Use `dbo.sp_UpsertSpecificationDefinition` to add a spec name, `dbo.sp_UpsertCategorySpecification` to map it to a category, and `dbo.sp_UpsertProductSpecificationValue` to set a product's value.

Re-run `database/queries/03_procedures_and_queries.sql` after updating the product detail layout so `dbo.sp_GetRelatedProducts` can populate the four "You Might Also Like" cards.

### Admin portal upgrade

Back up `HelmetCartelDB` before updating an existing installation. Run these scripts in order with `QUOTED_IDENTIFIER ON` (for `sqlcmd`, use `-I`):

1. `database/schema/06_admin_portal_migration.sql`
2. `database/queries/03_procedures_and_queries.sql`
3. `database/queries/05_admin_operations.sql`
4. `database/queries/06_admin_catalog.sql`

For a fresh installation, run the existing schema, gallery, and specification scripts first, then the four scripts above. The migration adds required `FirstName` and `LastName`, splits existing `FullName` at its first space, and keeps `FullName` for older callers. It retains each color's original `ColorHex` and converts recognized legacy linear gradients and comma-separated hex stops to structured stops. Check name and color counts before removing any legacy columns; this release does not remove them. The dashboard and reports count completed payments as revenue. Inventory valuation awaits acquisition-cost storage.

`/Admin/Dashboard.aspx` is the portal entry point. Admin sees Catalog, Reports, Users, Reviews, and Payments in addition to operations pages. Staff sees Dashboard, Orders, Inventory, and POS. Customers remain on the storefront. API actions enforce the same roles; hiding navigation links is only a presentation choice.

---

## 3. Web.config Configuration
Open `HelmetCartelOrderingAndManagementSys/Web.config` and configure the following connection strings and app settings:

```xml
<configuration>
  <connectionStrings>
    <add name="DefaultConnection" 
         connectionString="Server=localhost;Database=HelmetCartelDB;Integrated Security=True;MultipleActiveResultSets=True;" 
         providerName="System.Data.SqlClient" />
  </connectionStrings>

  <appSettings>
    <!-- JWT Configuration -->
    <add key="Jwt:Secret" value="" />
    <add key="Jwt:Issuer" value="HelmetCartelApi" />
    <add key="Jwt:Audience" value="HelmetCartelClients" />
    <add key="Jwt:ExpiryMinutes" value="60" />

    <!-- HitPay Gateway Configuration -->
    <add key="HitPay:BaseUrl" value="https://api.sandbox.hit-pay.com/v1/" />
    <add key="HitPay:ApiKey" value="your_sandbox_hitpay_api_key_here" />
    <add key="HitPay:Salt" value="your_sandbox_hitpay_salt_here" />

    <!-- System Configuration -->
    <add key="Inventory:DefaultReorderPoint" value="3" />
  </appSettings>
</configuration>
```

Set `HELMET_CARTEL_JWT_SECRET` to a private value of at least 32 characters in production. With no configured secret, the app creates `App_Data/jwt-secret.key` locally; the app pool must be able to write that folder. Keep the key out of source control and stable across application instances. SignalR uses the bundled SignalR and OWIN packages and serves `/signalr`; the admin order hub checks a fresh Staff or Admin role before accepting a connection.

---

## 4. Building & Running the Project
1. Open `HelmetCartelOrderingAndManagementSys.slnx` or `HelmetCartelOrderingAndManagementSys.csproj` in Visual Studio.
2. In Visual Studio, right-click the solution and choose **Restore NuGet Packages**.
3. Build the solution (`Ctrl + Shift + B`).
4. Press `F5` to start debugging with **IIS Express**.
5. The application will launch at:
   - Storefront: `https://localhost:44359/`
   - Staff Dashboard: `https://localhost:44359/Admin/Dashboard.aspx`
   - Web API: `https://localhost:44359/api/v1/...`
   - SignalR Endpoint: `https://localhost:44359/signalr`

---

## 5. Default Credentials for Testing
- **Admin User:**
  - Email: `admin@helmetcartel.com`
  - Password: `password` (local seed only; change before deployment)
  - Role: `Admin` (Access to reports, user management, full catalog & restock controls)
- **Staff User:**
  - Email: `staff@helmetcartel.com`
  - Password: `password` (local seed only; change before deployment)
  - Role: `Staff` (Access to in-store POS, order pipeline, stock management)
- **Customer User:**
  - Email: `juan@rider.com`
  - Password: `password` (local seed only; change before deployment)
  - Role: `Customer`

### Small fresh database (same current schema)

Open `database/setup/new_database_minimal.sql` in a normal SSMS query window and execute the complete file. SQLCMD Mode is not required. It creates `HelmetCartelMinimalDB` with the current tables, constraints, indexes, functions and stored procedures, including migrations through 14. It refuses to run if that database already exists; the existing `HelmetCartelDB` is untouched. If installation fails midway, use a different new database name after correcting the error.

The compact sample contains three roles, three brands, four categories, five image-backed products, ten SKUs, 51 current warehouse units, twelve gallery images, and six orders spread across the previous week. Two of the original variants remain low-stock so the dashboard alert state is visible. The product details and image paths come from the existing project catalog. Users and reviews remain empty; register an account through the application because no shared demo password is installed.

To use another database name or regenerate after schema changes, run from the repository root:

```powershell
powershell -File .\database\setup\Build-MinimalDatabase.ps1 -DatabaseName HelmetCartelMinimalDB
```

The builder only writes SQL. After executing the SQL, change `Initial Catalog=HelmetCartelDB` to `Initial Catalog=HelmetCartelMinimalDB` in `Web.config` to connect the application to it. Do not run the full catalog seed scripts on this small database.

For an existing database already at migration 13, run `database/schema/14_pos_and_inventory_drilldown.sql` in that database before using POS. It adds exact Inventory links, Analytics brand item details, the filtered POS catalog, and server-priced cash validation. No extra sample data is added by this migration.

### Local JWT secret file

The app now reads your `HelmetCartelOrderingAndManagementSys/App_Data/Jwt_Secret` file when neither `HELMET_CARTEL_JWT_SECRET` nor `Jwt:Secret` is configured. Keep only the secret text in this file (at least 32 characters); surrounding whitespace is trimmed. It is excluded from Git. The original generated `App_Data/jwt-secret.key` remains the fallback only when `Jwt_Secret` is absent. Restart the app after changing the secret; tokens signed using the previous key will require a new login. Supply this private file separately when deploying, or use the environment variable.
