# Performance pass

A check of a diff for work whose cost grows with data or traffic. It applies to any diff, your own
or someone else's; the skill that reads it decides what happens to the findings.

## When it applies

When the diff touches work that grows with data or traffic:

- database queries or ORM calls;
- network or API calls;
- loops over collections that grow with usage;
- request handlers, jobs and queue consumers;
- UI rendering: components, hooks, state.

Touching none of these → it doesn't apply. Say so in one line rather than skipping it silently.

## What to look for

- **A query or request inside a loop** (N+1): one call per item where one call for all of them
  would do.
- **Unbounded work**: a fetch, list or scan with no limit or pagination.
- **Repeated work on a hot path**: the same fetch twice, recomputing on every render,
  re-rendering on every keystroke, an effect whose dependencies change every render.
- **A new query no index serves.**
- **A large new dependency** in what the client downloads.

## The bar for a finding

Each finding names **what grows, and what it costs as it does**: "one query per row, so a 500-row
board makes 500 queries", not "this could be slow". That makes it a claim the reader can check
rather than a hunch. Micro-optimizations on cold paths are noise; leave them out.

A fix that trades something away, like a cache (staleness) or an index (a migration, write cost),
is a judgment call, not a clear fix.

## Why it's a pass of its own

These defects look correct in isolation. A correctness review reads the logic and finds it right;
tests on small fixtures run fast whatever the shape. An efficiency cleanup catches local waste, not
cost under load. And agent-written code produces them readily: a query per item reads naturally
when each line is written for the item in hand.
