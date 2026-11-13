# Official docs pass

A check of a diff's code against the official documentation for the version of each language,
framework or tool it's written in or for, for any of them that has no stack pass of its own.

## When it applies

When the diff changes code in or for a specific language, framework, library or tool that no other
file in this folder covers: a GraphQL schema or operations, SQL migrations, Terraform, a CI
workflow, a test framework's config, a library's API used in a new way. The repo's main language
counts only where the change relies on something its version decides (new syntax, a changed
default, a deprecated API). Everything the diff touches already covered by a stack pass of its own,
or no tool-specific code at all → it doesn't apply.

## What to know first

- **The version in use, and what sits on top.** Read it from the manifest, lockfile or toolchain
  file, and note anything layered over the tool that changes its rules: for GraphQL, the server
  library, a federation spec, the codegen setup; for SQL, the database and its version.
- **The tool's own docs for that version, not memory.** Its reference or spec, and the
  best-practices or migration guide it publishes, where it has one. Read only the pages that bear
  on what the diff uses. Prefer the project's own docs; reach for anything else only where they're
  silent, and say which source a finding rests on. Where the docs are versioned, read that
  version's page, not the latest.
- **What the repo's linter, type checker or schema check already reports**, so it isn't repeated.

## What to look for

- **APIs the version deprecated or removed**, or a feature the version doesn't have yet.
- **Behaviour the docs describe differently from what the code assumes**: a default, an error or
  null case, ordering, transactions, caching, what happens on retry.
- **Patterns the docs advise against, for the reason they give**, and practices they recommend
  that the change departs from where it matters. For GraphQL, nullability, pagination, errors and
  evolving a schema without breaking clients are where its own guidance says the most; check what
  it actually says for the case at hand before raising one.
- **Changes the docs call breaking for whoever consumes them**: other services, clients, saved
  queries, existing data.

## The bar for a finding

Each finding links the doc page it rests on, for the repo's version, says what that page says, and
what goes wrong in this code because of it. A pattern that only looks dated or unusual to you, with
no page saying so, isn't one. Where the repo's own guidance differs from the docs, the repo wins:
say so in one line rather than raising it.

## Why it's a pass of its own

A review from memory blends versions: a rule from an older release, an API that changed, advice
that was never official. The docs for the version in use settle it, and they say what the code
can't: which defaults apply, what a change breaks for consumers. One pass covers every tool, so a
new one needs no file of its own. A tool gets its own stack pass, as React has, only when there's
more to say than its docs: patterns worth calling out every time, or lint-shaped gaps the docs
leave.

## Left to the skill running it

What a finding becomes. A deprecated call with a documented replacement is usually a clear fix; a
change the docs call breaking for consumers, and anything resting on a source other than the
tool's own docs, is a question for the user or the author.
