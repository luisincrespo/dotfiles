# API shape pass

A check of the endpoints a diff adds or changes, for shapes that hide failures or will need a
second break to fix.

## When it applies

When the diff adds or changes an HTTP endpoint: its route, its request or response shape, or how
its handler reports failure. None → it doesn't apply.

## What to look for

- **Failures returned as a success.** A 200 with a `success: false` body rather than an error
  status hides the failure from status-code monitoring and from anything that only sees thrown
  errors.
- **Names that no longer say what it does.** When the change already breaks a request shape, check
  whether the route and field names still describe what it does now: renaming later is a second
  break for every caller.
