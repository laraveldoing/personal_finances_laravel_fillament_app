# Documentation & Changelog

Applies to any project, regardless of stack.

## Two different things get called "documentation"

**Don't create standalone documentation files unprompted** — a new `SETUP.md`, a how-it-works
guide, an architecture writeup nobody asked for. If one would genuinely help, offer it at the end
of a response instead of just creating it. Unsolicited docs go stale fast, aren't discoverable by
whoever eventually needs them, and their real cost shows up months later as one more file nobody
trusts.

**Do maintain the living files below without being asked each time.** This is closer to
engineering note-taking than to "documentation" in the deliverable sense — it's how continuity
survives a session boundary, a context reset, or simply a different person picking the work back
up. A future session inherits state through files like these, not by re-reading the conversation
that produced them. This now includes `/plans/_index.md` and per-task plan files — see
`documentation/planning-log.md` — which replace what used to be tracked in a standalone
`docs/TODO.md`.

## When to document

After completing each **significant** task (new module, feature, architecture change):

1. Update `docs/CHANGELOG.md` using the format below.
2. If the task introduced or changed a communication pattern between modules, update the
   project's architecture doc (e.g. `docs/00-architecture.md`) accordingly — never let it drift
   from the real implementation.
3. If technical debt or an undecided item remains, add it to `/plans/_index.md` with enough
   context to pick it back up without needing to remember the original conversation — see
   `documentation/planning-log.md`.

**Do not document trivial changes** (typo fixes, minor style adjustments). Document: architecture
decisions, new modules, contract changes between modules, and trade-offs taken.

## Changelog format

```markdown
## [YYYY-MM-DD]

### Title of the significant change
- **Modules affected:** ...
- **Implementation:** ...
- **Technical decisions:** ...
```

- Group all changes from the same day under a single `## [YYYY-MM-DD]` heading.
- Each significant change (new module, feature, cross-module refactor) gets its own `###`
  sub-entry.
- Trivial changes don't get their own sub-entry — they can go as a loose bullet under the date's
  heading if worth mentioning at all.

## Out-of-scope findings

If, while working on a task, unrelated problems turn up (dead code, inconsistent patterns, missing
tests elsewhere), don't fix them silently — that's a scope violation (see
`base/03-safety-and-scope.md`). Log them in `/plans/_index.md` with enough context to evaluate
later — see `documentation/planning-log.md` for the format. This is also where a recurring
instruction to an agent belongs before it becomes a permanent line in a project's guideline file —
see `MAINTAINING.md` on generalizing incidents instead of transcribing them: if the same
friction shows up on more than one project, that's the signal it belongs in this library, not
evidence that it needed to be said sooner.
