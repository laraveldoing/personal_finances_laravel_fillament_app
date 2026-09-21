# Personal AI Coding Guidelines Library

Stack-agnostic base, plus per-language and per-framework overrides, meant to be reused across
projects (not tied to any single repo).

## Structure

```
base/
  01-decision-making.md      # verify before assuming, propose don't decide unilaterally, etc.
  02-code-standards.md       # separation of concerns, naming, DRY, fail explicitly, tests, etc.
  03-safety-and-scope.md     # limited scope, secrets, destructive actions, new dependencies

languages/
  php.md
  python.md
  go.md
  js-ts.md

frameworks/
  laravel.md                 # extends base + php.md
  nextjs.md                  # extends base + js-ts.md
  nuxtjs.md                  # extends base + js-ts.md

documentation/
  changelog-and-docs.md      # changelog format, TODO.md format, when to document
```

## How to apply this to a new project

1. Always include everything in `base/`.
2. Add the relevant file(s) from `languages/` for the project's language(s).
3. Add the relevant file(s) from `frameworks/` if the project uses one of the covered frameworks.
4. Always include `documentation/changelog-and-docs.md`.
5. If the project has its own tool that generates its main guideline file automatically (e.g.
   Laravel Boost regenerating `AGENTS.md` from `.ai/guidelines/`), **do not paste these files'
   content directly into the generated file** — it will get overwritten. Instead:
   - Copy the relevant files from this library into wherever that tool reads project-level
     guidelines from.
   - Add any project-specific rules (that override or extend these) as separate files in that
     same location, referencing this library rather than duplicating it wholesale.
6. If a project needs to override a rule from this library, the override belongs in the
   project's own guideline file, with an explicit note on why — don't silently edit the library
   copy per-project, or future syncs will lose the general rule.

## Maintaining this library

This is meant to grow over time. When a project teaches you something worth generalizing
(a rule that would have helped in a previous project too), port it back here — don't let good
rules stay trapped in one repo's `.ai/guidelines/`.

Precedence when combining, most specific wins:

```
project-specific rules  >  framework file  >  language file  >  base/
```
