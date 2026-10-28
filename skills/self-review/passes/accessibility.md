# Accessibility pass

A check of a diff's frontend changes against WCAG 2.2 AA, read in the source.

## When it applies

When the diff changes frontend files: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`,
`*.html`, or the repo's equivalent templates. None changed → it doesn't apply. Say so in one line
rather than skipping it silently.

## What to look for

WCAG 2.2 AA as it shows in the source. What changed code most often gets wrong:

- **Keyboard**: anything clickable is reachable and operable without a mouse, with a visible focus
  state, and focus goes somewhere sensible when a dialog opens or closes.
- **Names and labels**: an icon-only button has an accessible name; an input has a label.
- **Semantics**: a `div` with an `onClick` where a `button` belongs; ARIA that overrides what the
  native element already says.
- **Dynamic content**: a status or error that appears without being announced.
- **Contrast and motion**: text against its background, and animation that ignores
  `prefers-reduced-motion`.

## Why it's done this way

Deliberately plugin-free: native tools and the user's own skills, until the user vets a dedicated
accessibility-reviewer plugin to swap in.
