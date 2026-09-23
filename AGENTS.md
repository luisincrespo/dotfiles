# Personal instructions

Rules that apply to every project. **General** and **Git…** hold regardless of stack; each
language section below them is self-contained — add one when you pick up a new language, delete
one when you stop using it, and don't let its conventions leak upward into the general rules.

## General

1. When writing new unit tests or modifying existing ones, please always follow the Arrange-Act-Assert pattern.
2. When writing a commit message, please don't add the "co-authored with Claude" footer that you usually add.
3. When documenting a general-purpose type, interface, property, function, or component (i.e. one that isn't inherently owned by a single feature), describe *what it is and its general-purpose meaning* — never tie the description to a specific consumer or feature that happens to use it. Don't write "Consumed by X to …", "Used by the onboarding flow for …", or similar callouts to a particular caller. Give an intrinsic definition plus, if helpful, a neutral example; if a usage example is genuinely needed, phrase it as one representative example ("e.g. …"), not as the field's purpose. (This applies even when the immediate/only current caller is that one feature — describe the thing, not who uses it.)
4. When writing or updating documentation for a library, app or module, split it three ways by what goes stale. **README.md** carries concepts — the decisions, semantics and mechanisms a reader can't recover from any single file (what the module decides vs. what its caller decides, lifecycle, rollout, failure behavior). **CLAUDE.md** carries contributor notes — a directory map, the load-bearing invariants ("breaking one rarely fails loudly"), and recipes for common tasks. **Doc comments in the source** — JSDoc, docstrings, rustdoc, godoc, KDoc, whatever the language uses — carry everything code-shaped: signatures, parameters, fields, what a symbol does. Neither markdown file may restate a signature or enumerate exports; the test is: if you're about to write "`X` takes these parameters" in markdown, write it as a doc comment on `X` instead. State that split explicitly in both markdown files, and add the tie-breaker that when a doc and the source disagree the source is right and the doc is stale.

## Git, worktrees & MR/PR workflow

5. When performing repo-related operations (e.g., creating MRs), please make use of the corresponding CLI: `glab` for GitLab and `gh` for GitHub.
6. When creating MRs, please make sure you check if there are existing MR templates for the corresponding repo and use the appropriate one.
7. When creating MRs/PRs, keep the title concise — an imperative summary of the change, with NO `<TICKET_ID>:` prefix. If the change is related to a ticket, reference it in the description/summary instead (e.g. "Part of ABC-123."), not the title. If the change relates to no ticket (a standalone fix/chore), omit the reference — no need to ask.
8. When sending a message in Slack to request an MR review, use the following template:

   ```
   MR to <brief description of the changes>

   <link_to_MR>
   ```

9. When working inside a git worktree, please work with the files inside that worktree, for both reading and writing. Also make sure that if you spin up agents or other tasks like "Explore", they're also instructed to work with files inside the corresponding git worktree.
10. When performing a git merge between to branches, please default to using git merge instead of git rebase.
11. The `deliver` skill family owns the MR/PR lifecycle (it replaced `manage-mr`). When I ask you to create / open / raise / put up / submit an MR or PR, or say a branch is ready to ship/land, **invoke `/deliver` to do it** — it opens the PR via `pr-open` (following the CLI, MR-template and title rules above) and babysits it through merge + cleanup via `pr-babysit` → `pr-merge` → `post-merge-cleanup`, and can adopt an already-open PR by entering at the babysit stage. When I just want an existing MR/PR watched, `/deliver` (auto-detects and babysits) or `/pr-babysit` directly is fine. Do NOT call `glab mr create` / `gh pr create` directly. Skip these skills only if I explicitly say not to use them for a given MR/PR.
12. When creating worktrees, default to `<current_repo_root>/.claude/worktrees`. If the repo has its own worktree convention — a skill or script that creates them, or a documented location — follow that instead, and say which one you're using and why. A repo that ships worktree tooling usually encodes setup steps you'd otherwise rediscover the hard way.
13. When a self-educate step edits a skill or rule in the dotfiles repo, applying the confirmed edit is the end of your job: don't commit it, and don't offer to run `maintain-dotfiles` or otherwise land it. A separate agent owns landing dotfiles changes, and it picks yours up on its next round.

## TypeScript

14. When working with Typescript and you'd like to check if there are any TS errors, please check files through the IDE diagnostics first. If that fails, then you can fall back to using `tsc` but try to run it scope to the files that you know need to be checked, not the whole project.
15. When writing interfaces in Typescript, please always list required (non-optional) properties first, and then the optionals. Also, please never forget to write a jsdoc for the interface per se and for each of the properties.
16. When writing jsdocs, never forget to add statements with corresponding descriptions for @returns and @param.
