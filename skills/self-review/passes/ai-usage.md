# AI usage pass

A check of a diff for model usage whose cost or context grows faster than it needs to: model
calls, what goes into their context, and the instructions agents load.

## When it applies

When the diff touches any of:

- a call to a model: an LLM or embedding API, an SDK client, an agent framework or tool loop;
- a prompt, prompt template, system prompt or tool definition;
- what gets assembled into a model's context: documents, history, retrieved chunks, tool results;
- instructions an agent loads on every run: an `AGENTS.md` or `CLAUDE.md`, a skill, a subagent
  definition.

Touching none of these → it doesn't apply. Say so in one line rather than skipping it silently.

## What to look for

- **Calls that multiply.** One model call per item where one batched call would do; parallel
  agents or subagents fanned out with no bound; retries with no cap or backoff; the same call
  re-run on every request or render when the same input gives the same answer and could be cached.
- **More model than the task needs.** The top tier doing classification, extraction or routing; a
  reasoning or thinking budget far beyond the task. A hard-coded model id where the repo has a
  config or registry for them ages out as models ship.
- **Unbounded context.** Whole files, documents or histories passed in with no truncation,
  summary or retrieval; a conversation history that grows without a cap; a tool returning raw
  results (a large JSON payload, a full page) when the model needs a few fields; images sent at
  full resolution.
- **Prompt-cache misses.** Where the provider caches prompt prefixes, a large stable part (system
  prompt, tool definitions, reference documents) placed after content that varies, reordered per
  request, or carrying a timestamp or id, so the cache never hits.
- **Output with no limit.** No `max_tokens`, or one far above what the call needs; asking for
  verbose output and parsing a small part of it.
- **Agent loops with no budget**: no cap on turns or tool calls, or a loop that re-reads the same
  large context every turn.
- **Instructions paid on every run.** Text an agent loads on every run costs its tokens and
  attention on every call: a rule stated twice, a second example where one makes the point, detail
  that belongs in a file loaded only when it's needed.
- **Usage nobody can see.** A new call path whose token usage isn't logged or metered, so its cost
  shows up first on the bill.

Check claims about a provider's pricing, limits or caching against its docs, not memory: they change
(see [`claims.md`](claims.md)).

## The bar for a finding

Each finding names **what multiplies, and roughly what it costs**: "one call per row with the full
3k-token brief, so a 200-row import is 200 calls and 600k input tokens", not "this could be
expensive". Context counts as cost too: a prompt that fills the window degrades answers before it
fails outright.

A fix that trades quality for cost, like a smaller model, a truncation or a cached answer, is a
judgment call, not a clear fix.

## Why it's a pass of its own

Model cost doesn't show up where code gets checked. Tests mock the model, so a call per item runs
as fast as one call; a correctness review reads the prompt and finds it right; and the cost grows
with usage and data, showing up as a bill, a rate limit, or answers that get worse as the context
fills. Agent-written code makes it likely: it reaches for the strongest model and passes everything
it has into the prompt, because that's the version that works first.
