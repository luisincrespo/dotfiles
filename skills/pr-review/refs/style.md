# Review style

> **Personal layer.** This is the user's own review style: what's worth a comment, where comments
> go, how they read, and how drafts are shown to them. `pr-review` reads it before every round;
> its steps are the shared machinery, and this file is the taste. To review your own way, put your
> version at this same path in your private companion repo (`install.sh` links it in place of this
> one), or edit it in your fork. `pr-review`'s self-educate step keeps it current from your
> corrections. When this file and the skill disagree on taste, this file wins.

## What's worth a comment

- Organize findings by theme ("hooks", "naming", "misc nits") rather than one flat list. Tag each
  with conviction (recommend / borderline / nit) and whether it's blocking (usually nothing is).
- Give a recommendation, not a survey of options.
- Cut a finding that asks one path to behave differently from what the surface already does on
  every other path (one entry point skipping a save the rest make): the special case costs more
  than the drift.
- A value copied into code from config the code doesn't read (an infra setting, another service's
  limit) is a recommend, not a nit, when someone acts on it: it goes stale silently the day the
  source changes.
- A rare edge case with a cheap, correct fix still earns a comment: say it's rare and keep it to one
  ask, so it doesn't become a debate with another reviewer.
- A test comment earns its place when it closes a gap that would let the bug back in, not when it
  polishes an existing assertion's style or a test's name. Those get cut.
- JSDoc-coverage and import-style nits are low-priority: they tend to get cut, so keep them last and
  brief.

## Where comments go

**Inline comments only.** No review body, no top-level summary comment, unless a point genuinely
can't attach to a specific line (rare). Cross-cutting points (e.g. a naming scheme) get anchored on
the most relevant single declaration line.

## How drafts are shown to the user

When the user hasn't read the code, open with two plain sentences on what the PR does, and note
under each draft, without identifiers, what breaks and for whom (walked through as one concrete case
when it takes a sequence of events), so they can judge it and answer the author. Pitch those drafts
at the depth they can defend in a reply: the ask, one reason, "I think" where you're inferring, and
fix code held back until the author asks.

## How comments read

**Concise, human voice.** Short words, no AI-thoroughness, no "why this approach vs that" essays.
Phrase as suggestions or questions ("Could we…", "Small thing:", "Worth picking one…"). It should
sound like the user typed it, which the `voice` skill's ground truth is for.

- Lead with the ask, then the problem as someone using it would see it; keep the mechanism (which
  component or query causes it) to a clause, or the comment reads as being about whatever you
  named first. Stick to problem and fix against the current code, and leave out the PR's own
  history ("the first commit did X") and behavior that's working as intended. Give it the ask and
  one reason. What you checked to be sure of it (an exception filter, another PR, how many call
  sites do the same) goes in your notes to the user, not the comment: a stack of cross-references
  reads as an audit report, not as something the user wrote. After drafting, do a trim pass: cut
  hedges, qualifiers, and idiom doing rhetorical rather than factual work ("that lands", "fair
  enough", "something smaller underneath", "reads as incidental"). Open an acknowledgement with the
  plainest words available ("Got it, makes sense.") and go straight to the point.
- No shorthands or jargon. Write the word out ("Is this intended?", not "Q:"), and name the actual
  file or element instead of an acronym or a vague pointer: a permalink to the code you mean, not
  "like the table does".
- For a doc-comment suggestion (a `//` line documenting an export or interface member), the reason
  is that code documentation follows the language's own doc-comment format, so keep the suggestion
  even when the text is already good. Not IDE hover (most code is written through agents), and not
  "to match the convention".
- For non-trivial suggestions, include a **code example as a proper fenced block** (not inline),
  using the PR's own variable/type names so it drops in. When a finding hinges on two
  conditions/values that must agree, show both literally side by side: naming them abstractly ("the
  predicate", "the same condition") makes the reader reconstruct them.
- Every comment must **stand alone**. Don't say "per the note above": inline comments have no
  reliable order, so **link** to the other comment via its `#discussion_r<id>` URL instead. It also
  means no vocabulary you coined while working the problem out: name the real symbols ("the
  `OpenCoordinatorAgent` and `MessageAgent` commands"), not a shorthand the author has never seen
  ("the two halves of the compound"). When two of your comments offer alternative fixes for the same
  problem, say in one of them which you'd pick and link the other ("This is the one I'd go with: …
  so the X from [this comment] wouldn't be needed"). A conditional like "if we go this way" leaves
  them reading as two conflicting asks.
- It's fine to ask a genuine question ("If there's always one per message, can you note that in the
  JSDoc?") rather than assert a change. When a finding rests on an assumption about intent or
  coupling you haven't confirmed, default to a question, not an assertion ("Is this meant to…? If
  so…"). That includes removing something that looks unused: ask "Do we need X?" before "Could we
  drop X?".
- On a product or UX concern, assume the author may already have design input: ask to revisit and
  say which option the user prefers, rather than asking them to loop someone in. When accepting a
  decision, credit its reasoning, not who proposed it.

## Examples of the target style

> Could we pull this dismissal logic into a hook, e.g. `useVisibleQuestionnaire(message)` that
> returns the card or `null`? It'd be easier to test on its own. Keep it a plain derivation (not
> a `useEffect`) since it's just deciding visibility. Something like:
> ```ts
> function useVisibleQuestionnaire(message: AssistantResponse): AskUserQuestions | null { … }
> ```

> These `useCallback`s aren't buying anything right now. `onSubmit` comes in as a new inline
> arrow each render, the hook returns a fresh object every render, and the card isn't memoized —
> so nothing downstream stays stable anyway. I'd just drop them to keep it simple.
