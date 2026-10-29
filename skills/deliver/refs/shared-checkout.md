# Shared checkout

A `deliver` task works in one worktree, and every unit's branch lives in it. The `deliver`
session's agents check out whichever branch they're changing, so several of the task's PRs can be
open and babysat at once while only one branch is checked out. `pr-babysit`, `pr-merge` and
`post-merge-cleanup` read these rules wherever they would change files.

## Who switches branches

**Only the `deliver` session.** `pr-babysit`, `pr-merge` and `post-merge-cleanup` never run
`git checkout <branch>` or `git switch`, inside a `deliver` task or out of one: a cycle that
checked out its own PR's branch would pull the ground out from under whatever was being changed
there. Restoring files with `git checkout -- <path>` or `--ours`/`--theirs` during a merge is fine;
moving `HEAD` is not.

## The checkout lock

Anyone about to change the checkout takes the lock **first**, then checks the state below while
holding it, so nothing can change between the check and the work. That includes the `deliver`
session: it holds the lock while it switches branches or has uncommitted changes, and releases it
once those are committed.

- **Its owner** is a token unique to each acquisition: `<skill>:<pr or task>:<random>`, made when
  the lock is taken. A skill holding it passes it to a skill it calls directly with
  `--lock-token <token>` (`deliver` to `pr-babysit --once`, `pr-babysit` to `pr-merge`, `pr-merge`
  to `post-merge-cleanup`), and the callee treats a lock naming that token as its own: it carries on
  without taking it again, and leaves releasing it to the taker. Anyone else, a sibling agent
  included, contends for it normally.
- **Take it:** `mkdir -p ~/.claude/cache/deliver/locks`, then
  `mkdir ~/.claude/cache/deliver/locks/<worktree-path-with-slashes-as-dashes>` (a plain `mkdir`
  fails when it already exists, which is what makes it a lock), then write
  `{"owner": "<token>", "pr": <number or null>, "at": "<time>"}` into `owner.json` inside it.
- **Release it** on every path out, failures included, and only when `owner.json` still names you:
  `rm -f …/owner.json` and `rmdir`.
- **Held by another owner** → treat the PR as not checked out this cycle. Never take over a lock
  because it's old: a long build or conflict resolution can hold it for a while. Held for over 30
  minutes → say once who holds it and since when, so the user can clear it if its session died.

## When a PR counts as checked out

With the lock held, `checked_out` holds for a PR when all of these do:

- the checkout has the PR's `source_branch` checked out;
- the tree is clean: `git status --porcelain` prints nothing, untracked files included, since
  `git add -A` would commit them and `worktree remove --force` would destroy them;
- no merge is in progress (no `MERGE_HEAD`).

**Before working in it, bring it to the PR's head:** `git fetch origin <source_branch>`, then
`git merge --ff-only origin/<source_branch>`. If local commits make it diverge, merge without
rebasing. A conflict there is between the branch's own local and remote commits, which no automated
step should pick between: `git merge --abort`, batch it for the user, and make no local change to
this PR until it's resolved. A pushed no-checkout merge, a remote fixer's commit or a teammate's push
all leave the local branch behind otherwise. If this moved the checkout past the head the cycle
read, read the PR again before going on, so every later step works on the head that's checked
out.

**Work that needs the PR's files runs only when checked out:** CI fixes (unless a remote fixer owns
them), AI-reviewer fixes, Danger coverage tests, conflict resolution, screenshots, and `pr-merge`'s
local verification. Every push from the checkout fetches and merges `origin/<source_branch>` just
before it, and verifies again when that changed the tree.

**Work that needs no checkout runs regardless:** reading CI, comments and annotations; reading a
file at the PR's head with `git show <head_sha>:<path>` (never the checkout, which may hold another
unit's version); replies and resolves; retrying a flaky job; the title and description, re-derived
from `origin/<target_branch>...origin/<source_branch>` after a fetch, never from `HEAD`; and
keeping the branch current with its base (below).

## Queuing work for a checkout

Work that needs the files but can't run now goes into the PR's state file, under `needs_checkout`,
as `{"what": "<the work>", "since": "<time>"}`, once per kind of work:

- **Write it to disk when you queue it,** not at the end of the cycle: a cycle that returns early
  otherwise loses it.
- **The state file may not exist yet** (a dependent never babysat, a PR merged straight from
  `pr-merge`). Create it with `pr-babysit`'s initial state (its Phase 0.4) first, then add the item.
- **Say once** that it's waiting for a checkout of `source_branch`. Don't batch it again every cycle.

`pr-babysit` runs queued items first whenever it finds the PR checked out (its Phase 0.7), and
removes each one once it's done or no longer applies.

## Keeping a branch current without a checkout

For a repo that syncs by merging (not in `REBASE_SYNC_REPOS`). This pushes objects, never touches
the checkout, and so needs no lock:

```bash
git fetch origin <target_branch> <source_branch> || exit 2
src=$(git rev-parse --verify origin/<source_branch>) || exit 2
tgt=$(git rev-parse --verify origin/<target_branch>) || exit 2
if git merge-base --is-ancestor "$tgt" "$src"; then echo "already current"; exit 0; fi
out=$(git merge-tree --write-tree "$src" "$tgt"); rc=$?    # never pipe it: a pipe hides rc
if [ "$rc" -eq 1 ]; then echo "conflicts"; exit 1; fi
if [ "$rc" -ne 0 ]; then echo "merge-tree failed ($rc)"; exit 2; fi
tree=${out%%$'\n'*}
sha=$(git commit-tree "$tree" -p "$src" -p "$tgt" -m "Merge origin/<target_branch> into <source_branch>") || exit 2
[ "${#sha}" -eq 40 ] || { echo "no commit to push"; exit 2; }
git push origin "${sha}:refs/heads/<source_branch>"
```

Run it as one command and act on its exit: 0 is done or already current, 1 is a conflict, 2 is an
error, anything else is a rejected push. **Never let the push run with an empty SHA:**
`git push origin ":refs/heads/<source_branch>"` deletes the branch.

- **Pin both SHAs once** and use them for the merge and the parents. Re-reading
  `origin/<source_branch>` in between could pair the old tree with a newer parent, and that push
  would fast-forward while dropping the newer commit.
- On a conflict, queue `resolve conflicts with <target_branch>`; on an error, batch it. A lockfile
  conflict lands here too, since regenerating one needs the files.
- A plain push, never forced. Rejected means the branch moved since the fetch: start again from the
  fetch next cycle.
- Keep the braces in `"${sha}:refs/…"`: in zsh, `$sha:r` is a modifier that strips the value, and
  the push sends a mangled ref.
- `commit-tree` runs no hooks. That's acceptable for a base merge, whose content is already on the
  base branch, and CI still runs on the push; it's also what keeps the merge off the checkout.

A `REBASE_SYNC_REPOS` repo rebases and force-pushes with a lease, which needs the checkout: queue
it.

## Running queued work

The `deliver` session runs it, between its own steps, holding the lock, and never with uncommitted
changes. For each in-flight unit whose state file has `needs_checkout` items:

1. Note the branch checked out now, then check out the unit's branch, in the ledger's `worktree`
   (`git -C <worktree> …`).
2. Run `Skill(pr-babysit) <pr> --once --task-slug <slug> --lock-token <token>`. It finds the PR
   checked out, runs the queued items first, and a merge-ready PR goes on to `pr-merge` the usual
   way, after a fresh read of CI and comments.
3. Re-read the ledger. If the worktree is still registered (`git worktree list`), check the noted
   branch back out there; if the last unit's cleanup removed it, there's nothing to restore.
4. Release the lock, and say what ran.

Outside `deliver`, `pr-babysit` says which branch to check out to let it do the work, once.
