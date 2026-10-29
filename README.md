# dotfiles

Personal interactive shell and AI tooling config.

## New machine

Roughly in order — each step has something later that depends on it.

1. **Xcode Command Line Tools** — `xcode-select --install`. Ships `git` and `curl`, and
   Homebrew won't install without them.
2. **SSH key** — `ssh-keygen -t ed25519`, add the public half to GitHub, confirm with
   `ssh -T git@github.com`.
3. **Clone this repo**, and the private companion beside it if you have access:

   ```shell
   git clone git@github.com:luisincrespo/dotfiles.git ~/code/dotfiles
   git clone git@github.com:luisincrespo/dotfiles-private.git ~/code/dotfiles-private
   ```

   The second is optional — it's found as a sibling, or wherever `DOTFILES_PRIVATE` points.

4. **Shell** — Homebrew, `ohmyzsh`, the plugins and their prerequisites:
   [`zsh/README.md`](./zsh/README.md). Do this before the Claude install, which needs
   `python3` to merge settings.
5. **Terminal** — cmux, so an agent waiting on you raises a macOS banner:
   [`cmux/README.md`](./cmux/README.md). The Claude install below sets the notification channel
   it relies on, and its `cmux hooks setup` runs once the other agents you use are installed.
6. **Git identity** — a fresh Mac has no `~/.gitconfig` at all, so nothing commits until:

   ```shell
   git config --global user.name  "<name>"
   git config --global user.email "<email>"
   git config --global pull.rebase false   # CLAUDE.md rule 10 — default to merge, not rebase
   ```

7. **Claude Code** — `cd ~/code/dotfiles && ./tools/claude/install.sh`, then fill in the
   machine-local files and install plugins: [`tools/claude/README.md`](./tools/claude/README.md).
8. **Forge CLIs** — `gh auth login`, plus `glab auth login` if the job uses GitLab. Both
   need a real terminal for the browser handshake.
9. **Devin**, if you use it — one key in `~/.config/devin/config.json` points it at the Claude
   config, so the same rules and skills serve both: [`tools/devin/README.md`](./tools/devin/README.md).

Anything that prompts for `sudo` or opens a browser needs a TTY, so run it in a terminal
window rather than through a pipe or an agent's shell.

## Layout

Split by **what a thing is**, not by which tool reads it. The content at the top is portable; the
adapters under `tools/` are the only vendor-specific parts.

That holds for skills too. A skill belongs in `skills/` when what it does makes sense in any
harness, even if it uses a Claude Code tool where one exists; most fall back gracefully elsewhere.
It belongs in `tools/claude/skills/` when its whole purpose is a Claude Code mechanism, so another
harness has nothing to fall back to: `respawn`, which restarts a Claude Code background session,
is the first.

A skill that only makes sense on one project, because it names that employer's buckets, paths or
tickets, belongs in neither repo: this one publishes, and the private one's leak guard blocks
employer terms by design. It lives in `~/.agents/local/skills/<project>/<skill>/`, machine-local
like the rest of `~/.agents/local/`, and `install.sh` links it in beside the others. Nobody plans
these up front. One appears when a procedure on a project recurs and a session turns it into a
skill rather than walking through it again (the self-educate rule in `AGENTS.md`).

Skills share text the way code shares a module. A checklist two skills apply lives once, in the
folder of the skill that owns it, and the other reads it from there. `skills/self-review/passes/`
holds every check `self-review` and `pr-review` both run, from performance to the second-model
review: each file says what the check looks for and when it applies, and each skill decides what a
finding becomes, a fix in one and a drafted comment in the other. A pass loads only when it runs.
Pointing at a sibling's step also works for a rule, but loads that whole skill to read one
paragraph. Don't give shared files a folder of their own under `skills/`, because `install.sh`
links every directory there as a skill.

| Path | | |
|---|---|---|
| `AGENTS.md` | the rules | **portable** — the cross-tool standard for agent instructions |
| `skills/` | the skills | **portable** — `SKILL.md` is one format shared by Devin, Claude Code, Copilot and Windsurf |
| `tools/claude/` | adapter | installer, settings, machine-local schemas, and the skills only Claude Code can run |
| `tools/devin/` | adapter | plugin packaging, config |
| `.devin-plugin/` | adapter | plugin manifest — must sit at the repo root, not under `tools/` |
| `.githooks/` | repo hygiene | leak guard; vendor-neutral |
| `zsh/` | shell | nothing to do with agents |
| `cmux/` | terminal | setup only; the notification setting it needs is in `tools/claude/` |

Anything that can't be published lives in a private companion repo,
[`dotfiles-private`](https://github.com/luisincrespo/dotfiles-private), which mirrors this layout.
`install.sh` overlays the two into `~/.claude` at install time — a skill in both trees is assembled
file-by-file. Neither checkout ever holds the other's files, so publishing this repo can't leak the
private half by accident. Without it, everything still installs; only `voice` runs thinner.

Adding a tool means adding one directory under `tools/` that points it at `AGENTS.md` and
`skills/`. Nothing in either needs to change, and nothing about them is Claude-specific despite
Claude Code being the tool they were first written for.

Three of those placements aren't preferences. A Devin plugin's always-on rule must be an
`AGENTS.md` at the plugin root, its manifest must be at `.devin-plugin/plugin.json`, and its skills
path can't traverse `..` — so the root-level layout is forced, and it happens to be the neutral
standard anyway.

## Make it yours

This setup is opinionated on purpose, and built to be shared. The skills, the review passes and
the guidelines in them are the **shared machinery**: they hold up for anyone, opinions included. A
small set of files hold one person's taste instead, the **personal layer**, and the machinery reads
them. The ones in this repo are Luis's, kept here as working defaults. Making the setup yours means
replacing those files; nothing else needs editing.

| Personal-layer file | What it holds |
|---|---|
| `AGENTS.md` | The rules every session loads: workflow, git and PR conventions, code style, how much the agent does without asking. The skills cite rules 5, 8, 10, 12 and 13 by number, so keep those, reworded as you like |
| `skills/voice/refs/principles.md` | How you write. `voice` drafts PR descriptions, review comments and messages in it |
| `skills/voice/refs/examples-*.md` | Real messages of yours, the voice's ground truth. Private by nature, so they only ever live in the private companion |
| `skills/pr-review/refs/style.md` | How you review: what's worth a comment, where comments go, how they read, how drafts are shown to you |
| `skills/self-review/passes/personal-conventions.md` | Your code conventions beyond what the rules and each repo's `CLAUDE.md` say |
| `tools/claude/settings.stable.json`, `tools/claude/global.stable.json` | Your Claude Code preferences |

`zsh/` and `cmux/` document one person's shell and terminal; nothing reads them, so take or leave
them.

**Two ways to replace them:**

- **A private companion repo**, the way this one is meant to be used. Clone this repo as it is, and
  keep your versions of the files above at the same paths in a private repo beside it
  (`../dotfiles-private`, or wherever `DOTFILES_PRIVATE` points). `install.sh` links yours in place
  of these: a skill file or `AGENTS.md` of yours replaces this repo's, and your two preference files
  are merged on top of these key by key, so they only need the keys you want different. This repo's
  improvements then arrive with a plain `git pull`, with nothing to merge, and `install.sh` installs
  the leak guard into your private repo too.
- **A fork.** Edit the files in place. Pulling from upstream then conflicts only in the files you
  made yours.

**Then it learns your way.** Every skill's self-educate step routes what it learns: a preference
that's your own taste goes into the personal-layer file it belongs to, and a lesson anyone using
the skill would want goes into the shared skill, which is worth sending upstream as a PR. A nearly
empty voice principles file is a fine start, since `voice` adds a principle each time you correct a
draft.

Two limits. Devin reads this repo through its plugin, so it sees these defaults, not a private
companion's files. And machine-specific values (repo ids, hosts, the leak guard's denylist, review
settings) are a third layer, in `~/.agents/local/`, which `install.sh` seeds: see
[`tools/claude/README.md`](./tools/claude/README.md).

## Usage

### ZSH

Personal `zsh` config: `ohmyzsh` setup and plugins. Follow the instructions [here](./zsh/README.md).

### cmux

The terminal app, for the macOS banner it raises when an agent needs input. Follow the
instructions [here](./cmux/README.md).

### Claude Code

`./tools/claude/install.sh` links `AGENTS.md` and `skills/` into `~/.claude`, and merges the durable
settings. Follow the instructions [here](./tools/claude/README.md).

Everything committed here is employer-neutral; machine-specific values live outside the repo and are
never committed. Roll back with `./tools/claude/install.sh --uninstall`.

### Devin

Devin reads the same `AGENTS.md` and `skills/` — natively, not through a translation. Follow the
instructions [here](./tools/devin/README.md).

## Leak guard

Commits are checked by two hooks in `.githooks/` — `pre-commit` over the lines a commit adds,
`commit-msg` over its message — which block credentials, real email addresses, internal hostnames,
ticket ids and any employer-specific term listed in `~/.agents/local/commit-denylist.txt`. That
denylist stays outside the repo, since one naming your employer would be the leak it prevents.
Enabled by `./tools/claude/install.sh`, or manually with:

```shell
git config core.hooksPath .githooks
```

Override a false positive with `git commit --no-verify`.

Hooks only catch content on the way in. `.githooks/leak-audit` scans what is already committed —
every message and every blob on every ref — for the same patterns. Worth a run after adding denylist
terms, since those are retroactively wrong about every earlier commit.
