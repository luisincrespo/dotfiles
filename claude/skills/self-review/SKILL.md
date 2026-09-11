---
name: self-review
description: >-
  Review your OWN branch or uncommitted changes before pushing or opening a PR. Runs the repo's
  gates (lint, typecheck, build, tests), then correctness, simplification, security and, for
  frontend changes, accessibility passes over the diff; fixes the clear findings and batches
  judgment calls for you, looping until the diff is clean. Use for "self-review", "check my diff",
  or before pr-open. For someone ELSE's PR use pr-review.
allowed-tools:
  - Skill(simplify)
  - Skill(security-review)
  - Agent
  - Read
  - Grep
  - Glob
  - Edit
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git diff --name-only:*)
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
  - mcp__ide__getDiagnostics
---

# self-review

The **verify** stage: put your own diff through the same scrutiny a reviewer would, *before* asking anyone else to look. Distinct from `pr-review` (which reviews other people's PRs) — this is your work, and the point is to catch problems while they're cheap to fix. `/code-review` is one input this composes, not the whole thing.

## Args (all optional)

- `--base <branch>`: what to diff against for "the change." Default: the merge-base with the repo's default branch (so it covers the whole branch, not just uncommitted work). Pass a parent branch for a stacked unit so it reviews only that unit's diff.
- `--task-slug <slug>`: when invoked by `deliver`, so batched findings can be noted against the task.

## Step 1 — Scope the diff
- Compute the changeset: `git diff --name-only <base>...HEAD` plus any uncommitted changes (`git status --porcelain`). List the affected packages.
- Flag whether **frontend** files changed (`*.tsx`/`*.jsx`/`*.vue`/`*.svelte`/`*.css`/`*.scss`/`*.html`, or the repo's equivalent templates) — gates the accessibility pass.
- Note new components: a new `*.tsx` component in a package that has Storybook (`.storybook/` or existing `*.stories.*`) **must** have a story when the repo's `CLAUDE.md` requires one — flag if missing.

## Step 2 — Automated gates (fix failures)
Run the repo-appropriate checks scoped to the change (don't reformat the world):
- **Read the repo first** — its `CLAUDE.md`/docs name the real lint, build, test and typecheck commands. Never assume a build system.
- **nx monorepos** (one common case): `npx nx affected --target=eslint:lint|build|test --base=<base> --head=HEAD` (fall back to `lint` if `eslint:lint` isn't the target). Typecheck via **IDE diagnostics first** (`mcp__ide__getDiagnostics`), falling back to scoped `npx tsc --noEmit`.
- **Repo addenda:** run any `verification_addenda` from `~/.claude/local/config.json` whose `when_paths_under` prefix matches a changed path — e.g. a nested app that owns a separate pipeline.
Fix failures at the source (preferred) or test. Run the formatter over **only the changed files** (`npx prettier --write <files>`, `ruff format`, `gofmt -w`, `cargo fmt --`, whatever the repo uses), never a format-everything target — it reformats unrelated code and buries the real diff.

## Step 3 — Compose the review passes
Run these over the diff and collect findings:
- **Correctness / bugs** (the primary hunt) — `/code-review` is a native built-in *command*, not a Skill-tool skill, so it can't be called via `Skill()`. Default (autonomous): launch a native review-focused `Agent` over the diff. Alternative: the user runs `/code-review` themselves and feeds findings back.
- **Reuse / simplification** — `Skill(simplify)` (native built-in; quality only, applies its own fixes).
- **Security** — `Skill(security-review)` (native built-in) over the pending changes.
- **Accessibility (frontend only)** — launch a native `Agent` (general-purpose) to review the changed frontend files against WCAG 2.2 AA in the source. Skip when no frontend files changed. *(Deliberately plugin-free. If the user later vets a dedicated accessibility-reviewer plugin, its agent can be swapped in here — but this pipeline defaults to Anthropic-native tools + the user's own skills only.)*
Run the independent passes in parallel where the tooling allows.

## Step 4 — Triage & fix (loop)
Triage fix-now vs batch:
- **Fix now** — clear, bounded, and you can verify the fix (obvious bugs, a missing `const`, a reuse the simplify pass surfaced, a genuine a11y defect). Apply, then re-run the relevant Step-2 check.
- **Batch** — anything ambiguous, opinion-driven, cross-cutting, or where the "fix" needs a judgment call (including a Sonar/linter rule that fights another). Present these to the user with `file:line` + why-unsure; don't guess.
- After applying fixes, **re-review the changed areas** — don't stop at one pass; a fix can introduce a new issue. Loop Steps 2–4 until the automated gates are green and no clear findings remain.

## Step 5 — Convention sweep (reference, don't restate)
Confirm the diff honors the repo's own `CLAUDE.md` and the user's global rules + feedback memories, rather than re-deriving them. **Read the repo's `CLAUDE.md` for its conventions** — versioning/changeset rules, styling and design-system preferences, file-layout rules — instead of assuming another project's. From the user's global rules, the recurring ones are: doc comments on new/edited types, functions and their members; AAA structure in new/edited tests; strict equality (`!== undefined`, not `!= null`); no non-null assertions or `void`-operator fire-and-forget. Flag anything off as a fix-now or batch item.

## Output
When the loop settles, report: gates status (green/what's red), what you fixed, and the batch (unresolved items for the user). If `--task-slug` was set, fold unresolved items into the task ledger's notes. This stage does **not** commit, push, or open a PR — it leaves a clean, reviewed diff for the next stage (`pr-open`).

## Hard constraints
- Review *your* changes only; don't wander outside the diff hunting for unrelated issues (that's not the job, and it inflates scope).
- Don't invent findings to seem thorough — a clean diff is a valid result.
- Fix at the right layer: a real product bug the change exposes is fixed in source, not papered over in a test. If it's a pre-existing bug outside this change, batch it (don't silently expand scope).
- Never bypass a check to make it pass. Format only changed files.
