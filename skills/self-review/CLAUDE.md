# self-review: contributor notes

## Passes

- `passes/` holds the checks any change can raise; `passes/stack/` holds one per language,
  framework or tool. Both reviews, this skill and `pr-review`, run every file in either folder that
  has a `## When it applies` section, by that section's own test. So a new pass is a new file: no
  list to edit anywhere. The files with no such section (`claims`, `exercise`, `second-opinion`,
  `conventions`, `personal-conventions`) are procedures their own steps call; adding one to a step
  is a change to that step.
- A pass has *When it applies* (a test a reviewer can apply to the diff, ending with how to say it
  doesn't), *What to know first*, *What to look for*, *The bar for a finding* and *Why it's a pass
  of its own*, and optionally *Left to the skill running it*. It says what to check, never what a
  finding becomes: that's the reviewing skill's.
- Each root cause has one owning pass. A pass that touches another's ground names the owner in a
  line, as `customer-data.md` hands data in logs to `observability.md`.

## Adding a stack pass

`stack/react.md` is the model. A stack pass:

- reads the version the repo uses from its manifest or lockfile, and anything that changes the
  rules (a compiler, a framework on top);
- checks against the official docs for that version, linked, not against memory;
- leaves out what the repo's linter or type checker already reports;
- lets the repo's own guidance for the stack win where they differ;
- carries no taste: the user's own conventions for a stack go in `personal-conventions.md`, under
  that stack's heading.

A project's own library (a company's UI kit, its ORM conventions) gets no pass here. The repo
supplies that guidance, the way the UX pass reads a project's design guidance.

## Kept in step with write-code

Each principle in `../write-code/refs/principles.md` cites the pass that checks it in depth.
Changing a pass means checking that principle still says the same thing, and the reverse.
