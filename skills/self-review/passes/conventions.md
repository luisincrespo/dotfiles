# Convention sweep

A check that a diff honors the repo's conventions and the user's, by reading them rather than
re-deriving them.

## The repo's

- **`CLAUDE.md`**, the root one and the nearest one to each changed file: versioning and changeset
  rules, styling and design-system preferences, barrel-file and file-layout rules. Read them instead
  of assuming another project's.
- **`REVIEW.md`**, the root one plus any in a directory that is an ancestor of a changed file.
  Claude Code auto-loads `CLAUDE.md` but **not** `REVIEW.md`, so fetch it explicitly; none is
  normal. A repo that keeps one encodes what a general reviewer can't infer: PR classes to skip,
  a mandated review, dedupe or post order, change types needing human sign-off, and recurring
  domain gotchas worth flagging on sight. A more specific file beats the root one for the paths it
  covers.

## The user's

The global rules and feedback memories are already loaded; follow them rather than restating them.
The recurring ones written nowhere else:

- **Doc comments**: every export and interface member has one, in the language's own doc-comment
  format (`/** */` in TypeScript, not a `//` line), even when a `//` comment's text is already
  good. Each is **shorter than the thing it documents**: coverage is the rule, length is the failure
  mode. Keep only what a reader can't recover from the code, such as cross-file coupling, a platform
  quirk, or a caveat about what the function does not check.
- **Strict equality**: `!== undefined`, not `!= null`.
- **No non-null assertions**, and no `void`-operator fire-and-forget.
- **Interfaces and props**: required members before optional ones, and `readonly` props.
- **Naming**: components are nouns, not verb phrases, and use the design-system and domain
  vocabulary already in the codebase (prefer the UI kit's existing noun). Watch for a component
  name colliding with a domain type name.
- **New components** in a package with Storybook (`.storybook/` or existing `*.stories.*`) are
  expected to have a story, and **must** when the repo's `CLAUDE.md` requires one.
- **New files and directories**: check what they mean for `CODEOWNERS` (see the repo's
  `CLAUDE.md`).

## Left to the skill running it

What a miss becomes (a fix, or a comment), and how much weight a nit gets.
