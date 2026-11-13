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

**When the change produces something a later flow consumes** (a saved template, a setting, a file
another step reads), run that flow on what it produced. The write can be right while the consumer
drops it: a template saved with the right instructions still made a deck whose plan left them out.

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

## Note the friction

Write down, as it happens, what made running it slow or needed the user: a missing seed or fixture,
a manual login or secret, a slow or broken script, a run instruction that's wrong, state you had to
build by hand. Each note says what it cost (minutes, a step only the user could take) and how you
got past it. A trap specific to this machine also goes in `local_e2e`, as above. The notes are what
lets the next run be easier than this one, so keep them even when the run succeeded.

## When the environment is broken

A missing setup step (secrets not pulled, stale dependencies, an expired login) isn't a broken
environment: run it, or ask the user for the one only they can take, naming the command. Broken for
reasons unrelated to the change → say so plainly, and report what stayed unverified. Don't count
"couldn't run it" as verified, and don't sink the run into debugging someone's broken setup.

## Left to the skill running it

When running it is worth the time, where the code is checked out, who hears what was exercised, and
where the friction notes go.
