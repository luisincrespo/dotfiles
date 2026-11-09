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

1. The file-upload tool takes only files this session can read, and the build folder isn't one:
   copy the ZIP into the session's scratch folder (a background job's `$CLAUDE_JOB_DIR/tmp`), in a
   subfolder only the user can read, and delete that copy once the upload is done.
2. **First upload:** open `https://claude.ai/customize/skills/new/upload` (Customize › Skills,
   + Add, Upload skill) and attach the copy to the page's hidden file input with the file-upload
   tool. Never click the drop zone: it opens the system file picker, which the browser tools
   can't reach. Check the preview's name and description, then Upload.
3. **A refresh:** open the copy from the skills list (Yours), and use ⋯ › Replace, which keeps
   the same skill and adds a version, instead of removing it and uploading again.
4. A security scan runs before the copy can be used, and the list shows it as "In review"
   meanwhile; the page says a minute or two, but the first one took over seven. Don't hold the
   session on it: check back later (`maintain-dotfiles`' next round will do). Once it passes, check
   it's turned on and listed only under Yours ("by you"), with "Publish to org" still on offer,
   which means it isn't published. A passed scan also brings a "Share" button, for sharing with
   named people. Never press either: the copy holds the private corpus.

When one step fails two or three times, stop driving the browser: `open` the skills page, reveal
the ZIP with `open -R <zip>`, tell the user the clicks, and wait for them to say it's done.

## Step 4 — Record it

`python3 package.py mark-uploaded <skill>` once the scan has passed, so staleness is measured from
it. Never before: a failed upload recorded as done hides a stale copy.

## Self-educate

The page is the fragile part. When a step behaved differently from what's written here (a path, a
button, whether a copy can be replaced in place, a limit the upload enforced, a folder the chat
couldn't read), fix the step, or `package.py` when it's the ZIP that has to change, and say what
changed.
