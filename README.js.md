# hyperly (JavaScript API)

> **Using PureScript?** See the [**PureScript API documentation**](https://github.com/ethantw/purescript-hyperly/blob/main/README.md) instead.

Hyperly is a library for manipulating HTML text content with regular expressions, while preserving the surrounding HTML structure. For example, it can match and replace `/hello/giu` in `<a>H</a>el<b>l</b>o` without breaking the elements or their attributes.

The library provides powerful tools for scraping, finding, and transforming text within HTML documents, with support for both client-side and server-side environments. It handles HTML contexts intelligently to ensure text operations respect element boundaries and semantic structure.

> **Try it live** → [**ethantw.github.io/purescript-hyperly**](https://ethantw.github.io/purescript-hyperly/) — interactive playground for `match` / `replace` / `wrap` / `insert`. Drop in any HTML, tweak the regex, see the result update in real time.

```js
import { replace, html } from 'hyperly'

try {
  const result = replace(
    /world/gi,
    'Universe',
    '<p data-keep="world">Hello <b>W</b>orld</p>',
  )
  html(result)
  // → '<p data-keep="world">Hello <b>U</b>niverse</p>'
  //
  // The match spans <b>W</b> and the trailing 'orld'. Hyperly rewrites both
  // text nodes correctly without touching the data-keep attribute.
} catch (e) {
  // All Hyperly operations throw on failure (e.g. zero-length matches,
  // invalid wrappers). See the Error Handling section for the full list.
  console.error(e.message)
}
```

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Advanced Usage](#advanced-usage)
- [API Reference](#api-reference)
  - [Utilities](#utilities) · [`textContents`](#textcontents) · [`match`](#match) · [`replace`](#replace) · [`insert`](#insert) · [`wrap`](#wrap-1) · [`transform`](#transform) · [`revert` / `revertAll`](#revert--revertall)
- [Type Reference](#type-reference)
  - [`Hyperly`](#hyperly) · [`Hype`](#hype) · [`HTMLType`](#htmltype) · [`Match`](#match-1) · [`SourcePortion`](#sourceportion) · [`Insertion`](#insertion-1) · [`Target`](#target) · [`Options`](#options)
- [Error Handling](#error-handling)
- [Browser Support](#browser-support)
- [Author](#author)

## Features

- **Text scraping** — extract text contents from HTML elements with configurable context handling
- **Pattern matching** — find text patterns using regular expressions with full match information
- **Text transformation** — replace, wrap, insert, and transform text portions with custom logic
- **History management** — track and revert text transformation operations step by step
- **Cross-platform** — works in both browser and Node.js (via [happy-dom](https://github.com/capricorn86/happy-dom)) environments
- **Two calling conventions** — non-curried for simplicity, curried for composition

## Installation

```bash
npm install hyperly
# or
pnpm add hyperly
```

For browsers, you can also use the pre-built bundle:

```html
<script type="module">
  import { replace, html } from '/node_modules/hyperly/lib/hyperly.js'
</script>
```

## Quick Start

> **Note**
> All Hyperly operations **throw** on failure rather than returning an error value. The examples below omit `try` / `catch` for clarity; in production code, wrap calls that handle untrusted input. See [Error Handling](#error-handling) for the full list of error conditions.

### Extracting text contents (plural)

```js
import { textContents } from 'hyperly'

textContents('<div><p>Hello <strong>World</strong></p><p>Another paragraph</p></div>')
// → ['', '', 'Hello World', 'Another paragraph']
//   The two leading empties stand in for the (empty) <body> and <div>
//   contexts before their first block-level child; each <p> then
//   contributes one entry.
```

> **Note**
> Each block-level element produces one entry. Loose text or inline content between blocks also becomes its own entry. An empty string `""` appears whenever a container has no leading text before its first block-level child — drop these with `tcs.filter(Boolean)` if you only need non-empty entries.

### Finding matches

```js
import { match } from 'hyperly'

const ms = match(/\b\w+\b/g, '<p>Hello <strong>W</strong>orld!</p>')
// → [
//   {
//     captures:   ['Hello'],
//     groups:     {},
//     input:      'Hello World!',
//     startIndex: 0,
//     endIndex:   5,
//     portions: [
//       {
//         text:        'Hello',
//         atIndex:     0,    index:           0,
//         indexInMatch: 0,   indexInNode:     0,  endIndexInNode: 5,
//         start:       true, inner:           false, end:        true,
//         node:        { ... },
//       },
//     ],
//   },
//   {
//     captures:   ['World'],
//     groups:     {},
//     input:      'Hello World!',
//     startIndex: 6,
//     endIndex:   11,
//     portions: [
//       { text: 'W',    atIndex: 6, index: 0, indexInMatch: 0, indexInNode: 0, endIndexInNode: 1, start: true,  inner: false, end: false, node: { ... } },
//       { text: 'orld', atIndex: 7, index: 1, indexInMatch: 1, indexInNode: 0, endIndexInNode: 4, start: false, inner: false, end: true,  node: { ... } },
//     ],
//   },
// ]
```

### Manipulation

#### Replacement

```js
import { replace, html } from 'hyperly'

const result = replace(
  /world/gi,
  'Universe',
  "<p data-original-target='world'>Hello World</p>",
)
html(result)
// → "<p data-original-target='world'>Hello Universe</p>"
```

#### Wrap

Wrap matched text with a designated element. The wrapper can be an HTML string (e.g. `'<mark />'`) or a live `Element`. For matches that span multiple inline elements, each portion gets its own wrapper.

```js
import { wrap, html } from 'hyperly'

const result = wrap(/\b\w+\b/g, '<mark />', '<p>Hello <b>W</b>orld</p>')
html(result)
// → '<p><mark>Hello</mark> <b><mark>W</mark></b><mark>orld</mark></p>'
//
// Notice "World" spans two nodes (<b>W</b> and 'orld') and each portion
// gets its own <mark> wrapper.
```

#### Insertion

```js
import { insert, html } from 'hyperly'

const result = insert(
  /World/g,
  { start: '<a>[</a>', between: '<b>|</b>', end: '<u>]</u>', outer: true },
  '<p>Hello <b>W</b><b>o</b>rld</p>',
)
html(result)
// → '<p>Hello <a>[</a><b>W</b><b>|</b><b>o</b><b>|</b>rld<u>]</u></p>'
```

#### Transformation

The `transform` operation is the underlying engine for replacement, wrapping, and insertion. It lets you convert each matched text portion into anything: an HTML string, an `Element`, an array of those, or even an empty string (to delete the match entirely).

```js
import { transform, html } from 'hyperly'

const result = transform(
  /world/gi,
  portion => _match => {
    const btn = portion.node.ownerDocument.createElement('button')
    btn.className = 'btn'
    btn.textContent = `Click: ${portion.text}`
    return btn
  },
  '<p>Hello World</p>',
)
html(result)
// → '<p>Hello <button class="btn">Click: World</button></p>'
```

> Returning an `Element` works by reading its `outerHTML` — Hyperly creates a fresh node from that markup in the source document, so the live element you constructed is **not** moved into the DOM. Use the form `portion.node.ownerDocument.createElement(...)` only when you want the convenience of programmatic construction; the result is equivalent to returning the same HTML string.

## Core Concepts

### The `Hyperly` input type

Most functions accept any of three sources interchangeably:

```ts
type Hyperly = string | Element | Hype
```

| Input | Use when |
|---|---|
| `string` | You have an HTML fragment as a string and want a string back |
| `Element` | You have a live DOM node and want it mutated in place |
| `Hype` | You're chaining operations on a previous result |

```js
// All three forms work the same way:
match(/foo/, '<p>foo bar</p>')           // from string
match(/foo/, document.querySelector('p')) // from Element
match(/foo/, hype('<p>foo bar</p>'))     // from Hype
```

### The `Hype` result type and chaining

Mutating operations (`replace`, `insert`, `transform`) return a `Hype`. Pass it back into another operation to chain:

```js
import { replace, transform, html } from 'hyperly'

const a = replace(/Hello/g, 'Hi', '<p>Hello World</p>')
const b = transform(
  /\bWorld\b/g,
  portion => _m => `<em>${portion.text}</em>`,
  a,
)
html(b)
// → '<p>Hi <em>World</em></p>'
```

The `Hype` also carries a transformation history — see [`revert` / `revertAll`](#revert--revertall).

### Context-aware vs contextless

Each operation has three variants:

| Variant | Behaviour |
|---|---|
| `match(regex, src)` | Context-aware. Block-level elements (`<p>`, `<li>`, `<h1>`, …) form independent contexts; matches do not cross block boundaries. |
| `match(options, regex, src)` | Same name, **overloaded**: pass an [`Options`](#options) record as the first argument to override context rules. Detection is by `instanceof RegExp` on the first arg. |
| `matchContextlessly(regex, src)` | All text is treated as one flat string, regardless of block structure. |

```js
import { match, matchContextlessly } from 'hyperly'

const html = '<p>foo</p><p>bar</p>'

match(/foo\s*bar/, html).length        // 0 — context boundary breaks the match
matchContextlessly(/foo\s*bar/, html).length  // 0 — still 0 here, no whitespace between
matchContextlessly(/foobar/, html).length     // 1 — text is concatenated flatly
```

### Two calling conventions

Hyperly exports the same operations in two styles. Use whichever fits your code.

#### Non-curried (default)

All arguments in one call. Import from the package root:

```js
import { match, replace, transform } from 'hyperly'

match(/hello/gi, src)
replace(/hello/gi, 'Hi', src)
```

#### Curried

One argument per call; partially applicable for composition. Import from `'hyperly/fp'`:

```js
import { match, replace } from 'hyperly/fp'

const findHellos = match(/hello/gi)               // (src) => Match[]
const sayHi      = replace(/hello/gi)('Hi')        // (src) => Hype

findHellos(src)
sayHi(src)
```

The two APIs are otherwise identical. Every signature shown in [API Reference](#api-reference) below is the non-curried form; the curried equivalent always replaces commas with successive calls — `f(a, b, c)` becomes `f(a)(b)(c)`. The default-vs-custom-options overload works the same way in both styles: the first argument is inspected (`instanceof RegExp` for the operation functions, type check for `textContents`), and the call is dispatched accordingly.

> **Exception**: the `transformer` callback passed to `transform` is **always curried** — `portion => match => Target` — regardless of which import style you use. This is intentional, since `portion` and `match` carry distinct information and are often partially applied.

## Advanced Usage

### Working with different input types

```js
import { match, replace, html, element } from 'hyperly'

// HTML strings — useful in Node.js, server rendering, or string pipelines.
const fromString = replace(/world/gi, 'Universe', '<p>Hello World</p>')
html(fromString)
// → '<p>Hello Universe</p>'

// Live DOM elements — mutates the element in place.
const el = document.querySelector('article')
const fromElement = replace(/world/gi, 'Universe', el)
element(fromElement) === el
// → true (same node, modified in place)

// Hype results — chain operations.
const chained = replace(/Hi/g, 'Hello', fromString)
html(chained)
// → '<p>Hello Universe</p>'
```

### Custom transformers

A transformer is a curried function `(portion: SourcePortion) => (match: Match) => Target`. The two arguments carry different information:

| | `portion` | `match` |
|---|---|---|
| Scope | One text node slice of the match | The entire regex match |
| Useful fields | `text`, `node`, `start`, `end`, `inner` | `captures`, `groups`, `startIndex`, `endIndex` |
| Multi-node match | One call per node | One identical reference per node |

```js
import { transform, html } from 'hyperly'

// Use match.captures for capture groups; portion.text for what's in this node.
const result = transform(
  /(\w+)@(\w+\.\w+)/g,
  portion => match => {
    if (portion.start && portion.end) {
      // Single-node match — render the full link.
      return `<a href="mailto:${match.captures[0]}">${match.captures[1]}</a>`
    }
    // Multi-node match — preserve the per-node text without losing structure.
    return portion.text
  },
  '<p>Email: alice@example.com</p>',
)
html(result)
// → '<p>Email: <a href="mailto:alice@example.com">alice</a></p>'
```

### History and reversion

Every mutating operation appends a step to the `Hype`'s history. Use `revert` to undo the last step or `revertAll` to restore the original.

```js
import { replace, revert, revertAll, html } from 'hyperly'

const h0 = '<p>Hello World</p>'
const h1 = replace(/Hello/g, 'Hi',    h0)
const h2 = replace(/World/g, 'Earth', h1)

html(h2)            // '<p>Hi Earth</p>'
html(revert(h2))    // '<p>Hi World</p>'    ← only the last step undone
html(revertAll(h2)) // '<p>Hello World</p>' ← all steps undone
```

> **Warning**
> Do not manually remove or replace DOM nodes that are tracked by a `Hype`'s history (e.g. via `Element.remove()`). Hyperly relies on those nodes remaining in the tree to revert correctly. Doing so may result in unexpected behavior or errors during reversion.

### Custom options

The third variant of each operation takes an [`Options`](#options) record to override individual context rules. Any key you omit falls back to the default behaviour.

```js
import { match } from 'hyperly'

// Treat every <span> as a context boundary too:
// — pass options as the first argument; the same `match` function dispatches
// to the custom-options path when its first arg is not a RegExp.
const ms = match(
  {
    isContextElement: node =>
      node.nodeName === 'SPAN' || /^(P|LI|H[1-6])$/.test(node.nodeName),
  },
  /\b\w+\b/g,
  '<p>foo<span>bar</span>baz</p>',
)
```

### Match semantics — context boundaries

The fundamental purpose of "contextful" mode (the default) is to **prevent matches from spanning across block-element boundaries**. Two adjacent paragraphs are different contexts, and a regex match must live entirely inside one of them:

```js
// Text content of <p>foo</p><p>bar</p> when flattened is "foobar".
// Contextful mode never sees that flattened form — each <p> is its own string.
match(/oob/, '<p>foo</p><p>bar</p>')                // 0 matches
matchContextlessly(/oob/, '<p>foo</p><p>bar</p>')   // 1 match (operates on "foobar")
```

This is why `textContents` returns one entry per context: hyperly's regex pipeline runs the pattern **independently against each entry** and concatenates the results. The block boundary acts as a hard wall — a regex cannot match content that straddles it. Without this, `replace(/foo bar/, 'X', '<h1>End of foo</h1><h2>bar starts</h2>')` would silently merge the two headings.

The `*Contextlessly` family is the explicit escape hatch: it collapses the tree into one flat string and applies plain regex semantics. Use it when block boundaries are noise rather than signal.

#### Consequence: the `g` flag is per-context

A side effect of "the regex runs once per context" is that the `g` flag's meaning is also per-context:

- **Without `g`** — each context yields its first match → up to N matches total (where N = number of contexts).
- **With `g`** — each context yields all its matches.

```js
match(/foo/, '<p>foo foo</p><p>foo</p>')                // 2 matches  (one per <p>, no g)
match(/foo/g, '<p>foo foo</p><p>foo</p>')               // 3 matches
matchContextlessly(/foo/, '<p>foo foo</p><p>foo</p>')   // 1 match   (flat string, no g)
matchContextlessly(/foo/g, '<p>foo foo</p><p>foo</p>')  // 3 matches
```

So `replace(/foo/, 'X', '<p>foo foo</p><p>foo</p>')` rewrites the first `foo` of *each* paragraph (2 substitutions), not "the first `foo` in the whole document". If you want the latter, use `replaceContextlessly` or include `g`.

For comparison with related tools — there is no industry convention here, so hyperly's choice is one of several reasonable ones:

| Approach | Crosses block boundaries? | Without `g` flag |
|---|---|---|
| Plain `String.prototype.match` | n/a | first match in the string |
| findAndReplaceDOMText (jQuery era) | yes (flattens tree) | first match in the entire tree |
| Mark.js | no (per text node) | first match per text node |
| **hyperly contextful (default)** | **no (per context)** | **first match per context** |
| **hyperly `*Contextlessly`** | **yes (flattens tree)** | **first match in the entire tree** |

## API Reference

Each operation is exported in two styles — non-curried from `'hyperly'`, curried from `'hyperly/fp'`. Both forms are shown for every function below.

### Utilities

```ts
// identical in 'hyperly' and 'hyperly/fp' (single argument, no currying)
hype(src: Hyperly): Hype
element(src: Hyperly): Element
html(src: Hyperly): string
htmlType(src: Hyperly): HTMLType
document(src: Hyperly): Document
```

| Function | Returns |
|---|---|
| `hype` | A `Hype` representation of the source (parses HTML strings into a holder element). |
| `element` | The underlying DOM `Element`. |
| `html` | The current HTML string of the source. Use this to read out the result of any operation. |
| `htmlType` | How the source HTML was parsed: `'Outer'`, `'Inner'`, `'BodyOuter'`, or `'BodyInner'`. |
| `document` | The owning `Document` of the underlying element. |

### `textContents`

Scrape visible text into a flat array. Each block-level element (`<p>`, `<li>`, `<h1>`, …) and each stretch of loose text or inline content between blocks contributes one entry. An empty `""` appears whenever a container has no leading text before its first block-level child — filter with `.filter(Boolean)` if you only want non-empty entries.

```ts
// from 'hyperly'
textContents(src: Hyperly): string[]
textContents(options: Options, src: Hyperly): string[]
contextlessTextContents(src: Hyperly): string[]

// from 'hyperly/fp'
textContents(src: Hyperly): string[]
textContents(options: Options): (src: Hyperly) => string[]
contextlessTextContents(src: Hyperly): string[]
```

```js
textContents('<div><p>Hello <b>World</b></p><p>Foo</p></div>')
// → ['', '', 'Hello World', 'Foo']
//   (two leading empties for the empty <body> and <div> contexts)

contextlessTextContents('<div><p>Hello <b>World</b></p><p>Foo</p></div>')
// → ['Hello WorldFoo']
```

### `match`

Find every regex match across the source. Returns an array of [`Match`](#match) records.

```ts
// from 'hyperly'
match(regex: RegExp, src: Hyperly): Match[]
match(options: Options, regex: RegExp, src: Hyperly): Match[]
matchContextlessly(regex: RegExp, src: Hyperly): Match[]

// from 'hyperly/fp'
match(regex: RegExp): (src: Hyperly) => Match[]
match(options: Options): (regex: RegExp) => (src: Hyperly) => Match[]
matchContextlessly(regex: RegExp): (src: Hyperly) => Match[]
```

```js
const ms = match(/\b\w+\b/g, '<p>Hello <b>W</b>orld</p>')

ms[0].captures      // ['Hello']
ms[0].startIndex    // 0
ms[0].portions      // single portion: { text: 'Hello', start: true, end: true, ... }

ms[1].captures      // ['World']
ms[1].portions      // two portions: { text: 'W', ... } and { text: 'orld', ... }
```

The `portions` array reveals which DOM nodes a match spans — essential for understanding multi-node matches like `World` above, which is split across `<b>W</b>` and the trailing text `orld`.

### `replace`

Replace each match with a string. The replacement string supports the same `$&`, `$1`, `$<name>` back-references as `String.prototype.replace`.

```ts
// from 'hyperly'
replace(regex: RegExp, replacement: string, src: Hyperly): Hype
replace(options: Options, regex: RegExp, replacement: string, src: Hyperly): Hype
replaceContextlessly(regex: RegExp, replacement: string, src: Hyperly): Hype

// from 'hyperly/fp'
replace(regex: RegExp): (replacement: string) => (src: Hyperly) => Hype
replace(options: Options): (regex: RegExp) => (replacement: string) => (src: Hyperly) => Hype
replaceContextlessly(regex: RegExp): (replacement: string) => (src: Hyperly) => Hype
```

```js
import { replace, html } from 'hyperly'

const out = replace(
  /(\w+)@(\w+\.\w+)/g,
  '<email user="$1" domain="$2">$&</email>',
  '<p>Reach me at alice@example.com.</p>',
)
html(out)
// → '<p>Reach me at <email user="alice" domain="example.com">alice@example.com</email>.</p>'
```

### `insert`

Insert content before, between, or after the portions of each match. Does not modify the matched text itself.

```ts
// from 'hyperly'
insert(regex: RegExp, insertion: Insertion, src: Hyperly): Hype
insert(options: Options, regex: RegExp, insertion: Insertion, src: Hyperly): Hype
insertContextlessly(regex: RegExp, insertion: Insertion, src: Hyperly): Hype

// from 'hyperly/fp'
insert(regex: RegExp): (insertion: Insertion) => (src: Hyperly) => Hype
insert(options: Options): (regex: RegExp) => (insertion: Insertion) => (src: Hyperly) => Hype
insertContextlessly(regex: RegExp): (insertion: Insertion) => (src: Hyperly) => Hype
```

The `Insertion` object selects what to insert and how:

```ts
interface Insertion {
  start?:   Target  // before the match
  end?:     Target  // after the match
  between?: Target  // between every adjacent pair of portions
  outer?:   boolean     // false (default) = Inner; true = Outer
}
```

| Provided fields | Behaviour |
|---|---|
| `{ start, between, end }` | Insert before, between every portion pair, and after. |
| `{ start, end }` | Insert before and after only. |
| `{ start }` / `{ end }` | Insert at one side only. |
| `{ between }` | Insert between portion pairs only. |

| `outer` | Boundary | Where `start` / `end` land |
|---|---|---|
| `false` (default) | Inner | Inside the matched text node, adjacent to the matched characters. |
| `true` | Outer | Outside the nearest enclosing element of the start/end portion. |

```js
import { insert, html } from 'hyperly'

// Inner brackets — placed inside the text nodes containing the match.
html(insert(
  /World/g,
  { start: '[', end: ']' },
  '<p>Hello <b>W</b>orld</p>',
))
// → '<p>Hello <b>[W</b>orld]</p>'

// Outer brackets — escape outwards past the <b>.
html(insert(
  /World/g,
  { start: '<a>[</a>', end: '<u>]</u>', outer: true },
  '<p>Hello <b>W</b>orld</p>',
))
// → '<p>Hello <a>[</a><b>W</b>orld<u>]</u></p>'
```

### `wrap`

Wrap each match with a designated element. The wrapper can be an HTML string (e.g. `'<mark />'`, `'<span class="hl" />'`) or a live `Element`. Matches spanning multiple inline elements get one wrapper per portion.

```ts
// from 'hyperly'
wrap(regex: RegExp, wrapper: string | Element, src: Hyperly): Hype
wrap(options: Options, regex: RegExp, wrapper: string | Element, src: Hyperly): Hype
wrapContextlessly(regex: RegExp, wrapper: string | Element, src: Hyperly): Hype

// from 'hyperly/fp'
wrap(regex: RegExp): (wrapper: string | Element) => (src: Hyperly) => Hype
wrap(options: Options): (regex: RegExp) => (wrapper: string | Element) => (src: Hyperly) => Hype
wrapContextlessly(regex: RegExp): (wrapper: string | Element) => (src: Hyperly) => Hype
```

```js
import { wrap, html } from 'hyperly'

// Single-node match — straightforward wrap.
html(wrap(/\b\w+\b/gi, '<mark />', 'Hello world'))
// → '<mark>Hello</mark> <mark>world</mark>'

// Cross-element match — each portion wrapped separately.
html(wrap(/\b\w+\b/gi, '<mark />', '<p>Hello <b>W</b>orld</p>'))
// → '<p><mark>Hello</mark> <b><mark>W</mark></b><mark>orld</mark></p>'

// A live Element also works (useful when you've configured attributes already).
const tpl = document.createElement('mark')
tpl.className = 'hl'
html(wrap(/world/gi, tpl, '<p>Hello world</p>'))
// → '<p>Hello <mark class="hl">world</mark></p>'
```

Void elements like `<br>`, `<wbr>`, `<input>` cannot be used as wrappers — `wrap` will throw. When the wrapper is dynamic (user input, config, etc.) and you cannot guarantee it is non-void, catch the error:

```js
import { wrap, html } from 'hyperly'

const userWrapper = '<br />'  // ← came from somewhere untrusted

try {
  const result = wrap(/world/gi, userWrapper, '<p>Hello world</p>')
  return html(result)
} catch (e) {
  // e.message === 'Wrapper cannot be a void element.'
  console.warn('falling back to <mark>:', e.message)
  return html(wrap(/world/gi, '<mark />', '<p>Hello world</p>'))
}
```

### `transform`

The low-level engine behind `replace`, `wrap`, and `insert`. Returns a [`Target`](#target) for each portion.

```ts
type Transformer = (portion: SourcePortion) => (match: Match) => Target

// from 'hyperly'
transform(regex: RegExp, transformer: Transformer, src: Hyperly): Hype
transform(options: Options, regex: RegExp, transformer: Transformer, src: Hyperly): Hype
transformContextlessly(regex: RegExp, transformer: Transformer, src: Hyperly): Hype

// from 'hyperly/fp'
transform(regex: RegExp): (transformer: Transformer) => (src: Hyperly) => Hype
transform(options: Options): (regex: RegExp) => (transformer: Transformer) => (src: Hyperly) => Hype
transformContextlessly(regex: RegExp): (transformer: Transformer) => (src: Hyperly) => Hype
```

The `transformer` callback is **curried** in both calling styles — its two arguments arrive in two separate calls:

```js
const transformer = portion => match => /* returns Target */
```

A transformer can return:

- A **string** (interpreted as HTML markup)
- An **Element** (its `outerHTML` is taken; the live element is not moved)
- An **array** of strings / Elements (concatenated)
- An empty string `''` or empty array `[]` to **delete** the matched portion

```js
import { transform, html } from 'hyperly'

// Wrap (return HTML markup including the original text):
html(transform(
  /\b\w+\b/g,
  portion => _m => `<mark>${portion.text}</mark>`,
  '<p>Hello <b>W</b>orld</p>',
))
// → '<p><mark>Hello</mark> <b><mark>W</mark></b><mark>orld</mark></p>'

// Delete (return empty):
html(transform(
  /\s*\(internal\)/g,
  _p => _m => '',
  '<p>Public API (internal) — see docs (internal).</p>',
))
// → '<p>Public API — see docs.</p>'

// Use capture groups via match.captures:
html(transform(
  /(\w+):(\w+)/g,
  _p => match => `<kbd>${match.captures[1]}</kbd>=${match.captures[2]}`,
  '<p>flag:enabled</p>',
))
// → '<p><kbd>flag</kbd>=enabled</p>'
```

### `revert` / `revertAll`

Undo transformation steps tracked in a `Hype`'s history.

```ts
// identical in 'hyperly' and 'hyperly/fp' (single argument, no currying)
revert(hype: Hype): Hype       // undo the last operation
revertAll(hype: Hype): Hype    // undo every operation
```

```js
import { replace, revert, revertAll, html } from 'hyperly'

const h0 = '<p>Hello World</p>'
const h1 = replace(/Hello/g, 'Hi',    h0)
const h2 = replace(/World/g, 'Earth', h1)

html(h2)            // '<p>Hi Earth</p>'
html(revert(h2))    // '<p>Hi World</p>'
html(revertAll(h2)) // '<p>Hello World</p>'
```

## Type Reference

### `Hyperly`

```ts
type Hyperly = string | Element | Hype
```

The accepted source type for almost every operation — see [The `Hyperly` input type](#the-hyperly-input-type).

### `Hype`

```ts
interface Hype {
  tag: 'Hype'
  _1: Element   // the underlying DOM element
  _2: HTMLType  // how the source HTML was parsed
  _3: Node[][]  // transformation history (used by revert)
}
```

The opaque result of any mutating operation. Pass to [`html()`](#utilities) to read out the current HTML, to another operation to chain, or to [`revert`](#revert--revertall) to undo.

### `HTMLType`

```ts
type HTMLType = 'Outer' | 'Inner' | 'BodyOuter' | 'BodyInner'
```

How an HTML string source was parsed into a holder element. Inferred automatically; you rarely need to inspect it.

### `Match`

```ts
interface Match {
  captures:   [string, ...(string | undefined)[]]  // [fullMatch, group1, group2, ...]
  groups:     Record<string, string | undefined>   // named capture groups
  input:      string                                // the context string that was searched
  startIndex: number                                // start position in `input`
  endIndex:   number                                // end position in `input`
  portions:   SourcePortion[]                       // node-level slices of the match
  context:    Node                                  // the context node this match was found within
}
```

`captures[0]` is always the full matched text. `captures[1]` onward are positional capture groups (same layout as `Array.from(str.matchAll(re))[n]`); a group that did not participate in the match is `undefined`.

### `SourcePortion`

```ts
interface SourcePortion {
  node:           Node     // the text node this portion lives in
  text:           string   // the text covered by this portion

  atIndex:        number   // absolute offset within the surrounding context string
  index:          number   // 0-based portion index within the match
  indexInMatch:   number   // char offset from the start of the full match
  indexInNode:    number   // char offset from the start of the text node
  endIndexInNode: number

  start:          boolean  // first portion of the match?
  inner:          boolean  // a middle portion (multi-node spans only)?
  end:            boolean  // last portion of the match?
}
```

A match that spans multiple inline elements (e.g. `Hello` across `<a>H</a>el<b>l</b>o`) is split into one `SourcePortion` per text node. Single-node matches have `start === end === true`.

### `Insertion`

```ts
interface Insertion {
  start?:   Target
  end?:     Target
  between?: Target
  outer?:   boolean
}
```

See [`insert`](#insert) for the full table of behaviours.

### `Target`

```ts
type Target = string | Element | Array<string | Element>
```

The value a transformer or insertion may return. Strings are treated as HTML markup. Elements are serialised to their `outerHTML`. Arrays are concatenated.

### `Options`

```ts
interface Options {
  ignore?:             (node: Node) => boolean
  isContextElement?:   (node: Node) => boolean
  hasContextElements?: (node: Node) => boolean
  isVoidElement?:      (node: Node) => boolean
}
```

Each callback runs synchronously during DOM traversal and must return a plain `boolean`. Omit any key to inherit the default rule; pass `{}` to use all defaults.

#### `ignore(node)` — skip this node entirely

Called for **every** node hyperly visits. Returning `true` makes hyperly leave the node alone: it is not descended into, contributes no text to `textContents`, and will not be a `match` portion. Use this to mask out subtrees that should be invisible to the operation (e.g. a `<noscript>` block, an in-page widget, your own annotations).

**Default:** ignores `<head>`, `<title>`, `<wbr>`, `<hr>`, `<script>`, `<style>`, `<picture>`, replaced media (`<img>`, `<video>`, `<audio>`, `<canvas>`, `<svg>`, `<map>`, `<object>`), form controls (`<input>`, `<textarea>`, `<select>`, `<option>`, `<optgroup>`), HTML comments, and pure-whitespace text nodes (except those directly inside `<html>`).

#### `isContextElement(node)` — treat as a context boundary

Called for non-ignored elements. If `true`, the element opens a fresh **text context**: its content becomes its own entry in `textContents`, and a regex match cannot straddle this element and its siblings/ancestors. Together with `hasContextElements` this is what gives `replace(/foo bar/, …)` the intuitive behaviour of *not* matching across `<p>` boundaries.

**Default:** block-level elements (`<p>`, `<div>`, `<li>`, `<h1>`–`<h6>`, `<section>`, `<article>`, `<nav>`, …), table parts (`<tr>`, `<td>`, `<thead>`, …), replaced media, form controls, and most HTML5 void elements except `<wbr>`. The full list lives in `Data.Hyperly.Options.contextElements`.

#### `hasContextElements(element)` — does this subtree contain a context element?

Called when hyperly meets a non-context element with children. If `false`, hyperly treats the whole subtree as one flat run of text and skips the descent. If `true`, hyperly recurses to find the inner context boundaries. Returning `true` always produces correct output — just slower; `false` is a fast-path commitment that the subtree is "all inline".

**Default:** runs a precompiled regex against `element.innerHTML` matching any context-element opening tag. This was measured to be 2.5–9× faster than `element.querySelector(…)` / `:has(…)` under hyperly's fresh-clone workload (see `CONTRIBUTING.md`).

#### `isVoidElement(node)` — refuse to wrap with this element

Used **only by `wrap`**. When the wrapper element is determined void, `wrap` throws (`"Wrapper cannot be a void element."`) rather than producing HTML the browser would silently discard. The other operations ignore this option.

**Default:** the HTML5 spec void elements (`<area>`, `<base>`, `<br>`, `<col>`, `<embed>`, `<hr>`, `<img>`, `<input>`, `<link>`, `<meta>`, `<param>`, `<source>`, `<track>`, `<wbr>`).

## Error Handling

Unlike the PureScript API (which returns `Either String Hype`), the JavaScript API **throws** on failure. The thrown value is always a real `Error` instance whose `.message` is the PureScript-side error string.

```js
import { replace } from 'hyperly'

try {
  const result = replace(/hello/g, 'Hi', maybeInvalidSource)
} catch (e) {
  // e instanceof Error === true
  console.error(e.message)
}
```

Errors raised by the library:

| Condition | Message |
|---|---|
| Source is not a `string`, `Element`, or `Hype` (`null`, `undefined`, number, …) | `Hyperly only accepts an element or an HTML string as source.` |
| Zero-length match passed to `replace` / `insert` / `transform` / `wrap` (e.g. `/^/g`, `/\b/g`, lookarounds) | `Hyperly cannot transform zero-length matches.` |
| `wrap` called with a void element as the wrapper (`<br>`, `<wbr>`, `<input>`, etc.) | `Wrapper cannot be a void element.` |
| `wrap` called with a wrapper HTML string that does not parse to a single element | `Failed to clone wrapping element.` |
| Underlying DOM operation fails inside `replaceWith` / `insertBeforeStart` / `insertAfterEnd` | The native DOM error message |

## Browser Support

- **Browsers**: ES2022+ baseline. The bundle uses [top-level `await`](https://caniuse.com/mdn-javascript_operators_await_top_level) for happy-dom initialization — supported in Chrome 89+, Edge 89+, Firefox 89+, Safari 15+ (all from 2021 onwards).
- **Node.js**: 22+. Uses [happy-dom](https://github.com/capricorn86/happy-dom) for server-side execution; install it as a peer dependency (`npm install happy-dom`) for SSR use.

## Author

陳奕鈞 Chen Yijun — [@ethantw](https://github.com/ethantw)
