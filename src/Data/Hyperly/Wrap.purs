module Data.Hyperly.Wrap
  ( class Wrapper
  , wrapWith
  , wrapPortion
  ) where

import Prelude

import Control.Monad.Except (ExceptT(..), runExceptT)
import Data.Either (Either(..))

import Data.Hyperly.DOM (elementToNode, replaceWith, windowEffect) as DOM
import Data.Hyperly.Options (Options)
import Data.Hyperly.Transformer (PortionTransformer, cloneNodes)

import Data.Tuple.Nested ((/\))

import Effect (Effect)
import Unsafe.Coerce (unsafeCoerce)

import Web.DOM (Document, Element, Node)
import Web.DOM.Node (setTextContent)
import Web.HTML.Window (document)

class Wrapper w where
  wrapWith
    :: (Node -> Effect Boolean)
    -> String
    -> w
    -> Effect (Either String Element)

instance wrapperElement :: Wrapper Element where
  wrapWith isVoidElement text elmt =
    cloneNodes elmt
    >>= case _ of
    [node] ->
      isVoidElement node
      >>= case _ of
      false -> do
        setTextContent text node
        pure $ Right $ unsafeCoerce node
      _ -> pure $ Left "Wrapper cannot be a void element."
    _ -> pure $ Left "Failed to clone wrapping element."

instance wrapperString :: Wrapper String where
  wrapWith isVoidElement text html = do
    doc <- DOM.windowEffect >>= document
    runExceptT do
      elmt <- ExceptT $ createWrapperElmt html $ unsafeCoerce doc
      ExceptT $ wrapWith isVoidElement text elmt

foreign import createWrapperElmtImpl
  :: (String -> Either String Element)
  -> (Element -> Either String Element)
  -> String
  -> Document
  -> Effect (Either String Element)

createWrapperElmt :: String -> Document -> Effect (Either String Element)
createWrapperElmt = createWrapperElmtImpl Left Right

wrapPortion
  :: forall w
   . Wrapper w
  => Record Options
  -> w
  -> PortionTransformer
wrapPortion o w preceding following p _m =
  runExceptT do
    elmt <- ExceptT $ wrapWith isVoidElement text w
    let replacements = preceding <> [DOM.elementToNode elmt] <> following
    ExceptT $ DOM.replaceWith src replacements
    pure (src /\ replacements)

  where
  { isVoidElement } = o
  { node: src, text } = p
