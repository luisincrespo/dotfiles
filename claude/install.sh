#!/usr/bin/env bash
#
# Link this repo's Claude Code config into ~/.claude.
#
# Symlinks so edits made on any machine land in the repo and can be committed.
# Anything real that would be replaced is moved into a timestamped backup first.
# Machine-specific values are NOT linked: they live in ~/.claude/local/config.json,
# which this script only ever seeds, never overwrites.
#
# Usage:
#   ./claude/install.sh [--dry-run]     link the repo into ~/.claude
#   ./claude/install.sh --uninstall     drop the symlinks and restore the last backup

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_DIR}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
UNINSTALL=0
TILDE='~'
case "${1:-}" in
  --dry-run)   DRY_RUN=1 ;;
  --uninstall) UNINSTALL=1 ;;
  "")          ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

log()  { printf '  %s\n' "$*"; }
run()  { if (( DRY_RUN )); then printf '  would: %s\n' "$*"; else "$@"; fi; }

# Symlink $1 -> $2, backing up an existing real file/dir at $2.
link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      log "ok        ${dest/#$HOME/$TILDE}"
      return
    fi
    run rm "$dest"
  elif [[ -e "$dest" ]]; then
    run mkdir -p "$BACKUP_DIR/$(dirname "${dest#"$CLAUDE_DIR"/}")"
    run mv "$dest" "$BACKUP_DIR/${dest#"$CLAUDE_DIR"/}"
    log "backed up ${dest/#$HOME/$TILDE}"
  fi
  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
  log "linked    ${dest/#$HOME/$TILDE}"
}

# Remove any symlink under ~/.claude that points into this repo, then put the
# most recent backup back. Leaves ~/.claude/local/* alone — that is machine
# state, not repo content.
if (( UNINSTALL )); then
  echo "Unlinking Claude config from ${REPO_DIR}"
  echo
  for target in "${CLAUDE_DIR}/skills/"* "${CLAUDE_DIR}/CLAUDE.md"; do
    [[ -L "$target" ]] || continue
    case "$(readlink "$target")" in
      "${REPO_DIR}"/*) rm "$target"; log "unlinked  ${target/#$HOME/$TILDE}" ;;
    esac
  done

  LATEST="$(ls -1d "${CLAUDE_DIR}/.dotfiles-backup/"*/ 2>/dev/null | sort | tail -1 || true)"
  if [[ -n "$LATEST" && -d "$LATEST" ]]; then
    echo
    echo "Restoring ${LATEST/#$HOME/$TILDE}"
    if [[ -d "${LATEST}skills" ]]; then
      mkdir -p "${CLAUDE_DIR}/skills"
      for backup in "${LATEST}skills/"*; do
        [[ -e "$backup" ]] || continue
        dest="${CLAUDE_DIR}/skills/$(basename "$backup")"
        [[ -e "$dest" ]] && continue
        cp -R "$backup" "$dest" && log "restored  ${dest/#$HOME/$TILDE}"
      done
    fi
    for file in CLAUDE.md; do
      [[ -e "${LATEST}${file}" && ! -e "${CLAUDE_DIR}/${file}" ]] || continue
      cp -R "${LATEST}${file}" "${CLAUDE_DIR}/${file}" && log "restored  ~/.claude/${file}"
    done
  else
    echo
    log "no backup found — nothing to restore"
  fi
  echo
  echo "Done. Restart Claude Code."
  exit 0
fi

(( DRY_RUN )) && echo "DRY RUN — nothing will be changed"
echo "Linking Claude config from ${REPO_DIR}"

echo
echo "Skills:"
for skill in "$REPO_DIR"/skills/*/; do
  link "${skill%/}" "${CLAUDE_DIR}/skills/$(basename "$skill")"
done

echo
echo "Config:"
link "${REPO_DIR}/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md"

# settings.json is NOT linked — Claude Code rewrites it at runtime, so the machine
# owns the file. The repo's durable preferences are merged into it key-by-key;
# volatile keys (model, modelSettings) are never touched. See settings.stable.json.
# A symlink here is legacy, from an install before settings became machine-owned.
# Replace it with a real file, preserving the content it currently resolves to.
if [[ -L "${CLAUDE_DIR}/settings.json" ]]; then
  legacy="$(cat "${CLAUDE_DIR}/settings.json")"
  run rm "${CLAUDE_DIR}/settings.json"
  (( DRY_RUN )) || printf '%s\n' "$legacy" > "${CLAUDE_DIR}/settings.json"
  log "unlinked  ~/.claude/settings.json — now machine-owned, content preserved"
fi

if command -v python3 >/dev/null 2>&1; then
  log "merging   durable preferences into ~/.claude/settings.json"
  if (( DRY_RUN )); then
    python3 "${REPO_DIR}/merge-settings.py" "${REPO_DIR}/settings.stable.json" "${CLAUDE_DIR}/settings.json" --dry-run
  else
    python3 "${REPO_DIR}/merge-settings.py" "${REPO_DIR}/settings.stable.json" "${CLAUDE_DIR}/settings.json"
  fi
else
  log "SKIPPED   settings merge — python3 not found; copy settings.stable.json by hand"
fi

echo
echo "Machine-local overrides:"
run mkdir -p "${CLAUDE_DIR}/local"
run cp "${REPO_DIR}/local/config.example.json" "${CLAUDE_DIR}/local/config.example.json"
log "copied    ~/.claude/local/config.example.json"
if [[ -e "${CLAUDE_DIR}/local/config.json" ]]; then
  log "kept      ~/.claude/local/config.json (already present, left untouched)"
else
  run cp "${REPO_DIR}/local/config.example.json" "${CLAUDE_DIR}/local/config.json"
  log "seeded    ~/.claude/local/config.json — fill in this machine's values"
fi

run cp "${REPO_DIR}/local/commit-denylist.example.txt" "${CLAUDE_DIR}/local/commit-denylist.example.txt"
log "copied    ~/.claude/local/commit-denylist.example.txt"
if [[ -e "${CLAUDE_DIR}/local/commit-denylist.txt" ]]; then
  log "kept      ~/.claude/local/commit-denylist.txt (already present, left untouched)"
else
  run cp "${REPO_DIR}/local/commit-denylist.example.txt" "${CLAUDE_DIR}/local/commit-denylist.txt"
  log "seeded    ~/.claude/local/commit-denylist.txt — add this employer's terms"
fi

echo
echo "Leak guard:"
if [[ "$(git -C "${REPO_DIR}/.." config --get core.hooksPath 2>/dev/null || true)" == ".githooks" ]]; then
  log "ok        core.hooksPath already set to .githooks"
else
  run git -C "${REPO_DIR}/.." config core.hooksPath .githooks
  log "enabled   pre-commit leak guard (core.hooksPath = .githooks)"
fi

# Commits here travel, so the identity must too. A work address in a commit header
# is published with the repo and can only be removed by rewriting every sha after
# it, so this repo gets GitHub's no-reply address. The global identity is left
# alone — work repos should keep committing as you.
echo
echo "Commit identity:"
if [[ -n "$(git -C "${REPO_DIR}/.." config --local --get user.email 2>/dev/null || true)" ]]; then
  log "ok        repo-local identity already set"
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  NOREPLY="$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null || true)"
  if [[ -n "$NOREPLY" ]]; then
    run git -C "${REPO_DIR}/.." config user.email "$NOREPLY"
    log "set       repo-local identity to ${NOREPLY}"
  else
    log "SKIPPED   repo-local identity — could not read the GitHub account"
  fi
else
  log "SKIPPED   repo-local identity — gh not authenticated; set user.email by hand"
fi

echo
if [[ -d "$BACKUP_DIR" ]]; then
  echo "Replaced files are in ${BACKUP_DIR/#$HOME/$TILDE}"
fi
echo "Done. Restart Claude Code to pick up the skills."
