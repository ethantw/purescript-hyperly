module Data.Hyperly.Insert
  ( Insert(..), Boundary(..)
  , insertAroundPortion
  ) where

import Prelude

import Data.Array (length)
import Control.Monad.Except (ExceptT(..), runExceptT)
import Data.Either (Either(..))

import Data.Hyperly.DOM
  ( getDocumentByNode
  , insertAfterEnd
  , insertBeforeStart
  , isSameAs
  , replaceWith
  , textToNode
  ) as DOM
import Data.Hyperly.Options (Options)
import Data.Hyperly.Transformer
  (class Target, PortionTransformer, cloneNodes, nodes)

import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))

import Effect (Effect)

import Web.DOM (Element, Node)
import Web.DOM.Document (createTextNode) as DOM
import Web.DOM.Node (nextSibling, parentNode, previousSibling) as DOM

data Insert :: forall k. k -> Type -> Type
data Insert b t =
  Around Boundary t t t
  | Start Boundary t | End Boundary t | Both Boundary t t
  | Between Boundary t

-- | `Boundary` specifies where the insertion should take place relative to the
-- | targeted DOM node of the matched portion.
-- | - `Outer`: The insertion happens outside the current text node's element wrapper
-- |   (e.g., using `insertBeforeStart` or `insertAfterEnd` on the DOM tree).
-- | - `Inner`: The insertion happens inside the text node, directly adjacent to
-- |   the matched text snippet.
data Boundary = Outer | Inner
data Position = Before | After

insertAroundPortion
  :: forall t
   . Target t
  => Record Options
  -> Element
  -> Insert Boundary t
  -> PortionTransformer
insertAroundPortion
  options
  range
  ins
  preceding following
  { text, node, start, end }
  _match
  = do
  doc <- DOM.getDocumentByNode node
  textNode <- DOM.textToNode <$> DOM.createTextNode text doc
  textNodes <- nodes textNode

  emptyTextNode <- DOM.textToNode <$> DOM.createTextNode "" doc

  beforeStart <-
    if start
    then case ins of
      Start Outer t -> cloneNodes t
      Both Outer t _ -> cloneNodes t
      Around Outer t _ _ -> cloneNodes t
      _ -> pure mempty
    else pure mempty

  before <-
    if start
    then case ins of
      Start Inner t -> cloneNodes t
      Both Inner t _ -> cloneNodes t
      Around Inner t _ _ -> cloneNodes t
      _ -> pure mempty
    else pure mempty

  btwn <-
    if not end
    then case ins of
      Between Inner t -> cloneNodes t
      Around Inner _ t _ -> cloneNodes t
      _ -> pure mempty
    else pure mempty

  btwnBoundary <-
    if not end
    then case ins of
      Between Outer t -> cloneNodes t
      Around Outer _ t _ -> cloneNodes t
      _ -> pure mempty
    else pure mempty

  after <-
    if end
    then case ins of
      End Inner t -> cloneNodes t
      Both Inner _ t -> cloneNodes t <> nodes emptyTextNode
      Around Inner _ _ t -> cloneNodes t
      _ -> pure mempty
    else pure mempty

  afterEnd <-
    if end
    then case ins of
      End Outer t -> cloneNodes t <> nodes emptyTextNode
      Both Outer _ t -> cloneNodes t <> nodes emptyTextNode
      Around Outer _ _ t -> cloneNodes t <> nodes emptyTextNode
      _ -> pure mempty
    else pure mempty

  let new = preceding <> before <> textNodes <> btwn <> after <> following

  runExceptT do
    ExceptT $ DOM.replaceWith node new
    ExceptT $ properlyInsertOutside Before textNode beforeStart
    ExceptT $ properlyInsertOutside After textNode (btwnBoundary <> afterEnd)
    pure $ node /\ (new <> beforeStart <> btwnBoundary <> afterEnd)

  where
  { ignore
  , isContextElement
  } = options

  properlyInsertOutside
    :: Position
    -> Node
    -> Array Node
    -> Effect (Either String Unit)
  properlyInsertOutside p n ns =
    if length ns == 0
    then
      pure $ Right mempty
    else
      untilInsertable p n
      >>= case _ of
      Just insertable ->
        case p of
        Before -> DOM.insertBeforeStart insertable ns
        After -> DOM.insertAfterEnd insertable ns
      _ ->
        pure $ Right mempty

  untilInsertable :: Position -> Node -> Effect (Maybe Node)
  untilInsertable p n =
    if n `DOM.isSameAs` range
    then pure $ Just n
    else
    ( case p of
      Before -> DOM.previousSibling n
      After -> DOM.nextSibling n
    )
    >>= case _ of
    Just sibling ->
      ignore sibling
      >>= case _ of
        true ->
          isContextElement sibling
          >>= case _ of
          true ->
            pure $ Just n
          _ ->
            untilInsertable p sibling
        _ ->
          pure $ Just n

    _ ->
      DOM.parentNode n
      >>= case _ of
      Just pn ->
        untilInsertable p pn
      _ ->
        pure Nothing
