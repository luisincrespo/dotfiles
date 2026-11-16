#!/usr/bin/env python3
"""Set the display name of the Claude Code background session that runs this script.

Claude Code has no command a session can run to rename itself: `/rename` is the user's, and
`--name` only applies at launch. The name the agents dashboard shows lives in the job's
`state.json`, as `name` with a `nameSource`; writing both there renames the session, and the name
holds once `nameSource` is "user" (seen on 2.1.323 and 2.1.325). That record isn't a documented
interface, so this is the one place to fix when its format changes.

A name the user gave the session is kept unless `--force` is passed.

Usage:
    name.py <name> [--force]
"""

import json
import os
import re
import sys
import tempfile
from pathlib import Path

MAX_LENGTH = 60


def slug(name: str) -> str:
    """Turns a free-form name into the kebab-case form session names use.

    Args:
        name: the name to normalize, e.g. "Brand: template picker".

    Returns:
        Lowercase words joined by hyphens, at most MAX_LENGTH characters, e.g.
        "brand-template-picker".
    """
    words = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return words[:MAX_LENGTH].rstrip("-")


def rename(state_path: Path, name: str, force: bool) -> str:
    """Writes `name` into a job's state file, unless the user already named the session.

    Args:
        state_path: the job's `state.json`.
        name: the new display name, already normalized.
        force: whether to replace a name the user set.

    Returns:
        One line saying what happened.
    """
    state = json.loads(state_path.read_text())
    current = state.get("name") or ""
    if current == name:
        return f"SESSION NAME: already {name}"
    if state.get("nameSource") == "user" and current and not force:
        return f"SESSION NAME: kept {current}, which the user set"
    state["name"] = name
    state["nameSource"] = "user"
    fd, tmp = tempfile.mkstemp(dir=state_path.parent)
    with os.fdopen(fd, "w") as f:
        json.dump(state, f)
    os.replace(tmp, state_path)
    return f"SESSION NAME: set to {name} (was {current or 'unnamed'})"


def main(argv: list[str]) -> int:
    """Renames this session, or says why it can't.

    Args:
        argv: the arguments after the script name.

    Returns:
        The exit code: 0 when the name is set or kept, 1 when it can't be set.
    """
    args = [a for a in argv if a != "--force"]
    if len(args) != 1 or not slug(args[0]):
        print("usage: name.py <name> [--force]")
        return 1
    job_dir = os.environ.get("CLAUDE_JOB_DIR")
    if not job_dir:
        print("SESSION NAME: not a Claude Code background session, so nothing to set")
        return 0
    try:
        print(rename(Path(job_dir) / "state.json", slug(args[0]), "--force" in argv))
    except (OSError, ValueError) as err:
        print(f"SESSION NAME: couldn't set it: {err}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
