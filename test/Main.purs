module Test.Main where

import Prelude
import Prim

import Effect (Effect)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)

import Test.Contextless (testContextless)
import Test.HTML (testHTML)
import Test.Hyperly (testHyperly)
import Test.Insert (testInsert)
import Test.Match (testMatch)
import Test.Piping (testPiping)
import Test.Replace (testReplace)
import Test.Spacing (testInsertSpacing)
import Test.Transform (testTransform)
import Test.Wrap (testWrap)
import Test.ZeroLength (testZeroLength)

foreign import addIteratorPolyfill :: Effect Unit

main :: Effect Unit
main = do
  runSpecAndExitProcess [consoleReporter] do
    testHyperly
    testHTML
    testContextless
    testMatch
    testInsertSpacing
    testWrap
    testReplace
    testTransform
    testPiping
    testZeroLength
    testInsert
