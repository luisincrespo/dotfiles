---
name: pr-merge
description: >-
  Merge one open, review-complete MR/PR. Re-verifies every condition (approved, threads resolved,
  CI green, platform-mergeable, not draft), runs a local pre-merge check against the merged state
  to catch semantic conflicts CI missed, merges with the repo's enforced strategy, then triggers
  post-merge-cleanup. No-ops with "not ready" if any condition fails, so it is safe to call
  speculatively.
allowed-tools:
  - Bash(glab api:*)
  - Bash(glab mr view:*)
  - Bash(glab mr merge:*)
  - Bash(gh api:*)
  - Bash(gh pr view:*)
  - Bash(gh pr merge:*)
  - Bash(gh repo view:*)
  - Bash(git remote get-url:*)
  - Bash(git status:*)
  - Bash(git rev-parse:*)
  - Bash(git branch --show-current)
  - Bash(git fetch origin:*)
  - Bash(git merge-base:*)
  - Bash(git merge-tree:*)
  - Bash(git merge --no-ff:*)
  - Bash(git merge --abort)
  - Bash(git rebase origin/:*)
  - Bash(git rebase --abort)
  - Bash(git rebase --continue)
  - Bash(git reset --hard:*)
  - Bash(git grep:*)
  - Bash(git checkout --ours:*)
  - Bash(git checkout --theirs:*)
  - Bash(git diff --name-only:*)
  - Bash(git rev-list --count:*)
  - Bash(git commit --no-edit)
  - Bash(git push)
  - Bash(git push --force-with-lease origin:*)
  - Bash(npx nx affected:*)
  - Bash(npx nx eslint:lint:*)
  - Bash(npx tsc:*)
  - Bash(npx prettier --write:*)
  - Bash(pnpm install)
  - Bash(pnpm lint)
  - Bash(pnpm test:*)
  - Bash(pnpm build:*)
  - Bash(jq:*)
  - Bash(cat:*)
  - Skill(post-merge-cleanup)
  - Read
---

# pr-merge

Merges one open MR/PR **only when every condition holds**, after a local verification against the merged state. This is the merge stage of the `deliver` pipeline (create → `pr-open`, babysit → `pr-babysit`, cleanup → `post-merge-cleanup`). Platform detected from `git remote get-url origin`. Write **"PR"** on GitHub, **"MR"** on GitLab.

**Safe to call speculatively.** `pr-babysit` invokes this whenever a cycle looks plausibly ready; this skill is the authoritative gate — it re-checks all conditions and simply returns "not ready — keep watching" if any fails. It never merges on partial confidence.

## Args (all optional)

- `<mr-ref>`: URL, `!123`/`#123`, or branch name. Default: current branch.
- `--task-slug <slug>`: passed through to `post-merge-cleanup` so it can raise the task's deferred follow-ups once the whole task is merged.

## Config

> **Local overrides.** Values below are portable defaults. If `~/.claude/local/config.json` exists,
> its keys override or extend them (schema: `~/.claude/local/config.example.json`); any key absent
> there keeps the default. `config.json` is machine-local and never committed.

- `PROTECTED_BRANCHES`: `["main", "master", "stage-*"]` + `protected_branches_extra`. Entries are **glob patterns**: a bare name matches exactly, `*` matches any run of characters. A branch is protected if it matches any entry — so `rc-*` covers every dated release candidate, and a literal `prod` still matches only itself.
- `REBASE_SYNC_REPOS`: `[]` + `rebase_sync_repos` — derive `SYNC_STRATEGY = "rebase"` if `repo_id` matches, else `"merge"` (only relevant if a conflict surfaces here).
- **State file**: `~/.claude/cache/deliver/pr-<platform>-<repo-with-slashes-as-dashes>-<number>.json` (shared with `pr-babysit`; read `last_pipeline_id`).

## Phase 0: Resolve + guards

1. **Platform**: `git remote get-url origin` → `github`/`gitlab` (else stop).
2. **Resolve** the MR/PR and map to unified fields (same shape as `pr-babysit` 0.1): `number`, `repo_id`, `source_branch`, `target_branch`, `web_url`, `state`, `head_sha`, `is_draft`, `has_conflicts`, `mergeable`. GitHub: `gh pr view [<arg>] --json number,headRefName,baseRefName,url,state,headRefOid,isDraft,mergeable,mergeStateStatus,reviewDecision`. GitLab: `glab mr view [<arg>] --output json`.
3. **Branch guard**: abort if `source_branch` matches `PROTECTED_BRANCHES`.
4. **Terminal**: `state != opened` → announce (already merged/closed) and return; if merged and `--task-slug` set, still invoke `Skill(post-merge-cleanup)` once to finish any pending cleanup + follow-ups.

## Phase 1: Merge conditions (ALL must hold; else return "not ready")

1. `state == opened`.
2. **Approved**: GitLab `glab api "projects/<repo_id>/merge_requests/<number>/approvals"` → `approved: true` and `approvals_required` met; GitHub `reviewDecision == "APPROVED"`.
3. **All threads resolved**: GitLab every `resolvable` discussion resolved; GitHub every review thread `isResolved == true` (issue-comment pseudo-threads don't count, but each new one must be in `state.addressed_thread_ids` — `pr-babysit` records replies there).
4. `state.last_pipeline_id` status == `success`.
5. **Platform mergeable**: GitLab `merge_status == "can_be_merged"` AND `!has_conflicts` AND `blocking_discussions_resolved`; GitHub `mergeable == "MERGEABLE"` AND `mergeStateStatus ∈ ["CLEAN", "HAS_HOOKS"]` (NOT `BLOCKED`/`BEHIND`/`DIRTY`/`UNSTABLE`).
6. **Local conflict check**: `git fetch origin <target_branch>` then `git merge-tree HEAD "origin/<target_branch>"` — no markers AND exit 0 → pass; else → Phase 3 (conflict).
7. `is_draft == false`.

Any condition unmet → announce which one and **return** `Not merge-ready (<reason>) — keep watching.` (no mutation).

## Phase 2: Merge (when all conditions pass)

**Merge with confidence — don't hesitate.** Once the conditions hold and the local verification passes, merging is the correct, expected action. Don't stall or re-confirm with the user "to be safe" — the conditions ARE the safety check. (Only hold off if a condition is genuinely unmet, or the user explicitly said not to merge.)

CI passed on the source alone; a semantic conflict with the current target can still break lint/build/tests. Verify against the merged state first:

1. Announce: `✅ !<number> looks mergeable. Running pre-merge local verification...`
2. **Pre-merge local verification**:
   - Preconditions: clean working tree, current branch == `source_branch`. Else announce and return (don't merge).
   - **Scope the risk first: intersect the two changed-file sets.** `merge-tree` only finds *textual*
     conflicts, and the dangerous ones are semantic — `CLEAN` + approved + green and still wrong.
     ```bash
     MB=$(git merge-base HEAD origin/<target_branch>)
     comm -12 <(git diff --name-only $MB..HEAD | sort) \
              <(git diff --name-only $MB..origin/<target_branch> | sort)
     ```
     Non-empty → the target changed a file you changed; read those commits before trusting anything.
     Empty → still check whether the target touched machinery your diff *registers into* (shared
     service bags, DI containers, enum-to-implementation maps, generated manifests): two PRs adding
     an entry to the same list never conflict textually and routinely break a registry test.
     Real cases: a PR flipped `await` to `void` on a function under test, silently racing the other
     PR's assertions; two PRs each added a service to the builder's lists.
   - `git merge-base --is-ancestor origin/<target_branch> HEAD` exit 0 → up-to-date, skip to checks. Else `git merge --no-ff --no-commit origin/<target_branch>` (`merged_locally = true`); unexpected conflict → `git merge --abort`, go to Phase 3.
   - **Always abort the probe merge before returning, on every path.** An interrupted run otherwise
     leaves the worktree mid-merge with hundreds of staged files; the next session must
     `git merge --abort` before anything else. Check `MERGE_HEAD` when resuming.
   - **Re-run the intersection immediately before merging, not once at the start.** On a busy repo
     the target can move materially between verification and merge — one branch went from +73 to
     +165 commits, and its overlap from 2 files to 14, in a single overnight gap.
   - Run the repo's lint, build and test gates against the merged state, scoped to what the merge
     touched. Read the repo's `CLAUDE.md`/docs for the real commands; don't assume a build system.
     Where the repo has affected-graph tooling, scope with it — for an nx monorepo (falling back to
     `lint` if `eslint:lint` isn't the target name):
     ```bash
     npx nx affected --target=eslint:lint --base=origin/<target_branch> --head=HEAD
     npx nx affected --target=build       --base=origin/<target_branch> --head=HEAD
     npx nx affected --target=test        --base=origin/<target_branch> --head=HEAD
     ```
     Where it doesn't, run the documented suite (`pytest`, `go test ./...`, `cargo test`, `make
     check`, …), narrowed to the affected packages if the repo makes that easy.
   - Repo addenda: for each `verification_addenda` entry in local config whose `when_paths_under` prefix matches a changed path, also run its `run` command (separate child pipeline).
   - Any failure → batch `Pre-merge verification failed on merged state: <target> in <pkg>. <20-line error>. CI passed on source alone; likely semantic conflict.` and return (don't merge).
   - If `merged_locally`: `git merge --abort` (always, pass or fail).
3. Announce: `✅ Pre-merge verification passed. Merging !<number> now...`
4. **Merge — respect the repo's enforced/default strategy** (merge commit, squash, or rebase); don't impose your own:
   - **GitLab**: `glab mr merge <number> --yes` (uses the project's default/enforced strategy; pass `--squash` only if `squash_on_merge` requires it). **Do NOT pass `--delete-branch`** — cleanup is delegated (a stacked dependent may still base on this branch).
   - **GitHub**: rulesets override repo settings, so check them first: `gh api "repos/<repo_id>/rulesets" --jq '.[] | select(.target=="branch") | .id'` → for the ruleset covering `<target_branch>`, read `.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods`. Use that list when present; fall back to `gh api "repos/<repo_id>" --jq '.allow_merge_commit, .allow_squash_merge, .allow_rebase_merge'` only when no ruleset constrains it. Exactly one allowed → use it (`--merge`/`--squash`/`--rebase`). Several → prefer merge > squash > rebase. Don't pass an unsupported mode. Don't use `--auto` (already verified). **Do NOT pass `--delete-branch`.**
5. **Success** → announce `✅ Merged !<number>.`, then invoke `Skill(post-merge-cleanup)` with `<source_branch>`, `<target_branch>`, `<number>`, and `--task-slug <slug>` if set. Return.
6. **Failure** (race, etc.) → announce the error verbatim and return (no cleanup — not merged). The caller's next cycle re-checks.

## Phase 3: Conflict resolution

Entered from Phase 1 condition 6 (local conflict) or an unexpected conflict during pre-merge verification. Read `refs/conflict-resolution.md` and follow it (it branches on `SYNC_STRATEGY`: merge-forward for the default; rebase + `--force-with-lease` for `REBASE_SYNC_REPOS`). After it returns, **do not merge this cycle** — return so the caller re-verifies against the new pipeline next cycle.

## Hard constraints

- Never merge unless **every** Phase 1 condition holds and the pre-merge local verification passed. Never merge a draft or a `PROTECTED_BRANCHES` source branch.
- Merge via this skill only. Respect the repo's enforced merge strategy — never impose one, never pass an unsupported mode.
- **Never rebase or force-push by default** — only the `REBASE_SYNC_REPOS` conflict path in `refs/conflict-resolution.md`, `--force-with-lease` only, discard-and-batch on a rejected lease.
- Never pass `--delete-branch` to the merge — branch/worktree deletion happens only in `post-merge-cleanup`, after retargeting any stacked dependents.
- Never `git checkout --theirs` on source code. Never send Slack messages. Follow the repo `CLAUDE.md` + the user's feedback memories.
