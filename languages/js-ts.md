# JavaScript / TypeScript

Extends `base/*.md`. Only JS/TS-specific additions below.

1. Prefer TypeScript over plain JS for anything beyond a trivial script, if the project allows
   introducing it (see base rule on new dependencies/tooling — confirm before adding TS to a JS
   project).
2. Avoid `any`; if a type is genuinely unknown, use `unknown` and narrow it, or document why `any`
   is unavoidable.
3. Prefer `const` by default, `let` only when reassignment is required. Never `var`.
4. Async code: use `async`/`await` over raw `.then()` chains for anything with more than one
   step. Always handle rejections — no dangling unhandled promises.
5. Run the project's configured linter/formatter (ESLint/Prettier or equivalent) before
   finalizing, don't just report violations.
6. Immutable data patterns preferred where the codebase already leans that way (spread/map/filter
   over in-place mutation) — but follow existing convention over personal preference (base rule
   7).
7. No default exports for anything except framework-mandated cases (e.g. Next.js pages) — named
   exports are easier to refactor and trace. Follow existing project convention if it differs.
