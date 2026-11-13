#!/usr/bin/env bash
#
# Restart the background Claude Code session that runs this script onto the installed
# Claude Code binary, then exit only once the new process is up.
#
# Meant to run as a background command of the session it restarts: background commands
# carry over into the session's next process, so this script outlives the restart and its
# completion notice lands in the new process, which starts a turn there. The last line it
# prints says how the restart went:
#   RESPAWN COMPLETE    — the session runs in a new process
#   RESPAWN FAILED      — `claude respawn` refused; the old process is still the session
#   RESPAWN UNCONFIRMED — no new process showed up in time
#
# Usage:
#   respawn.sh [delay-seconds]  wait this long first (default 10) so the current turn can end,
#                               then restart the session
#   respawn.sh --wait [hours]   restart nothing: mark the session as waiting and wait up to this
#                               long (default 24) for someone else to restart it, as catchup.py
#                               does for a session whose launch folder isn't trusted

set -uo pipefail

if [[ -z "${CLAUDE_JOB_DIR:-}" ]]; then
  echo "RESPAWN FAILED: CLAUDE_JOB_DIR is unset, so this is not a Claude Code background session"
  exit 1
fi

id="$(basename "${CLAUDE_JOB_DIR}")"
handoff="${CLAUDE_JOB_DIR}/tmp/respawn-handoff.md"
# Holds the waiting helper's pid while one runs; catchup.py reads it.
waiting_marker="${CLAUDE_JOB_DIR}/tmp/respawn-waiting"

# The session's current process ID as the supervisor reports it, or nothing if it isn't listed.
pid_of_session() {
  claude agents --json 2>/dev/null | python3 -I -c '
import json, sys
rows = json.load(sys.stdin)
print(next((str(r["pid"]) for r in rows if r.get("id") == sys.argv[1]), ""))
' "${id}" 2>/dev/null
}

# Polls until the session reports a pid other than $old_pid, and sets new_pid to it.
# Returns 1 if none shows up within $1 polls, $2 seconds apart.
wait_for_new_pid() {
  local tries="$1" interval="$2"
  for _ in $(seq 1 "${tries}"); do
    new_pid="$(pid_of_session)"
    [[ -n "${new_pid}" && "${new_pid}" != "${old_pid}" ]] && return 0
    sleep "${interval}"
  done
  new_pid=""
  return 1
}

old_pid="$(pid_of_session)"
if [[ -z "${old_pid}" ]]; then
  echo "RESPAWN FAILED: session ${id} is not in \`claude agents --json\`"
  exit 1
fi

if [[ "${1:-}" == "--wait" ]]; then
  hours="${2:-24}"
  if [[ -f "${waiting_marker}" ]] && kill -0 "$(cat "${waiting_marker}")" 2>/dev/null; then
    echo "RESPAWN FAILED: a waiting helper already runs as pid $(cat "${waiting_marker}"); it will wake the new process"
    exit 1
  fi
  echo "$$" > "${waiting_marker}"
  trap 'rm -f "${waiting_marker}"' EXIT
  if ! wait_for_new_pid $(( hours * 120 )) 30; then
    echo "RESPAWN UNCONFIRMED: nobody restarted session ${id} within ${hours}h; it still runs as pid ${old_pid}"
    exit 1
  fi
else
  sleep "${1:-10}"
  if ! out="$(claude respawn "${id}" 2>&1)"; then
    case "$out" in
      *"not trusted"*) echo "RESPAWN FAILED: ${out}. Run this helper again with --wait, then ask the user to run claude-catchup in a terminal" ;;
      *) echo "RESPAWN FAILED: ${out}" ;;
    esac
    exit 1
  fi
  if ! wait_for_new_pid 60 2; then
    echo "RESPAWN UNCONFIRMED: sent (${out}) but session ${id} still reports pid ${old_pid} after 120s"
    exit 1
  fi
fi

# A notice that arrives while the new process is still starting is recorded without starting a
# turn, so give it a moment before completing.
sleep 10
echo "RESPAWN COMPLETE: session ${id} now runs $(claude --version) as pid ${new_pid} (was ${old_pid}). Read ${handoff} and resume."
