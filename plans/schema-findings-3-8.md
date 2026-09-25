# Remaining schema findings (3–8): status, FK checks, ranges, amount sign, naming, transfers

## Status
`complete` — all six recommendations accepted by the person on 2026-09-25; findings 3–7 implemented
and verified (D21–D25) and finding 8 deferred with its shape recorded (D26).

## Context
Findings 3–8 of `/plans/schema-import-and-filament.md`, the ones left after finding 1 (D19) and
finding 2 (D20). None of them is a live bug: they are decisions about the domain schema that get
cheap while the tables are empty and no model or Filament resource exists yet — which is exactly the
current state (only `app/Models/User.php` exists). Findings 3, 5 and 6 in particular have to be
settled *before* the domain models and their Filament forms are written, or the forms encode a
convention nobody decided.

## Finding 3 — `status ENUM('completed','pending','cancelled')` vs `VARCHAR`
- **Current state:** `transactions.status` is a MySQL `ENUM` with three values, `NOT NULL DEFAULT
  'completed'`. It works and the database enforces membership.
- **Trade-off:** the `ENUM` makes every new status an `ALTER TABLE`, and Laravel/Filament are
  happier casting a `VARCHAR` through a PHP enum (`TransactionStatus`), which is also where labels
  and colours live for the panel.
- **Recommendation:** `VARCHAR(20)` + a PHP backed enum (`App\Enums\TransactionStatus`) cast on the
  model, plus the same values as the current three. The database stops being the list's home; the
  enum becomes the single source of truth. Nothing to migrate today (no rows).
- **Alternative:** keep the `ENUM` and accept the `ALTER` per new status.

## Finding 4 — `SET FOREIGN_KEY_CHECKS = 0` in the script
- **Current state:** the script disables FK checks for the whole run and re-enables them at the end.
- **Trade-off:** the tables are created in dependency order (`users` → `accounts` → `categories` →
  `transactions` → `budgets`) and there are no cycles, so the toggles are not needed; worse, they
  remove the failure signal if the script is applied out of order or aborts midway.
- **Recommendation:** delete both statements and verify a fresh import still succeeds — the scratch
  import of D20 already passes *with* them, so the check has to be repeated without them before
  claiming it.
- **Alternative:** keep them as insurance, documented as such.

## Finding 5 — `month` / `year` have no range check
- **Current state:** `budgets.month` is `TINYINT UNSIGNED` (0–255) and `year` is `SMALLINT
  UNSIGNED` (0–65535), so `month = 13` and `year = 0` are storable.
- **Trade-off:** a `CHECK` constraint binds raw SQL as well (the D19/D20 standard); Filament-level
  validation alone protects only the panel, and the panel does not exist yet.
- **Recommendation:** `CHECK` constraints — `month BETWEEN 1 AND 12`, `year BETWEEN 1900 AND 2999`
  — **plus** the same rules as form validation when the resource is built (belt and braces, cheap
  here). MySQL 8.4 enforces `CHECK` (8.0.16+).
- **Alternative:** application-only validation, which leaves the database permissive.

## Finding 6 — `amount` sign convention
- **Current state:** `transactions.amount` is `NOT NULL` with no `CHECK`, and `categories.type`
  (`income` / `expense`) exists alongside it. Nothing defines whether expenses are negative.
- **Trade-off:** deriving the sign from the category breaks now that `transactions.category_id` is
  nullable (D19) — an uncategorised transaction would have no direction. A signed amount is
  self-contained but can disagree with its category's type.
- **Recommendation:** signed amounts as the convention — positive = income, negative = expense,
  `CHECK (amount <> 0)` — documented in the script header; the form (later) asks for a positive
  figure plus an income/expense direction and stores the signed value. Category type stays a
  classification, not the source of the sign.
- **Alternative:** unsigned amounts plus a `direction` column (or a `transaction_type` column), which
  makes "amount matches its category" enforceable with a two-column rule but duplicates information.

## Finding 7 — singular `personal_finance` in the two commented lines
- **Current state:** the script's commented `CREATE DATABASE IF NOT EXISTS personal_finance` / `USE
  personal_finance;` say singular; the container, `.env` and the header say plural, and the header
  explains the discrepancy.
- **Trade-off:** leaving it costs nothing today (the lines stay commented) but is exactly the kind of
  near-miss a copy-paste resurrects later, creating a second, empty database.
- **Recommendation:** change both commented lines to `personal_finances` and trim the header note to
  just say the block is optional; nothing else follows from it.
- **Alternative:** leave both the lines and the explanatory note as the historical record.

## Finding 8 — no transfer concept
- **Current state:** nothing models money moving between two accounts; today that is two unlinked
  transactions, so per-account balances stay right while any report that reads transactions as
  income/expense counts both legs.
- **Trade-off:** it is a feature, not a defect, and building it now means designing UI and rules that
  nothing needs yet; ignoring it means the eventual design has to be retrofitted onto whatever the
  resources assume.
- **Recommendation:** **defer the implementation, record the shape** — a `transfers` table holding the
  shared metadata (`id`, `user_id`, `from_account_id`, `to_account_id`, `amount`, `transfer_date`,
  `description`, timestamps, `deleted_at`) plus a nullable `transfer_id` on `transactions` linking the
  two legs, so balances keep working from `transactions` alone and reports can exclude transfer legs
  with a predicate. No schema change and no code in this task.
- **Alternative:** decide and build it now, before the resources exist.

## Subtasks
- [x] 1. Person confirms the recommendations above, or picks the alternative for any finding; record
      each accepted decision as D21+ in this file → **all six accepted as recommended** (2026-09-25)
- [x] 2. Finding 3: `transactions.status` → `VARCHAR(20) NOT NULL DEFAULT 'completed'` in the script
      and live via `ALTER TABLE`, plus `App\Enums\TransactionStatus` (D21) → done, plus
      `tests/Unit/TransactionStatusTest.php` pinning the three values
- [x] 3. Finding 4: delete both `SET FOREIGN_KEY_CHECKS` statements from the script (D22) → done; the
      scratch import runs without them
- [x] 4. Finding 5: add the `month` / `year` `CHECK` constraints to the script and live (D23) → done
      (`chk_budgets_month`, `chk_budgets_year`)
- [x] 5. Finding 6: add `CHECK (amount <> 0)` and write the sign convention into the script header
      (D24) → done (`chk_transactions_amount_not_zero`)
- [x] 6. Finding 7: fix the two commented database lines to the plural name and trim the header note
      (D25) → done
- [x] 7. Verify live: `ALTER_RC=0`; the structure query reports `varchar(20)`, the three `CHECK`
      clauses and the eight foreign keys unchanged; `month = 13`, `month = 0`, `year = 1899` and
      `amount = 0` inserts refused with **error 3819** while `month = 12`, `amount = -12.34` and an
      omitted status (stored as `completed`) succeeded; test rows removed
- [x] 8. Verify a fresh import: scratch database (created with `root` inside the container, grant
      revoked and database dropped afterwards) — migrate `RC=0`, import `RC=0` **without the FK
      toggles**, re-import `RC=0`, structure diff against live `DIFF_EXIT=0`
- [x] 9. Verify the PHP side: `php artisan test` 7 passed / 15 assertions; `vendor/bin/pint --test` on
      the new files and `--dirty --test` both PASS
- [x] 10. Document: script header, `docs/CHANGELOG.md`, this plan and its `_index.md` row; commit →
      all in the closing commit

## Success criteria

### Subtask 2: the status column stops being an enum
```gherkin
Feature: Transaction status storage

  Scenario: The database stores and returns the three statuses
    Given `transactions.status` is `VARCHAR(20) NOT NULL DEFAULT 'completed'`
    When a row is inserted with `status = 'cancelled'` and another with no status
    Then both are stored and read back as `cancelled` and `completed`
```

### Subtask 4: the range checks reject impossible periods
```gherkin
Feature: Budget period ranges

  Scenario: An impossible month is refused
    Given `budgets` has `CHECK (month BETWEEN 1 AND 12)`
    When a row is inserted with `month = 13`
    Then MySQL refuses it with error 3819
    And inserting a valid month succeeds and is rolled back afterwards
```

### Subtask 5: the sign convention is enforced
```gherkin
Feature: Amount sign convention

  Scenario: A zero amount is refused
    Given `transactions` has `CHECK (amount <> 0)`
    When a row is inserted with `amount = 0`
    Then MySQL refuses it with error 3819
```

### Subtasks 3, 6, 7, 8: mechanical checks
One-line checks: `grep -c '^SET FOREIGN_KEY_CHECKS' database/schema/01-personal-finances.sql` returns
`0` — the word survives only in the header prose that records D22 (subtask 3); no singular
`personal_finance` remains in the script (subtask 6); the scratch structure diff against the live
database exits `0` (subtask 8).

### Subtasks 9–10: verified and documented
One-line check: `php artisan test` and `vendor/bin/pint --dirty --test` exit 0, the script header and
`docs/CHANGELOG.md` describe the settled conventions, this file and its `_index.md` row read
`complete`, and `git status --short` is clean after the commit.

## Decisions log

All six recommendations were accepted by the person on 2026-09-25 without changes; each entry below
is the decision that was actually implemented.

### D21: `transactions.status` is a `VARCHAR(20)`, the list lives in a PHP enum
- **Context:** the column was a MySQL `ENUM('completed','pending','cancelled')`; adding a status meant
  an `ALTER TABLE`, and Filament casts PHP enums more naturally.
- **Options considered:** keep the `ENUM`; or `VARCHAR(20)` with `App\Enums\TransactionStatus`.
- **Decision:** `VARCHAR(20) NOT NULL DEFAULT 'completed'` live and in the script, plus the backed enum
  and `tests/Unit/TransactionStatusTest.php` pinning the three stored values.
- **Reason:** one case to add instead of a migration, and the list stops being duplicated between
  schema and application. Accepted cost, verified rather than assumed: the database no longer rejects a
  status outside the list — inserting `'refunded'` succeeds, so the enum plus validation is what keeps
  it honest from here on.
- **Reversibility:** easy while the table is empty; the `ENUM` can be restored with the same `MODIFY`
  statement.

### D22: the two `SET FOREIGN_KEY_CHECKS` statements are gone
- **Context:** the script disabled FK checks for the whole run; nothing needed it.
- **Options considered:** keep them as insurance; or delete them.
- **Decision:** deleted both, and re-ran the scratch import to prove the creation order (`users` →
  `accounts` → `categories` → `transactions` → `budgets`) is enough.
- **Reason:** with checks on, a script applied in the wrong order fails loudly instead of creating
  references that only break later.
- **Reversibility:** easy.

### D23: range checks on the budget period
- **Context:** `month` (`TINYINT UNSIGNED`) accepted `13` and `year` accepted `0`.
- **Options considered:** `CHECK` constraints; or validation only in the Filament form.
- **Decision:** `chk_budgets_month` (`month BETWEEN 1 AND 12`) and `chk_budgets_year` (`year BETWEEN
  1900 AND 2999`), live and in the script; the same rules belong in the resource's validation when it
  is built.
- **Reason:** a `CHECK` binds raw SQL too, which is the standard D19 and D20 already set.
- **Reversibility:** easy (`ALTER TABLE ... DROP CHECK`).

### D24: `transactions.amount` carries the sign
- **Context:** nothing defined whether an expense is negative; `categories.type` exists beside it.
- **Options considered:** signed amounts; or unsigned amounts plus a direction column; or deriving the
  sign from the category.
- **Decision:** signed amounts (positive = income, negative = expense) with
  `chk_transactions_amount_not_zero`, and the convention written into the script header.
- **Reason:** `transactions.category_id` is nullable since D19, so an uncategorised transaction would
  have no direction if the sign came from the category. The category stays a classification; the
  transaction carries the direction. A form (later) asks for a positive figure plus a direction.
- **Reversibility:** easy while empty; changing it later means rewriting every amount.

### D25: the commented database lines use the plural name
- **Context:** the two commented `CREATE DATABASE` / `USE` lines said `personal_finance`, contradicting
  the live `personal_finances`.
- **Decision:** both lines now use the plural, and the header note about the discrepancy was trimmed.
- **Reason:** removes a copy-paste trap that would silently create a second, empty database.
- **Reversibility:** easy.

### D26: transfers are deferred, their shape is recorded
- **Context:** nothing models money moving between two accounts; today it is two unlinked
  transactions, which per-account balances tolerate but income/expense reports double-count.
- **Options considered:** build it now; or defer with the shape recorded.
- **Decision:** defer — no schema change, no code. Shape recorded here: a `transfers` table holding
  the shared metadata (`user_id`, `from_account_id`, `to_account_id`, `amount`, `transfer_date`,
  `description`, timestamps, `deleted_at`) plus a nullable `transfer_id` on `transactions` linking the
  two legs.
- **Reason:** it is a feature, not a defect, and the resources do not exist yet; recording the shape
  now is what stops the eventual design from being retrofitted onto assumptions.
- **Reversibility:** n/a (nothing was built).

## Blockers / open questions
None. All six decisions were answered on 2026-09-25; finding 8 is deferred by decision (D26) rather
than blocked.

## Documentation produced
- `plans/schema-findings-3-8.md` — this file, closed as the record of decisions D21–D26.
- `docs/CHANGELOG.md` — 2026-09-25 entry "Remaining schema findings settled (3–7) and transfers
  deferred (8)".
- `plans/schema-import-and-filament.md` — findings 3–8 marked resolved or deferred.
- `/tmp/pf_d21_*.sql`, `/tmp/pf_d23_*.sql` — throwaway verification SQL, intentionally outside the
  repository.

