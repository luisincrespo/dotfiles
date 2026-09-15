#!/usr/bin/env bash
#
# Build the plugin bundle for upload to Devin.
#
# Uploading can't be automated — the Devin CLI installs only from a repo, a git
# URL or a local path, and the v3 API has no plugin or upload endpoints at all.
# The zip goes in by hand through Customize → Add plugin → upload. What this
# removes is every step before that one.
#
# Needed because Devin Cloud can't clone a private repo without an org admin
# granting its Git integration access. See README.md.
#
# Usage:
#   ./devin/package-plugin.sh [output.zip]     default: dist/dotfiles-plugin.zip

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

OUT="${1:-${REPO_ROOT}/dist/dotfiles-plugin.zip}"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

# What the plugin actually needs: the manifest, the always-on rule, and the
# skills the manifest points at. Everything else in this repo — the installer,
# the hooks, the shell config — is machine setup and has no meaning in a session.
#
# No -y, deliberately: zip follows AGENTS.md (a symlink to claude/CLAUDE.md) and
# stores real content. Stored as a link it would dangle, since the zip carries no
# claude/CLAUDE.md for it to point at.
zip -rq "$OUT" .devin-plugin AGENTS.md claude/skills \
  -x '*/.DS_Store' '*/.git/*'

# A bundle that unpacks wrong fails silently in the web UI, so check it here.
# The listing is captured once rather than piped per check: `grep -q` exits on its
# first match, which SIGPIPEs `unzip`, and pipefail then reports the whole pipeline
# as failed even though the content was right there.
fail() { printf '  \033[1;31mFAILED\033[0m %s\n' "$*" >&2; exit 1; }
listing="$(unzip -l "$OUT")"
grep -q '\.devin-plugin/plugin\.json' <<<"$listing" || fail "manifest missing"
agents="$(unzip -p "$OUT" AGENTS.md)"
[[ -n "$agents" ]] || fail "AGENTS.md empty — symlink stored as a link, not followed?"
skills=$(grep -c 'claude/skills/[^/]*/SKILL\.md' <<<"$listing" || true)
declared=$(python3 -c "import json;print(json.load(open('.devin-plugin/plugin.json'))['skills'])")
[[ "$skills" -gt 0 ]] || fail "no SKILL.md files bundled"

printf '\n  \033[1;32mBuilt\033[0m %s\n' "${OUT/#$HOME/~}"
printf '  %s skills from %s, plus AGENTS.md and the manifest (%s)\n\n' \
  "$skills" "$declared" "$(du -h "$OUT" | cut -f1 | tr -d ' ')"
cat <<'NEXT'
  Upload it: Devin → Customize → Add plugin → upload, scope Personal.
  Re-run this and re-upload after changing a skill — an uploaded bundle is a
  snapshot, not a link to this repo. Don't edit it in Devin's web editor, or
  the copy there silently stops matching what's committed here.

NEXT
