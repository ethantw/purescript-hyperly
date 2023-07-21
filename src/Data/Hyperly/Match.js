export const stringLength = str => str.length

// Polyfill for `Iterator.prototype.map`:
//
// For Web environment (Safari) only. Use `iterator-helpers-polyfill` instead on
// Node.js (< v22) for better performance.
//
// Walk up two prototype levels from an Array Iterator instance to reach the
// shared `%IteratorPrototype%`. Naively using `[].values().constructor.prototype`
// resolves to `Object.prototype` on engines without Iterator helpers (because
// `[].values()` has no own `.constructor`, the lookup falls through to
// `Object.prototype.constructor`), which would dangerously pollute every
// object if we patched `.map` onto it.
const IteratorPrototype = Object.getPrototypeOf(Object.getPrototypeOf([].values()))

// Use `hasOwnProperty.call` rather than `Object.hasOwn` (ES2022) so the
// bundle's effective baseline is governed only by top-level await elsewhere.
if (
  typeof window === 'object'
  && IteratorPrototype
  && !Object.prototype.hasOwnProperty.call(IteratorPrototype, 'map')
) {
  IteratorPrototype.map = function(f) {
    return Array.from(this).map(f).values()
  }
}

export const stringMatchAllImpl =
  nothing =>
  just =>
  tuple =>
  context =>
  pattern =>
  text =>
  (
    // Global matches:
    pattern.global
    ? text.matchAll(pattern)

    // Single match: avoid running the regex twice (test + match) by going
    // straight to match() and turning the (string[] | null) result into a
    // 0-or-1-element iterator.
    : (() => {
        const m = text.match(pattern)
        return (m ? [m] : []).values()
      })()
  )
  .map(
    (v, index) => (
    tuple
      (index === 0 ? just (context) : nothing)
      (prepareInitialMatch (context) (v))
    )
  )

export const combineIterators =
function *(iterators) {
  for (let it of iterators) {
    yield* it
  }
}

const prepareInitialMatch =
  context =>
  captures =>
({
  captures,
  context,

  groups: captures.groups ?? {},
  input: captures.input,

  startIndex: captures.index,
  endIndex: captures.index + captures[0].length,

  portions: [],
})

export const take1Impl =
  nothing =>
  just =>
  iterator =>
{
  const { value, done } = iterator.next()

  if (done) {
    return nothing
  }

  return just (value)
}
