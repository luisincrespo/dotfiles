#!/usr/bin/env bash
#
# Link this repo's Claude Code config into ~/.claude.
#
# Symlinks so edits made on any machine land in the repo and can be committed.
# Anything real that would be replaced is moved into a timestamped backup first.
# Machine-specific values are NOT linked: they live in ~/.claude/local/config.json,
# which this script only ever seeds, never overwrites.
#
# Usage: ./claude/install.sh [--dry-run]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_DIR}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
TILDE='~'
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

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

(( DRY_RUN )) && echo "DRY RUN — nothing will be changed"
echo "Linking Claude config from ${REPO_DIR}"

echo
echo "Skills:"
for skill in "$REPO_DIR"/skills/*/; do
  link "${skill%/}" "${CLAUDE_DIR}/skills/$(basename "$skill")"
done

echo
echo "Config:"
link "${REPO_DIR}/CLAUDE.md"     "${CLAUDE_DIR}/CLAUDE.md"
link "${REPO_DIR}/settings.json" "${CLAUDE_DIR}/settings.json"

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

echo
if [[ -d "$BACKUP_DIR" ]]; then
  echo "Replaced files are in ${BACKUP_DIR/#$HOME/$TILDE}"
fi
echo "Done. Restart Claude Code to pick up the skills."
