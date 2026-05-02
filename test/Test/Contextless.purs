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
      reAB    = unsafeRegex "ab" giu

      -- "Hello" split across two <p>s — for the cases that need a multi-char
      -- replacement demonstrating per-portion slicing.
      crossBoundary = "<p>Hel</p><p>lo</p>"

      -- Single character per <p>. <p> is a context element, so contextful
      -- match yields zero hits and contextless flattening is the only thing
      -- that makes /ab/ fire. The headline contextless fixture.
      atomicSplit = "<p>a</p><p>b</p>"

      -- Single character per inline element. <a>/<b>/<u>/etc. are NOT
      -- context boundaries (default `isContextElement` only flags block
      -- elements + <br>), so contextful and contextless both fire on /ab/.
      -- These cases pin parity — contextless mode doesn't introduce
      -- surprises when elements happen to be inline.
      inlineSplit = "<a>a</a><b>b</b>"

  itEff "matchContextlessly — crosses block boundaries" do
    -- Contextful: each <p> is its own context → "Hel" and "lo" → no match
    match reHello crossBoundary
      >>= \ms -> (length ms) `shouldEqual` 0
    -- Contextless: flat text "Hello" → 1 match
    matchContextlessly reHello crossBoundary
      >>= \ms -> (length ms) `shouldEqual` 1

  itEff "matchContextlessly — text-level inline elements (parity)" do
    -- Inline elements aren't context boundaries — both modes match.
    match reAB inlineSplit
      >>= \ms -> (length ms) `shouldEqual` 1
    matchContextlessly reAB inlineSplit
      >>= \ms -> (length ms) `shouldEqual` 1

  itEff "replaceContextlessly — crosses block boundaries" do
    -- "Hel" → "Uni", "lo" → "verse" (replacement sliced across portions)
    replaceContextlessly reHello "Universe"
      crossBoundary
      >>= assertHypeHTML "<p>Uni</p><p>verse</p>"

  itEff "replaceContextlessly — text-level inline elements" do
    -- Each portion gets a proportionate slice of the replacement.
    replaceContextlessly reAB "XY"
      inlineSplit
      >>= assertHypeHTML "<a>X</a><b>Y</b>"

  itEff "replaceContextlessly — single element" do
    replaceContextlessly reAB "XY"
      "<p>ab</p>"
      >>= assertHypeHTML "<p>XY</p>"

  itEff "wrapContextlessly — crosses block boundaries" do
    -- Two-portion match wraps separately in each original parent. Contextful
    -- wrap(/ab/) wouldn't fire at all.
    wrapContextlessly reAB "em"
      atomicSplit
      >>= assertHypeHTML "<p><em>a</em></p><p><em>b</em></p>"

  itEff "wrapContextlessly — text-level inline elements" do
    -- Each portion gets wrapped inside its inline parent.
    wrapContextlessly reAB "em"
      inlineSplit
      >>= assertHypeHTML "<a><em>a</em></a><b><em>b</em></b>"

  -- `Around Outer` walks up to the enclosing element boundary (the wrapping
  -- <body> in these fixtures) by skipping empty text-node placeholders that
  -- `Transformer.purs` injects during portion split. The skip is centralised
  -- in `Insert.purs:untilInsertable`; without it, contextless mode (where
  -- `ignore = const false`) would stop at every placeholder and trap
  -- brackets inside the original parent.
  --
  -- Inner places brackets directly in the portion's text flow (no walk-up).
  -- So Inner ≠ Outer in both `start`/`end` (adjacent vs. boundary) and
  -- `between` (end of previous portion's container vs. inter-element gap).

  itEff "insertContextlessly — Around Inner crosses block boundaries" do
    insertContextlessly reAB (Around Inner "[" "|" "]")
      atomicSplit
      >>= assertHypeHTML "<p>[a|</p><p>b]</p>"

  itEff "insertContextlessly — Around Outer crosses block boundaries" do
    insertContextlessly reAB (Around Outer "[" "|" "]")
      atomicSplit
      >>= assertHypeHTML "[<p>a</p>|<p>b</p>]"

  itEff "insertContextlessly — Around Inner with text-level inline elements" do
    -- Inner brackets stay adjacent to the matched text inside the inline
    -- parents, exactly as for the block-level fixture.
    insertContextlessly reAB (Around Inner "[" "|" "]")
      inlineSplit
      >>= assertHypeHTML "<a>[a|</a><b>b]</b>"

  itEff "insertContextlessly — Around Outer with text-level inline elements" do
    -- Outer reaches the enclosing boundary even past inline parents — the
    -- walk-up doesn't care that <a>/<b> aren't context elements.
    insertContextlessly reAB (Around Outer "[" "|" "]")
      inlineSplit
      >>= assertHypeHTML "[<a>a</a>|<b>b</b>]"

  itEff "insertContextlessly — single element" do
    -- Sanity: with no boundary to cross, contextless behaves like contextful
    -- (no `between` because the match has only one portion).
    insertContextlessly reAB (Around Inner "[" "|" "]")
      "<p>ab</p>"
      >>= assertHypeHTML "<p>[ab]</p>"

  itEff "transformContextlessly — crosses block boundaries" do
    -- Two-portion cross-boundary match: the transformer is invoked once per
    -- portion, and each result lands in that portion's original parent.
    transformContextlessly reAB
      (\_ _ -> pure ["X"])
      atomicSplit
      >>= assertHypeHTML "<p>X</p><p>X</p>"

  itEff "transformContextlessly — text-level inline elements" do
    transformContextlessly reAB
      (\_ _ -> pure ["X"])
      inlineSplit
      >>= assertHypeHTML "<a>X</a><b>X</b>"
