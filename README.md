# .dotfiles

Personal interactive shell and AI tooling config.

## Usage

### ZSH

Personal `zsh` config: `ohmyzsh` setup and plugins. Follow the instructions [here](./zsh/README.md).

### Claude Code

Skills, global instructions and settings for [Claude Code](https://claude.com/claude-code).
Follow the instructions [here](./claude/README.md). On a new machine:

```shell
git clone git@github.com:luisincrespo/.dotfiles.git ~/code/.dotfiles
cd ~/code/.dotfiles && ./claude/install.sh
```

Everything committed here is employer-neutral; machine-specific values live in
`~/.claude/local/` and are never committed. Roll back with `./claude/install.sh --uninstall`.

## Leak guard

Commits are checked by `.githooks/pre-commit`, which blocks credentials, real email addresses,
internal hostnames, ticket ids and any employer-specific term listed in
`~/.claude/local/commit-denylist.txt`. Enabled by `./claude/install.sh`, or manually with:

```shell
git config core.hooksPath .githooks
```

Override a false positive with `git commit --no-verify`.
