# Devin

The Devin CLI can read Claude Code's config directly, so the rules and skills in
[`tools/claude/`](../claude/README.md) work in Devin without being copied or kept in sync.

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

The real file lives outside this repo, like `~/.agents/local/` does, and for the same
reason: it names an account.

## What carries across

| Claude source | Becomes in Devin |
|---|---|
| `~/.claude/CLAUDE.md` | An always-on rule, listed as `CLAUDE [Claude]` |
| `~/.claude/skills/*` | User skills, invokable as `/<name>` |
| `~/.claude/commands`, `~/.claude/agents` | Slash commands and subagents |
| `~/.claude/settings.json`, `settings.local.json` | Permissions |
| `~/.claude/mcp_servers.json` | MCP servers |

`tools/claude/install.sh` symlinks the skills into `~/.claude/skills/`, and Devin follows those
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
  under `skills/`, which is where ours live. **Closed beta** — request access from Cognition support.
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

- **`skills/` at the repo root** is the plugin default, so the manifest declares no path at all.
  The `skills` field exists for a layout that needs one; ours doesn't.
- **`AGENTS.md` is the rules file itself** — a plugin's always-on rule must be an `AGENTS.md`
  at the plugin root and that path *isn't* configurable. Rather than keep a copy, the rules
  live there and `tools/claude/install.sh` points `~/.claude/CLAUDE.md` at it.

Skills arrive namespaced as `/dotfiles:<name>`.

### Installing it

```shell
devin plugins install luisincrespo/dotfiles
```

That's it. The source is public, so Devin Cloud clones it directly — no admin grant, no
upload, no bundle. It installs at **personal** scope, so it reaches your cloud sessions and
your other machines, and nobody else's. **Merging to `master` is the release.**

### Three surfaces, three freshness rules

They do not stay current the same way, and the difference bites once skills start amending
themselves:

| Surface | Source | Current when |
|---|---|---|
| Claude Code | `~/.claude` symlinks into the repo | **immediately** — before you even commit |
| Devin, cloud | fetched per session from the git source | **next session** — nothing to do |
| Devin, local | a cached **copy** under `~/.local/share/devin/cli/plugins/cache/` | **only after `devin plugins update`** |

So on this machine `/deliver` (the Claude import, live) and `/dotfiles:deliver` (the plugin,
a snapshot) can be different versions of the same skill, and nothing warns you. Whichever
the model reaches for is what runs.

```shell
./tools/devin/sync-plugin.sh             # push, then refresh the cache
./tools/devin/sync-plugin.sh --no-push   # refresh only
```

### Why the Claude import stays on

Both sources are active locally, so each of your skills is listed twice and `AGENTS.md`
loads as a rule twice. Turning the import off with `{"read_config_from": {"claude": false}}`
would fix that — and it's one boolean governing every Claude import, so it would also stop
Devin reading a **work repo's** own `.claude/` directory. On the monorepo here that's 48
skills, 6 commands and 5 rules the team maintains.

De-duplicating nine entries isn't worth losing forty-eight. Leave it on.

Cloud is unaffected either way: a cloud VM has no `~/.claude` to import from, so it sees the
nine from the plugin and nothing doubled. That was the whole reason the import couldn't reach
cloud in the first place.

### What does not work, so nobody re-investigates

- **Plugin environment variables and Devin Secrets** for a private fetch. They configure
  command hooks at session start — after the plugin loads, far too late to authenticate the
  fetch that loads it. No documented way to hand git credentials to a plugin fetch at all.
- **Installing the GitHub App on your personal account.** Cloud clones through the
  *organization's* integration, which never consults a personal installation. The two layers
  are easy to conflate: linking your account grants **identity** (authored PRs, review
  comments); only an App installation grants **read access**. Granting it for a repo is
  admin-only, and a repo appearing in the list is not permission — the docs say to confirm it
  "even if it already appears in the repository list".
- **A force-push, to remove something from a published history.** GitHub retains the previous
  tip, and the whole pre-rewrite history stays fetchable by that sha. Deleting and recreating
  the repo is what actually removes it.
- **The repo name.** Briefly suspected when this was called `.dotfiles`; it clones fine over
  HTTPS with a token either way.

### Packaging it as a zip — the private-source fallback

Not needed while the source is public. It's the way in if the repo ever goes private again,
since a zip bypasses git entirely and needs no admin.

`./tools/devin/package-plugin.sh` builds the bundle into `dist/` — the manifest, `AGENTS.md`
and the nine skills — then verifies it, because a bundle that unpacks wrong fails silently in
the web UI.

```shell
./tools/devin/package-plugin.sh                 # public content only
./tools/devin/package-plugin.sh --with-private  # + the private overlay
```

The upload is personal-scope and visible only to you, so the private overlay can ride along —
and `voice` is much better with its corpus than without. Opt-in rather than default because an
**org-scoped** upload would hand that corpus to everyone in the org; a flag you have to type is
a decision, a default is an accident waiting to happen.

**Uploading can't be automated.** The CLI installs only from a repo, a git URL or a local path,
and the v3 API has 151 endpoints and not one for plugins or uploads. The last step is by hand:
Devin → Customize → Add plugin → upload, scope **Personal**.

And a zip is a snapshot: re-run and re-upload after changing a skill, and don't edit the plugin
in Devin's web editor — it's allowed, and it silently forks that copy from this repo.

## Verify

```shell
devin rules list      # expect: CLAUDE [Claude] and AGENTS [Standard], both always-on
devin skills list     # expect: nine bare names, plus nine as /dotfiles:*
devin plugins list    # expect: dotfiles, installed at Personal scope
```

Two rules and doubled skills is the **correct** result here, not a fault — see *Why the
Claude import stays on*. A cloud session shows nine and one, since it has no `~/.claude`.

Run `devin skills list` from **outside this repo**. Inside it, the skills resolve as
project files via `./skills/`, which proves nothing about the user-level wiring —
that path exists here whether or not the flag works. From any other directory they must
still appear, listed against `~/code/dotfiles/skills/`. That's the real check.
