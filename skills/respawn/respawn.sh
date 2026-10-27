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
#   RESPAWN UNCONFIRMED — the respawn was sent but no new process showed up in time
#
# Usage:
#   respawn.sh [delay-seconds]   wait this long first (default 10) so the current turn can end

set -uo pipefail

if [[ -z "${CLAUDE_JOB_DIR:-}" ]]; then
  echo "RESPAWN FAILED: CLAUDE_JOB_DIR is unset, so this is not a Claude Code background session"
  exit 1
fi

id="$(basename "${CLAUDE_JOB_DIR}")"
handoff="${CLAUDE_JOB_DIR}/tmp/respawn-handoff.md"
delay="${1:-10}"

# The session's current process ID as the supervisor reports it, or nothing if it isn't listed.
pid_of_session() {
  claude agents --json 2>/dev/null | python3 -I -c '
import json, sys
rows = json.load(sys.stdin)
print(next((str(r["pid"]) for r in rows if r.get("id") == sys.argv[1]), ""))
' "${id}" 2>/dev/null
}

old_pid="$(pid_of_session)"
if [[ -z "${old_pid}" ]]; then
  echo "RESPAWN FAILED: session ${id} is not in \`claude agents --json\`"
  exit 1
fi

sleep "${delay}"

if ! out="$(claude respawn "${id}" 2>&1)"; then
  echo "RESPAWN FAILED: ${out}"
  exit 1
fi

new_pid=""
for _ in $(seq 1 60); do
  new_pid="$(pid_of_session)"
  [[ -n "${new_pid}" && "${new_pid}" != "${old_pid}" ]] && break
  new_pid=""
  sleep 2
done

if [[ -z "${new_pid}" ]]; then
  echo "RESPAWN UNCONFIRMED: sent (${out}) but session ${id} still reports pid ${old_pid} after 120s"
  exit 1
fi

# A notice that arrives while the new process is still starting is recorded without starting a
# turn, so give it a moment before completing.
sleep 10
echo "RESPAWN COMPLETE: session ${id} now runs $(claude --version) as pid ${new_pid} (was ${old_pid}). Read ${handoff} and resume."
