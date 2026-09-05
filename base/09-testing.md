# Testing

Complements `02-code-standards.md` rule 8 (tests as part of "done" for sensitive logic) and
`04-verification-and-debugging.md` (tests as the concrete check behind "give every change a way
to fail"). This file is the standard those two assume: what to test, how, and what not to do to
make a suite pass.

1. **Match test type to what's being verified.** Unit tests for logic that doesn't cross a
   process/network/DB boundary — fast, no real I/O. Integration tests for anything that does —
   a repository hitting a real (test) database, a client calling a real (sandboxed) external
   service. Don't unit-test with everything mocked when the actual risk is in the integration
   itself (a query that's syntactically fine but returns the wrong rows); that gives false
   confidence, not coverage.

2. **Coverage follows risk, not a percentage target.** No blanket "80% coverage" rule. Mandatory:
   payments, auth, permissions, and any financial/security-sensitive path
   (`02-code-standards.md` rule 8) — happy path plus at least one failure/edge case. Expected:
   business logic with real branching. Optional: thin glue code, trivial getters/setters,
   framework boilerplate. Chasing a coverage number produces tests that assert nothing
   meaningful just to touch a line — see rule 6.

3. **Fixtures and mocks represent something real.** A mock stands in for a dependency that's
   slow, external, or non-deterministic (network calls, clocks, random IDs) — not for logic that
   could just run for real in a test environment. A fixture reflects data shaped like production
   data, including the messy edges (nulls, empty collections, boundary values), not just the
   happy-path shape that's convenient to construct. A test suite built entirely on idealized
   fixtures will pass while the same code fails on the first real row it sees.

4. **One behavior per test, named after that behavior.** A test name should describe the
   scenario and expected outcome (`rejects_transfer_when_balance_is_insufficient`), not the
   method under test (`test_transfer`). If a test needs "and" in its description to cover what
   it checks, it's covering more than one behavior — split it. This is what makes a failing test
   informative on its own, without reading the test body.

5. **A red test before the fix, when debugging.** Per `04-verification-and-debugging.md` rule 7,
   debugging is a search: when fixing a reported bug, first write a test that reproduces it and
   confirm it fails, then fix the code and confirm the same test passes. This is what proves the
   fix addressed the actual reported behavior, not a guess at it.

6. **Never make a test pass by weakening it — this extends to authoring, not just editing.**
   `04-verification-and-debugging.md` rule 4 already forbids loosening an existing test to get it
   green. The same applies when writing a new test: don't assert something trivially true
   (`expect(result).toBeDefined()` for a function that always returns something), don't catch and
   swallow the exception the test exists to check for, and don't assert against whatever the
   implementation currently outputs instead of against the actual requirement.

7. **Flaky tests get fixed or removed, never retried into silence.** A test that fails
   intermittently is signaling something real — a race condition, a shared-state leak between
   tests, an unmocked clock or network call — not a CI hiccup. Don't add a retry wrapper or
   `--no-fail` flag to make it stop blocking the build. If the root cause genuinely can't be
   found in reasonable time, skip the test explicitly with a comment stating why and a reference
   to a tracked follow-up (`documentation/planning-log.md`), not a silent retry loop.

8. **Test error paths as deliberately as success paths.** For any function that can fail (invalid
   input, a dependency being down, a permission check), there should be a test asserting *how* it
   fails — the right exception type, the right error code, the right partial-state behavior — not
   just that the happy path returns the right value.

9. **Snapshot tests need a human-reviewed baseline, not an auto-accepted one.** If the stack uses
   snapshot testing (UI, serialized output), a snapshot is only meaningful the first time it was
   reviewed by a person as correct. Regenerating a snapshot to match new output is equivalent to
   editing an assertion — it needs the same justification as rule 6, not a blind
   `--update-snapshots` run.
