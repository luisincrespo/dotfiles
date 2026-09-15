# Devin

The Devin CLI can read Claude Code's config directly, so the rules and skills in
[`claude/`](../claude/README.md) work in Devin without being copied or kept in sync.

## Setup

**Nothing is required.** Every `read_config_from` import is enabled by default, `claude`
included — Devin picks up the Claude config with no config file at all. The key is only
needed to turn an import *off*:

```json
{
  "read_config_from": {
    "claude": true,
    "windsurf": false
  }
}
```

Setting `"claude": true` explicitly is a no-op that documents the intent and pins it
against a future default change. Worth knowing before you go looking for what a config
edit changed: the answer is nothing.

The rest of that file is machine state the CLI writes itself — `devin.org_id`,
`shell.setup_complete`, `theme_mode`. Leave those to it, and never copy an `org_id`
between accounts; it identifies the org you authenticated against.
[`config.example.json`](./config.example.json) has the shape.

The real file lives outside this repo, like `~/.claude/local/` does, and for the same
reason: it names an account.

## What carries across

| Claude source | Becomes in Devin |
|---|---|
| `~/.claude/CLAUDE.md` | An always-on rule, listed as `CLAUDE [Claude]` |
| `~/.claude/skills/*` | User skills, invokable as `/<name>` |
| `~/.claude/commands`, `~/.claude/agents` | Slash commands and subagents |
| `~/.claude/settings.json`, `settings.local.json` | Permissions |
| `~/.claude/mcp_servers.json` | MCP servers |

`claude/install.sh` symlinks the skills into `~/.claude/skills/`, and Devin follows those
links back here — so one copy of each skill serves both tools, and a skill edited from
either lands in this repo ready to commit.

## What does NOT carry across

**claude.ai connectors.** Linear, Slack, Google Drive and the rest are account-level
connectors on Anthropic's side, not entries in `~/.claude/mcp_servers.json`, so Devin
sees none of them — `devin mcp list` starts empty even with the flag on.

Skills that name an `mcp__claude_ai_*` tool degrade rather than break: `ticket-status.md`
treats a missing connector as "skip silently", by design for exactly this case. But under
Devin, ticket sync doesn't happen and `voice` can't reach Slack. Add what you need with
`devin mcp add`.

## Cloud sessions do NOT get these skills

Everything above is the **local CLI**. A cloud session runs on a fresh VM with no access
to your machine, and `/handoff` sends it exactly three things: the repo and branch, the
conversation context, and your uncommitted diff. Local rules and skills are not on that
list.

The project-level import still applies, though — a cloud session working in a repo reads
that repo's own `.claude/skills/**/SKILL.md`. So skills reach the cloud by living in the
repo being worked on, not by living on your laptop.

Two ways to actually get them there:

- **A plugin** — a bundle of skills, rules, hooks, MCP servers and subagents installed
  from a git repo or subfolder, and the one mechanism documented to work across cloud
  sessions, the CLI and Desktop alike. Needs a `.devin-plugin/plugin.json` and the skills
  under `skills/`; ours sit under `claude/skills/`, so this repo is close to the shape but
  not there yet. **Closed beta** — request access from Cognition support.
- **Commit them into the work repo** under `.claude/skills/`. Simple, and works today —
  but it publishes personal skills into an employer's repo, which is the thing this repo
  is arranged to avoid. Only reasonable for a skill the team should have anyway.

Treat any claim that Desktop "bundles your local profile into the VM" as unverified
unless the shipped docs say so. They enumerate what carries over, and this isn't in it.

## Verify

```shell
devin rules list     # expect: CLAUDE [Claude] always-on
devin skills list    # expect: the nine skills
devin doctor
```

Run `devin skills list` from **outside this repo**. Inside it, the skills resolve as
project files via `./claude/skills/`, which proves nothing about the user-level wiring —
that path exists here whether or not the flag works. From any other directory they must
still appear, listed against `~/code/.dotfiles/claude/skills/`. That's the real check.
