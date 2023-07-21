---
name: hyperly-design-invariants
description: Use when proposing or implementing changes to hyperly's API, naming, build pipeline, or output behaviour. Lists deliberate design choices that should NOT be undone without explicit user agreement, and the reasons behind them.
---

# Design invariants for purescript-hyperly

Each item below was decided deliberately, often after measurement or discussion. Do **not** propose changes that contradict these without explicitly asking the user, and explain *why* you think the decision should be revisited.

If you spot what looks like a bug that turns out to be one of these, link to the matching item here in your reply rather than "fixing" it.

---

## API naming

### `Match.captures`, not `content`
The field that holds `[fullMatch, ...groupCaptures]` is named `captures` in both PS and the JS `.d.ts`. Do not rename it back to `content` or to anything generic. `captures` aligns with .NET / Rust / Python regex conventions where `captures[0]` is the full match by convention.

### JS uses overloading; PS uses prime suffix `'`
- **PS**: three variants per operation — `match`, `match'` (with options), `matchContextlessly`. The prime suffix is Haskell-style "extended sibling" convention.
- **JS**: two-form overload on the same name — `match(regex, src)` vs `match(options, regex, src)`, dispatched by `instanceof RegExp`. Do **not** introduce `*Custom` / `*WithOptions` suffixes in JS — the overload is intentional and matches lodash/Express/jQuery-style JS idiom.

### `*Contextlessly` is a separate function, not part of the overload
"Contextlessly" is a different *mode* (different default `Options`), not a configuration flag. It stays as a named function in both PS and JS. Do not collapse it into `match`/`replace`/etc. via a sentinel.

### Instance variables are camelCase even when accessing constructors
Example: `const window = windowEffect()` — not `Win`, even though we then access `window.Element` and `window.Node`. PascalCase signals "constructor/type"; an instance is a value, even if it carries constructors as properties. Don't be cute with namespace-looking access patterns.

---

## Error handling

### PS returns `Either String Hype`; JS throws
This is a **boundary translation pattern**, not a preference. PS internals stay pure (`Either`); the JS wrapper layer's `unwrap` function in `js/utilities.js` converts `Left e` to `throw new Error(e)`. Do not:
- Expose `Either` to JS users (alien to JS idiom)
- Convert PS to throw (loses purity / explicit error tracking)
- Add a `tryReplace`/`replaceR`-style Result API in JS without explicit user request

`match` and `textContents` do **not** throw — they cannot fail.

---

## `textContents` semantics

### Leading `""` placeholders are intentional
`TextContents.purs` records a `(containerNode, "")` tuple whenever a container has block-level children but no leading text. So `<div><p>A</p></div>` produces `["", "", "A"]`.

The empty entry preserves the ability for a caller to *operate on* (or detect) the empty container slot. Removing it would silently lose information. Callers who don't want them filter with `tcs.filter(Boolean)` / `Array.filter (_ /= "")` — both READMEs document this.

Do not propose auto-filtering as the default behaviour without explicit user agreement.

---

## Match semantics

### Block boundaries are hard walls — matches cannot span across them

The **primary purpose** of contextful mode (the default) is to prevent regex matches from straddling block-element boundaries. `<p>foo</p><p>bar</p>` flattens to `"foobar"` in the DOM's textContent view, but hyperly's contextful pipeline never sees that flattened form — `<p>foo</p>` and `<p>bar</p>` are two independent strings:

```js
match(/oob/, '<p>foo</p><p>bar</p>')                // 0 matches
matchContextlessly(/oob/, '<p>foo</p><p>bar</p>')   // 1 match (operates on "foobar")
```

This is why `textContents` returns one entry per context: the regex pipeline runs the pattern independently against each entry, then concatenates the per-context match arrays. Trace: `Match.purs:matchAllDefault` → `traverse` per `(context, textContent)` tuple → `Match.js:stringMatchAllImpl` runs `text.match(pattern)` (or `text.matchAll`) on that one string. `replace`, `wrap`, `insert`, `transform` go through `lazyMatchAllDefault` with the same per-context iteration.

Without this guarantee, `replace(/foo bar/, 'X', '<h1>End of foo</h1><h2>bar starts</h2>')` would silently merge the two headings. The boundary-blocking is the **feature**, not an implementation detail.

### Consequence: the `g` / `global` flag is per-context

A direct corollary of "the regex runs once per context" is that `g`'s meaning is also per-context:

```js
match(/foo/, '<p>foo foo</p><p>foo</p>')   // → 2 matches (one per <p>, no g)
match(/foo/g, '<p>foo foo</p><p>foo</p>')  // → 3 matches
```

So `replace(/foo/, 'X', ...)` rewrites the first `foo` of *each* context, not "the first `foo` in the document". `Match.js:stringMatchAllImpl` branches on `pattern.global` — non-global path uses `text.match(pattern)` (yields 0 or 1 match per context); global path uses `text.matchAll(pattern)`.

### Escape hatch and what NOT to "fix"

Users coming from raw-regex intuition or from findAndReplaceDOMText (which flattens the tree) will be surprised on both axes — the boundary blocking AND the per-context `g` semantics. The escape hatch is the `*Contextlessly` family: those collapse the tree into one flat string, making boundaries invisible and `g` mean what raw-regex says it means.

Both READMEs document this under "Match semantics — context boundaries" with a comparison table (`String.match` / findAndReplaceDOMText / Mark.js / hyperly contextful / hyperly contextless), framed primary-first (boundary blocking) with the `g` consequence as a sub-point.

Do **not** "fix" the per-context `g` behaviour by switching to "first match across all contexts" — that would break the symmetry between `textContents` (per-context output) and the matching pipeline (per-context input), make `replace(/foo/, 'X', src)` ambiguous about which `foo` gets rewritten when there are multiple contexts, and turn the `*Contextlessly` family into the only sensible default — at which point the contextful family loses its reason to exist.

---

## Performance characteristics (measured, not guessed)

### `Array.includes` over `Set.has` for small element lists
`contextElements` (~50 items), `elementsToBeIgnored` (~15 items), `voidElements` (~13 items) stay as `Array String`. User benchmarked: under 100 elements, Array wins or ties (cache locality beats Set's hash + pointer overhead). These are HTML5 spec lists — they will never grow large enough for Set to win.

### `innerHTML + regex` everywhere for `hasContextElements`
`Options.purs:hasContextElementsDefault` uses a precompiled regex tested against `innerHTML` on **both browser and server** — no `isBrowserSide` branch. Re-verified 2026-04-27 with a fresh benchmark; the path was briefly switched to `el.matches(":has(...)")` (server) and `el.querySelector(selector)` (browser), but profiling revealed selector parsing dominated 64% of total wrap/replace time. Both DOM impls cache selector results per element, but hyperly's workload always sees fresh clones — cache miss every call, parser runs every time. The unified `innerHTML + regex` path:
- 2.5–9× faster on happy-dom under realistic fresh-clone workload
- Ties or wins on Chrome (small subtrees benefit, large subtrees neutral)
- Eliminates the dual-path code (browser vs server) — one consistent implementation
Do not reintroduce `:has(...)` or `querySelector` based detection here even if a microbenchmark says they're faster — those benchmarks reuse the same element across iterations and hit the per-element cache, an artifact users never see.

### Comment-stripping in unminified rollup output
`build/rollup/config.js` runs `terser({ compress: false, mangle: false, format: { comments: false, beautify: true } })` on the unminified bundle. PS's `purs-backend-es` output carries hundreds of lines of original PS docstrings into JS — they bloat the unminified bundle by ~3 KB (8 KB+ in raw, ~600 bytes after gzip). Source maps already point back to source for debugging.

### Transformer accumulator uses `STArray`, not `Array <>`
`Transformer.purs:transformMatches` accumulates `Steps` via `Data.Array.ST` push. The earlier naive `acc <> src'tgts` was O(N²) over many matches. Don't replace with `Array.snoc` or `<>` — the user explicitly asked for the `STArray` rewrite.

### `Iterator.prototype.map` polyfill targets `%IteratorPrototype%`, not Array iterator's prototype
`js/Match.js` walks two prototype levels up (`Object.getPrototypeOf(Object.getPrototypeOf([].values()))`) instead of `[].values().constructor.prototype`. The naive form resolves to `Object.prototype` in pre-Iterator-helpers environments — patching `.map` there would catastrophically pollute every object.

---

## Build pipeline

### `compile` → `purs-backend-es build` → bundler — never skip the first step
`spago build` produces `output/`; `purs-backend-es` reads `output/` and emits `output-es/`; rollup/esbuild reads `output-es/` and emits `lib/` or `src/Demo/public/static/`.

If `output/` is stale, `purs-backend-es` happily re-emits stale JS, and the bundle picks up old PS bytecode silently. Every `pnpm build` / `pnpm build:demo` / `pnpm start` script in `package.json` therefore starts with `pnpm compile &&`. Do not remove that prefix to "save time" — `spago build` is mtime-cached and basically free when up-to-date.

### rollup for the npm library, esbuild for the demo
- `pnpm build` → rollup → `lib/hyperly.{js,min.js}` (smaller minified output via terser; npm release path)
- `pnpm build:demo` / `pnpm start` → esbuild → `src/Demo/public/static/*` (native CSS handling, fast watch mode)

Don't propose unifying both onto rollup unless the user explicitly accepts the cost of adding a CSS plugin to handle `main.css` / `demo.css`.

---

## File structure

### `src/` is PureScript-first; `js/` is the wrapper layer
`src/` contains PS sources plus PS-required foreign JS (e.g. `DOM.js` next to `DOM.purs` — the PS compiler enforces this). The JS wrapper layer (uncurried + curried API, `.d.ts` files, utilities) lives in `js/` at the root. Do not move JS wrapper files back into `src/`.

### Demo HTML lives at `src/Demo/public/`, not `demo/`
Earlier the project had a separate `demo/` directory at root with HTML files. That directory was eliminated; HTML now lives co-located with the demo's PS source under `src/Demo/public/`. esbuild's `servedir` and `outdir` point there. Don't reintroduce a top-level `demo/` directory.

### Build tooling lives at `build/`
`build/rollup/` and `build/esbuild/` hold their respective configs. Do not put rollup or esbuild configs at the project root or split them apart.

---

## Public API surface (encapsulation via `exports`)

`package.json`'s `exports` field deliberately exposes only:
- `'.'` → `hyperly.js` (uncurried)
- `'./fp'` → `js/fp/index.js` (curried)
- `'./package.json'`

External consumers cannot reach into `js/match.js`, `js/fp/match.js`, etc. Don't add wildcard exports or expose internal files — the encapsulation lets us refactor `js/` internals without breaking users.

Internal tests use the `imports` field:
- `#hyperly/*` → `./js/*` (wildcard)
- `#hyperly/fp` → `./js/fp/index.js` (specific entry, mirrors public `'hyperly/fp'`)

---

## Things that look weird but are correct

### `wrap` is a first-class function in JS too
PureScript has `wrap`. Earlier the JS wrapper layer didn't expose it — users had to use `transform`. We deliberately added `js/wrap.js` and `js/fp/wrap.js`. Do not remove or "simplify back to transform" — it's a real ergonomic win for the most common use case.

### `Hype` retains references to detached old DOM nodes
For `revert` to work, every replaced/wrapped/inserted node's old subtree must stay reachable. Memory cost is real (KB to MB depending on transformation count). A `commit` / `discardHistory` API to release this is a deferred design item; until it exists, do not auto-discard history.

### `isHype` uses optional chaining: `h?.tag === 'Hype'`
The `?.` is intentional — guards against `null`/`undefined` slipping past the earlier `isString`/`isElement` checks in `dict()`. Don't simplify back to `h.tag === 'Hype'`.

---

