---
name: pr-open
description: >-
  Open one MR/PR for the current branch. Follows the user's conventions: a concise title with any
  ticket referenced in the summary rather than the title, the repo's template filled reviewer-
  facing, draft-if-stacked, and Storybook screenshots for UI changes. It creates and returns; it
  does not poll, babysit or merge. Use deliver for the full lifecycle, this directly when you want
  create-without-babysit.
allowed-tools:
  - Bash(glab api:*)
  - Bash(glab mr list:*)
  - Bash(glab mr create:*)
  - Bash(gh api:*)
  - Bash(gh pr list:*)
  - Bash(gh pr create:*)
  - Bash(gh repo view:*)
  - Bash(git remote get-url:*)
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(git rev-parse:*)
  - Bash(git branch --show-current)
  - Bash(git fetch origin:*)
  - Bash(git rev-list --count:*)
  - Bash(git push origin:*)
  - Bash(git diff --name-only:*)
  - Bash(jq:*)
  - Bash(mkdir -p:*)
  - Bash(cat:*)
  - Read
  - Skill(voice)
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_wait_for
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_resize
  - mcp__playwright__browser_close
---

# pr-open

Opens **one** MR/PR for the current branch and returns. This is the create stage of the `deliver` pipeline — the babysitting/merge/cleanup happen in `pr-babysit` → `pr-merge` → `post-merge-cleanup`. Platform is detected from `git remote get-url origin`; "MR" = Merge Request (GitLab), "PR" = Pull Request (GitHub).

**Terminology in user-facing text.** Write **"PR"** on GitHub and **"MR"** on GitLab in everything you announce; never call a GitHub PR an "MR" or vice-versa.

**Fully automatic** — only stop to ask when a required input genuinely can't be derived (see Step 4), or a risk gate trips (protected branch).

## Args (all optional)

- `--target <branch>` / `--base <branch>`: base branch for the new MR/PR. Default: the repo's default branch. When `deliver` opens a **stacked** unit, it passes the previous unit's branch here (which also makes this MR a draft).
- `--task-slug <slug>`: the `deliver` task this unit belongs to, used to update the task ledger's `units[]` entry with the created PR number. Omit when run standalone.
- `--no-review-ping`: skip the Step 7 review-request draft entirely.

## Config

> **Local overrides.** Values below are portable defaults. If `~/.agents/local/config.json` exists,
> its keys override or extend them (schema: `~/.agents/local/config.example.json`); any key absent
> there keeps the default. `config.json` is machine-local and never committed.

- `PROTECTED_BRANCHES`: `["main", "master", "stage-*"]` + `protected_branches_extra`. Entries are **glob patterns**: a bare name matches exactly, `*` matches any run of characters. A branch is protected if it matches any entry — so `rc-*` covers every dated release candidate, and a literal `prod` still matches only itself.
- `SCREENSHOT_WIDTH_PX`: `400` (reviewer-friendly default; ~640 for full-page/wide layouts)
- `SCREENSHOT_MARKER`: `<!-- pr:screenshots:start -->` … `<!-- pr:screenshots:end -->` (skill-owned, delimited region)
- `REVIEW_REQUEST_CHANNEL`: unset + `review_request_channel` — the Slack channel the Step 7 draft is addressed to.
- `REVIEW_REQUEST_HANDLE`: unset + `review_request_handle` — the group handle to @-mention there. Unset ⇒ fall back to named reviewers or a placeholder.

## Step 0: Platform + already-open guard

1. `git remote get-url origin` → contains `github.com` ⇒ `github`; contains `gitlab` ⇒ `gitlab`; else announce and stop.
2. `branch = git branch --show-current`. If `branch` matches `PROTECTED_BRANCHES` → announce and stop (never open from a protected branch).
3. Already-open check:
   - **GitLab**: `glab mr list --source-branch <branch> --state opened --output json`.
   - **GitHub**: `gh pr list --head <branch> --state open --json number,url`.
   - Non-empty → announce `Found existing <platform> MR/PR for <branch> (<url>); nothing to open.` and return the existing number to the caller.

## Step 1: Target + preconditions

- Default branch: GitHub `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`; GitLab `glab api projects/<repo_id> --jq .default_branch`. Fallback `main`.
- `target` = `--target` if passed, else the default branch. `git fetch origin <target>`.
- **Clean tree**: `git status --porcelain` empty. Else stop: `Uncommitted changes on <branch> — commit them first.` (Never auto-commit arbitrary work.)
- **Has commits**: `git rev-list --count origin/<target>..HEAD` ≥ 1. Else stop: `<branch> has no commits ahead of <target>; nothing to open.`
- **Pushed**: `git push origin <branch>` (idempotent).

## Step 2: Title (concise — NO ticket prefix)

**Voice — write the title AND the Step 3 description in Luis's voice.** Follow the `voice` skill's ground truth (its `refs/principles.md`, `refs/examples-pr-descriptions.md` — the source of truth for his written style): plain, concise, first-person where natural, not robotic or "sophisticated." The template *structure* stays; the *prose within* sounds like him. This is drafting editable PR metadata (kept current by `pr-babysit`), not a message to a person — so no separate send-approval gate.

- Write a concise, imperative one-line summary of the diff (e.g. `Make onboarding progression resilient to storage failures`).
- **Do NOT prefix with a ticket id** — the ticket reference goes in the description summary (Step 3), so you never need to ask about a ticket for the title.

## Step 3: Description / template (reviewer-facing)

- Find the repo template: **GitLab** `.gitlab/merge_request_templates/*.md`; **GitHub** `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, or `.github/PULL_REQUEST_TEMPLATE/*.md`. Multiple → pick by changed paths (`git diff --name-only origin/<target>..HEAD`): extension template under `apps/extension/`, http-client template for `libs/http-clients-*`, else the default.
- Fill sections from the diff, kept **reviewer-facing**:
  - **Reference the related ticket in the Summary (not the title).** Detect a ticket id (`[A-Z][A-Z0-9]+-\d+` — matches Jira and Linear alike) in the branch/commits and add a brief line (e.g. `Part of ABC-1001.`) when the change is part of a ticket. If the caller (`deliver`) knows a ticket that isn't in the branch/commits, use it. Standalone fix/chore with no ticket → omit; don't ask.
  - **Open the summary with one or two plain sentences saying what the change is**, then bullets only for what genuinely needs separate calling out — kept short. A stack of bold-lead bullets reads robotic: the lead is taxonomy, not information, and the reviewer never gets a sentence telling them what the PR does. A bullet that runs to a dense paragraph is the same failure in another shape. Explaining *each* sub-change's mechanism is the most common way this goes wrong: a reviewer reads the diff for mechanism and the description for intent. Name what changed in one sentence; don't narrate the chain of cause for every part.
  - **State decisions; never solicit.** A description is not a place to ask for a second opinion, flag what you're unsure about, or invite the reviewer to weigh in on an approach — the review itself is that conversation. A genuine trade-off the reviewer should know about is stated as a fact ("returning to a deep grid shows cached data until something invalidates it"), not as a question. This holds even for a repo template section that *invites* uncertainty ("anything you'd like a closer look at?"): answer it with the trade-off, not with a request.
  - **"Testing" / "Test plan" = numbered steps a reviewer can go and run** (e.g. "open the side panel, switch agents, confirm the card renders"), each saying what to do and what they should see. It must **never** describe what *you* did to validate ("added unit tests", "wrote a story", "ran e2e") — that's worthless to a reviewer. **This wins over a repo template that prescribes a different shape** for the section (a claim/evidence table, an assertion/proof pair): keep the repo's heading, fill it with reviewer steps. Nothing to manually check → say so briefly.
  - Leave checklist boxes unchecked. Separately, when the change can only be verified by exercising
    the running app against real data, opt into the repo's staging-verification flag by its own
    mechanism — usually a label, not a template checkbox (see local config) — set
    `needs_staging_verification: true` on the ledger unit, and say so in the report: it creates a
    human obligation with a deadline. Reviewer test-plan steps alone are not the trigger; the bar is
    that a regression would be invisible to CI and unit tests.
  - **Drop a template section this diff can't fill** — e.g. a `## Changeset` section when the change touches no versioned package. Check the repo's own layout for which paths those are; don't assume `libs/**`. **When the repo's own instructions say to always follow the template, keep every section instead and write one line saying why it's empty** — a missing heading reads as not having followed the template, and that's what gets asked about in review. A section whose own text is conditional ("if X was created, paste it here") is satisfied by **omitting** it when X doesn't exist — don't keep the heading to write "n/a", and never fill it with a substitute because the slot is there.
  - Don't cite Figma nodes, design-source names, or sibling implementations ("mirrors X.tsx"); describe behavior so each line stands alone.
  - **Describe the change as it stands in the final diff — what it does and why — not how it got there.** Out: file-by-file maps, function lists, code-level references, "changed from X to Y" for decisions internal to *this* PR, alternatives you weighed, reasoning you worked through, and corrections to the ticket's premise. Explain a decision only when it is critical *and* a reader can't get it from the code and its comments; when the repo asks you to name a rejected alternative, that's one clause. Describing the prior behavior of already-shipped code this PR *fixes* is fine.
  - **Reference other PRs as full URLs, never bare `#123`** (stacked base, follow-up, etc.). For a stacked unit, fold the stack into whichever template section already carries context or the ticket reference — never a section of its own, and never above the summary: an ordered list in merge order, one line per PR as `<short title> — <full URL>`, the current one bolded and marked `**← this PR**`.
- No template → write a short reviewer-facing description (what + why, a few lines). Same rules.

## Step 4: UI screenshots (when snapshottable UI changed)

Give reviewers Storybook screenshots. **Capture at create time (interactive — permission prompts are fine).**

**Gate — only run when all hold:** there are changed component files (`*.tsx`/`*.jsx`/`*.vue`/`*.svelte` in the diff that are NOT `*.stories.*`/`*.spec.*`/`*.test.*`); at least one has a co-located story (`Foo.tsx` → `Foo.stories.tsx`) — scope = the stories of those changed components only; Playwright MCP is available. Gate fails → skip silently and open without them (one-line note if Playwright was the blocker).

Gate passes → Read `refs/storybook-screenshots.md` and follow it. Delivery differs by platform:
- **GitHub** (manual attach): capture in-scope stories to `~/Desktop/pr-screenshots-<branch>/` with descriptive filenames, create the PR **without** embedding, then tell the user where the folder is and that they drag-drop the images in. **Then arm a `Monitor` polling the PR body every 60s that emits when the `<img>` count rises** (`gh pr view <n> --json body --jq .body | grep -c '<img'`). On that event, fold the new images into the `## Screenshots` section without waiting to be asked, and stop the monitor once every captured file is accounted for. Tell him it's armed so he knows not to prompt.
  - **Layout:** screenshots live in the `## Screenshots` section, never above `## Summary` — a reviewer should read what the change is before seeing pictures of it. Group by state, one labelled light/dark table each, with a short line saying when that state shows. Strip `width`/`height` off dropped uploads so they scale to their cell.
- **GitLab** (auto-embed): upload each via the uploads API and embed a `SCREENSHOT_MARKER`-wrapped, reviewer-sized `## Screenshots` block into the Step-3 description before creating.

Any capture step fails → don't block; create without screenshots and note it in one line.

## Step 5: Draft vs ready

- **Draft** if `target != default branch` (stacked — base is another feature branch). **Ready** otherwise.

## Step 6: Create

- **GitLab**: `glab mr create --source-branch <branch> --target-branch <target> --title "<title>" --description "<desc>" [--draft] --yes`
- **GitHub**: `gh pr create --base <target> --head <branch> --title "<title>" --body "<desc>" [--draft]`
- `--draft` only when Step 5 says draft.
- Announce: `✅ Opened <web_url> (<draft|ready>, → <target>).`
- If `--task-slug` was passed, update that unit's `pr_number`/`status:"open"` in the task ledger (`~/.claude/cache/deliver/task-<repo-dashes>-<slug>.json`).
- **Never send Slack automatically.** A review-request ping is drafted in Step 7 for Luis to send himself.

## Step 7: Review request (draft via `voice` — generate, don't send)

Only for a **ready** PR (skip a draft/stacked unit — its review request happens when it's promoted to ready in `post-merge-cleanup`). Unless `--no-review-ping`:

- Invoke `Skill(voice)` to **draft** a Slack review-request in Luis's voice, following his convention: the review-request template (global `CLAUDE.md` rule #6 — `PR to <one-line of what it does>`, a blank line, then the PR `web_url`; `MR to …` on GitLab), addressed to `REVIEW_REQUEST_CHANNEL` and opening with `REVIEW_REQUEST_HANDLE`. **Prefer that group handle over naming individuals** — it reaches whoever is free, which is how a claim-by-reaction channel works. With no handle configured, use whoever Luis names (an arg or in-conversation), else leave a clear `@<reviewer>` placeholder for him to fill.
- **Announce a stack as a stack**: say so in the first line, then one line per PR in merge order giving what that PR alone handles, its full URL, and a marker on any that are draft — a reviewer has to know which to pick up first.
- **Generate it, don't send it.** Present the draft for Luis to send himself — that's his default. Send it yourself only if he *explicitly* tells you to this run.
- Autonomous (`deliver`) run: surface the draft alongside the open announcement (`✅ Opened <web_url> (ready). Review-request draft ready for you to send.`) and let `pr-babysit` proceed — don't wait on it.

Then **return to the caller** — do not loop or babysit. `deliver` (or the user) hands off to `pr-babysit` next.

## Step 8: Capture learnings (self-educate)
Once the PR is open, ask whether anything about how this ran warrants a durable edit. Never invent one — "nothing to capture" is the usual answer and deserves a line, not a paragraph.

What recurs at this stage: a template section filled or dropped wrongly; a title or summary convention the user corrected; where a repo actually keeps its template, or which one it picks for a given path.

Route it: repo- or employer-specific facts → `~/.agents/local/config.json`; a lesson that would hold at any job → this skill; a durable one-off → a memory. **When `deliver` invoked you**, hand it up with your report instead of editing — `deliver`'s end-of-run reflection owns the routing, and two skills acting on one lesson records it twice. **Show the exact edit and apply it only once the user confirms**; prefer refining an existing line to adding one, and if a section grows, cut a sentence elsewhere.

## Hard constraints

- Never open from a `PROTECTED_BRANCHES` branch. Never auto-commit uncommitted work — stop and ask.
- GitHub screenshots go to `~/Desktop/pr-screenshots-<branch>/` for manual attach — never push an assets branch or embed raw-URL images in a GitHub PR body.
- The Step 7 review-request is **generated, not sent** — Luis sends it himself; send it yourself only if he explicitly instructs it this run.
- Follow the repo `CLAUDE.md` and the user's feedback memories (ticket-in-summary-not-title, changeset conventions, reviewer-facing testing section) rather than re-deriving them.
