#!/usr/bin/env bash
#
# Link this repo's Claude Code config into ~/.claude.
#
# Symlinks so edits made on any machine land in the repo and can be committed.
# Anything real that would be replaced is moved into a timestamped backup first.
# Machine-specific values are NOT linked: they live in ~/.agents/local/config.json,
# which this script only ever seeds, never overwrites.
#
# Usage:
#   ./claude/install.sh [--dry-run]     link the repo into ~/.claude
#   ./claude/install.sh --uninstall     drop the symlinks and restore the last backup

set -euo pipefail

# Two roles that used to be one directory. TOOL_DIR is this adapter — the pieces
# that only mean anything to Claude Code. REPO_ROOT holds the portable content:
# AGENTS.md and skills/, in formats other agents read natively.
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TOOL_DIR}/../.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
# Machine-local skill config. Vendor-neutral on purpose: the values are portable
# (protected branches, verification commands), the skills reading them are portable,
# and only this installer happens to sit in the Claude adapter.
LOCAL_DIR="${HOME}/.agents/local"
# A companion repo mirroring this one's layout, holding content that must not be
# published. Sibling by convention; override with DOTFILES_PRIVATE. Absent is fine —
# everything still installs, just without the private half.
PRIVATE_ROOT="${DOTFILES_PRIVATE:-$(cd "${REPO_ROOT}/.." && pwd)/dotfiles-private}"
# Links are made from ~/.claude, so a relative DOTFILES_PRIVATE would resolve from there, not from
# where install.sh ran: make it absolute when it exists.
[[ -d "$PRIVATE_ROOT" ]] && PRIVATE_ROOT="$(cd "$PRIVATE_ROOT" && pwd)"
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

# Remove any symlink under ~/.claude that points into this repo or into
# ~/.agents/local/skills, then put the most recent backup back. Leaves
# ~/.agents/local/* itself alone — that is machine state, not repo content.
if (( UNINSTALL )); then
  echo "Unlinking Claude config from ${REPO_ROOT}"
  echo
  for target in "${CLAUDE_DIR}/skills/"* "${CLAUDE_DIR}/CLAUDE.md"; do
    if [[ -L "$target" ]]; then
      case "$(readlink "$target")" in
        "${REPO_ROOT}"/*|"${PRIVATE_ROOT}"/*|"${LOCAL_DIR}/skills"/*|*/AGENTS.md) rm "$target"; log "unlinked  ${target/#$HOME/$TILDE}" ;;
      esac
    elif [[ -d "$target" && -z "$(find "$target" -type f -not -type l -print -quit 2>/dev/null)" ]]; then
      # An overlaid skill: a real directory holding nothing but symlinks.
      rm -rf "$target"; log "unlinked  ${target/#$HOME/$TILDE} (overlay)"
    fi
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
echo "Linking Claude config from ${REPO_ROOT}"

echo
echo "Skills:"
# A skill the private repo also carries is assembled file-by-file, so the private
# half never has to sit inside the public checkout — where one missed .gitignore
# entry would publish it, and no leak check would catch it, the corpus being
# anonymized by design. A public-only skill stays a single directory symlink.
overlay() {
  local root="$1" name="$2" dest="${CLAUDE_DIR}/skills/$2" src rel
  if [[ -L "$dest" ]]; then
    run rm "$dest"
  elif [[ -d "$dest" ]]; then
    if [[ -n "$(find "$dest" -type f -not -type l -print -quit 2>/dev/null)" ]]; then
      run mkdir -p "$BACKUP_DIR/$(dirname "${dest#"$CLAUDE_DIR"/}")"
      run mv "$dest" "$BACKUP_DIR/${dest#"$CLAUDE_DIR"/}"
      log "backed up ${dest/#$HOME/$TILDE} (held real files)"
    else
      run rm -rf "$dest"
    fi
  fi
  for src in "${REPO_ROOT}/${root}/$name" "${PRIVATE_ROOT}/${root}/$name"; do
    [[ -d "$src" ]] || continue
    while IFS= read -r rel; do
      run mkdir -p "$dest/$(dirname "$rel")"
      run ln -sfn "$src/$rel" "$dest/$rel"
    done < <(cd "$src" && find . -type f | sed 's|^\./||')
  done
  log "overlaid  ${dest/#$HOME/$TILDE}"
}

if [[ -d "$PRIVATE_ROOT" ]]; then
  log "private   ${PRIVATE_ROOT/#$HOME/$TILDE}"
else
  log "private   none found — public content only"
  log "          to make it yours: a repo at ${PRIVATE_ROOT/#$HOME/$TILDE} (or DOTFILES_PRIVATE)"
  log "          holding your own personal-layer files, at the paths README.md's \"Make it yours\" lists"
fi

# Two skill roots, installed side by side. skills/ is portable: every harness reads it,
# and the Devin plugin packages it. tools/claude/skills/ holds skills whose whole purpose
# is a Claude Code mechanism, so only this adapter installs them. The private repo mirrors
# both paths. Both land in ~/.claude/skills/, so a name used in both roots would collide.
seen=" "
for root in skills tools/claude/skills; do
  for skill in "$REPO_ROOT/$root"/*/; do
    [[ -d "$skill" ]] || continue
    name="$(basename "$skill")"
    case "$seen" in
      *" $name "*) echo "skill '${name}' exists in more than one skill root; rename one" >&2; exit 1 ;;
    esac
    seen+="$name "
    if [[ -d "${PRIVATE_ROOT}/${root}/${name}" ]]; then
      overlay "$root" "$name"
    else
      link "${skill%/}" "${CLAUDE_DIR}/skills/${name}"
    fi
  done
done

# Employer- and project-specific skills: ~/.agents/local/skills/<project>/<skill>/. They name
# buckets, paths and tickets, so neither repo can hold them: the public one publishes, and the
# private one's leak guard blocks employer terms by design. Machine-local like the rest of
# ~/.agents/local/, and linked in beside the others, under the same no-collision rule.
for skill in "${LOCAL_DIR}"/skills/*/*/; do
  [[ -f "${skill}SKILL.md" ]] || continue
  name="$(basename "$skill")"
  case "$seen" in
    *" $name "*) echo "skill '${name}' exists in more than one skill root; rename one" >&2; exit 1 ;;
  esac
  seen+="$name "
  link "${skill%/}" "${CLAUDE_DIR}/skills/${name}"
done

echo
echo "Config:"
# The rules are the broadest personal-layer file: a private companion's own AGENTS.md, when it
# has one, is linked in place of this repo's. It should keep the rules the skills cite by number
# (5, 8, 10, 12, 13), or those references point at nothing.
rules="${REPO_ROOT}/AGENTS.md"
[[ -f "${PRIVATE_ROOT}/AGENTS.md" ]] && rules="${PRIVATE_ROOT}/AGENTS.md"
link "$rules" "${CLAUDE_DIR}/CLAUDE.md"

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

# Each preference file is merged in layers: this repo's, then a private companion's on top, key
# by key, so the companion only names the keys it wants different. A dry run previews each layer
# against the result of the ones before it, as the real run applies them.
merge_layers() {
  local file="$1" target="$2" layer tmp
  local layers=("${TOOL_DIR}/${file}")
  [[ -f "${PRIVATE_ROOT}/tools/claude/${file}" ]] && layers+=("${PRIVATE_ROOT}/tools/claude/${file}")
  if (( DRY_RUN )); then
    tmp="$(mktemp)"
    cp "$target" "$tmp" 2>/dev/null || printf '{}\n' > "$tmp"
    for layer in "${layers[@]}"; do
      python3 "${TOOL_DIR}/merge-settings.py" "$layer" "$tmp" --dry-run
      python3 "${TOOL_DIR}/merge-settings.py" "$layer" "$tmp" >/dev/null
    done
    rm -f "$tmp"
  else
    for layer in "${layers[@]}"; do
      python3 "${TOOL_DIR}/merge-settings.py" "$layer" "$target"
    done
  fi
  (( ${#layers[@]} > 1 )) && log "          with the private companion's ${file} on top"
  return 0
}

if command -v python3 >/dev/null 2>&1; then
  log "merging   durable preferences into ~/.claude/settings.json"
  merge_layers settings.stable.json "${CLAUDE_DIR}/settings.json"

  # Global config is Claude Code's own state file, so it's merged only once Claude Code has
  # created it: seeding it here with a lone key would come before onboarding ever ran.
  if [[ -f "${HOME}/.claude.json" ]]; then
    log "merging   durable global preferences into ~/.claude.json"
    merge_layers global.stable.json "${HOME}/.claude.json"
  else
    log "SKIPPED   global merge — no ~/.claude.json until Claude Code's first run; re-run after it"
  fi
else
  log "SKIPPED   settings merge — python3 not found; copy settings.stable.json and global.stable.json by hand"
fi

echo
echo "Machine-local overrides:"
run mkdir -p "${LOCAL_DIR}"
run cp "${REPO_ROOT}/local/config.example.json" "${LOCAL_DIR}/config.example.json"
log "copied    ~/.agents/local/config.example.json"
if [[ -e "${LOCAL_DIR}/config.json" ]]; then
  log "kept      ~/.agents/local/config.json (already present, left untouched)"
else
  run cp "${REPO_ROOT}/local/config.example.json" "${LOCAL_DIR}/config.json"
  log "seeded    ~/.agents/local/config.json — fill in this machine's values"
fi

run cp "${REPO_ROOT}/local/commit-denylist.example.txt" "${LOCAL_DIR}/commit-denylist.example.txt"
log "copied    ~/.agents/local/commit-denylist.example.txt"
if [[ -e "${LOCAL_DIR}/commit-denylist.txt" ]]; then
  log "kept      ~/.agents/local/commit-denylist.txt (already present, left untouched)"
else
  run cp "${REPO_ROOT}/local/commit-denylist.example.txt" "${LOCAL_DIR}/commit-denylist.txt"
  log "seeded    ~/.agents/local/commit-denylist.txt — add this employer's terms"
fi

run cp "${REPO_ROOT}/local/placeholder-roster.example.txt" "${LOCAL_DIR}/placeholder-roster.example.txt"
log "copied    ~/.agents/local/placeholder-roster.example.txt"
if [[ -e "${LOCAL_DIR}/placeholder-roster.txt" ]]; then
  log "kept      ~/.agents/local/placeholder-roster.txt (already present, left untouched)"
else
  run cp "${REPO_ROOT}/local/placeholder-roster.example.txt" "${LOCAL_DIR}/placeholder-roster.txt"
  log "seeded    ~/.agents/local/placeholder-roster.txt — add your own name"
fi

echo
echo "Leak guard:"
if [[ "$(git -C "${REPO_ROOT}" config --get core.hooksPath 2>/dev/null || true)" == ".githooks" ]]; then
  log "ok        core.hooksPath already set to .githooks"
else
  run git -C "${REPO_ROOT}" config core.hooksPath .githooks
  log "enabled   pre-commit leak guard (core.hooksPath = .githooks)"
fi

# Commits here travel, so the identity must too. A work address in a commit header
# is published with the repo and can only be removed by rewriting every sha after
# it, so this repo gets GitHub's no-reply address. The global identity is left
# alone — work repos should keep committing as you.
echo
echo "Commit identity:"
if [[ -n "$(git -C "${REPO_ROOT}" config --local --get user.email 2>/dev/null || true)" ]]; then
  log "ok        repo-local identity already set"
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  NOREPLY="$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null || true)"
  if [[ -n "$NOREPLY" ]]; then
    run git -C "${REPO_ROOT}" config user.email "$NOREPLY"
    log "set       repo-local identity to ${NOREPLY}"
  else
    log "SKIPPED   repo-local identity — could not read the GitHub account"
  fi
else
  log "SKIPPED   repo-local identity — gh not authenticated; set user.email by hand"
fi

# The private repo holds the voice corpus — precisely what the person check exists
# for — so it needs the same guard. Rather than maintain two copies, the public
# repo's hooks are authoritative and copied in on every install, so they can't drift.
if [[ -d "${PRIVATE_ROOT}/.git" ]]; then
  echo
  echo "Private repo:"
  run mkdir -p "${PRIVATE_ROOT}/.githooks"
  run cp "${REPO_ROOT}/.githooks/"* "${PRIVATE_ROOT}/.githooks/"
  run git -C "$PRIVATE_ROOT" config core.hooksPath .githooks
  log "synced    hooks from this repo (authoritative copy)"
  if [[ -z "$(git -C "$PRIVATE_ROOT" config --local --get user.email 2>/dev/null || true)" ]]; then
    EMAIL="$(git -C "$REPO_ROOT" config --local --get user.email 2>/dev/null || true)"
    if [[ -n "$EMAIL" ]]; then
      run git -C "$PRIVATE_ROOT" config user.email "$EMAIL"
      log "set       repo-local identity to match this repo"
    fi
  else
    log "ok        repo-local identity already set"
  fi
fi

echo
if [[ -d "$BACKUP_DIR" ]]; then
  echo "Replaced files are in ${BACKUP_DIR/#$HOME/$TILDE}"
fi
echo "Done. Restart Claude Code to pick up the skills."
