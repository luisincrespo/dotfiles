# Claude Code

Personal [Claude Code](https://claude.com/claude-code) config: skills, global instructions and
settings, kept portable so they can be installed on any machine.

## Setting up a new machine

```shell
git clone git@github.com:luisincrespo/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./tools/claude/install.sh
```

Then restart Claude Code, and fill in the three machine-local files below — none of them is ever
committed:

| File | What goes in it |
|---|---|
| `~/.claude/settings.json` | Model choice — the durable preferences are merged in by `install.sh`, the rest is yours |
| `~/.agents/local/config.json` | This machine's repo id, SonarQube host, protected branches, reviewer bots — see [Machine-local overrides](#machine-local-overrides) |
| `~/.agents/local/commit-denylist.txt` | Employer, product and service names the [leak guard](#leak-guard) must keep out of commits |

The skills work unconfigured, so filling these in can wait until you know the new setup: SonarQube
is skipped, no extra branches are protected, and `pr-review` derives the repo from `git remote`.
The denylist is the exception worth doing on day one — until it names the new employer, the leak
guard is only catching the generic patterns, and the whole point of it is the employer-specific
words. Confirm it works with a throwaway staged line:

```shell
echo "<denylisted term>" > leaktest.md && git add leaktest.md && .githooks/pre-commit
git reset -q leaktest.md && rm leaktest.md
```

Plugins aren't linked — Claude Code owns its own cache, so install those separately (see
[Plugins](#plugins)).

## Install, preview, roll back

```shell
./tools/claude/install.sh              # link into ~/.claude
./tools/claude/install.sh --dry-run    # show what would change, touch nothing
./tools/claude/install.sh --uninstall  # drop the symlinks, restore the last backup
```

Install symlinks each skill and `CLAUDE.md` into `~/.claude`, so edits made from any machine land
back in this repo ready to commit. Anything real it would replace is moved to
`~/.claude/.dotfiles-backup/<timestamp>/` first, and `--uninstall` puts it back. Restart Claude Code
after any of these to pick up the change.

### The private overlay

A companion repo mirroring this one's layout supplies content that can't be published — today, the
`voice` example corpus. It's found as a sibling of this checkout, or at `DOTFILES_PRIVATE`.

A skill present in **both** trees is assembled in `~/.claude/skills/<name>/` as a real directory of
symlinks, one per file, drawn from each. A skill in this repo alone stays a single directory
symlink, as before. Editing through `~/.claude` still writes back to whichever repo owns the file.

The merge happens at install time and **never in a checkout**. Symlinking private files into this
tree and relying on `.gitignore` would be simpler and wrong: one missed entry publishes them, and
no leak check would catch it, because that content is anonymized by design and passes every rule.

`install.sh` also copies `.githooks/` into the private repo and sets its `core.hooksPath`. This
repo's hooks stay authoritative, so the two can't drift — don't edit the copy.

### What is linked, what is merged, what is yours

| Mode | Files | Why |
|---|---|---|
| **Linked** | `skills/`, `CLAUDE.md` | Edited deliberately; writing back to the repo is the point |
| **Merged on install** | the five keys in `settings.stable.json` | Preferences that should hold on every machine |
| **Yours alone** | everything else in `settings.json`; `local/config.json`; `local/commit-denylist.txt` | Rewritten by the tool, or machine-specific by nature |

`settings.json` can't be linked: Claude Code rewrites it at runtime, and a `/model` switch strips the
`model` pin — which showed up here as spurious deletions and two pointless restore commits. But most
of what's in it *is* worth carrying, so the durable half lives in `settings.stable.json` and
`install.sh` merges it in key-by-key. Anything not named there is left untouched, so `model`,
`modelSettings` and anything Claude Code writes later all survive.

**`model` and `modelSettings` are deliberately excluded.** Both encode a model id (`opus[1m]`,
`claude-opus-5`) that ages out as new models ship, so the intent worth carrying is "newest Opus,
1M context, xhigh effort" rather than the literal strings. Set them per machine with `/model`.

Two consequences of merging rather than seeding: re-running install **re-asserts** those five keys,
so a local `/config` change to one of them gets overwritten — set machine-specific preferences on
keys outside the stable set. And the merge needs `python3`; without it the step is skipped with a
warning and you copy the values by hand.

## What's here

This directory is the **Claude Code adapter**. The content it installs is portable and lives at the
repo root — `AGENTS.md` and `skills/` — in formats other agents read natively. Only the wiring is
here.

| Path | What |
|---|---|
| `install.sh` | Links the root `AGENTS.md` and `skills/` into `~/.claude`; `--dry-run` and `--uninstall` supported |
| `settings.stable.json` | Durable preferences, merged into `~/.claude/settings.json` on install (see below) |
| `merge-settings.py` | Does that merge, key-by-key |
| `local/config.example.json` | Schema for the machine-local skill overrides (see below) |
| `local/commit-denylist.example.txt` | Starting point for the machine-local leak-guard denylist |

`~/.claude/CLAUDE.md` is a symlink to the repo's `AGENTS.md`: Claude Code looks for the first name,
every other agent for the second, and there is one file behind both.

### The skills

| Skill | What it does |
|---|---|
| `deliver` | Conductor for a whole task: understand → plan → execute → verify → open → merge → clean up |
| `understand-task` | Builds a grounded brief from a ticket or ask, before any code is written |
| `self-review` | Runs the repo's gates over your own diff, then composes the review passes |
| `pr-open` | Opens one MR/PR following your conventions (title, template, draft-if-stacked) |
| `pr-babysit` | Polls an open MR/PR toward merge-ready: sync, CI, comments, SonarQube |
| `pr-merge` | Re-verifies every merge condition, verifies locally against the merged state, merges |
| `post-merge-cleanup` | Advances stacked dependents, deletes branch/worktree, closes the ticket |
| `pr-review` | Reviews someone else's PR, inline, in your voice, never posting without approval |
| `voice` | Drafts outward-facing writing (Slack, PR comments, descriptions) in your voice |
| `maintain-dotfiles` | Lands changes to this repo pair — judges public vs private, groups by concern, commits, pushes, resyncs |

**Every one of them self-educates.** Each ends by asking whether the run warranted a durable edit,
and routes what it finds by portability — repo- or employer-specific facts to `~/.agents/local/`, a
lesson that holds anywhere into the skill, a one-off into a memory. Nothing is written without
showing the exact edit first. Run under `deliver`, a skill hands its lesson up rather than editing,
so `deliver`'s end-of-run reflection routes it once instead of two skills recording it twice.

## Also read by Devin

The Devin CLI can consume this config directly — `CLAUDE.md` becomes an always-on rule and the
skills become `/`-commands — so nothing here needs duplicating for it. What it can't see are the
claude.ai connectors, which live on Anthropic's side rather than in `~/.claude/mcp_servers.json`.
See [`devin/README.md`](../devin/README.md).

## Machine-local overrides

The skills in this repo are generic. Anything that names a private repo, host, bot account or
build pipeline lives in `~/.agents/local/config.json`, which is **outside this repo and never
committed**. Skills read it at run time; every key is optional and falls back to a portable default.

`install.sh` copies the schema to `~/.agents/local/config.example.json` and seeds `config.json`
from it on first run only — an existing one is never overwritten.

| Key | Effect when set |
|---|---|
| `protected_branches_extra` | More branches to refuse to work from, on top of `main`/`master`/`stage-*`. Glob patterns — `*` matches any run of characters, so `rc-*` covers a dated release-candidate series |
| `pr_review_default_repo` | Repo `pr-review` targets when the cwd has no useful origin remote |
| `rebase_sync_repos` | Repos that require rebase-before-push, enabling lease-only force-push there |
| `ai_reviewer_usernames_gitlab` / `_github` | Reviewer bots whose comments get auto-addressed rather than batched |
| `sonar_host_url` | Turns the SonarQube phase on (unset ⇒ skipped entirely) |
| `bot_noise_body_markers_extra` | More bot-comment markers to treat as noise |
| `verification_addenda` | Extra build/test commands for nested apps with their own pipeline |

## Plugins

Not linked by this repo (Claude Code manages its own plugin cache), so install them per machine:

```shell
/plugin marketplace add anthropics/claude-plugins-official
/plugin install frontend-design@claude-plugins-official
```

`settings.json` enables `frontend-design` once it's installed. Work marketplaces and their plugins
are per-machine and intentionally not listed here.

On an Nx monorepo, add `/plugin marketplace add nrwl/nx-ai-agents-config` as well — but only
there. `marketplace add` registers a source without installing anything from it, so anywhere the
codebase isn't Nx the line is inert. Check for an `nx.json`, or an `nx` dependency, first: a
yarn/pnpm workspaces monorepo is still not an Nx one.

## Leak guard

Two hooks in `.githooks/` (enabled by `install.sh` via `core.hooksPath`) block anything that
shouldn't follow this repo to another machine or employer. `pre-commit` scans the lines a commit
**adds**; `commit-msg` scans the **message** — equally public once pushed, and the one place the
reasoning behind a change can name an employer. They share `leak-checks.sh` so the patterns can't
drift apart:

| Check | Catches |
|---|---|
| Credential or token | `ghp_`/`gho_`, `github_pat_`, `glpat-`, `sk-ant-`, `xoxb-`, `AKIA…`, private keys, bearer headers |
| Real email address | any address outside `example.*` / `noreply@` |
| Absolute home path | `/Users/<name>/…`, `/home/<name>/…` |
| Internal hostname | `*.internal`/`*.corp`/`*.lan`, and `sonarqube.`/`gitlab.`/`jira.`/`jenkins.`… on a real domain |
| Real-looking ticket id | any `[A-Z]{2,}-\d+` that isn't the `ABC-1234` placeholder |
| Denylisted term | anything in `~/.agents/local/commit-denylist.txt` |
| Unrecognized person | **`pre-commit` only**, in `skills/voice/refs/` — any person not on `.githooks/placeholder-roster.txt` |
| Commit identity | the author/committer address, when it names an employer or an internal host |

Every check but the last two runs over both a diff and a message. The person check is path-scoped, so
it has no meaning for a message and stays in `pre-commit`.

### Commit identity

An author address is published with the repo like everything else, but no content scan reaches it —
it lives in the commit header, not in any file. It's also the one thing that can't be fixed
afterwards: changing it rewrites every sha from that commit on. So it's checked **before** the diff,
on every commit, and audited across all history.

The blanket "real email address" rule is deliberately not applied here: an identity is an address by
construction, so it would flag every commit ever made and say nothing. What's caught is an address
carrying a **denylisted term** or an **internal hostname** — an employer's domain, a `.lan` machine
name.

`install.sh` sets a repo-local identity to GitHub's no-reply address (`<id>+<login>@users.noreply.
github.com`), leaving your global identity alone so work repos still commit as you. That address is
also now exempt from the email check — "noreply" sits in its domain rather than its local part, so
the original `noreply@` exclusion never matched it.

**The audit will report historical identities until they're rewritten**, and that's intended: this
history carries two past employers' addresses and a `.lan` hostname from before the check existed.
They're harmless while the repo is private and would be published the moment it isn't, so the audit
says so rather than going quiet. `git filter-repo --mailmap` is the fix, if that day comes.

That last check works the other way round from the rest. The voice corpus is anonymized by contract,
so every person in it is invented; the hook therefore keeps an **allowlist** of placeholders and
flags anything person-shaped that isn't on it — `@mentions` and narrative references like
`Firstname asked`. A real name is caught the first time it appears, with nobody having to predict
it, which a denylist can't do. Coined a new placeholder? Add it to the roster. The roster is
committed, since fake names are safe to share and it should work on a fresh machine with no setup.

The denylist is where employer, product and service names go. It's **machine-local on purpose** — a
denylist naming your employer would itself be the leak it prevents, so it lives in `~/.agents/local/`,
outside this repo, and `.gitignore` blocks the in-repo path as a backstop. List what was named
in-house rather than what was bought: a codename nobody coins by accident is worth catching, while a
third-party product anyone might write about buys false positives instead. Previous employers belong
on it too — the repo outlives the job. `install.sh` copies
`local/commit-denylist.example.txt` as a starting point and seeds the real one only if absent.

### Auditing what's already in

The hooks only see content on its way in. `.githooks/leak-audit` covers the other half — every
commit message and every blob ever committed, on all refs, including content added and later
deleted:

```shell
.githooks/leak-audit           # all history
.githooks/leak-audit --tree    # current tree only, fast
```

Run it after adding denylist terms, before making a repo public, and when changing employers. That
first case is the one that matters: the denylist grows when you learn a new codename, and it is
retroactively wrong about every commit made before it. Exits non-zero on a finding, so it can gate a
release.

Reviewed findings go in `.githooks/leak-audit-allow.txt`, **pinned to a blob id** (`path@sha`) rather
than a bare path — a path prefix would exempt that location permanently and swallow a real leak
landing there later. It suppresses history findings only; the hooks ignore it. The run prints how
many exceptions were applied, so nothing is dropped invisibly.

False positive? `git commit --no-verify`. Two self-amending skills — `voice` (Step 4) and `pr-review`
(Step 8) — are also instructed to anonymize before writing anything to disk, so the hook is the
backstop rather than the only defence.

## Not in this repo

Credentials, tokens, chat history, caches and session state all live under `~/.claude` and stay
there — `.credentials.json`, `secrets/`, `history.jsonl`, `projects/`, `sessions/`, `plugins/`.
So do `local/config.json` and `local/commit-denylist.txt`. Nothing here should ever contain a secret.
