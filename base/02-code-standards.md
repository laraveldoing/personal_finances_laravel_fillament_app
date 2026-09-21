# Code Standards

Language-agnostic standards. See `languages/*.md` and `frameworks/*.md` for stack-specific
overrides and additions — those files should assume these rules as a baseline and only add,
not repeat.

1. **Separation of concerns.** Non-trivial business logic belongs in dedicated units (services,
   use cases, actions — naming varies by stack), never in the thinnest layer of the request cycle
   (controllers, handlers, route callbacks). That layer only orchestrates: validate input, call
   business logic, return a response. Data-representation layers (models, entities, structs)
   represent data and relationships, not business rules.

2. **No magic strings/numbers.** Never hardcode literal strings or numbers that represent a
   meaningful value (statuses, roles, limits, config thresholds). Use constants, enums, or config
   files. If the same literal appears more than once, it must be a named reference, not repeated
   text.

3. **Naming.** Names must be descriptive and unambiguous — no single-letter variables outside
   trivial loops, no abbreviations that aren't universally clear. A name should make a comment
   unnecessary.

4. **DRY, but not premature.** Don't duplicate logic across files. But don't abstract/generalize
   code that's only used once "just in case" — wait until a real second use case appears.

5. **Fix in place, don't fork.** When an approach isn't working, fix or replace it where it lives.
   Don't create `thing_v2.py`, `ComponentFixed.tsx`, or a parallel implementation left "just in
   case" alongside the original. If comparing two real approaches deliberately, say so, and remove
   the one not kept before calling the task done — an abandoned variant left in the tree is a bug
   waiting to be imported by mistake, and a maintenance cost nobody signed up for.

6. **Match the size of the fix to the size of the ask.** Don't introduce a new abstraction layer,
   config system, or defensive branch for a case the task didn't ask about and the codebase
   doesn't otherwise need — that's scope creep in different clothes (see
   `03-safety-and-scope.md`). Noticing a real gap while working is useful; building the general
   solution for it unasked is not. Log it instead in `/plans/_index.md` (see
   `documentation/planning-log.md`).

7. **Fail explicitly.** Don't silently swallow errors (empty catch blocks, ignored return values,
   ignored error returns). Handle exceptions/errors deliberately or let them propagate with
   context.

8. **Tests are part of "done" for sensitive logic.** Code handling payments, permissions, auth, or
   any financial/security-sensitive path must include tests covering the happy path and at least
   one failure/edge case — not considered done without this. See
   `04-verification-and-debugging.md` for how to verify any change, sensitive or not, and
   `05-security.md` for what else "sensitive" should make you careful about.

9. **Consistency over personal preference.** Follow the existing conventions already present in
   the codebase (formatting, structure, patterns) even if a different approach is technically
   valid. If you believe an existing convention should change, propose it explicitly rather than
   introducing an inconsistent alternative silently.

10. **Respect authorization boundaries.** Never cross authorization boundaries defined in the
    project (e.g. using one permission guard/context/policy where another applies). If unclear
    which context an action belongs to, ask before implementing.

11. **Small, reviewable units.** Prefer small functions/classes/modules with a single
    responsibility over large multi-purpose ones. If a function needs a comment to explain "what
    it does" in one sentence, it's a candidate for a name change or a split.
