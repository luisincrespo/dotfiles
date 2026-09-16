# Phase 4a: Conflict resolution

Loaded by the `pr-*` skills when conflicts surface (from Phase 0.5a or Phase 4 condition 6). Goal: bring the branch current with the target, push, and let the next cycle re-verify.

The **file-classification rules and the typecheck gate are identical** for both strategies; only the git plumbing (merge commit + `push` vs. rebase + `--force-with-lease`) differs. Pick the section by `SYNC_STRATEGY` (see the `REBASE_SYNC_REPOS` config): `"merge"` (default, every normal repo) → **Merge strategy**; `"rebase"` (repos whose CLAUDE.md mandates rebase-before-push) → **Rebase strategy**.

## Preconditions (bail and return to caller if any fail — both strategies)

1. `git status --porcelain` is empty. If dirty → announce `Working tree dirty; cannot auto-resolve upstream conflicts this cycle.` and return.
2. Current branch == `source_branch`. If not → announce mismatch and return.

## File classification (shared by both strategies)

When a conflict stops the merge/rebase, `git diff --name-only --diff-filter=U` lists the conflicted files. Classify each:
- **Lockfile** — never hand-merge one. Take either side, then **regenerate it from the manifest**: `git checkout --ours <file>` → run the ecosystem's install/resolve at the root → `git add <file>`. (`pnpm-lock.yaml`/`package-lock.json`/`yarn.lock` → `pnpm|npm|yarn install`; `poetry.lock` → `poetry lock`; `Cargo.lock` → `cargo build`; `Gemfile.lock` → `bundle install`; `go.sum` → `go mod tidy`.)
- **Append-only changelog files** — `CHANGELOG.md` at any depth, and per-change fragments (`.changeset/*.md`, `changelog.d/*`, `newsfragments/*`), excluding their README/config: union merge — strip markers, keep both halves verbatim. Both sides are additions, so neither is wrong. Use `Read` + `Edit`. `git add <file>`.
- **Source code** (`.ts`/`.tsx`/`.js`/`.json`/`.css`/`.scss`/etc.): auto-resolvable ONLY if (a) both sides added different non-overlapping lines (keep both in original order), or (b) diff is purely whitespace/import-ordering/formatting (take ours, plan to re-run formatter). Anything else → **COMPLICATED**.
- **Anything else** (binaries, unfamiliar configs) → **COMPLICATED**.

> **Note on "ours" during a rebase:** git swaps the sides while replaying — `--ours` is the *target* (the base you're rebasing onto) and `--theirs` is *your* commit. So for lockfiles during a rebase, take the target's version with `git checkout --theirs <lockfile>` then regenerate (`pnpm install`). The intent is unchanged (regenerate the lockfile); just mind the inverted flag.

## Merge strategy (default — `SYNC_STRATEGY == "merge"`)

### Attempt

1. Announce: `Detected conflicts with origin/<target_branch>. Attempting local merge.`
2. `git merge origin/<target_branch> --no-ff --no-commit` (expect non-zero — that's the conflict).
3. `git diff --name-only --diff-filter=U`, then resolve each file per **File classification** above.

### Branches

**If any COMPLICATED:**
- `git merge --abort`.
- For each, extract a 10-line conflict snippet for context.
- Add to batch: `Merge conflict needs your eyes in <file>:` + snippet.
- Announce: `<N> files need manual conflict resolution. Left the branch untouched.`
- Return — skip Phase 4 merge.

**If all resolved:**
- `git grep -l "<<<<<<< HEAD" || true` — must be empty (else `git merge --abort`, batch, return).
- If any "whitespace/ordering" resolutions: run the repo's formatter over **only the changed files**, then re-stage (e.g. `npx prettier --write <files>` / `nx eslint:lint <pkg> --fix`, `ruff format`, `gofmt -w`, `cargo fmt --`). Never run a format-everything target — it reformats unrelated code and buries the real diff.
- `npx tsc --noEmit` scoped to packages with changed files. If fails → `git merge --abort`, batch as `Auto-resolved conflicts but typecheck failed: <summary>`, return. (If the only failures are pre-existing on the target — same errors present on `origin/<target_branch>` untouched by this branch — they are not merge-induced: leave them, note them, and proceed.)
- `git commit --no-edit` (default merge message).
- `git push`.
- Announce: `✅ Auto-resolved <N> conflicts and pushed merge commit <sha>. Resolved files: <list>. Awaiting new pipeline before merging MR.`
- Return — Phase 4 will re-verify next cycle (approvals may reset on push, that's expected).

## Rebase strategy (`SYNC_STRATEGY == "rebase"` — `REBASE_SYNC_REPOS`)

For repos whose CLAUDE.md mandates rebase-before-push. Same classification and typecheck gate; the branch is replayed onto the target and force-pushed **with lease**. A rebase can stop on several commits in turn, and once it *completes* you can't `--abort` — so save a bail-out ref first.

### Attempt

1. Announce: `Detected conflicts with origin/<target_branch>. Rebasing branch onto it (repo mandates rebase-before-push).`
2. Save the bail-out ref: `PRE=$(git rev-parse HEAD)`.
3. `git rebase origin/<target_branch>`.
4. **Resolve loop** — repeat until the rebase reports success or a stop can't be auto-resolved:
   - On a conflict stop: `git diff --name-only --diff-filter=U`, resolve each per **File classification** above (mind the inverted `--ours`/`--theirs` note).
   - Any **COMPLICATED** → `git rebase --abort` (restores `PRE` automatically), extract 10-line snippets, batch `Merge conflict needs your eyes in <file>:` + snippet, announce `<N> files need manual conflict resolution. Left the branch untouched.`, return.
   - Else, once all conflicted files are `git add`-ed: `GIT_EDITOR=true git rebase --continue` (no editor prompt). Loop back — the next commit may also stop.

### After the rebase completes

- `git grep -l "<<<<<<< HEAD" || true` — must be empty (else `git reset --hard $PRE`, batch, return).
- If any "whitespace/ordering" resolutions were taken: format only the changed files (`npx prettier --write <changed files>`), then `git add -A && git commit -m "Format after rebase"` (a small follow-up commit — the rebase is already finished).
- `npx tsc --noEmit` scoped to packages with changed files. If fails → **`git reset --hard $PRE`** (rebase is complete, so `--abort` is unavailable), batch `Auto-resolved conflicts but typecheck failed: <summary>`, return. (Pre-existing-on-target errors: same carve-out as the merge branch.)
- **Force-push with lease only:** `git push --force-with-lease origin <source_branch>`.
  - Lease **accepted** → announce `✅ Rebased onto origin/<target_branch> and force-pushed with lease as <sha>. Resolved files: <list>. Approval may reset. Awaiting new pipeline.` Return.
  - Lease **rejected** (remote advanced — someone else pushed): do **NOT** retry with a bare `--force`. `git fetch origin <source_branch>` then `git reset --hard origin/<source_branch>` (discard the local rebase; local now matches the remote, nothing lost). Batch `Branch advanced on the remote (someone else pushed) — skipped rebase+force-push to avoid clobbering; needs a look.` Return.

## Hard rules

- Never `git checkout --theirs` on source code — prefer ours, integrate theirs manually. (During a rebase the sides are swapped, so "keep our work" = keep `--theirs`; still never blindly take the *other* side of a source conflict.)
- Never skip the typecheck verification.
- **Never force-push except the rebase-strategy path above, and only with `--force-with-lease`** — never a bare `git push --force`. On a rejected lease, discard-and-batch; never clobber.
- If `git rev-list --count HEAD..origin/<target_branch>` > ~50 commits, abort and add a batch item: source branch too stale, suggest manual rebase/merge. Large syncs deserve human review.
- Prior merge commits from `target_branch` in history are fine — don't try to squash them. (In a rebase-strategy repo the branch is normally merge-commit-free; if a merge commit is present from an earlier cycle, `git rebase` will still replay cleanly — don't attempt to rewrite history beyond the standard rebase.)
