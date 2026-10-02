# Normalization decisions

The latest schema is produced by the ordered setup generator through migration 24.
Use `setup/Update-LatestSchema.ps1` for backed-up transactional upgrades; use its
`-DryRun` switch for rollback-only validation. Earlier migrations are historical
upgrade steps and must not be applied independently after newer ones.

## Removed redundancy

`Users.FullName` is not a table column after migration 24. FirstName and LastName
are the source of truth; procedures return their concatenation as the FullName
result alias required by existing DTOs. No C# query or client contract needs a
stored full name. Global search follows the same rule.

## Deliberately retained fields

- Order customer/contact/shipping details and line-item UnitPrice are transaction
  snapshots. They must not change when a user, saved address, or product is edited.
- Address RecipientName and PhoneNumber describe the recipient of that particular
  address, who may differ from the account holder.
- Review ReviewerName records the review attribution, including guest reviews.
- Payment Amount records the actual payment, rather than the current order total.
- Audit PreviousStock and QuantityChanged describe a historical stock event.
- TotalAmount, TotalPrice, NewStock and IsLowStock are SQL computed expressions,
  not independently writable duplicate facts. They support existing constraints,
  indexes and query contracts without update anomalies.

Tables separate roles, brands, categories, colors, variants, inventory, payments,
addresses, specification definitions/values and review reports using foreign keys.
Normalization depends on business functional dependencies, not repeated values
alone. These decisions are an operational audit, not a proof that every current
or future business attribute meets third normal form.
