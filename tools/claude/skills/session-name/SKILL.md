---
name: session-name
description: >-
  Set the display name of this Claude Code background session, the name the agents dashboard
  lists, from inside the session. Keeps a name the user gave it unless told to replace it. Use for
  "name this session X", "rename this session", or when a skill says to name the session. Claude
  Code background sessions only.
---

# session-name — name this background session

Run `python3 -I <skill folder>/name.py <name>`, where the skill folder is this file's folder. It
normalizes the name to kebab case and prints one `SESSION NAME:` line saying what it did. Add
`--force` only when the user asked to replace a name they set themselves.

Outside a Claude Code background session the script does nothing and says so; in an interactive
session, the user names it with `/rename <name>`. Under any other harness, say this skill only
applies to Claude Code, and stop.

The name lives in a record Claude Code doesn't document, so the dashboard can stop showing it after
an update. When the printed line says it was set but the dashboard shows the old name, fix
`name.py`, the one place that writes it.
