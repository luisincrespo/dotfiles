# Observability pass

A check of the signals a change leaves behind for the people who run and grow the product:
analytics events, logs, metrics, traces and error reports. It applies to any diff, your own or
someone else's; the skill that reads it decides what happens to the findings.

## When it applies

When the diff:

- adds a user flow or changes one's steps (a step, choice or way out added or removed), or adds an
  endpoint, background job, queue consumer, or call to another service;
- changes how errors are caught, retried or reported;
- adds, renames, moves or removes an analytics event, log line, metric, span or error report, or
  the code that emits one;
- changes what decides whether signals are sent at all: sampling, filters, exporter or logger
  configuration, or the middleware that instruments requests.

Any of these applies, however small the change. A diff that does none of them → it doesn't apply.
Say so in one line rather than skipping it silently.

## What to know first

- **The repo's existing way, for the signal types in play.** Its tracking helper or analytics
  client, event and property naming, logger and levels, how metrics and spans are named and tagged,
  where errors get reported, and what its redaction rules allow. The closest existing flow, endpoint
  or job shows the convention; it isn't a list of signals every new one must copy.
- **What the change is meant to move.** The ticket's success metric or acceptance criteria, the PR
  description, the experiment or flag it sits behind. They say what someone will ask of this change
  once it ships.
- **What reads a signal whose identity, schema, units, meaning or availability the diff changes.**
  Search the repo for its name (other emitters, tests, typed event schemas) and, where the repo's
  observability or analytics tool has a connector, its monitors, dashboards and saved queries. Code
  that only moved, emitting the same signal, needs no search. Where you can't reach a tool, say its
  readers are unchecked rather than assume there are none.

## What to look for

- **Blind spots.** A new flow that can't answer what the ticket says to measure: no event where it
  starts, finishes or fails. A new or changed user-facing flow that leaves no way to tell whether
  people use it or where they drop off, when the product's neighbouring flows have usage events for
  that. A new endpoint, job or consumer with nothing to diagnose it by, when its neighbours have
  spans, metrics or logs for that purpose. A failure that leaves no trace: an error caught and
  swallowed, a retry that gives up silently, a fallback that hides what it replaced.
- **Lost context.** A changed service or queue boundary that drops the trace context, so a job can't
  be tied to the request that started it. Changed error handling that discards the cause, stack or
  correlation fields an existing way of diagnosing relies on.
- **Broken readers.** A renamed or removed event, metric or log line that a dashboard, alert,
  experiment or another service still reads. A changed property name, type or unit (ms → s) counts
  too: the reader keeps working and reports the wrong thing. So does a sampling or filter change
  that quietly stops a signal reaching them.
- **Signals that lie.** An event sent before the action it reports succeeds ("saved" on click, not
  on the server's answer), counted more often than what it reports (once per retry or re-render when
  readers count it once per action), or attributed to the wrong user or workspace. A success log on a
  path that can still fail.
- **Leaks.** Secrets, tokens and sensitive payloads nobody meant to send (whole request bodies, text
  a user typed, contact details) in a log line, event property, span attribute or error report.
  Personal fields go by the repo's telemetry schema and redaction rules: an identifier it already
  sends on purpose isn't a leak.
- **Unbounded volume.** A value with no ceiling (a user id, a URL, a raw error message) as a metric
  tag, which adds a series per value; a dynamic span name, which breaks trace grouping; a log or
  event per item in a loop that grows with data.
- **Convention breaks that matter.** A name, level or raw client call that differs from the repo's
  scheme in a way that changes what's collected, how it's read, or what's redacted: a direct call
  that skips the helper's redaction, an error logged at debug that alerts never see. A difference
  with no such effect is not a finding.

**When the exercise pass ran the change** ([`exercise.md`](exercise.md)), check that each new or
changed signal came out as the code intends (count, timing and properties, under whatever sampling
or batching the repo uses), in whatever the repo shows locally (a dev event log, the console, the
logger's output). Say which findings you saw at runtime and which you read in code; paths you didn't
run stay unverified.

**Each root cause goes to one pass.** This one owns whether signals are right, delivered and
affordable to collect; [`cost.md`](cost.md) owns what instrumenting costs the application at
runtime, and model calls whose token usage isn't logged or metered;
[`customer-data.md`](customer-data.md) owns where customer data is stored, how long it
stays, whether deletion reaches it, and what leaves the product outside telemetry.

## The bar for a finding

Each finding names **the question nobody could answer, or the reader that breaks, and what it's
measured against**: "nobody could tell how many imports fail at the provider step: the flow emits
started and completed but nothing on failure, and the ticket's success metric is the failure rate",
or "the `import_duration` metric is renamed, and the import-latency monitor still queries the old
name". An unbounded-volume finding names what grows and roughly how much: "one series per workspace,
so tens of thousands". Not "this could use more logging": a signal nobody reads is noise.

Without a reader or a reference (the ticket's metric, a named dashboard or alert, a diagnosis the
team relies on, or for usage the neighbouring flows' events), leave it out. Ask only when one fact
you couldn't check decides it, like whether anything still reads a renamed event. Two exceptions. A
secret or an unintended sensitive payload is a finding on sight. A new user-facing flow with no
usage signal and nothing to measure it against isn't dropped: it becomes a question for the user,
what should be tracked for it, since that's their call or the author's (*Left to the skill running
it*). Most tickets name no metric, so dropping it there leaves product usage unchecked.

## Why it's a pass of its own

Missing and broken signals fail silently, and late. Tests pass and the feature works; the gap shows
weeks later as a dashboard flat at zero after a rename, an incident nobody can diagnose, or an
experiment that can't be read. Every other pass checks what the code does, not what it tells anyone.
Agent-written code leaves the gap readily: the task describes the behaviour, rarely the events, and a
renamed function takes its log line's name with it.

## Left to the skill running it

What a finding becomes. A leak is a clear fix wherever dropping or redacting the field is the fix.
Wiring a missing signal through the repo's existing helper, matching what the neighbouring code
already emits for the same question, usually is too. What to track for a new product question, and
what it's called, is the user's call or the author's, since someone else usually reads it; so is
removing or renaming a signal something may still read.
