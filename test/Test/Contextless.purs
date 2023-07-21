module Test.Contextless (testContextless) where

import Prelude

import Data.Array (length)
import Data.Hyperly
  ( Boundary(..), Insert(..)
  , insertContextlessly
  , match
  , matchContextlessly
  , replaceContextlessly
  , transformContextlessly
  , wrapContextlessly
  )

import Data.String.Regex.Unsafe (unsafeRegex)
import Data.String.Regex.Flags (RegexFlags, global, ignoreCase, unicode)

import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

import Test.Util
  ( assertHypeHTML
  , itEff
  )

giu :: RegexFlags
giu = global <> ignoreCase <> unicode

testContextless :: Spec Unit
testContextless = describe "Contextless variants" do
  let reHello = unsafeRegex "Hello" giu
      reAorB  = unsafeRegex "a|b" giu

      -- "Hello" is split across two <p> elements
      crossBoundary = "<p>Hel</p><p>lo</p>"

  itEff "matchContextlessly — crosses block boundaries" do
    -- Contextful: each <p> is its own context → "Hel" and "lo" → no match
    match reHello crossBoundary
      >>= \ms -> (length ms) `shouldEqual` 0
    -- Contextless: flat text "Hello" → 1 match
    matchContextlessly reHello crossBoundary
      >>= \ms -> (length ms) `shouldEqual` 1

  itEff "replaceContextlessly — crosses block boundaries" do
    -- "Hel" → "Uni", "lo" → "verse" (replacement sliced across portions)
    replaceContextlessly reHello "Universe"
      crossBoundary
      >>= assertHypeHTML "<p>Uni</p><p>verse</p>"

  itEff "replaceContextlessly — single element" do
    replaceContextlessly (unsafeRegex "ab" giu) "XY"
      "<p>ab</p>"
      >>= assertHypeHTML "<p>XY</p>"

  itEff "wrapContextlessly" do
    -- "a" and "b" (not "c" or "d") are matched in flat "abcd" context
    wrapContextlessly reAorB "em"
      "<p>ab</p><p>cd</p>"
      >>= assertHypeHTML
      "<p><em>a</em><em>b</em></p><p>cd</p>"

  itEff "insertContextlessly" do
    -- Around Inner puts brackets inside the element
    insertContextlessly (unsafeRegex "ab" giu) (Around Inner "[" "|" "]")
      "<p>ab</p>"
      >>= assertHypeHTML "<p>[ab]</p>"

  itEff "transformContextlessly" do
    transformContextlessly reAorB
      (\_ _ -> pure ["!"])
      "<p>ab</p><p>cd</p>"
      >>= assertHypeHTML "<p>!!</p><p>cd</p>"
