# Personal conventions

> **Personal layer.** These are the user's own code conventions: the recurring ones not written in
> the global rules or a repo's `CLAUDE.md`. The shared convention pass
> ([`conventions.md`](conventions.md)) reads this file. To use your own, put your version at this
> same path in your private companion repo (`install.sh` links it in place of this one), or edit
> it in your fork. Self-educate steps add to it when you correct a convention a review missed.

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
