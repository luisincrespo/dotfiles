#!/usr/bin/env python3
"""List the background Claude Code sessions by what they're doing, from their own records.

The agents dashboard can file a session under the wrong heading: one waiting on its own background
commands, or even one waiting on the user, has shown as completed. This reads what each session's
job folder records instead (its state, its question, and what's armed to wake it) and groups the
sessions into waiting on you, working, and done.

Usage:
    status.py
"""

import json
import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

JOBS_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")) / "jobs"


@dataclass(frozen=True)
class Session:
    """A background session as its job folder records it."""

    id: str
    """The short ID `claude agents` lists."""
    name: str
    """The session's display name."""
    state: str
    """Its recorded state: "working", "blocked" (waiting on the user), "done" or "stopped"."""
    running_turn: bool
    """Whether a turn is in progress right now."""
    activity: str
    """Its one-line account of what it's doing, or "" when none is recorded."""
    question: str
    """What it asked the user, when it's waiting on them, else ""."""
    background_tasks: int
    """Background commands or monitors still running, whose completion wakes it."""
    wakeup_armed: bool
    """Whether a self-paced wakeup is scheduled."""
    updated_at: datetime | None
    """When its record last changed."""


def group(sessions: list[Session]) -> dict[str, list[Session]]:
    """Sorts sessions by what they need from the user.

    Args:
        sessions: the sessions to sort.

    Returns:
        "Waiting on you", "Working" and "Done" lists, in that order; a stopped session counts as
        done, since nothing will wake it.
    """
    groups: dict[str, list[Session]] = {"Waiting on you": [], "Working": [], "Done": []}
    for s in sessions:
        if s.state == "blocked":
            groups["Waiting on you"].append(s)
        elif s.state == "working":
            groups["Working"].append(s)
        else:
            groups["Done"].append(s)
    return groups


def what_wakes_it(s: Session) -> str:
    """Describes how a working session gets its next turn.

    Args:
        s: a session recorded as working.

    Returns:
        "running a turn", what's armed to wake it, or a warning that nothing is.
    """
    if s.running_turn:
        return "running a turn"
    armed = []
    if s.background_tasks:
        armed.append(f"{s.background_tasks} background task{'s' if s.background_tasks > 1 else ''}")
    if s.wakeup_armed:
        armed.append("a wakeup")
    if armed:
        return "between turns, woken by " + " and ".join(armed)
    return "between turns with nothing armed to wake it: it may have stalled"


def age(when: datetime | None, now: datetime) -> str:
    """Returns how long ago `when` was, e.g. "12m ago", or "" when it's unknown."""
    if when is None:
        return ""
    minutes = int((now - when).total_seconds() // 60)
    if minutes < 60:
        return f"{minutes}m ago"
    if minutes < 48 * 60:
        return f"{minutes // 60}h ago"
    return f"{minutes // (24 * 60)}d ago"


def parse_time(value: str | None) -> datetime | None:
    """Returns the ISO timestamp `value` as a datetime, or None when it's missing or malformed."""
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None
    except ValueError:
        return None


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
        try:
            state = json.loads((JOBS_DIR / row["id"] / "state.json").read_text())
        except (OSError, ValueError):
            continue
        in_flight = state.get("inFlight") or {}
        ask = state.get("needsAsk") or {}
        sessions.append(
            Session(
                id=row["id"],
                name=row.get("name") or row["id"],
                state=state.get("state") or row.get("state") or "",
                running_turn=state.get("tempo") == "active",
                activity=str(state.get("detail") or ""),
                question=str(ask.get("text") or state.get("needs") or ""),
                background_tasks=int(in_flight.get("tasks") or 0),
                wakeup_armed=bool(state.get("selfWake")),
                updated_at=parse_time(state.get("updatedAt")),
            )
        )
    return sessions


def main() -> int:
    """Prints the grouped sessions.

    Returns:
        The exit code: 0, or 1 when the supervisor's list couldn't be read.
    """
    try:
        sessions = read_sessions()
    except (OSError, subprocess.CalledProcessError, ValueError) as err:
        print(f"Couldn't read `claude agents --json`: {err}")
        return 1
    now = datetime.now(timezone.utc)
    for heading, members in group(sessions).items():
        if not members:
            continue
        print(f"{heading} ({len(members)})")
        for s in sorted(members, key=lambda s: s.updated_at or now, reverse=True):
            print(f"  {s.name} ({s.id}) · {age(s.updated_at, now)}")
            if heading == "Waiting on you":
                print(f"    {s.question or s.activity}")
            elif heading == "Working":
                print(f"    {what_wakes_it(s)}" + (f": {s.activity}" if s.activity else ""))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
