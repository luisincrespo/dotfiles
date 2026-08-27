1. When writing new unit tests or modifying existing ones, please always follow the Arrange-Act-Assert pattern.
2. When writing a commit message, please don't add the "co-authored with Claude" footer that you usually add.
3. When performing repo-related operations (e.g., creating MRs), please make use of the corresponding CLI: `glab` for GitLab and `gh` for GitHub.
4. When creating MRs, please make sure you check if there are existing MR templates for the corresponding repo and use the appropriate one.
5. When creating MRs/PRs, keep the title concise — an imperative summary of the change, with NO `<JIRA_TICKET_ID>:` prefix. If the change is related to a ticket, reference it in the description/summary instead (e.g. "Part of ABC-123."), not the title. If the change relates to no ticket (a standalone fix/chore), omit the reference — no need to ask.
6. When sending a message in Slack to request an MR review, use the following template:

   ```
   MR to <brief description of the changes>

   <link_to_MR>
   ```

7. When working inside a git worktree, please work with the files inside that worktree, for both reading and writing. Also make sure that if you spin up agents or other tasks like "Explore", they're also instructed to work with files inside the corresponding git worktree.
8. When working with Typescript and you'd like to check if there are any TS errors, please check files through the IDE diagnostics first. If that fails, then you can fall back to using `tsc` but try to run it scope to the files that you know need to be checked, not the whole project.
9. When performing a git merge between to branches, please default to using git merge instead of git rebase.
10. The `deliver` skill family owns the MR/PR lifecycle (it replaced `manage-mr`). When I ask you to create / open / raise / put up / submit an MR or PR, or say a branch is ready to ship/land, **invoke `/deliver` to do it** — it opens the PR via `pr-open` (following rules #3–5) and babysits it through merge + cleanup via `pr-babysit` → `pr-merge` → `post-merge-cleanup`, and can adopt an already-open PR by entering at the babysit stage. When I just want an existing MR/PR watched, `/deliver` (auto-detects and babysits) or `/pr-babysit` directly is fine. Do NOT call `glab mr create` / `gh pr create` directly. Skip these skills only if I explicitly say not to use them for a given MR/PR.
11. When creating worktrees, always create the worktree under `<current_repo_root>/.claude/worktrees`.
12. When writing interfaces in Typescript, please always list required (non-optional) properties first, and then the optionals. Also, please never forget to write a jsdoc for the interface per se and for each of the properties.
13. When writing jsdocs, never forget to add statements with corresponding descriptions for @returns and @param.
14. When documenting a general-purpose type, interface, property, function, or component (i.e. one that isn't inherently owned by a single feature), describe *what it is and its general-purpose meaning* — never tie the description to a specific consumer or feature that happens to use it. Don't write "Consumed by X to …", "Used by the onboarding flow for …", or similar callouts to a particular caller. Give an intrinsic definition plus, if helpful, a neutral example; if a usage example is genuinely needed, phrase it as one representative example ("e.g. …"), not as the field's purpose. (This applies even when the immediate/only current caller is that one feature — describe the thing, not who uses it.)
