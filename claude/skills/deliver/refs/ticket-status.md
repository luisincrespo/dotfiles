# Ticket status sync

Loaded by `deliver` (In Progress, In Review) and `post-merge-cleanup` (Done) to move an associated tracker ticket **forward** through the dev workflow as the task progresses. Jira-first via the connected Atlassian MCP; Linear / GitHub-issue trackers are analogous via their connectors.

## Gate — only run when ALL hold
- The task ledger has a `task_ref` with a ticket (`{tracker, id, url}`) **and** `ticket_sync.enabled == true`.
- The tracker's connector is available this session (e.g. the Atlassian MCP tools). Interactively-authenticated MCPs can be **absent in headless/cron runs** — if the tool isn't there, **skip silently** (batch one line the first time: `Ticket sync skipped — no <tracker> connector this session.`).
- `--no-ticket-sync` was not passed.

Any fail → no-op (never block the task on ticket sync).

## Intended states (ranked)
`to_do`(0) < `in_progress`(1) < `in_review`(2) < `done`(3). Each caller passes one **target intent**: `in_progress` | `in_review` | `done`.

## Procedure (per transition)
1. **Read current state.** Jira: Atlassian MCP `getJiraIssue <id>` → current `status.name`. Map it to a rank via the synonym table below.
2. **Forward-only guard.** If `current_rank >= target_rank` → **skip** (already at/past it — covers a human moving it ahead, or the project's own PR/merge automation already advancing it). **Never move a ticket backward**, and never fight a manual move.
3. **Resolve the transition.** Jira: `getTransitionsForJiraIssue <id>` → transitions valid *from the current status*. Pick the one whose **target status** matches the intent via the synonym table (case-insensitive).
   - No confident match, or multiple ambiguous matches → **don't guess.** Batch: `Ticket <id>: couldn't map "<intent>" to a workflow transition (available: <names>) — move it manually or tell me which.` and return.
4. **Apply.** Jira: `transitionJiraIssue <id> <transitionId>`. Announce one line: `🎫 <id> → <status name>.`
5. **Record.** Set `ledger.ticket_sync.<intent> = true` (idempotent — a re-run hits the step-2 skip).

## Status synonym table (case-insensitive; extend per your projects)
- **to_do / backlog (0):** `To Do`, `Backlog`, `Open`, `Selected for Development`, `Ready`, `Reopened`.
- **in_progress (1):** `In Progress`, `In Development`, `Doing`, `Start Progress`.
- **in_review (2):** `In Review`, `Code Review`, `In Code Review`, `Ready for Review`, `Review`, `PR Review`.
- **done (3):** `Done`, `Closed`, `Resolved`, `Complete`, `Completed`, `Merged`, `Shipped`.

An unrecognized status name → treat as rank 0 (safe: still allows forward moves) and log it so the table can be extended. On many org Jira boards, transitions here are pure status moves — leave labels/automation (e.g. `keep-active`) alone; the forward-only guard means we won't double-move if a Jira↔GitHub integration already advanced the status.

## Posture
**Autonomous** — low-risk internal workflow updates, no per-transition approval (matches "move the ticket as the task progresses"); the forward-only + no-fight-manual guards keep it safe. To make **Done** confirm-first, set `TICKET_DONE_CONFIRM` in the caller's config → batch a one-line confirm instead of transitioning.

## Trackers other than Jira
- **Linear:** the connected Linear MCP — read the issue's workflow state, move to the state matching the intent (same synonym idea; states are per-team).
- **GitHub issues:** no universal "status" — use the repo's convention (a `status:*` label via `gh issue edit`, or a Projects board column). Skip if the convention is unclear.
