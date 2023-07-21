module Data.Hyperly.Options
  ( Options

  , contextElements
  , elementsToBeIgnored

  , defaultOptions
  , contextlessOptions

  , ignoreDefault
  , isContextElementDefault
  , hasContextElementsDefault

  , mergeOptions
  )
  where

import Prelude

import Data.Array (elem)
import Data.Hyperly.DOM
  ( innerHTML
  , isComment, isEmptyTextNode, lowerNodeName, nodeToElement
  )
import Data.String (joinWith)
import Data.String.Regex (Regex, test)
import Data.String.Regex.Flags (ignoreCase)
import Data.String.Regex.Unsafe (unsafeRegex)

import Effect (Effect)
import Prim.Row (class Union)
import Record (merge)
import Unsafe.Coerce (unsafeCoerce)

import Web.DOM (Node)

-- | Options of a set of functions that determine how a visited node should be
-- | handled while scraping the text contents.
-- |
-- | - `ignore` determines whether a visited node should be ignored during
-- |   scraping text contents.
-- | - `isContextElement` determines whether a visited node is a context element
-- |   and belongs to a new context while scraping the text contents.
-- | - `hasContextElements` determines whether a non-text node (element)
-- |   contains context elements.
-- | - `isVoidElement` determines whether a visited node is a void element.
-- |   Only used by `wrap` operations to prevent wrapping void elements.
-- |
type Options =
  ( ignore :: Node -> Effect Boolean
  , isContextElement :: Node -> Effect Boolean
  , hasContextElements :: Node -> Effect Boolean
  , isVoidElement :: Node -> Effect Boolean
  )

-- | Block-level and replaced elements that each establish an independent text
-- | context. Used by `hasContextElementsDefault` to detect whether a parent
-- | node contains any block structure (via `innerHTML` regex), and by
-- | `isContextElementDefault` to classify a node as a context boundary.
contextElements :: Array String
contextElements =
  [ "html", "body"
  , "address", "article", "aside", "blockquote", "dd", "div", "dl"
  , "fieldset", "figcaption", "figure", "footer", "form"
  , "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup"
  , "main", "nav"
  , "ol", "output", "p", "pre", "section", "ul", "br", "li", "summary"
  , "dt", "details", "rp", "rt", "rtc"
  , "script", "style", "noscript"
  , "img", "video", "audio", "canvas", "svg", "map", "object"
  , "input", "textarea", "select", "option", "optgroup", "button"
  , "table", "tbody", "thead"
  , "th", "tr", "td", "caption", "col", "tfoot", "colgroup"
  ]
  -- By default, all void elements, except for <wbr>, are considered context
  -- elements (including <hr>, which is also listed in elementsToBeIgnored).
  <> contextualVoidElements

-- | Elements skipped entirely during node traversal — they contribute no text
-- | content and produce no context of their own.
-- |
-- | Note: `<hr>` appears here AND in `contextElements` (via
-- | `contextualVoidElements`). The two lists serve different purposes:
-- | `contextElements` is used at the *parent* level to detect block structure
-- | (so a container holding `<hr>` is correctly identified as having context
-- | elements and recursed into); `elementsToBeIgnored` is used when the
-- | traversal actually *visits* `<hr>` directly, preventing it from producing
-- | an empty context of its own.
elementsToBeIgnored :: Array String
elementsToBeIgnored =
  [ "head", "title"
  , "wbr", "hr"
  , "script", "style"
  , "img", "picture", "video", "audio", "canvas", "svg", "map", "object"
  , "input", "textarea", "select", "option", "optgroup"
  ]

voidElements :: Array String
voidElements =
  [ "area", "base", "br", "col", "embed", "hr", "img", "input", "link"
  , "meta", "param", "source", "track", "wbr"
  ]

contextualVoidElements :: Array String
contextualVoidElements =
  [ "area", "base", "br", "col", "embed", "hr", "img", "input", "link"
  , "meta", "param", "source", "track"
  ]

-- | Regex compiled once at module load; matches the opening tag of any
-- | element in `contextElements`. Tested against `innerHTML` to detect whether
-- | a subtree contains any context-establishing element.
-- |
-- | Why not `el.matches(":has(...)")`? Both happy-dom and native browsers
-- | run `:has` queries fast on a *reused* element, but cache hits are
-- | impossible in hyperly's workload (every wrap/replace operates on a fresh
-- | clone). Under that fresh-element pattern, this regex outperforms `:has`
-- | by 2.5–9× on happy-dom, and ties or wins on Chrome too. Kept identical
-- | across browser and server for one consistent code path.
contextElementsRegex :: Regex
contextElementsRegex =
  unsafeRegex
    ("<(" <> joinWith "|" contextElements <> ")[ />]")
    ignoreCase

-- | Default options (a set of functions) for scraping text contents.
defaultOptions :: Record Options
defaultOptions =
  { ignore: ignoreDefault
  , isContextElement: isContextElementDefault
  , hasContextElements: hasContextElementsDefault
  , isVoidElement: isVoidElementDefault
  }

-- | Options (a set of functions) for scraping text contents without considering
-- | the element contexts.
contextlessOptions :: Record Options
contextlessOptions =
  { ignore: returnFalse
  , isContextElement: returnFalse
  , hasContextElements: returnFalse
  , isVoidElement: returnFalse
  }
  where
  returnFalse :: forall a. a -> Effect Boolean
  returnFalse _ = pure false

ignoreDefault :: Node -> Effect Boolean
ignoreDefault n =
  if elem (lowerNodeName n) elementsToBeIgnored || isComment n
  then pure true
  else isEmptyTextNode n

isContextElementDefault :: Node -> Effect Boolean
isContextElementDefault n =
  pure $ elem (lowerNodeName n) contextElements

hasContextElementsDefault :: Node -> Effect Boolean
hasContextElementsDefault n =
  innerHTML (nodeToElement n) <#> test contextElementsRegex

isVoidElementDefault :: Node -> Effect Boolean
isVoidElementDefault n =
  pure $ elem (lowerNodeName n) voidElements

mergeOptions
  :: forall o o_
   . Union o o_ Options
  => Record o
  -> Record Options
mergeOptions partial = total
  where
  unsafe :: Record Options
  unsafe = unsafeCoerce partial

  total :: Record Options
  total = merge unsafe defaultOptions
