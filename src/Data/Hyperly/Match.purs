module Data.Hyperly.Match
  ( Match
  , Portion

  , MatchIterator

  , stringLength
  , isZeroLength

  , matchAllDefault
  , lazyMatchAllDefault

  , lazyTake1Match
  ) where

import Prelude

import Data.Array (last, length, snoc)
import Data.Array.NonEmpty (NonEmptyArray)
import Data.Traversable (traverse)
import Data.Hyperly.DOM (advanceWithinRange, isElement, isTextNode) as DOM
import Data.Hyperly.Options (Options)
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits (slice)
import Data.String.Regex (Regex)
import Data.Tuple (Tuple)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Foreign.Object (Object)
import Record (modify)
import Type.Proxy (Proxy(..))
import Web.DOM (Element, Node)
import Web.DOM.Node (firstChild, textContent) as DOM

foreign import stringLength :: String -> Int

type Match =
  { captures :: NonEmptyArray String
  , context :: Node

  , groups :: Object String
  , input :: String

  , startIndex :: Int
  , endIndex :: Int

  , portions :: Array Portion
  }

type Portion =
  { text :: String

  , atIndex :: Int
  , node :: Node

  , index :: Int
  , indexInMatch :: Int

  , indexInNode :: Int
  , endIndexInNode :: Int

  , start :: Boolean
  , inner :: Boolean
  , end :: Boolean
  }

foreign import data MatchIterator :: Type
foreign import combineIterators :: Array MatchIterator -> MatchIterator

foreign import stringMatchAllImpl
  :: (Maybe Match)
  -> (Match -> Maybe Match)
  -> (Node -> MatchIterator -> Tuple Node MatchIterator)
  -> Node
  -> Regex
  -> String
  -> MatchIterator

stringMatchAll :: Node -> Regex -> String -> MatchIterator
stringMatchAll = stringMatchAllImpl Nothing Just (/\)

foreign import take1Impl
  :: (Maybe Match)
  -> (Match -> Maybe Match)
  -> MatchIterator
  -> Maybe (Tuple (Maybe Node) Match)

take1 :: MatchIterator -> Maybe (Tuple (Maybe Node) Match)
take1 = take1Impl Nothing Just

isZeroLength :: Match -> Boolean
isZeroLength m = m.startIndex == m.endIndex

prepareMatchWithPortions
  :: Record Options
  -> Element
  -> Int
  -> Node
  -> Match
  -> Effect Match
prepareMatchWithPortions options range atIndex' atNode' match =
  prepareMatch =<< preparePortions [] atIndex' (Just atNode')

  where
  { ignore } = options
  { startIndex, endIndex } = match

  advance = DOM.advanceWithinRange range
  zeroLength = isZeroLength match

  prepareMatch :: Array Portion -> Effect Match
  prepareMatch portions =
    pure
    $ modify
      (Proxy :: Proxy "portions")
      (const portions)
      match

  preparePortions
    :: Array Portion
    -> Int
    -> Maybe Node
    -> Effect (Array Portion)
  preparePortions portions atIndex atNode = case atNode of
    Nothing -> pure portions
    Just node ->
      -- If the node should be ignored, go forward:
      ignore node
      >>= case _ of
      true ->
        preparePortions portions atIndex
        =<< advance node

      _ ->
        -- Found an element, go inside or go forward:
        if DOM.isElement node
        then
          preparePortions portions atIndex
          =<< (
            DOM.firstChild node
            >>= case _ of
              Just fc -> pure $ Just fc
              _ -> advance node
          )

        -- Not a text node yet, go forward:
        else if not $ DOM.isTextNode node
        then
          preparePortions portions atIndex
          =<< advance node

        -- Found a text node. Check if it is within the match's range:
        else do
          text <- DOM.textContent node

          let
            textCount = stringLength text
            newAtIndex = atIndex + textCount
            portionCount = length portions

            started =
              if zeroLength
              then newAtIndex >= startIndex
              else newAtIndex > startIndex

            start = portionCount == 0 && started
            inner = portionCount > 0 && newAtIndex < endIndex
            end   = newAtIndex >= endIndex

          -- Not within the matched range yet, keep going with the updated
          -- `atIndex`:
          if not started
          then
            preparePortions portions newAtIndex
            =<< advance node

          -- Found the text node within the match's range:
          --
          else if zeroLength
          then
            -- If the current match is zero-length, prepare and return the
            -- portion.
            pure [
              { node
              , text: ""

              , atIndex
              , index: 0
              , indexInMatch: 0
              , indexInNode: startIndex - atIndex
              , endIndexInNode: startIndex - atIndex

              , start
              , inner
              , end
              }]

          -- Regular (Non-zero-length) match:
          else
            preparePortions
              ( if start
                -- The start portion is within the current node. Prepare the
                -- portions now:
                then
                  [
                    { node
                    , text:
                      slice (startIndex - atIndex) (endIndex - atIndex) text

                    , atIndex
                    , index: 0
                    , indexInMatch: 0
                    , indexInNode: startIndex - atIndex
                    , endIndexInNode: endIndex - atIndex

                    , start
                    , inner
                    , end
                    }
                  ]

                -- Concat the inner portion(s) if there are ones:
                else if inner
                then
                  snoc
                    portions
                    { node
                    , text

                    , atIndex
                    , index: length portions
                    , indexInMatch: atIndex - startIndex
                    , indexInNode: 0
                    , endIndexInNode: -1

                    , start
                    , inner
                    , end
                    }

                -- Finally, concat the end portion:
                else
                  snoc
                    portions
                    { node
                    , text: slice 0 (endIndex - atIndex) text

                    , atIndex
                    , index: length portions
                    -- Return 0 if it's the first match:
                    , indexInMatch:
                      if atIndex == 0 then 0 else atIndex - startIndex
                    , indexInNode: 0
                    , endIndexInNode: endIndex - atIndex

                    , start
                    , inner
                    , end
                    }
              )
              newAtIndex
              =<<
              -- Not the end yet, keep going with the updated `atIndex`,
              -- `portions` and the advanced node:
              case not end of
              true -> advance node

              -- The end is reached, stop going forward:
              _ -> pure Nothing

matchAllDefault
  :: Record Options
  -> Regex
  -> Element
  -> Array (Tuple Node String)
  -> Effect (Array (Array Match))
matchAllDefault options pattern range tcs =
  traverse (prepareTextContentMatches options range pattern) tcs

prepareTextContentMatches
  :: Record Options
  -> Element
  -> Regex
  -> Tuple Node String
  -> Effect (Array Match)
prepareTextContentMatches options range pattern (context /\ tc) =
  fromIterator
    0
    context
    (stringMatchAll context pattern tc)
    []

  where
  fromIterator
    :: Int
    -> Node
    -> MatchIterator
    -> Array Match
    -> Effect (Array Match)
  fromIterator atIndex atNode iterator acc =
    case take1 iterator of
      Nothing -> pure acc
      Just (_ /\ m) ->
        prepareMatchWithPortions
          options
          range
          atIndex
          atNode
          m
        >>=
        \m' ->
          case last m'.portions of
          Just p ->
            fromIterator p.atIndex p.node iterator $ snoc acc m'

          -- `Nothing` is a rather impossible case, for all matches will have at
          -- least one portion.
          _ ->
            pure acc

lazyMatchAllDefault
  :: Regex
  -> Array (Tuple Node String)
  -> MatchIterator
lazyMatchAllDefault pattern =
  combineIterators
  <<< map lazyPrepareTextContentMatches

  where
  lazyPrepareTextContentMatches
    :: Tuple Node String
    -> MatchIterator
  lazyPrepareTextContentMatches (context /\ tc) =
    stringMatchAll context pattern tc

lazyTake1Match
  :: Record Options
  -> Element
  -> Int
  -> Node
  -> MatchIterator
  -> Effect (Maybe Match)
lazyTake1Match options range atIndex atNode iterator =
  case take1 iterator of
  Just (Just context /\ match) ->
    Just <$> prepare 0 context match
  Just (_ /\ match) ->
    Just <$> prepare atIndex atNode match
  _ ->
    pure Nothing

  where
  prepare = prepareMatchWithPortions options range
