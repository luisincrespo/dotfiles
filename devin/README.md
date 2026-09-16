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

## This repo is a plugin

`.devin-plugin/plugin.json` makes the repo installable as a plugin, which is how the
skills reach a cloud session:

```shell
devin plugins install luisincrespo/dotfiles      # git source — syncs to cloud
devin plugins install --local .                  # this machine only, for authoring
```

The CLI refuses a local-path install with "local path sources can't sync to Devin Cloud",
which is also how you know a git-sourced one does.

Two details make the packaging cost almost nothing:

- **`"skills": "claude/skills"`** — the manifest points at where the skills already live,
  so nothing moved. The field takes any plugin-root-relative path.
- **`AGENTS.md` is a symlink to `claude/CLAUDE.md`** — a plugin's always-on rule must be
  an `AGENTS.md` at the plugin root and that path *isn't* configurable, so linking beats
  keeping a second copy to drift. Devin follows it.

Skills arrive namespaced as `/dotfiles:<name>`.

### If you ever do install it: turn the Claude import off

With both active, everything doubles — `/deliver` from the import and `/dotfiles:deliver`
from the plugin, and `CLAUDE.md` loaded as a rule twice over. Same files either way, so
nothing breaks, but the list is ambiguous and the rule burns context twice. Once the
plugin is the source of truth, set:

```json
{ "read_config_from": { "claude": false } }
```

That is the one edit to this file that actually changes behaviour.

### Cloud needs the repo public, or an admin

The manifest works — all nine skills and the rule load, and a git-sourced install is
explicitly "added to your personal plugins, applying to your cloud sessions and other
devices". **But a private repo can't be cloned by Devin Cloud here**, and the way out
isn't in your hands.

The GitHub integration has two layers that are easy to conflate:

| Layer | Grants | |
|---|---|---|
| Account link | Devin acts under **your identity** — authored PRs, review comments | attribution |
| GitHub App installation | **Read access** to selected repositories | access |

Linking your account is not access. Cloud clones through the **organization's** integration,
so the org must hold read permission on the repo — and installing the app on your *personal*
GitHub account doesn't help, because the org's integration never consults that installation.
Granting it is admin-only: "ask an admin to grant the affected organization access… from
Settings → Repositories". The repo showing up in a list means nothing; the docs call this
out directly — confirm permission "even if it already appears in the repository list".

What does work, all verified:

- **A public source repo.** No grant, no integration, no admin — a public plugin installs
  to personal scope and reaches cloud.
- **A zip uploaded at personal scope.** Bypasses git entirely — see below. This is the
  route in use here, since the repo is staying private.
- **An admin grant**, if asking is reasonable where you work.

What does **not** work, so nobody re-investigates:

- Plugin environment variables and Devin Secrets. They configure command hooks at session
  start — after the plugin loads, which is far too late to authenticate the fetch that
  loads it. No documented way to hand git credentials to a plugin fetch at all.
- Installing the GitHub App on your own account, as above.
- The repo name. It was briefly suspected, since the repo was called `.dotfiles` at the time;
  it clones fine over HTTPS with a token either way.

### Packaging it as a zip

`./devin/package-plugin.sh` builds the bundle into `dist/` — the manifest, `AGENTS.md`
with its symlink resolved to real content, and the nine skills — then verifies it, because
a bundle that unpacks wrong fails silently in the web UI.

**Uploading can't be automated.** The CLI installs only from a repo, a git URL or a local
path, and the v3 API has 151 endpoints and not one for plugins or uploads. So the last step
is by hand: Devin → Customize → Add plugin → upload, scope **Personal** (an org-scoped
upload would install it for everyone in the org).

Two consequences of a zip being a snapshot rather than a link:

- **Re-run and re-upload after changing a skill.** Nothing propagates on its own.
- **Don't edit the plugin in Devin's web editor.** It's allowed, and it silently forks the
  copy there away from what's committed here. This repo stays the source of truth.

### So: don't install this plugin locally

It would add nothing. The Claude import above already serves all nine skills to the CLI
and Desktop, and a local install merely duplicates them as `/dotfiles:*` and loads
`CLAUDE.md` as a rule twice. The plugin's only value is cloud, which is blocked. That also
makes `read_config_from.claude` moot — leave it alone.

The manifest stays in the repo, working and ready, for whenever the source is public or an
account can grant access.

## Verify

```shell
devin rules list     # expect: CLAUDE [Claude] always-on
devin skills list    # expect: the nine skills
devin doctor
```

Run `devin skills list` from **outside this repo**. Inside it, the skills resolve as
project files via `./claude/skills/`, which proves nothing about the user-level wiring —
that path exists here whether or not the flag works. From any other directory they must
still appear, listed against `~/code/dotfiles/claude/skills/`. That's the real check.
