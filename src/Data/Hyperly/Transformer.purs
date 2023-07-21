module Data.Hyperly.Transformer
  ( Transformer, PortionTransformer
  , Step, Steps

  , class Target
  , TargetHTML(..)
  , nodes, cloneNodes

  , transformMatches
  , transformPortion
  ) where

import Prelude

import Control.Monad.ST.Class (liftST)
import Control.Monad.ST.Global (Global)
import Data.Array (last, singleton, snoc)
import Data.Array.ST (STArray)
import Data.Array.ST as STA
import Data.Either (Either(..))
import Data.Foldable (foldM, traverse_)

import Data.Hyperly.DOM
  (elementToNode, getDocumentByNode, replaceWith, windowEffect) as DOM
import Data.Hyperly.Match
  (Match, MatchIterator, Portion, stringLength, lazyTake1Match, isZeroLength)
import Data.Hyperly.Options (Options)

import Data.Maybe (Maybe(..))
import Data.String.CodeUnits (slice)
import Data.Traversable (sequence)
import Data.Tuple (Tuple)
import Data.Tuple.Nested ((/\))

import Effect (Effect)
import Unsafe.Coerce (unsafeCoerce)

import Web.DOM (Document, Element, Node, Text)
import Web.DOM.Document (createTextNode) as DOM
import Web.DOM.Node (deepClone, textContent) as DOM
import Web.DOM.Text (toNode) as DOM
import Web.HTML.Window (document) as DOM

-- | `Target` represents data structures that can be converted into the new
-- | content for transforming actions (replacing, inserting, etc). These data
-- | structures include single nodes, elements, text nodes, regular strings,
-- | HTML markup (via `TargetHTML`), or arrays of these items.
-- |
-- | - `nodes` converts a target into *an array of nodes*, preparing them for
-- |   use in transforming actions.
-- | - `cloneNodes` duplicates a target into an array of nodes (deep-cloning
-- |   any live DOM nodes so the original tree is left untouched).
-- |
class Target t where
  nodes :: t -> Effect (Array Node)
  cloneNodes :: t -> Effect (Array Node)

instance targetNodes :: Target (Array Node) where
  nodes ns = pure ns
  cloneNodes ns = sequence $ DOM.deepClone <$> ns

instance targetNode :: Target Node where
  nodes n = nodes [n]
  cloneNodes n = cloneNodes [n]

instance targetElements :: Target (Array Element) where
  nodes es = pure $ unsafeCoerce es
  cloneNodes es = nodes es >>= \ns -> cloneNodes ns

instance targetElement :: Target Element where
  nodes e = nodes [e]
  cloneNodes e = cloneNodes [e]

instance targetTexts :: Target (Array Text) where
  nodes ts = pure $ unsafeCoerce ts
  cloneNodes ts = nodes ts >>= \ns -> cloneNodes ns

instance targetText :: Target Text where
  nodes t = nodes [t]
  cloneNodes t = cloneNodes [t]

instance targetStrings :: Target (Array String) where
  nodes ss = nodesFromStrings ss
  cloneNodes ss = nodes ss

instance targetString :: Target String where
  nodes s = nodes [s]
  cloneNodes s = nodes s

newtype TargetHTML = TargetHTML String

instance targetHTML :: Target TargetHTML where
  nodes (TargetHTML html) =
    ( createNodesFromHTML
      html
      =<< unsafeCoerce <$> (DOM.windowEffect >>= DOM.document)
    )
    >>= case _ of
    Right ns -> pure ns
    _ -> pure []
  cloneNodes h = nodes h

nodesFromStrings :: Array String -> Effect (Array Node)
nodesFromStrings = sequence <<< map toText

toText :: String -> Effect Node
toText s = DOM.windowEffect >>= DOM.document >>= \hd -> do
    t <- DOM.createTextNode s (unsafeCoerce hd)
    pure $ unsafeCoerce t

createNodesFromHTML
  :: String
  -> Document
  -> Effect (Either String (Array Node))
createNodesFromHTML = createNodesFromHTMLImpl Left Right

foreign import createNodesFromHTMLImpl
  :: (String -> Either String (Array Node))
  -> ((Array Node) -> Either String (Array Node))
  -> String
  -> Document
  -> Effect (Either String (Array Node))

-- | `Transformer` represents a function that transforms a match portion into
-- | a `Target` value (nodes, elements, strings of text or HTML).
type Transformer t = Target t => Portion -> Match -> Effect t

type Step = Tuple Node (Array Node)
type Steps = Array Step

transformMatches
  :: Record Options
  -> PortionTransformer
  -> Element
  -> MatchIterator
  -> Effect (Either String Steps)
transformMatches options customTransformPortion range iterator = do
  -- Accumulate steps into a mutable STArray to avoid the O(N²) cost of
  -- repeatedly concatenating Arrays as new matches are produced.
  acc <- liftST STA.new
  result <- fromIterator 0 rangeNode acc
  case result of
    Left e -> pure $ Left e
    _ -> Right <$> liftST (STA.unsafeFreeze acc)

  where
  rangeNode = DOM.elementToNode range

  fromIterator
    :: Int
    -> Node
    -> STArray Global Step
    -> Effect (Either String Unit)
  fromIterator atIndex atNode acc =
    lazyTake1Match options range atIndex atNode iterator
    >>= case _ of
    Just m ->
      if isZeroLength m
      then pure $ Left "Hyperly cannot transform zero-length matches."
      else
      transformMatch m
      >>= case _ of
      Left e -> pure $ Left e
      Right src'tgts -> do
        traverse_ (\x -> liftST $ void $ STA.push x acc) src'tgts
        case last src'tgts of
          Just (_ /\ replacements) ->
            case last replacements of
            Just following ->
              fromIterator m.endIndex following acc

            _ -> -- impossible case
              pure $ Right unit
          _ ->   -- impossible case
            pure $ Right unit
    _ ->
      pure $ Right unit

  foldEithers
    :: (Steps -> Portion -> Effect (Either String Steps))
    -> Array Portion
    -> Effect (Either String Steps)
  foldEithers f ps = foldM folder (Right []) ps
    where
    folder
      :: Either String Steps
      -> Portion
      -> Effect (Either String Steps)
    folder (Right acc) p = f acc p
    folder (Left err) _ = pure $ Left err

  transformMatch :: Match -> Effect (Either String Steps)
  transformMatch m =
    foldEithers
    ( \acc p -> do
      let { node, start, end } = p
      nodeText <- DOM.textContent node
      doc <- DOM.getDocumentByNode node
      let createText = flip DOM.createTextNode $ doc

      preceding <- case start of
        true -> singleton
          <$> DOM.toNode
          <$> ( createText
                $ slice 0 p.indexInNode nodeText
              )
        _ -> pure []

      following <- case end of
        true -> singleton
          <$> DOM.toNode
          <$> ( createText
                $ slice p.endIndexInNode (stringLength nodeText) nodeText
              )
        _ -> pure []

      customTransformPortion preceding following p m
      >>= case _ of
      Right pair -> pure $ Right $ snoc acc pair
      Left e -> pure $ Left e
    )
    m.portions

type PortionTransformer
  =  Array Node                           -- Preceding node singleton
  -> Array Node                           -- Following node singleton
  -> Portion                              -- Current matched portion
  -> Match                                -- Current match
  -> Effect (Either String Step)

transformPortion
  :: forall t
   . Target t
  => Transformer t
  -> PortionTransformer
transformPortion transform preceding following p m =
  (transform p m)
  >>= nodes
  >>= \new ->
    case preceding <> new <> following of
      [] -> nodes [""]
      ns -> pure ns
  >>= \replacements ->
    DOM.replaceWith src replacements
  >>= case _ of
    Left e -> pure $ Left e
    _ -> pure $ Right (src /\ replacements)

  where src = p.node
