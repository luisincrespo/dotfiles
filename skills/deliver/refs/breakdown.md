# Breaking a task into PRs

How `deliver` decides how many PRs a task becomes, and how they depend on each other. Read it at
A2, when the code grows during B1, and at B3's final check. The aim is PRs a reviewer can judge in
one sitting, each doing one thing, without splitting so far that a PR can't be judged without the
next one.

## Seams to split on

Look for these in the plan, and again as the diff takes shape:

- **Behaviour slices.** The first cut to look for is a piece of behaviour that works and can be
  reviewed on its own, even inside one large concern: a whole feature that touches every layer is
  still several increments.
- **A layer whose contract can be reviewed by itself**, such as a server route the CLI will call,
  or a command an agent skill will use. Split by layer when the contract is the thing to review,
  not by habit: four layers aren't four PRs.
- **A substantial preparatory refactor, move or rename.** Ships first, alone, when separating it
  makes the behaviour change easier to review. A small supporting change stays with the behaviour
  it enables.
- **A drive-by fix or cleanup the task doesn't need.** Its own independent PR, or a deferred item.
- **Mechanical churn** (a rename across many files, a bulk reformat), apart from the logic, but only
  when every intermediate state stays valid. Generated artifacts go with the inputs that produce
  them; a migration says how it stays compatible and in which order it deploys.

## Size is a prompt, not a rule

Count additions plus deletions across the whole diff, and report mechanical or generated volume
(lockfiles, snapshots, generated code) separately. Past roughly 400 changed lines, or about 15
files, look for a seam. What tires a reviewer is logic to reason about, and complex tests or config
are part of that, so judge the complexity of the whole diff, not only the count. A change under the
line can still need splitting when it carries two concerns. One over it that stays whole names the
cuts it considered and why each would leave a half-built piece.

## Stack or separate

- **Separate**, off the default branch, when either merge order is safe: not only that each builds,
  but that runtime, schema and rollout don't depend on the order. Independent PRs merge sooner and
  don't wait on each other.
- **Stack** when a later PR needs an earlier one's unmerged code. Base each unit on its actual
  prerequisite, not on whichever unit came before: two units that both need the same one share it as
  their base. A small interface landed first is still a dependency until it merges; once it does,
  `post-merge-cleanup` retargets what was built on it.
- **Keep chains short**, about three deep. A deeper one merges slowly and drags every change through
  the PRs above it; look for units that don't really depend on the one below.

## Don't over-split

Every unit has to stand on its own, given the prerequisites it names:

- a reviewer can judge its correctness without opening the next one;
- it's verified in a way that fits it: tests where it has behaviour, not tests duplicated for the
  sake of the split;
- the default branch still builds and works once it merges, with new code unused until a later PR
  calls it, or behind a flag, rather than broken.

Combine units when their correctness needs reviewing together, for example a function and its only
caller when how they fit is exactly what's in question. A small preparatory PR is fine when its
purpose is clear from its own description; one that only makes sense after reading the next is a
sign to merge them.

## At the plan checkpoint

List each unit in one line: what it does on its own, roughly how big, and what it's based on. For a
single unit past the size prompt, name the cuts considered and why it stays whole. The breakdown is
a decision the user should see.

## When the code says otherwise

The breakdown is an estimate made before the code existed. Reassess when the diff grows during B1,
before self-review, and for an adopted branch as soon as it's adopted; B3 is the final check.
Propose a change only when something new justifies it: a concern the plan didn't foresee, or growth
well past what was approved. An approved large unit that grew as expected gets a line saying why the
breakdown still holds, not another proposal.

To split a branch that's already built:

1. Keep the original branch as it is, as the reference.
2. Build each new unit's branch from it, by its commits where they line up with the seam, otherwise
   by selected hunks, each on its stated base.
3. Check that the tip of the new branches, together, has the same tree as the original:
   `git diff <original> <last new branch>` shows nothing, or only what the split was meant to change.
4. Update `units[]` in the ledger, and take each new unit through B1/B2 again, since its
   intermediate state is new code that hasn't been verified on its own.
