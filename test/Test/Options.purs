module Test.Options (testOptions) where

import Prelude

import Data.Array (length)
import Data.Hyperly (defaultOptions, match, match', replace, replace')
import Data.Hyperly.DOM (lowerNodeName)
import Data.String.Regex.Unsafe (unsafeRegex)

import Effect (Effect)
import Web.DOM (Node)

import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)
import Test.Util (assertHypeHTML, giu, itEff)

-- | The PS counterpart of the JS composition pattern advertised in
-- | `README.js.md`:
-- |
-- | ```js
-- | const isContextElementHan = (node) =>
-- |   defaultOptions.isContextElement(node) && hanCssExtraCheck(node)
-- | ```
-- |
-- | "Default boundary AND not <p>" — a stricter `isContextElement` built on
-- | top of the default's, by composition rather than by reimplementation.
notParagraph :: Node -> Effect Boolean
notParagraph n = do
  isCtxByDefault <- defaultOptions.isContextElement n
  pure $ isCtxByDefault && lowerNodeName n /= "p"

testOptions :: Spec Unit
testOptions = describe "Options composition (defaultOptions.isContextElement)" do

  let helloWorld = unsafeRegex "hello world" giu
      src = "<p>hello</p> world"

  itEff "Bare default: <p> blocks the cross-boundary read" do
    -- <p> is a default boundary, so /hello world/ cannot match across the
    -- <p>/text-node seam.
    match helloWorld src
      >>= \ms -> length ms `shouldEqual` 0

  itEff "Composed (defaultOptions.isContextElement && tag /= 'p'): regex spans" do
    -- Demoting <p> via composition collapses the partition; the regex
    -- now sees "hello" and " world" as one stretch.
    match' { isContextElement: notParagraph } helloWorld src
      >>= \ms -> length ms `shouldEqual` 1

  itEff "Composed predicate carries through replace'" do
    replace' { isContextElement: notParagraph } helloWorld "HW" src
      >>= assertHypeHTML "<p>HW</p>"

  itEff "Bare replace on the same fixture leaves the source untouched" do
    -- Sanity check: the bare path produces no replacement (no match), so
    -- the surface differs observably from the composed path above.
    replace helloWorld "HW" src
      >>= assertHypeHTML "<p>hello</p> world"
