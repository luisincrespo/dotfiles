---
name: respawn
description: >-
  Restart the current Claude Code background session onto the installed Claude Code binary
  and pick its long-running work back up in the new process. Writes what a restart drops
  (monitors, a self-paced /loop wakeup, workflows, the task in progress) into a handoff note,
  restarts the session from a background command that outlives the restart (or, where Claude Code
  won't let it restart itself, waits for the user to run claude-catchup), and re-arms everything
  from the note when that command's completion wakes the new process. Use for
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
| Monitors | Stop. The new process gets a `stopped` notice, which starts no turn; it also lists monitors that had already expired (2.1.319) | Re-arm only the ones the note lists |
| Self-paced `/loop` wakeup | Restored (2.1.314, 2.1.318), as its one-shot cron under a new ID. One whose fire time passed while no process ran the session never fires, and the loop stays stopped until a message arrives (2.1.321) | Check `CronList`; reschedule only if it's missing, or the loop fires twice |
| Permission mode | Usually kept: auto stayed auto through the helper (2.1.314 to 2.1.321), and through a manual respawn on 2.1.323. It came back in plan mode after a manual `claude respawn` (2.1.322), and through the helper onto 2.1.325 in a session that had entered and left plan mode earlier (Nov 13). Plan mode blocks the re-arms | Check the mode first. If it's plan, do the read-only checks, then ask the user to switch it back: only they can, and the re-arms wait until then. In a session that has a plan, re-presenting it with ExitPlanMode is the quickest way to ask |
| Workflows | Continue only when relaunched | Relaunch with `resumeFromRunId` |
| The turn in progress | Cut off | Record the next step |

Nothing wakes the new process on its own, so step 2 starts a background command that does.

## Step 0 — Guard

**Started just to run this?** If `/respawn` is this session's first message, the `claude agents`
dashboard started the session to run it: the dashboard isn't a session, so a command typed there
gets a new one. There's nothing here to restart. Say so, and say how to reach the session meant:
open it from the dashboard and send `/respawn` there, or reply `all` to run fleet mode from here,
which never restarts this session. Write no handoff note and offer no restart: one session started
this way (Oct 27) wrote an empty note and asked the user to restart it by hand.

`$CLAUDE_JOB_DIR` names this session's job folder, and its basename is the session's ID. If it's
unset, this isn't a Claude Code background session, and `claude respawn` can't reach it. In an
interactive Claude Code session, say that exiting and running `claude --continue` resumes it on the
installed version; in any other agent, say that respawn only applies to Claude Code. Then stop.

Then check where the session was launched: the trust check uses that directory, which the job's
`state.json` records as `cwd`. The `cwd` in `claude agents --json` follows an `EnterWorktree`, so
it isn't the one (a session launched in home and moved into a repo worktree was still refused, Oct
30). Sent from a background command, `claude respawn` refuses a session in a workspace Claude Code
doesn't trust ("Workspace not trusted", seen Oct 26 for a home-launched session). Read whether it's
trusted from `~/.claude.json`, `projects["<launch dir>"].hasTrustDialogAccepted`, rather than
assuming. Home never is: Claude Code doesn't save trust for it (accepted Nov 12, still false after
the session exited), so don't suggest accepting it. A restart keeps the launch folder, so an
untrusted session takes Step 2's waiting route every time; only one started from a trusted folder
avoids it. To move one for good, write the handoff note, stop it (`claude stop <id>`), and run
`cd <trusted folder> && claude --bg --resume <its sessionId> --fork-session`: that continues the
conversation there as a new session with a new ID, idle until a message tells it to pick up from
the note (2.1.323, Nov 12). Without `--fork-session`, run from a background command, it tries to
continue the old session in home and is refused. Nothing it had running comes along, background
commands included. `claude rm <old id>` clears the old entry and deletes its job folder, note and
`tmp/` scripts with it, so run it only once the copy has picked up and copied what it still needs.

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

**In an untrusted launch folder**, run `bash <skill folder>/respawn.sh --wait` the same way
instead. It restarts nothing: it marks the session as waiting and exits once someone else's restart
has brought up the new process, so its notice still wakes you. End the turn with `needs input: run
claude-catchup in a terminal to restart this session`. That's `python3 -I <skill folder>/catchup.py`
(the dotfiles repo's `zsh/README.md` aliases it): it restarts every waiting session from its launch
folder in the user's terminal, the only place the restart is accepted. A trusted folder elsewhere
doesn't do: run from `~/code`, it failed (Nov 12).

## Step 3 — Pick up in the new process

The helper's completion notice starts a turn. A session restarted while no helper ran for it is
woken by the user's message instead. The helper's last line says how it went:

- **`RESPAWN COMPLETE`**: read the note, then:
  1. Get back into the worktree if you're no longer in it. A session launched outside a repo
     (home, say) restarts there, and `EnterWorktree` `path` then refuses: from a directory that
     isn't a repo, and for the directory you're already in (2.1.318). `cd <worktree>` in Bash
     moves the session's working directory, which is all the pickup needs.
  2. Re-arm each monitor with its recorded arguments.
  3. Reschedule the self-paced wakeup, only if `CronList` no longer shows its one-shot.
  4. Relaunch each workflow.
  5. Run `CronList`, and recreate only the jobs that are missing.
  6. Carry on with the task in progress.

  Delete the note, then report in one line: the version from the notice, and what you re-armed.
  If the user's agents list then shows the session as completed, check `claude agents --json` and
  the job's `state.json` before blaming your messages: after a manual respawn (2.1.323, Nov 12)
  the list said completed while both said `working`, and the classifier's timeline never left it.
- **`RESPAWN FAILED` or `RESPAWN UNCONFIRMED`**: you're still the old process, and everything
  you had running still is. Re-arm nothing. Quote the line, keep the note for a retry, and stop;
  for a "not trusted" refusal, take Step 2's waiting route instead.

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

For moving every background session onto the installed version at once. Run it from any session,
interactive or background. `/respawn --all` typed in the `claude agents` dashboard works too: the
dashboard starts a new session to run it, which leaves itself out like any other. Stop that session
once it has reported.

1. **List the candidates**: the rows of `claude agents --json` with `kind: "background"`, minus this
   session (its `id` is `$CLAUDE_JOB_DIR`'s basename, when that's set). Leave out any the JSON
   reports as idle, which the supervisor moves by itself, and any already on the installed version:
   asking one of those cuts off its work for nothing. Read the version from its process, not its
   job's `state.json`: `cliVersion` there isn't rewritten by a respawn (still 2.1.323 after a
   confirmed restart onto 2.1.325, Nov 13). `lsof -p <pid> -a -d txt -Fn`, with the row's `pid`,
   names the binary (`…/claude/versions/<version>`).
2. **Sort out the ones in an untrusted workspace**, read as in Step 0. They take Step 2's waiting
   route, so the user runs `claude-catchup` once they're ready.
3. **Show the plan and wait for a go-ahead**: each session to be asked, and whether `claude-catchup`
   will be needed. A restart cuts off whatever each session is doing, so don't send unasked.
4. **Ask each one**: `SendMessage` to its name from `ListAgents`, with "Run the respawn skill to
   restart this session onto the installed Claude Code version." Each then runs Steps 0–4 itself,
   so every restart gets its own handoff note and pickup.
5. **Report once the untrusted ones are ready.** `python3 -I <skill folder>/catchup.py --list`
   shows each as `would restart … it wakes itself once back` when its note is written and its
   waiting helper runs; watch for that with a Monitor on an until-loop, for up to 10 minutes. Say
   who was asked. With untrusted ones, end on `needs input: run claude-catchup in a terminal`,
   naming any not ready by then; with none, end on `result:`. This session isn't among them; if it
   needs restarting too, run `/respawn` here afterwards.

## Hard constraints

- **Never restart a background command or subagent** after a respawn. They're still running.
- **Never run `claude respawn` yourself.** Run the helper, which outlives the restart. Running
  `claude respawn` directly from a tool call cuts off that call, and nothing wakes the new process.
