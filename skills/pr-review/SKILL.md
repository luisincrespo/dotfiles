---
name: pr-review
description: >-
  Review someone else's GitHub PR the way Luis reviews: deep context-gathering, findings grouped
  into rounds, reviewed WITH the user before anything is posted, then posted as inline comments
  via gh api in a concise human voice. Use for "review this PR" or a pasted github.com PR link.
  This is for reviewing another person's PR; for your own PR lifecycle use deliver.
allowed-tools:
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh pr review:*)
  - Bash(gh api:*)
  - Bash(git fetch:*)
  - Bash(git show:*)
  - Bash(git grep:*)
  - Bash(git log:*)
  - Bash(git ls-tree:*)
  - Bash(rm -f ~/.claude/cache/pr-review/:*)
  - Read
  - Edit
  - Write
  - Grep
  - Glob
---

# pr-review

Reviews a PR in `<repo>` (see Config). The goal is a small set of
high-signal comments, written so they read like Luis wrote them, posted inline, and
**never posted without showing them to the user first.**

The checks themselves are shared with `self-review`, in its `passes/` folder
(`../self-review/passes/` from this skill's). This file decides which run on someone else's PR and
what their findings become.

As you work, keep a light note of anything the user corrects (wording, calibration) or
anything you had to dig to find out — Step 8 folds those back into this skill at the end so
the next review goes better.

## Config

> **Local overrides.** If `~/.agents/local/config.json` exists, its keys override the defaults
> below (schema: `~/.agents/local/config.example.json`). `config.json` is machine-local and never committed.

- `<repo>`: resolve in this order, first hit wins — **most specific beats most general**:
  1. An owner/repo named in the invocation: a pasted PR URL (`github.com/<owner>/<repo>/pull/<N>`)
     or an explicit `--repo`.
  2. `<owner>/<repo>` derived from `git remote get-url origin` in the current directory.
  3. `pr_review_default_repo` — the last-resort fallback for when the cwd isn't a git repo (or has
     no origin), **not** an override. Where you're standing beats a machine-wide default.

  Then always pass the result explicitly as `--repo <repo>` so the review can't drift onto the
  wrong project mid-run.
- **Review ledger**: `~/.claude/cache/pr-review/<repo-with-slashes-as-dashes>-<N>.json`, holding
  `{"deferred_items":[]}`. An item takes the shape `deliver`'s task ledger uses —
  `{summary, why_deferred, risk, suggested_owner}` — plus `evidence` (`file:line`, the test or
  command that shows it) and any `options` the user named, so one settling procedure fits both.

## Hard rules (these are why the user uses this skill, not the built-in `/review`)

1. **Always review the draft comments WITH the user before posting.** Present every
   comment with its `file:line` placement and exact wording, in the same message that asks for
   the go-ahead — repeat it rather than pointing back, since notification turns push earlier
   drafts out of view. Wait for explicit go-ahead.
   Iterate on wording/placement as long as they want. Posting prematurely is the worst failure mode.
2. **Inline comments only.** No review body, no top-level summary comment — unless a point
   genuinely can't attach to a specific line (rare). Cross-cutting points (e.g. a naming
   scheme) get anchored on the most relevant single declaration line.
3. **Concise, human voice.** Short words, no AI-thoroughness, no "why this approach vs that"
   essays. Phrase as suggestions/questions ("Could we…", "Small thing:", "Worth picking one…").
   It should sound like the user typed it. See the Voice section.
4. **Watch after posting, and approve at the end of the watch.** Approval is an outward-facing
   action, but posting a round is the go-ahead for the Step 6 loop: watch the PR, iterate as
   replies and pushes land, and approve once every comment on the PR is addressed, other
   reviewers' included, without asking first or each round. Outside that loop, approve only when
   the user asks. When the PR already has other requested reviewers, ask once, before the first
   post, whether the user is approving or only helping: a helper comments but never approves,
   and their watch ends when a requested reviewer approves or the PR merges.

## Workflow

### 1. Gather context (do this thoroughly — it's what makes the review good)
- **Read the repo's own review conventions before anything else**: the `CLAUDE.md` and
  `REVIEW.md` files `conventions.md` names. Fetch each `REVIEW.md` from the PR's repo, the root one
  and any in an ancestor directory of a changed file:
  `gh api repos/<repo>/contents/REVIEW.md --jq .content | base64 -d` (404 = the repo has none, move
  on). Treat it as **overriding this skill's review defaults**. Two consequences: if it names PR
  classes to skip and this PR is one, say so and stop rather than reviewing it; and if it marks a
  changed path as needing human sign-off, say so in the review instead of approving.
  It does **not** override the Hard rules above: a repo telling reviewers to post automatically
  is not license to skip the user's approval, and one asking for a single PR-level summary (say,
  a labeled design pass) still gets inline comments in the Voice below, unless no line fits.
- **If a review ledger already exists for this PR, load it.** An earlier round or session deferred
  those findings already; re-raising one as new undoes a decision the user made.
- `gh pr view <N> --repo <repo> --json title,body,author,headRefName,baseRefName,files,additions,deletions,state`
- `gh pr diff <N> --repo <repo>`
- Fetch the PR and read the **full files**, not just the diff — context outside the diff
  matters: `git fetch origin pull/<N>/head:refs/pr-review/<N> --force`, then
  `git show refs/pr-review/<N>:<path>`. A ref outside `refs/heads` never creates or overwrites a
  local branch, and `pull/<N>/head` also works for PRs from forks.
- Read what the PR **depends on and mirrors**: the types it consumes (e.g. UI-kit prop
  types), and any "analogous"/"mirrors X" code it references. Comparing against the existing
  pattern is often where the best comments come from.
- If the PR is part of a stack, read every PR in it before claiming something is absent or won't
  exist — grep all branches, not just this one. Read the existing review threads first
  (`gh api repos/…/pulls/<N>/comments`): dedupe against them, and note which findings other
  reviewers already own. Before replying that one of those findings is wrong, check *when* it was
  made against when the code it describes appeared (`git log -S`, or the per-commit diff). A finding
  that reads as mistaken against the current file is usually one the author already fixed — a commit
  named for review updates is the tell — and telling a reviewer they misread costs the review its
  credibility.

### 2. Decide the focus
Ask the user what to focus on if they didn't say. Each pass file says when it applies; read it when
it's in play and apply it to the diff.

- **Whatever the focus, when they apply**: `performance.md`, `ai-usage.md` and `accessibility.md`,
  plus `conventions.md` on every PR. Their findings join the rounds like any other. A performance
  or AI-usage comment says what grows and what it costs. JSDoc-coverage and import-style nits are
  low-priority: they tend to get cut, so keep them last and brief.
- **Lenses to offer**: `react.md` (memoization that buys nothing, derivations in effects, hooks,
  component API) and `api-shape.md` (endpoints).
- **Reuse / simplification / correctness** — does it reinvent an existing util/pattern? Hold your
  own suggested code to the same bar: when it would repeat a calculation other callers already
  inline, propose the one shared function they'd all call, not another copy.

### 3. Analyze → group findings into rounds/categories
Organize by theme (e.g. "hooks", "naming", "misc nits") rather than one flat list. Tag each
with conviction (recommend / borderline / nit) and whether it's blocking (usually nothing is).
Give a recommendation, not a survey of options. A test comment earns its place when it closes a
gap that would let the bug back in — not when it polishes an existing assertion's style or a
test's name. Those get cut.

A real finding that doesn't belong on this PR (a pre-existing bug the review surfaced, a wider fix
the user wants to own) isn't cut either: append it to the review ledger's `deferred_items` the
moment it leaves the PR — here, when the user moves one out in Step 4, or in a Step 6 re-review.
Written then, it survives a paused loop or a new session; held in context until the wrap-up, it
doesn't.

Findings that assert **absence**, **equivalence**, **redundancy**, **detectability** or
**implementability**, that a type is free to tighten, or how an external engine behaves are where
reviews go wrong: check each as `claims.md` says before drafting, not after the author pushes back.
A caveat you notice in your own suggestion goes in your notes to the user even when it looks minor.

### 3.5 Second opinion, different model
Follow `second-opinion.md`, after your own pass and before drafting. Here the payload is:
- `gh pr diff <N>`, which is already relative to the merge-base, so it carries only this PR;
- the full text of each changed file from `refs/pr-review/<N>`;
- the PR's title and description, so it can judge the change against what it claims to do.

What comes back are candidates, not comments, checked like your own and deduped against the existing
threads too. In the Step 4 rounds, name the model that ran, and mark the findings only it raised so
the user can weigh them; the posted comment never says so. It reviews; it never posts or replies.

On a re-review (Step 6), re-run it only for a push that substantially changes the code, up to the
entry's `max_rounds`. A one-line fix for one of your comments doesn't need a second pair of eyes.

### 3.6 Run it end to end, when it's worth it
Reading the diff tells you what the code says; running it tells you what it does. Most PRs don't
need it: when the change is logic its unit tests already pin down, CI running them is the
verification. Run it only when **both** hold:

- **It's worth it** — a substantial UI change, or a behavior change built on an involved
  interaction: multi-step flows, state carried across screens, drag and drop, focus and keyboard
  handling, anything whose correctness lives in how the pieces combine rather than in one function
  a test can call.
- **It can run locally** — the repo has a dev setup you can bring up (`Skill(run)`, the repo's own
  local-dev skill, its `local_e2e` entry in local config) without infra you lack.

Either fails → skip it, and mention that in one line only if the user might expect a run.

When you do run it:
- **Check it out in its own worktree**, never by switching the user's checkout — they may have
  work in flight there. Commit and push nothing to the author's branch.
- **Run it as `exercise.md` says**: the change works as intended, and the neighbouring case still
  does. A finding you reproduced is one the author can't wave off; a suspicion that doesn't
  reproduce gets cut before it costs the review credibility.
- **A fork, or an author outside the org → ask before running anything.** Running the branch
  executes their code on this machine, install scripts included.
- With the round's drafts, tell the user which states you exercised and what stayed unverified.
  That's for the user, not a comment — "I ran it and it works" isn't review feedback.
- Environment broken for reasons unrelated to the PR → say so and review statically; don't sink
  the review into fixing someone's local setup.

### 4. Review with the user, in rounds
Present each round's draft comments with `file:line` + exact text. Let the user cut, reword,
re-home points between rounds, and request code examples. Lock wording before moving on. When the
user hasn't read the code, open with two plain sentences on what the PR does, and note under each
draft, without identifiers, what breaks and for whom, so they can judge it and answer the author.
Pitch those drafts at the depth they can defend in a reply: the ask, one reason, "I think" where
you're inferring, and fix code held back until the author asks.

**Verify any code you hand over the way CI will** (`claims.md`, *Evidence that isn't*). A snippet
that doesn't compile costs the author a CI round and the comment its credibility.

### 5. Post — inline, via `gh api`
- Get the **full 40-char head SHA** (a short SHA returns HTTP 422):
  `gh pr view <N> --repo <repo> --json headRefOid --jq .headRefOid`. If it moved since you
  drafted, re-check that each anchored line still says what the comment describes.
- Write each comment body to a temp file (preserves markdown/newlines). Post one at a time —
  **do not wrap the `gh api` calls in a bash helper function** (it loses `PATH` in this sandbox):
  ```bash
  gh api -X POST "repos/<repo>/pulls/<N>/comments" \
    -f commit_id="<FULL_SHA>" \
    -f path="<path>" \
    -F line=<line> -f side=RIGHT \
    -f body="$(cat /tmp/cN.md)" \
    --jq '"OK " + (.id|tostring) + " -> " + .path + ":" + (.line|tostring)'
  ```
  - `side=RIGHT` for added/changed lines (all lines of an added file are RIGHT). A leftover the
    change creates outside its hunks (an import whose last use was deleted) anchors on that
    deleted line: `side=LEFT` with its base line number, plus a permalink to the leftover.
  - Multi-line anchor: add `-F start_line=<n>` (with `-f start_side=RIGHT`) alongside `line`.
  - Reply on an existing thread: `-F in_reply_to=<comment_id>`.
- Edit a posted comment: `gh api -X PATCH "repos/.../pulls/comments/<comment_id>" -f body="$(cat …)"`.
- Capture each returned comment id — you'll need it to edit, and to link comments to each other
  (`…/pull/<N>#discussion_r<comment_id>`).

### 6. Re-review after the author pushes changes (and monitor until fully addressed)
- `git fetch … --force`, look at the new commit, and **map each of your comments to a concrete
  change** in a small table (addressed / partially / missed). For a test written in answer to your
  comment, check that it would fail if the bug came back (`claims.md`, *Protection*). Also check
  thread replies (`gh api repos/.../pulls/<N>/comments`) — a reasoned "won't do" reply counts as
  addressed; a question back to you is yours to relay, not to silently resolve. Judge an
  ack against the head, not its tense, and give a silent comment one cycle before calling it punted
  — partial pushes often land ahead of the replies on the rest. Once it's punted, draft a one-line
  question to the author on that thread rather than waiting longer: an agent's fix round works
  from the threads it was pointed at, and a comment added later can be left out. A reply that
  cites a commit SHA gets checked against the remote too: an agent's push can be rejected after a
  concurrent merge, leaving its replies ahead of the code. Before telling the author, confirm it
  through the remote (`git ls-remote`, the PR's commit list), and word it as a push that may not
  have landed.
- `git grep` for stale references after renames (the only legit leftover is a domain *type* that
  legitimately keeps the old name).
- **After a force-push, read the base change too.** A rebase can land upstream work in the very
  files you commented on, which can moot a finding or change whether a fix is still correct.
  Re-verify each comment against the new base, not just the author's delta.
- **Check authorship before crediting the author** — `git log --format='%h %an %s'`. Fixes are often
  written by a bot agent (`Cursor Agent`, via an AI reviewer's "fix this" button), not the person.
  That matters beyond attribution: in a bot-fix-bot loop each agent patch draws the next finding, so
  "every finding got fixed" is not convergence and a quiet bot is not a ready change. Once a shared
  module has several agent patches, recommend reading the whole delta as one change.
- Report what's done and what (if anything) was missed. Don't invent issues to seem thorough — but
  don't withhold a real one to avoid another round either. If it's worth describing to the user in
  detail, it's worth either raising or explicitly deciding to accept. A detail that could mislead a
  later reader, such as a doc comment left detached from its symbol, counts as real: raise it as
  non-blocking rather than accepting it silently. When you raise a leftover issue, say first
  whether it changes behavior or only weakens a test.
- **Monitor until every comment is fully addressed, then approve** — don't stop at one re-review,
  and don't ask whether to start: right after Step 5's last post, wrap in
  `Skill(loop)` and let it arm a **Monitor** on the PR, as `pr-babysit` does, rather than waking on
  a timer. A shell loop polls `gh` every couple of minutes and wakes you only when the signature
  changes, so a push or reply lands within minutes instead of up to an hour later, and quiet
  stretches cost nothing. Build the signature from `state`, `head_sha`, and the review,
  review-comment and issue-comment counts **taken excluding the account this session posts as**,
  since your own replies would otherwise wake you on your own previous cycle. Leave CI out (see
  below). When an API call fails, skip that poll instead of emitting a placeholder, which would
  fire twice. A Monitor expires after 30 minutes at most, so re-arm it on each expiry — waiting on
  an answer included, rather than swapping it for a slow timer — and end any interactive turn
  about this PR by re-arming too: a conversation replaces the turn that would have done it. A
  Monitor also dies with the session. When resuming, seed the new one with the last signature you
  saw, not a fresh read, so anything that landed in the gap still fires. On
  each wake, re-run this step until all comments are resolved, then do Step 7. Surface anything
  that needs the user (a reply asking a question, a pushback you don't buy, CI gone red) instead
  of forcing resolution. Stop polling only when approved (by a requested reviewer, when the user
  is only helping) or the user calls it off. Watch commits and comments, not CI state — a red
  check on an unchanged SHA is noise — and verify any alarm your own tooling raises against the
  PR before relaying it. If the PR goes quiet for a day or more, say so and offer to stop rather
  than accruing silent ticks, especially when every prior fix came from one bot answering another:
  ordinary human-review threads have nothing automated to pick them up.

### 7. Approve (when asked, or once Step 6's loop clears every comment)
`gh pr review <N> --repo <repo> --approve --body "<short note>"`

A permission check can refuse an approval that rests on a conditional go-ahead. Don't work around
it: ask the user for a direct instruction, or give them the command to run. A finding that lands
between the user's go-ahead and the approval gets shown before you approve; the go-ahead covered
what they had seen.
- **Every comment on the PR counts, not just yours.** Before approving, hold other reviewers'
  open threads, review summaries and PR comments, bots included, to the bar Step 6 sets for yours:
  fixed in the code, or answered with a reasoned reply. One still open → keep watching instead of
  approving, and tell the user whose and what, with your read of each one's impact: they can choose
  to approve over the low-impact ones. An approval reads as "ready to merge", and one that
  lands over another reviewer's open suggestion lets it merge unaddressed. A comment you think is
  wrong or stale isn't yours to wave through: raise it with the user rather than approve past it.
- **Don't gate approval on CI being green.** Once every comment is addressed, approve — CI/checks
  are the author's to land. Only surface (don't block silently) if CI has gone *red*.
- Then resolve your own threads whose findings are addressed — **in the same step, not later**.
  Where the repo requires all conversations resolved to merge, approving while leaving them open
  blocks the author on you. Never resolve another reviewer's threads. REST can't do it; use
  GraphQL — get node ids from `repository.pullRequest.reviewThreads`, then:
  ```bash
  gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id="<PRRT_…>"
  ```
- **Then settle the ledger's `deferred_items`** with the user by following `post-merge-cleanup`
  Step 6, items 1–4 (its last-unit gate is `deliver`'s; skip it). Delegate rather than paraphrase:
  a summary drops its existing-ticket search and its priority rule, and goes stale when it changes.
  Besides a ticket or the personal backlog, an item here can become a PR of the user's own. Filed
  items leave the ledger and un-filed ones stay; delete it only once it's empty.
- **Then clean up**, here or whenever the user calls the review off: stop any Monitor or pending
  wakeup, delete the Step 1 ref (`git update-ref -d refs/pr-review/<N>`) and the comment body
  files, and remove anything else the review created locally. Only delete what this review
  made; check before removing anything. **The ledger is the exception:** calling a review off
  doesn't settle its deferrals, so offer to settle them first, and leave the ledger for whatever
  the user doesn't file — the next review of this PR loads it in Step 1.

### 8. Capture learnings (self-educate) — after the review wraps, usually post-approval
Once the lifecycle is done (the PR is approved, or the user clearly closes out the review),
do a short reflection pass and improve **this skill** so the next review goes better. The aim
is a *tighter* skill over time, not a longer one.

Scan the session for **reusable** signals:
- **Voice/wording** — anything the user reworded, shortened, or reframed (e.g. "make this a
  question", "too verbose"). Capture the *rule*, not the one-off phrasing.
- **Calibration** — findings the user cut as not worth it (which nit categories to stop
  leading with) or pushed harder on (what they want surfaced).
- **Process** — a check you skipped that would have caught a wrong claim (e.g. verifying a
  component's public-export surface before calling a prop "unused"), or a step that wasted time.
- **Repo knowledge** — a convention, gotcha, or pattern you had to discover mid-review.

Then:
- If something generalizes, **apply the edit and say what you changed** (which section, the
  new wording), unless it's consequential (global rule 13). A lesson about a check itself goes in
  its file in `../self-review/passes/`, worded for both skills that read it: what the check looks
  for, not what a finding becomes here. Prefer refining or replacing an
  existing line over adding a new one; if an edit grows a section, cut a sentence.
- Keep the bar high. Skip anything specific to this one PR — that's a fact, not a skill rule,
  and a memory feedback note may fit it better. A review procedure that recurs on one project is
  a project skill (global rule 13). If nothing generalizes, say so and change nothing.
- **Keep the edit confidential-free.** This skill lives in a portable dotfiles repo that travels
  between machines and employers, so an edit must never name a real person, private repo, internal
  host, ticket id, or proprietary identifier. Capture the transferable *rule* and let the specifics
  stay in the repo's own `CLAUDE.md` or a memory note, where they belong anyway.

## Voice (write comments like this)

- Lead with the ask, then the problem as someone using it would see it; keep the mechanism (which
  component or query causes it) to a clause, or the comment reads as being about whatever you
  named first. Stick to problem and fix against the current code, and leave out the PR's own
  history ("the first commit did X") and behavior that's working as intended. Give it the ask and
  one reason. What you checked to be sure of it (an exception filter, another PR, how many call
  sites do the same) goes in your notes to the user, not the comment: a stack of cross-references
  reads as an audit report, not as something the user wrote. After drafting, do a trim pass —
  cut hedges, qualifiers, and idiom doing rhetorical rather than factual work ("that lands", "fair enough",
  "something smaller underneath", "reads as incidental"). Open an acknowledgement with the
  plainest words available ("Got it, makes sense.") and go straight to the point.
- No shorthands or jargon. Write the word out ("Is this intended?", not "Q:"), and name the actual
  file or element instead of an acronym or a vague pointer: a permalink to the code you mean, not
  "like the table does".
- For a doc-comment suggestion (a `//` line documenting an export or interface member), the
  reason is that code documentation follows the language's own doc-comment format, so keep the
  suggestion even when the text is already good. Not IDE hover (most code is written through
  agents), and not "to match the convention".
- For non-trivial suggestions, include a **code example as a proper fenced block** (not inline),
  using the PR's own variable/type names so it drops in. When a finding hinges on two
  conditions/values that must agree, show both literally side by side — naming them abstractly
  ("the predicate", "the same condition") makes the reader reconstruct them.
- Every comment must **stand alone**. Don't say "per the note above" — inline comments have no
  reliable order; **link** to the other comment via its `#discussion_r<id>` URL instead. It also
  means no vocabulary you coined while working the problem out: name the real symbols ("the
  `OpenCoordinatorAgent` and `MessageAgent` commands"), not a shorthand the author has never
  seen ("the two halves of the compound"). When two of your comments offer alternative fixes for
  the same problem, say in one of them which you'd pick and link the other ("This is the one I'd
  go with: … so the X from [this comment] wouldn't be needed"). A conditional like "if we go this
  way" leaves them reading as two conflicting asks.
- It's fine to ask a genuine question ("If there's always one per message, can you note that in
  the JSDoc?") rather than assert a change. When a finding rests on an assumption about intent
  or coupling you haven't confirmed, default to a question, not an assertion ("Is this meant
  to…? If so…"). That includes removing something that looks unused: ask "Do we need X?"
  before "Could we drop X?".

## Examples of the target style

> Could we pull this dismissal logic into a hook, e.g. `useVisibleQuestionnaire(message)` that
> returns the card or `null`? It'd be easier to test on its own. Keep it a plain derivation (not
> a `useEffect`) since it's just deciding visibility. Something like:
> ```ts
> function useVisibleQuestionnaire(message: AssistantResponse): AskUserQuestions | null { … }
> ```

> These `useCallback`s aren't buying anything right now. `onSubmit` comes in as a new inline
> arrow each render, the hook returns a fresh object every render, and the card isn't memoized —
> so nothing downstream stays stable anyway. I'd just drop them to keep it simple.

## Reference

- `gh` for everything GitHub (global rule 5).
- The conventions a review checks, the user's and the target repo's, are in `conventions.md`. Read
  the target repo's own before the first round rather than assuming this machine's apply.
