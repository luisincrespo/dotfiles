# React pass

A check of a diff's React components and hooks for patterns that look right and buy nothing, or
break the rules React depends on.

## When it applies

When the diff adds or changes a React component or hook. None → it doesn't apply.

## What to look for

- **Memoization that isn't effective.** A `useCallback` or `useMemo` buys nothing when its
  dependencies are unstable, when the hook returns a fresh object each render, or when the child it
  feeds isn't memoized and re-wraps its handlers anyway. Flag it as dead ceremony: drop it, or
  complete the chain (stabilize the inputs, plus `React.memo`). What a re-render costs under load
  is [`performance.md`](performance.md)'s question; this one is whether the memoization does what
  it claims.
- **Derivations in effects.** A pure derivation belongs at render time, or in a `useMemo`, not in a
  `useEffect` that sets state.
- **Logic worth a hook.** Suggest extracting a hook where it makes logic easier to test on its
  own or to optimize in one place: logic that decides what renders, say
  (`useVisibleQuestionnaire(message)` returning the card or `null`).
- **Rules of Hooks**: hooks called unconditionally, at the top level, from components or hooks.
- **Component and hook API**: prop names that match the value they carry. Before calling a prop
  "wider than needed" or unused, check the component's public-export surface and its sibling
  components' prop types: a widening that matches an exported or sibling API is deliberate, not
  dead code.
