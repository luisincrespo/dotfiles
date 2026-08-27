---
name: voice
description: >-
  Draft and post outward-facing written content in Luis's voice — Slack messages, PR/MR review comments/replies, and PR/MR titles/descriptions.
  Use whenever composing ANY outward-facing written message on Luis's behalf: a Slack DM or
  channel post (review request, heads-up, question), or a comment/reply on a GitHub PR or GitLab
  MR. It loads real past examples and learned tone principles so the first draft already sounds
  like him — casual, first-person, plain prose, not a structured brief or "sophisticated"
  phrasing — always shows the draft for approval before anything is sent, and folds each round of
  his edits back into itself so it keeps improving. Prefer this over free-handing a message in a
  generic assistant voice.
---

# voice — write the way Luis writes

Luis has a specific, consistent communication style, and he reworks drafts that don't match it.
This skill exists so messages sound like him on the first pass, and so every correction makes the
next one better. It applies to:

- **Slack** — messages to teammates or channels (review requests, heads-ups, questions).
- **PR/MR** — review comments, replies to reviewers, and PR/MR titles/descriptions.

The skill's own folder is the base dir for the relative paths below.

## Step 1 — Load the ground truth (always, before drafting)

Read these first:

- `refs/principles.md` — the distilled voice rules.
- `refs/examples-slack.md` — real Slack messages (read for a Slack draft).
- `refs/examples-pr-comments.md` — real PR/MR review comments & replies (read for a comment/reply draft).
- `refs/examples-pr-descriptions.md` — real PR/MR titles & descriptions (read for a title/description draft).

**The examples are the ground truth.** When the abstract rules and a real example disagree, imitate
the closest example.

## Step 2 — Draft in his voice

Write the message following the principles and the closest example(s). Match his tone, length, and
shape — keep it as short as it can be while still clear; don't pad.

## Step 3 — Approve before sending (never skip)

Show the draft and get **explicit approval** before posting or sending. Post only the approved text.

The approval gate is for **a message to a person** (Slack, a reply to a human reviewer). Content drafted in this voice that *isn't* a message to a person — a PR/MR **title or description**, a bounded **ack to a bot reviewer** — is an editable draft the caller posts without a separate approval step. (Draw title/description drafts from `examples-pr-descriptions.md`, comments/replies from `examples-pr-comments.md` — different genres.)

If the caller asks to **generate but not send** — e.g. a review-request ping Luis will send himself — draft it and hand it over; don't send. Send only when he explicitly says to.

- **Slack:** never send unapproved. After approval, send via the native Slack sender/scheduler.
- **PR/MR:** post via `gh api` (GitHub) / `glab api` (GitLab). If the message is a reply addressing a
  reviewer's comment and they've approved the PR, resolve that thread after posting.

## Step 4 — Learn from every iteration (this is the point of the skill)

Whenever Luis edits, rewrites, or rejects a draft — or gives tone feedback ("too formal", "less
robotic", "you don't say it like that") — capture it **before moving on**:

1. Append a new entry to the **genre-matching** `refs/examples-*.md` (`examples-slack.md`, `examples-pr-comments.md`, or `examples-pr-descriptions.md`) with:
   - **Context** — one line on what the message was about.
   - **❌ draft** — the version that missed (verbatim), if there was one.
   - **✅ final** — his approved/edited wording (verbatim — this is the most valuable signal).
   - **What changed** — one line on the tone shift, so the lesson is explicit.
2. If it reveals a new or sharper rule, **show the exact `refs/principles.md` edit first — the line, new or changed — and apply it only once he confirms** (a principle shapes every future draft; prefer refining an existing line over adding one). The step-1 ✅ example append needs no approval — it's his own approved words.

3. **Anonymize as you write it — before it lands on disk.** These files live in a portable dotfiles
   repo that travels between machines and employers, so an entry must never carry confidential
   detail. While appending, replace:
   - **People** → placeholder first names and handles (`Sam`, `Jordan`, `@sam`), never real ones.
   - **Org, repo, product and service names** → `acme-org/web-monorepo` and neutral stand-ins.
   - **Internal hosts, endpoints, scopes, channels** → `example.com` / `#website` style placeholders.
   - **Ticket ids** → `ABC-1234`.
   - **Proprietary identifiers** — table, column, function, codename — → plausible neutral
     equivalents (`refreshBrainTenantId` → `refreshTenantId`, `agent_instance` → `item_instance`).

   Keep **verbatim** everything that carries the voice: sentence shape, openers, hedges, punctuation,
   word choice, the ❌→✅ contrast. Those are the signal; the identifying nouns are not. If a lesson
   is unintelligible without the confidential specifics, state the lesson abstractly rather than
   quoting the message.

Keep the ✅ wording verbatim apart from that anonymization pass. Prune only true duplicates. Do this proactively, mid-session — the
moment he corrects a message is exactly when the lesson is clearest.

**End-of-run reflection (even when he approves with no edits).** At send/approval, pause once: did
this exchange teach anything durable? A no-edit approval that nailed a *hard* tone is worth a ✅
example; a sharper rule earns a `principles.md` line. But if the message just reused a pattern the
corpus already covers well, add nothing — don't pad it. His edits stay the richest signal (above);
this is the safety net for the runs where he approves as-is and there'd otherwise be no reflection.

## Notes

- Complements `pr-review` (owns the review workflow) and the `deliver` pipeline (MR/PR lifecycle): use `voice`
  for the *wording* of any message those produce.
- This skill is the source of truth for his written voice; the `feedback_slack_message_style` memory
  is a lightweight pointer to it.
