# Planning Log — Format & Templates

Reference material for `base/08-planning.md`. That file says *when* to plan and what a plan must
guarantee; this file says what the files actually look like.

## Why `/plans` isn't "unsolicited documentation"

`changelog-and-docs.md` warns against creating standalone docs files unprompted — a `SETUP.md`
nobody asked for, an architecture writeup that goes stale. `/plans` files are a different kind of
artifact: they're working state for the task currently in progress, not a deliverable. They're
expected to exist for the duration of the task and either get folded into `CHANGELOG.md` (if the
task was significant) or left as a closed record (if someone might resume related work later) —
never left open-ended as prose nobody will maintain.

## Structure

```
/plans
  _index.md                   # Single source of truth for status across all tasks — replaces
                               # a separate TODO.md; see "Replacing TODO.md" below.
  <task-slug>.md               # One file per task, kebab-case, no dates in the name.
  <feature>/                   # Subfolder for a large feature split into multiple task files.
    _index.md
    <task-slug>.md
```

## `_index.md`

```markdown
# Plans Index

| Task | Slug | Status | Updated | Notes |
|---|---|---|---|---|
| Auth refresh token | `auth-refresh-token` | in-progress | 2026-08-20 | — |
| Postgres 16 migration | `pg16-migration` | pending | 2026-08-18 | blocked on infra decision |
```

Status values: `pending` / `in-progress` / `blocked` / `in-review` / `complete`.

Update this file whenever a task file is created or changes status — it's read, not
reconstructed from memory, whenever status is asked for (`08-planning.md` rule 6).

### Replacing `TODO.md`

Out-of-scope findings and deferred decisions — previously logged to `docs/TODO.md` per
`changelog-and-docs.md` — go in `_index.md`'s **Notes** column when they block a specific task, or
as a `pending` row of their own (with no code yet, just context) when they don't map to an
existing task file. This keeps one status surface instead of two files that can silently drift
apart. If a project's tooling still expects `docs/TODO.md`, that's a project-specific override to
state explicitly, not a reason to maintain both by default.

## `<task-slug>.md`

```markdown
# <Task name>

## Status
`pending` | `in-progress` | `blocked` | `in-review` | `complete`

## Context
3-5 lines: what's being asked and why. Should be enough for a future session — human or agent —
to resume without re-reading the conversation that produced it.

## Subtasks

- [ ] 1. <Subtask>
- [ ] 2. <Subtask>
  - [ ] 2.1 <Sub-subtask, if needed>

Checkbox state is the literal answer to "what's done and what's left" — see `08-planning.md`
rule 6. Don't check a box until its scenario below has actually passed.

## Success criteria

One Given/When/Then block per subtask with real logic. Purely mechanical subtasks (bump a
version string, rename a file) can use a one-line check instead of a full scenario.

### Subtask 1: <name>
```gherkin
Feature: <subtask name>

  Scenario: <main case>
    Given <precondition>
    When <action>
    Then <verifiable outcome>

  Scenario: <edge case, if relevant>
    Given <precondition>
    When <action>
    Then <verifiable outcome>
```

Keep to 1-3 scenarios per subtask. `Then` steps must be objectively checkable — by a test, a
command, or direct inspection of output — never a vague "the code should be better."

## Decisions log

Populated during execution, per `08-planning.md` rule 4 — not written in advance.

```markdown
### D<N>: <short title>
- **Context:** what forced this decision
- **Options considered:** one line each
- **Decision:** what was chosen
- **Reason:** 1-3 lines
- **Reversibility:** easy / costly / hard
```

Skip trivial decisions (variable names, formatting). A decision marked `hard` to reverse is also
an ADR candidate — see "ADRs" below.

## Blockers / open questions

Anything currently waiting on human input, per `08-planning.md` rule 5. Remove once resolved
— don't leave stale questions next to their answers.

## Documentation produced

Paths to any docs this task generated (see "Closing a task" below). No orphaned documentation:
if a doc was written, it's linked from here.

---

## Closing a task

When a task file moves to `complete`:

1. Every subtask is checked and its scenario has actually passed — evidence, not assertion
   (`04-verification-and-debugging.md` rule 2).
2. Follow `changelog-and-docs.md`: if the task was significant, add a `CHANGELOG.md` entry.
3. If a decision in the log has `Reversibility: hard`, promote it to a proper ADR in
   `docs/adr/NNNN-<slug>.md` (Context / Decision / Consequences), sourced from that log entry.
4. Update status in both the task file and `_index.md`.

A task file isn't deleted after closing — it's the historical record of *why*, which
`CHANGELOG.md` alone doesn't capture at the same resolution. If a project wants closed task files
pruned periodically, that's a project-specific override.
