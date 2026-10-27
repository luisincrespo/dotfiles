---
name: maintain-dotfiles
description: >-
  Land changes to the dotfiles repo pair — review what's pending, judge whether it belongs in
  the public repo or the private one, group it by concern, commit, push, and resync the tools
  that consume it. Use when changes are sitting uncommitted in ~/code/dotfiles, when a skill
  has just amended itself, or to keep both repos current: it watches by default, re-checking on
  an interval (`--once` for a single pass). Knows the public/private split, the leak
  guard's three entry points, and which surfaces go stale. On idle rounds, trims whichever skill
  has grown most. Only for this repo pair; for any other repo use deliver.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git push)
  - Bash(git pull)
  - Bash(git fetch:*)
  - Bash(git rev-parse:*)
  - Bash(git ls-files:*)
  - Bash(git -C:*)
  - Bash(stat:*)
  - Bash(date:*)
  - Bash(./.githooks/leak-audit:*)
  - Bash(./tools/devin/sync-plugin.sh:*)
  - Bash(./tools/claude/install.sh:*)
  - Bash(devin plugins:*)
  - Skill(loop)
---

# maintain-dotfiles

## The repo pair

Two repos, split by what can be published, not by what a thing is:

| | | |
|---|---|---|
| `~/code/dotfiles` | **public** | `AGENTS.md`, `skills/`, `local/` schemas, `tools/<vendor>/` adapters |
| `~/code/dotfiles-private` | **private** | mirrors the public layout; today the `voice` example corpus |

`tools/claude/install.sh` overlays them into `~/.claude` **at install time**. Neither checkout
ever holds the other's files — that is deliberate, and Step 3 below is why.

Concepts live in the READMEs, not here: [`README.md`](../../README.md) for the layout and what's
forced vs chosen, [`tools/claude/README.md`](../../tools/claude/README.md) for the overlay and
leak guard, [`tools/devin/README.md`](../../tools/devin/README.md) for the plugin and the
freshness rules. Read the relevant one rather than re-deriving it.

## Args

- `--once`: a single pass — land what's pending and stop, no watch.
- `--_looped`: internal — set by the wrap below so a looped round doesn't wrap again.
- `--watch`: accepted and ignored; watching is already the default.

**Watches by default, like `pr-babysit`.** Unless args contain `--once` or `--_looped`, invoke
`Skill(loop)` with `/maintain-dotfiles --_looped`, then continue below; the loop re-enters this
skill each round. Changes land here from other sessions amending a skill after their own task, on
no schedule anyone announces, so a one-shot run only lands what happened to be pending when
someone remembered to ask: one backlog of seven files sat uncommitted for three weeks that way.

### Pacing, when watching

Don't arm a Monitor on the repo. A file watcher fires on every save, and the condition here is
the opposite: Step 2 wants the tree to have been **quiet** for ten minutes. Time is the signal.

**Re-arm on every turn, not just loop turns.** The wakeup is scheduled by the turn that ends a
round, and an interactive exchange replaces that turn — so a conversation silently ends the
watch, and the longer the conversation the likelier it is already off. While watching, end *any*
turn that touched these repos by re-arming, and say when the next check is. If you cannot tell
whether a wakeup is pending, re-arm: a duplicate replaces the old one, a missing one goes
unnoticed until someone asks why nothing has been committed for four days.

Start around 30 minutes and stretch when rounds come back clean — 50, then an hour. Skills
amend themselves on the scale of hours, and an uncommitted change sitting a little longer costs
nothing; polling an idle tree costs more than it saves. Say so and stop if the user is plainly
done for the day: the skill works the same when run on demand.

## Step 1 — Survey

`git status --porcelain` in both repos, and `git fetch` to see if either is behind. Behind →
`git pull` (merge, never rebase — global rule 10) before anything else.

Clean and in sync → skip to Step 8. That is the common outcome.

## Step 2 — Is anything still being written?

**Other sessions edit these files while working** — normal here, not a fault. Check the mtime
of everything modified: committing half a skill is worse than committing nothing.

**Hold per file, not per round.** A file touched in the last ~10 minutes waits; the rest
proceed. Backlogs here run to nine files spanning seven hours, and parking the settled ones
behind one active edit means they sit until the editing stops — which may be days.

Two things the clock alone won't tell you, so check both before acting on the settled ones:

- **Is the fresh file part of the same change?** A multi-file edit in progress can leave one
  file stale and another current. If the settled files only make sense alongside the fresh one,
  hold them together.
- **Right at the boundary, read the diff instead.** The mtime is a proxy for "is it finished";
  the content is the evidence. A complete, self-contained edit at exactly ten minutes is safe,
  and a truncated one at thirty is not.

## Step 3 — Judge where each change belongs

Read every diff in full, then ask of each: **should this be world-readable?** A push publishes
immediately.

The leak guard is mechanical. It catches credentials, real addresses, internal hostnames,
ticket ids, denylisted employer terms, and commit identities. It cannot catch a change that is
merely *private* — and the `voice` corpus is the proof: anonymized by design, so it passes
every rule we have, which is exactly why it lives in the other repo.

So flag, don't assume, when a change:

- reads like a personal note, an unresolved opinion about a person, or something written to
  think rather than to publish;
- names a colleague, even a placeholder, outside `skills/voice/refs/`;
- records a workplace situation rather than a portable lesson — the lesson belongs in the
  public skill, the anecdote may not;
- describes a private codebase's internals concretely enough to be recognisable, even without
  a denylisted word in it;
- would embarrass anyone if a stranger read it.

**Flagging is the job, not deciding.** Say what you'd move to `dotfiles-private` and why, and
let the user choose. If they say publish, publish.

Machine-specific values are a separate question with a settled answer: they go in
`~/.agents/local/`, never in either repo. See the local-overrides section of the Claude README.

## Step 4 — Check the change is finished

Twice now a skill has landed referencing something that did not exist. Before committing:

- a new config key the skill reads → is it in `local/config.example.json`?
- a referenced path, script or sibling skill → does it exist at that path?
- a renamed heading or moved file → did every link and doc reference follow?

Complete it, or say why you left it.

## Step 5 — Commit, one concern at a time

- **Group by concern.** Unrelated changes get separate commits, even in the same file. The
  commit body carries real rationale; one message cannot do that for two unrelated things.
- **Stage explicitly by path.** Never `git add -A` — it sweeps in whatever another session
  touched thirty seconds ago, and the message will not mention it.
- **Message style:** imperative subject, then a body saying what was wrong and why the fix
  takes the shape it does.

## Step 6 — Push and resync the surfaces

They do not stay current the same way:

| Surface | Current when |
|---|---|
| Claude Code | immediately — `~/.claude` symlinks into the repo |
| Devin, cloud | next session — fetched from the git source |
| Devin, local | **only after** `devin plugins update` |

`./tools/devin/sync-plugin.sh` pushes and refreshes in one step (`--no-push` to refresh only).
Re-run `./tools/claude/install.sh` as well if a skill was added, renamed or removed, or if the
private overlay changed — symlinks do not appear on their own.
`local/config.example.json` is copied, not linked, so a schema change needs refreshing too:
`cp local/config.example.json ~/.agents/local/`, the one line of install it needs, which leaves
`settings.json` alone.

## Step 7 — Capture learnings (self-educate)

Ask once whether the round warranted a durable edit. "Nothing to capture" is the usual answer.
Route by portability: repo- or employer-specific facts → `~/.agents/local/`; a lesson that
holds anywhere → the relevant skill; a durable one-off → a memory. Make the edit yourself
unless it needs the user (see `## Deciding without asking`), and say what you changed.

## Step 8 — Trim (the counterweight to Step 7)

Every skill ends by capturing learnings, which adds rules; nothing removed them. In one week the
skills grew 16% — `self-review` 67% — and `deliver` loads seven of them per run. Growth is the
default, so trimming has to be a step, not a hope.

**When.** On an idle round — the tree is clean, so there's nothing else to do — pick the one skill
that has grown most since its last `Trim` commit, if that's over ~15%. One skill per round, so a
trim never arrives as a wall of diffs.

**Cut what doesn't change behaviour:** a rule stated twice, in one skill or restated from
`AGENTS.md` or a sibling; a rule a later one supersedes; a second or third illustration of one
point; hedging and throat-clearing.

**Keep the reasons, even though they're the longest part.** The *why* is what lets a rule reach the
cases it didn't name, and an incident anchor ("it read twenty-eight transcripts") is what stops the
next editor deleting a rule as paranoia. Cut those and the imperative survives with less effect —
which is changing impact, not trimming.

**Cutting a step from the pipeline needs evidence, not a hunch.** A step earns removal when it
reliably produces nothing — `self-review` Step 6 already records passes that come back empty — or
when it re-does what an earlier stage already established. "This seems slow" is not enough; a step
that catches one bad merge in twenty is worth its time on the other nineteen.

**Check nothing was lost.** Where `second_opinion_review` covers the repo (its own entry, else `*`;
see self-review Step 3.6), hand it the old and new text and ask for any instruction the old version
gives that the new one doesn't. That's a precise question, and a second model is better at it than
the author of the cut.

Then apply it yourself: a trim the second opinion clears doesn't need the user, and where the check
flags a cut, keep the text rather than ask. One skill per commit, subject starting `Trim`, with the
before and after word counts in the body — so the next round can find the last trim and measure
growth since.

## Deciding without asking

Trims and small skill fixes are yours to make. Apply them, commit, and name each in the round's
summary, so they're reviewed after the fact rather than approved in advance. That covers a trim
the second opinion clears, a wording or formatting fix, a stale reference or wrong rule number,
finishing a half-done edit (Step 4), and a lesson whose fix is local and plainly what the user
would want. The user asked for this after a week of approving every trim and small fix one by one.

Bring a change to the user first only when it's big, or consequential as global rule 13 defines
it. Step 3 already flags anything that should stay private.

## Hard constraints

- **Never `--no-verify`.** If the guard blocks, fix the content: a false positive is a bug in
  the check worth fixing in `.githooks/`, not a reason to bypass it. Never edit the allowlist to
  silence a finding you have not understood — a pinned blob id is a reviewed exception; a path
  prefix is a hole.
- **Never move private content into the public checkout**, even behind `.gitignore`. One
  missed entry publishes it and no check here would notice.
- **Stop and ask** on: a guard block you cannot cleanly fix, a change that looks private, a
  merge conflict, or a diff that looks truncated despite Step 2.
- Publishing is one-way. A force-push does **not** remove data from GitHub — the old tip stays
  fetchable by sha. Deleting and recreating the repo is what actually removes it.
