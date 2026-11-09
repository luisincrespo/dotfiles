#!/usr/bin/env python3
"""Package an installed skill as the ZIP claude.ai's skill upload takes, and record uploads.

Usage:
  package.py build <skill>          build the ZIP; print its path and a summary
  package.py mark-uploaded <skill>  record that the last build is now live on claude.ai

The copy is built from ~/.claude/skills/<skill>, so the private overlay comes with it. Its name,
description and refresh window come from local config chat_skill_uploads["claude.ai"]. The ZIP
goes under ~/.agents/local/build/, outside both repos, since it holds private files.
"""

import datetime
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import zipfile

SURFACE = "claude.ai"
HOME = pathlib.Path.home()
LOCAL = HOME / ".agents" / "local"
CONFIG = LOCAL / "config.json"
STATE = LOCAL / "state" / "chat-uploads.json"
BUILD = LOCAL / "build" / SURFACE
SKILLS = HOME / ".claude" / "skills"
# claude.ai's Help Center gives 200 characters for a description, the platform docs 1,024:
# stay under the stricter one.
MAX_DESCRIPTION = 200
MAX_NAME = 64


def die(message):
    """Print an error and exit.

    @param message: what went wrong and what to do about it
    @returns: never
    """
    print(f"package.py: {message}", file=sys.stderr)
    sys.exit(1)


def load_json(path, default):
    """Read a JSON file, or return a default when it doesn't exist.

    @param path: the file to read
    @param default: the value to return for a missing file
    @returns: the parsed JSON, or the default
    """
    if not path.exists():
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, value):
    """Write a value as indented JSON, creating parent directories.

    @param path: the file to write
    @param value: the value to serialize
    @returns: None
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(value, f, indent=2, ensure_ascii=False)
        f.write("\n")


def git(repo, *args):
    """Run git in a repo and return its trimmed output.

    @param repo: the repository directory
    @param args: the git arguments
    @returns: stdout without the trailing newline, or None when git fails
    """
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def repos(skill):
    """Find the public repo the skill is installed from, and its private companion.

    @param skill: the skill's installed name
    @returns: a dict of role ("public", "private") to repo root, for the repos that exist
    """
    found = {}
    public = git((SKILLS / skill / "SKILL.md").resolve().parent, "rev-parse", "--show-toplevel")
    if public:
        found["public"] = pathlib.Path(public)
        companion = os.environ.get("DOTFILES_PRIVATE") or str(found["public"].parent / "dotfiles-private")
        if (pathlib.Path(companion) / ".git").exists():
            found["private"] = pathlib.Path(companion)
    return found


def commits(skill):
    """Record each repo's HEAD, and warn when the skill has uncommitted changes there.

    @param skill: the skill's installed name
    @returns: a dict of role to HEAD commit
    """
    heads = {}
    for role, root in repos(skill).items():
        heads[role] = git(root, "rev-parse", "HEAD")
        if git(root, "status", "--porcelain", "--", f"skills/{skill}"):
            print(f"warning: {skill} has uncommitted changes in the {role} repo; "
                  "the copy includes them, but the recorded commit doesn't", file=sys.stderr)
    return heads


def rewrite_frontmatter(text, name, description):
    """Replace a SKILL.md's name and description, keeping any other frontmatter keys.

    @param text: the SKILL.md contents
    @param name: the copy's name
    @param description: the copy's description
    @returns: the SKILL.md contents with the new frontmatter
    """
    lines = text.split("\n")
    if lines[0] != "---" or "---" not in lines[1:]:
        die("SKILL.md has no frontmatter")
    end = lines.index("---", 1)
    kept, skipping = [], False
    for line in lines[1:end]:
        if line.startswith(("name:", "description:")):
            skipping = True
            continue
        # A folded value runs until the next top-level key, blank lines between paragraphs included.
        if skipping and (line.startswith((" ", "\t")) or not line.strip()):
            continue
        skipping = False
        kept.append(line)
    # A JSON string is a valid YAML double-quoted scalar.
    head = ["---", f"name: {name}", f"description: {json.dumps(description, ensure_ascii=False)}", *kept, "---"]
    return "\n".join(head + lines[end + 1:])


def chat_copy_note(skill, config, heads, today):
    """Write the note that tells a chat copy what it is and where corrections go.

    @param skill: the skill's installed name
    @param config: the whole local config
    @param heads: the commits the copy is built from
    @param today: the build date
    @returns: the note's markdown
    """
    built_from = ", ".join(f"{sha[:7]} ({role})" for role, sha in heads.items() if sha) or "unknown commits"
    out = [
        "# This is a chat copy",
        "",
        f"This copy of the `{skill}` skill was uploaded to {SURFACE} by hand on {today}, built from "
        f"{built_from}. It can read its own files but can't write to them, or to the repos they come "
        "from, so it can't record a correction itself.",
        "",
        "## Where corrections go",
        "",
    ]
    inbox = config.get(f"{skill}_inbox")
    if inbox:
        out.append(f"Save each correction to {inbox.get('app', 'the configured app')}: {inbox.get('url', '')}")
        # Every other key (an id the connector needs, say) is passed through as is.
        extra = {k: v for k, v in inbox.items() if k not in ("app", "url", "layout", "notes")}
        if extra:
            out += [""] + [f"- {key}: {value}" for key, value in extra.items()]
        if inbox.get("layout"):
            out += ["", inbox["layout"]]
        if inbox.get("notes"):
            out += [""] + [f"- {note}" for note in inbox["notes"]]
        out += ["", "Tell the user it's saved only once the save succeeded. If it fails, fall back to the block below."]
    out += [
        "",
        "Without a destination, or when saving fails, end your reply with the entry and any principle "
        "change as one block the user can paste into a coding session, which records it.",
        "",
    ]
    return "\n".join(out)


def build(skill):
    """Build the ZIP for one skill and record it as packaged.

    @param skill: the skill's installed name
    @returns: None
    """
    config = load_json(CONFIG, {})
    conf = config.get("chat_skill_uploads", {}).get(SURFACE, {}).get("skills", {}).get(skill)
    if not conf:
        die(f'no chat_skill_uploads["{SURFACE}"].skills.{skill} entry in {CONFIG}')
    name = conf.get("upload_name") or f"{skill}-chat"
    description = conf.get("description", "")
    if not description or len(description) > MAX_DESCRIPTION:
        die(f"set a description of at most {MAX_DESCRIPTION} characters for {skill} (it's {len(description)})")
    # The name becomes a folder this script deletes and rebuilds, so it has to be one plain path
    # component: a skill name's lowercase letters, digits and hyphens, nothing that leaves BUILD.
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name) or len(name) > MAX_NAME:
        die(f"upload_name must be lowercase letters, digits and hyphens, at most {MAX_NAME} characters")
    source = SKILLS / skill
    if not (source / "SKILL.md").exists():
        die(f"{source} isn't an installed skill")

    heads = commits(skill)
    today = datetime.date.today().isoformat()
    BUILD.mkdir(parents=True, exist_ok=True)
    os.chmod(BUILD, 0o700)
    folder = BUILD / name
    shutil.rmtree(folder, ignore_errors=True)
    # copytree follows symlinks by default, which is what pulls in the private overlay.
    shutil.copytree(source, folder, ignore=shutil.ignore_patterns(".*", "__pycache__"))
    skill_md = folder / "SKILL.md"
    skill_md.write_text(rewrite_frontmatter(skill_md.read_text(encoding="utf-8"), name, description), encoding="utf-8")
    (folder / "refs").mkdir(exist_ok=True)
    (folder / "refs" / "chat-copy.md").write_text(chat_copy_note(skill, config, heads, today), encoding="utf-8")

    archive = BUILD / f"{name}.zip"
    files = sorted(p for p in folder.rglob("*") if p.is_file())
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for path in files:
            z.write(path, str(pathlib.Path(name) / path.relative_to(folder)))
    words = sum(len(p.read_text(encoding="utf-8", errors="ignore").split()) for p in files)

    state = load_json(STATE, {})
    entry = state.setdefault(SURFACE, {}).setdefault(skill, {})
    entry.update(upload_name=name, packaged_at=datetime.datetime.now().isoformat(timespec="seconds"),
                 packaged_commits=heads, zip=str(archive))
    write_json(STATE, state)
    print(f"built {archive}")
    print(f"  {len(files)} files, about {words} words; name {name}, description {len(description)} characters")
    print(f"  from {', '.join(f'{role} {sha[:7]}' for role, sha in heads.items() if sha)}")


def mark_uploaded(skill):
    """Record that the last build of a skill is now live on claude.ai.

    @param skill: the skill's installed name
    @returns: None
    """
    state = load_json(STATE, {})
    entry = state.get(SURFACE, {}).get(skill)
    if not entry or "packaged_commits" not in entry:
        die(f"nothing packaged for {skill} yet; run build first")
    entry.update(uploaded_at=datetime.datetime.now().isoformat(timespec="seconds"),
                 uploaded_commits=entry["packaged_commits"])
    write_json(STATE, state)
    print(f"recorded {entry['upload_name']} as uploaded, from {entry['packaged_commits']}")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("build", "mark-uploaded"):
        die("usage: package.py build|mark-uploaded <skill>")
    (build if sys.argv[1] == "build" else mark_uploaded)(sys.argv[2])
