# Maintaining This Library

This file is about how to write and prune rules, not what the rules say. Read it before adding
anything to `base/`, `languages/`, or `frameworks/`.

## What this library is actually for

Be honest about what a context file buys you. Controlled studies on repository-level context
files (AGENTS.md-style) have found their effect on whether an agent solves a given task correctly
is small and inconsistent — one large study found essentially no effect on correctness at all,
with agents failing on implementation skill (design, exact wiring, edge cases) rather than on
missing facts a context file could have supplied. Verbose, auto-generated context files measurably
made things worse: more tokens, more exploration, no better outcomes. Minimal, precise,
human-written ones showed a small real benefit.

Where context files *do* have clear, reproducible value: keeping the agent from repeating a
mistake you've already told it about, following conventions instead of inventing new ones each
session, not wasting effort (re-running a slow full test suite blindly instead of the targeted
one, re-deriving a decision that was already made), and behaving consistently across tools and
sessions. That's what this library is for. It is not a substitute for scoping the task well,
giving the agent a way to verify its own work, and reviewing what it produces — those matter more
than anything written here.

This reframes what "more powerful" means for this library: not longer, not more comprehensive —
higher signal per line.

## Before adding a rule, ask these in order

**1. Would removing this line actually cause a mistake?** Not "is this good practice" — every
coding practice is good practice. Would a capable engineer or a capable model, without this line,
plausibly get it wrong? If no, cut it.

**2. Is this the toolchain's job?** If a linter, formatter, type checker, or CI gate already
enforces it deterministically, the rule belongs in that tool's config, not in prose the agent has
to remember to re-derive every session. Here, at most, point at the command:

```
Good:  Run `vendor/bin/pint --dirty` before finishing any PHP change.
Bad:   Use 4 spaces, put braces on the same line, order imports alphabetically...
```

If you catch yourself writing out what a tool already checks, delete the prose and add — or
verify — the tool config instead.

**3. Is this the right altitude?** Two failure modes, both common:

- **Too brittle** — hardcoded step-by-step logic for a specific scenario, written as if it were a
  general rule. It'll be wrong the first time reality doesn't match the scenario, and nobody will
  notice until it silently misfires.
- **Too vague** — "write clean code," "be careful with security," "communicate well." Nothing
  here implies a different action than the model would already take. It just takes up space that
  competes with the rules that do matter.

A rule at the right altitude is specific enough that following it changes what gets built, and
general enough to still make sense on a project you haven't described in detail.

**4. Is it falsifiable?** You should be able to look at a finished piece of work and say
definitively whether the rule was followed. "Tests required for payment logic" is falsifiable.
"Write good tests" is not — rewrite it until it is, or drop it.

**5. Does it already fit NEVER / ASK / ALWAYS?** Most durable behavioral rules (as opposed to code
style) are one of:

- **NEVER** — a hard limit that holds regardless of how the request is phrased or how confident
  the agent is (destructive commands without confirmation, secrets in code).
- **ASK** — a human-in-the-loop trigger: the stakes or ambiguity are high enough that guessing,
  even a reasonable guess, would be presumptuous (new dependencies, touching CI/deploy config
  outside the task).
- **ALWAYS** — a proactive default the agent should do without being asked each time (verify
  before assuming, show evidence instead of asserting success).

If a candidate rule doesn't fit any of the three, it's probably not a behavioral rule at all —
it's either a style preference (→ toolchain) or trivia (→ delete).

## Pruning is not optional

A file that only grows is a file nobody trusts. On a regular pass through this library —
not only when something breaks — re-read every line against these questions:

- Has this become the linter's job since it was written? Delete it, and confirm the linter
  actually covers it.
- Was this added to steer around one specific piece of legacy code or one specific ambiguity? If
  that code got deleted or the ambiguity got resolved, the instruction is now dead weight —
  delete it rather than leaving it as a monument to a problem that no longer exists.
- Is this now just restating a default any capable model already does unprompted? Delete it.
- Do two rules, in this file or across files, say almost the same thing? Keep the more specific
  one and delete the other.

A rule that keeps needing to be repeated is a signal the underlying friction wasn't actually fixed
— consider whether the fix belongs in the codebase (delete the confusing legacy pattern, add a
lint rule) rather than in one more line of prose trying to steer around it.

## Generalize incidents, don't transcribe them

When a project teaches you something worth keeping — the existing `README.md` already asks you to
port lessons back here — write the general rule the incident implies, not the incident itself.

```
Bad:   Don't use raw SQL in OrderService.php like on 2026-03-14, use the query builder.
Good:  Use the query builder or ORM for application queries; drop to raw SQL only for cases the
       builder genuinely can't express, and say why in a comment when you do.
```

The bad version is a landmine for one file in one project. The good version is a rule.

## Where a new rule goes

- Applies to how the agent should think or behave regardless of stack → `base/`.
- Applies to one language, regardless of framework → `languages/`.
- Applies to one framework specifically → `frameworks/`.
- Is really a one-off fact about a single project (an internal service name, a team's Slack
  handle, this quarter's migration plan) → it doesn't belong in this library at all. It belongs in
  that project's own instruction file, layered on top per the precedence rule in `README.md`.

## This file itself

`MAINTAINING.md` should change rarely — it's about method, not content, so it shouldn't need to
grow just because a project taught you a new fact. If you find yourself editing it often, what
you're adding is probably a new rule for `base/`, not a new principle for writing rules.
