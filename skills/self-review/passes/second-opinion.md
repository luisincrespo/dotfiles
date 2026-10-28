# Second opinion, different model

A correctness review of a change by a different model from the one doing the review.

## When it runs

Only when local config's `second_opinion_review` covers the repo: its own `github/<owner>/<repo>`
entry, else the `*` fallback, never when its entry is `false`. Look it up directly rather than
scanning a dump, which can truncate away the key you're after:
`jq --arg k github/<owner>/<repo> '(.second_opinion_review // {}) | if has($k) then .[$k] else .["*"] end' ~/.agents/local/config.json`.
`null` or `false` → skip and say so in one line. **Read the entry from local config on every
run**, not from earlier in the session: a resumed session otherwise runs whatever model was pinned
when it first looked (once, three days after the pin had moved on).

## Why a second model

The failure modes that survive a review are the ones the reviewer shares with the author: the same
blind spot that wrote the bug reads past it. A different model has different blind spots. That is
the whole value, so **don't prompt it toward your own conclusions**. Run it after your own pass,
don't show it your findings, and ask what's wrong with the change.

## Hand it the content, and run it from outside the checkout

Pipe the payload to the configured `command` on stdin, instructions as the argument, with the
working directory set to a scratch dir rather than the repo. The payload:

- **The diff from the merge-base, and nothing else.** For a local branch,
  `git diff $(git merge-base origin/<base> HEAD)`; `gh pr diff <N>` already is one. A two-dot
  `git diff origin/<base>` also carries every commit the base gained since the branch was cut, and
  the reviewer then reports on other people's code (a 417 KB payload and four bogus findings,
  once).
- **The full text of each changed file.** A **deleted** file's text is not in the tree: read it
  from `git show <base>:<path>`.
- **What the change claims to do**, when there's a description (a PR's title and body), so it can
  judge the change against it.

> Why bother: a review CLI pointed at a working tree reads whatever it finds interesting. Asked to
> review a one-line change in this repo, one read twenty-eight Claude Code session transcripts
> belonging to an unrelated project.

**This is mitigation, not isolation, and the difference matters.** A payload removes the *need* to
explore and takes the repo out of arm's reach; it does not remove the *ability*. The process still
has your filesystem and, in the case tested here, read access everywhere with no deny rules. Assume
anything it decides to open can go to its vendor.

That is precisely why this is **opt-in**, per repo or, with `*`, per machine. Enable it where a
reviewer reading beyond the payload would be acceptable anyway; leave it off where it would not.
Don't reason from "we handed it only the diff": that was the first claim this pass made, and the
first second-opinion run falsified it.

## What to ask for

Correctness defects, and an explicit verdict line when it finds none, so "clean" is
distinguishable from "crashed" or "ran out of turns".

## What comes back

Candidates, not conclusions, and not privileged over your own. Check each the way you check your
own findings ([`claims.md`](claims.md) catches a second model as often as the first), dedupe
against what you already have, and drop what doesn't hold up.

**It reviews; it does not write.** It never edits, posts or replies. You act on every finding: a
reviewer that edits is a second author, and then nobody reviewed the result.

## Left to the skill running it

Where the diff and the files come from; what happens to a finding that holds up; and when to run
it again on a changed diff, never past the entry's `max_rounds`.
