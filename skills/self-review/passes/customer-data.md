# Customer data pass

A check of how a change handles the data customers trust the product with: where it lands, how
long it stays, whether it can be deleted when they ask, and whether any of it goes somewhere it
shouldn't. Customer data means personal data (names, emails, anything that identifies a person) and
the customer's own content (their documents, uploads, messages, generated output). It applies to any
diff, your own or someone else's; the skill that reads it decides what happens to the findings.

## When it applies

When the diff puts customer data somewhere new, or changes what happens to it where it already is:

- a new table, column, collection, file, bucket path, cache or queue payload that holds it;
- a copy of it: an export, a snapshot, a denormalized field, a temp file, a search index, an
  embedding;
- a new destination outside the product, or new fields, purposes or settings for an existing one: a
  vendor, a model provider, an analytics or support tool;
- a change to how it's deleted, expired, archived, backed up, versioned or restored, or to what
  records whose it is.

A diff that touches none of these → it doesn't apply. Say so in one line rather than skipping it
silently.

## What to know first

Only for the data paths the diff touches:

- **The deletion contract for that data.** What deletes it, and when: deleting the item itself,
  the user, or the whole account or workspace, and any deadline or documented exception. Find the
  job, cascade or handler that carries it out and how it locates what to remove (foreign keys, a
  list of stores, an ownership mapping, a path prefix).
- **How long that kind of data is meant to live.** The repo's convention for it: TTLs, lifecycle
  rules, cleanup jobs, a documented retention period.
- **Where it already goes, and with what.** The vendors and providers it's already sent to (from a
  documented list where there is one, otherwise from the existing calls), and which fields go to
  each. A provider already in use doesn't make every new payload or setting for it approved.

Missing documentation isn't a finding by itself.

## What to look for

- **Data deletion can't reach.** Trace how the applicable deletion would find each new store or
  copy, and report one it can't: a table with no path to its owner, objects nothing maps back to the
  item or customer, an index or embedding that survives the deletion of the document it came from.
  The key's format proves nothing either way: report the unreachable copy, not the random id. For an
  object several owners share, check that each owner's reference goes and the last owner's removal
  cleans it up. A vendor copy counts when it outlives the deletion deadline and no purge, expiry or
  zero-retention setting already covers it.
- **Data that outlives its purpose.** A cache key, temp file, queue message or intermediate artifact
  holding customer data with no expiry, cleanup or cascade, when the feature needed it only briefly;
  a copy that survives the retention or deletion deadline that applies to it, with no established
  exception. Check the existing cleanup and cascades before proposing a TTL.
- **Data coming back after deletion.** When the diff changes backups, versioning, a restore or
  replay path, or a write that can land after the delete: whether deleted data can reappear, and
  whether backups expire as the repo's process says. Removing records from backups one by one isn't
  the bar where an established expiry process applies.
- **Data going somewhere nobody meant it to.** Customer data, personal or not, sent to a destination
  outside the product that wasn't receiving it, or more of it to one that was (the full document
  where only titles went before); customer data copied into a place people outside the customer can
  reach, like a test fixture or seed copied from production.
- **Kept beyond its purpose.** Fields or a raw original stored past what the feature's established
  purpose needs. That no code in the repo reads a field, or that the original is kept beside what was
  derived from it, isn't enough by itself: reprocessing, recovery or another consumer can need it.

Who can reach data through the product (access checks, one tenant seeing another's, an exploitable
leak) is the security review's. Customer data in logs, events, traces and error reports, captured
URLs and error messages included, is [`observability.md`](observability.md)'s. This pass owns where
data lives, how long, whether deletion reaches it, and what leaves the product. Report each root
cause once, under the pass that owns it.

## The bar for a finding

Each finding names **the data, where it lands, and what fails, measured against the repo's own
contract or mechanism**: "deleting a workspace leaves its imported files in the `imports/` bucket:
nothing maps an import id back to its workspace, and the deletion job only walks workspace
prefixes", or "the full document text now goes to the embedding provider, which until now only
received titles". Not "consider data retention" or "is this GDPR-compliant?": a finding says what
can't be deleted, what lives too long, or what goes where it shouldn't.

Ask only when one fact you can't check decides a concrete issue, like whether the provider's
retention is already set to zero. An evidenced transfer of customer data to an outside destination
nobody meant to receive it is the exception: it's a finding on sight.

## Why it's a pass of its own

These defects escape feature tests unless something checks deletion, retention and destinations on
purpose. The feature works and the data is there; the gap shows months later, as a deletion request
nobody can fully honour because the copies weren't tracked, a cache still holding last year's
documents, or a vendor holding data no agreement covers. Fixing it then means finding every copy
after the fact. Agent-written code produces these readily, since a task says what to store and
rarely when to forget it.

## Left to the skill running it

What a finding becomes. Adding a new store or copy to the existing deletion path, or an expiry that
matches the repo's convention for the same kind of data, is usually a clear fix. Choosing a retention
period, sending data to a new destination or more of it to an existing one, or changing what the
product collects is the user's decision or a question to the author: it often needs someone outside
the code to agree.
