---
name: pr-review
description: >-
  Review a GitHub PR the way Luis reviews — deep context-gathering, findings grouped into rounds, reviewed WITH
  the user before anything is posted, then posted as INLINE comments only via `gh api`, in a
  concise human voice. Use when the user asks to "review this PR", "pr-review", pastes a
  github.com PR link and wants feedback, or wants help leaving review comments. This is for
  REVIEWING someone else's PR (reading the diff, leaving inline comments, approving) — NOT for
  creating/babysitting/merging your own MR/PR (that's `deliver`).
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
  - Read
  - Edit
  - Grep
  - Glob
---

# pr-review

Reviews a PR in `<repo>` (see Config). The goal is a small set of
high-signal comments, written so they read like Luis wrote them, posted inline, and
**never posted without showing them to the user first.**

As you work, keep a light note of anything the user corrects (wording, calibration) or
anything you had to dig to find out — Step 8 folds those back into this skill at the end so
the next review goes better.

## Config

> **Local overrides.** If `~/.claude/local/config.json` exists, its keys override the defaults
> below (schema: `~/.claude/local/config.example.json`). `config.json` is machine-local and never committed.

- `<repo>`: resolve in this order, first hit wins — **most specific beats most general**:
  1. An owner/repo named in the invocation: a pasted PR URL (`github.com/<owner>/<repo>/pull/<N>`)
     or an explicit `--repo`.
  2. `<owner>/<repo>` derived from `git remote get-url origin` in the current directory.
  3. `pr_review_default_repo` — the last-resort fallback for when the cwd isn't a git repo (or has
     no origin), **not** an override. Where you're standing beats a machine-wide default.

  Then always pass the result explicitly as `--repo <repo>` so the review can't drift onto the
  wrong project mid-run.

## Hard rules (these are why the user uses this skill, not the built-in `/review`)

1. **Always review the draft comments WITH the user before posting.** Present every
   comment with its `file:line` placement and exact wording. Wait for explicit go-ahead.
   Iterate on wording/placement as long as they want. Posting prematurely is the worst failure mode.
2. **Inline comments only.** No review body, no top-level summary comment — unless a point
   genuinely can't attach to a specific line (rare). Cross-cutting points (e.g. a naming
   scheme) get anchored on the most relevant single declaration line.
3. **Concise, human voice.** Short words, no AI-thoroughness, no "why this approach vs that"
   essays. Phrase as suggestions/questions ("Could we…", "Small thing:", "Worth picking one…").
   It should sound like the user typed it. See the Voice section.
4. **Approve only when the user asks.** Approval is an outward-facing action. But "monitor
   this / take care of it / approve once addressed" is a standing ask: it authorizes the full
   monitor-until-addressed-then-approve loop (Step 6) without a fresh prompt each round.

## Workflow

### 1. Gather context (do this thoroughly — it's what makes the review good)
- `gh pr view <N> --repo <repo> --json title,body,author,headRefName,baseRefName,files,additions,deletions,state`
- `gh pr diff <N> --repo <repo>`
- Fetch the branch and read the **full files**, not just the diff — context outside the diff
  matters: `git fetch origin <headRefName>:<headRefName> --force` then `git show <branch>:<path>`.
- Read what the PR **depends on and mirrors**: the types it consumes (e.g. UI-kit prop
  types), and any "analogous"/"mirrors X" code it references. Comparing against the existing
  pattern is often where the best comments come from.
- Note new files/dirs → check CODEOWNERS implications (see repo CLAUDE.md). New components in a
  package with Storybook → stories expected.
- If the PR is part of a stack, read every PR in it before claiming something is absent or won't
  exist — grep all branches, not just this one. Read the existing review threads first
  (`gh api repos/…/pulls/<N>/comments`): dedupe against them, and note which findings other
  reviewers already own.

### 2. Decide the focus
Ask the user what to focus on if they didn't say. Common lenses for this repo (frontend/React):
- **React best practices & re-renders** — and verify memoization is *actually effective*:
  `useCallback`/`useMemo` that buy nothing (unstable deps, fresh object returned each render,
  non-memoized child that re-wraps handlers) are worth flagging as dead ceremony → simplify,
  or complete the chain (stabilize + `React.memo`).
- **Hooks usage** — suggest extracting hooks for testability/perf; pure derivations belong at
  render time (or in a `useMemo`), **not** in a `useEffect`. Check Rules of Hooks.
- **Component/hook API** — `readonly` props, required-before-optional, prop names that match
  the value. (JSDoc-coverage and import-style nits are low-priority here — they tend to get
  cut, so keep them last and brief.) Before calling a prop "wider than needed" or unused, check
  the component's public-export surface and sibling components' prop types — a widening that
  matches an exported/sibling API is deliberate, not dead code.
- **Naming** — components should be nouns, not verb phrases; align with the design-system /
  domain vocabulary already in the codebase (e.g. prefer the UI-kit's existing noun). Watch for
  a component name colliding with a domain type name.
- **Reuse / simplification / correctness** — does it reinvent an existing util/pattern?

### 3. Analyze → group findings into rounds/categories
Organize by theme (e.g. "hooks", "naming", "misc nits") rather than one flat list. Tag each
with conviction (recommend / borderline / nit) and whether it's blocking (usually nothing is).
Give a recommendation, not a survey of options. A test comment earns its place when it closes a
gap that would let the bug back in — not when it polishes an existing assertion's style or a
test's name. Those get cut.

Findings that assert **absence** ("this will never exist"), **equivalence** ("this changes nothing
observable"), **redundancy** ("this buys nothing"), or **implementability** ("we could just pass X
here") are where reviews go wrong — verify each before drafting, not after the author pushes back.
For equivalence, check side-effect ordering separately from rendered output. For redundancy, check
whether the thing is load-bearing for a documented invariant: a `[]` dep array plus an
`eslint-disable` is usually protecting a "runs exactly once" contract. For implementability, follow
the value to whoever consumes it — threading a field through a command whose only handler ignores it
relocates the problem instead of fixing it.

### 4. Review with the user, in rounds
Present each round's draft comments with `file:line` + exact text. Let the user cut, reword,
re-home points between rounds, and request code examples. Lock wording before moving on.

**Verify any code you hand over the way CI will**, not just the way that's quickest. Know which of
your local commands actually enforce what you're claiming: a test runner that strips types instead of
checking them (vitest via esbuild, say) will happily pass code that fails the build, so a green scratch
test proves nothing about types — run the real build/typecheck (`nx build <package>`, `tsc --noEmit`,
`mypy`, `cargo check`, …). A snippet that doesn't compile costs the author a CI round and the comment its credibility.

### 5. Post — inline, via `gh api`
- Get the **full 40-char head SHA** (a short SHA returns HTTP 422):
  `gh pr view <N> --repo <repo> --json headRefOid --jq .headRefOid`
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
  - `side=RIGHT` for added/changed lines (all lines of an added file are RIGHT).
  - Multi-line anchor: add `-F start_line=<n>` (with `-f start_side=RIGHT`) alongside `line`.
  - Reply on an existing thread: `-F in_reply_to=<comment_id>`.
- Edit a posted comment: `gh api -X PATCH "repos/.../pulls/comments/<comment_id>" -f body="$(cat …)"`.
- Capture each returned comment id — you'll need it to edit, and to link comments to each other
  (`…/pull/<N>#discussion_r<comment_id>`).

### 6. Re-review after the author pushes changes (and monitor until fully addressed)
- `git fetch … --force`, look at the new commit, and **map each of your comments to a concrete
  change** in a small table (addressed / partially / missed). Also check thread replies
  (`gh api repos/.../pulls/<N>/comments`) — a reasoned "won't do" reply
  counts as addressed; a question back to you is yours to relay, not to silently resolve. Judge an
  ack against the head, not its tense, and give a silent comment one cycle before calling it punted
  — partial pushes often land ahead of the replies on the rest.
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
  detail, it's worth either raising or explicitly deciding to accept.
- **Default to monitoring until every comment is fully addressed, then approve** — don't stop at
  one re-review. When the user has handed off ("monitor this", "approve once addressed"), poll
  the PR (self-pace via `/loop` / scheduled wake-ups; cadence in hours, not minutes — human
  feedback is slow) and re-run this step on each new push or reply until all comments are
  resolved, then do Step 7. Surface anything that needs the user (a reply asking a question, a
  pushback you don't buy, CI gone red) instead of forcing resolution. Stop polling only when
  approved or the user calls it off. Watch commits and comments, not CI state — a red check on an
  unchanged SHA is noise — and verify any alarm your own tooling raises against the PR before
  relaying it. If the PR goes quiet for a day or more, say so and offer to stop rather than
  accruing silent ticks, especially when every prior fix came from one bot answering another:
  ordinary human-review threads have nothing automated to pick them up.

### 7. Approve (when asked, or once Step 6's loop clears every comment)
`gh pr review <N> --repo <repo> --approve --body "<short note>"`
- **Don't gate approval on CI being green.** Once every comment is addressed, approve — CI/checks
  are the author's to land. Only surface (don't block silently) if CI has gone *red*.
- Then resolve your own threads whose findings are addressed — **in the same step, not later**.
  Where the repo requires all conversations resolved to merge, approving while leaving them open
  blocks the author on you. Never resolve another reviewer's threads. REST can't do it; use
  GraphQL — get node ids from `repository.pullRequest.reviewThreads`, then:
  ```bash
  gh api graphql -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }' -f id="<PRRT_…>"
  ```

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
- If something generalizes, **propose the exact edit** — which section, the new/changed
  wording — and apply it once the user confirms. (Editing this skill changes every future
  review, so it follows the same show-first rule as posting comments.) Prefer refining or
  replacing an existing line over adding a new one.
- Keep the bar high. Skip anything specific to this one PR — that's a fact, not a skill rule,
  and a memory feedback note may fit it better. If nothing generalizes, say so and change nothing.
- Watch for bloat: if an edit grows a section, find a sentence to cut.
- **Keep the edit confidential-free.** This skill lives in a portable dotfiles repo that travels
  between machines and employers, so an edit must never name a real person, private repo, internal
  host, ticket id, or proprietary identifier. Capture the transferable *rule* and let the specifics
  stay in the repo's own `CLAUDE.md` or a memory note, where they belong anyway.

## Voice (write comments like this)

- Lead with the ask, keep it short. Plain words. After drafting, do a trim pass — cut hedges,
  qualifiers, and idiom doing rhetorical rather than factual work ("that lands", "fair enough",
  "something smaller underneath", "reads as incidental"). Open an acknowledgement with the
  plainest words available ("Got it, makes sense.") and go straight to the point.
- No shorthands. Write the word out — "Is this intended?", not "Q:"/"q:". The user never uses these.
- For a JSDoc/doc suggestion, give the reason as helping devs understand what the code does —
  not "to match the convention".
- Suggestion/question framing: "Could we pull this into a hook…", "Small thing: make this
  `readonly`…", "Worth picking one — simplest is to wrap these two to match."
- For non-trivial suggestions, include a **code example as a proper fenced block** (not inline),
  using the PR's own variable/type names so it drops in. When a finding hinges on two
  conditions/values that must agree, show both literally side by side — naming them abstractly
  ("the predicate", "the same condition") makes the reader reconstruct them.
- Every comment must **stand alone**. Don't say "per the note above" — inline comments have no
  reliable order; **link** to the other comment via its `#discussion_r<id>` URL instead. It also
  means no vocabulary you coined while working the problem out: name the real symbols ("the
  `OpenCoordinatorAgent` and `MessageAgent` commands"), not a shorthand the author has never
  seen ("the two halves of the compound").
- Don't over-explain trade-offs the reader can see. State it plainly and move on.
- It's fine to ask a genuine question ("If there's always one per message, can you note that in
  the JSDoc?") rather than assert a change. When a finding rests on an assumption about intent
  or coupling you haven't confirmed, default to a question, not an assertion ("Is this meant
  to…? If so…").

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

- Repo: `<repo>` from Config (always pass `--repo`).
- Honors the user's global rules already in CLAUDE.md/memory: `gh` for GitHub, JSDoc coverage,
  `readonly`/required-first interface props, `!== undefined` over `!= null`.
- Also honors whatever the **target repo's own** `CLAUDE.md` mandates — design-system preferences,
  barrel-file rules, changeset/versioning conventions. Read it before the first round rather than
  assuming this machine's conventions apply.
