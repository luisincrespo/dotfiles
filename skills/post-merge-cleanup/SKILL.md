---
name: post-merge-cleanup
description: >-
  Clean up after a merged MR/PR. Advances stacked dependents (retarget off the disappearing base,
  merge forward, promote the next out of draft), deletes the merged branch and its worktree,
  clears the per-PR state file, moves the tracker ticket to Done, and turns the task's deferred
  items into follow-ups, proposing them for approval before filing anything. Normally triggered by
  pr-merge.
allowed-tools:
  - Bash(glab api:*)
  - Bash(glab mr list:*)
  - Bash(glab mr update:*)
  - Bash(gh api:*)
  - Bash(gh pr list:*)
  - Bash(gh pr edit:*)
  - Bash(gh pr ready:*)
  - Bash(gh issue create:*)
  - Bash(git remote get-url:*)
  - Bash(git worktree list:*)
  - Bash(git worktree remove:*)
  - Bash(git worktree unlock:*)
  - Bash(git worktree prune:*)
  - Bash(git branch -D:*)
  - Bash(git push origin --delete:*)
  - Bash(git ls-remote:*)
  - Bash(git show-ref:*)
  - Bash(git for-each-ref:*)
  - Bash(git status:*)
  - Bash(git rev-parse:*)
  - Bash(git merge origin/:*)
  - Bash(git merge --no-edit:*)
  - Bash(git commit --no-edit)
  - Bash(git push)
  - Bash(git -C:*)
  - Bash(jq:*)
  - Bash(cat:*)
  - Bash(rm -f ~/.claude/cache/deliver/:*)
  - Read
  - ExitWorktree
  - Skill(voice)
  - mcp__claude_ai_Atlassian__getJiraIssue
  - mcp__claude_ai_Atlassian__getTransitionsForJiraIssue
  - mcp__claude_ai_Atlassian__transitionJiraIssue
  - mcp__claude_ai_Linear__get_issue
  - mcp__claude_ai_Linear__list_issue_statuses
  - mcp__claude_ai_Linear__save_issue
---

# post-merge-cleanup

Runs after a **confirmed merge**. This is the last stage of the `deliver` pipeline (create → `pr-open`, babysit → `pr-babysit`, merge → `pr-merge`). Platform detected from `git remote get-url origin`. Write **"PR"** on GitHub, **"MR"** on GitLab.

Do everything from the **main worktree root**, never from inside the worktree being removed.

## Args

- `<source_branch>`: the merged branch to clean up (required; `pr-merge` passes it). If omitted, resolve from the merged MR/PR ref.
- `<target_branch>`: the branch it merged into (the new base for any dependents; usually the default branch).
- `<number>`: the merged MR/PR number (for the state-file name).
- `--task-slug <slug>`: the `deliver` task, so its deferred-items ledger can be turned into follow-ups.

## Config

> **Local overrides.** Values below are portable defaults. If `~/.agents/local/config.json` exists,
> its keys override or extend them (schema: `~/.agents/local/config.example.json`); any key absent
> there keeps the default. `config.json` is machine-local and never committed.

- **PR state file**: `~/.claude/cache/deliver/pr-<platform>-<repo-with-slashes-as-dashes>-<number>.json`
- **Task ledger**: `~/.claude/cache/deliver/task-<repo-with-slashes-as-dashes>-<slug>.json`

## Step 0: Identify the main worktree root
First entry of `git worktree list` → `<main_root>`. Run every git command below as `git -C <main_root> …` so it doesn't depend on the (possibly about-to-be-deleted) current directory.

**Worktree-isolated sessions.** If this session is sandboxed to the worktree being cleaned up, `git -C <main_root> …` is refused. Do the non-git steps first (remote branch, state file, ticket, follow-ups), then call `ExitWorktree` — it drops the session to the main root, lifts the sandbox, and can delete the worktree + branch in one move.

**`ExitWorktree` only handles worktrees `EnterWorktree` created *in this session*.** When the worktree is simply the session's launch directory (the common case for a session started with `cwd` already inside one), `ExitWorktree` returns `No-op: there is no active EnterWorktree session to exit` and changes nothing. That is not an error to work around — fall through to the ordinary Step 3/4 removal below. A squash-merged branch will be reported as having N unmerged commits: verify the squash commit is on the target and the change is present there, then confirm with the user before `discard_changes: true`.

## Step 1: Stacked-PR guard — retarget, merge forward, promote
When a PR in a stack merges, the rest of the stack must be advanced **before** deleting `<source_branch>` (deleting a base branch **closes** dependents on GitHub with no auto-retarget, and you can't reopen while the base is gone):
- **Retarget dependents.** GitHub: `gh pr list --base <source_branch> --state open --json number` → each `gh pr edit <number> --base <target_branch>`. GitLab: `glab mr list --target-branch <source_branch> --state opened` → `glab mr update <iid> --target-branch <target_branch>`.
- **Merge the target forward into each dependent's head** so its diff is clean against the new base. If the pre-commit hook fails only on files dragged in from the target that belong to a separate toolchain (e.g. `apps/extension`'s own lint) and are already CI-green, commit the forward-merge with `--no-verify` (the **only** sanctioned `--no-verify`; CI re-runs on push).
- **Promote the new front-of-stack** out of draft: `gh pr ready <number>` / `glab mr update <iid> --ready`. It's now up for review → draft (don't send) its review-request ping via `Skill(voice)`, per `pr-open` Step 7.
- Only after all dependents are retargeted is it safe to delete `<source_branch>`. (Recovery if you slipped: recreate the branch at its last sha `git push origin <sha>:refs/heads/<source_branch>`, reopen the closed PR, retarget, then delete.)

## Step 2: Delete the remote branch
If it still exists (`git ls-remote --exit-code --heads origin <source_branch>`): `git push origin --delete <source_branch>`. Some repos auto-delete on merge — already gone → skip without error.

## Step 3: Remove the worktree
`git worktree list --porcelain` → the worktree whose branch is `<source_branch>`. If a separate worktree `<wt_path>` exists (not `<main_root>`):
- **Removing the session's own worktree (current cwd) is fine and expected** once its PRs are done. Run from `<main_root>`. The shell survives: the harness re-resolves the working directory after every command and falls back to the repo root once the worktree is gone (`Shell cwd was reset to <repo root>`), so you can keep running commands afterwards. Do not warn the user that removal will end the session.
- **Chain this one.** The cwd reset happens *between* invocations, so `cd <main_root> && worktree remove && branch -D && worktree prune && <verification>` in a single call is what lets you confirm the result while the shell is still somewhere valid. This is the documented exception to the separate-commands rule below.
- Locked (session/dev worktrees usually are) → `git -C <main_root> worktree unlock <wt_path>` first.
- Remove: `git -C <main_root> worktree remove --force <wt_path>` (keep `--force` — clears the checkout guard and untracked `node_modules`/`dist`/`.nx`).
- **Fallback** if it still errors `Directory not empty`: `rm -rf <wt_path>` then `git -C <main_root> worktree prune`. Scope `rm -rf` to the exact `<wt_path>` (may need a one-time approval — expected).
- Run destructive steps as **separate commands** (worktree remove → local branch → remote branch), not chained — a combined destructive command is more likely to trip the permission classifier.

**Stop the worktree's build daemon before removing it (Bazel especially).** `git worktree remove` does not touch it, so it survives as an orphan pointing at a path that no longer exists — a multi-GB JVM holding thousands of file descriptors until its idle timeout (`--max_idle_secs` is 3h). Before removing, from the workspace dir inside the worktree, run the repo's env setup if it has one, then `bazelisk shutdown` (or `bazel shutdown`). If the worktree is already gone, find and stop it by workspace:

```bash
pgrep -f bazel | while read p; do
  ws=$(ps -o args= -p "$p" | grep -o '\-\-workspace_directory=[^ ]*' | cut -d= -f2)
  [ -n "$ws" ] && [ ! -d "$ws" ] && kill -TERM "$p"
done
```

Killing a Bazel server loses nothing — the disk cache lives in `~/Library/Caches/bazel`, not the server. Nx has the same shape but is cheap; Bazel is the one worth the step.

**Enough open file descriptors will make removal fail partway.** `git worktree remove` reports `Too many open files in system` and leaves the directory behind, deregistered but intact — and `rm -rf` then also fails. That is a *system-wide* limit, so the cause is usually not this repo: check `lsof | awk '{print $1}' | sort | uniq -c | sort -rn | head` before blaming the worktree. A wedged VM (Docker Desktop's `com.apple.Virtualization.VirtualMachine.xpc`) once held 237k of 262k descriptors. Fix the hog, then retry — do not force-delete around it.

## Step 4: Delete the local branch
If it still exists (`git -C <main_root> show-ref --verify --quiet refs/heads/<source_branch>`): `git -C <main_root> branch -D <source_branch>` (the merge is confirmed on the server, so `-D` is correct even if `<main_root>` hasn't pulled the merge commit).

**Also delete the `worktree-<name>` placeholder branch.** Creating a worktree leaves a second branch named after the *directory* (e.g. `worktree-abc-2357-init-starter-agents`) alongside the real `<source_branch>`. It holds none of the work and survives Step 4, so `git -C <main_root> branch --list "worktree-*"` and delete the one matching the worktree just removed. Leave the others — they belong to live worktrees.

**Never touch stashes.** `git stash` is repo-global, not per-worktree, so a stash listed here probably belongs to unrelated work. Check `git -C <main_root> stash list` only to confirm you have not disturbed it; never drop one during cleanup.

## Step 5: Remove the PR state file
`rm -f ~/.claude/cache/deliver/pr-<platform>-<repo-dashes>-<number>.json`.

## Step 5.5: Ticket → Done (last unit)
Run only when `--task-slug` is set, this was the **last** unit (all `units[]` in the ledger `status:"merged"`), and `ticket_sync.enabled == true` with a `task_ref` ticket. The task is now fully merged → move its ticket to Done: Read `refs/ticket-status.md` and follow it with target intent **`done`** (forward-only — skips silently if already Done, or if the tracker MCP is absent this session). Autonomous by default; if the ledger's `ticket_sync` carries a done-confirm flag, propose the transition and wait for approval instead. This is the definitive completion moment — `deliver` can't do it (the merge happened detached inside `pr-babysit`'s `/loop`), so it lives here.

## Step 6: Raise deferred follow-ups (NEW — approval-gated)
This is the pipeline's loop-closer beyond a plain merge + cleanup. Only run when `--task-slug` is set AND this was the **last** unit of the task (all `units[]` in the ledger are `status:"merged"`). If earlier units remain open, skip for now — the last unit's cleanup will do it.

1. Read `deferred_items` from the task ledger. Empty → announce `No deferred follow-ups for this task.` and skip.
2. For each item, draft a concise follow-up (title + one-line why + risk + suggested owner). **Propose the full list to the user and ask which to file** — filing tickets/issues is outward-facing and often cross-team, so it always needs explicit approval (never auto-file; ties to the user's "scope: low-lift only, document the rest" and "no outward action without approval" habits).
3. On approval, file the approved ones and skip the rest:
   - GitHub issue: `gh issue create --title "<title>" --body "<body>"`.
   - Jira/Linear, or a repo that ships its own ticket skill: delegate to that skill / MCP rather than guessing field values (the harness will surface any needed tool). Do NOT invent tracker field values.
   - If the user prefers no ticket: leave a written hand-off note (a short markdown block they can paste), don't file.
4. Announce what was filed with links; leave the un-filed items in the note. Then clear the filed items from the ledger (keep the un-filed ones for later).

## Step 7: Announce + housekeeping
- `🧹 Deleted branch <source_branch> and worktree <wt_path>.` (omit the worktree clause if there wasn't one).
- **Heads-up if the session ran inside the removed worktree**: that dir no longer exists, so tell the user to `/loop stop` and `cd <main_root>`.
- **If the merged PR carried the repo's needs-testing label** (`staging_verification.needs_testing_label` in local config), set `needs_staging_verification: true` on its unit. The deploy gets tested later, in another session, so this step only records it — `deliver` B5 is what acts on it.
- Once every unit's PR is merged and cleaned, mark the task ledger done. **Keep the ledger** while any unit still has `needs_staging_verification: true` and `staging_verified: null` — deleting it there would strand the pending verification; delete only when no un-filed follow-ups and no pending verification remain.

**Session / integration worktree.** The same recipe (Steps 3–4) applies to the worktree this session runs in once all its PRs are merged/closed — remove it decisively even though it's the current cwd; that's normal end-of-session cleanup. Hard prerequisite: no *unpushed, unmerged* work — verify `git -C <wt> status --porcelain` is empty and its HEAD is merged or still on a remote branch (`git -C <wt> for-each-ref --format='%(upstream:short)' refs/heads/<branch>`) before removing.

## Step 8: Capture learnings (self-educate)
Once cleanup finishes, ask whether anything about how this ran warrants a durable edit. Never invent one — "nothing to capture" is the usual answer and deserves a line, not a paragraph.

What recurs at this stage: a stacked-dependent step that needed doing by hand; a tracker state that wouldn't map to an intent; a follow-up that should have been raised earlier, or shouldn't have been raised at all.

Route it: repo- or employer-specific facts → `~/.agents/local/config.json`; a lesson that would hold at any job → this skill; a durable one-off → a memory. **When `deliver` invoked you**, hand it up with your report instead of editing — `deliver`'s end-of-run reflection owns the routing, and two skills acting on one lesson records it twice. **Show the exact edit and apply it only once the user confirms**; prefer refining an existing line to adding one, and if a section grows, cut a sentence elsewhere.

## Hard constraints

- Branch/worktree deletion happens ONLY here, only after a confirmed merge, only for the merged `<source_branch>`, always from `<main_root>`. Never delete an unmerged branch. Retarget stacked dependents (Step 1) **before** deleting the base.
- Never `--force` a push. `--no-verify` only for the sanctioned Step-1 forward-merge case. Leave `rm -rf` out of any broad allowlist — `worktree remove --force` covers the normal case; the `rm -rf` fallback stays prompt-gated.
- **Never file a follow-up ticket/issue without explicit user approval** (Step 6). Never send Slack messages.
- The **Done** ticket transition (Step 5.5) is forward-only and gated on `ticket_sync.enabled` — never move a ticket backward or fight a manual status; skip silently if the tracker MCP is absent.
- **Permissions note.** `git push origin --delete`, `git worktree unlock`, `git worktree prune`, and `gh issue create` may prompt the first time — expected; an agent can't self-grant them. Add Bash rules yourself for zero-prompt cleanup if desired; keep `rm -rf` out.
