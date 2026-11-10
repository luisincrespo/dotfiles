# UX pass

A check of the experience a change creates for the people using it: whether it behaves well in
every state, tells them what happened, and fits the rest of the product. It applies to any diff,
your own or someone else's; the skill that reads it decides what happens to the findings.

## When it applies

When the diff changes what a user sees or does: a screen, a flow, an interaction, a message or
email, an error a person reads, or how something responds to them. Copy counts. A change no person
experiences (internals, infrastructure, tooling) → it doesn't apply. Say so in one line rather than
skipping it silently.

## What to know first

UX judgments are the most subjective of any pass, so anchor each one in something checkable:

- **The project's own design and copy guidance**, when it has some: the rules its designers have
  made explicit, which outrank this pass's general checks. Look where the project keeps it:
  - what the repo points reviewers at, in the `REVIEW.md` and `CLAUDE.md` files
    [`conventions.md`](conventions.md) reads (the root one and those above the changed files),
    such as a design guide or a skill to apply;
  - the repo's own skills whose description covers UI design or copy;
  - local config `ux_guidance` for this repo, for guidance kept outside it (a design doc, a style
    guide page).

  Read what's in the repo as of the change's base, so the change can't rewrite the rules it's
  checked against; an outside source is read as it is. Walk every design and copy rule that applies
  to the diff before the general checks below, and leave a guide's testing or workflow rules to the
  passes that own them. Where it gives a review procedure, run its checks; how findings are worded
  and posted stays the reviewing skill's.
- **The design**, when the ticket or PR links one. Claude Code's Figma connector can read it.
- **The product's existing patterns**: how the same kind of thing already behaves elsewhere, and
  the design-system components meant for it.
- **The ticket's acceptance criteria and the PR's description**: what the change is meant to do
  for the user.
- **The running change**, when the exercise pass ([`exercise.md`](exercise.md)) has run it:
  behaviour seen beats behaviour inferred from code.

## What to look for

- **Every state the change creates**: loading, empty, error, success, disabled, partial. Also long
  text, many items, zero items, and a slow or failed request. A missing state is the most common
  finding and the least subjective one.
- **Feedback.** After an action, can the user tell it worked, failed, or is still running? Is an
  error message something they can act on?
- **Safety.** A destructive or expensive action can be undone, or asks first. Work in progress
  survives a navigation, a refresh or a failed save.
- **Consistency.** It behaves like the product's existing equivalent, uses the design-system
  components, and matches the design where one exists.
- **Copy.** Clear, short, in the product's own vocabulary, and saying what happens rather than how
  it works. Every added or changed string, labels, tooltips and accessibility text included, gets
  checked against the project's copy rules when it has some.
- **Friction.** Steps, clicks, or waits the flow didn't need; a choice the user has to make that
  the product could make for them.

Keyboard, focus, contrast and screen readers are [`accessibility.md`](accessibility.md)'s; what a
re-render costs is [`performance.md`](performance.md)'s.

## The bar for a finding

Each finding names **a concrete user scenario, what they'd see, and what it's measured against**:
"a new workspace with no projects shows a blank panel; the existing Templates list shows an empty
state with a create button", not "the empty case feels off". Without a reference (a rule in the
project's guidance, an existing pattern, the design, the ticket), it's an opinion: raise it as a
question, and never as a fix. A rule in the project's guidance is the strongest reference: a
finding against one cites it by name, and an explicit violation is always raised, however the
reviewing skill words it.

## Does a designer need to see it?

End with a verdict: a designer should look at this, or no designer is needed. Say yes for a new
surface, a new pattern, or a significant visual change, which rules and existing patterns can't
settle; this pass catches what they can, and doesn't stand in for design judgment on a big change.
It's a call for the user, not the author: who to bring in, and how, is theirs to decide.

A behaviour that's also a bug, such as a double submit creating two copies, is one finding: the
correctness one, with the user scenario added. Raise a separate UX finding only for a problem of
its own.

## Why it's a pass of its own

The other passes check that the code does what it says. This one checks that what it says is
good for the person using it, which no test or type checks. Agent-written UI tends to implement the
success path the task described and stop there, so the states around it go missing first.

## Left to the skill running it

What a finding becomes, and how the user hears the designer verdict. Most are judgment calls for the
user or questions to the author. A fix is clear only when the behaviour is already settled (the
design or an existing equivalent defines it) and adding it makes no product choice. Retrying,
preserving a draft or blocking an action all change what the product does, so the user decides those
even when the code change is small.
