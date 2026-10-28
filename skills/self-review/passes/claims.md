# Checking a claim before acting on it

Some kinds of claim are where reviews go wrong, whoever makes them: you, a review pass, a second
model, a bot, the author, a ticket. Check each one before acting on it, whether that means drafting
a comment, applying a fix, or repeating it in a commit message or PR description.

## The claims that need checking

- **Absence** ("this will never exist"): search everywhere it could come from before saying so,
  including the other branches of a stack.
- **Equivalence** ("this changes nothing observable"): check side-effect ordering separately from
  rendered output. When a change alters how many rows stand for one thing, check every reader that
  iterates them, inside the diff or not: work fanned out per row (a job queued per row's key)
  shrinks with it.
- **Redundancy** ("this buys nothing"): check whether the thing is load-bearing for a documented
  invariant. A `[]` dep array plus an `eslint-disable` is usually protecting a "runs exactly once"
  contract.
- **Detectability** ("this would only show up as X"): follow the bad case down every early return.
  An empty-input path that skips the check makes it silent, not visible as X.
- **Implementability** ("we could just pass X here"): follow the value to whoever consumes it, since
  threading a field through a command whose only handler ignores it relocates the problem instead
  of fixing it. Then follow it to whoever else can supply it: a framework hook that reads request
  input before the handler's result lets the caller set the value. A fix offered in passing ("if
  not, we could…") gets the same check as the main ask.
- **Free to tighten** (a type change): enumerate producers **including tests**. Loosely typed spec
  helpers (`Array<{ field: string }>`) are what a production-only sweep misses, so "free to
  tighten" becomes a red build.
- **How an external engine behaves** (a template language's escaping or scoping, a query planner, a
  provider's API): check it against that engine when a read-only call is available. A repo
  convention is a hint, not proof.
- **Causation** ("this is what caused it"): when a change bundles fixes for several diagnosed
  causes, confirm each is load-bearing by removing it alone and re-testing. A cause inferred from
  reading code, rather than isolated by experiment, may not exist, and a fix for a non-existent
  cause still passes every test written for it. The same goes for a causal story you inherited:
  before repeating a brief's or ticket's account of what went wrong, check it against the code, and
  trace the whole path rather than stopping at the one suspect it names. Ruling that suspect out is
  not the same as finding the cause, and a misattributed cause ships as documentation and
  invalidates the test plan built on it.
- **Protection** ("this test guards the fix"): check that it would fail if the bug came back, by
  walking the fixture through the broken version of the code. A bot's "this proves X" is a claim,
  not evidence.

A caveat you notice in your own suggestion or fix gets said, even when it looks minor.

## Evidence that isn't

- **A filter over a failed command's output.** Check the command actually ran before trusting what
  its output does not contain: a grep for errors returns nothing when the compiler never started,
  and "no findings" and "never checked" look identical afterwards. Confirm the exit code and that
  the output has the shape you expect, then filter.
- **A check that doesn't enforce what you're claiming.** Verify code the way CI will, not just the
  way that's quickest. A test runner that strips types instead of checking them (vitest via esbuild,
  say) will happily pass code that fails the build, so a green scratch test proves nothing about
  types: run the real build or typecheck (`nx build <package>`, `tsc --noEmit`, `mypy`,
  `cargo check`, …). Code that doesn't compile costs a CI round and whoever handed it over their
  credibility.

## Left to the skill running it

When the check happens, and what a claim that fails it becomes: cut, turned into a question, or
handed to the user.
