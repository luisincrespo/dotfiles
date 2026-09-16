#!/usr/bin/env bash
#
# Push, then refresh the local Devin plugin cache.
#
# The three surfaces this repo feeds don't stay current the same way:
#
#   Claude Code    ~/.claude symlinks into the repo  — live, before you commit
#   Devin, cloud   fetched per session               — current on the next session
#   Devin, local   a cached COPY of the git source   — frozen until refreshed
#
# Only the last one needs a nudge, and these skills self-amend, so it goes stale
# on its own. Left alone, `/deliver` runs today's rules and `/dotfiles:deliver`
# runs the ones from whenever you last fetched.
#
# Usage:
#   ./tools/devin/sync-plugin.sh [git push args...]
#   ./tools/devin/sync-plugin.sh --no-push      refresh the cache only

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ "${1:-}" == "--no-push" ]]; then
  shift
else
  echo "Pushing…"
  git push "$@"
fi

if ! command -v devin >/dev/null 2>&1; then
  echo "  devin not on PATH — nothing to refresh."
  exit 0
fi

NAME="$(python3 -c "import json;print(json.load(open('.devin-plugin/plugin.json'))['name'])")"

# A plugin installed from a local path is already linked, so refreshing it is
# pointless — and `update` re-fetches from the source, which for a local install
# is this very directory. Only the git-sourced install has a cache to go stale.
if ! devin plugins list 2>/dev/null | grep -q "$NAME"; then
  echo "  '$NAME' isn't installed — nothing to refresh."
  exit 0
fi

echo "Refreshing the local plugin cache…"
devin plugins update "$NAME"
echo
echo "  Cloud sessions pick this up on their next start; nothing to do there."
