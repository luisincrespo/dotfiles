# ZSH

Personal interactive shell config for `zsh`: `ohmyzsh` plus the plugins below.

## Two things that bite on a fresh machine

Both are about *when* things load, not whether they're installed — and both fail quietly,
so they're worth knowing before you start rather than debugging after.

- **`brew shellenv` must run before `source $ZSH/oh-my-zsh.sh`.** The `autojump` and `pyenv`
  plugins probe for their binaries at load time and simply return if the Homebrew paths
  aren't on `$PATH` yet. No error — just a shell with no `j`.
- **`pyenv` needs its shims on `$PATH` for non-interactive shells too.** The plugin only
  covers interactive ones, so without this pyenv prints a `badly configured` warning on
  every shell and breaks in scripts.

The `~/.zprofile` and `~/.zshrc` below both handle this.

## Install

### 1. Homebrew

Follow the instructions [here](https://brew.sh/).

Run it in a **real terminal window**. The installer needs a TTY to prompt for `sudo`, so
anywhere that isn't one — a pipe, a CI step, Claude Code's `!` prefix — it aborts with
`Need sudo access on macOS`, which reads like a permissions problem but isn't. To run it
from somewhere without a TTY, prime the credential cache with `sudo -v` in a real terminal
first, then use `NONINTERACTIVE=1`.

### 2. ohmyzsh

Follow [these](https://github.com/ohmyzsh/ohmyzsh#basic-installation) instructions.

It replaces `~/.zshrc` with its own template and backs the old one up to
`~/.zshrc.pre-oh-my-zsh`; anything already in there has to be carried across by hand.
`--unattended` skips the confirmation prompt and the `chsh` call.

### 3. Plugin prerequisites

`autojump` and `pyenv` come from Homebrew:

```shell
brew update
brew install autojump pyenv
```

`nvm` does **not** — use the [official installer](https://github.com/nvm-sh/nvm#installing-and-updating):

```shell
PROFILE=/dev/null bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'
nvm install --lts
```

Two reasons to skip `brew install nvm`. Homebrew's own caveat says upstream considers
managing nvm through it unsupported. And it loses either way against the plugin: the
plugin checks `~/.nvm` first and gives up when `~/.nvm/nvm.sh` isn't there, so the
Homebrew copy yields no `nvm` at all — while the Homebrew layout it *would* fall back to
puts `NVM_DIR` inside the Cellar, where `brew upgrade` takes every installed Node with it.

`PROFILE=/dev/null` stops the installer appending its own `NVM_DIR` block to `~/.zshrc`.
The plugin already does that; letting both do it sources `nvm.sh` twice on every shell.

### 4. `~/.zprofile`

Login-shell environment. Homebrew lives here so scripts and non-interactive shells get it,
and pyenv's shims go here for the reason above.

```shell
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export PYENV_ROOT="$HOME/.pyenv"
if [[ -d "$PYENV_ROOT/bin" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init --path)"
fi
```

On Intel Macs Homebrew lives at `/usr/local` rather than `/opt/homebrew`.

### 5. `~/.zshrc`

Set the plugin list:

```shell
plugins=(git nvm npm yarn autojump pyenv)
```

and, **above** the `source $ZSH/oh-my-zsh.sh` line, repeat Homebrew as a fallback for
non-login interactive shells. The `command -v` guard keeps it from prepending `$PATH` a
second time when `~/.zprofile` already ran:

```shell
if [[ -x /opt/homebrew/bin/brew ]] && ! command -v brew >/dev/null 2>&1; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
```

Nothing else is needed. The `autojump`, `pyenv` and `nvm` plugins all locate their own
installs, so none of the `source` lines from the various install caveats belong here.

## Verify

```shell
zsh -l -i -c 'command -v node; command -v pyenv; which j | head -1'
```

Expect a Node under `~/.nvm/versions/`, a `pyenv` shim, `j` defined as a function, and no
pyenv `badly configured` warning. Duplicate `$PATH` entries mean the `~/.zshrc` fallback
guard is missing:

```shell
zsh -l -i -c 'echo $PATH | tr ":" "\n" | sort | uniq -d'
```

## The plugins

- [git](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git)
- [nvm](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/nvm)
- [npm](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/npm)
- [yarn](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/yarn)
- [autojump](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/autojump)
- [pyenv](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/pyenv)
