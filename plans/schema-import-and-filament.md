# SQL schema import + Filament panel (steps 3–4)

## Status
`complete` — steps 3–4 verified; finding 1 (`ON DELETE CASCADE` on financial history) remediated and verified (subtasks 11–14); finding 2 (`fk_*_user` cascades + soft-delete policy) resolved afterwards as D20 in `/plans/user-delete-policy.md` (2026-09-25)

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

Step 4 (Filament panel + admin user):

- [x] 6. Install `filament/filament` with Composer **inside `pf-php:8.4-dev`** (host PHP has no `ext-intl`)
- [x] 7. Create the panel with `php artisan filament:install --panels` (path `/admin`) and publish its assets
- [x] 8. Create `AdminUserSeeder` (credentials from `FILAMENT_ADMIN_*` env vars, never hardcoded) and run it
- [x] 9. Verify end to end: dependency present, panel routes, login page serves, admin row hashes correctly
- [x] 10. Document: `docs/CHANGELOG.md` entry, close this plan, update `/plans/_index.md`; commit

Finding 1 remediation (`ON DELETE CASCADE` on financial history):

- [x] 11. Apply the three FK changes to the live database (`fk_transactions_account` → `RESTRICT`,
      `fk_transactions_category` → `SET NULL` + `category_id` nullable, `fk_budgets_category` →
      `RESTRICT`) and verify `DELETE_RULE` in `information_schema`
- [x] 12. Functional proof: hard-delete of an account is refused, hard-delete of a category without
      budgets detaches its transactions (`category_id → NULL`), hard-delete of a category with
      budgets is refused; test rows removed afterwards (domain tables back to 0 rows)
- [x] 13. Update `database/schema/01-personal-finances.sql` so a fresh import produces the same
      rules, and prove it by importing into a scratch database and diffing `DELETE_RULE`
- [x] 14. Document: D19, finding 1 marked resolved, `docs/CHANGELOG.md` entry, `_index.md`, re-close
      this plan; commit

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

### Subtasks 6–7: Filament is installed and the panel exists
```gherkin
Feature: Filament panel

  Scenario: The package is a dependency
    Given `composer.json`
    When it is inspected
    Then `filament/filament` is listed under `require`

  Scenario: The panel is registered at the default path
    Given the install ran inside `pf-php:8.4-dev`
    When `php artisan route:list --path=admin` runs
    Then Filament's routes for the panel are listed under `/admin`
```

### Subtask 8: the admin user is reproducible
```gherkin
Feature: Admin user seeder

  Scenario: Seeding creates the admin
    Given `.env` defines `FILAMENT_ADMIN_NAME`, `FILAMENT_ADMIN_EMAIL` and `FILAMENT_ADMIN_PASSWORD`
    When `php artisan db:seed --class=AdminUserSeeder --force` runs in the verification image
      with host networking
    Then it exits 0
    And a `users` row exists with the configured email
    And its stored `password` verifies against the configured plaintext (hashed cast)

  Scenario: Seeding twice does not duplicate
    Given the row already exists
    When the seeder runs again
    Then the `users` row count for that email is unchanged
```

### Subtask 9: the panel serves its login page
```gherkin
Feature: Panel reachability

  Scenario: The login page responds
    Given `php artisan serve` running in the verification image with host networking
    When `curl` requests `http://127.0.0.1:8000/admin/login`
    Then it returns `200`
    And the response is Filament's login form
```

### Subtask 11: the live database carries the new rules
```gherkin
Feature: FK delete rules on the live database

  Scenario: information_schema reports the remediated rules
    Given the MySQL container is healthy
    When `REFERENTIAL_CONSTRAINTS` is queried for schema `personal_finances`
    Then `fk_transactions_account` reports `RESTRICT`
    And `fk_transactions_category` reports `SET NULL`
    And `fk_budgets_category` reports `RESTRICT`
    And the four `fk_*_user` constraints still report `CASCADE` (finding 2, untouched)
    And `fk_categories_parent` still reports `SET NULL`

  Scenario: only the column nullability changes
    Given the `transactions` table
    When `information_schema.COLUMNS` is queried
    Then `category_id` is `IS_NULLABLE = YES` and no other column changed nullability
```

### Subtask 12: deletes behave as intended
```gherkin
Feature: Hard-delete behaviour

  Scenario: An account with transactions cannot be hard-deleted
    Given a test account with one test transaction
    When `DELETE FROM accounts WHERE id = <test>` runs
    Then it fails (RESTRICT)
    And the account and the transaction both still exist

  Scenario: A category without budgets detaches its transactions
    Given a test category with one test transaction and no budgets
    When `DELETE FROM categories WHERE id = <test>` runs
    Then it succeeds
    And the test transaction survives with `category_id = NULL`

  Scenario: A category with budgets cannot be hard-deleted
    Given a test category with one test budget
    When `DELETE FROM categories WHERE id = <test>` runs
    Then it fails (RESTRICT)

  Scenario: Nothing is left behind
    Given all test rows created by these scenarios
    When they are deleted explicitly
    Then `accounts`, `categories`, `transactions` and `budgets` all report 0 rows
    And `users` still reports exactly 1 row (the admin)
```

### Subtask 13: a fresh import matches the live rules
```gherkin
Feature: Script and database stay in sync

  Scenario: The scratch import produces the same delete rules
    Given a scratch database created only for this check
    When the updated `database/schema/01-personal-finances.sql` is imported into it
    Then the import exits 0
    And the set of `(TABLE_NAME, CONSTRAINT_NAME, DELETE_RULE)` equals the live database's set
    And `transactions.category_id` is nullable there too

  Scenario: The scratch database is removed
    Given the check finished
    When the scratch database is dropped
    Then only `personal_finances` (plus MySQL's system schemas) remain
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

## Step 4 verification evidence (2026-09-23)

All artisan/composer commands ran in `pf-php:8.4-dev` (`--user 1000:1000 --network host`, workspace
mounted) — the host PHP (now 8.5.1) still has no `intl`/`pdo_mysql`.

| Check | Command | Observed |
|---|---|---|
| Dependency installed | `composer require filament/filament` | `EXIT=0`; `filament/filament: ^5.8` (resolved **v5.8.4**) + 32 transitive packages (Livewire **v4.4.6**), lock file written, no security advisories |
| Panel created | `php artisan filament:install --panels --no-interaction` | `EXIT=0`; `app/Providers/Filament/AdminPanelProvider.php` created, registered in `bootstrap/providers.php`, assets published, `.gitignore` gained `/public/js/filament`, `/public/css/filament`, `/public/fonts/filament` |
| Panel is the default at `/admin` | `php artisan route:list --path=admin` | 3 routes: `GET admin` (dashboard), `GET admin/login`, `POST admin/logout` |
| Seeder runs | `php artisan db:seed --class=AdminUserSeeder --force` ×2 | both `EXIT=0` (622 ms, 268 ms) |
| Admin row + idempotency + hash | `tinker --execute` counting rows and `Hash::check` | `count=1`, `name=Admin`, `hash_ok=yes`, `total_users=1` — second run created no duplicate |
| Login page serves | `php artisan serve` in the container + `curl http://127.0.0.1:8000/admin/login` | `HTTP=200`, `<title>Login - Laravel</title>`, Filament `v5.8.4.0` CSS/JS and Livewire scripts present in the HTML |
| Code style | `vendor/bin/pint --dirty --test` | `PASS` — 4 files, exit 0 |
| Test suite | `php artisan test` | `2 passed` (2 assertions), exit 0 |

The `pf-serve` container was removed after the check; only `mysql` and `adminer` remain running.
Environment quirk worth remembering: `tinker --execute` inside the container needs `HOME=/tmp`,
otherwise psysh fails with `Writing to directory /.config/psysh is not allowed`.

## Finding 1 remediation evidence (2026-09-23)

| Check | Command | Observed |
|---|---|---|
| FK changes applied | 7 `ALTER TABLE` statements (drop 3 FKs, modify 1 column, re-add 3 FKs) | `ALTER_EXIT=0` |
| New delete rules | `information_schema.REFERENTIAL_CONSTRAINTS` | `fk_transactions_account` → `RESTRICT`, `fk_transactions_category` → `SET NULL`, `fk_budgets_category` → `RESTRICT`; the four `fk_*_user` still `CASCADE`; `fk_categories_parent` still `SET NULL` |
| Column nullability | `information_schema.COLUMNS` on `transactions` | `category_id` → `IS_NULLABLE = YES` (only column that changed) |
| T1: account with transaction cannot be hard-deleted | `DELETE FROM accounts WHERE name='__FK_TEST_ACC'` | `ERROR 1451 … ON DELETE RESTRICT`, exit 1; account **and** transaction both still present afterwards |
| T2: category without budgets detaches its transactions | `DELETE FROM categories WHERE name='__FK_TEST_CAT_A'` | exit 0; category gone, **transaction survived with `category_id = NULL`** |
| T3: category with budgets cannot be hard-deleted | `DELETE FROM categories WHERE name='__FK_TEST_CAT_B'` | `ERROR 1451 … ON DELETE RESTRICT`, exit 1; category and budget both still present |
| Cleanup | explicit `DELETE`s of the `__FK_TEST_*` marker rows | `users=1, accounts=0, categories=0, transactions=0, budgets=0` |
| Script updated | `database/schema/01-personal-finances.sql` | header documents the semantic change (D19); `transactions.category_id` nullable; the three FK lines now `RESTRICT`/`SET NULL`/`RESTRICT`; `budgets.category_id` stays `NOT NULL`; `fk_*_user` untouched |
| Fresh import matches live | create `pf_scratch_fkcheck`, import updated script, `diff` sorted `(table, constraint, rule)` against live | import exit 0, **`DIFF_EXIT=0`** (all 8 rules identical), scratch `category_id` nullable |
| Scratch removed | `DROP DATABASE pf_scratch_fkcheck` | exit 0; `SHOW DATABASES` → only `personal_finances` + MySQL system schemas |

Test rows were created with `__FK_TEST_*` markers and explicit values in otherwise-empty tables,
then deleted in the same session — domain tables were verified back at 0 rows (the `users` admin
row untouched). No application code changed; `pint`/tests were not re-run for DDL-only work (the
suite runs on in-memory sqlite and never sees these tables).

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

### D16: panel stays at Filament's default `/admin`, unrestricted by email
- **Context:** step 4 had to pick a panel path and whether to gate access to one email/role.
- **Options considered:** default `/admin` vs a custom path; `canAccessPanel()` restriction vs open to
  any authenticated user.
- **Decision:** `/admin` (Filament's default, `->login()` enabled), no email/role restriction yet —
  the application currently has exactly one user (the seeded admin), so a restriction would be
  dead logic until a second kind of user exists.
- **Reason:** the restriction becomes a real requirement the moment another user is created; adding it
  now would guess at a policy (which email? which role?) nobody has defined.
- **Reversibility:** easy — one method on `AdminPanelProvider`.

### D17: admin user via `AdminUserSeeder` + `config/filament-admin.php`, not `make:filament-user`
- **Context:** `php artisan make:filament-user` is interactive and puts the password in shell history.
- **Options considered:** pipe answers into `make:filament-user`; a seeder reading `env()` directly;
  a seeder reading env through a config file.
- **Decision:** `database/seeders/AdminUserSeeder.php` + `config/filament-admin.php` exposing
  `FILAMENT_ADMIN_NAME` / `FILAMENT_ADMIN_EMAIL` / `FILAMENT_ADMIN_PASSWORD`; the seeder fails
  explicitly (naming the missing variables) if any is absent, and is idempotent by email.
- **Reason:** reproducible from a fresh clone, password never typed into history or code
  (`base/03` rule 2), and `env()` outside config files returns `null` under `config:cache` — the
  config file is the stack's standard loading path.
- **Reversibility:** easy.

### D18: `.env.example` left untouched again (consistent with D12)
- **Context:** the new `FILAMENT_ADMIN_*` variables exist only in the untracked `.env`.
- **Decision:** no `.env.example` edit — the previous decision (D12) limited that file's changes to
  what was explicitly requested, and the pattern repeats. Consequence: a fresh clone copies
  `.env.example` and the seeder then fails with a message naming the three missing variables.
- **Reversibility:** easy; one line each in `.env.example` whenever it is wanted.

### D19: the three financial-history FKs stop cascading (finding 1)
- **Context:** finding 1 showed a hard `DELETE` on an account or category silently destroyed
  transaction history; `budgets` cascaded on `category_id` too. Eloquent's soft delete on
  `accounts`/`transactions` does not protect raw SQL, `forceDelete()`, or future admin actions.
- **Options considered:** keep `CASCADE` (status quo, data loss stays silent); translate the fix
  into different delete rules per FK; drop soft deletes and enforce policy only in application code
  (the domain tables are owned by an imported script, not migrations — application-only policy
  would not bind raw SQL either).
- **Decision:** `fk_transactions_account` → `RESTRICT` (the account row stays as the reason a
  transaction cannot be hard-deleted); `fk_transactions_category` → `SET NULL` with
  `transactions.category_id` made nullable (history survives uncategorized); `budgets.category_id`
  stays `NOT NULL` and `fk_budgets_category` → `RESTRICT` (`SET NULL` would produce category-less
  budgets and weaken `uq_user_category_period`, since MySQL UNIQUE allows repeated NULLs). Applied
  to the live database **and** to `database/schema/01-personal-finances.sql` so a fresh import
  matches (D13/D15's source-of-truth rule, with the semantic change recorded in the file header —
  the "no semantic changes" claim of D15 is now historical, not current).
- **Reason:** matches exactly what finding 1 proposed and what the person approved; keeps every
  write path (including raw SQL) safe, not just Eloquent's.
- **Out of scope then, resolved since:** the four `fk_*_user` cascades and the soft-delete policy
  inconsistency (finding 2). At the time, a user hard-delete still cascaded accounts → transactions,
  categories and budgets, and `fk_transactions_account` RESTRICT did not stop it — the user-level
  cascade deleted the transactions first via `fk_transactions_user`. **Resolved 2026-09-25 by D20 in
  `/plans/user-delete-policy.md`:** the four cascades became `RESTRICT` and `users` soft-deletes.
- **Reversibility:** easy — the original `CASCADE` lines are in git history and the constraints can
  be swapped back with the same `ALTER` pattern; costly only once real financial data exists.

## Findings raised for a decision (nothing changed in the script)

1. **`ON DELETE CASCADE` on financial history — RESOLVED 2026-09-23 (D19, subtasks 11–14).**
   `fk_transactions_account` is now `RESTRICT`, `fk_transactions_category` is `SET NULL`
   (`category_id` nullable) and `fk_budgets_category` is `RESTRICT`; verified live (functional
   delete tests) and via a scratch re-import (`DIFF_EXIT=0`). Superseded ALTER snippets from the
   original proposal:
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
2. **Soft-delete policy is inconsistent — RESOLVED 2026-09-25 (finding 2 closed by D20 in
   `/plans/user-delete-policy.md`).** `users` gained `deleted_at` (new migration) and `SoftDeletes`
   on `App\Models\User`; the four `fk_*_user` cascades became `RESTRICT`, so a hard `DELETE` on a
   user can no longer destroy accounts, transactions, categories or budgets — not even by raw SQL.
   The original text of the finding, kept as the historical record of what was wrong:
   > `accounts` and `transactions` have `deleted_at`; `categories` and `budgets` do not, and neither
   > does `users`. Combined with finding 1, deleting a user hard-cascaded accounts → transactions,
   > categories and budgets, and `App\Models\User` did not use the `SoftDeletes` trait, so nothing in
   > the application prevented it. A one-line policy decision (soft deletes for users/categories, or
   > `RESTRICT` wherever history hangs off a row) closes it.
3. **`status ENUM('completed','pending','cancelled')`.** Works and enforces values in the database, but
   every new status needs an `ALTER TABLE`, and Laravel/Filament are happier casting a `VARCHAR` to a PHP
   enum. A trade-off to keep or drop, not an error.
   **Resolved 2026-09-25 (D21 in `/plans/schema-findings-3-8.md`):** converted to
   `VARCHAR(20) NOT NULL DEFAULT 'completed'`, with `App\Enums\TransactionStatus` holding the list.
4. **`SET FOREIGN_KEY_CHECKS = 0` is unnecessary here.** The tables are created in dependency order and
   there are no cycles; it also removes protection if the script aborts midway for any other reason.
   **Resolved 2026-09-25 (D22):** both statements deleted; the scratch import succeeds without them.
5. **`month`/`year` have no range check.** `TINYINT UNSIGNED` accepts `0..255`, so `month = 13` is
   storable. Either a `CHECK` constraint or Filament-level validation (`min:1|max:12`), the latter
   belonging to step 4.
   **Resolved 2026-09-25 (D23):** `CHECK` constraints added — `chk_budgets_month` and
   `chk_budgets_year` — live and in the script.
6. **Sign convention for `amount` is undefined.** `transactions.amount` is `NOT NULL` with no `CHECK`; if
   income/expense is derived from `categories.type`, a negative amount can still be stored. Worth pinning
   down before the Filament form is generated.
   **Resolved 2026-09-25 (D24):** signed amounts documented (positive = income, negative = expense)
   plus `chk_transactions_amount_not_zero`.
7. **Naming:** the two commented lines at the top of the script say `personal_finance` (singular) while the
   container and `.env` use `personal_finances` (plural). They stay commented, and the header comment in
   `database/schema/01-personal-finances.sql` records the discrepancy.
   **Resolved 2026-09-25 (D25):** the commented lines now use the plural name and the header note was
   trimmed.
8. **No transfer concept.** Nothing models money moving between two accounts; today that would be two
   unlinked transactions. Not a defect — just the next schema decision whenever transfers are wanted.
   **Deferred 2026-09-25 (D26):** no schema change; the intended shape is recorded in
   `/plans/schema-findings-3-8.md`.

## Step 4 readiness → executed

All three points below were resolved during execution and are recorded as **D16** (path/restriction),
**D17** (seeder instead of interactive `make:filament-user`) and the evidence table at the top:

- `filament/filament` **5.8.4** requires `ext-intl`; the host PHP lacks it, so `composer require` and
  `php artisan filament:*` **did** run through `pf-php:8.4-dev` (which has `intl`), not the host.
- The admin user is a seeder (`database/seeders/AdminUserSeeder.php`) so it is reproducible and its
  password comes from the environment instead of shell history.
- Panel path: `/admin` (Filament's default); no email/role restriction yet — see D16.
