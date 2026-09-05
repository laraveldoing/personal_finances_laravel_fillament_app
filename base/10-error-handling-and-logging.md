# Error Handling & Logging

Complements `02-code-standards.md` rule 7 ("fail explicitly") with the actual standard for how
errors are structured and what gets logged. Also complements `05-security.md` rule 3 on secrets
never entering logs — this file is about the rest of what logging touches.

## Error handling

1. **Use the stack's real error/exception mechanism, not a side channel.** Return codes checked
   by convention, a `success: boolean` flag on every response, or a global "last error" variable
   are all ways to make failure silently ignorable. If the language/framework has typed
   exceptions or a `Result`/`Either`-style type, use it — the goal is that failure can't be
   accidentally dropped by forgetting to check something.

2. **Custom error types carry information, not just a message string.** An error a caller might
   need to handle differently (validation failure vs. not-found vs. permission-denied) should be
   a distinct type or a structured code, not a single generic exception with different string
   messages. String-matching on an error message to decide behavior is a sign the error hierarchy
   is missing a level.

3. **Catch where you can act, not where it's convenient.** A catch block should either recover
   meaningfully (retry, fall back, return a typed error to the caller) or add context before
   re-throwing (what was being attempted, with what input, sanitized per rule 6 below) — never
   catch-and-log-and-continue as if the operation had succeeded. This is the concrete form of
   `02-code-standards.md` rule 7: catching without one of those two outcomes is the "empty catch
   block" that rule already forbids, just less obviously.

4. **Don't use exceptions/errors for expected control flow.** A user submitting an already-taken
   username, a cache miss, a not-yet-authenticated request — these are expected outcomes with a
   defined response, not exceptional conditions. Reserve exceptions for genuinely unexpected
   failures (a DB connection drop, a malformed response from a dependency). Using exceptions for
   expected branches makes both harder to reason about: normal flow gets buried in try/catch, and
   real failures stop standing out.

5. **Every unhandled path still needs a defined outcome.** At the boundary of the system (API
   handler, message consumer, scheduled job), there must be a top-level handler that catches
   anything not caught deeper, logs it with full context, and returns/emits a well-formed error
   response — never lets a raw stack trace reach a client or silently drop a message.

## Logging

6. **Never log secrets, and treat PII as sensitive by default.** Extends `05-security.md` rule 3
   from "don't echo secrets into chat/commits" to "don't echo them into logs either" — the same
   value in a log file is exposure in a different shape, often a more persistent one, since logs
   are commonly shipped to third-party aggregators. Personal data (emails, names, addresses, full
   card numbers) gets masked or omitted unless the project's data-handling policy explicitly
   allows it for that log destination.

7. **Log level reflects operational meaning, not developer convenience.** `ERROR`: something
   failed and needs attention. `WARN`: unexpected but handled, worth noticing in aggregate.
   `INFO`: significant state changes (request received, job started/finished) — sparse enough to
   be readable at a glance in production. `DEBUG`: anything needed to trace execution during
   development, off by default in production. Reaching for `console.log`/`print` instead of the
   stack's logger, or defaulting everything to `INFO` because it's the level already in scope, is
   the sign this rule was skipped.

8. **Structured, not just readable.** Log with a structured format (JSON, key-value pairs) the
   stack's tooling can query, not string interpolation the log level and context are baked into
   for no functional reason (`` `ERROR: failed for user ${id}` ``). At minimum: timestamp, level,
   a stable event/error identifier, and relevant IDs (request, user, entity) as separate fields —
   not concatenated into the message.

9. **A log statement replaces a comment, it doesn't duplicate one.** Don't log "entering
   function X" immediately followed by a comment saying the same thing. Log what a human debugging
   a production incident would need and couldn't get from re-reading the code: actual input
   values (sanitized per rule 6), which branch was taken, what an external call actually returned.

10. **Errors surfaced to the person are not the same as errors logged internally.** An
    internal log can carry a stack trace and implementation detail; what reaches an end user
    (API response, UI message) should be safe to show externally — no stack traces, no internal
    identifiers, no detail that helps an attacker map the system — while still being specific
    enough to be actionable. Map the internal error to a user-facing one deliberately, don't
    return the raw exception outward by default.
