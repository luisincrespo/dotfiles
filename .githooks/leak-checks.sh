#!/usr/bin/env bash
#
# Patterns shared by the two leak-guard hooks. Sourced, never executed.
#
#   pre-commit  scans what a commit CHANGES (its added lines)
#   commit-msg  scans what a commit SAYS about it (the message)
#
# Both are equally public once pushed, so both get the same checks. They live
# here so the pattern list can't drift between the two.
#
# Callers: set FOUND=0, call `scan_common "<text>"`, then on FOUND call
# `leak_blocked "<noun>"` and exit 1.

DENYLIST="${HOME}/.claude/local/commit-denylist.txt"

report() {
  local label="$1" hits="$2"
  printf '\n  \033[1;31m%s\033[0m\n' "$label"
  printf '%s\n' "$hits" | sed 's/^/    /' | head -10
  FOUND=1
}

# check <label> <pattern> [exclude-pattern] [case]
#   case = "cs" for case-sensitive (default is case-insensitive).
# POSIX ERE only (macOS grep has no -P), so exclusions are a second pass.
# Reads $SCAN, set by scan_common.
check() {
  local label="$1" pattern="$2" exclude="${3:-}" case="${4:-ci}"
  local flags="-E" vflags="-vE"
  if [[ "$case" != "cs" ]]; then flags="-iE"; vflags="-ivE"; fi
  local hits
  hits="$(printf '%s\n' "$SCAN" | grep $flags "$pattern" || true)"
  [[ -n "$hits" && -n "$exclude" ]] && hits="$(printf '%s\n' "$hits" | grep $vflags "$exclude" || true)"
  [[ -n "$hits" ]] && report "$label" "$hits"
}

# `git@host.tld`, with or without a trailing `:path`, is an SSH remote rather than an
# address — `git clone git@github.com:owner/repo` and `ssh -T git@github.com` both. Blank
# it out rather than excluding the whole line, so a real address beside one still gets
# caught. The leading-character guard keeps `build-git@vendor.com` a real address.
normalize_ssh_remotes() {
  sed -E \
    -e 's|^git@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|<ssh-remote>|g' \
    -e 's|([^A-Za-z0-9._%+-])git@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|\1<ssh-remote>|g'
}

# Everything that must not travel between machines or employers, regardless of
# whether it appears in a diff or in a message.
scan_common() {
  SCAN="$1"
  [[ -z "$SCAN" ]] && return 0

  check "Credential or token" \
    '(ghp|gho|ghs|ghu)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{15,}|sk-ant-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|Authorization: *Bearer +[A-Za-z0-9._-]{20,}'

  check "Real email address" \
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    '@(example\.(com|org|net)|acme-org)|noreply@'

  check "Absolute home path" \
    '/(Users|home)/[A-Za-z0-9._-]+/'

  check "Internal hostname" \
    '[A-Za-z0-9-]+\.(internal|corp|intranet|lan)\b|(sonar|sonarqube|gitlab|jira|jenkins|artifactory|grafana|confluence)\.[A-Za-z0-9-]+\.[A-Za-z]{2,}'

  # Ticket ids: ABC- is the documented placeholder prefix.
  check "Real-looking ticket id (use ABC-1234 as the placeholder)" \
    '(^|[^A-Za-z0-9])[A-Z]{2,}-[0-9]+' \
    '(^|[^A-Za-z0-9])ABC-[0-9]+' \
    cs

  # Machine-local company terms — employer, product and service names.
  if [[ -r "$DENYLIST" ]]; then
    local terms term hits
    terms="$(grep -vE '^\s*(#|$)' "$DENYLIST" | sed 's/[[:space:]]*$//' || true)"
    if [[ -n "$terms" ]]; then
      while IFS= read -r term; do
        [[ -z "$term" ]] && continue
        hits="$(printf '%s\n' "$SCAN" | grep -iF -- "$term" || true)"
        [[ -n "$hits" ]] && report "Denylisted term: ${term}" "$hits"
      done <<< "$terms"
    fi
  fi
}

leak_blocked() {
  local what="${1:-lines}"
  cat <<MSG

  ────────────────────────────────────────────────────────────────
  Commit blocked: this repo is portable, so the ${what} above would
  follow you to another machine or employer.

  Fix the content, or if it is a false positive:
      git commit --no-verify

  Company-specific terms are read from:
      ~/.claude/local/commit-denylist.txt
  ────────────────────────────────────────────────────────────────

MSG
}
