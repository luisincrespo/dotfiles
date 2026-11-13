#!/usr/bin/env python3
"""Restart the background Claude Code sessions that are waiting for the user to restart them.

A session launched in a folder Claude Code doesn't trust can't restart itself, so the respawn
skill has it write its handoff note and run `respawn.sh --wait`, which marks it as waiting.
Run from an interactive terminal, this restarts each such session from its launch folder, the
only place `claude respawn` accepts it, and the waiting helper then wakes the new process.

Usage:
    catchup.py          restart every session that's behind and has its handoff note written
    catchup.py --list   only print what it would do (needs no terminal)
"""

import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

JOBS_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")) / "jobs"


@dataclass(frozen=True)
class Session:
    """A background session as its job folder and the supervisor describe it."""

    id: str
    """The short ID `claude agents` lists."""
    name: str
    """The session's display name."""
    version: str
    """The Claude Code version its process runs."""
    launch_dir: str
    """The folder it was launched in, which a restart has to run from."""
    idle: bool
    """Whether the supervisor reports it idle; it moves those onto a new version by itself."""
    has_note: bool
    """Whether its respawn handoff note is written."""
    waiting: bool
    """Whether a `respawn.sh --wait` helper is running for it, so it wakes itself once back."""


@dataclass(frozen=True)
class Plan:
    """What to do with each session, given the installed version."""

    restart: list[Session]
    """Behind, with the note written: ready to restart."""
    not_ready: list[Session]
    """Behind, with no note yet: the session has to run /respawn first."""
    awaiting_pickup: list[Session]
    """Already current but still holding a note and no helper: it needs a message to pick up."""


def plan(sessions: list[Session], installed: str) -> Plan:
    """Sorts the sessions into what to do with each.

    Args:
        sessions: every background session.
        installed: the installed Claude Code version, e.g. "2.1.323".

    Returns:
        The restarts to run, and the sessions to tell the user about.
    """
    behind = [s for s in sessions if s.version != installed and not s.idle]
    return Plan(
        restart=[s for s in behind if s.has_note],
        not_ready=[s for s in behind if not s.has_note],
        awaiting_pickup=[
            s for s in sessions if s.version == installed and s.has_note and not s.waiting
        ],
    )


def pid_alive(pid_file: Path) -> bool:
    """Whether the process whose ID `pid_file` holds is running.

    Args:
        pid_file: a file holding one process ID.

    Returns:
        False when the file is missing, unreadable, or names no running process.
    """
    try:
        os.kill(int(pid_file.read_text().strip()), 0)
    except (OSError, ValueError):
        return False
    return True


def read_sessions() -> list[Session]:
    """Reads every background session the supervisor lists from its job folder.

    Returns:
        One entry per session whose job folder has a readable `state.json`.
    """
    out = subprocess.run(
        ["claude", "agents", "--json"], capture_output=True, text=True, check=True
    ).stdout
    sessions = []
    for row in json.loads(out):
        if row.get("kind") != "background":
            continue
        job = JOBS_DIR / row["id"]
        try:
            state = json.loads((job / "state.json").read_text())
        except (OSError, ValueError):
            continue
        sessions.append(
            Session(
                id=row["id"],
                name=row.get("name") or row["id"],
                version=state.get("cliVersion", ""),
                launch_dir=state.get("cwd", ""),
                idle=row.get("status") == "idle",
                has_note=(job / "tmp" / "respawn-handoff.md").exists(),
                waiting=pid_alive(job / "tmp" / "respawn-waiting"),
            )
        )
    return sessions


def installed_version() -> str:
    """Returns the installed Claude Code version, e.g. "2.1.323"."""
    out = subprocess.run(["claude", "--version"], capture_output=True, text=True, check=True)
    return out.stdout.split()[0]


def label(s: Session) -> str:
    """Returns how to name session `s` to the user: its name, ID and version."""
    return f"{s.name} ({s.id}, {s.version or 'unknown version'})"


def main(argv: list[str]) -> int:
    """Restarts the sessions that are ready, or lists them with `--list`.

    Args:
        argv: the arguments after the script name.

    Returns:
        The exit code: 1 when a restart failed or there's no terminal to run one in.
    """
    list_only = "--list" in argv
    installed = installed_version()
    todo = plan(read_sessions(), installed)

    for s in todo.not_ready:
        print(f"not ready: {label(s)} has no handoff note yet; run /respawn in it first")
    for s in todo.awaiting_pickup:
        print(f'awaiting pickup: {label(s)} is current; message it "pick up from the handoff note"')
    if not todo.restart:
        print(f"Nothing to restart: no session behind {installed} has its handoff note written.")
        return 0
    if list_only:
        for s in todo.restart:
            after = "it wakes itself once back" if s.waiting else "no waiting helper yet"
            print(f"would restart: {label(s)} from {s.launch_dir}; {after}")
        return 0
    if not sys.stdin.isatty():
        print("Run this in an interactive terminal: the restart may need to show a trust prompt.")
        return 1

    failed = 0
    for s in todo.restart:
        print(f"restarting {label(s)} from {s.launch_dir}")
        try:
            result = subprocess.run(["claude", "respawn", s.id], cwd=s.launch_dir)
        except OSError as err:
            print(f"  failed: {err}")
            failed += 1
            continue
        if result.returncode != 0:
            failed += 1
        elif not s.waiting:
            print('  no waiting helper: once it\'s back, message it "pick up from the handoff note"')
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
