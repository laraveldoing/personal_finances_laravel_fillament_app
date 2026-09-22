# Laravel 13 application bootstrap

## Status
`complete` (steps 1–2 of the request; steps 3–4 tracked as a pending row in `/plans/_index.md`)

## Context
The repository already holds verified local infrastructure — MySQL 8.4 + Adminer via
`docker-compose.yml` (see `mysql-docker-container.md`) — and this guidelines library, but no
application. The application is now being created: Laravel 13 at the repository root, connected to the
existing MySQL container.

Scope of this file is steps 1 and 2 of the request:
1. Create the Laravel project.
2. Configure `.env` so the application connects to the existing MySQL container.

The SQL schema import (step 3) and Filament + admin user (step 4) are **not** started here; they get
their own subtasks once steps 1–2 are reported as done.

Two constraints shape the approach, both verified rather than assumed:
- The repository root is **not empty** (guidelines library, `plans/`, `docs/`, `docker-compose.yml`),
  and `composer create-project` refuses a non-empty target: the project is created in a temporary
  directory and copied in, so existing files are preserved (copy without clobbering) and only the
  files the application must genuinely own — `.env` — are created fresh.
- The host PHP (8.4.15) lacks `pdo_mysql`, `intl`, `zip` and `bcmath`, so an artisan command that
  opens a database connection **cannot** be run with the host interpreter. Verification therefore runs
  it inside a `php:8.4-cli` container with `pdo_mysql` enabled, mounted on the workspace — the same
  path a future app container would use.

## Subtasks

- [x] 1. Write this plan and register it in `/plans/_index.md`
- [x] 2. Create the Laravel 13 skeleton in a temporary directory outside the repository
- [x] 3. Copy the skeleton into the repository root without clobbering existing files
- [x] 4. Create `.env` from the skeleton's `.env.example` and point it at the MySQL container
- [x] 5. Verify: framework boots, `APP_KEY` set, database connection and schema access work
- [x] 6. Report steps 1–2 with evidence; SQL import and Filament left for the next step

Checkboxes are checked only once the matching scenario below has actually run — see
`documentation/planning-log.md`.

## Success criteria

### Subtask 2: the skeleton is Laravel 13
```gherkin
Feature: Project creation

  Scenario: The framework reports its version
    Given the freshly created project in the temporary directory
    When `php artisan --version` runs
    Then it prints a `13.x` version

  Scenario: The skeleton is complete
    Given the project directory
    When its top level is listed
    Then `artisan`, `composer.json`, `app`, `bootstrap`, `config`, `database`, `public`,
      `resources`, `routes`, `storage`, `tests` and `vendor` are all present
```

### Subtask 3: nothing pre-existing is lost
```gherkin
Feature: Copying into a non-empty root

  Scenario: The application lands at the root
    Given the repository root after the copy
    When `artisan` and `composer.json` are checked for
    Then both exist at the root

  Scenario: Repository files survive the copy
    Given the files that were already there (`docker-compose.yml`, `plans/`, `docs/`, `base/`,
      `frameworks/`, `languages/`, `documentation/`, `README.md`, `MAINTAINING.md`)
    When `git status --short` runs
    Then none of them is reported as modified or deleted
```

### Subtask 4: the environment points at the container database
```gherkin
Feature: Database configuration

  Scenario: The values come from the running container
    Given the MySQL container published on `127.0.0.1:3306` with database `personal_finances`
    When `.env` is inspected
    Then it sets `DB_CONNECTION=mysql`, `DB_HOST=127.0.0.1`, `DB_PORT=3306`,
      `DB_DATABASE=personal_finances` and the `laravel` credentials
    And `.env` is still absent from `git status` (gitignored)

  Scenario: No other database is left selected
    Given the Laravel skeleton defaults to `DB_CONNECTION=sqlite`
    When the configuration is read back
    Then the sqlite line is commented out or replaced, so MySQL is what the app resolves
```

### Subtask 5: the connection actually works
```gherkin
Feature: Verified connection

  Scenario: Laravel opens the connection itself
    Given a PHP 8.4 container with `pdo_mysql`, mounted on the workspace
    When `php artisan db:show` (or an equivalent artisan command that queries the server) runs
    Then it exits 0 and reports the MySQL `8.4.x` server, host `127.0.0.1`, database `personal_finances`

  Scenario: An application key exists
    Given `.env`
    When its `APP_KEY` line is inspected
    Then it is non-empty and prefixed `base64:`
```

## Verification evidence (2026-09-22)

| Check | Command | Observed |
|---|---|---|
| Skeleton version in the temp dir | `php artisan --version` | `Laravel Framework 13.33.0` |
| Skeleton version at the repository root | `php artisan --version` | `Laravel Framework 13.33.0` |
| Skeleton installed | `composer create-project` output | `laravel/laravel (v13.10.1)`, `laravel/framework (v13.33.0)`, `APP_KEY` set |
| Pre-existing files untouched | `git status --short -- docker-compose.yml plans docs base frameworks languages documentation README.md MAINTAINING.md .gitignore` | only this task's own `plans/` entries — no modification or deletion |
| `.gitignore` / `README.md` not clobbered | `rsync -a --ignore-existing` plus root listing | both kept their repository versions |
| `.env` points at the container | `grep '^DB_' .env` | `mysql` / `127.0.0.1` / `3306` / `personal_finances` / `laravel` / `password` |
| `.env` is still gitignored | `git check-ignore -v .env` | `.gitignore:19:.env` |
| **Laravel opens the connection itself** | `php artisan db:show` (in `pf-php:8.4-dev`, `--network host`) | server `8.4.11`, connection `mysql`, database `personal_finances`, host `127.0.0.1`, port `3306`, username `laravel`, open connections `1`, tables `0` |
| No `root`-owned files left behind | `find . -user root` (vendor pruned) | empty — the verification container ran as uid/gid 1000 |
| `database/database.sqlite` not carried over | `ls database/` | only `.gitignore`, `factories/`, `migrations/`, `seeders/` |

`Tables: 0` confirms the database is still empty, which is what step 3 (SQL schema import) expects.

## Decisions log

### D10: scaffold created in `/tmp` and copied in without clobbering
- **Context:** `composer create-project` refuses a non-empty target, and the repository root holds the
  guidelines library, `plans/`, `docs/` and `docker-compose.yml`.
- **Options considered:** move the guidelines library to `.ai/guidelines/` and scaffold in place
  (relocates files nobody asked to move); scaffold into a subdirectory (the request puts the project at
  the root); scaffold elsewhere and copy in.
- **Decision:** `composer create-project "laravel/laravel:^13.0" /tmp/laravel13-skeleton`, then
  `rsync -a --ignore-existing` into the root.
- **Reason:** the application lands at the root as requested, and `--ignore-existing` guarantees the
  pre-existing `.gitignore`, `README.md` and the whole guidelines library survive untouched.
- **Reversibility:** easy (only new files were added; nothing was overwritten).

### D11: verification runs in a local, non-committed PHP image
- **Context:** the host PHP (8.4.15) has no `pdo_mysql` (`PDO::getAvailableDrivers()` → `sqlite` only),
  so no artisan command can open the MySQL connection with the host interpreter. `composer:2` and
  `php:8.4-cli` were checked too and neither ships `pdo_mysql`.
- **Options considered:** compile the extension into the host PHP (invasive and unrequested);
  `--ignore-platform-reqs` (proves nothing — the missing extension *is* the runtime driver); treat the
  `mysql` client as a proxy for Laravel (weaker evidence than the real path); build a small local image.
- **Decision:** built `pf-php:8.4-dev` from `/tmp/pf-php-dev.Dockerfile` (`php:8.4-cli` +
  `pdo_mysql intl bcmath zip` + Composer), run as `--user 1000:1000 --network host` on the workspace.
- **Reason:** it exercises Laravel's own connection path, and uid 1000 keeps `root`-owned files out of
  the repository (verified). The Dockerfile stays outside the repository on purpose: promoting it into
  the repo is the separate "application container" task from `D9`.
- **Reversibility:** easy (delete the image whenever a real app container replaces it).

### D12: `database.sqlite` excluded, `.env.example` left alone
- **Context:** the skeleton defaults to `DB_CONNECTION=sqlite` and its post-create script creates and
  migrates `database/database.sqlite`.
- **Options considered:** carry the sqlite file over (dead weight plus a second, silently diverging
  database); delete it after copying; never copy it at all.
- **Decision:** excluded with `rsync --exclude 'database/database.sqlite'`. `.env.example` was **not**
  modified: the request named `.env`, and the tracked template is a separate, user-owned file.
- **Reason:** exactly one database, the one the container runs; nothing for a future migration to run
  against by accident. The template still advertises sqlite — see "Next".
- **Reversibility:** easy.

## Next (not started, tracked in `/plans/_index.md`)

Steps 3 and 4 of the request, deliberately not begun:

**Facts read from the application on disk (2026-09-22), which step 3 has to accommodate:**
- The skeleton's three migrations create **8 tables**: `users`, `password_reset_tokens` and `sessions`
  (`0001_01_01_000000`), `cache` + `cache_locks` (`...000001`), `jobs` + `job_batches` + `failed_jobs`
  (`...000002`). The schema script introduces a second definition of `users`, which is the clash.
- `.env` wires `SESSION_DRIVER=database`, `CACHE_STORE=database` and `QUEUE_CONNECTION=database`, so the
  `sessions`, `cache`/`cache_locks` and `jobs` family are not optional decoration — dropping them breaks
  sessions and the queue.
- `App\Models\User` expects `id`, `name`, `email` (unique), `email_verified_at`, `password`,
  `remember_token` and timestamps, with `password` cast to `hashed`. A script whose `users` table differs
  (no `remember_token`, split name columns, extra required columns) needs the model adapted, not just the
  import.
- Laravel 13 declares `Fillable`/`Hidden` as **PHP attributes** on the model (`#[Fillable([...])]`)
  rather than `protected $fillable`/`$hidden` properties — relevant when wiring Filament resources.
- Unresolved until the script is in hand: integer vs `DECIMAL` money columns, foreign keys with explicit
  `ON DELETE`, and indexes on date columns.

- **Step 3 — SQL schema import.** Needs the SQL script (`users`, `accounts`, `categories`,
  `transactions`, `budgets`). Two things to settle then: how it coexists with the skeleton's own
  `0001_01_01_000000_create_users_table` migration (both define `users`), and whether it is applied with
  the `mysql` client (simplest, sidesteps Laravel migrations) or converted into migrations.
- **Step 4 — Filament + admin user.** `filament/filament` requires `ext-intl`, absent from the host PHP,
  so the install must run through `pf-php:8.4-dev` (or a real app container) rather than the host.
  `php artisan make:filament-user` additionally needs the schema from step 3.
- **Noticed while working, not fixed (scope rules):**
  - `.env.example` still says `DB_CONNECTION=sqlite` while the project runs MySQL.
  - The skeleton added `AGENTS.md` and `CLAUDE.md`; the repository had neither, so nothing was
    overwritten. This repository's guidelines library is meant to be copied into `.ai/guidelines/` for
    Laravel Boost, and `base/03-safety-and-scope.md` forbids rewriting agent-instruction files
    unprompted — so they are left exactly as shipped, pending a decision.
  - `.gitignore` gained `/.phpunit.cache` (Laravel 13's own template ignores it, the repository's older
    file did not), checked before the first commit of PHPUnit's cache directory. `/.vscode` was
    deliberately **not** added, because this repository tracks `.vscode/launch.json`.

## Documentation produced

- `plans/laravel-app-bootstrap.md` — this file.
- `docs/CHANGELOG.md` — entry for the bootstrap.
- `/tmp/pf-php-dev.Dockerfile` — throwaway verification tooling, intentionally **outside** the
  repository and therefore not part of its documentation.
