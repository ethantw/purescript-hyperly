# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

## [0.2.0-rc.1] - 2026-04-30

### Added

- `defaultOptions` and `contextlessOptions` are now exported from the JavaScript / TypeScript surface (both `'hyperly'` and `'hyperly/fp'`). Each is a frozen `Required<Options>` record whose predicates are uncurried `(node: Node) => boolean` — the JS-facing shape, not the curried PS-facing shape used internally. The recommended use case is composing on top of the defaults rather than reimplementing them:

  ```ts
  import { defaultOptions, replace } from 'hyperly'

  const isContextElementHan: Options['isContextElement'] = (node) =>
    defaultOptions.isContextElement(node) && hanCssExtraCheck(node)

  replace({ isContextElement: isContextElementHan }, /…/g, '…', root)
  ```

  Both records are `Object.freeze`d, so reassigning a predicate (`defaultOptions.ignore = …`) throws in strict mode. The PureScript-side `Data.Hyperly.Options.defaultOptions` / `contextlessOptions` are unchanged — the JS exports are uncurried views over the same source-of-truth lists.

## [0.1.0] - 2026-04-27

Initial public release. The library has been under development for years; this version codifies the public API surface for both PureScript and JavaScript / TypeScript consumers.

### Added

#### Core operations (PureScript and JavaScript)
- `textContents` / `contextlessTextContents` — scrape visible text, partitioned by block-level context boundaries.
- `match` / `matchContextlessly` — find regex matches across text contents, returning per-text-node `Portion` slices.
- `replace` / `replaceContextlessly` — replace matched text with a string (with `$&` / `$1` / `$<name>` back-references).
- `wrap` / `wrapContextlessly` — wrap matched text with a designated element. The wrapper can be a `String` (HTML markup) or a live `Element`.
- `insert` / `insertContextlessly` — insert content before, between, or after matched portions, with `Inner` or `Outer` boundary semantics. Five `Insert` constructors: `Around`, `Both`, `Start`, `End`, `Between`.
- `transform` / `transformContextlessly` — low-level engine; transform each portion into any `Target` (string, element, array, or empty).
- `revert` / `revertAll` — undo the last (or all) recorded transformation step(s).

#### JavaScript public API
- Two import paths: `'hyperly'` (uncurried) and `'hyperly/fp'` (curried, partially applicable).
- TypeScript declarations for every operation and every type (`Match`, `SourcePortion`, `Insertion`, `Target`, `Hype`, `Options`).
- Function overloading on first-argument type (`instanceof RegExp`) so `match(regex, src)` and `match(options, regex, src)` share the same name.
- Errors thrown as native `Error` instances with the underlying PS error string preserved on `.message`.

#### PureScript public API
- `Hyperly` type class with instances for `String`, `Element`, and `Hype`.
- Three variants per operation: bare (default options), prime `'` (custom options), and `*Contextlessly`.
- `Target` and `Wrapper` type classes covering nodes, elements, strings, arrays, and HTML markup via `TargetHTML`.

#### Tooling
- Unified build pipeline: `pnpm compile` (Spago) → `purs-backend-es` → bundler.
- `pnpm build` produces the npm-publishable library via rollup + terser.
- `pnpm build:demo` and `pnpm start` produce the demo via esbuild (with native CSS handling and serve mode).
- `pnpm typecheck` validates the TypeScript declarations against test usage with `tsc --noEmit`.
- `pnpm test` runs both the PureScript suite (66 tests) and the JavaScript suite (50 tests).
- `prepublishOnly` script ensures tests pass and the bundle builds before any `pnpm publish`.
- Public API encapsulation via `package.json` `exports` — only `'hyperly'` and `'hyperly/fp'` are reachable externally.

#### Documentation
- Comprehensive [`README.md`](README.md) (PureScript-flavoured) with type reference, error handling, and accurate working examples.
- Companion [`README.js.md`](README.js.md) (JavaScript / TypeScript-flavoured) covering the JS public API, both import styles, and the throw-on-error contract.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) "Design decisions you should know about" section locking in deliberate choices.
- AI-agent skill at `.claude/skills/hyperly-design-invariants/SKILL.md` mirroring the design notes.

### Performance

Compared to early prototypes:
- `Transformer.purs:transformMatches` now uses `Data.Array.ST` push (O(N) amortized) instead of array concatenation per match (O(N²)).
- `js/utilities.js` caches `windowEffect()` once at module load; `isElement` / `isNode` no longer re-resolve the window per call.
- `Match.js:stringMatchAllImpl` non-global path uses `text.match()` directly instead of `pattern.test()` followed by `text.match()` (one regex pass instead of two).
- `Revert.purs:revertOne` skips the already-detached first node when removing replacement nodes.
- The minified library bundle (`lib/hyperly.min.js`) is 6–8% smaller than the previous esbuild-based output thanks to rollup + terser. Unminified output also strips PS docstrings carried over from `purs-backend-es` (~3 KB saved).

### Notable design decisions (locked in for 0.1.0)

These are documented in [`CONTRIBUTING.md`](CONTRIBUTING.md#design-decisions-you-should-know-about) and the in-repo Claude skill. They are intentional and should not be reverted without discussion:

- `Match.captures` aligns with .NET / Rust / Python regex naming, where `captures[0]` is the full match and the rest are positional groups.
- JavaScript uses overloading for `match` / `replace` / `insert` / `wrap` / `transform` / `textContents`; PureScript uses Haskell-style prime suffix `'` for the same purpose. Each language follows its own idiom.
- `*Contextlessly` is a separate function (not part of the overload) because it represents a different default mode, not a configuration of the same operation.
- PureScript returns `Either String Hype`; JavaScript throws. This is a deliberate boundary translation, not a stylistic choice.
- `textContents` returns leading `""` placeholders for empty container contexts. Callers filter at the call site if they don't want them.
- `Array` is used (not `Set`) for HTML-spec lists like `contextElements`; `innerHTML + regex` is used (not `querySelector`) for context detection on happy-dom — both are based on measured benchmarks, not preference.

### Fixed

Latent bugs corrected before initial publish:

- `Match.js`: the Iterator helpers polyfill formerly walked `[].values().constructor.prototype`, which resolves to `Object.prototype` in pre-Iterator-helpers environments — patching `.map` there would have polluted every object. Now correctly walks two prototype levels to reach `%IteratorPrototype%`.
- TypeScript declarations: `Match` now exposes `input`, `portions`, and `context`; `SourcePortion` now exposes `atIndex`. These were missing from the original `.d.ts` files.
- `isHype` in `js/utilities.js` is now null-safe (`h?.tag === 'Hype'`).
- README examples that did not compile (wrong imports, wrong `Insert` constructors, wrong types) have been replaced with verified working code.
- `Match.js` polyfill check uses `Object.prototype.hasOwnProperty.call` instead of `Object.hasOwn` (ES2022). The bundle's effective ES baseline is now governed solely by top-level `await` in the happy-dom initialiser (ES2022; Chrome / Edge / Firefox 89+, Safari 15+).
- `Options.purs:hasContextElementsDefault` now uses `innerHTML + regex` test on both browser and server, replacing the prior split (`:has(...)` selector on server, `querySelector` on browser). CPU profiling showed selector parsing dominated 64% of total `wrap`/`replace` time on happy-dom; investigation revealed both DOM implementations cache parsed selectors per element instance, but hyperly's workload always operates on a fresh `cloneNode`, missing the cache every call. A precompiled regex tested against `innerHTML` has no per-element cache to miss, so its cost is consistent. Final benchmark deltas on a 30-paragraph fixture with ~60 matches:

  | Operation | Node before | Node after | Chrome before | Chrome after |
  |---|---:|---:|---:|---:|
  | wrap simple | 150 µs | **19 µs** (8.0×) | 12.9 µs | 12.6 µs |
  | wrap bulky | 3106 µs | **914 µs** (3.4×) | 733 µs | **680 µs** (-7%) |
  | replace simple | 137 µs | **8.7 µs** (15.8×) | 5.5 µs | 5.9 µs |
  | replace bulky | 2647 µs | **456 µs** (5.8×) | 271 µs | **232 µs** (-14%) |

  vs. findAndReplaceDOMText on the same fixtures: hyperly is 1.55–2.97× slower on Node and 2.57–6.26× slower on Chrome at 0.1.0. The per-call gap reflects feature differences (context-aware regex, history tracking via `revert`/`revertAll`, full Match record with portions, type-safe error handling) that findAndReplaceDOMText doesn't provide.
- npm publish surface unified onto pre-bundled `lib/`. Previously the package shipped both `lib/` (rolled bundle) and `output-es/` (per-module purs-backend-es output), with consumer routing depending on `browser` vs `default` conditions. Now `'hyperly'` and `'hyperly/fp'` both resolve to bundled files (`lib/hyperly.js` and `lib/hyperly.fp.js`), eliminating the 4 MB / 736-file `output-es/` directory from the publish. Tarball dropped from 509 KB → 281 KB; unpacked 3.0 MB → 1.3 MB. Source-map debugging is unchanged in either path.
