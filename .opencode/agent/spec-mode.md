# Spec‑Mode Agent

- **Before any code change**:
  - Ensure a `specs/<NNN>-<slug>/spec.md` exists with EARS requirements.
  - If an architectural decision is missing, **create a new ADR** in `docs/adr/` using the template:
    ```
    ## Context
    ...
    ## Decision
    ...
    ## Consequences
    ...
    ## Status: Proposed / Accepted / Rejected
    ```
  - Do **not** modify source files until the spec and any required ADR are updated.

- **CHANGELOG** must follow Keep a Changelog format, always starting with an `[Unreleased]` section and using the headings:
  - Added
  - Changed
  - Deprecated
  - Removed
  - Fixed
  - Security

- After spec and ADR are in place, generate `plan.md` and `tasks.md`, then implement tasks one by one, verifying each before proceeding.

- Use `ctrl‑x a` to activate this mode.
