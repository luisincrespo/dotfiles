# Ticket status sync

Loaded by `deliver` (In Progress, In Review) and `post-merge-cleanup` (Done) to move an associated tracker ticket **forward** through the dev workflow as the task progresses. The procedure below is tracker-neutral; the per-tracker calls live in **Tracker adapters** at the bottom. Use whichever tracker the ticket belongs to and whose connector is available this session.

## Gate — only run when ALL hold
- The task ledger has a `task_ref` with a ticket (`{tracker, id, url}`) **and** `ticket_sync.enabled == true`.
- That tracker's connector is available this session (its MCP tools, or a CLI). Interactively-authenticated MCPs can be **absent in headless/cron runs** — if the tool isn't there, **skip silently** (batch one line the first time: `Ticket sync skipped — no <tracker> connector this session.`).
- `--no-ticket-sync` was not passed.

Any fail → no-op (never block the task on ticket sync).

## Intended states (ranked)
`to_do`(0) < `in_progress`(1) < `in_review`(2) < `done`(3). Each caller passes one **target intent**: `in_progress` | `in_review` | `done`.

## Procedure (per transition)
1. **Read current state.** Adapter's *read* call → the ticket's current state. Rank it: if the tracker exposes a native state **category**, use that (it beats matching display names, which teams rename freely); otherwise fall back to the synonym table below.
2. **Forward-only guard.** If `current_rank >= target_rank` → **skip** (already at/past it — covers a human moving it ahead, or the project's own PR/merge automation already advancing it). **Never move a ticket backward**, and never fight a manual move. A terminal state the ranks don't cover (cancelled, won't-do, duplicate) → **skip and leave it alone**; that is a decision someone made.
3. **Resolve the target.** Adapter's *resolve* call → the concrete transition or state to apply, matched to the intent.
   - No confident match, or multiple ambiguous matches → **don't guess.** Batch: `Ticket <id>: couldn't map "<intent>" to a workflow state (available: <names>) — move it manually or tell me which.` and return.
4. **Apply.** Adapter's *apply* call. Announce one line: `🎫 <id> → <state name>.`
5. **Record.** Set `ledger.ticket_sync.<intent> = true` (idempotent — a re-run hits the step-2 skip).

## Status synonym table (case-insensitive; extend per your projects)
Used when the tracker has no native state category, and to separate ranks a category lumps together.

- **to_do / backlog (0):** `To Do`, `Backlog`, `Open`, `Selected for Development`, `Ready`, `Reopened`.
- **in_progress (1):** `In Progress`, `In Development`, `Doing`, `Start Progress`.
- **in_review (2):** `In Review`, `Code Review`, `In Code Review`, `Ready for Review`, `Review`, `PR Review`.
- **done (3):** `Done`, `Closed`, `Resolved`, `Complete`, `Completed`, `Merged`, `Shipped`.

An unrecognized state name → treat as rank 0 (safe: still allows forward moves) and log it so the table can be extended.

## Posture
**Autonomous** — low-risk internal workflow updates, no per-transition approval (matches "move the ticket as the task progresses"); the forward-only + no-fight-manual guards keep it safe. To make **Done** confirm-first, set `TICKET_DONE_CONFIRM` in the caller's config → batch a one-line confirm instead of transitioning.

## Tracker adapters

### Jira — Atlassian MCP
- **read:** `getJiraIssue <id>` → `status.name`. No reliable category, so rank via the synonym table.
- **resolve:** `getTransitionsForJiraIssue <id>` → transitions valid *from the current status*; pick the one whose **target status** matches the intent. Jira is transition-graph based, so the wanted status may simply not be reachable from here — that is a legitimate "no match", not a failure.
- **apply:** `transitionJiraIssue <id> <transitionId>`.
- Transitions here are usually pure status moves — leave labels and automation (e.g. `keep-active`) alone. The forward-only guard means we won't double-move if a Jira↔GitHub integration already advanced the status.

### Linear — Linear MCP
- **read:** `get_issue <id>` → the issue's workflow state, and prefer its **`type`** over its name — teams rename states freely but the type is fixed: `triage`/`backlog`/`unstarted` → rank 0, `started` → rank 1+, `completed` → rank 3, `canceled` → terminal, skip per step 2.
- `started` covers **both** `in_progress` and `in_review`, so when the current or target rank is 1 vs 2, disambiguate among the team's `started` states by name via the synonym table.
- **resolve:** `list_issue_statuses` for *this issue's* team — states are **per-team**, so never reuse an id seen on another team's issue.
- **apply:** `save_issue` with the target state id. Setting state directly. Linear has no transition graph, so any state is reachable — which makes the forward-only guard in step 2 the only thing preventing a backward move. Do not skip it.

### GitHub issues
- No universal "status" — use the repo's convention (a `status:*` label via `gh issue edit`, or a Projects board column). Skip if the convention is unclear.
