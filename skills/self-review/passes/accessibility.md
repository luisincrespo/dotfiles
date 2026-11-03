# Accessibility pass

A check of a diff's frontend changes against WCAG 2.2 AA, with the WAI-ARIA Authoring Practices as
the guide for custom widgets, read in the source.

## When it applies

When the diff changes frontend files: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`,
`*.html`, or the repo's equivalent templates. None changed → it doesn't apply. Say so in one line
rather than skipping it silently.

## What to check against

The specs, not memory. Read the page a finding rests on before raising it:

- [Understanding WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/): what each success
  criterion requires, at which level, and how it's met. This is the normative bar.
- [ARIA Authoring Practices patterns](https://www.w3.org/WAI/ARIA/apg/patterns/): the roles,
  states and keyboard interaction a custom widget needs (dialog, menu, tabs, combobox, listbox and
  the rest), and its [read-me-first](https://www.w3.org/WAI/ARIA/apg/practices/read-me-first/) on
  why no ARIA beats bad ARIA. It's guidance, not a standard: a different but working design isn't a
  WCAG failure.
- [ARIA in HTML](https://www.w3.org/TR/html-aria/): which roles and attributes a native element
  already carries, and which it may take.
- [MDN's ARIA reference](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA) for a
  single role or attribute.

Where the repo has a design system, its component for the job usually handles focus and roles
already: check what it renders before flagging, and prefer it over rebuilding the pattern by hand.

## What to look for

WCAG 2.2 AA as it shows in the source. What changed code most often gets wrong:

- **Keyboard**: anything clickable is reachable and operable without a mouse, with a visible focus
  state that the page's own sticky headers or overlays don't entirely cover (2.4.11). Focus goes
  somewhere sensible when a dialog opens or closes. A [modal](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)
  has a name, keeps focus inside, closes on Escape and makes the page behind it inert; a composite
  widget (tabs, menu, listbox) moves between items with the arrow keys, so not every item is a Tab
  stop.
- **Pointer and touch**: targets at least 24×24 CSS pixels, or spaced as 2.5.8 allows; anything done
  by dragging also works with a single tap or click (2.5.7).
- **Names and labels**: an image has a text alternative that says what it's for, or is marked
  decorative (1.1.1); an icon-only button has an accessible name; an input has a label, and a
  visible label is part of its accessible name (2.5.3).
- **Semantics**: a `div` with an `onClick` where a `button` belongs; ARIA that contradicts or
  duplicates what the native element already says, per ARIA in HTML.
- **Messages and errors**: a status message that appears without moving focus is announced to
  assistive technology (4.1.3); an input error is identified in text, not by colour alone (3.3.1).
- **Forms and sign-in**: signing in doesn't rest on memorising or transcribing (3.3.8): blocking
  paste or password managers fails it; information already given in the same process isn't asked
  for again (3.3.7).
- **Contrast and layout**: text against its background, and icons, borders and focus rings against
  theirs (1.4.11); content that reflows at narrow widths without scrolling both ways (1.4.10);
  content shown on hover or focus that can be dismissed and hovered (1.4.13).
- **Motion**: anything that moves, blinks or auto-updates for more than five seconds can be paused
  (2.2.2), and nothing flashes more than three times a second (2.3.1). Honouring
  `prefers-reduced-motion` for interaction animation is AAA (2.3.3): worth suggesting, not a
  failure at AA.

## The bar for a finding

Each finding names the element, who it blocks (keyboard, screen reader, touch, low vision or
cognitive load) and how, and the success criterion it fails, with its level (2.4.7 Focus Visible,
AA). Citing an Authoring Practices pattern supports a finding but doesn't prove a WCAG failure by
itself, and what the code renders in the browser is the evidence, so check the design system's
composition before calling something missing. Without a criterion, it's a suggestion or a
question, not a fix.

## Why it's done this way

Deliberately plugin-free: native tools and the user's own skills, until the user vets a dedicated
accessibility-reviewer plugin to swap in.
