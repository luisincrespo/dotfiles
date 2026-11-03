# React pass

A check of a diff's React components and hooks for patterns that look right and buy nothing, or
break the rules React depends on, measured against React's own docs for the version the repo uses.

## When it applies

When the diff adds or changes a React component or hook. None → it doesn't apply.

## What to know first

- **The React version, and whether the React Compiler covers this code.** Read `react` in
  `package.json` or the lockfile, and look for the compiler in the build or framework config
  (`babel-plugin-react-compiler`, or the framework's compiler option). Configured isn't the same as
  covering a given file: compilation can be scoped to some paths, and a component can opt out
  (`"use no memo"`). See [incremental adoption](https://react.dev/learn/react-compiler/incremental-adoption).
- **The docs for that version, not memory.** Before raising a finding that rests on how React
  wants something done, read the page it rests on: [Rules of React](https://react.dev/reference/rules),
  [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect),
  [React Compiler](https://react.dev/learn/react-compiler), or the hook's or API's entry in the
  [API reference](https://react.dev/reference/react). The framework the app runs in (Next.js,
  Remix and the like) documents what it changes on top, like server components and data loading.
- **What the linter already enforces.** Where [`eslint-plugin-react-hooks`](https://react.dev/reference/eslint-plugin-react-hooks)
  runs, don't restate what it reports.

## What to look for

- **Effects doing what isn't an effect's job.** A pure derivation computed in a `useEffect` that
  sets state, where it belongs at render time; work a user action triggers, where it belongs in the
  event handler. And effects that are an effect's job but leak or race: a subscription or timer with
  no cleanup, a fetch whose late response can overwrite a newer one, a dependency list that leaves
  out what the effect reads. See [`useEffect`](https://react.dev/reference/react/useEffect).
  `useEffectEvent` is for the non-reactive part of an effect's logic: not a handler to pass around,
  and not a way to drop a dependency the effect should re-run on.
- **State that lands on the wrong item.** A list key that's random or positional where the list
  reorders ([keys](https://react.dev/learn/rendering-lists)); a component defined inside another's
  render, which remounts and loses its state each time.
- **Render that isn't pure.** Reading or writing `ref.current` during render, outside the
  initialization the [`useRef`](https://react.dev/reference/react/useRef) docs allow; a fresh,
  uncached promise passed to [`use`](https://react.dev/reference/react/use), which suspends on every
  render; anything that relies on memoization for correctness rather than speed.
- **Memoization that misleads.** Without the compiler, a `useMemo` or `useCallback` can still be
  right on its own: an expensive calculation, or a value another hook depends on. It's a finding
  only when it can't do what it's there for (a dependency that changes every render, say) and that
  costs something nameable. With the compiler covering the file, its docs recommend relying on it
  for new code, keeping `useMemo`/`useCallback` as an escape hatch (an effect's dependency, say),
  and testing before removing existing memoization. What a re-render costs under load is
  [`performance.md`](performance.md)'s question.
- **Rules of Hooks**: hooks called unconditionally, at the top level, from components or hooks.
  `use` is the exception: it can be called in conditionals and loops. The rest of the
  [Rules of React](https://react.dev/reference/rules) too: components and hooks pure, props and
  state never mutated.
- **Logic worth a hook.** Extract a hook when the logic calls hooks and has a reason to live on its
  own: tested by itself, or reused. A function that calls no hooks is a plain function without the
  `use` prefix ([custom hooks](https://react.dev/learn/reusing-logic-with-custom-hooks)).
- **Component and hook API**: prop names that match the value they carry. Before calling a prop
  "wider than needed" or unused, check the component's public-export surface and its sibling
  components' prop types: a widening that matches an exported or sibling API is deliberate, not
  dead code.

## The bar for a finding

Each finding names the docs page it rests on, for the repo's React version, what goes wrong (state
lost, a stale value shown, a request racing another, a re-render that costs something), and what
the code should do instead. A pattern that only looks dated to you, with no page saying so, isn't
one, and neither is memoization that's merely unnecessary.
