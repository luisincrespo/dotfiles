# Remote fixer

A hosted agent that watches one PR and pushes fixes for its failing CI checks, reacting to GitHub
events, so CI keeps getting fixed while no local session is running. `pr-babysit` stays in charge of
the PR; the fixer is a helper it starts, watches, takes work back from, and stops. Read this file
when local config's `remote_fixer` covers the repo, or when `state.remote_fixer` records one.

Only for a PR whose head branch is in the repo itself, not a fork (`origin/<source_branch>` names
the wrong repo for one), and not in a `REBASE_SYNC_REPOS` repo, whose rebase-and-force-push sync
can't share a branch with a second writer. Either → run every phase locally.

## What each side owns

| | Remote fixer | `pr-babysit` |
|---|---|---|
| Failing lint, format, typecheck, build and unit-test checks, and those checks' annotations (Phase 2.0, item 4) | fixes them | watches; takes one back (below) |
| e2e, integration and flaky checks (retry once) | leaves them | owns |
| Keeping the branch current with its base, and conflicts | leaves them | owns |
| Every review comment, human or bot | leaves it: no fix, reply or resolve | owns, as Phase 2 says |
| SonarQube, Danger, title, description, screenshots | leaves them | owns |
| State file, `deliver`'s ledger, handoff to `pr-merge` | — | owns |

A check belongs to one side at a time. Two agents fixing the same failure push two commits for it,
and the second usually breaks the first.

## The rules the fixer runs under

The adapter hands these to the fixer verbatim. They are the contract; an adapter renders them for
its vendor but never loosens one.

- Fix only failing lint, format, typecheck, build and unit-test checks. Leave e2e, Cypress,
  integration, deploys, and cancelled or flaky runs alone.
- Leave every review comment alone, from people and from bots: don't fix it, reply to it, or
  resolve its thread.
- Never ask anything. If a failure isn't clearly fixable, leave it, and say so.
- Before verifying, install what the failing check needs the way its CI workflow does. Verify each
  fix with the command that check runs, after your last edit, and don't push a fix you couldn't
  verify.
- Fix the source rather than the test, unless the test itself is wrong; say so when you change one.
- Push only to the PR's own branch, as new commits on top of it. Fetch it right before pushing, and
  if it moved, build on the new head. Never merge or rebase the base branch into it, never
  force-push, and never open a new branch or PR.
- After two failed attempts on the same check, stop trying that check.
- When told to leave a check alone, stop working on it, from then on.
- When told to stop, unsubscribe from the PR and cancel any check-in you scheduled.

## State

`state.remote_fixer`, `null` until the first start:

```json
{"adapter": "<skill>", "session_id": null, "started_at": null, "phase": null,
 "status_since": null, "takebacks": [], "reason": null, "pilot": null}
```

`phase` is `starting`, `running`, `stopping`, `stopped` or `unavailable`; `reason` says why for the
last three. `takebacks` lists the checks `pr-babysit` owns again. `pilot` holds the record below,
when the entry's `pilot` is set. Merge what the adapter returns into this object; never replace it.

## Starting

On the first cycle that finds the PR open and config covering the repo:

1. Set `phase: "starting"` and **write the state file** before calling the adapter, so an
   interrupted start is visible to the next cycle.
2. Call the adapter's `start` with the PR's URL, merge what it returns, set `phase: "running"`, and
   write the state file again at once.
3. If it returns `unavailable`, record the reason, say it once, and run every phase locally. When
   it also returns a `session_id` (a session that may still subscribe later), stop that session
   first, as below, before fixing anything locally.

A cycle that finds `phase: "starting"` left over calls `start` again: the adapter looks for a run
it already started for this PR before starting a new one, so `start` launches once per PR.

## Coordinating, each cycle

- **Pull its commits** with `../../deliver/refs/shared-checkout.md`'s "bring it to the PR's head",
  which every checked-out cycle runs anyway. If that moved `HEAD`, re-run Phase 0.1 so every later
  phase works on the current head.
- **A push from the checkout** follows that file: holding the lock, fetch and merge
  `origin/<source_branch>` just before, verify again if that changed the tree. A conflict →
  `git merge --abort`, keep the local commits, batch it, and make no more changes this cycle. A push
  rejected because the fixer moved the branch → the same again once; rejected again → batch it.
- **A push without the checkout** (Phase 0.5c's base merge) follows that file's no-checkout recipe
  instead: pinned SHAs, a plain push, and a fresh start from the fetch when it's rejected. It never
  merges anything into the checkout.
- **Read its status** through the adapter's `status` since `status_since`, then set `status_since`
  to the newest event it returned, so nothing is counted twice. Name its pushes in the cycle report;
  the adapter says how to recognize its commits.
- **Take a check back** when the fixer says it left it (not clearly fixable, couldn't verify, two
  failed attempts), or when the check has been red for over 20 minutes with no fixer push for it.
  The loop's fallback wakeup still runs cycles when the PR is quiet, so a stalled fixer gets caught.
  Tell the fixer through the adapter's `exclude`, and add the check to `takebacks` once a later
  `status` shows the fixer confirming it; from then on fix it locally, as Phase 1.2 says, for the
  rest of the PR, on any head. Until it's confirmed, the check stays the fixer's. No confirmation
  after two cycles, or `exclude` failing twice → stop the fixer.
- **A rule break stops it.** A reply or resolve on any thread, a rebase or force-push, a base merge,
  a push to another branch, or a fix to a check it doesn't own: stop the fixer, batch what it did
  with the evidence, and don't restart it on this PR.

## Stopping

Stop through the adapter's `stop`:

- before handing off to `pr-merge` (Phase 4): by then CI is green and an approval has landed, so the
  fixer has nothing left to do, and merging ends in `post-merge-cleanup`, which deletes the state
  file;
- when the PR merges or closes elsewhere (Phase 0.3);
- when the user calls the babysit off, or config no longer covers the repo;
- on a rule break, or a start that came back `unavailable` with a session.

Set `phase: "stopping"` until the adapter returns `stopped`: unsubscribed, and every check-in it
scheduled cancelled. Until then, take no check back, hand nothing to `pr-merge`, and delete no
state. If it's waiting on an approval, tell the user where; if `stop`
failed, retry it next cycle. Then `phase: "stopped"`, and copy the pilot record (below) before any
state file is deleted.

## Recording, while `pilot` is set

The pilot judges the fixer on real PRs, so each cycle adds to `state.remote_fixer.pilot`:

- `pushes`: one entry per fixer push: `sha`, `pushed_at`, `check`, `verified` (the command and its
  result, when the status shows the check's own command passing after the last edit; else `null`),
  `ci_after` (that commit's checks, read by SHA with
  `gh api repos/<repo_id>/commits/<sha>/check-runs` on later cycles), and `touched_tests`, from
  `git log -1 --name-only --format= <sha>` after the pull.
- `rule_breaks`: what happened and the evidence (the log line, the comment or commit link).
- `takebacks`: the check, when, and why it came back.
- `races`: local pushes rejected because the fixer moved the branch, and failures both sides pushed
  a fix for.
- `wakes`: each wake the status reports, with its time and trigger (a GitHub event, a check-in it
  scheduled, a message), and whether it ended with no action.
- `unattended`: fixer pushes with no local cycle within 30 minutes after them. A fixer push changes
  the PR's head commit, which is in the Monitor signature (Phase -1), so a running `pr-babysit`
  wakes within minutes; a 30-minute gap means nothing local was watching when the fix landed.
- `red_to_green`: for each failing check, the first cycle that saw it red, the first that saw it
  green, and who pushed the fix in between: the fixer, `pr-babysit`, someone else, or `unknown`.
- `idle_resumes`: GitHub-triggered wakes more than an hour after the previous one, which show the
  subscription surviving.

Before any state file is deleted, copy the record to
`~/.claude/cache/deliver/remote-fixer-pilot/<repo-with-slashes-as-dashes>-<number>.json`.

## The pilot report

Delete this section once the pilot is decided. When the user asks for the report:

1. Read every record in that folder. For each PR, show every fixer commit with its diff, and ask the
   user to mark it accepted or rejected.
2. Write one row per PR: pushes, verified pushes, rule breaks, takebacks, races, wakes (and how many
   with no action), unattended fixes, idle resumes.
3. Give the verdict. The fixer stays on for the repo only if there were no rule breaks, no push the
   user rejected, every push verified or held back, at most one race, wakes the user considers worth
   paying for, and at least one unattended fix that held. Otherwise: tune it (model, rules, noise)
   and run again, or drop it.
