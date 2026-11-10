---
name: write-code
description: >-
  How to write or change code the way the user wants it: their principles (one job per unit,
  separation of concerns, extensible for what's coming, testable by construction), their
  conventions, and the self-review passes that will check the change, read before writing so the
  code is built to pass them. Use whenever writing or changing code, in deliver's execute stage or
  any coding session. Learns from corrections, and from what self-review keeps having to fix.
---

# write-code — write it the way it'll be reviewed

`self-review`'s passes check a change in depth once it's written. This skill brings them forward:
`refs/principles.md` says in a line each how the user wants code written, and the pass each
principle cites says what it means in detail. Code written to both comes back from review with less
to fix.

The skill's own folder is the base dir for the relative paths below.

**This skill is shared machinery; `refs/principles.md` is the personal layer.** Someone else using
this setup puts their own principles at the same path in their private companion repo, which
`install.sh` links in place of these.

## Before writing

1. Read `refs/principles.md`.
2. Read the conventions for what you'll touch, the way `../self-review/passes/conventions.md`
   finds them (the repo's `CLAUDE.md` and `REVIEW.md` files, and the user's own in
   `../self-review/passes/personal-conventions.md`, the sections for the stacks in play).
3. Read the passes that will check this change: each file in `../self-review/passes/` and its
   `stack/` folder whose *When it applies* matches what you're about to write. Their *What to look
   for* is what to build in, and the project guidance they point to (the UX pass's design guidance,
   say) binds the code as much as it binds the review.

Where the repo's own rules disagree with a principle, the repo wins; say so once.

## While writing

Keep the change the smallest one that does the job. A principle this change can't meet without a
redesign it shouldn't carry is a deferred item or a question for the user, never a silent
exception.

## Learn from every correction

When the user corrects code you wrote, or a review fixes something a principle should have
prevented, capture it before moving on:

- a short, general rule → `refs/principles.md`, citing the pass that checks it in depth when one
  does;
- an in-depth check → that pass, with the principle it backs pointing to it;
- a convention (a name, a format, a language rule) →
  `../self-review/passes/personal-conventions.md`, under its stack;
- something only one repo does → its `CLAUDE.md`, which is the user's to change: suggest the line.

Prefer sharpening a line to adding one. Apply the edit and say what changed, unless it's
consequential (global rule 13). Under `deliver`, hand the lesson up instead: its end-of-run
reflection routes it once.

## Kept in step with the passes

A principle that cites a pass is that pass's rule in a sentence. Changing either means checking the
other still says the same thing: a pass that no longer backs its principle has code written to one
bar and reviewed against another.
