# Project brain

A project's background page is its brain: what someone working on the project every day carries in
their head, so a task or a review starts with the big picture instead of rebuilding it. It's only
useful if a session can read all of it every time, so it stays small, and history lives elsewhere.

This is the default shape. A page that says how to update itself follows its own rules, and those
win over this file.

## Shape

The **brain**, read in full by every task and review on the project, capped near **3,000 words**,
one short line per fact (a few hundred characters at most) linking out for detail:

- **Current state** — what's live, what's in flight, what's next, each with its date.
- **Decisions in force** — one line each: what, why, a link. A product decision says who made it.
- **Map** — where things live: code areas (paths), contracts (APIs, schemas, events), flags and
  their rollout, vendors and their limits.
- **Invariants and traps** — what breaks silently if forgotten.
- **Open questions** — including what only the user can answer.
- **Recent changes** — the last ten edits, newest first.

The **archive**: a separate page the brain links to, holding per-PR history, superseded decisions
and older changes. Open it only to answer a specific question.

## Reading it

Read the brain whole, never a digest scoped to one task: the big picture is what a digest drops.
Then ask of the work in hand:

- Where does it sit in the current state, and what that's in flight does it touch?
- Which decisions, invariants and traps apply to it?
- Which open question does it answer or reopen?

An answer that bears on the work goes where the task or review records project context, traceable
to the line it rests on. The page itself is private context for the user and their agents: nothing
other people read (a review comment, a PR description, a message) cites or links it, since they
don't know it exists. Cite the ticket, PR, file or doc its line points to instead.

## Writing it

- **Replace, don't append.** A change to current state rewrites the line it changes. A decision
  that's superseded moves to the archive, with what replaced it.
- **Stay under the cap.** An addition that would push the brain past it moves something older to
  the archive first.
- **History goes to the archive**, never the brain: who reviewed what when, PR-by-PR status, run
  logs.
- **Log the edit** in Recent changes, and move the eleventh-oldest line to the archive.
- Product decisions, scope and priorities aren't the agent's to change: where the work contradicts
  one, ask the user instead.
