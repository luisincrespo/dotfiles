# cmux

The terminal app. It's here for one reason: when an agent session needs input, cmux raises a
macOS notification banner, so a session waiting on you doesn't sit unnoticed in a tab you aren't
looking at.

## Install

```shell
brew install --cask cmux
```

Then let it notify: **System Settings → Notifications → cmux**, notifications allowed, with the
style set to **Banners** (or **Alerts**, to keep them on screen until dismissed).

## Hooks for the other agents

```shell
cmux hooks setup
```

This hooks cmux into the other coding agents it finds on `PATH`, so it sees their sessions start,
stop and ask for permission.

- **Claude Code isn't one of them.** cmux injects Claude Code's hooks itself when `claude` runs
  inside cmux (`cmux hooks --help` says so), so there's nothing to install for it.
- **It only sees what's on `PATH` when you run it.** Run it after installing the agents you use,
  and again after adding one; `cmux hooks setup --agent <name>` does a single agent.
- **What it writes is per machine**, so the repo doesn't track it. For Codex, that's entries in
  `~/.codex/hooks.json` pointing at scripts it generates under `~/.cmux/hooks/`, plus two marked
  blocks in `~/.codex/config.toml`. `cmux hooks uninstall` removes them.

## The notification channel lives on Claude's side

A Claude Code session signals that it needs you through the channel named by
`preferredNotifChannel` in `~/.claude/settings.json`, and cmux only turns some channels into a
macOS banner. With `terminal_bell` the session rings the bell and cmux shows nothing outside its
window; `ghostty` sends the desktop-notification sequence cmux understands, and that becomes the
banner.

So the setting that makes this work is `preferredNotifChannel: "ghostty"`, and it's carried by
[`tools/claude/settings.stable.json`](../tools/claude/settings.stable.json): `install.sh` merges
it in on every machine, with nothing to set by hand. Two consequences:

- **A per-machine `/config` change to it doesn't stick.** The next `install.sh` merges the repo's
  value back over it. Change it in `settings.stable.json` instead.
- **It assumes cmux.** In a terminal that doesn't understand the `ghostty` sequence, a session
  needing you may signal nothing at all. Moving off cmux means revisiting this key.

## Config

cmux reads `~/.config/cmux/cmux.json` (JSON with comments). A setting there is managed by the
file only once it's uncommented; anything else is whatever cmux's Settings window saved. This repo
tracks none of it: the one setting this setup depends on is Claude's, above.
