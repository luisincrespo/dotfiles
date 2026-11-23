# Fixing a regression

A regression is behavior that used to work and stopped, so a change caused it: a commit, a deploy or
a flag flip. Find that change before theorizing about the code. It says where to look, whose fix it
is and how urgent it is, and a cause read from code alone may not exist (`claims.md`, *Causation*).

It applies when a task is a bug in behavior that used to work, and when exercising or verifying a
change turns up a failure the change didn't cause. A bug with no last-good point (it never worked)
skips to step 4.

## In this order

1. **Find when it broke.** Bisect between a known-good and a known-bad point: `git bisect run` with
   a script that reproduces the failure and exits non-zero on it. When it only reproduces in a
   deployed environment, bisect the deploys or releases first, then the commits inside the bad one.
   Then say which release or deploy carries it: whether it's already in production or rides the next
   release decides how urgent the rest is.
2. **Find whose change it is**: this task's, a teammate's, or another session's or agent's (a
   sibling session, a bot's fix). Not this task's → tell its owner, with the commit, before fixing
   it yourself: they may know already or have a fix in flight, and their change is theirs to rework.
3. **Check whether a gate decides it.** Behavior behind a feature flag or experiment (LaunchDarkly,
   Statsig, a config switch) can break with no bad commit at all. Reproduce with the gate on and
   off, and read its change history around when it broke: a flag flip explains a failure that bisect
   can't find, and a gate on in one environment only explains "fails on staging, not locally". How
   to read a given repo's flags is that project's knowledge, in its skill or local config.
4. **Then find the root cause**, starting from what steps 1–3 found: the change's diff, under the
   gate state that breaks. Trace the whole path rather than the first suspect, and confirm the cause
   by removing it (`claims.md`, *Causation*).
5. **The fix comes with a regression test** that fails without the fix and passes with it: walk it
   through the broken code to check (`claims.md`, *Protection*). Without one, nothing stops the same
   change from breaking it again. Where a test truly can't be written (the failure only shows in a
   third party's system), the PR says why.

Steps 1–3's answers go in the brief or the report before any fix, each with its evidence: the first
bad commit or deploy, its owner, and the gate state that breaks.
