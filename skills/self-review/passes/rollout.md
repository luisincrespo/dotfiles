# Rollout pass

A check of who gets a change and when: that new behaviour sits behind the gate its rollout calls
for, that the gate holds on every path to it, and that a change to a feature already rolling out
follows that feature's gate. It applies to any diff, your own or someone else's; the skill that
reads it decides what happens to the findings.

## When it applies

When the diff:

- adds or changes behaviour users can reach: a screen, a flow's steps, an endpoint, an agent tool
  or skill, a default;
- touches code behind a feature flag, gate or experiment, or code a gated feature calls;
- adds, changes or removes a flag check, a flag's definition or its default.

A diff that does none of these → it doesn't apply. Say so in one line rather than skipping it
silently.

## What to know first

- **The repo's way of gating.** Its flag SDK or config, where flags are declared, how they're
  evaluated (per user, per workspace, per request) on the server and on each client, and what a
  missing flag or a failed evaluation returns. The closest gated feature shows the convention.
- **The rollout this work is meant to follow.** The ticket, the project's background page, the PR
  description: a staged percentage, internal or beta first, an experiment, or "ships to everyone".
- **The gates already on what the change touches.** Search the surrounding code paths for flag
  checks on the same feature, and where the flag tool has a connector, read the flag's current
  targeting and rollout. A feature that's at 10% today is the reference for a change to it.

## What to look for

- **Ungated behaviour.** New behaviour users can reach with no gate, where the stated rollout calls
  for one or the rest of the feature is gated: it reaches everyone at merge.
- **Paths around the gate.** One entry point gated and another not: a second screen, an API route,
  a background job, another client, an agent tool or skill. The UI hidden while the endpoint it
  calls stays open counts, and so does the reverse.
- **The wrong gate.** A new piece of a feature that's already rolling out, put behind a new or
  different flag, so users can get half of it; or evaluated on a different context than the
  existing gate (per user where it's per workspace), so the halves disagree for the same person.
- **Unsafe fallback.** A missing flag, an environment where it isn't defined yet, or a failed
  evaluation that turns the new behaviour on.
- **Rollback.** With the flag turned off again, the old path still works, and it can still read
  data written while the flag was on. A migration or a data shape change that only the on path
  understands makes the flag one-way.
- **Removal too early.** A flag, or its check, removed while the flag isn't fully rolled out, which
  ships it to everyone with the merge.

**Each root cause goes to one pass.** This one owns who gets the change and when. Exposure events
and the signals an experiment is read by belong to [`observability.md`](observability.md); a
migration's own correctness, to the general correctness review.

## The bar for a finding

Each finding names the gate, or the missing one, and the users who'd get the behaviour at merge or
the path that gets around the gate, measured against the stated rollout or the gate already on the
feature: "the new export step is behind `new-export`, but the agent's export tool calls the same
endpoint ungated, so every agent session gets it". Without a stated rollout or an existing
gate to measure against, it isn't a finding, with one exception: a large change users can reach,
with no gate and no plan anyone stated, is a question for the user (does this ship to everyone at
merge?).

## Why it's a pass of its own

Rollout mistakes pass every test: the feature works, it just reaches the wrong people. It ships to
everyone at merge, leaks through the one path nobody gated, or splits a feature in half across two
flags, and in an experiment it contaminates the results. Every other pass checks what the code
does; this one checks who it does it for. Agent-written code misses it easily: the task describes
the behaviour, rarely the flag it should sit behind.

## Left to the skill running it

What a finding becomes. Putting a new piece behind the feature's existing gate, on the path that
missed it, is usually a clear fix. Whether to gate something new, which flag, and how to roll it
out is the user's call or the author's.
