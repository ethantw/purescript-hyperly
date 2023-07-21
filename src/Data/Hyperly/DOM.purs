module Data.Hyperly.DOM
  ( HTMLType(..)
  , windowEffect

  , createHTMLHolder
  , getHTMLType
  , getHTMLHolderHTML

  , outerHTML, innerHTML
  , bodyOuterHTML, bodyInnerHTML

  , setInnerHTML

  , isTextNode
  , isSameAs
  , isComment
  , isElement

  , isEmptyTextNode

  , getDocumentByElement
  , getDocumentByNode
  , lowerNodeName

  , nodeToElement, elementToNode, textToNode

  , replaceWith
  , removeNodes

  , insertBeforeStart
  , insertAfterEnd

  , textContent
  , advanceWithinRange
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Enum (fromEnum)
import Data.Maybe (Maybe(..))
import Data.String (toLower)

import Effect (Effect)
import Unsafe.Coerce (unsafeCoerce)

import Web.DOM (Document, Element, Node, Text)
import Web.DOM.Node
  (nextSibling, nodeName, nodeTypeIndex, parentNode)
import Web.DOM.NodeType (NodeType(..))
import Web.HTML (Window)

foreign import windowEffect :: Effect Window

data HTMLType = Outer | Inner | BodyOuter | BodyInner

getHTMLHolderHTML :: HTMLType -> Element -> Effect String
getHTMLHolderHTML Outer = outerHTML
getHTMLHolderHTML Inner = innerHTML
getHTMLHolderHTML BodyOuter = bodyOuterHTML
getHTMLHolderHTML BodyInner = bodyInnerHTML

foreign import createHTMLHolder :: String -> Effect Element

foreign import getHTMLTypeImpl
  :: HTMLType
  -> HTMLType
  -> HTMLType
  -> HTMLType
  -> String
  -> Effect HTMLType

getHTMLType :: String -> Effect HTMLType
getHTMLType = getHTMLTypeImpl Outer Inner BodyOuter BodyInner

foreign import outerHTML :: Element -> Effect String
foreign import innerHTML :: Element -> Effect String
foreign import bodyOuterHTML :: Element -> Effect String
foreign import bodyInnerHTML :: Element -> Effect String

foreign import setInnerHTML :: String -> Element -> Effect Unit

foreign import getDocumentByElement :: Element -> Effect Document

getDocumentByNode :: Node -> Effect Document
getDocumentByNode = getDocumentByElement <<< unsafeCoerce

foreign import isSameAs :: forall a b. a -> b -> Boolean

isTextNode :: Node -> Boolean
isTextNode n = fromEnum TextNode == nodeTypeIndex n

isComment :: Node -> Boolean
isComment n = fromEnum CommentNode == nodeTypeIndex n

isElement :: Node -> Boolean
isElement n = fromEnum ElementNode == nodeTypeIndex n

isEmptyTextNode :: Node -> Effect Boolean
isEmptyTextNode n =
  if not $ isTextNode n
  then pure false
  else textContent n >>= \tc ->
    if tc == ""
    then pure true
    else parentNode n >>= case _ of
      Just p -> pure $ lowerNodeName p == "html"
      _ -> pure false

lowerNodeName :: Node -> String
lowerNodeName = toLower <<< nodeName

nodeToElement :: Node -> Element
nodeToElement = unsafeCoerce

elementToNode :: Element -> Node
elementToNode = unsafeCoerce

textToNode :: Text -> Node
textToNode = unsafeCoerce

replaceWith :: Node -> Array Node -> Effect (Either String Unit)
replaceWith = replaceWithImpl Left Right

insertBeforeStart :: Node -> Array Node -> Effect (Either String Unit)
insertBeforeStart = insertBeforeStartImpl Left Right

insertAfterEnd :: Node -> Array Node -> Effect (Either String Unit)
insertAfterEnd = insertAfterEndImpl Left Right

foreign import replaceWithImpl
  :: (String -> Either String Unit)
  -> (Unit -> Either String Unit)
  -> Node
  -> Array Node
  -> Effect (Either String Unit)

foreign import insertBeforeStartImpl
  :: (String -> Either String Unit)
  -> (Unit -> Either String Unit)
  -> Node
  -> Array Node
  -> Effect (Either String Unit)

foreign import insertAfterEndImpl
  :: (String -> Either String Unit)
  -> (Unit -> Either String Unit)
  -> Node
  -> Array Node
  -> Effect (Either String Unit)

foreign import removeNodes :: Array Node -> Effect Unit

-- | If the node type is document fragment, element, text, processing
-- | instruction, or comment this is the node's data, or empty string in all
-- | other cases.
foreign import textContent :: Node -> Effect String

advanceWithinRange :: Element -> Node -> Effect (Maybe Node)
advanceWithinRange range node =
  if range `isSameAs` node
  then pure Nothing
  else
    nextSibling node
    >>= case _ of
    Just n -> pure (Just n)
    _ ->
      parentNode node
      >>= case _ of
      Just p -> advanceWithinRange range p
      _ -> pure Nothing
