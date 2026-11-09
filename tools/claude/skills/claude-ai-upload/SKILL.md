---
name: claude-ai-upload
description: >-
  Upload a copy of a local skill to claude.ai so regular Claude chats (web, desktop, mobile) can
  use it, or refresh a copy uploaded before. Packages the installed skill, private overlay
  included, as the ZIP claude.ai's skill upload takes, uploads it through Claude in Chrome once
  the user approves, and records the upload. Use for "upload voice to claude.ai", "refresh the
  claude.ai copy", or when maintain-dotfiles says an uploaded copy is behind. Claude Code only.
---

# claude-ai-upload — a local skill, in claude.ai chats

A claude.ai chat can't read `~/.claude/skills`. It sees only the skills uploaded to the user's
account, and nothing but claude.ai's own UI can upload one, so a copy goes up by hand and stays
as it was until the next upload. Which skills have a copy, what each is called there and how stale
it may get are in local config `chat_skill_uploads["claude.ai"]`.

The skill's own folder is the base dir for the relative paths below. Under any harness but Claude
Code, say this skill drives Claude in Chrome from Claude Code, and stop.

## Step 1 — Build

`python3 package.py build <skill>`. It copies the installed skill, private files and all, under its
`upload_name` and short `description`, adds `refs/chat-copy.md` (what the copy is and where it saves
corrections), and writes the ZIP under `~/.agents/local/build/claude.ai/`, outside both repos. A
warning about uncommitted changes means the copy won't match the commit it records: land them
first (`maintain-dotfiles`), then build again.

## Step 2 — Ask before uploading

The ZIP holds the private corpus, and uploading puts it in the user's claude.ai account. Every
upload needs their go-ahead: name the skill, the commits it's built from, and whether it replaces a
copy already there.

## Step 3 — Upload through Claude in Chrome

1. In a new tab, open claude.ai's skills settings (Customize › Skills).
2. A copy under the same name already there: replace it in place if the page offers that;
   otherwise remove it first. The first upload hasn't shown which yet; record it here once known.
3. Add the ZIP (+, Create skill, Upload a skill), attaching the path Step 1 printed with the
   file-upload tool.
4. Check that it's listed and turned on, and that it isn't shared with anyone or published to the
   organization's library. One shared by mistake: unshare it, and tell the user.

When one step fails two or three times, stop driving the browser: `open` the skills page, reveal
the ZIP with `open -R <zip>`, tell the user the clicks, and wait for them to say it's done.

## Step 4 — Record it

`python3 package.py mark-uploaded <skill>` once the copy is live, so staleness is measured from it.
Never before: a failed upload recorded as done hides a stale copy.

## Self-educate

The page is the fragile part. When a step behaved differently from what's written here (a path, a
button, whether a copy can be replaced in place, a limit the upload enforced, a folder the chat
couldn't read), fix the step, or `package.py` when it's the ZIP that has to change, and say what
changed.
