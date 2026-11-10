# Cost pass

A check of a diff for work whose cost grows faster than it needs to: queries, requests and
rendering that grow with data or traffic, and model calls whose number or context grows with them.
It applies to any diff, your own or someone else's; the skill that reads it decides what happens to
the findings.

## When it applies

When the diff touches work that grows with data or traffic:

- database queries or ORM calls;
- network or API calls;
- loops over collections that grow with usage;
- request handlers, jobs and queue consumers;
- UI rendering: components, hooks, state.

Or model usage:

- a call to a model: an LLM or embedding API, an SDK client, an agent framework or tool loop;
- a prompt, prompt template, system prompt or tool definition;
- what gets assembled into a model's context: documents, history, retrieved chunks, tool results;
- instructions an agent loads on every run: an `AGENTS.md` or `CLAUDE.md`, a skill, a subagent
  definition.

Touching none of these → it doesn't apply. Say so in one line rather than skipping it silently.
Check only the half the diff touches.

## What to look for

### Data and traffic

- **A query or request inside a loop** (N+1): one call per item where one call for all of them
  would do.
- **Unbounded work**: a fetch, list or scan with no limit or pagination.
- **Repeated work on a hot path**: the same fetch twice, recomputing on every render,
  re-rendering on every keystroke, an effect whose dependencies change every render.
- **A new query no index serves.**
- **A large new dependency** in what the client downloads.

### Model usage

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

**For code calling Anthropic's API, where Claude Code's `claude-api` skill is available:**
`Skill(claude-api)` with `prompt-audit` flags instructions written for older models in prompts,
skills and tool descriptions, a fit when the diff changes one. `cost-optimize` profiles the whole
project's spend and proposes savings one change at a time: suggest it to the user when the pass
finds a pattern worth a wider look, rather than running it per diff.

## The bar for a finding

Each finding names **what grows or multiplies, and roughly what it costs as it does**: "one query
per row, so a 500-row board makes 500 queries", or "one call per row with the full 3k-token brief,
so a 200-row import is 200 calls and 600k input tokens", not "this could be slow" or "this could be
expensive". That makes it a claim the reader can check rather than a hunch. Context counts as cost
too: a prompt that fills the window degrades answers before it fails outright. Micro-optimizations
on cold paths are noise; leave them out.

A fix that trades something away is a judgment call, not a clear fix: a cache (staleness), an index
(a migration, write cost), a smaller model, a truncation or a cached answer (quality). A claim that
a settings change (model, thinking level, tier) leaves the output unchanged needs every part of the
output compared against a rerun on the old settings, free text included: exact fields can match
while a summary or a list of rules quietly thins.

## Why it's a pass of its own

These costs don't show up where code gets checked. A correctness review reads the logic or the
prompt and finds it right; tests on small fixtures, with the model mocked, run fast whatever the
shape. The cost grows with usage and data, and shows up as load, a bill, a rate limit, or answers
that get worse as the context fills. Agent-written code produces it readily: a query or a model
call per item reads naturally when each line is written for the item in hand, and the strongest
model with everything in the prompt is the version that works first.
