# UI screenshots from Storybook

Loaded by the `pr-*` skills when a created/updated MR/PR changes components that have co-located Storybook stories. Goal: capture each in-scope story as a PNG so reviewers can see the UI change.

Two distinct jobs live here:
- **Capture & deliver** (Steps 1–6) — runs at create time (Phase -2.5). On **GitHub** it captures the PNGs to an easy-to-find local folder and hands off to the user to attach via the GitHub UI (the old assets-branch + raw-URL approach was removed — it didn't render reliably). On **GitLab** it additionally auto-embeds them via the uploads API.
- **Organize & resize** (Step 7) — runs **on request** ("organize the screenshots", "make them smaller/readable") after the user has pasted images into the description. Platform-agnostic; rewrites the existing image refs in the description to a tidy, reviewer-friendly layout with sane widths.

Interactive (permission prompts are acceptable). Never runs inside the polling loop. If any capture step fails, **do not block MR creation** — skip screenshots and batch a one-line note.

## Inputs (from Phase -2)

- `source_branch`, `target`, `repo_id`, `web_url`, platform (`gitlab`/`github`).
- `changed_components`: `*.tsx`/`*.jsx` files in `git diff --name-only origin/<target>..HEAD`, excluding `*.stories.*`, `*.spec.*`, `*.test.*`.

## Step 1 — Resolve in-scope stories

- For each file in `changed_components`, look for a co-located story: same directory, same basename, `*.stories.tsx`/`*.stories.jsx` (e.g. `src/Foo/Foo.tsx` → `src/Foo/Foo.stories.tsx`). Keep the ones that exist → `story_files`.
- If `story_files` is empty → return "no in-scope stories"; caller skips screenshots.
- Group `story_files` by owning package: walk up from each story file to the nearest dir containing a `.storybook/` folder (or a `package.json` whose `nx`/project has a `storybook` target) → `pkg`. Most PRs touch one package; handle multiple by repeating Steps 2–4 per package.

## Step 2 — Serve Storybook for the package

- Discover the Storybook target name from the package's `project.json` / `package.json` `nx` section (commonly `storybook`). If none exists, skip this package (batch: `No Storybook target for <pkg>; cannot auto-screenshot`).
- Start the dev server in the background: `npx nx storybook <pkg>` (run_in_background). Read its stdout for the served URL — a line like `Local: http://localhost:<port>/`. Capture `base = http://localhost:<port>`.
- Wait until ready: poll `<base>/index.json` (via Playwright `browser_navigate` to it, or until the page loads) before proceeding. Give it up to ~120s; on timeout → stop the server and batch `Storybook didn't start for <pkg>`.

## Step 3 — Map story files → story IDs

- Fetch `<base>/index.json` (Storybook 7+). It has `entries: { <id>: { type, title, name, importPath } }`.
- Keep entries where `type == "story"` AND `importPath` resolves to one of `story_files` (compare by path suffix — `importPath` is repo-relative-ish like `./src/Foo/Foo.stories.tsx`).
- Result: `stories = [{ id, title, name }]`. If empty → skip this package.
- Skip stories whose `name`/tags indicate they aren't meant to render standalone (e.g. docs-only `tags` containing `!dev`); keep it simple — default to all matched `type == "story"` entries.

## Step 4 — Screenshot each story (Playwright MCP)

Destination folder (easy for the user to locate): `~/Desktop/pr-screenshots-<source_branch-sanitized>/` (`mkdir -p` it first; sanitize `/` → `-`).

For each `story` in `stories`:
1. `mcp__playwright__browser_navigate` → `<base>/iframe.html?id=<id>&viewMode=story`.
2. `mcp__playwright__browser_wait_for` a short settle (story root rendered / network idle).
3. `mcp__playwright__browser_take_screenshot` → save as `<folder>/<title> - <name>.png` — use the **human story title + name** in the filename (sanitize for the filesystem), not the raw id. This matters: when the user drag-drops the file into GitHub, GitHub uses the filename as the image's alt text, which Step 7 then uses to label/organize.

Keep a list `shots = [{ id, title, name, path }]`.

After all stories: **stop the background Storybook server** (TaskStop the background task / kill the process). Always stop it, success or failure.

## Step 5 — Deliver

### GitHub — capture to folder + hand off (manual UI attach)

GitHub has no reliable API path to embed an image in a PR body, so the user attaches them through the GitHub web UI:

1. Leave the PNGs in `~/Desktop/pr-screenshots-<branch>/` (Step 4).
2. Do **not** embed anything in the PR description and do **not** push any branch.
3. Hand off with a clear, actionable message, e.g.:
   `📸 Captured N screenshot(s) → ~/Desktop/pr-screenshots-<branch>/. Open the PR description on GitHub and drag-drop them in — I'll size and lay them out automatically next time I babysit this PR (Phase 2.6a), or say "organize the screenshots" to do it now.`
4. List the files (and which story each is) so the user knows what they're attaching.

### GitLab — uploads API (auto-embed)

For each shot: `glab api --method POST "projects/<repo_id>/uploads" -F "file=@<path>"`. The response includes a `markdown` field like `![<title> - <name>](/uploads/<hash>/<file>.png)`. Build the marker-wrapped block (Step 6) with these refs — apply the default width (Step 7's sizing) so they don't render full-bleed — and embed it in the description. No cleanup needed (uploads are project-scoped).

## Step 6 — Marker-wrapped `## Screenshots` block (GitLab embed / Step 7 output)

When embedding into the description, **always wrap the block in ownership markers** so it can be refreshed/reorganized later without disturbing human prose:

```
<!-- pr:screenshots:start -->
## Screenshots

### <story title> — <story name>
<sized image ref>
<!-- pr:screenshots:end -->
```

- One subsection per shot, grouped/ordered by component. Use the human story title/name, not the raw id.
- If only one shot, a single image under `## Screenshots` is fine (skip the per-story subheadings).
- Reviewer-facing: shows *what the UI looks like*, nothing about how it was captured.
- (GitHub create-time produces no block — the user attaches manually, then Step 7 builds this block from the pasted images.)

## Step 7 — Organize & resize attached screenshots (on request)

Trigger: **either** the user has pasted/attached images into the MR/PR description and asks to organize them / make them readable / fix their size, **or** `pr-babysit` detects freshly-attached, unsized images automatically (SKILL.md Phase 2.6a) — the steps below are identical either way. GitHub-pasted images default to full content width (huge); this fixes that.

1. **Read the current description**: GitHub `gh pr view <number> --json body --jq .body`; GitLab `glab mr view <number> --output json` (`.description`).
2. **Find image refs** anywhere in the body (inside or outside any existing marker block):
   - Markdown: `![<alt>](<url>)`
   - HTML: `<img ... src="<url>" ...>`
   - GitHub attachment URLs look like `https://github.com/user-attachments/assets/<uuid>` or `https://user-images.githubusercontent.com/...`. **Preserve each URL exactly — never re-host or alter it.**
3. **Label** each image from its alt text / pasted filename (Step 4 named files `<title> - <name>`, so the alt usually carries the story). If a label can't be inferred, keep a neutral caption and ask the user to confirm the mapping.
4. **Resize**: convert every image to an HTML tag with a reviewer-friendly width — `<img src="<url>" width="<W>" alt="<label>">`. Default `W = SCREENSHOT_WIDTH_PX` (400). Use a wider value (~640) only for full-page/wide layouts. If the user specified a size, use it.
5. **Organize**: place them under a `## Screenshots` heading, `###` subheading per component/story. For natural pairs (before/after, light/dark, variants) put them side by side in a simple 2-column HTML table:
   ```
   <table><tr>
     <td><img src="<urlA>" width="<W>" alt="A"><br>A</td>
     <td><img src="<urlB>" width="<W>" alt="B"><br>B</td>
   </tr></table>
   ```
6. **Wrap** the result in the Step 6 ownership markers (replace an existing marker block in place if present; otherwise replace the loose images where they sit, preserving all surrounding human prose).
7. **Update** the description: GitHub `gh pr edit <number> --body "<new body>"`; GitLab `glab mr update <number> --description "<new body>"`. Announce: `🖼️ Organized N screenshot(s) at <W>px.`

## Failure handling (any capture step)

- Stop the background Storybook server if running.
- Do NOT fail MR creation. Skip screenshots and surface a one-line reason (e.g. `Couldn't auto-capture Storybook screenshots: <reason>. Attach manually if useful.`) for the caller to batch.
