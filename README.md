# .dotfiles

Personal interactive shell and AI tooling config.

## New machine

Roughly in order — each step has something later that depends on it.

1. **Xcode Command Line Tools** — `xcode-select --install`. Ships `git` and `curl`, and
   Homebrew won't install without them.
2. **SSH key** — `ssh-keygen -t ed25519`, add the public half to GitHub, confirm with
   `ssh -T git@github.com`.
3. **Clone this repo:**

   ```shell
   git clone git@github.com:luisincrespo/.dotfiles.git ~/code/.dotfiles
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

6. **Claude Code** — `cd ~/code/.dotfiles && ./claude/install.sh`, then fill in the
   machine-local files and install plugins: [`claude/README.md`](./claude/README.md).
7. **Forge CLIs** — `gh auth login`, plus `glab auth login` if the job uses GitLab. Both
   need a real terminal for the browser handshake.
8. **Devin**, if you use it — one key in `~/.config/devin/config.json` points it at the Claude
   config, so the same rules and skills serve both: [`devin/README.md`](./devin/README.md).

Anything that prompts for `sudo` or opens a browser needs a TTY, so run it in a terminal
window rather than through a pipe or an agent's shell.

## Usage

### ZSH

Personal `zsh` config: `ohmyzsh` setup and plugins. Follow the instructions [here](./zsh/README.md).

### Claude Code

Skills, global instructions and settings for [Claude Code](https://claude.com/claude-code).
Installed with `./claude/install.sh`; follow the instructions [here](./claude/README.md).

Everything committed here is employer-neutral; machine-specific values live in
`~/.claude/local/` and are never committed. Roll back with `./claude/install.sh --uninstall`.

### Devin

The Devin CLI reads the Claude config above rather than duplicating it, so one copy of each rule
and skill serves both tools. Follow the instructions [here](./devin/README.md).

## Leak guard

Commits are checked by two hooks in `.githooks/` — `pre-commit` over the lines a commit adds,
`commit-msg` over its message — which block credentials, real email addresses, internal hostnames,
ticket ids and any employer-specific term listed in `~/.claude/local/commit-denylist.txt`. That
denylist stays outside the repo, since one naming your employer would be the leak it prevents.
Enabled by `./claude/install.sh`, or manually with:

```shell
git config core.hooksPath .githooks
```

Override a false positive with `git commit --no-verify`.

Hooks only catch content on the way in. `.githooks/leak-audit` scans what is already committed —
every message and every blob on every ref — for the same patterns. Worth a run after adding denylist
terms, since those are retroactively wrong about every earlier commit.
