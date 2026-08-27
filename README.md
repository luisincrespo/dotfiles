# .dotfiles

Personal interactive shell and AI tooling config.

## Usage

### ZSH

Personal `zsh` config: `ohmyzsh` setup and plugins. Follow the instructions [here](./zsh/README.md).

### Claude Code

Skills, global instructions and settings for [Claude Code](https://claude.com/claude-code),
installed with `./claude/install.sh`. Follow the instructions [here](./claude/README.md).

## Leak guard

Commits are checked by `.githooks/pre-commit`, which blocks credentials, real email addresses,
internal hostnames, ticket ids and any employer-specific term listed in
`~/.claude/local/commit-denylist.txt`. Enabled by `./claude/install.sh`, or manually with:

```shell
git config core.hooksPath .githooks
```

Override a false positive with `git commit --no-verify`.
