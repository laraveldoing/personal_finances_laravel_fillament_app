# Laravel

Extends `base/*.md` and `languages/php.md`. Only Laravel-specific additions below. If the
project uses Laravel Boost, prefer Boost's own generated rules (from installed package versions)
over these when they conflict — Boost's are version-verified against the actual installed
packages.

1. **Use Artisan generators.** Use `php artisan make:*` commands to create new files (migrations,
   controllers, models, etc.) instead of creating them by hand. Use `php artisan list` to
   discover commands and `--help` to check parameters. Pass `--no-interaction` plus the correct
   options so commands work without prompts.
2. **Generic PHP classes** that aren't a Laravel construct: use `php artisan make:class`.
3. **Model creation**: create factories (and seeders if relevant) alongside new models. Don't
   create models directly in tinker — prefer tests with factories.
4. **Eloquent API Resources** by default for APIs, with API versioning, unless the existing
   codebase doesn't already do this (follow existing convention over the default).
5. **Named routes.** Prefer named routes and the `route()` helper over hardcoded URLs.
6. **Testing conventions**: use factories (check for custom states first), `php artisan make:test`
   to scaffold, and run only the relevant test/file via `--filter` while iterating.
7. **Formatting**: run the project's configured formatter (e.g. `vendor/bin/pint --dirty`) before
   finalizing any PHP change, not `--test` mode — fix, don't just report.
8. **Long-running server runtimes (Octane and similar).** If the project uses Octane or another
   long-running PHP server: never store request-specific state in singletons or static
   properties (it leaks across requests); prefer scoped bindings over singletons for per-request
   services.
