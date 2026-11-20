# Voice principles

> **Personal layer.** This is the repo owner's written voice, the default the shared `voice` skill
> writes in. To write in yours, put your own version at this same path in your private companion
> repo (`install.sh` links it in place of this one), or edit it in your fork. Starting nearly empty
> is fine: `voice` adds a principle each time you correct a draft.

The user's written voice, distilled. When one of these conflicts with a real example in
`examples-*.md`, follow the example.

## Tone
- **Casual and first-person.** Lead with your own lived experience — "While testing X e2e I ran
  into…", "Yeah, it's handled — I pass…" — not "We're building…" or a formal statement. When the
  work is mostly theirs, AI help included, it's "I" ("I'll look into", "on my list", "ideas I've
  been thinking about", "behaviors I've been collecting", and "I plan to … in ABC-1234" for a ticket
  they created); keep "we" for what involves the rest of the team,
  like when the team starts an experiment, or what a shared design is and how it evolves ("which
  ones we'd store", "we should keep evolving the shape"), even when they're the one building it.
- **Plain words, not jargon.** Prefer everyday phrasing over precise-but-dense terms:
  - "success and error handler" not "fulfilled and rejected handler"
  - "throws" not "rejects synchronously"
  - "get a log" not "a breadcrumb"
  - "cuts an emoji in half" not "cut by code point" or "a lone surrogate": say what the reader
    would see, not the encoding or spec term behind it
  - drop filler like "best-effort", "leverage", "utilize", "furthermore", "moreover".
- **Low ceremony, friendly, direct.** A wave-emoji opener ("Hey folks 👋") is a Slack thing. A
  tracker-ticket comment or PR/MR comment takes no greeting at all: lead with the @-mention and go
  straight into the finding.
- **Casual Spanish punctuates like English.** No opening `¡` or `¿`, only the closing mark
  ("te amo!", "todo bien?"): the inverted marks read formal in a casual message.
- **Openers they actually use:** "Yeah, …", "Hey folks 👋", "Heads up …". A review request takes no
  greeting: in a broad team or project channel it opens straight with `Here's a PR to <what>` (or a
  bare `PR to <what>`), where `<what>` first says what kind of change it is ("PR to fix brand
  template tracking", not straight into the mechanism; no "the" before a general noun like
  tracking), and a PR small by file count (a few files; 13 isn't, even if mostly tests) says so
  first ("Small PR to …"), then a sentence or two on what it does for the user (for a UX change,
  what they see, in the words someone in the channel would use: leave command and code names, UI
  component labels, version tags and vendor names to the PR; for several PRs too, never a walk
  through every case, which the PRs explain). For a rename or restructure of something the channel
  already knows, say that's mostly what it is and what it makes clearer, rather than retelling what
  the feature does: the retelling undersells the PR and repeats what readers have. Something not in
  scope yet goes in a thread reply under the request ("Heads up: this first step only …"). When
  part of the work already shipped, say
  in a word which part ("the form itself (UI component) is already merged"). Members of the project
  pinged in that project's own channel need no reason: the channel is the reason, so the last line
  is just "@Sam @Jordan could you please help review this one when you have some time?" (with the
  reviewer already requested on the PR itself, the post just shares it, with no ping). Anywhere
  else, the requested reviewer is pinged with a reason, never a bare `cc @<reviewer>`: a thread
  reply under it ("@Sam added you as reviewer here", then why them), or a last line of the message
  itself when the reason is short ("cc @Sam the comments you had already left there are now
  addressed!"). Someone stepping in for an absent reviewer is doing a favor: ask for their help with
  the reason first ("since Sam is out today, could you help out by reviewing this one?", not "help
  me review", which sounds like a joint review), and leave that you added them as a trailing fact. A
  request in another team's channel, for their approval on code they own, opens "Would appreciate a
  review from someone on <team> for <link>", says in a sentence what the PR does and why it needs
  them, and links the original request for the rest. A request opens with someone's @-mention only
  when the message is to them alone. A request posted as a reply under a related PR's request opens
  by tying itself to it ("Related to this one: here's the PR that…") and points back at what that
  one introduced ("that form"); a bare "Here's another PR for…" reads as a new, unrelated ask. A new
  post following up on a meeting opens by tying itself to it ("Following up on the team weekly,
  where X came up"), since the readers were there; a reply in the thread where the chat was arranged
  goes straight to the point, with no "following up on our chat". When someone tags them into a
  thread, they open by thanking that person by name ("Thanks for looping me in, Sam!") before their
  point. When one reviewer has been getting a run of their PRs, the ping says it's part of the
  series ("(yep, one more 😬)"). A light apology ("sorry for flooding you with PRs lately 😅") is a
  one-time thing: once they've made it, later requests don't repeat it.
- **Words they don't use.** Keep this list growing as they correct them.
  - **"gotcha" as a NOUN** — not for a tricky/catch part of something (avoid "the gotcha is…", "one gotcha…"); say "the catch is" / "the tricky part is" or just state the thing plainly. As an *interjection* of understanding ("Oh, gotcha!") they *can* use it, but rarely — they'd usually go with "Got it!" / "Oh, got it!".
  - **"shout"** — never "shout if you'd rather…". Use **"let me know"** or something similar.
  - **"bolt" / "bolt on"** — not for tacking something onto a change. Say it plainly: "not part of this change", "not something to add here".
  - **"nah"** — reads impolite in an outward message, even when the answer really is no. Open with a plain "I don't think we need it" / "I don't think so" instead.
  - **"agreed on X" / "Agreed, …"** as a way to agree in conversation. They say "yeah, I agree that…" instead.
  - **"critical path"**, or any framing of a deferral as keeping something off one. Say what you
    want done ("get this in soon so we can launch as planned") and why today's approach still holds.
  - **"looking likely / unlikely"** ("launching today isn't looking likely") reads stiff to them.
    Say it first person: "I don't think we'll be able to launch today."
  - **Someone else's jargon** ("bench set") picked up from the thread or from the drafter: they
    wouldn't have used it on their own, so say the plain thing instead.

## Punctuation
- **No em dashes (`—`).** The user rarely uses them, so an em dash is a dead giveaway the text was
  generated when they paste it. Use a period, comma, parentheses, or a reworded sentence instead. This
  applies to every message (Slack and PR/MR). Avoid the spaced-hyphen substitute too; just split the
  sentence or use a comma.

## Shape
- **Prose, not structure.** No markdown headers, bullet lists, or numbered question lists inside the
  message itself. Short paragraphs. The exception is a set of **options, alternatives, or distinct
  changes** the reader has to compare or act on, introduced by a short framing sentence: one bullet
  each with a bolded lead-in, written as full conversational sentences, beats a paragraph they have
  to parse serially to find the one they care about. A sentence about one bullet goes in that
  bullet: after the list, it reads as following from the last one. That exception is for a new
  post: a follow-up in a thread they're already in stays casual prose, links inline, with no
  opener, not even "Heads up". A reply to one message in a busy thread opens by quoting it (a `>`
  line with the part being answered), so it reads against that message.
- **Inline code for identifiers.** Backtick function/var/file/flag names: `createItemInstance`,
  `next()`, `pnpm-lock.yaml`.
- **Technical context woven in, not exhaustive.** Enough to understand the problem or the answer —
  the key finding, the error — not a full change-map.
- **End a Slack ask with a single open-ended question**, not a checklist of asks; say what you're
  trying to understand. A second ask smuggled into the same sentence ("who can do X, and what about
  Y?") is still two asks — pick the one that unblocks you and let the rest come up in the replies. A
  new ask posted under your own still-unanswered questions says so ("one more, separate from the two
  questions above"), so it isn't read as part of them. Sharing a view in a peer's design thread
  isn't an ask: they close it with an open "Let me know what you think!", not a yes/no like "Does
  that sound right to you?". Nor is a proposal posted to a channel for alignment, when they ping the
  owners themselves: it ends with a cc line and a casual why ("cc @Sam @Jordan just want to make
  sure we're aligned here before I start with any of these changes"), not a closing question.
- **Name things the way the reader sees them, and don't leave a reference for them to reconstruct.**
  Internal words (`unfiled`, `chip`, "the PRs"), shorthand that made sense while writing ("merge
  bottom up", `A → this → C`) and labels for the work coined in the session ("a design pass") read
  as noise, or as wrong, to someone meeting it once: say what changed instead. A design's own step
  or component names count too: in a team-wide post, say what each step does in plain words and
  leave the names to the linked doc, or readers read too much into them; a name that says what it
  does on its own ("normalize" into our own format) is fine to use. When a shared proposal is
  renaming a step, name neither the old nor the new one in a review comment; say what it does
  ("anything that reads X as ready"), so the point survives the rename. An implicit comparison has
  the same problem: "before or after" attaches to the nearest thing in the sentence, not the one you
  meant, so name the baseline. So does an "it" after a sentence naming two things ("could we turn it
  on" after two flags): name the one you mean, and where it goes. A relative date ("yesterday's
  run") is a baseline only to you, who knows what changed in between: say "before this change". And
  watch for names that collide with their context, like "the main list" in a message that also
  discusses `main`; a proposed component whose name blurs with a generic word (the *item skill*
  among skills) is bolded each time it appears. When a message points at something (a PR, a stack, a
  comment, a doc), link it inline; link a stack through its first PR. An example from your own work
  (a test run, a sample you tried) is said as one, with where it came from, after the general point
  it shows; a bare name reads as something the reader should already know. A number measured once is
  that run's result ("in my test run, the board took almost 5 minutes"), never stated as how long
  something takes in general. An exact tally from your own digging ("57 runs so far") reads
  machine-written in a casual message: say the pattern ("every run since last night") and leave the
  count out. Size a gain instead of praising it: "about 2x faster end to end in a few of my own
  runs", not "a lot faster".
- **Vary the openers across a batch of replies.** Several replies to one reviewer that all open
  with "Yeah, good catch." read robotic side by side. Mix them ("Good catch!", "That's a good
  point,", "Fair,", "You're right,"), and let one or two open straight with the fix ("Fixed in
  `abc1234`.").
- **Short.** As brief as it can be while still clear. They trim; so should you. But short means
  cutting noise, not compressing feeling — on sincere or personal content they write full, warm
  sentences and say the thing outright; clipped fragments and aphorisms are a tic, not their voice.
  A design check-in lists the decisions people need to react to, one line each; reasoning,
  conditions and file lists wait for the replies. A channel heads-up about shipped changes gives
  each change one line with its headline number; methods and benchmark details wait for replies.
  A side capability mentioned along the way gets the claim alone ("It'd also be easy to A/B test
  providers if we ever want to."); how it would work waits for someone to ask. An update that comes
  with screenshots names what changed in a phrase ("pushed some tweaks for X and Y, see screenshots
  attached") and lets the screenshots carry the detail, including whose change was whose.

## Substance
- **A proposal asks only what it leaves open.** No question it already answers, and none about how
  a mechanism works when the proposal replaces that mechanism.
- **Answer the point they made.** Before replying to someone's reason, pin down what it refers to.
  If it could mean two things, ask the user which one rather than picking one and arguing it.
  Answer only what they asked. When they question a design choice, give your view in a clause of why
  and say you're open to changing it, rather than walking them through the mechanism. That holds
  even when you'd rather keep your way: say you lean towards it, and that you'd change it if they
  feel strongly. Close the door only when the alternative would make the system behave wrongly.
  When they're about to change it themselves and you agree, the reply is the go-ahead alone, in one
  line ("Yeah I think we should downgrade it to `edit`"), with no account of how it got that way.
- **Compare versions on what actually changed.** In "what's different from the old one", claim only
  what the old one couldn't do (check it), and lead with the gains they care about, such as the
  architecture or better output, rather than a list of visible features. Output they expect to be
  better but hasn't measured is said as their own subjective take, with why, and that they haven't
  measured it; don't turn measuring into something the team should do.
- **Lead with the general purpose, not the occasion.** When a change serves more than the pilot,
  deadline or request that prompted it, open with that broader purpose and give the immediate
  driver one clause near the end. Leading with the occasion undersells the work. Work that would
  serve any vendor or option is framed for all of them, as something they might do one day ("if
  we ever decide to …, whether that's VendorB, another third party or something in-house"), not
  for the one the thread is weighing.
- **Frame the ask honestly.** Don't downplay a real decision/clarification as a "sanity check" or a
  "quick question" — if you're asking someone to decide something, say that.
- **A fix that's yours isn't an ask.** When a finding's fix lands in your own work, post a heads-up:
  what you'll change, where, the merge order, and "so nothing's needed here". An ask that holds only
  in one merge order opens with that condition ("If my PR lands first, could we…?") and closes with
  who covers the other ("If this one lands first, I'll take care of it on my side").
- **Leave "optional" to the user.** Don't close a suggestion with "not blocking" or "fine as a
  follow-up" by default. Add that framing only when they call the point optional.
- **Don't rank your own findings.** Skip "the big one", "the critical thing",
  "most importantly". State each finding plainly and let the reader weigh it.
- **Concrete over abstract.** When explaining how something works, name the actual things (the agents,
  the tiers, the features) instead of describing them in the abstract — specifics give the reader
  clarity. "a Student gets Summarizer, Humanizer, AI Detector" beats "a set that varies by persona".
- **Cut the implicit.** Don't state what the reader already assumes ("whatever we decide is what I'll
  build") — it's noise. Trust them to infer it.
- **Ask what you need to know, not why you're asking.** Keep your own constraints and reasoning out of
  an outward ask — a policy you're trying not to touch, a change you're keeping small, a deadline
  you're working to, a ticket that reached you with no description or repro. Give only the context
  the reader needs to answer; the rationale, the urgency, and the state the work arrived in are
  yours, not theirs. That includes evidence for the question: on someone's own doc or design, don't
  walk them through their own content to justify asking. Name the gap in one clause, then ask.
- **When your digging says the premise is wrong, say so and name the disposition.** State the finding
  and what you'll do ("so unless X, I'll mark this one done"), and let the correction come back.
  Handing the reader a menu of possible causes ("was it A, B, or something else?") makes them redo
  the work you just did. When an author defers a fix on that premise, say plainly it isn't true and
  isn't a blocker, and accept the deferral only on a reason that still holds ("if it's more that …,
  I'm fine leaving it there"), never on the false one.
- **Don't assert specifics you haven't verified.** Naming a concrete thing (a vendor, a URL, a
  system) reads as knowledge of their setup. Either verify it first or describe the shape generically.
  The same goes for your own work: what isn't built yet is what you plan to do ("we plan to
  create"), not what you do. And for the product: an argument for robustness doesn't claim a
  precondition won't hold ("we can't count on X"); it says the system shouldn't depend on it even
  when it does. And for people: an absence you've only inferred is "I think Sam is out", not a
  fact. And for someone else's PR: say what it does and what shows it works ("moves X to https to
  get around it, and its own run passed"), not that it's the fix. Nudging a ready PR, ask what's
  holding back the merge, not when it'll land.
- **When you decline on cost, put the position first and the concession last.** A closing "if it
  needed real work I'd agree" names the condition under which the reviewer would be right, which is
  worth saying; an opening concession only cushions. Open by showing you weighed the alternatives
  when the decline turns on *judgment* instead, where the reviewer needs to see they were considered
  at all.
- **Don't overstate certainty — argue the cost, not the absolute.** "Impossible", "can't", "never"
  invite a counterexample, and one usually exists: a constant someone can raise, a flag, a server
  change. Say what it would actually take ("the server caps `first` at 50, so a full-window refetch
  needs a server change and a ~500 KB response") and let the cost carry the argument. It persuades
  better and it survives the reviewer who knows the exception. A hunch about someone's design is the
  same: open with "I'm wondering if…" and close by asking what case they have in mind, not with
  "I'm not sure there's a case" and a proposal to drop it.
- **Don't put feelings or commitments in their mouth.** Warmth invented on their behalf is still
  invention. If they haven't said they feel a thing, or that they'll do a thing, don't write it for
  them — they cut it, and it reads as someone else's voice when they don't. That includes a courtesy
  close like "happy to do it sooner as its own PR": after arguing a change isn't worth it yet, end
  on the position and when you'd revisit it, not an offer to do the work anyway. Work they keep
  deferring (evals, say) isn't promised as a specific follow-up: point at whoever's tickets own it,
  say what you're tracking, and that it isn't happening yet. A later revisit is their own plan said
  concretely ("I might revisit it soon: after these changes I plan to …"), never a vague "it's on
  our minds". And expertise: keep the reasons to ones they could explain if the reader follows up.
  Analysis of someone else's system that only the drafter worked out gets cut, even when it's right.
- **Relay a teammate's concern as the question, not as their verdict.** Asking someone else (a
  designer, another team) to weigh in on a point a reviewer raised, put the tradeoff to them
  neutrally and leave the reviewer out of it: "Jordan wasn't sure that's OK" casts Jordan as the one
  who approves the change.
- **Stay out of their domain.** In someone else's area of ownership, don't assign who does the next
  piece of work, and don't tell them how their own system behaves — even when you've verified it and
  you're right. State your part, ask your question, let them own theirs. If the gap you spotted
  matters, it surfaces on their side or comes up when they ask. When your design touches their work,
  suggest where it could fit and ask where they see it ("I think your X could be …, but I'm curious
  to see where you think it fits"), instead of placing it for them. That holds while the placement
  is theirs to choose; when the shape they have can't serve something already decided, be suggestive
  instead: open with the concrete alternative as a "Could …?" ask, say why the current one won't
  work, then what it needs. A heads-up to the owner about work near theirs says how the two relate
  ("I know you have plans to look more closely at X; these are just quick wins in the meantime") and
  stops: don't invite them to report a conflict you don't expect, and don't describe how they'll
  approach their part (what you'd guess it is, how big a change), since that's theirs to decide.
  With a vendor whose system fails, ask why, with your guess as a yes/no ("Is it because …?"), and
  what you'd like it to tell you; don't ask them to decide how our product should handle it. Asking
  a vendor for something new, name the call and what you'd like it to say, and leave the design to
  them: no sketched fields or values, and no "so we can …".
- **A heads-up about shipped work opens with what it was for**, then the result: "I wanted to cut
  down how long X takes, so I merged …", before "it came out about 2x faster".
- **When two things relate, say precisely how.** "overlap but aren't the same" beats "you get both".
  Agreeing with part of a proposal, narrow the agreement to that part ("reusing what those flows
  already use to extract"), and when the point is where something should live, name the boundary
  ("keep X inside Y, instead of spreading into Z"), not a mechanism ("plug them into Y") that could
  read as agreeing to the rest.
- **When the author has answered and the outcome is settled, reply with the acknowledgement only.**
  No clarifying what your original comment meant, no restating the mechanism already sitting in the
  thread, no explaining their own code back to them. Their answer plus a plain "yeah, agreed" is the
  whole reply; anything past that is re-reviewing a thread that's done. A one-line answer from them
  earns a one-line reply from you.
- **When you're recording an outcome that was already settled in person, give the cause and stop.**
  The reader was in the conversation, so anything propping the cause up is noise: corroborating
  evidence (why the same thing worked in the other view, why a refresh fixes it) argues a point
  nobody is disputing, and reassurance about the real environments (why it can't happen in staging
  or prod) answers a worry they never raised about machinery they already know. What does still
  belong is anything that changed in the code since they looked, because they have to re-read it. A
  thread post recording an offline decision for those who weren't there opens with "For the record,"
  names who was in the conversation, the main people first, lists the decisions one bullet each, and
  closes by tagging them: "@Sam @Jordan let me know if I got anything wrong."
- **Keep housekeeping out of a reply about a finding.** A review thread answers the thing that
  thread raised. Work done in the same sitting (a rebase, a lockfile regen, an unrelated CI failure
  clearing, your own local test results) is not part of the answer and belongs in a direct report instead.
- **Keep process state out of a PR/MR description.** Where a change sits in *your* workflow (waiting
  on someone, why it's a draft, what you'll do if the answer is no) is conversation, not description.
  The description says what the change is and why; the humans handle the rest in Slack.
- **Before a broadcast, check it hasn't already been said.** When drafting a heads-up for a broad
  channel, search Slack for an existing announcement on the topic first. If there is one, reply in
  its thread with only what it doesn't cover, instead of a new post that repeats it.

## Hard rules
- **Never send/post without explicit approval.**
- **In Slack, write the full URL, never a bare `#123`** — it doesn't autolink and `#` collides with
  channel autocomplete. A link that *is* the message (a review request) goes on its own line; a link
  that merely supports the ask goes inline in parentheses ("(here's the corresponding PR: <url>)").
- **@-mention people by their Slack handle**, not their GitHub/GitLab username.
- **A term the reader may not know gets its link on the term itself** (the word as link text), not a
  bare URL beside it.
- **Slack MR/PR review-request format** (their standing convention):
  ```
  @<handle> MR to <brief description of the changes>.

  <link>

  [optional trailing line: extra context, may or may not cc a person/team]
  ```
  (Say "PR" on GitHub, "MR" on GitLab.) When you're addressing a handle, it **leads the descriptor
  line inline**, not on its own line, and the descriptor takes a trailing period. The descriptor
  itself stays context-free (no CI/status/caveats). Anything worth adding goes on a line **after the
  link**, which may or may not cc someone. For a **multi-PR stack**, open with "Here's a PR stack for
  <what>", one numbered line per PR in merge order, as `1. <purpose> — <link>` (mark draft/stacked inline; when the PRs form several separate stacks, say so in the intro, "It's three separate stacks off main", and mark each line with its base and what it waits on to deploy, "off main, once the first is deployed"), and a sentence or two
  of context is fine here (unlike the single-PR form). **No JIRA ticket** in team Slack. **Broadcasting to a broad channel** — nobody addressed — drops the `@handle` and the greeting, and opens the ask to anyone: "PR to <what it does>. … Anyone's welcome to take a look!". Whoever picks it up is volunteering, so saying how big it is does the work the handle would have. When you've already added reviewers, the message still goes to the channel: in a broad channel they're pinged in a thread reply under it, one clause of why for each (see the openers above); in the project's own channel they're pinged at the end of the message itself, no reason needed ("@Sam @Jordan could you please help review this one when you have some time?", or a bare "cc @Sam @Jordan"). Invite anyone else to look only when the work suits an open review; when it needs specific people or a team, name them instead.
- **The `@handle PR to …` shape is for a COLD ask.** When you're following up with someone you were
  just talking to, or who just reviewed something adjacent, write it as conversation instead: open
  with where this sits relative to what they already know ("Here's one last PR related to <the work
  they know>"), put the link inline, say what you hit in your own words ("Ran into an edge case
  where…"), and close with "Mind taking a look?". Cut the comparison to the previous PR, the reason
  a bot could not approve it, and any second thing it also fixes. All true, none of it load-bearing
  for a yes.
- **A follow-up to a reviewer who already did a pass isn't a review request.** Thank them for the
  pass, say what you did with their feedback, and leave the ask open ("Let me know if there's
  anything else you'd like addressed"). A related PR can go in the same message, with what it is
  and, if it's a draft, why. Posted as an update in a thread with several reviewers, it ends on the
  update, with no closing ask.
- **In a dedicated review channel, drop the explicit "please review" ask** — the channel's purpose
  makes it implicit. (This is the one place the usual "end with a single ask" doesn't apply.)
