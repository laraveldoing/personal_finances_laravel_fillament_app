# Python

Extends `base/*.md`. Only Python-specific additions below.

1. Follow PEP 8; use a formatter (black/ruff format) and a linter (ruff/flake8) — run them before
   finalizing, don't just report violations.
2. Use type hints on all function signatures (`def foo(x: int) -> str:`). Prefer `from __future__
   import annotations` or native syntax matching the project's Python version.
3. Prefer `dataclasses` or `pydantic` models over untyped dicts for structured data crossing
   function/module boundaries.
4. Use context managers (`with`) for anything with a teardown step (files, connections, locks).
5. Never use bare `except:`; catch specific exceptions. If you must catch broadly, re-raise or
   log with full context — never swallow silently (see base rule on failing explicitly).
6. Use `pathlib.Path` over raw string path manipulation.
7. Dependency management: respect whatever the project already uses (poetry, uv, pip-tools,
   plain requirements.txt) — don't introduce a second tool without approval (see base rule on new
   dependencies).
