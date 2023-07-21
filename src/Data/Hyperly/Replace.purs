module Data.Hyperly.Replace (replacePortion) where

import Prelude

import Data.Array (index)
import Data.Array.NonEmpty (index, head) as NEA
import Data.Either (Either(..))
import Data.Hyperly.DOM (replaceWith) as DOM
import Data.Hyperly.Match (stringLength)
import Data.Hyperly.Transformer (PortionTransformer, nodes)
import Data.Int (fromString) as Int
import Data.Maybe (Maybe(..))
import Data.String.CodeUnits (slice) as String
import Data.String.Regex (Regex)
import Data.String.Regex (regex, replace') as String
import Data.String.Regex.Flags (global)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Foreign.Object (lookup)
import Web.DOM.Node (Node)

specialCharsRegex :: Either String Regex
specialCharsRegex = String.regex "\\$(\\$|\\d+|&|`|'|<(\\w+)>)" global

replacePortion :: String -> PortionTransformer
replacePortion replacement preceding following p m =
  replacementNode
  >>= \rn ->
    pure (preceding <> rn <> following)
  >>= \new ->
    DOM.replaceWith old new
  >>= case _ of
    Left e -> pure $ Left e
    _ -> pure $ Right $ old /\ new

  where
  { node: old, end, indexInMatch } = p

  -- Transformed whole replacement string:
  wholeReplacement :: String
  wholeReplacement =
    case specialCharsRegex of
    Right specialChars ->
      String.replace' specialChars transformSpecialChars replacement
    _ -> replacement

  -- An array containing a single text node with the replacement string sliced
  -- to match the length of the current portion.
  --
  -- If the replacement string is longer than the original match, the excess
  -- part will be placed entirely in the end portion.
  replacementNode :: Effect (Array Node)
  replacementNode =
    nodes
    $ String.slice
      indexInMatch
      ( if end
        then stringLength wholeReplacement
        else indexInMatch + (stringLength p.text)
      )
      wholeReplacement

  -- Transforms special replacement patterns in the given string.
  --
  -- [Reference]
  -- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/replace#specifying_a_string_as_the_replacement
  transformSpecialChars :: String -> Array (Maybe String) -> String
  transformSpecialChars _ sps =
    case index sps 0 of
    Just sp -> case sp of
      -- The matched substring `$&`:
      Just "$" -> "$"
      Just "&" -> NEA.head m.captures

      -- Portion of the string that precedes the matched substring `$``:
      Just "`" -> String.slice 0 m.startIndex m.input

      -- Portion of the string that follows the matched substring `$'`:
      Just "'" -> String.slice m.endIndex (stringLength m.input) m.input

      -- Capturing groups (indexed or named):
      Just cg ->
        case Int.fromString cg of
        -- Indexed capturing groups `$1`, `$2`, etc.:
        Just idx ->
          case NEA.index m.captures idx of
          Just ig -> ig
          _ -> "$" <> cg

        -- Named capturing groups `$<groupName>`:
        _ ->
          case index sps 1 of
          Just (Just name) ->
            case lookup name m.groups of
              Just ng -> ng
              _ -> "$" <> cg
          _ -> "$" <> cg
      _ -> ""
    _ -> ""
