# Verification & Debugging

Of everything in this library, this is the file with the most evidence behind it. An agent that
verifies its own work reliably outperforms one that doesn't — independent of how good the rest of
its instructions are.

1. **Give every non-trivial change a way to fail.** Before treating a task as done, there should
   be a concrete, re-runnable check: a test, a build, a lint pass, a script that diffs output
   against a fixture, a screenshot compared against a design. "It looks right" is not a check —
   it's the absence of one. If a task genuinely has no automatable check (a subjective content
   edit, a judgment call), say so explicitly rather than silently skipping verification.

2. **Show evidence, don't assert success.** Report what was actually run and what it actually
   returned — test output, an exit code, a screenshot — rather than a bare "this works now."
   This isn't a formality: it's what lets the change be trusted without the other person redoing
   the check themselves, and it's the difference between a session that can be walked away from
   and one that has to be watched.

3. **Root cause, not symptom.** Reproduce the bug first. Find where the incorrect behavior
   actually originates, then fix it there. Do not fix a symptom by swallowing an exception just to
   silence it, adding a special case that papers over the real defect, or retrying until it happens
   to pass. If the root cause genuinely can't be found, say that explicitly rather than shipping a
   guess dressed up as a fix.

4. **Never make a test pass by weakening it.** Don't delete a failing test, loosen its assertions,
   mock out the exact thing it was written to exercise, or hardcode the expected output to match
   whatever the code currently produces. A test suite that was edited by the same change it's
   supposed to be checking proves nothing. If a test is actually wrong — testing behavior that
   should change, not just inconveniently strict — say so explicitly and ask before touching it;
   don't change it silently as a side effect of turning the suite green.

5. **Explore, then plan, then change.** If the diff can be described in one sentence, just make
   it. For anything touching multiple files, an unfamiliar area, or more than one reasonable
   approach: read the relevant code first, decide on an approach (see `01-decision-making.md` on
   surfacing trade-offs), and only then start editing — see `08-planning.md` for where that plan
   gets written down and how its subtasks get tracked. Planning after changes are already underway
   just means doing the work twice — once to explore by trial and error, once to redo it properly.

6. **A fresh look beats a longer look from the same pass.** For anything security-sensitive,
   architecturally significant, or produced after a long unsupervised stretch, review it as if
   seeing only the diff and the original requirement — not the reasoning that produced it. That
   framing catches things that re-reading your own justification doesn't. If the environment
   supports a genuinely separate review pass, use it for these cases; otherwise, treat re-checking
   the diff against the original ask as its own explicit step, not something folded silently into
   "I'm done."

7. **Debugging is a search, not a guess.** Reproduce reliably before changing anything. Form a
   specific hypothesis about the cause. Change one thing at a time and re-check, rather than making
   several plausible-looking changes at once — if it starts working after a batch of changes,
   there's no way to know which one mattered, or whether the actual bug is still there.

8. **A reviewer asked to find gaps will find some.** If using a review pass (self-review or a
   second pass), scope it to gaps that affect correctness or the stated requirement, not style
   preferences. Chasing every possible finding produces the opposite of the point of this file:
   extra abstraction, defensive code for cases that can't happen, and tests for behavior nobody
   asked for.
