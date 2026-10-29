# Design pass

A check of how a change is shaped as a whole: whether its pieces have clear jobs, sit where they
belong, and leave the code easy to change next time. It applies to any diff, your own or someone
else's; the skill that reads it decides what happens to the findings.

## When it applies

When the diff changes the code's structure, not just its lines:

- a new module, service, component family or abstraction;
- a new or changed public API: an exported interface, an endpoint, a shared type, a schema;
- a change that cuts across several modules or layers;
- a change to where state lives, or to how data flows between parts.

Any of these applies, however small the change. A local fix or a small feature inside one existing
unit that touches none of them → it doesn't apply. Say so in one line rather than skipping it
silently.

## What to know first

**What's coming next.** "Easy to extend" only means something for extensions known to be on the
way: the ticket and its acceptance criteria, the project page, the later PRs of a stack, the PR's
own description. Read the ones that exist before judging. When none names what's coming, say so
and skip the extension checks below; the rest of the pass still applies. Guessing at future needs
is how this pass drifts into designing for hypotheticals, and speculative flexibility is a cost,
not a virtue.

**How the codebase already solves the same problem.** Find the closest existing example before
proposing a shape. A design that's better in isolation but unlike everything around it is usually
worse to maintain, since every reader has to learn two ways.

## What to look for

- **Responsibilities.** Each new unit does one job a reader can name. A function or component that
  fetches, transforms, decides and renders is worth a look, not a finding by itself: it's one when
  splitting it would make a named change or test easier.
- **Boundaries.** Logic sits in the layer that owns it, and the change uses another module through
  its interface rather than reaching into its internals.
- **Coupling.** What else has to change when this does: a rule repeated in several places, two
  modules that must be edited together, a type copied instead of shared.
- **Extension, for the known next steps.** Would the next planned change mean editing this code in
  several places, or adding to it in one? The reverse is a finding too, with evidence: an
  abstraction, option or layer that nothing in the current requirements uses and that adds a named
  cost (a case to handle, a layer to read through). Not knowing the plans isn't that evidence.
- **Robustness as a structure.** Failures handled the same way throughout, one owner for each piece
  of state, invariants kept in one place. A single bug is the correctness pass's; a design that makes
  that kind of bug easy to write is this one's.
- **Readability at the level of the change.** Could a reader new to it find where to start and
  follow the flow? Names of modules and types that say what they are, not how they were built.

Duplication and the level of abstraction inside one function are `/simplify`'s in `self-review`
(its reuse and altitude checks); this pass looks across the change.

## The bar for a finding

Each finding names **a concrete change or failure the current shape makes harder, and roughly how
much harder**: "adding the second provider the ticket mentions means editing these three switch
statements", not "this could be cleaner". When the cost can't be named, it's taste: leave it out.

Prefer the smallest change that removes the cost, and say what it would take. A redesign is rarely
the right ask for the change at hand; when it is the right answer, it's usually a follow-up, not a
condition for this one.

## Why it's a pass of its own

The other passes read a change line by line, for bugs, conventions or one kind of cost, and each
line can be fine while the whole is badly shaped. That's also what makes the cost slow to show: a
design problem doesn't fail a test, it makes every later change slower. Agent-written code produces
it readily, solving the task in front of it in the most direct place without asking where the
solution belongs.

## Left to the skill running it

What a finding becomes. They're judgment calls by default, since a change to a design is rarely
clear and bounded: one the user decides, or a question to the author.
