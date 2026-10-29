---
name: self-review
description: >-
  Review your OWN branch or uncommitted changes before pushing or opening a PR. Runs the repo's
  gates (lint, typecheck, build, tests), then correctness, simplification and security passes
  over the diff, plus design, UX, performance, AI-usage, React, API-shape and accessibility
  passes when the change touches what they cover; fixes the clear findings and batches judgment
  calls for you, looping until the diff is clean. Use for "self-review", "check my diff", or
  before pr-open. For someone ELSE's PR use pr-review.
allowed-tools:
  - Skill(code-review)
  - Skill(simplify)
  - Skill(security-review)
  - Agent
  - Read
  - Grep
  - Glob
  - Edit
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git show:*)
  - Bash(git log:*)
  - Bash(git rev-parse:*)
  - Bash(git merge-base:*)
  - Bash(git branch --show-current)
  - Bash(npx nx affected:*)
  - Bash(npx nx eslint:lint:*)
  - Bash(npx nx test:*)
  - Bash(npx nx build:*)
  - Bash(npx nx format:write:*)
  - Bash(npx tsc:*)
  - Bash(npx prettier --write:*)
  - Bash(pnpm lint)
  - Bash(pnpm test:*)
  - Bash(pnpm build:*)
  - Bash(pnpm install)
  - Bash(yarn install)
  - Bash(yarn lint:*)
  - Bash(yarn test:*)
  - Bash(yarn build:*)
  - Bash(yarn workspace:*)
  - Bash(bun install)
  - Bash(bun run:*)
  - Bash(bun test:*)
  - mcp__ide__getDiagnostics
  # Step 3.6's second opinion (passes/second-opinion.md). Narrow to the non-interactive review
  # verb: this hands over your diff, so the grant should not also cover an interactive session or
  # a subcommand that writes.
  - Bash(codex exec:*)
---

# self-review

The **verify** stage: put your own diff through the same scrutiny a reviewer would, *before* asking anyone else to look. Distinct from `pr-review` (which reviews other people's PRs) — this is your work, and the point is to catch problems while they're cheap to fix.

The checks themselves live in `passes/` in this skill's folder, and `pr-review` reads the same files. This file decides when each runs on your own diff and what happens to what it finds. Read each pass file when its step comes, not up front.

## Args (all optional)

- `--base <branch>`: what to diff against for "the change." Default: the merge-base with the repo's default branch (so it covers the whole branch, not just uncommitted work). Pass a parent branch for a stacked unit so it reviews only that unit's diff.
- `--task-slug <slug>`: when invoked by `deliver`, so batched findings can be noted against the task.

## Step 1 — Scope the diff
- Compute the changeset: `git diff --name-only <base>...HEAD` plus any uncommitted changes (`git status --porcelain`). List the affected packages. **Resolve `<base>` to its remote-tracking ref (`origin/<base>`) when one exists** — in a worktree the local branch ref is frozen at creation time, so a bare name can be far behind and silently widen the diff to include other people's commits.
- Decide which **targeted passes** apply, by each file's own *When it applies*: `design.md`, `ux.md`, `performance.md`, `ai-usage.md`, `react.md`, `api-shape.md` and `accessibility.md`, all in `passes/`. Give the design and UX passes what they need to know first: the brief, ticket or project page for what's coming next, and the exercise pass's states when it ran. Note the ones that don't, so the report can say so.

## Step 2 — Automated gates (fix failures)
Run the repo-appropriate checks scoped to the change (don't reformat the world):
- **Read the repo first** — its `CLAUDE.md`/docs name the real lint, build, test and typecheck commands, and the package manager that runs them. Never assume a build system or a package manager.
- **A single command that bundles several gates is the whole gate.** When the repo says its one command already covers lint, types and formatting, run that and do **not** re-run the parts after it. A repo stating "type checking is included, don't run `tsc`/`check-types` separately" means it: the second pass costs minutes and can disagree with the bundled one.
- **Only when the repo names nothing**, fall back by ecosystem. nx monorepos: `npx nx affected --target=eslint:lint|build|test --base=<base> --head=HEAD` (fall back to `lint` if `eslint:lint` isn't the target). Typecheck via **IDE diagnostics first** (`mcp__ide__getDiagnostics`), falling back to scoped `npx tsc --noEmit`.
- **Repo addenda:** run any `verification_addenda` from `~/.agents/local/config.json` whose `when_paths_under` prefix matches a changed path — e.g. a nested app that owns a separate pipeline.
- **Check each gate actually ran** before trusting what its output doesn't contain: a filter over a failed command's output is not evidence (`passes/claims.md`, *Evidence that isn't*).
Fix failures at the source (preferred) or test. Run the formatter over **only the changed files** (`npx prettier --write <files>`, `ruff format`, `gofmt -w`, `cargo fmt --`, whatever the repo uses), never a format-everything target — it reformats unrelated code and buries the real diff.

## Step 3 — Compose the review passes

**Hand every pass the diff's location explicitly, and make it prove it found one.** A review command or agent resolves its target from the shell's working directory, which under `deliver` is the main checkout, not the task worktree — so it reviews a clean tree and wanders into unrelated history without saying so. Put the worktree path in the prompt and require the reviewer to confirm a non-empty diff touching the expected paths *before* reviewing. (Step 3.6's second opinion is the exception: it gets the diff itself, never a path to the checkout, for the reasons `passes/second-opinion.md` gives.) A pass that can't state what it looked at has not run, whatever it reports — an empty diff and a clean diff produce the same verdict.

Run these over the diff and collect findings:
- **Correctness / bugs** (the primary hunt) — `Skill(code-review)` (bundled with Claude Code), with the diff as a revision range so it reviews this branch whatever is checked out: `<effort> origin/<base>...<branch>`. `<effort>` is local config's `code_review_effort` for this repo (its own `github/<owner>/<repo>` entry, else `*`, else `high`), read on every run. Never `--fix` or `--comment`: Step 4 decides what gets fixed. It runs as a background subagent and reports when done, so wait for its findings before Step 4. It doesn't read `REVIEW.md`; the convention sweep does. Not available (turned off with `skillOverrides`, or another harness) → launch a native review-focused `Agent` over the diff instead. `ultra`, a deeper review in the cloud that costs usage credits after a few free runs, only when the user asks for it.
- **Reuse / simplification** — `Skill(simplify)` (native built-in; quality only, applies its own fixes).
- **Security** — `Skill(security-review)` (native built-in) over the pending changes.
- **Targeted passes (the ones Step 1 found apply)** — for each, launch a native `Agent` (general-purpose) over the diff, briefed to read and apply its file from `passes/` (give it the absolute path). The file is the whole checklist. Clear, bounded fixes are fix-now in Step 4; the trade-offs a file names are batched. A pass that doesn't apply is skipped, and the report says so.
Run the independent passes in parallel where the tooling allows.

## Step 3.5 — Exercise it
When the change is user-facing and you can launch the app, run it as `passes/exercise.md` says, from *this* checkout. For a fix, "works as intended" means the defect is gone. Name the states you exercised in the report, and what stayed unverified.

## Step 3.6 — Second opinion, different model

Follow `passes/second-opinion.md`. Here the payload is `git diff $(git merge-base origin/<base> HEAD)` plus each changed file's full text from the worktree, and what comes back goes through Step 4 like your own findings. Step 4 also says when it runs again.

## Step 4 — Triage & fix (loop)
Triage fix-now vs batch:
- **Check the claim before acting on it.** A finding that asserts absence, equivalence, redundancy or the like gets checked as `passes/claims.md` says before you fix it: a wrong "this is redundant" becomes a fix that deletes load-bearing code.
- **Fix now** — clear, bounded, and you can verify the fix (obvious bugs, a missing `const`, a reuse the simplify pass surfaced, a genuine a11y defect, a query hoisted out of a loop). Apply, then re-run the relevant Step-2 check.
- **Batch** — anything ambiguous, opinion-driven, cross-cutting, or where the "fix" needs a judgment call (including a Sonar/linter rule that fights another). Present these to the user with `file:line` + why-unsure; don't guess.
- After applying fixes, **re-review the changed areas** — don't stop at one pass; a fix can introduce a new issue. Loop Steps 2–4 until the automated gates are green and no clear findings remain.

**Converging with the second opinion.** Its findings are not privileged: triage them exactly like
your own, fix-now or batch. Then re-run Step 3.6 on the amended diff, up to `max_rounds`.

Three things end the loop, and one of them must:

- **Both clean.** Done.
- **The cap.** A second model will always find *something* on a large diff, so rounds are capped
  rather than run to silence. **The cap stops re-running the second opinion, not fixing.** A clear,
  bounded defect found on the final round is still fixed and still verified by your own Step 2
  gates — Step 4's ordinary rule — and the report says it landed after the last second-opinion
  round, so nobody reads it as having been double-checked.
- **A finding you think is wrong.** Do not edit code to make a reviewer stop saying it — that is
  how a correct implementation gets bent toward a misreading. State both positions with
  `file:line`, batch it, and let the user settle it.

A finding already batched does not restart the loop; re-raising it is the same finding, not a new
round.

## Step 5 — Convention sweep (reference, don't restate)
Apply `passes/conventions.md` to the diff, the repo's `REVIEW.md` included: it lists what a reviewer here will flag, so a miss caught now is one they don't have to raise. Flag anything off as a fix-now or batch item.

## Output
When the loop settles, report: gates status (green/what's red), what you ran it against (or why you couldn't), what you fixed, and the batch (unresolved items for the user). If `--task-slug` was set, fold unresolved items into the task ledger's notes. This stage does **not** commit, push, or open a PR — it leaves a clean, reviewed diff for the next stage (`pr-open`).

## Step 6 — Capture learnings (self-educate)
After reporting, take one beat: did anything about *how this review ran* warrant a durable edit? Never invent one — "nothing to capture" is the common and correct answer, said in a line and moved past.

What actually recurs here:
- **A gate Step 2 got wrong** — the repo's real lint/test/build invocation, a bundled command whose parts shouldn't be re-run after it, a package manager the fallbacks don't cover.
- **A finding the user waved off** — something flagged that this codebase does deliberately. Record it so the next run doesn't re-raise it.
- **A pass that produced noise** instead of findings, or one that keeps earning its place.

Route by **portability**, which decides the file:
- **Repo- or employer-specific mechanics** (the actual command, a nested pipeline, a host) → `verification_addenda` or another key in `~/.agents/local/config.json`. This skill travels between jobs; a build command naming a private package doesn't belong in it.
- **A procedure that recurs on one project** → a project skill (global rule 13).
- **A convention that's the user's own taste** (they corrected something the review let through, or waved off something it flagged as theirs) → `passes/personal-conventions.md`, the personal layer, rather than the shared passes.
- **A lesson that would hold at any job** → the relevant section of this skill, or, when it's about a check itself, its file in `passes/`. `pr-review` reads those too, so word the lesson for both: what the check looks for, not what happens to the finding here.
- **A durable one-off fact** → a memory, not a rule.

**Under `deliver`** (`--task-slug` set): don't edit a skill here. Hand the lesson up with the batch — `deliver`'s end-of-run reflection owns the routing, and two skills acting on one lesson records it twice.

**Apply the edit yourself and say what you changed** (which file, which section, the new wording), unless it's consequential (global rule 13). Prefer refining an existing line to adding one; if a section grows, cut a sentence elsewhere.

## Hard constraints
- Review *your* changes only; don't wander outside the diff hunting for unrelated issues (that's not the job, and it inflates scope).
- Don't invent findings to seem thorough — a clean diff is a valid result.
- Fix at the right layer: a real product bug the change exposes is fixed in source, not papered over in a test. For a problem *outside the task* — and the task decides that, since a refactor's whole point is changing existing code — take it only if it's a genuinely quick win; otherwise batch it rather than silently widening the diff.
- When the change bundles fixes for several diagnosed causes, or its commit message or description repeats an inherited account of what went wrong, check each cause as `passes/claims.md` (*Causation*) says before it ships. A fix for a cause that doesn't exist still passes every test written for it.
- Never bypass a check to make it pass.
