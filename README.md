# purescript-hyperly

> **Using JavaScript / TypeScript?** See the [**JavaScript API documentation**](https://github.com/ethantw/purescript-hyperly/blob/main/README.js.md) instead.

Hyperly is a PureScript library for manipulating HTML text content with regular expressions, while preserving the surrounding HTML structure. For example, it can match and replace `/hello/giu` in `<a>H</a>el<b>l</b>o` without breaking the elements or their attributes.

The library provides powerful tools for scraping, finding, and transforming text within HTML documents, with support for both client-side and server-side environments. It handles HTML contexts intelligently to ensure text operations respect element boundaries and semantic structure.

> **Try it live** → [**ethantw.github.io/purescript-hyperly**](https://ethantw.github.io/purescript-hyperly/) — interactive playground for `match` / `replace` / `wrap` / `insert`. Drop in any HTML, tweak the regex, see the result update in real time.

```purescript
import Data.Either (Either(..))
import Data.Hyperly (replace, html)
import Data.String.Regex.Flags (global, ignoreCase)
import Data.String.Regex.Unsafe (unsafeRegex)
import Effect (Effect)
import Effect.Console (error, log)

example :: Effect Unit
example = do
  result <- replace
    (unsafeRegex "world" (global <> ignoreCase))
    "Universe"
    "<p data-keep=\"world\">Hello <b>W</b>orld</p>"
  case result of
    Right hy -> html hy >>= log
    -- → "<p data-keep=\"world\">Hello <b>U</b>niverse</p>"
    --
    -- The match spans <b>W</b> and the trailing 'orld'. Hyperly rewrites both
    -- text nodes correctly without touching the data-keep attribute.
    Left  e  -> error e
```

This project's algorithm is a reference to [findAndReplaceDOMText](https://github.com/padolsey/findAndReplaceDOMText).

## Features

- **Text scraping** — extract text contents from HTML elements with configurable context handling
- **Pattern matching** — find text patterns using regular expressions with full match information
- **Text transformation** — replace, wrap, insert, and transform text portions with custom logic
- **History management** — track and revert text transformation operations step by step
- **Cross-platform** — works in both browser and Node.js (via [happy-dom](https://github.com/capricorn86/happy-dom)) environments
- **Type-safe error handling** — all fallible operations return `Either String Hype`

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Advanced Usage](#advanced-usage)
- [API Reference](#api-reference)
  - [Utilities](#utilities) · [`textContents`](#textcontents) · [`match`](#match) · [`replace`](#replace) · [`insert`](#insert) · [`wrap`](#wrap-1) · [`transform`](#transform) · [`revert` / `revertAll`](#revert--revertall)
- [Type Reference](#type-reference)
  - [`Hyperly`](#hyperly) · [`Hype`](#hype) · [`HTMLType`](#htmltype) · [`Match`](#match-1) · [`Portion`](#portion) · [`Insert` / `Boundary`](#insert--boundary) · [`Target` / `TargetHTML`](#target--targethtml) · [`Wrapper`](#wrapper) · [`Options`](#options)
- [Error Handling](#error-handling)
- [Browser Support](#browser-support)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)
- [Author](#author)

## Installation

For modern Spago (`spago.yaml`), add the following to your `workspace`'s `extraPackages`:

```yaml
workspace:
  extraPackages:
    hyperly:
      git: "https://github.com/ethantw/purescript-hyperly.git"
      ref: "main"
```

Then add `hyperly` to your project's dependencies:

```bash
spago install hyperly
```

## Quick Start

> **Note**
> Mutating operations (`replace`, `insert`, `wrap`, `transform`) return `Effect (Either String Hype)`. Examples in this section show the full `case _ of …` shape once and then elide it for clarity. See [Error Handling](#error-handling) for the full list of error conditions.

### Extracting text contents (plural)

```purescript
import Data.Hyperly (textContents)

example :: Effect (Array String)
example =
  textContents "<div><p>Hello <strong>World</strong></p><p>Another paragraph</p></div>"
-- → ["", "", "Hello World", "Another paragraph"]
--
-- The two leading empties stand in for the (empty) <body> and <div>
-- contexts before their first block-level child; each <p> then
-- contributes one entry.
```

> **Note**
> Each block-level element produces one entry. Loose text or inline content sitting between blocks also produces its own entry. An empty string `""` appears whenever a container has no leading text before its first block-level child. Filter them out with `Array.filter (_ /= "")` if you only need non-empty entries.

### Finding matches

```purescript
import Data.Array.NonEmpty (head) as NEA
import Data.Foldable (for_)
import Data.Hyperly (match)
import Data.String.Regex.Flags (global)
import Data.String.Regex.Unsafe (unsafeRegex)

example :: Effect Unit
example = do
  ms <- match (unsafeRegex "\\b\\w+\\b" global) "<p>Hello <b>W</b>orld!</p>"
  -- ms :: Array Match — each entry contains:
  --
  --   { captures   :: NonEmptyArray String   -- [fullMatch, group1, …]
  --   , context    :: Node                   -- the context node searched
  --   , groups     :: Object String          -- named capture groups
  --   , input      :: String                 -- the context's text content
  --   , startIndex :: Int                    -- start position in input
  --   , endIndex   :: Int                    -- end position in input (exclusive)
  --   , portions   :: Array Portion          -- per-text-node slices
  --   }
  --
  -- For "<p>Hello <b>W</b>orld!</p>" with /\b\w+\b/g you get two matches.
  -- The second one ("World") is split into two portions, since it spans
  -- the <b>W</b> text node and the trailing 'orld' text node.
  for_ ms \m -> do
    log $ NEA.head m.captures <> " @ " <> show m.startIndex
```

### Manipulation

#### Replacement

```purescript
import Data.Hyperly (replace, html)
import Data.String.Regex.Flags (global, ignoreCase)
import Data.String.Regex.Unsafe (unsafeRegex)

example :: Effect (Either String String)
example = do
  result <- replace
    (unsafeRegex "world" (global <> ignoreCase))
    "Universe"
    "<p data-keep=\"world\">Hello World</p>"
  case result of
    Left  e  -> pure (Left e)
    Right hy -> Right <$> html hy
-- → Right "<p data-keep=\"world\">Hello Universe</p>"
-- (Attributes untouched; only visible text replaced.)
```

The replacement string supports the same `$&`, `$1`, `$<name>` back-references as JavaScript's `String.prototype.replace`:

```purescript
result <- replace
  (unsafeRegex "(\\w+)@(\\w+\\.\\w+)" global)
  "<email user=\"$1\" domain=\"$2\">$&</email>"
  "<p>Reach me at alice@example.com.</p>"
-- → "<p>Reach me at <email user=\"alice\" domain=\"example.com\">alice@example.com</email>.</p>"
```

#### Wrap

```purescript
import Data.Hyperly (wrap, html)

example :: Effect (Either String String)
example = do
  result <- wrap
    (unsafeRegex "\\b\\w+\\b" global)
    "<mark />"
    "<p>Hello <b>W</b>orld</p>"
  case result of
    Left  e  -> pure (Left e)
    Right hy -> Right <$> html hy
-- → Right "<p><mark>Hello</mark> <b><mark>W</mark></b><mark>orld</mark></p>"
--
-- Notice "World" spans two nodes (<b>W</b> and 'orld') and each portion
-- gets its own <mark> wrapper.
```

The wrapper can be either a `String` (HTML markup) or a live `Element` — both have `Wrapper` instances.

#### Insertion

```purescript
import Data.Hyperly (insert, html, Insert(..), Boundary(..), TargetHTML(..))

example :: Effect (Either String String)
example = do
  result <- insert
    (unsafeRegex "World" global)
    (Around Outer (TargetHTML "<a>[</a>") (TargetHTML "<b>|</b>") (TargetHTML "<u>]</u>"))
    "<p>Hello <b>W</b><b>o</b>rld</p>"
  case result of
    Left  e  -> pure (Left e)
    Right hy -> Right <$> html hy
-- → Right "<p>Hello <a>[</a><b>W</b><b>|</b><b>o</b><b>|</b>rld<u>]</u></p>"
```

`Insert b t` has five constructors covering different insertion shapes — see [`Insert` / `Boundary`](#insert--boundary) for the full table.

#### Transformation

`transform` is the underlying engine for `replace`, `wrap`, and `insert`. It lets you convert each matched portion into anything that has a `Target` instance: a `String`, `Element`, array of nodes, or even `[]` to delete the match entirely.

```purescript
import Data.Hyperly (transform, html)
import Data.Hyperly.DOM (getDocumentByNode, setInnerHTML)
import Web.DOM.Document (createElement)

example :: Effect (Either String String)
example = do
  result <- transform
    (unsafeRegex "world" (global <> ignoreCase))
    (\{ node, text } _match -> do
        -- The transformer runs in `Effect`, so DOM operations are fine.
        doc <- getDocumentByNode node
        btn <- createElement "button" doc
        setInnerHTML ("Click: " <> text) btn
        pure btn)
    "<p>Hello World</p>"
  case result of
    Left  e  -> pure (Left e)
    Right hy -> Right <$> html hy
-- → Right "<p>Hello <button>Click: World</button></p>"
```

## Core Concepts

### The `Hyperly` type class

`Hyperly` is the input abstraction shared by every operation. Three instances ship out of the box, so you can pass any of them anywhere a `Hyperly h` is expected:

| Instance | Use when |
|---|---|
| `Hyperly String` | You have an HTML fragment as a `String` and want a `String` (via `html`) back. |
| `Hyperly Element` | You have a live DOM `Element` and want it mutated in place. |
| `Hyperly Hype` | You're chaining operations on a previous result. |

```purescript
-- All three forms work the same way:
match regex "<p>foo bar</p>"           -- from String
match regex someElement                -- from Element
match regex (Hype elmt Outer steps)    -- from Hype
```

The class itself exposes the following methods:

```purescript
class Hyperly h where
  htmlType      :: h -> Effect HTMLType
  html          :: h -> Effect String
  element       :: h -> Effect Element
  document      :: h -> Effect Document
  hype          :: h -> Effect Hype
  history       :: h -> Array Steps
  textContents' :: forall o o_. Union o o_ Options
                => Record o -> h -> Effect (Array String)
```

### The `Hype` result type and chaining

Mutating operations (`replace`, `insert`, `wrap`, `transform`) return `Effect (Either String Hype)`. A `Hype` carries the underlying `Element`, its `HTMLType`, and the transformation history (used by `revert` / `revertAll`). Because `Hype` itself has a `Hyperly` instance, you can pass the `Right` value straight into the next operation:

```purescript
import Control.Monad.Except.Trans (ExceptT(..), runExceptT)
import Data.Hyperly (replace, html)
import Effect.Class (liftEffect)

chained :: Effect (Either String String)
chained = runExceptT do
  hy1 <- ExceptT $ replace (unsafeRegex "Hello" global) "Hi"    "<p>Hello World</p>"
  hy2 <- ExceptT $ replace (unsafeRegex "World" global) "Earth" hy1
  liftEffect $ html hy2
-- → Right "<p>Hi Earth</p>"
```

Or threading manually with case analysis:

```purescript
chained' :: Effect (Either String String)
chained' = do
  r1 <- replace (unsafeRegex "Hello" global) "Hi" "<p>Hello World</p>"
  case r1 of
    Left  e   -> pure (Left e)
    Right hy1 -> do
      r2 <- replace (unsafeRegex "World" global) "Earth" hy1
      case r2 of
        Left  e   -> pure (Left e)
        Right hy2 -> Right <$> html hy2
```

### Context-aware vs contextless

Each operation has three variants:

| Variant suffix | Behaviour |
|---|---|
| (no suffix, e.g. `match`) | Context-aware. Block-level elements (`<p>`, `<li>`, `<h1>`, …) form independent contexts; matches do not cross block boundaries. |
| `*Contextlessly` | All text is treated as one flat string, regardless of block structure. |
| `'` (prime, e.g. `match'`) | Custom rules via the [`Options`](#options) record. |

```purescript
import Data.Hyperly (match, matchContextlessly)

let html = "<p>foo</p><p>bar</p>"

ms1 <- match               (unsafeRegex "foobar" global) html
-- length ms1 == 0 — block boundary breaks the match

ms2 <- matchContextlessly  (unsafeRegex "foobar" global) html
-- length ms2 == 1 — text is concatenated flatly: "foobar"
```

### The PureScript naming convention

PureScript follows the Haskell-style **prime suffix** (`'`) for "extended / configurable" siblings of a base function. So:

```purescript
match              :: Regex -> h -> Effect (Array Match)              -- default options
match'             :: Record o -> Regex -> h -> Effect (Array Match)  -- custom options
matchContextlessly :: Regex -> h -> Effect (Array Match)              -- contextless options
```

The pattern repeats for `replace` / `replace'` / `replaceContextlessly`, `insert` / `insert'` / `insertContextlessly`, etc.

## Advanced Usage

### Working with different input types

```purescript
import Data.Hyperly (replace, element, html)
import Web.DOM.ParentNode (QuerySelector(..), querySelector)

-- HTML strings — useful for Node.js / server rendering / string pipelines.
result1 <- replace (unsafeRegex "world" ig) "Universe" "<p>Hello World</p>"

-- Live DOM elements — mutates the element in place. The `Hype` returned by
-- `Right` references the same `Element`, but with history attached.
elmt <- ... -- e.g. via querySelector
result2 <- replace (unsafeRegex "world" ig) "Universe" elmt
case result2 of
  Right hy -> do
    sameNode <- element hy
    -- sameNode === elmt
    pure unit
  _ -> pure unit

-- Hype results — chain operations.
result3 <- case result1 of
  Right hy -> replace (unsafeRegex "Hi" global) "Hello" hy
  Left  e  -> pure (Left e)
```

### Custom transformers

A `Transformer t` is `Target t => Portion -> Match -> Effect t`. The two arguments carry different information:

| | `portion` | `match` |
|---|---|---|
| Scope | One text-node slice of the match | The entire regex match |
| Useful fields | `text`, `node`, `start`, `end`, `inner` | `captures`, `groups`, `startIndex`, `endIndex` |
| Multi-node match | One call per node | Same record passed to each call |

```purescript
import Data.Hyperly (class Hyperly, Hype, transform)
import Data.Hyperly.DOM (elementToNode, getDocumentByNode)
import Web.DOM.Document (createElement)
import Web.DOM.Node (setTextContent)

-- Wrap each match in <mark>:
wrapMarks :: forall h. Hyperly h => h -> Effect (Either String Hype)
wrapMarks =
  transform
    (unsafeRegex "\\b\\w+\\b" global)
    (\{ node, text } _m -> do
        doc <- getDocumentByNode node
        mark <- createElement "mark" doc
        setTextContent text (elementToNode mark)
        pure mark)
```

Returning `[]` (the empty array, typed as `Array String`) deletes the matched portion. Returning a `String` produces a text node. Returning `TargetHTML "..."` parses the string as HTML markup.

### History and reversion

Every mutating operation appends a step to the `Hype`'s history. Use `revert` to undo the last step or `revertAll` to restore the original.

```purescript
import Data.Hyperly (replace, revert, revertAll, html)

example :: Effect Unit
example = do
  Right hy1 <- replace (unsafeRegex "Hello" global) "Hi"     "<p>Hello World</p>"
  Right hy2 <- replace (unsafeRegex "World" global) "Earth"  hy1

  html hy2 >>= log              -- "<p>Hi Earth</p>"

  Right hy3 <- revert hy2
  html hy3 >>= log              -- "<p>Hi World</p>"   (last step undone)

  Right hy4 <- revertAll hy2
  html hy4 >>= log              -- "<p>Hello World</p>" (all steps undone)
```

> **Warning**
> Do not manually remove or replace DOM nodes (e.g. via native `Element.remove`) that are currently being tracked by a `Hype` instance's history. Hyperly relies on those nodes remaining in the tree to revert correctly.

### Custom options

The prime variant of each operation takes an `Options` record to override individual context rules. Any key you omit falls back to the default behaviour.

```purescript
import Data.Array (elem)
import Data.Hyperly (match')
import Data.Hyperly.DOM (lowerNodeName)

-- Treat <span> as a context boundary in addition to the usual block elements:
example :: Effect (Array Match)
example =
  match'
    { isContextElement: \n ->
        pure $ lowerNodeName n `elem` ["span", "p", "li", "h1", "div"] }
    (unsafeRegex "\\b\\w+\\b" global)
    "<p>foo<span>bar</span>baz</p>"
```

### Match semantics — context boundaries

The fundamental purpose of "contextful" mode (the default) is to **prevent matches from spanning across block-element boundaries**. Two adjacent paragraphs are different contexts, and a regex match must live entirely inside one of them:

```purescript
-- Text content of <p>foo</p><p>bar</p> when flattened is "foobar".
-- Contextful mode never sees that flattened form — each <p> is its own string.
match              (unsafeRegex "oob" noFlags) "<p>foo</p><p>bar</p>"
-- → []  (0 matches)

matchContextlessly (unsafeRegex "oob" noFlags) "<p>foo</p><p>bar</p>"
-- → [_]  (1 match, operates on "foobar")
```

This is why `textContents` returns one entry per context: hyperly's regex pipeline runs the pattern **independently against each entry** and concatenates the results. The block boundary acts as a hard wall — a regex cannot match content that straddles it. Without this, `replace (unsafeRegex "foo bar" global) "X" "<h1>End of foo</h1><h2>bar starts</h2>"` would silently merge the two headings.

The `*Contextlessly` family is the explicit escape hatch: it collapses the tree into one flat string and applies plain regex semantics. Use it when block boundaries are noise rather than signal.

#### Consequence: the `global` flag is per-context

A side effect of "the regex runs once per context" is that the `global` flag's meaning is also per-context:

- **Without `global`** — each context yields its first match → up to N matches total (where N = number of contexts).
- **With `global`** — each context yields all its matches.

```purescript
match              (unsafeRegex "foo" noFlags) "<p>foo foo</p><p>foo</p>"
-- → 2 matches  (one per <p>, no global)
match              (unsafeRegex "foo" global)  "<p>foo foo</p><p>foo</p>"
-- → 3 matches
matchContextlessly (unsafeRegex "foo" noFlags) "<p>foo foo</p><p>foo</p>"
-- → 1 match    (flat string, no global)
matchContextlessly (unsafeRegex "foo" global)  "<p>foo foo</p><p>foo</p>"
-- → 3 matches
```

So `replace (unsafeRegex "foo" noFlags) "X" "<p>foo foo</p><p>foo</p>"` rewrites the first `foo` of *each* paragraph (2 substitutions), not "the first `foo` in the whole document". If you want the latter, use `replaceContextlessly` or include `global`.

For comparison with related tools — there is no industry convention here, so hyperly's choice is one of several reasonable ones:

| Approach | Crosses block boundaries? | Without `global` |
|---|---|---|
| Plain string regex | n/a | first match in the string |
| findAndReplaceDOMText (jQuery era) | yes (flattens tree) | first match in the entire tree |
| Mark.js | no (per text node) | first match per text node |
| **hyperly contextful (default)** | **no (per context)** | **first match per context** |
| **hyperly `*Contextlessly`** | **yes (flattens tree)** | **first match in the entire tree** |

## API Reference

Every operation has three variants — the bare name (default options), the `'` prime form (custom options), and the `*Contextlessly` variant. The signatures below show the bare form; the prime form prepends `Record o` as a first argument.

### Utilities

```purescript
hype     :: forall h. Hyperly h => h -> Effect Hype
element  :: forall h. Hyperly h => h -> Effect Element
html     :: forall h. Hyperly h => h -> Effect String
htmlType :: forall h. Hyperly h => h -> Effect HTMLType
document :: forall h. Hyperly h => h -> Effect Document
history  :: forall h. Hyperly h => h -> Array Steps
```

| Function | Returns |
|---|---|
| `hype` | A `Hype` representation of the source (parses HTML strings into a holder element). |
| `element` | The underlying DOM `Element`. |
| `html` | The current HTML string of the source. Use this to read out the result of any operation. |
| `htmlType` | How the source HTML was parsed: `Outer`, `Inner`, `BodyOuter`, or `BodyInner`. |
| `document` | The owning `Document` of the underlying element. |
| `history` | Pure access to the transformation history (an `Array Steps`). |

### `textContents`

```purescript
textContents            :: forall h. Hyperly h => h -> Effect (Array String)
contextlessTextContents :: forall h. Hyperly h => h -> Effect (Array String)
textContents'           :: forall o o_ h. Union o o_ Options => Hyperly h
                        => Record o -> h -> Effect (Array String)
```

Each block-level element and each stretch of loose text or inline content between blocks contributes one entry. An empty `""` appears whenever a container has no leading text before its first block-level child — filter with `Array.filter (_ /= "")` if you only want non-empty entries.

### `match`

```purescript
match              :: forall h. Hyperly h => Regex -> h -> Effect (Array Match)
matchContextlessly :: forall h. Hyperly h => Regex -> h -> Effect (Array Match)
match'             :: forall o o_ h. Union o o_ Options => Hyperly h
                   => Record o -> Regex -> h -> Effect (Array Match)
```

Returns an `Array Match` where each [`Match`](#match) carries `captures`, `groups`, `input`, position indices, and the per-text-node `portions` it spans.

### `replace`

```purescript
replace              :: forall h. Hyperly h => Regex -> String -> h -> Effect (Either String Hype)
replaceContextlessly :: forall h. Hyperly h => Regex -> String -> h -> Effect (Either String Hype)
replace'             :: forall o o_ h. Union o o_ Options => Hyperly h
                     => Record o -> Regex -> String -> h -> Effect (Either String Hype)
```

The replacement string supports `$&`, `$1`, `$<name>` back-references following JavaScript's `String.prototype.replace` rules.

### `insert`

```purescript
insert              :: forall h t. Hyperly h => Target t
                    => Regex -> Insert Boundary t -> h -> Effect (Either String Hype)
insertContextlessly :: forall h t. Hyperly h => Target t
                    => Regex -> Insert Boundary t -> h -> Effect (Either String Hype)
insert'             :: forall o o_ h t. Union o o_ Options => Hyperly h => Target t
                    => Record o -> Regex -> Insert Boundary t -> h -> Effect (Either String Hype)
```

The `Insert b t` data type selects what to insert and how — see [`Insert` / `Boundary`](#insert--boundary) for the five constructors.

```purescript
-- Outer brackets — escape outwards past the surrounding element.
insert
  (unsafeRegex "World" global)
  (Around Outer (TargetHTML "<a>[</a>") (TargetHTML "<b>|</b>") (TargetHTML "<u>]</u>"))
  "<p>Hello <b>W</b>orld</p>"
-- → "<p>Hello <a>[</a><b>W</b>orld<u>]</u></p>"

-- Inner brackets — placed inside the text nodes containing the match.
insert (unsafeRegex "World" global) (Both Inner "[" "]") "<p>Hello <b>W</b>orld</p>"
-- → "<p>Hello <b>[W</b>orld]</p>"
```

### `wrap`

```purescript
wrap              :: forall h w. Hyperly h => Wrapper w
                  => Regex -> w -> h -> Effect (Either String Hype)
wrapContextlessly :: forall h w. Hyperly h => Wrapper w
                  => Regex -> w -> h -> Effect (Either String Hype)
wrap'             :: forall o o_ h w. Union o o_ Options => Hyperly h => Wrapper w
                  => Record o -> Regex -> w -> h -> Effect (Either String Hype)
```

The wrapper can be a `String` (HTML markup containing exactly one element, e.g. `"<mark />"`) or a live `Element`. Matches spanning multiple inline elements get one wrapper per portion. Void elements (`<br>`, `<wbr>`, `<input>`, …) cannot be used as wrappers — `wrap` returns `Left "Wrapper cannot be a void element."`.

### `transform`

```purescript
transform              :: forall h t. Hyperly h => Target t
                       => Regex -> Transformer t -> h -> Effect (Either String Hype)
transformContextlessly :: forall h t. Hyperly h => Target t
                       => Regex -> Transformer t -> h -> Effect (Either String Hype)
transform'             :: forall o o_ h t. Union o o_ Options => Hyperly h => Target t
                       => Record o -> Regex -> Transformer t -> h -> Effect (Either String Hype)
```

Where `Transformer t = Target t => Portion -> Match -> Effect t`.

A transformer can return any `Target t`:

- `String` — produces a text node
- `TargetHTML "..."` — parses as HTML markup
- `Element` — used as-is
- `Array Node` / `Array Element` / `Array String` — concatenated
- `[]` (empty array) — deletes the matched portion entirely

### `revert` / `revertAll`

```purescript
revert    :: Hype -> Effect (Either String Hype)
revertAll :: Hype -> Effect (Either String Hype)
```

`revert` undoes the last operation step recorded in the `Hype`'s history; `revertAll` restores the original element by undoing every step.

## Type Reference

### `Hyperly`

```purescript
class Hyperly h where
  htmlType      :: h -> Effect HTMLType
  html          :: h -> Effect String
  element       :: h -> Effect Element
  document      :: h -> Effect Document
  hype          :: h -> Effect Hype
  history       :: h -> Array Steps
  textContents' :: forall o o_. Union o o_ Options
                => Record o -> h -> Effect (Array String)
```

Instances ship for `String`, `Element`, and `Hype`.

### `Hype`

```purescript
data Hype = Hype Element HTMLType (Array Steps)
```

Result type of every mutating operation. Pass to `html` to read the current HTML, to another operation to chain, or to `revert` / `revertAll` to undo. `Hype` itself has a `Hyperly` instance.

### `HTMLType`

```purescript
data HTMLType = Outer | Inner | BodyOuter | BodyInner
```

How an HTML string source was parsed into a holder element. Inferred automatically; you rarely need to inspect it.

### `Match`

```purescript
type Match =
  { captures   :: NonEmptyArray String      -- [fullMatch, group1, group2, …]
  , context    :: Node                       -- the context node searched
  , groups     :: Object String              -- named capture groups
  , input      :: String                     -- the context's text content
  , startIndex :: Int                        -- start position in `input`
  , endIndex   :: Int                        -- end position in `input` (exclusive)
  , portions   :: Array Portion              -- per-text-node slices of the match
  }
```

`NEA.head captures` is always the full matched text. Subsequent indices are positional capture groups.

### `Portion`

```purescript
type Portion =
  { text           :: String   -- the text covered by this portion
  , node           :: Node     -- the text node this portion lives in

  , atIndex        :: Int      -- absolute offset in the surrounding context string
  , index          :: Int      -- 0-based portion index within the match
  , indexInMatch   :: Int      -- char offset from the start of the full match
  , indexInNode    :: Int      -- char offset from the start of the text node
  , endIndexInNode :: Int

  , start          :: Boolean  -- first portion of the match?
  , inner          :: Boolean  -- a middle portion (multi-node match only)?
  , end            :: Boolean  -- last portion of the match?
  }
```

A match that spans multiple inline elements (e.g. `Hello` across `<a>H</a>el<b>l</b>o`) is split into one `Portion` per text node. Single-node matches have `start == end == true`.

### `Insert` / `Boundary`

```purescript
data Insert b t
  = Around   Boundary t t t   -- start, between, end
  | Start    Boundary t       -- start only
  | End      Boundary t       -- end only
  | Both     Boundary t t     -- start and end (no between)
  | Between  Boundary t       -- between only

data Boundary = Outer | Inner
```

| Constructor | Inserts |
|---|---|
| `Around b s b' e` | `s` before the match, `b'` between every adjacent portion pair, `e` after |
| `Both b s e` | `s` before, `e` after (no between) |
| `Start b s` | `s` before only |
| `End b e` | `e` after only |
| `Between b m` | `m` between portion pairs only |

| Boundary | Where `start` / `end` land |
|---|---|
| `Inner` | Inside the matched text node, adjacent to the matched characters |
| `Outer` | Outside the nearest enclosing element of the start/end portion |

### `Target` / `TargetHTML`

```purescript
class Target t where
  nodes      :: t -> Effect (Array Node)
  cloneNodes :: t -> Effect (Array Node)

newtype TargetHTML = TargetHTML String
```

Instances ship for: `Node`, `Array Node`, `Element`, `Array Element`, `Text`, `Array Text`, `String`, `Array String`, and `TargetHTML`. The `String` instance produces a text node; `TargetHTML "..."` parses the string as HTML markup.

### `Wrapper`

```purescript
class Wrapper w where
  wrapWith :: (Node -> Effect Boolean) -> String -> w -> Effect (Either String Element)
```

Instances ship for `Element` and `String`. The `String` instance accepts an HTML fragment containing exactly one element (e.g. `"<mark />"`, `"<span class='hl' />"`).

### `Options`

```purescript
type Options =
  ( ignore             :: Node -> Effect Boolean
  , isContextElement   :: Node -> Effect Boolean
  , hasContextElements :: Node -> Effect Boolean
  , isVoidElement      :: Node -> Effect Boolean
  )
```

Each prime variant accepts a `Record o` whose row is a sub-row of `Options`. Omitted keys fall back to the defaults defined in `Data.Hyperly.Options`. Pass `{}` to use all defaults.

#### `ignore` — skip this node entirely

Called for **every** node hyperly visits. Returning `pure true` makes hyperly leave the node alone: it is not descended into, contributes no text to `textContents`, and will not be a `match` portion. Use this to mask out subtrees that should be invisible to the operation (e.g. a `<noscript>` block, an in-page widget, your own annotations).

**Default (`ignoreDefault`):** ignores `<head>`, `<title>`, `<wbr>`, `<hr>`, `<script>`, `<style>`, `<picture>`, replaced media (`<img>`, `<video>`, `<audio>`, `<canvas>`, `<svg>`, `<map>`, `<object>`), form controls (`<input>`, `<textarea>`, `<select>`, `<option>`, `<optgroup>`), HTML comments, and pure-whitespace text nodes (except those directly inside `<html>`).

#### `isContextElement` — treat as a context boundary

Called for non-ignored elements. Returning `pure true` means the element opens a fresh **text context**: its content becomes its own entry in `textContents`, and a regex match cannot straddle this element and its siblings/ancestors. Together with `hasContextElements` this is what gives `replace (unsafeRegex "foo bar" global) "…"` the intuitive behaviour of *not* matching across `<p>` boundaries.

**Default (`isContextElementDefault`):** block-level elements (`<p>`, `<div>`, `<li>`, `<h1>`–`<h6>`, `<section>`, `<article>`, `<nav>`, …), table parts (`<tr>`, `<td>`, `<thead>`, …), replaced media, form controls, and most HTML5 void elements except `<wbr>`. The full list lives in `Data.Hyperly.Options.contextElements`.

#### `hasContextElements` — does this subtree contain a context element?

Called when hyperly meets a non-context element with children. Returning `pure false` lets hyperly treat the whole subtree as one flat run of text and skip the descent. Returning `pure true` makes hyperly recurse to find the inner context boundaries. Returning `pure true` always produces correct output — just slower; `pure false` is a fast-path commitment that the subtree is "all inline".

**Default (`hasContextElementsDefault`):** runs a precompiled regex against `innerHTML` matching any context-element opening tag. This was measured to be 2.5–9× faster than `Element.matches ":has(...)"` / `querySelector` under hyperly's fresh-clone workload (see `CONTRIBUTING.md`).

#### `isVoidElement` — refuse to wrap with this element

Used **only by `wrap` / `wrap'`**. When the wrapper element is determined void, the operation returns `Left "Wrapper cannot be a void element."` rather than producing HTML the browser would silently discard. The other operations ignore this option.

**Default (`isVoidElementDefault`):** the HTML5 spec void elements (`<area>`, `<base>`, `<br>`, `<col>`, `<embed>`, `<hr>`, `<img>`, `<input>`, `<link>`, `<meta>`, `<param>`, `<source>`, `<track>`, `<wbr>`).

## Error Handling

Every mutating operation returns `Effect (Either String Hype)`. The `Left` value carries a human-readable error message; `Right` carries the new `Hype`.

```purescript
example :: Effect Unit
example = do
  result <- replace (unsafeRegex "hello" global) "Hi" maybeInvalidSource
  case result of
    Left  err -> error err
    Right hy  -> html hy >>= log
```

Common error conditions:

| Condition | Message |
|---|---|
| Zero-length match passed to `replace` / `insert` / `transform` / `wrap` (e.g. `/^/g`, `/\b/g`, lookarounds) | `Hyperly cannot transform zero-length matches.` |
| `wrap` called with a void element as the wrapper (`<br>`, `<wbr>`, `<input>`, …) | `Wrapper cannot be a void element.` |
| `wrap` called with a wrapper string that does not parse to a single element | `Failed to clone wrapping element.` |
| Underlying DOM operation fails inside `replaceWith` / `insertBeforeStart` / `insertAfterEnd` | The native DOM error message |

`match` and `textContents` do not return `Either` — they cannot fail (zero-length matches simply yield the matches, since no transformation is attempted).

## Browser Support

- **Browsers**: ES2022+ baseline. Specifically the bundle uses [top-level `await`](https://caniuse.com/mdn-javascript_operators_await_top_level) for happy-dom initialization on the server-side branch — supported in Chrome 89+, Edge 89+, Firefox 89+, Safari 15+ (all from 2021 onwards).
- **Node.js**: 22+. Uses [happy-dom](https://github.com/capricorn86/happy-dom) for server-side execution; install it as a peer dependency for SSR use.

## Development

### Prerequisites

- Node.js 22+
- pnpm 9+
- PureScript 0.15+

### Building

```bash
# Install dependencies
pnpm install

# Compile PureScript sources
pnpm compile

# Build the library for npm (lib/hyperly.{js,min.js})
pnpm build

# Build the demo as static assets
pnpm build:demo

# Start dev server for the demo
pnpm start
```

### Testing

```bash
# Run all tests (PS + JS)
pnpm test

# Run only PureScript tests
pnpm test:purs

# Run only JavaScript tests (includes type-checking the .d.ts files)
pnpm test:js
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the developer workflow and coding standards.

## License

This project is licensed under the [MIT License](LICENSE).

## Author

陳奕鈞 Chen Yijun — [@ethantw](https://github.com/ethantw)
