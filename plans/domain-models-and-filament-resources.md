# Domain models and Filament resources (accounts, categories, transactions, budgets)

## Status
`blocked` — plan written, nothing implemented. The ownership scope (see "Blockers") is the one
decision that shapes every resource; everything else follows the schema as it stands.

## Context
The panel at `/admin` has existed since step 4 but exposes nothing: `app/Models/User.php` is the only
model in the application, and `accounts`, `categories`, `transactions` and `budgets` have no model, no
resource and no policy. The conventions the resources must encode were settled first on purpose — D19
(a delete never destroys history), D20 (soft deletes plus `RESTRICT` user FKs), D21 (`status` through
`App\Enums\TransactionStatus`), D23 (budget period ranges), D24 (signed amounts) — which is why this
work starts now and not earlier.

Facts read from disk on 2026-09-25, not assumed:
- Tables are InnoDB / `utf8mb4_unicode_ci`; `accounts` and `transactions` have `deleted_at`,
  `categories` and `budgets` do not (D20 deliberately left that policy open).
- `categories.user_id` is nullable (system-wide categories) with `parent_id` self-referencing;
  `fk_categories_parent` is `SET NULL`.
- `transactions.category_id` is nullable (D19), `budgets.category_id` is `NOT NULL` and participates
  in `uq_user_category_period`.
- `accounts.balance` is a stored `DECIMAL(12,2)` column, **not** derived from transactions.
- `transactions.amount` is signed (D24) and `status` is `VARCHAR(20)` cast through the enum (D21).
- Laravel 13 declares `Fillable`/`Hidden` as PHP attributes; Filament is v5.8.4 on Livewire v4.
- Composer and artisan run inside `pf-php:8.4-dev` (host PHP lacks `intl`/`pdo_mysql`); the panel's
  published assets are git-ignored.

## Scope
**In:** four Eloquent models (relationships, casts, the two soft deletes), four Filament resources
(list / create / edit, with validation mirroring the settled database rules), and panel navigation.
**Out:** dashboards, charts, reports, import/export, transfers (D26), the purge path (D20) and any
schema change — the resources follow the schema, they do not reinterpret it.

## Decisions to settle before implementing
1. **Ownership scope (the blocker).** Every resource filters by `auth()->user()` — plus the global
   categories (`user_id IS NULL`) for the category picker — and stamps `user_id` on create; or the
   panel is single-owner and lists/edits every row, leaving per-user scoping for later. With one
   seeded admin both behave identically today; what differs is the day a second user exists.
2. **`accounts.balance` (recommendation: keep it stored and editable).** It is a stored column, so
   editing it by hand can drift from the sum of its transactions. Recalculating it needs ledger rules
   that do not exist yet (transfers are deferred, D26), so the recommendation is to keep it as the
   schema has it and record the drift as a follow-up instead of inventing ledger logic inside a CRUD
   screen.
3. **Authorization (recommendation: no policies yet).** Filament policies only start mattering with
   more than one user type; today the panel is open to any authenticated user by decision D16. Adding
   policies belongs with the ownership scope above, not before it.

## Subtasks
- [ ] 1. Person settles the ownership scope (recorded as **D27** here)
- [ ] 2. `App\Models\Account` — `#[Fillable]`, `user()`, `transactions()`, `SoftDeletes`, casts
      (`is_active` boolean, `balance` decimal)
- [ ] 3. `App\Models\Category` — `user()`, `parent()`, `children()`, `transactions()`, `budgets()`
      (`parent_id` nullable, `user_id` nullable for system categories)
- [ ] 4. `App\Models\Transaction` — `user()`, `account()`, `category()`, `SoftDeletes`, casts
      (`amount` decimal, `transaction_date` date, `status` → `App\Enums\TransactionStatus`)
- [ ] 5. `App\Models\Budget` — `user()`, `category()`, casts (`amount` decimal, `month`/`year` int)
- [ ] 6. Four Filament resources whose validation mirrors what the schema now enforces: `month` 1–12,
      `year` 1900–2999, `amount` (transactions) non-zero and signed through an income/expense
      direction, `status` only from the enum, `category_id` required on budgets and optional on
      transactions, `type` from the documented values (`cash`, `bank`, `card`, `savings`;
      `income`, `expense`)
- [ ] 7. Model tests (sqlite, `RefreshDatabase`): relationships resolve and the two casts that matter
      (`status` → enum, `amount` → decimal string) behave
- [ ] 8. Resource tests: `ListRecords`, `CreateRecord` and a validation-rejection case per resource
      through Filament's testing helpers
- [ ] 9. Panel check over HTTP: `/admin` lists the four resources, a create form saves a row, and the
      form rejects `month = 13` and `amount = 0` before the database has to
- [ ] 10. Verify the database was not touched: the live structure query still matches the recorded
      output (`DIFF_EXIT=0`), no migration was added, and `php artisan test` plus
      `vendor/bin/pint --dirty --test` exit 0
- [ ] 11. Document: `docs/CHANGELOG.md`, this plan and its `_index.md` row; commit

## Success criteria

### Subtasks 2–5: the models speak the schema
```gherkin
Feature: Domain models

  Scenario: A user's history is reachable through relationships
    Given a user with one account, one category, one transaction and one budget
    When the account, category, transaction and budget are loaded through their models
    Then the transaction resolves its account and category
    And the budget resolves its category
    And the category resolves parent, children and transactions

  Scenario: The settled conventions are cast, not re-derived
    Given a transaction stored with `status = 'pending'` and `amount = -12.34`
    When it is read through the model
    Then `status` is `App\Enums\TransactionStatus::Pending`
    And `amount` compares equal to `-12.34` as a decimal string
```

### Subtask 8: the panel enforces the same rules as the database
```gherkin
Feature: Filament resources

  Scenario: A budget with an impossible month is refused by the form
    Given the panel's budget create form
    When it is submitted with `month = 13`
    Then the form reports a validation error and no row is stored

  Scenario: A valid transaction is stored through the panel
    Given the transaction create form
    When it is submitted with a positive amount, direction "expense" and a category
    Then a row is stored with the amount negated and `status = 'completed'`
```

### Subtasks 9–11: verified and documented
One-line checks: the panel check over HTTP returns a rendered list for each of the four resources;
the live structure query diff exits `0` and `git status` shows no migration; `php artisan test` and
`vendor/bin/pint --dirty --test` exit 0; `docs/CHANGELOG.md`, this file and `_index.md` describe the
result and `git status --short` is clean after the commit.

## Decisions log
Populated during execution (`base/08-planning.md` rule 4). Empty until subtask 1 resolves.

## Blockers / open questions
- **Ownership scope (subtask 1)** — per-user scoping versus a single-owner panel changes every query,
  every create form and whether policies are needed. Nothing is written before it is answered.
- Recommendations above for `accounts.balance` (stored, editable, drift recorded as a follow-up) and
  authorization (no policies yet) are proposals, and reversible either way.

## Documentation produced
- `plans/domain-models-and-filament-resources.md` — this file. Nothing else yet.
