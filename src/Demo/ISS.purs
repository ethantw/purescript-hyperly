module Demo.ISS where

import Prelude

import Data.Either (Either(..))

import Data.Hyperly
  ( class Hyperly
  , Boundary(..)
  , Hype
  , Insert(..)
  , TargetHTML(..)
  , hype
  , insert
  )

import Data.String.Regex (Regex)
import Data.String.Regex.Flags (RegexFlags(..))
import Data.String.Regex.Unsafe (unsafeRegex)

import Effect (Effect)

giu :: RegexFlags
giu = RegexFlags
  { global: true
  , ignoreCase: true
  , multiline: false
  , dotAll: false
  , sticky: false
  , unicode: true
  }

insertISS :: forall h. Hyperly h => Boolean -> h -> Effect (Either String Hype)
insertISS useElmt src =
  hype src
  >>= \h ->
    insert ce iss h
  >>= case _ of
  Right h' ->
    insert ec iss h'
  left -> pure left

  where
  cjkv :: String
  cjkv = "\\p{sc=Han}|\\p{sc=Bopomofo}|\\p{sc=Katakana}|\\p{sc=Hiragana}|\\p{sc=Hangul}|[\\u2FF0-\\u2FFA]"

  european :: String
  european = "\\p{sc=Latin}|\\p{sc=Cyrillic}|\\p{sc=Greek}|\\p{sc=Zinh}|\\d"

  puncOpen :: String
  puncOpen = "[‘“\\(\\[\\u00A1\\u00BF\\u2E18\\u00AB\\u2039\\u201A\\u201C\\u201E]"

  puncEnd:: String
  puncEnd = "[”’\\)\\]\\u00BB\\u203A\\u201B\\u201D\\u201F\\u203C\\u203D\\u2047-\\u2049,.;:!?]"

  ce :: Regex
  ce =
    unsafeRegex
    ("(" <> cjkv <> ")" <> "(?=" <> european <> "|" <> puncOpen <> ")")
    giu

  ec :: Regex
  ec =
    unsafeRegex
    ("(" <> european <> "|" <> puncEnd <> ")" <> "(?=" <> cjkv <> ")")
    giu

  iss :: Insert Boundary TargetHTML
  iss = End Outer (TargetHTML if useElmt then "<h-iss> </h-iss>" else " ")
