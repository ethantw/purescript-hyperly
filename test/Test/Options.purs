module Test.Options (testOptions) where

import Prelude

import Data.Array (length)
import Data.Hyperly (defaultOptions, match, match', replace, replace', textContents, textContents')
import Data.Hyperly.DOM (isComment, lowerNodeName)
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

-- | Custom ignore that hides every `<u>` element. `<u>` is **not** in
-- | `contextElements` and has non-empty textContent — exactly the shape
-- | that triggers the D-branch leak `ignoreAwareTextContent` was added to
-- | fix.
ignoreUTags :: Node -> Effect Boolean
ignoreUTags n = do
  ignoredByDefault <- defaultOptions.ignore n
  pure $ ignoredByDefault || lowerNodeName n == "u"

-- | Custom ignore that hides DOM Comment nodes — used to confirm the fix
-- | doesn't change the comment-handling behaviour (which already worked,
-- | because `Element.textContent` excludes Comment descendants per spec).
ignoreComments :: Node -> Effect Boolean
ignoreComments n = pure $ isComment n

testOptions :: Spec Unit
testOptions = do
  describe "Options composition (defaultOptions.isContextElement)" do

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

  describe "Custom ignore: D branch (no inner context elements)" do
    -- Reproducer for the bug fixed in 0.2.0-rc.2: when a custom `ignore`
    -- predicate matches an element NOT in `contextElements`, the previous
    -- `DOM.textContent atNode` shortcut in TextContents.purs's D branch
    -- would leak that element's text into the context string. The regex
    -- then matched against the leaked text, and `prepareMatchWithPortions`
    -- (which DOES respect ignore) slid the match onto the next visible
    -- text node — a wrong fire on adjacent content.
    --
    -- After the fix, the context string excludes the ignored subtree.

    let skipped = unsafeRegex "SKIPPED" giu

    itEff "context string excludes ignored <u> subtree" do
      -- <p> has no inner context elements (no nested block), so it lands in
      -- the D branch. With the fix, "SKIPPED" is excluded.
      -- (Leading "" is the body's pre-<p> context — intentional per design.)
      textContents' { ignore: ignoreUTags }
        "<p>before<u>SKIPPED</u>after</p>"
        >>= \tcs -> tcs `shouldEqual` ["", "beforeafter"]

    itEff "/SKIPPED/ has 0 matches (was incorrectly 1 before fix)" do
      match' { ignore: ignoreUTags } skipped
        "<p>before<u>SKIPPED</u>after</p>"
        >>= \ms -> length ms `shouldEqual` 0

    itEff "replace on the same source is a no-op (was incorrectly altering 'after' before fix)" do
      replace' { ignore: ignoreUTags } skipped "X"
        "<p>before<u>SKIPPED</u>after</p>"
        >>= assertHypeHTML "<p>before<u>SKIPPED</u>after</p>"

    itEff "/beforeafter/ matches across the bridged gap (positive: bridge is clean)" do
      -- The negative tests above only confirm "SKIPPED is gone". This one
      -- confirms the joined string is exactly "beforeafter" — no stray
      -- separator, no leftover text. Catches any future regression where
      -- the bridge string carries an artifact in place of the ignored span.
      let beforeafter = unsafeRegex "beforeafter" giu
      match' { ignore: ignoreUTags } beforeafter
        "<p>before<u>SKIPPED</u>after</p>"
        >>= \ms -> length ms `shouldEqual` 1

  describe "Custom ignore: C branch (inner context element forces descent)" do
    -- The same custom ignore must keep working when the parent has
    -- block-level children (forcing the C branch). This is essentially a
    -- regression test that the fix didn't break the path that was already
    -- correct.

    itEff "C branch + ignored <u>: SKIPPED is still excluded" do
      -- <section> contains <p> (a context element), so `hasContextElements`
      -- on <section> returns true → C branch. The walker descends, hits
      -- <u>, branch A (ignore) skips it.
      let skipped = unsafeRegex "SKIPPED" giu
      match' { ignore: ignoreUTags } skipped
        "<section>before<u>SKIPPED</u><p>nested</p>after</section>"
        >>= \ms -> length ms `shouldEqual` 0

  describe "Default ignore: <script>/<style> regression" do
    -- These elements are in BOTH `elementsToBeIgnored` and `contextElements`,
    -- so they've always been correctly handled (parent goes to C branch via
    -- `hasContextElements` matching `<script`, descent happens, branch A
    -- ignores them). This test pins the behaviour so future refactors of
    -- the D branch can't accidentally regress it.

    itEff "<p>visible<script>secret</script>more</p>: 'secret' not visible" do
      let secret = unsafeRegex "secret" giu
      match secret "<p>visible<script>secret</script>more</p>"
        >>= \ms -> length ms `shouldEqual` 0

      textContents "<p>visible<script>secret</script>more</p>"
        >>= \tcs -> tcs `shouldEqual` ["", "visiblemore"]

  describe "Custom ignore: Comment nodes" do
    -- `Element.textContent` already excludes Comment descendants per the
    -- WHATWG DOM spec, so this case worked correctly even with the buggy
    -- D branch. After the fix, the walker also hits Comment via branch A
    -- (ignore returns true) — same final answer, different path. Pinning
    -- the result so the two implementations stay consistent.

    itEff "<p>abc<!--xxx-->def</p> + isComment ignore: matches /abcdef/" do
      let abcdef = unsafeRegex "abcdef" giu
      match' { ignore: ignoreComments } abcdef
        "<p>abc<!--xxx-->def</p>"
        >>= \ms -> length ms `shouldEqual` 1
