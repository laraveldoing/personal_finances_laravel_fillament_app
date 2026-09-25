# User delete policy: `fk_*_user` cascades and soft deletes (finding 2)

## Status
`complete` — option A chosen by the person and implemented/verified on 2026-09-25 (D20). Findings
3–8 of `/plans/schema-import-and-filament.md` remain open and are tracked separately.

## Context
Finding 2 of `/plans/schema-import-and-filament.md`, left open on purpose by D19. The four
user-owned foreign keys still cascade — `fk_accounts_user`, `fk_categories_user`,
`fk_transactions_user`, `fk_budgets_user` — so one hard `DELETE FROM users` destroys that user's
accounts, transactions, categories and budgets in a single statement. `fk_transactions_account`
RESTRICT does **not** save the history: `fk_transactions_user` deletes the transactions first.

What makes it dangerous is the inconsistency around it: `accounts` and `transactions` carry
`deleted_at`, while `categories`, `budgets` and `users` do not, and `App\Models\User` does not use
the `SoftDeletes` trait — so nothing in the application even reaches for a soft delete. There is no
delete path today (the `/admin` panel has no resources and the database holds one seeded admin),
which is exactly why this is the cheapest moment to decide. Doubly so because the domain schema is
script-owned (`database/schema/01-personal-finances.sql`), so a policy enforced only in application
code would not bind raw SQL — the same reasoning D19 used for the account/category FKs.

Facts read from disk on 2026-09-25, not assumed:

- `users` is created by the skeleton migration `0001_01_01_000000_create_users_table` (no
  `deleted_at`); the script's `users` block is an `IF NOT EXISTS` no-op. Adding a column to `users`
  is therefore a **new migration**, not an edit to the imported script.
- `categories.user_id` is nullable (system-wide categories), so `fk_categories_user` only bites for
  user-owned categories. `categories` has no unique constraint besides its keys.
- `budgets.category_id` is `NOT NULL` and participates in `uq_user_category_period` (D19).
- `AdminUserSeeder` is idempotent through `User::updateOrCreate(['email' => ...])`, i.e. it queries
  through Eloquent — relevant if `User` starts soft-deleting (see consequence notes below).
- Only `app/Models/User.php` exists; there is no model or Filament resource for the domain tables
  yet, so no application delete path has to be migrated as part of this task.

## The decision (subtask 1)

### Option A — soft-delete users + `RESTRICT` on the four `fk_*_user` (recommended)
- New migration adds `users.deleted_at`; `App\Models\User` gains `SoftDeletes`; the four FK
  constraints become `ON DELETE RESTRICT` live **and** in the script.
- Guarantee: even raw SQL or `forceDelete()` cannot destroy financial history; the supported
  operation becomes `$user->delete()` (soft).
- Cost: a hard purge stops being expressible as one statement — it needs a deliberate path (a
  command or service deleting in dependency order inside a transaction). Either build it here or
  record it as a known, deliberate gap ("no user is purged until that path exists").
- Consequence to handle in the same task: a trashed user is invisible to Eloquent's global scope,
  so `AdminUserSeeder` would try to `INSERT` and hit the unique index on `email` (soft deletes do
  not release it). The seeder needs `withTrashed()` handling, or the policy has to say that
  restoring is the way back.
- Reversibility: easy while the tables are empty; costly once real data exists.

### Option B — keep the four cascades, soft-delete users only
- New migration adds `users.deleted_at` + `SoftDeletes` on `App\Models\User`; the four FKs stay
  `CASCADE` and the script is untouched.
- Guarantee: the application never destroys history (no code path calls `forceDelete()` or raw
  `DELETE`), and the cascade becomes the mechanism a future purge routine would ride on.
- Trade-off: the cheapest option (one migration, one trait line), but the database still offers zero
  protection — the guarantee lives in application code, which D19 explicitly avoided relying on.
  `AdminUserSeeder` / login consequences of Option A apply identically here.
- Reversibility: easy.

### Option C — `RESTRICT` on the four FKs + `deleted_at` on `users`, `categories` and `budgets`
- Everything in A, plus one migration adding `deleted_at` to `categories` and `budgets`, so every
  domain table has the same soft-delete column and the policy is uniform instead of half-applied.
- Guarantee: strongest *and* internally consistent — finding 2's second half ("soft-delete policy is
  inconsistent") disappears rather than being documented.
- Cost: the largest schema change (3 new columns, 4 FK rewrites), and `categories`/`budgets` need
  the same decisions the tables already force elsewhere (a trashed category cannot be hard-deleted
  while a budget references it — `fk_budgets_category` is RESTRICT; a trashed budget still holds
  `uq_user_category_period`).
- Reversibility: easy while empty; costly later.

### Option D — change nothing now, document the policy
- No migration, no FK change. `docs/CHANGELOG.md` + this file record that users are never
  hard-deleted until there is a real multi-user requirement (today: one seeded admin, no delete UI).
- Guarantee: none at the database or application level —finding 2 stays open, deliberately.
- Trade-off: zero work now and no risk of redoing it; the cost is that the decision gets made later
  under time pressure, when a delete path already exists and data is real.
- Reversibility: n/a (nothing changes).

Recommendation: **A**. It is the only option that binds every write path (D19's standard), it is
what makes `users` consistent with the two tables that already soft-delete, and its one extra
piece of work — the purge path — is cheap to define now and expensive to retrofit later. Its open
edge (the seeder's unique-email clash on a trashed row) is a known, small, testable fix rather than
a design risk.

## Subtasks
- [x] 1. Person chooses A / B / C / D; record the reasoning, the consequences accepted and the
      status of the purge path as **D20** in this file → **A chosen** (2026-09-25)
- [x] 2. Only for A/B/C: add the `deleted_at` migration(s) (`users`; `categories` + `budgets` too for
      C) and the `SoftDeletes` trait; decide and implement how `AdminUserSeeder` (and, if it exists
      by then, the login path) treats a trashed user → migration
      `2026_09_25_000000_add_deleted_at_to_users_table`, `SoftDeletes` on `App\Models\User`, and the
      seeder restores a trashed admin through `withTrashed()` instead of colliding with the unique
      `email`
- [x] 3. Only for A/C: rewrite the four `fk_*_user` constraints to `ON DELETE RESTRICT` on the live
      database **and** in `database/schema/01-personal-finances.sql`, with the script header
      recording the new semantics (the D19 pattern) → applied live (`ALTER_RC=0`) and in the script,
      header plus inline `-- D20` notes
- [x] 4. Verify against the live database: `DELETE_RULE` per constraint in
      `information_schema.REFERENTIAL_CONSTRAINTS` matches the decision, and the functional delete
      tests of the chosen option behave as designed (refused with error 1451 for A/C; soft delete
      leaves the row reachable via `withTrashed()`); test rows removed afterwards → four `RESTRICT`;
      hard delete refused with **error 1451**; live Eloquent soft delete reported `trashed=yes`,
      `find_after_delete=null`, `with_trashed_count=1` with all four domain rows intact; test rows
      removed (domain tables back to 0)
- [x] 5. Verify a fresh import: scratch database + updated script, diff the
      `(table, constraint, delete_rule)` set against the live database (`DIFF_EXIT=0`), scratch
      dropped → `DIFF_EXIT=0`, `users.deleted_at` present in the scratch too, script re-imported
      cleanly (idempotent), scratch dropped and the temporary grant revoked
- [x] 6. Verify the PHP side: `php artisan test` and `vendor/bin/pint --dirty --test` exit 0; a
      trashed user cannot authenticate; the seeder behaves as decided in subtask 2 →
      `php artisan test` 5 passed / 10 assertions (3 new tests in `tests/Feature/UserSoftDeleteTest.php`),
      `vendor/bin/pint --dirty --test` PASS (4 files)
- [x] 7. Document: script header, `docs/CHANGELOG.md` entry, close this plan and its `_index.md`
      row; commit → all in the closing commit

## Success criteria

### Subtask 1: the policy is chosen
One-line check: this file records the chosen option as D20 with its accepted consequences, and
`/plans/_index.md` no longer lists the task as `blocked`.

### Subtask 2 (A/B/C): soft deletes work and stop authentication
```gherkin
Feature: Soft-deleting a user

  Scenario: A trashed user keeps its financial history
    Given a user with an account, a category, a transaction and one budget
    When the user is soft-deleted through Eloquent
    Then `users.deleted_at` is set for that row
    And the account, transaction and budget rows are still present and unchanged
    And authentication with that user's credentials fails

  Scenario: The seeder does not crash on a trashed user
    Given the seeded admin row is soft-deleted
    When `php artisan db:seed --class=AdminUserSeeder --force` runs again
    Then it exits 0 and the `users` count for that email is still 1
```

### Subtask 3 (A/C): the database refuses the destructive delete
```gherkin
Feature: User-owned foreign keys

  Scenario: Hard-deleting the user fails
    Given `fk_accounts_user`, `fk_categories_user`, `fk_transactions_user` and `fk_budgets_user`
      are `RESTRICT`
    And a user with an account, a category, a transaction and a budget
    When `DELETE FROM users WHERE id = ?` runs through the `mysql` client
    Then it fails with error 1451
    And the row counts of `accounts`, `categories`, `transactions` and `budgets` are unchanged
```

### Subtask 4: the live database matches the decision
One-line check: the `information_schema.REFERENTIAL_CONSTRAINTS` `DELETE_RULE` values equal the
decision for all eight constraints, and the domain tables are back to 0 rows after the tests.

### Subtask 5: a fresh import reproduces the same rules
```gherkin
Feature: Script reproduces the live constraints

  Scenario: Scratch import matches the live database
    Given an empty scratch database
    When `php artisan migrate` runs against it and the updated script is imported
    Then the `(table, constraint, delete_rule)` set is identical to the live database's
    And the diff exit code is 0
```

### Subtasks 6–7: the change is verified and documented
One-line check: `php artisan test` and `vendor/bin/pint --dirty --test` both exit 0, the script
header and `docs/CHANGELOG.md` describe the new semantics, this file and its `_index.md` row read
`complete`, and `git status --short` is clean after the commit.

## Decisions log

### D20: soft deletes plus `RESTRICT` on the four `fk_*_user` (option A)
- **Context:** finding 2 — one hard `DELETE FROM users` destroyed the user's accounts, transactions,
  categories and budgets through the four `fk_*_user` cascades, and the inconsistency around soft
  deletes (`accounts`/`transactions` had `deleted_at`, `categories`/`budgets`/`users` did not) left
  nothing to stop it: `fk_transactions_account` RESTRICT never got the chance, because
  `fk_transactions_user` deleted the transactions first.
- **Options considered:** A soft-delete users + `RESTRICT` on the four FKs; B keep the cascades,
  soft-delete users only; C A plus `deleted_at` on `categories`/`budgets`; D document only, no change.
- **Decision:** **A**, chosen by the person on 2026-09-25. The four constraints became `RESTRICT`
  live and in the script; `users.deleted_at` arrives through the migration
  `2026_09_25_000000_add_deleted_at_to_users_table` (not the script, whose `users` block is a no-op);
  `App\Models\User` uses `SoftDeletes`; `AdminUserSeeder` looks the admin up with `withTrashed()` and
  restores it, because a trashed row keeps its unique `email`.
- **Reason:** the only option that binds every write path, raw SQL included — D19's standard — and it
  makes `users` consistent with the two tables that already soft-delete. An explicit purge path is
  deliberately **not** built here: until it exists no user can be hard-deleted, which is the intended
  behaviour, and it is recorded as an open item in `docs/CHANGELOG.md`.
- **Reversibility:** easy while the tables are empty (the original `CASCADE` lines are in git
  history); costly once real financial data exists.

## Blockers / open questions
None. The policy question was answered on 2026-09-25 (A, D20) and the seeder's unique-email clash was
solved in subtask 2. Deliberately open rather than blocking: there is no explicit purge path yet.

## Documentation produced
- `plans/user-delete-policy.md` — this file, closed as the record of the decision.
- `docs/CHANGELOG.md` — 2026-09-25 entry for the policy change.
- `plans/schema-import-and-filament.md` — finding 2 marked resolved.
- `/tmp/pf_d20_*.sql` — throwaway verification SQL, intentionally outside the repository.
