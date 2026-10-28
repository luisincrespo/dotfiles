# Exercise it

Running a change to see what it does. Reading a diff shows what the code says; static passes miss
what only shows up at runtime.

## Bring it up

`Skill(run)`, or the repo's own local-dev skill when it has one. Read the repo's `local_e2e` entry
in local config first: how to bring it up, how to authenticate, and the traps that have cost time
before. Append a note there when a new one costs you time. Reuse a running environment rather than
starting a second.

Other sessions may be driving their own stacks from sibling worktrees. Only start, stop or
reconfigure the instance belonging to the checkout you're running, and treat anything shared
between them (a database, a container, a fixed port) as yours to read but not to reset.

## What to check

Drive the actual path, and check two things, not one: **the change works as intended**, and **the
neighbouring case still works**. A guard added to fix one path is the likeliest thing to have
silently disabled another. Name the states you exercised.

**Exercise with data you change in the session, not only what's already there.** A feature that
reads a derived store (a search index, a cache) can look right on records some other path already
brought up to date and still miss everything the change creates. Archived-template search passed on
a template archived long ago and returned nothing for one archived minutes earlier, because
archiving never reindexes.

**When the change is gated on a data migration, exercise both sides of it.** Migrating the
environment to make the new path reachable destroys the state the change actually ships into, and
that pre-migration state is what every user sees on day one. Backfilling a column locally so the
new branch had something to read left the un-backfilled path, the whole production estate until
someone runs the script, verified by nothing.

## When the environment is broken

For reasons unrelated to the change → say so plainly, and report what stayed unverified. Don't
count "couldn't run it" as verified, and don't sink the run into fixing someone's local setup.

## Left to the skill running it

When running it is worth the time, where the code is checked out, and who hears what was exercised.
