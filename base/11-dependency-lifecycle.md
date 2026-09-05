# Dependency Lifecycle

`03-safety-and-scope.md` rule 6 and `05-security.md` rule 2 cover *adding* a new dependency —
asking first, verifying it's real. This file covers what happens to a dependency after it's
already in the project: updating, deprecating, and removing it.

1. **Routine updates (patch/minor, no advisory) don't need a stop-and-ask.** Bumping a dependency
   within its existing semver range to pick up a patch or minor release — no known breaking
   change, no security advisory driving it — is routine maintenance, not the kind of new-package
   decision `03-safety-and-scope.md` rule 6 gates. Still run the project's test suite before
   calling it done; "routine" describes the risk level, not a reason to skip verification.

2. **A security advisory changes the calculus, not the caution level.** If an audit tool
   (`npm audit`, `pip-audit`, `composer audit`, `govulncheck`, `cargo audit` — see
   `05-security.md` rule 2) flags an installed dependency, treat patching it as high-priority but
   not as license to skip review: read what the advisory actually affects, confirm the fixed
   version doesn't carry an unrelated breaking change bundled in, and still run the test suite.
   Speed matters here, silence about what changed does not.

3. **A major version bump is a task of its own, not a side effect.** Don't fold a major-version
   dependency upgrade into an unrelated feature or bugfix commit — see `06-version-control.md`
   rule 2 on atomic commits. Read the changelog/migration guide for what actually broke, don't
   assume semver alone tells the full story (published migration guides exist precisely because
   it doesn't). If the upgrade touches more than the dependency bump itself (API surface changed,
   config format changed), that's real work worth its own plan file per `base/08-planning.md`.

4. **Pin what needs to be reproducible, float what needs to stay current.** Application
   dependencies (the thing actually deployed) should be locked to exact versions via the
   ecosystem's lockfile, committed to version control — reproducibility beats always-latest.
   Library/package dependencies (code meant to be consumed by others) should specify a
   compatible range, not a pin, so consumers aren't forced into version conflicts. Never edit a
   lockfile by hand; regenerate it through the package manager.

5. **A deprecated dependency is a logged decision, not a silent swap.** If a dependency is
   unmaintained, has a known unpatched vulnerability, or is being deliberately replaced, that's a
   decision with reversibility implications — log it in the relevant plan file's decisions log
   (`documentation/planning-log.md`) rather than swapping it out as an incidental part of other
   work. Removing a dependency that turns out to still be used elsewhere in the codebase is a
   regression; grep for actual usage before removing, don't rely on the import list alone.

6. **Transitive dependencies aren't invisible.** A vulnerability or license issue three levels
   deep in the tree still applies to the project using it. When an audit tool flags a transitive
   dependency with no direct upgrade path, prefer forcing a resolution/override through the
   package manager's supported mechanism over vendoring a patched copy — and if neither is
   available, say so explicitly rather than leaving the finding unaddressed and unmentioned.

7. **License changes on update are a stop-and-ask, not a background detail.** If a dependency
   changes its license between versions (permissive to copyleft, open-source to a
   source-available/commercial model), surface that before merging the update — same class of
   decision as adding a new dependency in the first place (`03-safety-and-scope.md` rule 6), since
   the legal exposure is identical whether the package is new or just changed under an existing
   import.
