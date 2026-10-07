# Database scripts

The database folder contains SQL Server source scripts and setup tools. The web
application calls the stored procedures they install; it does not run these files.

## Standalone Database Script (for other devices / fresh setup)

The file `database/setup/HelmetCartelDB_Complete.sql` is a self-contained SQL script containing:
- Creation of `HelmetCartelDB` (if not exists)
- All 28 active application tables, primary keys, indexes, and constraints
- Full seed and catalog data (users with Admin/Staff/Customer roles, 36 products, 440 variants, stock inventory, categories, brands, specifications, orders, and vouchers)
- Table-valued types (`SaleLineInput`), scalar functions (`fn_BaseColorFromHex`, `fn_CalculateEffectivePrice`), views (`v_VisibleProducts`, etc.), and triggers (`tr_Orders_ReleaseVoucher`)
- All 104 actively referenced stored procedures (excluding obsolete/one-time seed procedures)

To install on a new device:
1. Open SQL Server Management Studio (SSMS) or Visual Studio.
2. Open `database/setup/HelmetCartelDB_Complete.sql`.
3. Execute the script (`F5`).
4. Ensure your `Web.config` connection string points to `.\SQLEXPRESS;Initial Catalog=HelmetCartelDB;Integrated Security=True;`.

## Fresh development database (Legacy builder)

From the repository root, build the installer for an unused database name:

```powershell
powershell -File .\database\setup\Build-MinimalDatabase.ps1 -DatabaseName HelmetCartelMinimalDB
```

Run `setup/new_database_minimal.sql` in SSMS, then point the
application connection string at that database. Edit source scripts rather than the generated installer.

## Existing database

Keep the numbered files in `schema/`: later definitions can replace earlier
procedures, but earlier files also establish tables, columns, views, and upgrade
steps. Repeated procedure names do not make an entire migration disposable.
Migration 02 is a legacy integrity upgrade, not part of the fresh-install builder.

For a configured `HelmetCartelDB` already at migration 17 or later, use
`setup/Update-LatestSchema.ps1` with explicit `-StartMigration` and `-EndMigration`
for the unapplied range. The runner backs up before applying changes. Its
`-DryRun` option still executes SQL inside a transaction before rolling it back;
it is not a static or read-only check. Do not blindly replay earlier migrations.
The range parameters are mandatory. Migration 47 is skipped unless
`-IncludeDemoContent` is supplied; it deletes/replaces demonstration reviews and
must not be treated as a routine structural upgrade. For a database already at
50, apply only 51–52 for the academic business-process corrections.

## Folder roles

| Folder | Purpose |
| --- | --- |
| `schema/` | Base schema and ordered upgrade history. |
| `queries/` | Procedure source required by the installer and migrations. |
| `setup/` | Fresh-install builder, generated installer, upgrade runner, visibility verification, and compact sample data. |
| `seeds/` | Optional full image-backed demo catalog, availability and audit samples, plus image provenance and tooling. |
| `query_logs/` | Historical profiling notes; measure the current schema before relying on old plans. |

The full-catalog seeds are a separate dataset from the compact setup samples.
Do not combine them automatically. `seeds/04_remove_unrequested_demo_brands.sql`
is retained for the documented legacy demo-catalog upgrade; it is not a normal
installation step.

## Retired scripts

Removed unreferenced scripts: the blanket order/payment reset, the one-off
14-SKU inventory cleanup, and the fixed-ID order seed. The compact setup's
`dashboard_sample_data.sql` supplies sample orders using SKU lookups instead.
Also removed the old migration 17/24 generators: they reconstructed historical
migrations from earlier definitions and could overwrite intentional later work.
The migrations themselves remain available. Tracked retired files can be
recovered from Git history; no live database objects or records were removed.
