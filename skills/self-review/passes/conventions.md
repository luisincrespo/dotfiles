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
- **New files and directories**: check what they mean for `CODEOWNERS` (see the repo's
  `CLAUDE.md`).

## The user's

The global rules and feedback memories are already loaded; follow them rather than restating them.
The user's own recurring conventions, written nowhere else, are in
[`personal-conventions.md`](personal-conventions.md): read it and check the diff against it too.

## Left to the skill running it

What a miss becomes (a fix, or a comment), and how much weight a nit gets.
