# Claude Code

Personal [Claude Code](https://claude.com/claude-code) config: skills, global instructions and
settings, kept portable so they can be installed on any machine.

## Install

```shell
./claude/install.sh            # add --dry-run to preview
```

It symlinks each skill and the config files into `~/.claude`, so edits made from any machine land
back in this repo ready to commit. Anything real it would replace is moved to
`~/.claude/.dotfiles-backup/<timestamp>/` first. Restart Claude Code afterwards to pick up skills.

## What's here

| Path | What |
|---|---|
| `skills/` | Nine skills — the `deliver` MR/PR lifecycle family, plus `self-review`, `understand-task`, `pr-review` and `voice` |
| `CLAUDE.md` | Global instructions applied to every project |
| `settings.json` | Model, effort level, permission mode, enabled plugins |
| `local/config.example.json` | Schema for the machine-local overrides (see below) |

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

## Machine-local overrides

The skills in this repo are generic. Anything that names a private repo, host, bot account or
build pipeline lives in `~/.claude/local/config.json`, which is **outside this repo and never
committed**. Skills read it at run time; every key is optional and falls back to a portable default.

`install.sh` copies the schema to `~/.claude/local/config.example.json` and seeds `config.json`
from it on first run only — an existing one is never overwritten.

| Key | Effect when set |
|---|---|
| `protected_branches_extra` | More branches to refuse to work from, on top of `main`/`master`/`stage-*` |
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
/plugin marketplace add nrwl/nx-ai-agents-config
/plugin install frontend-design@claude-plugins-official
```

`settings.json` enables `frontend-design` once it's installed. Work marketplaces and their plugins
are per-machine and intentionally not listed here.

## Leak guard

A `pre-commit` hook (`.githooks/pre-commit`, enabled by `install.sh` via `core.hooksPath`) scans the
lines each commit **adds** and blocks anything that shouldn't follow this repo to another machine or
employer:

| Check | Catches |
|---|---|
| Credential or token | `ghp_`/`gho_`, `github_pat_`, `glpat-`, `sk-ant-`, `xoxb-`, `AKIA…`, private keys, bearer headers |
| Real email address | any address outside `example.*` / `noreply@` |
| Absolute home path | `/Users/<name>/…`, `/home/<name>/…` |
| Internal hostname | `*.internal`/`*.corp`/`*.lan`, and `sonarqube.`/`gitlab.`/`jira.`/`jenkins.`… on a real domain |
| Real-looking ticket id | any `[A-Z]{2,}-\d+` that isn't the `ABC-1234` placeholder |
| Denylisted term | anything in `~/.claude/local/commit-denylist.txt` |

The denylist is where employer, product and service names go. It's **machine-local on purpose** — a
denylist naming your employer would itself be the leak it prevents. `install.sh` copies
`local/commit-denylist.example.txt` as a starting point and seeds the real one only if absent.

False positive? `git commit --no-verify`. Two self-amending skills — `voice` (Step 4) and `pr-review`
(Step 8) — are also instructed to anonymize before writing anything to disk, so the hook is the
backstop rather than the only defence.

## Not in this repo

Credentials, tokens, chat history, caches and session state all live under `~/.claude` and stay
there — `.credentials.json`, `secrets/`, `history.jsonl`, `projects/`, `sessions/`, `plugins/`.
So do `local/config.json` and `local/commit-denylist.txt`. Nothing here should ever contain a secret.
