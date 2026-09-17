---
name: deliver
description: >-
  Drive a whole task end to end: understand, plan, execute, verify, open the PR, babysit it to
  merge, clean up, raise follow-ups. Handles one PR or a stack, deciding the breakdown itself. Use
  for "deliver/ship this", a pasted ticket to implement, or the full cycle; it can also adopt work
  already in flight and enter at the right stage. Composes understand-task, self-review, pr-open,
  pr-babysit, pr-merge and post-merge-cleanup, so reach for those directly only when you want a
  single stage.
---

# deliver

A conductor for the whole task lifecycle. It owns only the **spine** — phase sequencing, the gates between phases, a per-task **ledger**, and handoff — and delegates the actual work to focused sub-skills. It carries no conventions of its own: at every step it follows the repo `CLAUDE.md`, the nearest module `CLAUDE.md`/`AGENTS.md`, and the user's feedback memories.

**Mostly autonomous, past one unconditional stop.** The **plan checkpoint** always runs (A2). Beyond it, flow straight through the phases and stop only for a genuine **ambiguity** or **risk** gate (below). Don't manufacture check-ins other than those.

**Terminology.** Write **"PR"** on GitHub and **"MR"** on GitLab in everything you say to the user.

**A task is not necessarily one PR.** `deliver` runs at two levels:
- **Task level (once):** understand + plan — where planning decides the **PR breakdown** (`units[]`: 1..N PR-sized pieces, `independent` or `stacked`).
- **Per-unit loop:** execute → verify → open → babysit, run once per unit. N=1 is the simple single-PR path with no stack bookkeeping.

## Args (all optional)

- `<task-ref>`: a ticket id/URL, a Slack link, or free-text describing the task. Default: the task stated in the conversation.
- `--resume`: continue an existing task from its ledger instead of starting fresh.
- `--stage <understand|plan|execute|verify|open|babysit|verify-staging>` (alias `--from`): force the entry stage for a task with no ledger — e.g. `--stage babysit` on a branch whose PR is already open. Overrides A0's auto-detection.
- `--interval <time>`: passed through to `pr-babysit`'s loop.
- `--no-ticket-sync`: don't touch the associated tracker ticket's status (see `## Ticket status sync`). Default: sync when a ticket + a connected tracker exist.
- `--no-review-ping`: passed through to `pr-open` — skip drafting the review-request ping.

## Config

> **Local overrides.** Values below are portable defaults. If `~/.agents/local/config.json` exists,
> its keys override or extend them (schema: `~/.agents/local/config.example.json`); any key absent
> there keeps the default. `config.json` is machine-local and never committed.

- `PROTECTED_BRANCHES`: `["main", "master", "stage-*"]` + `protected_branches_extra`. Entries are **glob patterns**: a bare name matches exactly, `*` matches any run of characters. A branch is protected if it matches any entry — so `rc-*` covers every dated release candidate, and a literal `prod` still matches only itself.
- **Task ledger**: `~/.claude/cache/deliver/task-<repo-with-slashes-as-dashes>-<task-slug>.json`
  ```json
  {"task_ref":null,"requirements":null,"acceptance":null,"plan_summary":null,"phase":"understand",
   "deferred_items":[],
   "ticket_sync":{"enabled":false,"in_progress":false,"in_review":false,"done":false},
   "units":[{"id":1,"title":null,"branch":null,"base":null,"kind":"independent","depends_on":null,"pr_number":null,"status":"pending","needs_staging_verification":false,"staging_verified":null}]}
  ```
  `task_slug` = the ticket id if there is one (lowercased, e.g. `abc-1234`), else a short kebab slug of the task. `task_ref` holds `{tracker, id, url, current_status}` when the task has an associated ticket, else `null`.
- `TICKET_SYNC`: **on by default** when `task_ref` has a ticket AND its tracker connector (the Atlassian / Linear MCP) is available this session; `--no-ticket-sync` forces it off. Governs the `## Ticket status sync` transitions.
- `TICKET_DONE_CONFIRM`: `false` — set `true` to confirm before the final **Done** transition (the others always run autonomously).

## Phase A — Task level (once)

### A0. Entry point — resume, adopt, or start fresh
`deliver` is a front door from **any** starting point, not just the top. Resolve where to begin. Compute `task_slug` (ticket id lowercased, else a kebab slug of the task/branch) and the ledger path.

1. **Resume** — `--resume`, or a ledger already exists for this task → load it and jump to the first unfinished phase/unit. Done.
2. **No ledger** — resolve the **entry stage** from the strongest signal available (in precedence), then seed a ledger from current reality so the rest of the spine runs unchanged:
   - **Explicit** — `--stage <understand|plan|execute|verify|open|babysit|verify-staging>` (alias `--from`) always wins.
   - **Session context** — if *this* conversation already establishes the task and how far it's gotten (we scoped it, agreed a plan, implemented/committed it, or opened a PR earlier this session), use that: set the task identity + entry stage and seed `requirements`/`plan_summary`/`deferred_items` from what was already done, so you don't re-run `understand-task`/plan on work you just did. It also disambiguates *which* task the current branch belongs to. (Caveat: a long or summarized session can be stale — treat session context as authoritative for *intent* but verify *artifacts* against the probe below.)
   - **Git/PR probe** — the objective ground truth: the sole signal on a cold start (no relevant session context), and the artifact cross-check otherwise. Probe platform + git state (`git remote get-url origin`, `git branch --show-current`, the default branch, and `gh pr list --head <branch>` / `glab mr list --source-branch <branch>`):

     | Observed state | Entry stage |
     |---|---|
     | ≥1 open PR/MR for the branch | **babysit** |
     | commits ahead of the default branch, no open PR | **verify → open** |
     | uncommitted changes, no commits ahead | **execute** (finish the in-progress change) |
     | clean branch with nothing ahead (or on the default branch) | **understand** (fresh start) |

   - **Reconcile the signals:** session context is authoritative for *task identity, requirements, plan, and deferred items*; **git/PR state is authoritative for artifacts** (which commits/PRs actually exist). If they disagree on the stage, trust the artifacts and say so; if it's ambiguous or material, ask rather than guess.
   - **Adopt into the ledger:** set `phase` = entry stage and mark earlier phases done. For every open PR found, add a `unit` with its `branch`, `base` (target branch), `pr_number`, `kind` (`stacked` if base ≠ default branch), `status:"open"`; if the branch has dependent PRs (a stack), adopt them all in stack order. For commits-no-PR, add one unit for the current branch (`status:"pending"`). Record `task_ref` if one was given.
   - Announce the decision: `deliver: adopting <task> at the <stage> stage (<N> existing PR(s): <refs>).`

When the resolved entry stage is past understand/plan (adoption, `--stage`, or work already covered by this session), **skip A1/A2** — don't re-understand or re-plan work already in flight; go straight to Phase B at the entry stage. (A light read of an adopted PR's description to seed `requirements`/`plan_summary` is fine, but don't gate on it.)

### A1. Understand *(skip when adopting past this stage)*
- Invoke `Skill(understand-task)` with `<task-ref>` and `--task-slug <slug>`. It writes `requirements`, `acceptance`, seeds `deferred_items`, and — when the task has a ticket — records `task_ref` (tracker/id/url/current status). If a ticket + a connected tracker MCP exist and `--no-ticket-sync` wasn't passed, set `ticket_sync.enabled = true`.
- **Ambiguity gate:** if it stopped to ask, relay the question and wait. Otherwise continue.

### A2. Plan + PR breakdown *(skip when adopting past this stage)*
- From the brief, form the smallest approach that satisfies the acceptance criteria (reuse existing code first). Decide the **breakdown**:
  - One cohesive, reviewable change → **one unit** (`kind:"independent"`).
  - Genuinely separable or too large for one review → **multiple units**. Mark them `stacked` when a later unit builds on an earlier unit's not-yet-merged code (base = the previous unit's branch); `independent` when they can each target the default branch on their own.
- Write `plan_summary` and the ordered `units[]` (with `title`, `base`, `kind`, `depends_on`) into the ledger.
- **Plan checkpoint (gate) — always, no exceptions.** Present the plan + breakdown for approval via `EnterPlanMode` → `ExitPlanMode` before building, however small the change looks. "Straightforward" is your own estimate of work you have not done yet, and the runs where that estimate is wrong are precisely the ones worth catching while the cost is a sentence rather than a diff. Approving a one-line plan takes seconds; finding out the approach was wrong once a PR is open costs the review.
- **Size the plan to the change.** A single-unit fix deserves a line or two — what you'll change, and why it's the smallest thing that satisfies the acceptance criteria. Don't pad it to justify the gate: a long plan for a small change is harder to check than a short one, which defeats the point of asking. A multi-unit or stacked breakdown is where detail belongs, because the stack is itself the decision.

## Phase B — Per-unit loop

Set up **one integration worktree per task** if not already working in one; create a branch per unit inside it. Use the repo's own worktree tooling when it ships any — a skill or script that creates them, or a documented location — since it usually encodes setup steps (certs, secrets, direnv) you'd otherwise rediscover the hard way; fall back to `<repo_root>/.claude/worktrees/<task-slug>` only when there is none (rule #12). Say which you used.

**Ticket → In Progress** (once): before the first unit's `B1` — or, on adoption entering past execute, right away — move the associated ticket forward per `## Ticket status sync`.

**Name the session** (once): at the same point, propose a name derived from the task — the ticket id, or a short kebab slug of the work — and ask the user to run `/rename <name>`. There is no rename tool; `/rename` is a user-only built-in. **Skip the ask when A2's plan checkpoint ran** — accepting a plan re-titles the session from the plan, so suggesting a rename on top of that is noise. Otherwise ask once in a single line, don't gate on it, and don't re-ask on later units or resumes.

Then, driven by the breakdown:

- **Adopted units** (from A0 adoption or `--stage`): enter the loop at the resolved entry stage and **skip the earlier steps** — an already-open PR runs **B4 only**; a committed-but-unopened branch runs **B2→B4**. Only run B1 (execute) for units still `pending`. Don't create a new worktree/branch for a PR you're adopting — you're already on it.
- **Independent / sequential units:** run the full sub-cycle (B1→B4) for a unit and let it merge + clean up **before** starting the next (each later unit branches off the freshly-updated default branch).
- **Stacked units:** run **B1→B3 for every unit first** (build + verify + open each, stacking bases: unit 1 off the default branch and **ready**, units 2..N off the previous unit's branch and **draft**), then babysit **bottom-up** (B4 on the front unit; its `post-merge-cleanup` retargets + promotes the next; repeat up the stack).

For each unit:

### B1. Execute
- **Risk gate** before starting: stop and check with the user before public-API changes, auth/security-sensitive or PII paths, destructive/irreversible actions, anything on a protected branch, or clearly cross-team/higher-risk work (the user's habit: do the low-lift part now, hand off the rest → log the hand-off to `deferred_items`). **A change that grants its own author access or privileges always stops here**, even when the user asked for it and it looks routine — confirm the access is actually needed before opening, not after.
- Create the unit's branch off its `base` in the task worktree. Implement the smallest change that satisfies this unit, following the repo's own `CLAUDE.md` (its versioning, styling and file-layout conventions) plus the user's global rules and memories (doc comments, strict equality, no non-null assertions, AAA tests, …). Anything you consciously punt → append to `deferred_items`. Commit (ticket-prefixed if the task has an id). Update the unit `status:"executing"`.

### B2. Verify
- Invoke `Skill(self-review)` with `--base <unit base>` and `--task-slug <slug>`. Address its fix-now items; relay its batch. **Loop B1↔B2** until the gates are green and no clear findings remain.

### B3. Open
- Invoke `Skill(pr-open)` with `--target <unit base>` and `--task-slug <slug>`. It creates the PR (draft-if-stacked) and records `pr_number` / `status:"open"` in the unit. For a **ready** PR it also drafts (doesn't send) a review-request Slack ping via `voice` (Step 7) — pass `--no-review-ping` through.
- **Ticket → In Review** (once per task): the first time the task has an open PR — right after this `pr-open` returns for the first unit, or on adoption when A0 found an open PR — move the ticket forward per `## Ticket status sync`.

### B4. Babysit → merge → cleanup
- Invoke `Skill(pr-babysit)` with the unit's PR ref, `--task-slug <slug>` (and `--interval` if set). It loops on CI/comments/keep-current and, when merge-ready, chains `Skill(pr-merge)` → `Skill(post-merge-cleanup)`.
- `post-merge-cleanup` marks the unit `merged`, advances any stacked dependents, and — on the **last** unit — proposes the task's `deferred_items` as follow-ups (approval-gated).
- Advance to the next unit until all are `merged`.

### B5. Verify on staging (deploy-gated, resumable)
A unit whose PR carried the repo's needs-testing label isn't finished at merge: someone has to exercise it on the deployed environment, usually a day later and in another session. `post-merge-cleanup` sets `needs_staging_verification` on the unit; this step clears it. Config comes from the repo's `staging_verification` entry in local config.

- **Entered later, not inline**: `deliver --stage verify-staging`, or when the user says a deploy is ready to test. Pick up every unit with `needs_staging_verification: true` and `staging_verified: null`. When the ask is broader than one task ("anything pending?"), don't stop at this ledger — it only knows units this task opened. Enumerate the user's recent merged PRs and read each one's labels directly; `--label` filters query a search index that lags both ways, so it both misses entries and reports ones already cleared.
- **Confirm the unit is actually deployed first.** Merged is not deployed, and a stack merges one unit at a time, so testing a unit still sitting on a branch produces findings that describe nothing. Run the repo's `deploy_state_cmd` against the unit's merge sha, read each surface separately rather than a composite verdict, and skip any unit that hasn't landed yet, saying so.
- **Take the steps from the unit's own PR description**, not from memory and not from a sibling unit's plan. That Test Plan section is the authored, reviewer-facing one, and it's what the label refers to.
- **Drive the deployed environment** (`staging_url`) the way `self-review` Step 3.5 drives local: real clicks, and both the cancel and the confirm path of anything destructive.
- **Attribute failures before reporting them.** Check whether the same failure reproduces without the unit's change; a bug that pre-dates it is not a regression, and calling it one costs a deploy. Say which of the two you established.
- **Record the outcome** in `staging_verified` as `{at, sha, result}`. On a fail, report and stop: the fix is a new unit, not an edit to a merged one.
- **On a pass, remove the label** — `gh pr edit <n> --remove-label <needs_testing_label>`. The label is the signal: it's what the reminder and release-candidate workflows query, and an unresolved one blocks the promotion to production. The `NEEDS_TESTING` checkbox is read once, at merge, by the labeler that adds the label; unchecking it afterwards changes nothing, so don't mistake an unchecked box for a cleared flag. Confirm before removing (outward-facing), and post a one-line note saying what was verified and against which sha.

## Gates (the only reasons to stop)

- **Ambiguity** — requirements/acceptance genuinely unclear, or a material choice between different solutions that changes scope. Surfaced by `understand-task`; relay and wait.
- **Plan checkpoint** — **always**, before building anything (plan mode). Sized to the change, never skipped for being small.
- **Risk** — before public-API/auth/security/PII/destructive/protected-branch/cross-team actions (B1), before a merge (owned by `pr-merge`'s conditions), and before filing any follow-up ticket (owned by `post-merge-cleanup`).

Everything else runs autonomously — including auto-fixing CI, addressing clear AI-reviewer comments, and merging with confidence once every condition holds.

## Handoff / resume

The ledger is the single source of truth. On any pause (a gate, `/loop` between babysit cycles, end of session), it already holds `phase`, per-unit `status`, `deferred_items`, and PR numbers — so a later `deliver --resume` (or a fresh session) picks up exactly where this left off. A task started **outside** `deliver` (no ledger — PRs opened by hand or via `pr-open`) is picked up the same way: A0 adopts it from git/PR state (or `--stage`) into a fresh ledger, then resume behaves identically. Keep a one-line status when you pause: `deliver: task <slug> — unit <i>/<N> in <phase>; <what's next>.`

## Ticket status sync

When the task has an associated tracker ticket (`task_ref`) and `ticket_sync.enabled`, `deliver` moves it **forward** through the workflow as work progresses — autonomously (a low-risk internal status update), and only ever forward. The mechanics (read current status → valid transitions → match intent → forward-only guard → apply, via the connected Atlassian/Linear MCP) live in **`refs/ticket-status.md`** — Read it and follow it for each transition.

Three milestones:
- **→ In Progress** — start of Phase B (first unit's execute begins). Fires once.
- **→ In Review** — the first time the task has an open PR (after the first `pr-open`, or on adoption when A0 finds one). Fires once.
- **→ Done** — owned by `post-merge-cleanup`, **not here**: `pr-babysit` self-wraps in `/loop`, so the merge happens detached from this conductor across later turns. `post-merge-cleanup` runs *at* merge completion, on the **last** unit, and does the Done transition there (gated on the same `ticket_sync.enabled`).

Guards (all in the ref): skip silently if no ticket / the tracker MCP is absent this session / `--no-ticket-sync`; never move a ticket backward or fight a manual move (forward-only via a status-rank table); record each transition in `ticket_sync` so it's idempotent across `/loop` cycles and resumes. Set `TICKET_DONE_CONFIRM` to confirm before Done.

## Learn from every iteration

Two triggers keep the pipeline sharpening:
- **When the user corrects how you ran the cycle** — a phase they wanted skipped or added, a gate that should/shouldn't have stopped, a wrong-sized breakdown, a convention missed — treat it as a durable lesson, not a one-off.
- **End-of-run reflection (proactive — do this, don't wait to be told).** When a run finishes — the task's last unit merges, or you pause/stop mid-way — take one beat and ask: *did anything about how this ran warrant a skill or memory edit?* (a gate that mis-fired, a phase you improvised, a breakdown that was the wrong size, a repeated manual step worth encoding, a convention you had to be reminded of). If yes, act on it now (routing + show-first below). If nothing surfaced, say so in one line and move on — never invent a lesson to seem diligent.

Fold each real lesson into the **right** place: spine/gate/breakdown lessons here in `deliver`; stage-specific lessons into `understand-task` / `self-review` / the `pr-*` skills; durable facts into a memory. **A skill edit changes every future run, so show the exact edit first — which skill + section + the new/changed wording — and apply it only once the user confirms** (prefer refining or replacing an existing line over adding one). A one-off fact is a memory, not a skill rule — write those directly and mention them. Keep each skill lean — if an edit grows a section, cut a sentence elsewhere. This is how the pipeline gets sharper with use.

## Hard constraints

- Carry no conventions of your own — defer to repo `CLAUDE.md`, module `AGENTS.md`, and the user's memories at every step. Don't duplicate them here.
- Never start execution on a `PROTECTED_BRANCHES` branch. Never merge outside `pr-merge`; never delete a branch/worktree outside `post-merge-cleanup`.
- Respect every sub-skill's own hard constraints (rebase/force-push rules, `--no-verify` limits, never touching human threads, no Slack without approval, no follow-up filed without approval).
- Outward-facing written content — PR titles/descriptions (`pr-open`) and review-thread replies (`pr-babysit`) — is written in Luis's voice via the `voice` skill (see their **Voice** notes); a reply to a human still needs his approval.
- Stop at the gates; otherwise keep the task moving to done.
