---
name: pr-babysit
description: >-
  Babysit an already-open MR/PR through to merge-ready. Each cycle brings the branch current with
  its base, resolves conflicts, auto-fixes safe CI failures (lint, format, typecheck, build, unit
  tests), sweeps every comment stream and addresses clear AI-reviewer notes while batching
  anything human-authored, and keeps the title and description current. Hands off to pr-merge when
  ready, and self-wraps in /loop. It does not create the PR; that is pr-open.
allowed-tools:
  - Bash(glab api:*)
  - Bash(glab mr view:*)
  - Bash(glab mr list:*)
  - Bash(glab mr update:*)
  - Bash(glab ci:*)
  - Bash(gh api:*)
  - Bash(gh pr view:*)
  - Bash(gh pr list:*)
  - Bash(gh pr edit:*)
  - Bash(gh pr comment:*)
  - Bash(gh pr checks:*)
  - Bash(gh repo view:*)
  - Bash(gh run view:*)
  - Bash(gh run list:*)
  - Bash(git remote get-url:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git push)
  - Bash(git push origin:*)
  - Bash(git checkout --:*)
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(git rev-parse:*)
  - Bash(git branch --show-current)
  - Bash(git fetch origin:*)
  - Bash(git merge-base:*)
  - Bash(git merge origin/:*)
  - Bash(git merge --abort)
  - Bash(git merge --no-edit:*)
  - Bash(git rebase origin/:*)
  - Bash(git rebase --abort)
  - Bash(git rebase --continue)
  - Bash(git reset --hard:*)
  - Bash(git commit --no-edit)
  - Bash(git diff --name-only:*)
  - Bash(git grep:*)
  - Bash(git checkout --ours:*)
  - Bash(git checkout --theirs:*)
  - Bash(git rev-list --count:*)
  - Bash(git push --force-with-lease origin:*)
  - Bash(npx nx eslint:lint:*)
  - Bash(npx nx format:write:*)
  - Bash(npx nx test:*)
  - Bash(npx nx build:*)
  - Bash(npx nx affected:*)
  - Bash(npx nx storybook:*)
  - Bash(pnpm lint)
  - Bash(pnpm test:*)
  - Bash(pnpm build:*)
  - Bash(npx tsc:*)
  - Bash(npx prettier --write:*)
  - Bash(pnpm install)
  - Bash(jq:*)
  - Bash(curl:*)
  - Bash(mkdir -p:*)
  - Bash(cat:*)
  - Bash(rm -f ~/.claude/cache/deliver/:*)
  - Skill(loop)
  - Skill(pr-merge)
  - Skill(voice)
  - Read
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_wait_for
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_resize
  - mcp__playwright__browser_close
---

# pr-babysit

Polls an open MR/PR and drives it toward merge. This is the babysit stage of the `deliver` pipeline; creation lives in `pr-open`, merging in `pr-merge`, cleanup in `post-merge-cleanup`. Platform detected from `git remote get-url origin`. Write **"PR"** on GitHub, **"MR"** on GitLab in all user-facing text.

## Args (all optional)

- `<mr-ref>`: URL, `!123`/`#123`, or branch name. Default: current branch.
- `--task-slug <slug>`: the `deliver` task this unit belongs to (passed through to `pr-merge`). Omit when standalone.
- `--once`: run one cycle, no auto-loop.
- `--interval <time>`: fixed polling interval (e.g. `5m`). Default: dynamic pacing (~270s while CI runs, ~1200s idle).
- `--_looped`: internal flag — never pass manually.

## Config

> **Local overrides.** Values below are portable defaults. If `~/.agents/local/config.json` exists,
> its keys override or extend them (schema: `~/.agents/local/config.example.json`); any key absent
> there keeps the default. `config.json` is machine-local and never committed.

- `AI_REVIEWER_USERNAMES_GITLAB`: `[]` + `ai_reviewer_usernames_gitlab` (empty ⇒ every comment batches as human)
- `AI_REVIEWER_USERNAMES_GITHUB`: `["cursor"]` + `ai_reviewer_usernames_github` (`cursor[bot]` = Cursor Bugbot; the 2.1 pre-filter strips the `[bot]` suffix before matching)
- `PROTECTED_BRANCHES`: `["main", "master", "stage-*"]` + `protected_branches_extra`. Entries are **glob patterns**: a bare name matches exactly, `*` matches any run of characters. A branch is protected if it matches any entry — so `rc-*` covers every dated release candidate, and a literal `prod` still matches only itself.
- `AUTO_FIX_CATEGORIES`: `["lint", "format", "typecheck", "build", "unit-test"]`
- `SONAR_HOST_URL`: `sonar_host_url` (unset ⇒ skip the SonarQube step entirely)
- `SONAR_TOKEN_FILE`: `~/.claude/secrets/sonar.env` (exports `SONAR_TOKEN`; never echo it)
- `SCREENSHOT_WIDTH_PX`: `400` (~640 for full-page/wide layouts)
- `SCREENSHOT_MARKER`: `<!-- pr:screenshots:start -->` … `<!-- pr:screenshots:end -->`
- `BOT_USERNAME_PATTERN`: `/^project_\d+_bot_/`
- `BOT_NOISE_BODY_MARKERS` (skip on match): `<!-- STORYBOOK SNAPSHOT MESSAGE`, `<!-- STORYBOOK PREVIEW MESSAGE`, `<!-- SNAPSHOT MESSAGE`, `<!-- build-artifacts`, `<!-- definition-of-ready-status -->` + `bot_noise_body_markers_extra`
- `BOT_ACTIONABLE_BODY_MARKERS`: `["DangerID: danger-id-Danger", "dangerJS"]` — match, then `/(\d+)\s+failure:/`: 0 → noise, >0 → actionable
- `REBASE_SYNC_REPOS`: `[]` + `rebase_sync_repos` — repos whose `CLAUDE.md` mandates rebase-before-push. For these, sync/conflict steps **rebase onto the target and force-push with `--force-with-lease`** instead of merging forward. Derive `SYNC_STRATEGY = "rebase"` if `repo_id` matches, else `"merge"`. This is the ONLY place force-push/rebase is permitted, lease-only, never a bare `--force`; discard-and-batch if the remote advanced.
- **State file**: `~/.claude/cache/deliver/pr-<platform>-<repo-with-slashes-as-dashes>-<number>.json` (the `deliver`-family namespace).

## Phase -1: Auto-wrap in /loop

If args contain `--_looped` or `--once` → skip to Phase 0. Otherwise invoke `Skill(loop)` with `[<interval>] /pr-babysit <mr-ref> [--task-slug <slug>] --_looped` and return without running this cycle.

**Monitor signature — poll the signal, not the churn.** When `loop` arms a Monitor for the MR/PR,
build its change signature from: `state`, `is_draft`, `reviewDecision`, `head_sha`, the **names** of
failing checks, a binary `running`/`all-done` for CI, and the three comment/review counts. Leave out
`mergeStateStatus` and any per-check running *count* — both flap on their own (GitHub recomputes merge
state unprompted, and a draft is permanently `BLOCKED`), so each flip burns a wakeup on nothing. And
when any API call in the loop fails, **skip the cycle** rather than substituting a placeholder like
`?` — a placeholder changes the signature and fires twice, once out and once back.

**Re-arm on every turn, not just loop turns.** An interactive exchange replaces the turn that would
have called `ScheduleWakeup`, so a conversation silently ends the watch — and the longer the
conversation, the likelier it is off. While a babysit is active, end *any* turn that touched this
PR by re-arming, and say when the next check is. If you cannot tell whether a wakeup is pending,
re-arm: a duplicate is replaced, a missing one is not noticed until the user asks.

## Phase 0: Detect platform, resolve MR/PR, load state

### 0.0 Platform
`git remote get-url origin` → `github.com` ⇒ `github`; `gitlab` ⇒ `gitlab`; else announce and stop. Set `AI_REVIEWER_USERNAMES` from the matching list (empty = all comments batch as human).

### 0.1 Resolve via CLI; map to unified fields
- **GitLab**: `glab mr view [<arg>] --output json`
- **GitHub**: `gh pr view [<arg>] --json number,headRefName,baseRefName,url,title,state,mergedAt,mergedBy,closedAt,headRefOid,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,reviewThreads,author`. Derive `repo_id` (`<owner>/<repo>`) from the remote.

| Unified | GitLab | GitHub |
|---|---|---|
| `number` | `iid` | `number` |
| `repo_id` | `project_id` | `<owner>/<repo>` |
| `source_branch` | `source_branch` | `headRefName` |
| `target_branch` | `target_branch` | `baseRefName` |
| `web_url` | `web_url` | `url` |
| `state` | `opened`/`closed`/`merged` | `OPEN`/`CLOSED`/`MERGED` (lowercase) |
| `head_sha` | `sha` | `headRefOid` |
| `is_draft` | `work_in_progress`/`draft` | `isDraft` |
| `has_conflicts` | `has_conflicts` | `mergeable=="CONFLICTING"` OR `mergeStateStatus=="DIRTY"` |
| `mergeable` | `merge_status=="can_be_merged"` | `mergeable=="MERGEABLE"` AND `mergeStateStatus=="CLEAN"` |

### 0.2 Branch guard
Abort if `source_branch` matches `PROTECTED_BRANCHES`.

### 0.3 Terminal state
A merged/closed MR/PR won't be revisited — **delete its state file and stop** (`pr-merge`/`post-merge-cleanup` handle in-skill merges; this catches merges/closes done elsewhere):
- `state == "merged"`: `rm -f` the state file, announce `🎉 !<number> merged. Stopping.`, tell the user to `/loop stop`, return.
- `state == "closed"`: `rm -f` the state file, announce `!<number> closed (not merged). Stopping.`, same, return.

### 0.4 State file
Path above. Initialize if missing:
```json
{"addressed_thread_ids":[],"seen_human_note_ids":[],"shown_but_unaddressed_thread_ids":[],"last_pipeline_id":null,"failed_fix_counts":{},"e2e_retry_counts":{},"metadata_synced_head_sha":null,"managed_title":null,"managed_body_hash":null,"screenshot_nudged":false}
```

### 0.5 Announce + derive flags
Announce: `Babysitting <platform>:<repo_id>!<number> (<source_branch> → <target_branch>): <title>`.
Derive `is_behind`: GitHub `mergeStateStatus == "BEHIND"`; GitLab `git fetch origin <target_branch>` then `git merge-base --is-ancestor origin/<target_branch> HEAD` — exit 1 ⇒ behind.

## Phase 0.5: Upstream-conflict / out-of-date early exit

Conflicts or a stale base must be fixed first. After resolving, skip Phases 1-2 this cycle and go to Phase 3.
**Common preconditions**: working tree clean and current branch == `source_branch`; else announce and skip to Phase 1.

### 0.5a — `has_conflicts == true`
1. Announce: `MR reports conflicts with origin/<target_branch>. Resolving before touching CI/comments.`
2. Read `refs/conflict-resolution.md` and follow it (it branches on `SYNC_STRATEGY`). After it returns, skip to Phase 3.

### 0.5b — `is_behind == true` AND `has_conflicts == false`
1. `git fetch origin <target_branch>`.
2. `git rev-list --count HEAD..origin/<target_branch>` > 50 → abort, batch `N commits behind — too stale for automatic sync`, skip to Phase 3.
3. **`SYNC_STRATEGY == "merge"`**: announce, `git merge origin/<target_branch> --no-edit`, unexpected conflict → `git merge --abort` + skip to Phase 1 (0.5a catches it next cycle); else `git push`, announce `✅ Merged origin/<target_branch> forward as <sha>`, skip to Phase 3.
4. **`SYNC_STRATEGY == "rebase"`**: `PRE=$(git rev-parse HEAD)`; `git rebase origin/<target_branch>` (conflict → `git rebase --abort` + skip to Phase 1); `git push --force-with-lease origin <source_branch>`. Lease rejected → `git reset --hard $PRE`, batch `Branch advanced on the remote — skipped rebase+force-push to avoid clobbering; needs a look`, skip to Phase 3. Else announce `✅ Rebased and force-pushed with lease as <sha>. Approval may reset (expected).`, skip to Phase 3.

**Order:** both true → 0.5a. Both false → Phase 1.

## Phase 1: Pipeline / Checks

### 1.0 Fetch CI state
- **GitLab**: `glab api "projects/<repo_id>/merge_requests/<number>/pipelines" | jq '.[0]'` → `pipeline_id`, `status`.
- **GitHub**: `gh api "repos/<repo_id>/commits/<head_sha>/check-runs?per_page=100" --paginate` + `gh api "repos/<repo_id>/commits/<head_sha>/status"`. Synthesize `status`: any non-`completed`/pending → `running`; any `failure`/`timed_out`/`action_required` → `failed`; all success/skipped/neutral → `success`. `pipeline_id = head_sha`.

> **Far fewer checks than the previous head_sha means conflicts, not broken CI.**
> GitHub cannot build a merge ref for a conflicting PR, and `pull_request`
> workflows run against that ref, so they never start — leaving only the
> `push`-triggered ones. Recheck `has_conflicts` (0.5) before investigating
> workflow config, dropped events or path filters.

### 1.1 Skip-fast
- `pipeline_id == state.last_pipeline_id` AND `status` ∈ {success, running, pending} → skip to Phase 2.
- `status` ∈ {running, pending} → note, skip to Phase 2.
- `status == success` → update `state.last_pipeline_id`, skip to Phase 2.

### 1.2 If `failed`
**Fetch failed jobs:** GitLab `glab api "projects/<repo_id>/pipelines/<pipeline_id>/jobs?scope[]=failed&per_page=50"` (logs via `.../jobs/<job_id>/trace`); GitHub filter check-runs `conclusion == "failure"`, for Actions extract run ID → `gh run view <run_id> --log-failed --job <job_id>`; non-Actions → batch with reason.

**Categorize by name (contains, case-insensitive):** `eslint`/`lint`/`format`/`prettier` → **lint**; `typecheck`/`tsc` → **typecheck**; `build` → **build**; `test`/`vitest`/`jest`/`unit-test` → **unit-test**; `e2e`/`playwright`/`integration`/`export` → **flaky-retry**; `security`/`codeowners`/`changeset`/`danger`/`scenario`/else → **skip** (batch `CI failure needs eyes: <job> — <reason>`).

The name is a heuristic, not the classification: read the failure before auto-fixing one that landed in **unit-test**. A suite whose name merely contains `test` can be a Docker-backed integration run against a third party, where the failure is that service's error page rather than anything in the diff. Editing source to satisfy it is the wrong move — retry once, then batch.

**Auto-fix (lint/typecheck/build/unit-test):** if `state.failed_fix_counts[<job>] >= 2` → batch `Repeatedly failing — stopping auto-fix: <job>`. Else read log tail (~200 lines), identify package, `pnpm install` if in a worktree, then: **lint/format** `npx nx eslint:lint <pkg> --fix` then `npx nx format:write --all --no-sort-root-tsconfig-paths`; **typecheck/build** read errors, edit source (IDE diagnostics first, fall back to scoped `npx tsc --noEmit`); **unit-test** fix source (preferred) or test. Verify with the same nx target. Pass → `git add -A`, commit (ticket-prefixed if branch has one), `git push`. Fail → increment counter, `git checkout -- .`, batch `Auto-fix attempt failed: <job> — <reason>`.

**Flaky-retry (e2e/playwright/integration):** `e2e_retry_counts[<job>] == 0` → retry once (GitHub `gh api -X POST repos/<repo_id>/actions/jobs/<job_id>/rerun` or `gh run rerun <run_id> --failed`; GitLab `glab api --method POST "projects/<repo_id>/jobs/<job_id>/retry"`), increment, report `Retrying flaky: <job>`. `>= 1` → batch `Flaky retry exhausted — likely real failure: <job> — <reason>`. Retry API errors → batch.

**Commit messages** (one per category, ticket-prefix if present): `Fix lint` / `Fix typecheck errors` / `Fix build errors` / `Fix failing unit tests`. Push once at phase end. Update `state.last_pipeline_id`.

## Phase 1.5: SonarQube issues (when configured)

Surfaces the specific Sonar issues (the platform check only shows pass/fail). IDE SonarLint is the pre-push catch; this is the post-push net.

### 1.5.0 Gate — run only when ALL hold
- `SONAR_HOST_URL` resolves from local config (unset → skip silently; this phase is opt-in per machine).
- `sonar-project.properties` exists at repo root (else skip silently).
- A token resolves: `$SONAR_TOKEN`, else `source` `SONAR_TOKEN_FILE`. Neither → skip silently (batch one line the first time). Never print the token.
- A check matching `/sonar/i` is `COMPLETED` for `head_sha` (else skip this cycle: `Sonar scan still running`; no sonar check ran → skip silently).

### 1.5.1 Query
- `project_key` = `sonar.projectKey=` from `sonar-project.properties`.
- Issues: `curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/issues/search?pullRequest=<number>&componentKeys=<project_key>&resolved=false&ps=500"`.
- Gate: `curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/qualitygates/project_status?projectKey=<project_key>&pullRequest=<number>"`.
- curl fails → skip + batch one line.

### 1.5.2 Surface (don't auto-fix)
- One batch item per issue: `Sonar (<severity> <rule>): <component>:<line> — <message>`. Sort by severity (BLOCKER > CRITICAL > MAJOR > MINOR > INFO).
- **Batch, don't auto-fix** — a Sonar rule can conflict with another linter, so it needs judgment. Add the gate verdict to the header: `Sonar gate: <OK|ERROR> (<N> open issues)`. The CI sonar job enforces the gate as a merge-blocking check, so this phase adds **no** separate merge condition.

## Phase 2: Comments

> **STOP — Phase 2 runs on EVERY cycle. Never optional, never abbreviated.** Fetch **all three** GitHub streams (2.0) every cycle — even when "just waiting on CI/approval," and **especially right after an approval lands** (reviewers often leave line comments *with* their approval). Never conclude "nothing new" without having swept all three streams.

### 2.0 Fetch threads
Unified per thread: `{ thread_id, resolvable, resolved, notes:[{note_id, author, body, system, url}] }`.
- **GitLab**: `glab api "projects/<repo_id>/merge_requests/<number>/discussions?per_page=100" --paginate`.
- **GitHub** — FOUR places, ALL fetched every cycle:
  1. Review threads (line-level) via GraphQL: `gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){reviewThreads(first:100){nodes{id isResolved isOutdated comments(first:50){nodes{id databaseId author{login} body url createdAt}}}}}}}' -F owner=<owner> -F repo=<repo> -F number=<number>`
  2. Issue comments (PR-level, NOT resolvable): `gh api "repos/<repo_id>/issues/<number>/comments?per_page=100" --paginate`.
  3. Reviews with body: `gh api "repos/<repo_id>/pulls/<number>/reviews?per_page=100" --paginate` (`COMMENTED` + non-empty body = pseudo-thread; APPROVED/CHANGES_REQUESTED feed the approval check in `pr-merge`).
  4. **Check-run annotations** — these render in Files Changed as `Check warning on line N`, so they read as review comments even though no API above returns them. For each check run with `output.annotations_count > 0`: `gh api "repos/<repo_id>/check-runs/<check_run_id>/annotations"`. A **passing** check still emits them, so never gate this on `conclusion == failure`. Treat a `warning`/`failure` annotation pointing at a file in your diff as an auto-fix item (it is usually lint the formatter does not cover); `notice` level and anything outside the diff is noise.

### 2.1 Iterate threads
Skip if `thread_id` ∈ `state.addressed_thread_ids`, OR all notes `system`, OR (`resolvable && resolved`). Take the first non-system note → `author`, `body`, `note_id`. Normalize `author_base` (GitHub: strip trailing `[bot]`).
**Bot pre-filter:** GitLab `author` matches `BOT_USERNAME_PATTERN`, or GitHub `author` ends `[bot]` → classify body (`BOT_NOISE_BODY_MARKERS` → skip; `BOT_ACTIONABLE_BODY_MARKERS` → DangerJS rule; else fail-open to 2b). **DangerJS:** match `/(\d+)\s+failure:/` — 0 → skip; >0: **coverage-threshold** failure → add unit tests for the listed files/lines, verify, commit (`<TICKET> Add unit tests to address coverage gap`), push (only batch if genuinely untestable; never use `ALLOW_COVERAGE_DECREASE` without approval); other DangerJS failures → 2b.
Then: `author_base` ∈ `AI_REVIEWER_USERNAMES` → 2a; else → 2b.

### 2a. AI-reviewer comment
Classify `body`: **auto-fix** (clear, bounded, scoped to diff lines, no opinion); **ask-user** (ambiguous/opinion/cross-cutting/unverifiable); **ignore-as-noise** (trivially wrong / already done / misread — verify by reading the file first).
Reply/resolve: GitLab reply `glab api --method POST ".../discussions/<thread_id>/notes" -f body="<text>"`, resolve `glab api --method PUT ".../discussions/<thread_id>?resolved=true"`; GitHub review-thread reply `gh api graphql -f query='mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{id}}}' -F t=<thread_id> -F b="<text>"`, resolve `gh api graphql -f query='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{id isResolved}}}' -F t=<thread_id>`; GitHub issue-comment pseudo-thread reply `gh pr comment <number> --body "<text>"` where `<text>` **opens with a blockquote of the finding** — one or two trimmed lines plus a link to it — because a PR-level comment lands with no visual tie to what it answers (mark addressed in state; UI keeps showing it open).
- **auto-fix**: edit → verify (IDE diagnostics / scoped `npx tsc --noEmit`) → commit `Address review: <summary>` (ticket-prefixed) → push → reply `Addressed in <sha>.` → resolve → append to `addressed_thread_ids`.
- **ask-user**: skip if in `shown_but_unaddressed_thread_ids`. Else batch `AI reviewer (unclear): <url> — <summary> — why unsure: <reason>`, append to `shown_but_unaddressed_thread_ids`.
- **ignore-as-noise**: reply (one polite sentence) → resolve → append to `addressed_thread_ids`.

**Voice.** Reply *prose* is in Luis's voice — follow the `voice` skill's ground truth (`refs/principles.md` + `refs/examples-pr-comments.md`, the source of truth for his written style). A bounded ack like `Addressed in <sha>.` is fine as-is; apply the voice to anything with latitude (the `ignore-as-noise` sentence, an explanatory reply). These go to a **bot** reviewer → they post autonomously. A reply to a **human** thread is a message to a person → draft it via the full `Skill(voice)` (draft → his approval → post); this loop never auto-replies to humans (2b batches them). The keep-current title/description (Phase 2.5) inherits `pr-open`'s voice too.

### 2b. Human / unfiltered bot comment
Filter notes with `note_id` not in `state.seen_human_note_ids` and not system. Batch each: `Human (@<author>): <url> — <body trunc 200>`. Append note IDs to `seen_human_note_ids`. **Never reply to or resolve human threads.**

## Phase 2.5: Keep title / description / screenshots current

Reconcile metadata with the diff as commits land — **without clobbering human edits.**
- **2.5.0** First sight (`metadata_synced_head_sha == null`): baseline it (`metadata_synced_head_sha = head_sha`, `managed_title = current title`, `managed_body_hash = hash(current desc, screenshots block stripped)`), skip the rest. `head_sha == metadata_synced_head_sha` → skip. Else proceed.
- **2.5.1** Re-derive intended title/description against `origin/<target>..HEAD` exactly as `pr-open` Steps 2-3 would; determine whether snapshottable UI changed (Step 4 gate).
- **2.5.2 Screenshots**: GitLab — the `SCREENSHOT_MARKER` block is skill-owned; re-capture/re-embed if in-scope stories changed, remove if UI no longer in scope, else leave. GitHub — can't re-embed; if the in-scope set changed, re-capture to `~/Desktop/pr-screenshots-<branch>/` and batch `UI changed — refreshed screenshots; re-attach on GitHub and ask me to organize them.` Don't touch a block the user arranged.
- **2.5.3 Title**: current == `managed_title` and re-derived differs materially → update (GitLab `glab mr update <number> --title`; GitHub `gh pr edit <number> --title`), set `managed_title`. Human renamed → don't touch (batch one line if clearly stale).
- **2.5.4 Description**: `current_body_hash == managed_body_hash` → regenerate body + re-attach screenshots block, update, recompute `managed_body_hash`. Human edited prose → leave prose; still swap only the marker-delimited screenshots block if 2.5.2 changed it (batch one line if prose clearly stale).
- **2.5.5** Set `metadata_synced_head_sha = head_sha` + updated managed fields. Announce `📝 Updated <title|description|screenshots> to match new commits.`

## Phase 2.6: Screenshots for UI PRs — auto-size attached, else nudge

Runs every cycle. Read `refs/storybook-screenshots.md` (Step 7) for the sizing algorithm.
- **2.6a Auto-size (GitHub)**: find image refs outside any `SCREENSHOT_MARKER` block that are unsized (bare markdown, `<img>` no width, or width ≥ 900). None/all reasonable → do nothing. Else run Step 7: preserve URLs byte-for-byte, set each `<img width>` to `SCREENSHOT_WIDTH_PX`, label from alt/filename, pair natural side-by-sides in a 2-col table, wrap in `SCREENSHOT_MARKER`. `gh pr edit <number> --body …`, announce `🖼️ Sized N attached screenshot(s).` Idempotent (marker-wrapped blocks are left alone). (GitLab embeds are sized at capture time.)
- **2.6b Nudge once (`screenshot_nudged`)**: if snapshottable UI changed (Step 4 gate on `origin/<target>..HEAD`) and the body has no screenshots at all (no marker, no `## Screenshots`, no image/`<img>`/attachment link) → capture the in-scope stories (GitHub → `~/Desktop/pr-screenshots-<branch>/`; GitLab → embed) and batch one nudge, then set `screenshot_nudged = true`. If already covered → set the flag and skip. Capture fails → still nudge without images.

## Phase 3: Write state + report

1. Persist state.
2. Header: `Cycle: pipeline <status> [(fixed N jobs)], <N> new batch items.`
3. Batch non-empty → list items with indices, ask **"Go through these now, or keep watching?"** ("Go through" → walk one-by-one, proposing fixes, awaiting approval; "Keep watching" → return, /loop schedules next). **Skip Phase 4.**
4. Batch empty → continue to Phase 4.

## Phase 4: Hand off to pr-merge

`pr-merge` owns the full merge gate (approval, threads resolved, CI green, mergeable, pre-merge local verification) and the merge itself. So this stage only decides whether it's worth *asking*:

- Skip (keep looping) if any of: `is_draft == true`, `state != opened`, batch non-empty this cycle (Phase 3 already gated), `state.last_pipeline_id` status is not `success`, or **no approval has landed yet** — GitHub `reviewDecision` ∈ {`REVIEW_REQUIRED`, `CHANGES_REQUESTED`} (already in the 0.1 payload, so this costs nothing), GitLab an empty `approved_by`. Approval is `pr-merge`'s first gate, so without one the handoff can only load the skill, re-run local pre-merge verification and come back "not ready" — every cycle, for as long as the review sits unclaimed. **Fail open**: no cheap approval signal ⇒ hand off anyway.
- Otherwise invoke `Skill(pr-merge)` with `<mr-ref>` (this MR/PR) and `--task-slug <slug>` if set. It re-verifies every condition and either merges (→ `post-merge-cleanup`) or returns "not ready — keep watching." Either way this cycle ends; `/loop` re-checks next cycle (a successful merge is caught by Phase 0.3's terminal check and stops the loop).

## Phase 5: Capture learnings (self-educate)
Once the PR hands off or you stop polling, ask whether anything about how this ran warrants a durable edit. Never invent one — "nothing to capture" is the usual answer and deserves a line, not a paragraph.

What recurs at this stage: a CI failure class that was safely auto-fixable — or looked it and wasn't; a bot whose comments are noise (→ `bot_noise_body_markers_extra`) or a reviewer worth auto-addressing (→ `ai_reviewer_usernames_*`); a sync or conflict pattern that keeps recurring.

Route it: repo- or employer-specific facts → `~/.agents/local/config.json`; a lesson that would hold at any job → this skill; a durable one-off → a memory. **When `deliver` invoked you**, hand it up with your report instead of editing — `deliver`'s end-of-run reflection owns the routing, and two skills acting on one lesson records it twice. **Show the exact edit and apply it only once the user confirms**; prefer refining an existing line to adding one, and if a section grows, cut a sentence elsewhere.

## Hard constraints

- Never push to `PROTECTED_BRANCHES`. **Never rebase or force-push by default** — the sole exception is a `REBASE_SYNC_REPOS` repo via the 0.5b / `conflict-resolution.md` rebase path: `--force-with-lease` only, discard-and-batch on a rejected lease. Every other repo is merge-only.
- Never approve, close, or comment on human threads. Allowed actions: commit, push (and, only in `REBASE_SYNC_REPOS`, `git push --force-with-lease` after a rebase), reply to AI-reviewer threads, resolve threads. Merging and cleanup are delegated to `pr-merge`/`post-merge-cleanup`.
- Never mark a thread resolved unless the commit actually pushed.
- Never bypass pre-commit hooks except the sanctioned large cross-toolchain sync case (0.5b / `conflict-resolution.md`) where the hook fails only on CI-green files from the target.
- Never send Slack messages (always needs user approval).
- Maintain JSDoc coverage on edited files that already have it. Follow the repo `CLAUDE.md` + the user's feedback memories rather than re-deriving conventions.

## Notes

- State per-MR/PR under `~/.claude/cache/deliver/`, deleted on terminal state (Phase 0.3).
- `addressed_thread_ids` (won't re-surface) vs `shown_but_unaddressed_thread_ids` (silent until the user resolves on-platform).
- Approval-reset-on-push clears approvals after a rebase force-push (0.5b) — expected; re-approve, next cycle hands off to `pr-merge` again. Rebase-sync repos churn approvals every sync.
