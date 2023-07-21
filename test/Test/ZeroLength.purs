module Test.ZeroLength (testZeroLength) where

import Prelude

import Data.Array (length)

import Data.Hyperly
  (Boundary(..), Insert(..), insert, match, replace, transform, wrap)

import Data.String.Regex.Unsafe (unsafeRegex)

import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

import Test.Util
  (assertHypeLeft, giu, itEff)

testZeroLength :: Spec Unit
testZeroLength = describe "Zero-length match(es)" do

  let lineStart = unsafeRegex "^" giu
  let input = "<p>AB</p>, <p>CD</p>. <section>E<em>F</em>G</section>."

  itEff "Match `/^/giu`" do
    match lineStart input
      >>= \matches -> (length matches) `shouldEqual` 7

  let leftMsg = "Hyperly cannot transform zero-length matches."

  itEff "Try to replace zero-length matches" do
    replace lineStart "%" input
      >>= assertHypeLeft leftMsg

  itEff "Try to wrap zero-length matches with an element" do
    wrap lineStart "em" input
      >>= assertHypeLeft leftMsg

  itEff "Try to insert around zero-length matches" do
    insert lineStart (Around Outer "[" "," "]") input
      >>= assertHypeLeft leftMsg

  itEff "Try to transform zero-length matches" do
    transform lineStart (\_ _ -> pure ["%"]) input
      >>= assertHypeLeft leftMsg
