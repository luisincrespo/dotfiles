---
name: respawn
description: >-
  Restart the current Claude Code background session onto the installed Claude Code binary
  and pick its long-running work back up in the new process. Writes what a restart drops
  (monitors, a self-paced /loop wakeup, workflows, the task in progress) into a handoff note,
  restarts the session from a background command that outlives the restart, and re-arms
  everything from the note when that command's completion wakes the new process. Use for
  "respawn", "restart this session", "get this session onto the latest version". Background
  sessions only; with --all, asks every other background session to respawn itself.
---

# respawn — restart this session without dropping its watches

A background session runs the Claude Code version it started on. The supervisor moves idle
sessions onto a new version by itself, but a session with a monitor or a pending `/loop` wakeup is
never idle, so it stays behind until it's restarted. `claude respawn <id>` restarts it with its
conversation intact, but not everything the session had running.

The skill's own folder is the base dir for the relative paths below.

## Args

- `--all`: fleet mode. Go to `## Fleet mode` instead of Step 0: it asks the other background
  sessions to respawn themselves and never restarts the one it runs in. Without it, Steps 0–4
  restart only this session.

## What a respawn keeps

| Running work | Across a respawn | So |
|---|---|---|
| Background Bash commands | Keep running; their completion notices reach the new process | Leave them. Restarting one runs it twice |
| Background subagents | Carry over | Leave them |
| `CronCreate` jobs, fixed-interval `/loop` | Restored | Check `CronList` after; recreate only a missing one |
| Monitors | Stop. The new process gets a `stopped` notice, which starts no turn | Re-arm |
| Self-paced `/loop` wakeup | Lost | Reschedule |
| Workflows | Continue only when relaunched | Relaunch with `resumeFromRunId` |
| The turn in progress | Cut off | Record the next step |

Nothing wakes the new process on its own, so step 2 starts a background command that does.

## Step 0 — Guard

`$CLAUDE_JOB_DIR` names this session's job folder, and its basename is the session's ID. If it's
unset, this isn't a Claude Code background session, and `claude respawn` can't reach it. In an
interactive Claude Code session, say that exiting and running `claude --continue` resumes it on the
installed version; in any other agent, say that respawn only applies to Claude Code. Then stop.

Then check where the session runs: its `cwd` in `claude agents --json`. Sent from a background
command, `claude respawn` refuses a session in a workspace Claude Code doesn't trust, and the home
directory is one ("Workspace not trusted", seen Oct 26). For such a session, skip Step 2: write the
handoff note, then tell the user to run `claude respawn <id>` from an interactive terminal in that
directory and, once it's back, to message the session "pick up from the handoff note". A restart
started that way has no helper to wake it, so that message is what starts Step 3.

## Step 1 — Write the handoff note

Write `$CLAUDE_JOB_DIR/tmp/respawn-handoff.md` from your own context. You armed this work, so you
know it. It goes in `tmp/` because Claude Code refuses writes elsewhere in the job folder, which
holds the files it restarts the session from. List:

- **Monitors still armed**: every Monitor call with no later stop or expiry notice. Give each one's
  exact `command`, `description` and `timeout_ms`.
- **A pending self-paced wakeup**: its `prompt` and the delay you'd give it now.
- **Running workflows**: run ID and script path.
- **Background commands and subagents**: for reference, marked "carry over — don't restart".
- **Cron jobs**: from `CronList`, to check against after the restart.
- **The task in progress**: what's done and the exact next step, or "none".
- **The worktree you're in**, if you entered one.

## Step 2 — Start the restart and end the turn

Run `bash <skill folder>/respawn.sh` with `run_in_background: true`. It waits 10 seconds,
restarts the session, waits for the new process to come up, and only then exits.

End the turn at once with one line, e.g. `Respawning in ~10s; I'll pick up from the handoff note.`
Any tool call still running when the restart lands is cut off.

## Step 3 — Pick up in the new process

The helper's completion notice starts a turn, or, after a manual respawn, the user's message
does. The helper's last line says how it went:

- **`RESPAWN COMPLETE`**: read the note, then:
  1. Re-enter the worktree with `EnterWorktree` `path` if you're no longer in it.
  2. Re-arm each monitor with its recorded arguments.
  3. Reschedule the self-paced wakeup.
  4. Relaunch each workflow.
  5. Run `CronList`, and recreate only the jobs that are missing.
  6. Carry on with the task in progress.

  Delete the note, then report in one line: the version from the notice, and what you re-armed.
- **`RESPAWN FAILED` or `RESPAWN UNCONFIRMED`**: you're still the old process, and everything
  you had running still is. Re-arm nothing. Quote the line, keep the note for a retry, and stop;
  for a "not trusted" refusal, give the user the manual route from Step 0.

## Step 4 — Capture learnings (self-educate)

After the pickup, or a failed respawn, ask whether the run showed something this skill didn't
know. Never invent one: "nothing to capture" is the usual answer, said in a line.

What recurs here:
- **A table row that proved wrong**: something meant to carry over didn't, or the reverse. Fix the
  row and note the Claude Code version you saw it on, since a later release can change it again.
- **Running work the note missed**: state the restart dropped that Step 1 doesn't list. Add it,
  with how to restore it.
- **A recovery that failed**: a re-arm that errored, or couldn't be done the way Step 3 says
  (re-entering a worktree, say). Record what worked instead.
- **A helper result that misled**: a `RESPAWN COMPLETE` with something still missing, or a
  `RESPAWN UNCONFIRMED` for a session that had in fact restarted.

Route by portability: Claude Code's restart behaviour → this skill; anything specific to one
machine → `~/.agents/local/`; a one-off → a memory. **Apply the edit yourself and say what you
changed**, unless it's consequential (global rule 13); prefer fixing a row or line to adding one.

## Fleet mode

For moving every background session onto the installed version at once. Run it from a session,
interactive or background, not from the `claude agents` dashboard: the dashboard isn't a session,
and `/respawn` typed there starts a new one, which then respawns itself.

1. **List the candidates**: the rows of `claude agents --json` with `kind: "background"`, minus this
   session (its `id` is `$CLAUDE_JOB_DIR`'s basename, when that's set). Leave out any the JSON
   reports as idle: the supervisor moves those by itself.
2. **Sort out the ones in an untrusted workspace**: a `cwd` in the home directory, as in Step 0.
   They still need asking, so they write their handoff note, but their restart is yours to run.
3. **Show the plan and wait for a go-ahead**: each session to be asked, and for the untrusted
   ones, the `claude respawn <id>` to run from an interactive terminal in its `cwd` once it has
   written its note. A restart cuts off whatever each session is doing, so don't send unasked.
4. **Ask each one**: `SendMessage` to its name from `ListAgents`, with "Run the respawn skill to
   restart this session onto the installed Claude Code version." Each then runs Steps 0–4 itself,
   so every restart gets its own handoff note and pickup.
5. **Report**: who was asked, and the manual commands still to run. This session isn't among them;
   if it needs restarting too, run `/respawn` here afterwards.

## Hard constraints

- **Never restart a background command or subagent** after a respawn. They're still running.
- **Never run `claude respawn` yourself.** Run the helper, which outlives the restart. Running
  `claude respawn` directly from a tool call cuts off that call, and nothing wakes the new process.
