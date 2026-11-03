# Documentation pass

A check that documentation a diff adds or changes is as short as it can be while still giving its
reader what the code doesn't. It covers markdown docs (a README, a `CLAUDE.md` or `AGENTS.md`, a
`docs/` page) and doc comments, for human and agent readers. It applies to any diff, your own or
someone else's; the skill that reads it decides what happens to the findings.

## When it applies

When the diff adds or changes a markdown doc, or doc comments beyond a line or two. None → it
doesn't apply. Say so in one line rather than skipping it silently.

## What to look for

The test for each part of a doc: does it help its reader understand a decision or get a task done
without reconstructing the implementation? Setup steps, a recipe, a contract, how pieces across
files fit together all pass it. Narrating what the code says doesn't.

- **Restating the code.** A step-by-step walkthrough of what a function does, a markdown list of
  parameters or fields, an enumeration of exports, a file listing that only reproduces the tree. A
  map that says where to start, or where a common change goes, is navigation and stays.
- **Too much of a good thing.** A section that repeats another's point, three examples where one
  shows it, depth past what the reader needs to act. Judge the doc as a whole, not only line by line:
  every sentence can be new and the doc still twice as long as it should be.
- **The obvious, explained, and the throat-clearing.** Background any engineer on the codebase has,
  a definition of a common term, "This document describes…", "It's important to note that…", a
  closing summary of what the doc just said.
- **Agent instruction files** (`CLAUDE.md`, `AGENTS.md`, and their nested copies): every line loads
  into every session's context. A line repeating what a parent instruction file or the global rules
  already say is a finding; must-follow constraints, the commands to build, run and verify, and their
  prerequisites stay where an agent will see them; background goes behind a link, not inline.
- **Doc comments.** Where the repo's or the user's rules require one on every symbol or parameter,
  the check is length, never existence: each says what the name and type don't, in as few words as it
  takes ("the user's id" on `userId: string` restates; "an id from the auth provider, not ours" adds).
- **Something a reader will need, missing.** Only for a concrete reader task or risk: a command
  nobody could guess, an invariant whose breakage fails quietly, a decision someone will otherwise
  reverse. Propose the wording from evidence in the diff or the PR; when the reason behind a choice
  isn't known, ask rather than invent one.

Where the repo's or the user's rules say what goes in which file, a sentence in the wrong one is a
finding too: move it, don't keep both.

## The bar for a finding

Each finding quotes the sentence or section and says what to do with it: cut it, with where the
reader already gets it ("the `fetchBrand` doc comment says this", "these four lines of the function
body"), or shorten it, with the shorter wording shown. Repeated boilerplate across a doc is one
finding, not one per instance. Not "this could be more concise": a finding names what to remove.

## Why it's a pass of its own

Correctness review doesn't read docs, and the convention sweep checks where things go, not how much
is said. Over-long docs cost twice: readers skim them and miss the one line that mattered, and every
sentence that restates the code goes stale the next time the code changes, with nothing to flag it.
Agent-written docs run long readily, narrating the code they were just written from, and agents
reading them pay for every extra line in context.

## Left to the skill running it

What a finding becomes. A cut of a restatement or a repeat is usually a clear fix; restructuring a
doc, or deciding a missing decision is worth recording, is a judgment call for the user or the
author.
