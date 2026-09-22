# SQL schema import + Filament panel (steps 3–4)

## Status
`in-progress` — step 3 in progress, step 4 not started

## Context
The application (Laravel 13.33.0 at the repository root) is connected to the MySQL 8.4.11 container,
database `personal_finances`, currently empty. The person supplied the schema script for `users`,
`accounts`, `categories`, `transactions` and `budgets` (InnoDB, `utf8mb4_unicode_ci`, explicit foreign
keys and indexes) and the original instruction was to **import it into the database** — so the script is
treated as the source of truth for the domain tables rather than being rewritten as migrations.

The framework-owned tables are *not* in the script (`sessions`, `cache`, `cache_locks`, `jobs`,
`job_batches`, `failed_jobs`, `password_reset_tokens`, `migrations`), and `.env` runs sessions, cache and
queues on the database, so they are created by the skeleton's own migrations.

Order therefore matters, and was verified rather than assumed: the script's `users` definition was
compared column by column with `0001_01_01_000000_create_users_table` and is **identical** (`bigint
unsigned` id, `name`, unique `email`, nullable `email_verified_at`, `password`, `remember_token`, nullable
timestamps). Running `php artisan migrate` first makes the script's `CREATE TABLE IF NOT EXISTS users` a
no-op; running the script first would instead make `Schema::create('users')` fail.

## Subtasks

- [x] 1. Write this plan, update `/plans/_index.md`, and keep the script in version control
- [x] 2. Run the framework migrations (8 framework tables + `migrations`)
- [x] 3. Import the supplied script into `personal_finances`
- [x] 4. Verify the result: table list, foreign keys, indexes, charset/collation, per-table row counts
- [x] 5. Report step 3 with evidence, plus the design findings raised for a decision

## Success criteria

### Subtask 2: the framework tables exist
```gherkin
Feature: Framework migrations

  Scenario: Migrations run against the container database
    Given `.env` points at the MySQL container
    When `php artisan migrate --force` runs in the verification image
    Then it exits 0 without errors
    And `SHOW TABLES` includes `migrations`, `sessions`, `cache`, `cache_locks`, `jobs`,
      `job_batches`, `failed_jobs`, `password_reset_tokens` and `users`
```

### Subtask 3: the supplied script is applied
```gherkin
Feature: Schema import

  Scenario: The domain tables are created
    Given the framework migrations have run
    When the script is piped into the `mysql` client inside the container, targeting `personal_finances`
    Then the client exits 0
    And `accounts`, `categories`, `transactions` and `budgets` exist
    And `users` was left untouched by the script's `IF NOT EXISTS`

  Scenario: The script is not applied twice by accident
    Given the tables already exist
    When the same script is applied again
    Then it still exits 0 (idempotent) and the table count is unchanged
```

### Subtask 4: the result matches the script's intent
```gherkin
Feature: Imported schema

  Scenario: Constraints and indexes are present
    Given the imported tables
    When `information_schema` is queried
    Then the 8 foreign keys of the script exist (`fk_accounts_user`, `fk_categories_user`,
      `fk_categories_parent`, `fk_transactions_user`, `fk_transactions_account`,
      `fk_transactions_category`, `fk_budgets_user`, `fk_budgets_category`)
    And `uq_user_category_period` exists on `budgets`
    And `idx_user_trans_date` and `idx_category_trans_date` exist on `transactions`

  Scenario: Storage is utf8mb4 end to end
    Given the imported tables
    When their collation is queried
    Then every table reports `utf8mb4_unicode_ci`

  Scenario: Money is stored as fixed precision
    Given `accounts.balance`, `transactions.amount` and `budgets.amount`
    When their column types are queried
    Then all three are `decimal(12,2)`
```

## Verification evidence (2026-09-22)

| Check | Command | Observed |
|---|---|---|
| Framework migrations | `php artisan migrate --force` | `users`, `cache`, `jobs` migrations `DONE`; `migrations` table created in batch 1 |
| Script applied | `docker compose exec -T mysql mysql … < database/schema/01-personal-finances.sql` | `exit=0` |
| Table list | `SHOW TABLES` | **13 tables**: the 9 framework ones plus `accounts`, `categories`, `transactions`, `budgets` |
| Domain tables empty | `COUNT(*)` per domain table | all `0` — nothing seeded or invented |
| Foreign keys | `information_schema.REFERENTIAL_CONSTRAINTS` | all 8 present: `fk_accounts_user`, `fk_categories_user`, `fk_categories_parent`, `fk_transactions_user`, `fk_transactions_account`, `fk_transactions_category`, `fk_budgets_user`, `fk_budgets_category` |
| Delete rules | same query, `DELETE_RULE` | `CASCADE` on all except `fk_categories_parent` → `SET NULL` (as the script specifies) |
| Unique constraints | `information_schema.STATISTICS` where `NON_UNIQUE = 0` | `budgets.uq_user_category_period (user_id, category_id, month, year)` and `users.users_email_unique (email)` |
| Query indexes | `STATISTICS` for `transactions` | `idx_user_trans_date (user_id, transaction_date)`, `idx_category_trans_date (category_id, transaction_date)`; no redundant index is created for `fk_transactions_user`/`fk_transactions_category` because those composite indexes already cover the leading column |
| Collation | `information_schema.TABLES.TABLE_COLLATION` | all 13 tables `utf8mb4_unicode_ci` |
| Money precision | `information_schema.COLUMNS.COLUMN_TYPE` | `accounts.balance`, `transactions.amount`, `budgets.amount` all `decimal(12,2)` — no float |
| Idempotency | script applied a second time | `exit=0`, table count still `13` |
| Laravel sees the result | `php artisan db:show` | `Tables: 13`, `Total Size: 336.00 KB` |

## Decisions log

### D13: the script is applied as-is; it is the source of truth for the domain tables
- **Context:** the schema could be imported literally, or translated into Laravel migrations.
- **Options considered:** import as-is (matches the original instruction "para que se importen en la base
  de datos" and the script's DDL style); translate everything to migrations (reproducible via
  `php artisan migrate`, testable with `RefreshDatabase`, but duplicates work and risks drift from the
  design the person already has).
- **Decision:** imported as-is. Recorded explicitly because the (a)/(b) question raised earlier was
  answered by the script's intent rather than by an explicit word from the person: if migrations are
  preferred later, this file's evidence table is the checklist any translation has to satisfy.
- **Consequence to keep in mind:** the domain schema now lives in `database/schema/01-personal-finances.sql`,
  not in migrations, so `php artisan migrate:fresh` would **drop** the framework tables while leaving the
  domain ones (EFKs on `users` mean `migrate:fresh` will in fact fail until the domain tables are dropped
  too). Flagged in "Findings".
- **Reversibility:** easy while the tables are empty; costly once real financial data exists.

### D14: `php artisan migrate` runs before the import
- **Context:** the script creates `users`, which the skeleton's migration also creates.
- **Options considered:** script first (`Schema::create('users')` then fails); migration first (the
  script's `CREATE TABLE IF NOT EXISTS users` becomes a no-op).
- **Decision:** migrations first, import second.
- **Reason:** the two `users` definitions were compared column by column and are identical, so neither
  order produces a different table — only a different failure mode. Verified after the fact: `users`
  reports Laravel's `users_email_unique` and the script changed nothing.
- **Reversibility:** easy.

### D15: the script is kept in the repository, with a provenance header
- **Context:** with D13 there is no migration describing `accounts`, `categories`, `transactions` or
  `budgets`, so the schema existed only inside the running container.
- **Options considered:** keep it out of the repository (nothing to review, schema unversioned);
  commit it verbatim; commit it with an added comment header.
- **Decision:** `database/schema/01-personal-finances.sql`, byte-identical in semantics to what was
  supplied, plus a comment block at the top recording who supplied it, when, the target database name and
  the required order of application.
- **Reason:** one schema, reviewable and reproducible, with no risk of the file drifting silently from
  what was executed. `base/03-safety-and-scope.md` forbids silently rewriting the person's artefacts, so
  only comments were added — say the word and the header comes out.
- **Reversibility:** easy.

## Findings raised for a decision (nothing changed in the script)

1. **`ON DELETE CASCADE` on financial history — the one worth a decision now.** `fk_transactions_account`
   and `fk_transactions_category` cascade, so a hard `DELETE` on an account or a category deletes its
   transactions. `accounts` and `transactions` do have `deleted_at`, so Eloquent's normal `delete()` is
   safe — but `forceDelete()`, a raw `DELETE`, or any future admin action bypasses that and the loss is
   silent. `budgets` cascades on `category_id` too. Safer alternatives, if wanted:
   ```sql
   -- keep the account row as the reason a transaction cannot be hard-deleted
   ALTER TABLE `transactions` DROP FOREIGN KEY `fk_transactions_account`;
   ALTER TABLE `transactions` ADD CONSTRAINT `fk_transactions_account`
     FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT;
   -- or, for categories, make the column nullable and keep the transaction with no category
   ALTER TABLE `transactions` MODIFY `category_id` BIGINT UNSIGNED NULL;
   ALTER TABLE `transactions` DROP FOREIGN KEY `fk_transactions_category`;
   ALTER TABLE `transactions` ADD CONSTRAINT `fk_transactions_category`
     FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL;
   ```
2. **Soft-delete policy is inconsistent.** `accounts` and `transactions` have `deleted_at`; `categories`
   and `budgets` do not, and neither does `users`. Combined with finding 1, deleting a user hard-cascades
   accounts → transactions, categories and budgets, and `App\Models\User` does not use the `SoftDeletes`
   trait, so nothing in the application currently prevents it. A one-line policy decision (soft deletes
   for users/categories, or `RESTRICT` wherever history hangs off a row) closes it.
3. **`status ENUM('completed','pending','cancelled')`.** Works and enforces values in the database, but
   every new status needs an `ALTER TABLE`, and Laravel/Filament are happier casting a `VARCHAR` to a PHP
   enum. A trade-off to keep or drop, not an error.
4. **`SET FOREIGN_KEY_CHECKS = 0` is unnecessary here.** The tables are created in dependency order and
   there are no cycles; it also removes protection if the script aborts midway for any other reason.
5. **`month`/`year` have no range check.** `TINYINT UNSIGNED` accepts `0..255`, so `month = 13` is
   storable. Either a `CHECK` constraint or Filament-level validation (`min:1|max:12`), the latter
   belonging to step 4.
6. **Sign convention for `amount` is undefined.** `transactions.amount` is `NOT NULL` with no `CHECK`; if
   income/expense is derived from `categories.type`, a negative amount can still be stored. Worth pinning
   down before the Filament form is generated.
7. **Naming:** the two commented lines at the top of the script say `personal_finance` (singular) while the
   container and `.env` use `personal_finances` (plural). They stay commented, and the header comment in
   `database/schema/01-personal-finances.sql` records the discrepancy.
8. **No transfer concept.** Nothing models money moving between two accounts; today that would be two
   unlinked transactions. Not a defect — just the next schema decision whenever transfers are wanted.

## Step 4 readiness (not started)

- `filament/filament` **5.8.4** requires `ext-intl`; the host PHP lacks it, so `composer require` and
  `php artisan filament:*` must run through `pf-php:8.4-dev` (which has `intl`), not the host.
- `php artisan make:filament-user` is interactive (name, email, password). Two clean options: pipe the
  answers in, or add a seeder (`database/seeders/AdminUserSeeder.php`) so the admin user is reproducible
  and its password comes from the environment instead of shell history.
- Also to decide then: panel path (`/admin` is Filament's default) and whether the panel should be
  restricted to a particular email/role.
