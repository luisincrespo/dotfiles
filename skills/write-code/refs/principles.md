# Principles for writing code

> **Personal layer.** How the user wants code written, one line each. Most cite the review pass (or
> ref) that checks them in depth, which is where the detail lives; one with none is checked only by
> the general correctness review. To use your own, put your version at this same path in your
> private companion repo (`install.sh` links it in place of this one). `write-code` adds to it when
> you correct code it wrote.

1. **One job per unit.** A function, module or component does one thing, and UI, data and side
   effects live apart. A unit doing several is worth splitting when that makes a change or a test
   easier, not by rule. → [`design.md`](../../self-review/passes/design.md)
2. **Extensible for what's coming, not for hypotheticals.** Leave seams where the ticket, the
   project or the stack says change is on the way, and nowhere else.
   → [`design.md`](../../self-review/passes/design.md)
3. **Testable by construction.** Logic stays pure and apart from I/O, and dependencies are passed
   in. Tests check behaviour, not implementation, arranged per global rule 1.
4. **Start from the closest existing example, with judgment.** Reuse before writing new, and match
   how the surrounding code does things: a way that's better on its own but unlike everything
   around it usually costs more than it saves. Don't copy what's clearly wrong, though, such as a
   bug, a deprecated API, a pattern the repo is moving away from, or something a pass would flag.
   Write it right, say in the PR why it differs, and leave fixing the old code to a follow-up
   (principle 5). → [`design.md`](../../self-review/passes/design.md),
   [`conventions.md`](../../self-review/passes/conventions.md)
5. **The smallest change that does the job.** No drive-by fixes; those become their own PR or a
   follow-up. → [`breakdown.md`](../../deliver/refs/breakdown.md)
6. **Every state the user can reach**, not only the success path.
   → [`ux.md`](../../self-review/passes/ux.md)
7. **Handle errors where they can be acted on**, and let the rest propagate. Never swallow one
   silently, and handle them the same way throughout.
   → [`design.md`](../../self-review/passes/design.md)
8. **Make it observable.** From the signals it leaves, someone can tell how it's used and how it
   behaves: usage events for what the change is meant to move, traces that follow a request across
   services, and logs and error reports that say what failed. Signals use the repo's existing way of
   reporting them, and report what actually happened, not what was attempted.
   → [`observability.md`](../../self-review/passes/observability.md)
9. **Names use the domain's own vocabulary;** a name that needs a comment is the wrong name.
   → [`personal-conventions.md`](../../self-review/passes/personal-conventions.md)
10. **Types say exactly what's allowed:** no `any`, non-null assertions or casts to make it compile.
    → [`personal-conventions.md`](../../self-review/passes/personal-conventions.md)
11. **Know where user data goes:** what's stored, logged or sent, and how it's deleted.
    → [`customer-data.md`](../../self-review/passes/customer-data.md)
12. **Comments carry only what the code can't say.** → global rule 4,
    [`personal-conventions.md`](../../self-review/passes/personal-conventions.md)
