# Planning

Applies before any non-trivial task. See `documentation/planning-log.md` for the file format,
templates, and Gherkin conventions this file assumes.

1. **No execution without a written plan.** Before writing or modifying code for any task that
   isn't trivial (see rule 2), break it into subtasks and write the plan to
   `/plans/<task-slug>.md` before touching code — not after, not interleaved with exploration.
   This is the concrete mechanism for "explore, then plan, then change" in
   `04-verification-and-debugging.md`; that file governs *when* to plan, this one governs *how*.

2. **Trivial tasks skip the file, not the discipline.** A one-line config change, a typo fix, or
   a diff describable in one sentence doesn't need a `/plans` file. It still follows every other
   rule in this library — scope, verification, commit hygiene. When in doubt whether a task is
   trivial, it isn't: write the plan.

3. **Every subtask needs a falsifiable success criterion.** Before marking a subtask complete,
   it must have a Given/When/Then scenario (or, for purely mechanical subtasks with no business
   logic, an equivalent one-line check) written *before* implementation starts, not reconstructed
   afterward to match whatever was built. Reconstructing criteria after the fact defeats the
   purpose — see `04-verification-and-debugging.md` rule 1 on why "it looks right" isn't a check.

4. **Decisions get logged where they're made, not remembered.** Any non-trivial decision made
   while executing a plan (library choice, data structure, naming a boundary, picking between
   approaches) is logged in that subtask's plan file at the moment it's made — see
   `01-decision-making.md` on which decisions warrant surfacing trade-offs to the person in the
   first place. The plan file is where the outcome of that discussion (or the reasoning if no
   discussion was needed) gets recorded for a future session to find.

5. **Stopping for confirmation follows the existing Never/Ask first/Always split.** A plan does
   not grant standing permission to proceed through what `03-safety-and-scope.md` already flags
   as "ask first" (destructive actions, new dependencies, build/CI config) or "never" (scope
   expansion, weakened security). Writing a step into a plan is not the confirmation itself.
   Genuinely ambiguous requirements — two reasonable readings where picking wrong means redoing
   real work — get the same treatment: state the interpretations, ask, don't guess and proceed.

6. **A plan file is the answer to "what's left," not a memory exercise.** When asked about
   status, read `/plans/_index.md` for the overview and the specific task file's checklist for
   detail — answer from what's on disk, not from what the conversation seems to imply. If the
   file and the actual code state have drifted, trust the code and fix the file, in that order.

7. **Closing a task means the file reflects reality, not just that work happened.** A subtask
   isn't checked off until its Given/When/Then has actually been run and passed — see
   `04-verification-and-debugging.md` rule 2 on showing evidence rather than asserting success.
   Closing the whole plan means: every subtask checked, every non-trivial decision logged, status
   updated in both the task file and `_index.md`, and any documentation obligation from
   `documentation/changelog-and-docs.md` satisfied before the plan is marked complete.
