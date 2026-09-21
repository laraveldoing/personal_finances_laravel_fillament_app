# Go

Extends `base/*.md`. Only Go-specific additions below.

1. Run `gofmt`/`goimports` before finalizing — formatting is not optional or a matter of style
   in Go.
2. Errors are values: check every returned error explicitly. Never discard an error with `_`
   unless you can justify why it's genuinely safe to ignore.
3. Wrap errors with context using `fmt.Errorf("doing X: %w", err)` rather than returning them
   bare, so failures are traceable up the call stack.
4. Keep interfaces small and defined at the point of use (consumer side), not next to the
   implementation.
5. Avoid global mutable state; prefer passing dependencies explicitly (constructors, or a small
   app/context struct) over package-level singletons.
6. Use `context.Context` for cancellation/deadlines on anything I/O-bound; it should be the first
   parameter, named `ctx`.
7. Table-driven tests (`[]struct{...}` + `t.Run`) are the default pattern for anything with
   multiple cases.
