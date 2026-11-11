---
name: eod
description: >-
  End the day for this Claude Code session, or every background session: reach a good stopping
  point, stop everything it has running (self-paced loops, crons, monitors, background tasks,
  workflows), and leave a summary of where things stand, then wait until the user says they're
  back, when it re-arms what it stopped and picks up from its next step. Use for "eod", "let's
  pause for the day", "stop at a good point and summarize", "I'm back". --all fans out to every
  background session; --back resumes. Claude Code only.
---

# eod — stop for the day, pick up tomorrow

End of day means **everything stops until the user says they're back**: no overnight watches, no
loops waking up, no questions piling up. What makes that cheap is a note written at the stop, so
coming back is one message instead of re-explaining the day.

The skill's own folder is the base dir for the relative paths below. Under any harness but Claude
Code, say this skill drives Claude Code's loop, cron and messaging tools, and stop.

## Args

- `--all`: fleet mode, see `## Fleet mode`. Without it, only this session stops.
- `--back`: the user is back; see `## Coming back`. With `--all`, every session resumes.

## Stopping

1. **Reach a good stopping point.** Finish the step you're on, and start nothing new. A step that
   can't finish soon stops at its last clean point (nothing half-edited), and the note says exactly
   where. Don't commit, push or post anything just to stop: what isn't ready stays local.
2. **Write the resume note** to `$CLAUDE_JOB_DIR/tmp/eod-resume.md` (a session with no job folder
   keeps it in its summary instead): each thing step 3 stops, with what re-arms it exactly (a
   self-paced loop's `prompt`, a monitor's `command`, `description` and `timeout_ms`, a cron's
   schedule and prompt, a workflow's run id and script path), and the next step.
3. **Stop everything this session has running:** a pending self-paced wakeup (`ScheduleWakeup`
   with `stop: true`), its cron jobs (`CronList`, then `CronDelete`), monitors, background commands
   and workflows (`TaskList`, then `TaskStop`), and background subagents. A dev server started
   outside the session's tasks (a detached stack, say) is the user's: leave it, and mention it.
4. **Summarize, as your last message**, short enough to read in the agents dashboard:
   - what got done today;
   - what's in flight: each PR or branch, its state, and what it's waiting on;
   - what's waiting on the user, each in a line;
   - the next step tomorrow;
   - what was stopped, in a line.

   End with a `needs input:` line saying what brings it back ("say you're back to resume"), never
   `result:`. The agents list reads that last line, and `result:` shows the session as done, so a
   paused one drops out of sight.

Then wait. Until the user says they're back, a task notification or a message from another
session changes nothing: note it for the morning, re-arm nothing, and reply in a line at most.

## Coming back

On "I'm back", "resume", or `/eod --back`: read the note, re-arm each thing it lists with its
recorded arguments, mention anything that arrived overnight, then carry on from the next step.
Delete the note, and report in one line what you re-armed.

## Fleet mode

With `--all`, from any session or typed in the `claude agents` dashboard (which starts a new
session to run it):

1. List the background sessions from `ListAgents`, leaving out this one.
2. Send each one, with `SendMessage`, "Run the eod skill: stop at a good point, stop everything
   until I'm back, and leave your summary." With `--back`: "Run the eod skill with --back: I'm
   back."
3. Then run it on this session too, unless the dashboard started it just for this.
4. Report who was asked, in a line. Their summaries are in their own sessions.
