# Database scripts

The database folder contains SQL Server source scripts and setup tools. The web
application calls the stored procedures they install; it does not run these files.

## Fresh development database

From the repository root, build the installer for an unused database name:

```powershell
powershell -File .\database\setup\Build-MinimalDatabase.ps1 -DatabaseName HelmetCartelMinimalDB
```

Run the complete `setup/new_database_minimal.sql` in SSMS, then point the
application connection string at that database. The builder only writes a file;
it does not connect to SQL Server. The generated installer includes migrations
through 35 and compact development samples. It must not be run on an existing
database. Edit source scripts rather than the generated installer.

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
