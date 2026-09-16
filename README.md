# dotfiles

Personal interactive shell and AI tooling config.

## New machine

Roughly in order — each step has something later that depends on it.

1. **Xcode Command Line Tools** — `xcode-select --install`. Ships `git` and `curl`, and
   Homebrew won't install without them.
2. **SSH key** — `ssh-keygen -t ed25519`, add the public half to GitHub, confirm with
   `ssh -T git@github.com`.
3. **Clone this repo:**

   ```shell
   git clone git@github.com:luisincrespo/dotfiles.git ~/code/dotfiles
   ```

4. **Shell** — Homebrew, `ohmyzsh`, the plugins and their prerequisites:
   [`zsh/README.md`](./zsh/README.md). Do this before the Claude install, which needs
   `python3` to merge settings.
5. **Git identity** — a fresh Mac has no `~/.gitconfig` at all, so nothing commits until:

   ```shell
   git config --global user.name  "<name>"
   git config --global user.email "<email>"
   git config --global pull.rebase false   # CLAUDE.md rule 10 — default to merge, not rebase
   ```

6. **Claude Code** — `cd ~/code/dotfiles && ./tools/claude/install.sh`, then fill in the
   machine-local files and install plugins: [`tools/claude/README.md`](./tools/claude/README.md).
7. **Forge CLIs** — `gh auth login`, plus `glab auth login` if the job uses GitLab. Both
   need a real terminal for the browser handshake.
8. **Devin**, if you use it — one key in `~/.config/devin/config.json` points it at the Claude
   config, so the same rules and skills serve both: [`tools/devin/README.md`](./tools/devin/README.md).

Anything that prompts for `sudo` or opens a browser needs a TTY, so run it in a terminal
window rather than through a pipe or an agent's shell.

## Layout

Split by **what a thing is**, not by which tool reads it. The content at the top is portable; the
adapters under `tools/` are the only vendor-specific parts.

| Path | | |
|---|---|---|
| `AGENTS.md` | the rules | **portable** — the cross-tool standard for agent instructions |
| `skills/` | the skills | **portable** — `SKILL.md` is one format shared by Devin, Claude Code, Copilot and Windsurf |
| `tools/claude/` | adapter | installer, settings, machine-local schemas |
| `tools/devin/` | adapter | plugin packaging, config |
| `.devin-plugin/` | adapter | plugin manifest — must sit at the repo root, not under `tools/` |
| `.githooks/` | repo hygiene | leak guard; vendor-neutral |
| `zsh/` | shell | nothing to do with agents |

Adding a tool means adding one directory under `tools/` that points it at `AGENTS.md` and
`skills/`. Nothing in either needs to change, and nothing about them is Claude-specific despite
Claude Code being the tool they were first written for.

Three of those placements aren't preferences. A Devin plugin's always-on rule must be an
`AGENTS.md` at the plugin root, its manifest must be at `.devin-plugin/plugin.json`, and its skills
path can't traverse `..` — so the root-level layout is forced, and it happens to be the neutral
standard anyway.

## Usage

### ZSH

Personal `zsh` config: `ohmyzsh` setup and plugins. Follow the instructions [here](./zsh/README.md).

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
ticket ids and any employer-specific term listed in `~/.claude/local/commit-denylist.txt`. That
denylist stays outside the repo, since one naming your employer would be the leak it prevents.
Enabled by `./tools/claude/install.sh`, or manually with:

```shell
git config core.hooksPath .githooks
```

Override a false positive with `git commit --no-verify`.

Hooks only catch content on the way in. `.githooks/leak-audit` scans what is already committed —
every message and every blob on every ref — for the same patterns. Worth a run after adding denylist
terms, since those are retroactively wrong about every earlier commit.
