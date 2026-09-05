# Version Control

1. **Default to Conventional Commits, but existing convention always wins.** Check recent
   `git log` output before the first commit of a session — if the project already has a pattern
   (with or without Conventional Commits), follow it. Otherwise:

   ```
   <type>(<scope>): <description>

   type: feat | fix | docs | style | refactor | perf | test | build | ci | chore
   ```

   Imperative mood ("add", not "added" or "adds"), no trailing period, body explains *why* when
   that isn't obvious from the diff alone. A `BREAKING CHANGE:` footer for anything that breaks a
   public contract.

2. **Atomic commits.** One logical change per commit. An unrelated formatting pass, a dependency
   bump, and the actual feature are three commits, not one — even when it means more commits for a
   single task. This is what makes `git bisect` and `git blame` useful instead of theoretical.

3. **Never rewrite shared history.** Force-push, `commit --amend`, and `rebase` on any branch
   other people might have pulled follow the same rule as any other destructive action in
   `03-safety-and-scope.md`: confirm explicitly first, and verify the branch is actually
   local-only/unshared before ever running one of these, even when it seems safe.

4. **Match existing branch and PR conventions; propose a default if there are none.** Check recent
   branches and merged PRs before inventing a pattern. If nothing established exists, a reasonable
   default is `type/short-description` (`fix/session-timeout-redirect`). PR/MR descriptions should
   state what changed and why, and explicitly flag anything a reviewer should look at twice — files
   touched outside the obvious scope, a behavior change, a follow-up intentionally left for later
   (see `documentation/changelog-and-docs.md` for how that follow-up should be logged).

5. **Nothing goes into history that shouldn't stay there forever.** Secrets (see
   `05-security.md`), large binaries, build output the project doesn't already track, and
   local-only config all belong in `.gitignore`, checked before the first commit of a new file
   type — not cleaned up after the fact, since removing a file from a future commit doesn't remove
   it from history.

6. **Commit messages describe the change, not the process that produced it.** "Fix session timeout
   redirect," not "apply suggested fix" or "address review comments round 2." Whoever reads
   `git blame` in a year needs the message to stand on its own, without the conversation that
   produced it.
