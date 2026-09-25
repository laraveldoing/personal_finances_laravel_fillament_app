# Changelog

## [2026-09-21]

### MySQL database container for local development
- **Modules affected:** none in the application yet — adds root-level local infrastructure.
- **Implementation:** new `docker-compose.yml` with a single `mysql` service (`mysql:8.4`, named
  `mysql-data` volume, `personal-finances` bridge network, `mysqladmin ping` healthcheck with a 30 s
  `start_period`, host port published as `127.0.0.1:${FORWARD_DB_PORT:-3306}`). Credentials and
  database name are read from the standard Laravel `DB_*` variables, with development-only
  fallbacks so the stack starts before the app is scaffolded. No `.env`/`.env.example` was created
  by this change: the Laravel scaffold owns those files.
- **Technical decisions:** MySQL 8.4 (supported LTS; 8.0 reached EOL on 2026-04-30, 9.7 rejected as
  unnecessary for this stack); database-only stack, the app keeps running on the host; the port is
  bound to loopback to avoid exposing the development database; the healthcheck reads the password
  from the container environment instead of interpolating it into the compose config. Full reasoning
  in `/plans/mysql-docker-container.md`.
- **Open items:** the repository still contains no Laravel application; scaffolding it (and deciding
  whether it should also run in Docker) is tracked in `/plans/_index.md`.

### Adminer web UI for the development database
- **Modules affected:** none in the application yet — extends the local infrastructure.
- **Implementation:** new `adminer` service (`adminer:6`, resolved to 6.0.1) in `docker-compose.yml`.
  Its PHP server is overridden to bind `127.0.0.1:${FORWARD_ADMINER_PORT:-8081}` and the service runs
  with host networking so it reaches the database through the published loopback port. It stores no
  database credentials — only `ADMINER_DEFAULT_SERVER=127.0.0.1`, which pre-fills the login form.
- **Technical decisions:** Adminer chosen over phpMyAdmin (43.7 MB vs 196.6 MB compressed). Host
  networking was forced by an environment limitation, not preference: on this machine a container
  cannot reach another container on **any** user-defined bridge (the Compose network, a fresh test
  network, and one created with `enable_icc=true` all timed out, with DNS resolving correctly), while
  the legacy `docker0` bridge and host → published port both work. The idiomatic bridge form is
  documented in the file for machines without the limitation. Reasoning in
  `/plans/mysql-docker-container.md` (D7, D8).
- **Verified:** login page `200` at `http://127.0.0.1:8081` bound to loopback; a real `mysqli`
  connection from inside the Adminer container reports `8.4.11` / `personal_finances`; a full UI
  login (CSRF token + cookie) reaches the database page. The database was left untouched (read-only
  checks).

## [2026-09-22]

### Laravel 13 application bootstrapped and connected to the container database
- **Modules affected:** the repository gains an application (`app/`, `bootstrap/`, `config/`,
  `database/`, `public/`, `resources/`, `routes/`, `storage/`, `tests/`, `artisan`, Composer manifests).
  Local infrastructure is unchanged.
- **Implementation:** `composer create-project "laravel/laravel:^13.0"` (resolved to v13.10.1, framework
  v13.33.0) in a temporary directory, then copied into the repository root with
  `rsync -a --ignore-existing`, so the guidelines library, `docker-compose.yml`, `README.md` and the
  existing `.gitignore` were preserved. `.env` was configured for the container database:
  `DB_CONNECTION=mysql`, `DB_HOST=127.0.0.1`, `DB_PORT=3306`, `DB_DATABASE=personal_finances`,
  `DB_USERNAME=laravel`, plus the development password `docker-compose.yml` already documents.
  `database/database.sqlite` was deliberately **not** carried over.
- **Technical decisions:** scaffold-then-copy because the root was not empty (D10); verification through
  a local, non-committed `pf-php:8.4-dev` image running as uid 1000, because host PHP has no
  `pdo_mysql` (D11); `.env.example` left untouched, as the request named `.env` only (D12).
- **Verified:** `php artisan db:show` reports MySQL `8.4.11`, connection `mysql`, database
  `personal_finances`, host `127.0.0.1`, port `3306`, user `laravel`, 1 open connection and 0 tables —
  the database is empty and ready for the schema import. `php artisan --version` reports
  `Laravel Framework 13.33.0` from the repository root. Evidence tables in
  `/plans/laravel-app-bootstrap.md`.
- **Open items:** SQL schema import and the Filament panel (steps 3–4 of the request) are not started;
  tracked as a `pending` row in `/plans/_index.md`.

## [2026-09-23]

### Filament admin panel and reproducible admin user (step 4)
- **Modules affected:** `composer.json`/`composer.lock` (+33 packages), `app/Providers/Filament/`
  (new `AdminPanelProvider`), `bootstrap/providers.php` (provider registered), `config/
  filament-admin.php` (new), `database/seeders/AdminUserSeeder.php` (new), `.env` (3 untracked
  `FILAMENT_ADMIN_*` dev variables), `.gitignore` (published Filament assets ignored).
- **Implementation:** `filament/filament` **v5.8.4** (with Livewire v4.4.6) installed via Composer
  **inside the `pf-php:8.4-dev` verification image** — host PHP 8.5.1 still lacks `ext-intl`.
  `php artisan filament:install --panels` created the default `AdminPanelProvider` at `/admin`
  (login enabled) and registered it in `bootstrap/providers.php`; its published assets live under
  `public/{js,css,fonts}/filament` and are git-ignored. The admin user is created by
  `AdminUserSeeder`, idempotent by email, reading `FILAMENT_ADMIN_NAME`/`FILAMENT_ADMIN_EMAIL`/
  `FILAMENT_ADMIN_PASSWORD` through the new `config/filament-admin.php` and failing with the names
  of any missing variables.
- **Technical decisions:** default `/admin` path with no email/role restriction until a second user
  type exists (D16); seeder + config file instead of interactive `make:filament-user` so the password
  comes from the environment and is reproducible (D17); `.env.example` left untouched again, so a
  fresh clone surfaces the three variables through the seeder's explicit error (D18). Full reasoning
  in `/plans/schema-import-and-filament.md`.
- **Verified:** `composer require` exit 0; `route:list --path=admin` shows `admin`, `admin/login`,
  `admin/logout`; seeder run twice → `count=1`, `hash_ok=yes`, `total_users=1`; `GET /admin/login`
  returns `200` with Filament 5.8.4 assets and Livewire scripts; `pint --dirty --test` PASS (4
  files); `php artisan test` 2 passed. Evidence table in `/plans/schema-import-and-filament.md`.
- **Open items:** the step-3 schema findings still await a decision (first: `ON DELETE CASCADE` on
  financial history); Laravel Boost is still not installed (`AGENTS.md` untouched — installing it
  regenerates that file, which requires explicit approval).

### Financial-history FKs stop cascading (finding 1 remediation)
- **Modules affected:** `database/schema/01-personal-finances.sql` (3 FK definitions +
  `transactions.category_id` nullability + header) and the live `personal_finances` database
  (same 3 constraints via `ALTER TABLE`). No application code.
- **Implementation:** `fk_transactions_account` `CASCADE` → `RESTRICT`; `fk_transactions_category`
  `CASCADE` → `SET NULL` (column made nullable); `fk_budgets_category` `CASCADE` → `RESTRICT`
  (column stays `NOT NULL`). The four `fk_*_user` cascades and `fk_categories_parent` are
  untouched.
- **Technical decisions:** per-FK rules instead of a blanket change (D19): accounts are *required*
  by history so deletes are refused; categories are *optional* so history detaches; budgets keep
  `category_id` `NOT NULL` because `SET NULL` would create category-less budgets and weaken
  `uq_user_category_period` (MySQL UNIQUE permits repeated NULLs). The script header now records
  the semantic change — D15's "no semantic changes" claim is explicitly historical. Reasoning and
  full evidence in `/plans/schema-import-and-filament.md`.
- **Verified:** functional tests on the live DB — hard-delete of an account with a transaction and
  of a category with a budget both fail with error 1451 (RESTRICT), hard-delete of a category
  without budgets succeeds and the transaction survives with `category_id = NULL`; test rows
  cleaned (domain tables back to 0, `users` untouched). Fresh import of the updated script into a
  scratch database produced an identical `(table, constraint, delete_rule)` set (`DIFF_EXIT=0`);
  scratch dropped.
- **Open items:** findings 2–8 unchanged — the `fk_*_user` cascades mean a user hard-delete still
  destroys history (finding 2, needs a policy decision); enum-vs-varchar status, `month`/`year`
  range checks, `amount` sign convention and the missing transfer concept remain open.

## [2026-09-25]

### User delete policy: soft deletes plus `RESTRICT` on the four user foreign keys (finding 2)
- **Modules affected:** `database/schema/01-personal-finances.sql` (4 FK definitions, header and a
  note on `users`), a new migration `2026_09_25_000000_add_deleted_at_to_users_table`,
  `app/Models/User.php` (`SoftDeletes`), `database/seeders/AdminUserSeeder.php` (trashed-row
  handling), `tests/Feature/UserSoftDeleteTest.php` (new) and the live `personal_finances` database
  (the same 4 constraints via `ALTER TABLE`).
- **Implementation:** `fk_accounts_user`, `fk_categories_user`, `fk_transactions_user` and
  `fk_budgets_user` changed from `ON DELETE CASCADE` to `ON DELETE RESTRICT`. `users` gained
  `deleted_at` through a migration rather than the script (`users` belongs to the framework's
  migrations; the script's block stays an `IF NOT EXISTS` no-op), and `App\Models\User` now soft
  deletes. `AdminUserSeeder` looks the admin up with `withTrashed()` and restores a trashed row
  instead of colliding with the unique index on `email`.
- **Technical decisions:** option A of `/plans/user-delete-policy.md`, recorded there as **D20** —
  the only rule that binds every write path (raw SQL included), matching D19's reasoning, at the
  cost of one migration and one extra piece of work. Options B (keep the cascades, soft-delete
  users only) and C (uniform soft deletes on `categories`/`budgets` as well) were rejected as
  weaker or inconsistent for the same or more work; D (document only) was rejected because the
  delete paths are about to be built. An explicit purge path is a deliberate, documented gap: until
  it exists, no user is hard-deleted, which is the intended behaviour.
- **Verified:** live `information_schema.REFERENTIAL_CONSTRAINTS` reports `RESTRICT` for the four
  `fk_*_user` (D19's three unchanged); `DELETE FROM users` for a user holding an account, category,
  transaction and budget fails with **error 1451** and all four domain tables keep their rows; an
  Eloquent soft delete on the live database reports `trashed=yes`, `find_after_delete=null`,
  `with_trashed_count=1` with the history intact; a scratch database (created with `root` inside
  the container, temporary grant, both revoked and dropped afterwards) migrated and imported the
  updated script to an identical `(table, constraint, delete_rule)` set (`DIFF_EXIT=0`), the script
  re-importing cleanly; `php artisan test` 5 passed / 10 assertions (3 new tests);
  `vendor/bin/pint --dirty --test` PASS (4 files); test rows removed (domain tables back to 0 rows).
- **Open items:** findings 3–8 of `/plans/schema-import-and-filament.md` remain (enum-vs-varchar
  `status`, `month`/`year` range checks, `amount` sign convention, the missing transfer concept,
  `SET FOREIGN_KEY_CHECKS = 0`, the singular/plural database name). No explicit purge path exists —
  by decision, not by oversight.

