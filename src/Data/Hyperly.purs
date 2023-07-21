module Data.Hyperly
  ( class Hyperly
  , Hype(..)

  , htmlType, html, element, document, hype, history

  , module HO
  , textContents', textContents, contextlessTextContents

  , module HM
  , match', match, matchContextlessly

  , module HT
  , transform', transform, transformContextlessly
  , replace', replace, replaceContextlessly

  , module HI
  , insert', insert, insertContextlessly

  , module HW
  , wrap', wrap, wrapContextlessly

  , revert, revertAll
  ) where

import Prelude

import Data.Array (concat, init, last, snoc)
import Data.Either (Either(..))
import Data.Hyperly.DOM (HTMLType(..))
import Data.Hyperly.DOM (createHTMLHolder, getDocumentByElement, getHTMLHolderHTML, getHTMLType) as DOM
import Data.Hyperly.Insert (Boundary, Insert, insertAroundPortion)
import Data.Hyperly.Insert (Insert(..), Boundary(..)) as HI
import Data.Hyperly.Match (Match, MatchIterator, matchAllDefault, lazyMatchAllDefault)
import Data.Hyperly.Match (Match, Portion, MatchIterator) as HM
import Data.Hyperly.Options (Options, contextlessOptions, defaultOptions) as HO
import Data.Hyperly.Options (Options, contextlessOptions, defaultOptions, mergeOptions)
import Data.Hyperly.Replace (replacePortion)
import Data.Hyperly.Revert (revertAllSteps, revertSteps)
import Data.Hyperly.TextContents (textContentsByContext)
import Data.Hyperly.Transformer (class Target, PortionTransformer, Steps, Transformer, transformMatches, transformPortion)
import Data.Hyperly.Transformer (class Target, TargetHTML(..), Step, Steps, Transformer) as HT
import Data.Hyperly.Wrap (class Wrapper, wrapPortion)
import Data.Hyperly.Wrap (class Wrapper) as HW
import Data.Maybe (Maybe(..))
import Data.String.Regex (Regex)
import Data.Tuple (snd)
import Effect (Effect)
import Prim.Row (class Union)
import Web.DOM (Document, Element)

-- | `Hyperly` represents data structures that is or can be converted to an HTML
-- | element. The text contents within the element can be properly scraped based
-- | on the configured options via the `textContents` function.
-- |
-- | - `htmlType` returns the type of how a structure will be converted to HTML.
-- | - `html` returns the HTML of a structure.
-- | - `element` returns the HTML element of a structure.
-- | - `document` returns the `window.document` of a structure.
-- | - `hype` returns an Hype data type containing the element, the HTML type,
-- |   and the history of steps of transforming operations.
-- | - `textContents` returns the text contents of a structure based on options.
-- | - `history` returns the history steps of transforming operations.
-- |
class Hyperly h where
  htmlType :: h -> Effect HTMLType
  html :: h -> Effect String
  element :: h -> Effect Element
  document :: h -> Effect Document
  hype :: h -> Effect Hype
  history :: h -> Array Steps

  textContents'
    :: forall o o_
     . Union o o_ Options
    => Record o
    -> h
    -> Effect (Array String)

data Hype = Hype Element HTMLType (Array Steps)

textContentsDefault
  :: forall o o_
   . Union o o_ Options
  => Record o
  -> Element
  -> Effect (Array String)
textContentsDefault o e =
  pure
    <<< map snd
    =<< textContentsByContext o' e
  where
  o' = mergeOptions o

instance hyperlyHTML :: Hyperly String where
  document h = element h >>= document
  htmlType = DOM.getHTMLType
  html = pure
  element = DOM.createHTMLHolder
  hype h = element h >>= \el -> htmlType h >>= \ty ->
    pure $ Hype el ty []
  history _ = []
  textContents' o html = textContents' o =<< hype html

instance hyperlyElement :: Hyperly Element where
  document h = element h >>= DOM.getDocumentByElement
  htmlType _ = pure Outer
  html = DOM.getHTMLHolderHTML Outer
  element = pure
  hype elmt = pure $ Hype elmt Outer []
  history _ = []
  textContents' = textContentsDefault

instance hyperlyHype :: Hyperly Hype where
  document (Hype h _ _) = element h >>= document
  htmlType (Hype _ t _) = pure t
  html (Hype e t _) = DOM.getHTMLHolderHTML t e
  element (Hype e _ _) = pure e
  hype = pure
  history (Hype _ _ steps) = steps
  textContents' o (Hype e _ _) = textContentsDefault o e

-- | Scrapes the text contents within a Hyperly instance using the default
-- | configurations.
-- |
-- | Each block-level context element (e.g. `<p>`, `<h1>`, `<li>`) produces one
-- | entry in the result array. Elements in `elementsToBeIgnored` (e.g. `<hr>`,
-- | `<img>`) produce no entry; context boundaries between adjacent block
-- | elements produce an empty string `""`. Consumers should filter out `""`
-- | entries if only non-empty text contents are needed.
textContents :: forall h. Hyperly h => h -> Effect (Array String)
textContents = textContents' defaultOptions

-- | Scrapes the text contents within a Hyperly instance contextlessly,
-- | treating all text nodes as one flat string regardless of element
-- | boundaries. Returns a singleton array containing the concatenated text.
contextlessTextContents :: forall h. Hyperly h => h -> Effect (Array String)
contextlessTextContents = textContents' contextlessOptions

-- | Matches the text contents within a Hyperly instance against the `Regex` and
-- | returns an array of the matches if there were any; otherwise, an empty
-- | array. The function uses the given `options` configurations to first scrape
-- | text contents and then match the given pattern in these text contents.
-- |
-- | A `Match` is a record containing:
-- |
-- | - `content`: An array of the matched text and capturing groups within.
-- | - `groups`: The foreign object of named capturing groups, if any.
-- | - `input`: The original original text content string.
-- | - `startIndex`: The starting index of the match.
-- | - `endIndex`: The ending index of the match.
-- | - `portions`: An array of matched portion objects, which may be spread
-- |    across one or multiple nodes.
-- |
match'
  :: forall o o_ h
   . Union o o_ Options
  => Hyperly h
  => Record o
  -> Regex
  -> h
  -> Effect (Array Match)
match' o r h = do
  hy <- hype h
  elmt <- element hy

  textContentsByContext o' elmt
    >>= matchAllDefault o' r elmt
    >>= \mss -> pure $ concat mss

  where
  o' = mergeOptions o

-- | Matches the text contents within a Hyperly instance using the default
-- | configurations.
match :: forall h . Hyperly h => Regex -> h -> Effect (Array Match)
match = match' defaultOptions

matchContextlessly :: forall h . Hyperly h => Regex -> h -> Effect (Array Match)
matchContextlessly = match' contextlessOptions

-- | Transforms the text contents within a Hyperly data structure using a passed
-- | in `Transformer` function, returning a Hype data type.
-- |
transform'
  :: forall o o_ h t
   . Union o o_ Options
  => Hyperly h
  => Target t
  => Record o
  -> Regex
  -> Transformer t
  -> h
  -> Effect (Either String Hype)
transform' o r t h = do
  hype <- hype h
  e <- element hype
  es <- transformDefault o r t e
  addHistory es hype

transform
  :: forall h t
   . Hyperly h
  => Target t
  => Regex
  -> Transformer t
  -> h
  -> Effect (Either String Hype)
transform = transform' defaultOptions

transformContextlessly
  :: forall h t
   . Hyperly h
  => Target t
  => Regex
  -> Transformer t
  -> h
  -> Effect (Either String Hype)
transformContextlessly = transform' contextlessOptions

addHistory
  :: forall h
   . Hyperly h
  => Either String Steps
  -> h
  -> Effect (Either String Hype)
addHistory steps h =
  case steps of
  Left e -> pure $ Left e
  Right s -> do
    ht <- htmlType h
    e <- element h
    pure $ Right $ Hype e ht $ snoc (history h) s

lazyMatchAll
  :: Record Options
  -> Regex
  -> Element
  -> Effect MatchIterator
lazyMatchAll o r e =
  textContentsByContext o e
  >>= pure <<< (lazyMatchAllDefault r)

transformDefault
  :: forall o o_ t
   . Union o o_ Options
  => Target t
  => Record o
  -> Regex
  -> Transformer t
  -> Element
  -> Effect (Either String Steps)
transformDefault o r t e =
  lazyMatchAll o' r e
  >>= transformMatches o' pt e

  where
  o' :: Record Options
  o' = mergeOptions o

  pt :: PortionTransformer
  pt = transformPortion t

replace'
  :: forall o o_ h
   . Union o o_ Options
  => Hyperly h
  => Record o
  -> Regex
  -> String
  -> h
  -> Effect (Either String Hype)
replace' o r replacement h = do
  hype <- hype h
  e <- element hype
  es <- replaceDefault o r replacement e
  addHistory es hype

replace
  :: forall h
   . Hyperly h
  => Regex
  -> String
  -> h
  -> Effect (Either String Hype)
replace = replace' defaultOptions

replaceContextlessly
  :: forall h
   . Hyperly h
  => Regex
  -> String
  -> h
  -> Effect (Either String Hype)
replaceContextlessly = replace' contextlessOptions

replaceDefault
  :: forall o o_
   . Union o o_ Options
  => Record o
  -> Regex
  -> String
  -> Element
  -> Effect (Either String Steps)
replaceDefault o r replacement e =
  lazyMatchAll o' r e
  >>= transformMatches o' pt e
  where
  o' :: Record Options
  o' = mergeOptions o

  pt :: PortionTransformer
  pt = replacePortion replacement

-- | Inserts texts and/or elements around the matched portions within a Hyperly
-- | data structure via `Insert` data type.
-- |
insert'
  :: forall o o_ h t
   . Union o o_ Options
  => Hyperly h
  => Target t
  => Record o
  -> Regex
  -> Insert Boundary t
  -> h
  -> Effect (Either String Hype)
insert' o r i h = do
  hype <- hype h
  e <- element hype
  es <- insertDefault o r i e
  addHistory es hype

insert
  :: forall h t
   . Hyperly h
  => Target t
  => Regex
  -> Insert Boundary t
  -> h
  -> Effect (Either String Hype)
insert = insert' defaultOptions

insertContextlessly
  :: forall h t
   . Hyperly h
  => Target t
  => Regex
  -> Insert Boundary t
  -> h
  -> Effect (Either String Hype)
insertContextlessly = insert' contextlessOptions

insertDefault
  :: forall o o_ t
   . Union o o_ Options
  => Target t
  => Record o
  -> Regex
  -> Insert Boundary t
  -> Element
  -> Effect (Either String Steps)
insertDefault o r i e =
  lazyMatchAll o' r e
  >>= transformMatches o' pt e

  where
  o' :: Record Options
  o' = mergeOptions o

  pt :: PortionTransformer
  pt = insertAroundPortion o' e i

-- | Wrapper the matched portion texts with an designated element within a
-- | Hyperly data structure via `Wrapper` data type.
-- |
wrap'
  :: forall o o_ h w
   . Union o o_ Options
  => Hyperly h
  => Wrapper w
  => Record o
  -> Regex
  -> w
  -> h
  -> Effect (Either String Hype)
wrap' o r w h = do
  hype <- hype h
  e <- element hype
  es <- wrapDefault o r w e
  addHistory es hype

wrap
  :: forall h w
   . Hyperly h
  => Wrapper w
  => Regex
  -> w
  -> h
  -> Effect (Either String Hype)
wrap = wrap' defaultOptions

wrapContextlessly
  :: forall h w
   . Hyperly h
  => Wrapper w
  => Regex
  -> w
  -> h
  -> Effect (Either String Hype)
wrapContextlessly = wrap' contextlessOptions

wrapDefault
  :: forall o o_ w
   . Union o o_ Options
  => Wrapper w
  => Record o
  -> Regex
  -> w
  -> Element
  -> Effect (Either String Steps)
wrapDefault o r w e =
  lazyMatchAll o' r e
  >>= transformMatches o' pt e
  where
  o' :: Record Options
  o' = mergeOptions o

  pt :: PortionTransformer
  pt = wrapPortion o' w

-- | Revert one set of steps of replacing or inserting operation in the history
-- | of a Hype data type.
-- |
revert :: Hype -> Effect (Either String Hype)
revert (Hype elmt htmlType history) = case last history of
  Just steps ->
    revertSteps steps >>= case _ of
      Left e -> pure $ Left e
      _ -> pure $ Right nextHype
  _ -> pure $ Right nextHype

  where
  nextHype = case init history of
    Nothing -> Hype elmt htmlType []
    Just as -> Hype elmt htmlType as

-- | Revert all sets of steps of replacing or inserting operations in the
-- | history of a Hype data type to its initial state.
-- |
revertAll :: Hype -> Effect (Either String Hype)
revertAll (Hype elmt htmlType history) =
  revertAllSteps history >>= case _ of
  Left e -> pure $ Left e
  _ -> pure $ Right $ Hype elmt htmlType []
