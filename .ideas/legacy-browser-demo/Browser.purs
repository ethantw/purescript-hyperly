module Demo.Browser (main) where

import Prelude

import Data.Array (length)
import Data.Either (Either(..))

import Data.Hyperly
  ( class Hyperly, Hype, Transformer, TargetableHTML(..)
  , transform, textContents, contextlessTextContents
  , match, matchContextlessly
  , replace
  , insert, Insert(..), Boundary(..)
  , wrap
  , revert, revertAll
  )
import Data.Hyperly.DOM (getDocumentByNode, setInnerHTML)

import Data.Maybe (Maybe(..))
import Data.String.Regex (Regex, replace') as String
import Data.String.Regex.Flags (RegexFlags(..))
import Data.String.Regex.Unsafe (unsafeRegex)

import Demo.Util.ISS (insertISS)

import Effect (Effect)
import Effect.Class.Console (logShow)
import Effect.Console (error)
import Unsafe.Coerce (unsafeCoerce)

import Web.DOM.Document (createElement)
import Web.DOM.Element (Element)
import Web.DOM.ParentNode (QuerySelector(..), querySelector)
import Web.HTML (window)
import Web.HTML.HTMLDocument (documentElement)
import Web.HTML.HTMLHtmlElement (HTMLHtmlElement)
import Web.HTML.Window (document)

tr :: Effect Unit
tr = do
  logShow replacement'
  pure unit
  where
  replacement' = String.replace' specialPattern transformer' "abc$&def"

  specialPattern :: String.Regex
  specialPattern = unsafeRegex "\\$(\\d+|&|`|')" giu

  transformer' :: String -> Array (Maybe String) -> String
  transformer' _ _ = "[]"

main :: Effect Unit
main = do
  _ <- spacing
  _ <- contextlessContentsDemo
  _ <- matchDemo
  _ <- matchContextlesslyDemo
  _ <- replaceDemo
  _ <- insertDemo
  _ <- wrapFnDemo
  _ <- revertDemo
  _ <- revertAllDemo
  _ <- wrapTransformDemo
  tr

giu :: RegexFlags
giu = RegexFlags
  { global: true
  , ignoreCase: true
  , multiline: false
  , dotAll: false
  , sticky: false
  , unicode: true
  }

transformer :: Transformer Element
transformer { node, text, start, end } _m =
  getDocumentByNode node
  >>= case _ of
  doc -> createElement "em" doc
    >>= case _ of
      em -> do
        let html' = (
          (if start then "[" else "")
          <> text
          <> (if end then "]" else "")
        )
        setInnerHTML html' em
        pure em

foreign import logHypeImpl :: Hype -> Effect Unit

logHype :: Either String Hype -> Effect Unit
logHype hype = case hype of
  Left e -> error e
  Right hy -> logHypeImpl hy

wrap5letterWords :: forall h. Hyperly h => h -> Effect Unit
wrap5letterWords input =
  transform (unsafeRegex "\\b(\\w{2})(\\w)(\\w{2})\\b" giu) transformer input
  >>= logHype

tryZeroLengthMatch :: forall h. Hyperly h => h -> Effect Unit
tryZeroLengthMatch hy = do
  transform (unsafeRegex "^" giu) transformer hy
  >>= logHype

-- | Demo: transform — wrap 5-letter words in <em> using a custom Transformer
wrapTransformDemo :: Effect Unit
wrapTransformDemo = window >>= document >>= documentElement >>= case _ of
  Just root -> do
    let rootElmt = toElement root
    textContents rootElmt >>= logShow
    tryZeroLengthMatch rootElmt
    mspan <- querySelector (QuerySelector "span") (unsafeCoerce root)
    case mspan of
      Just span -> do
        wrap5letterWords span
        wrap5letterWords rootElmt
        wrap5letterWords
          """
          <html lang="fr">
          <body class="a">
            <section>He<b>ll</b>o Apple v. Android <a>Nic</a>ky</section>
          </body>
          </html>
          """
      _ -> pure unit
  Nothing -> pure unit

  where
    toElement :: HTMLHtmlElement -> Element
    toElement = unsafeCoerce

spacing :: Effect Unit
spacing = window >>= document >>= documentElement >>= case _ of
  Just root -> do
    querySelector (QuerySelector "article") (unsafeCoerce root)
    >>= case _ of
      Just article -> do
        _ <- insertISS true article
        pure unit
      Nothing -> pure unit
  Nothing -> pure unit

-- | Demo: contextlessTextContents — scrape all text as one flat string,
-- | ignoring block-element context boundaries.
contextlessContentsDemo :: Effect Unit
contextlessContentsDemo = window >>= document >>= documentElement >>= case _ of
  Just root -> contextlessTextContents (unsafeCoerce root :: Element) >>= logShow
  Nothing -> pure unit

-- | Demo: match — find regex matches across context boundaries and return
-- | structured Match records. Logs the count of matches found per context.
matchDemo :: Effect Unit
matchDemo = window >>= document >>= documentElement >>= case _ of
  Just root -> do
    ms <- match (unsafeRegex "hello" giu) (unsafeCoerce root :: Element)
    logShow (length ms)
  Nothing -> pure unit

-- | Demo: matchContextlessly — same regex as matchDemo but treats all text
-- | as one flat string. Compare the count to see the difference.
matchContextlesslyDemo :: Effect Unit
matchContextlesslyDemo = window >>= document >>= documentElement >>= case _ of
  Just root -> do
    ms <- matchContextlessly (unsafeRegex "hello" giu) (unsafeCoerce root :: Element)
    logShow (length ms)
  Nothing -> pure unit

-- | Demo: replace — replace matched text with a plain string in the <ol>.
replaceDemo :: Effect Unit
replaceDemo = window >>= document >>= documentElement >>= case _ of
  Just root ->
    querySelector (QuerySelector "ol") (unsafeCoerce root)
    >>= case _ of
      Just ol ->
        replace
          (unsafeRegex "\\bApple\\b" giu) "Mango"
          (unsafeCoerce ol :: Element)
        >>= logHype
      _ -> pure unit
  Nothing -> pure unit

-- | Demo: insert — insert «» around every "VIP" match inside the article's
-- | first paragraph, using Inner boundary.
insertDemo :: Effect Unit
insertDemo = window >>= document >>= documentElement >>= case _ of
  Just root ->
    querySelector (QuerySelector "article p") (unsafeCoerce root)
    >>= case _ of
      Just p ->
        insert
          (unsafeRegex "\\bVIP\\b" giu)
          (Around Inner (HTML "«") (HTML "") (HTML "»"))
          (unsafeCoerce p :: Element)
        >>= logHype
      _ -> pure unit
  Nothing -> pure unit

-- | Demo: wrap — wrap 4+ letter words in the article's last paragraph with
-- | <b> using the dedicated wrap function (not a custom Transformer).
wrapFnDemo :: Effect Unit
wrapFnDemo = window >>= document >>= documentElement >>= case _ of
  Just root ->
    querySelector (QuerySelector "article p:last-child") (unsafeCoerce root)
    >>= case _ of
      Just p ->
        wrap
          (unsafeRegex "\\b\\w{4,}\\b" giu) "<b>"
          (unsafeCoerce p :: Element)
        >>= logHype
      _ -> pure unit
  Nothing -> pure unit

-- | Demo: revert — replace "Green" with "Red", then undo the last step.
revertDemo :: Effect Unit
revertDemo = window >>= document >>= documentElement >>= case _ of
  Just root ->
    querySelector (QuerySelector "body > p:last-of-type") (unsafeCoerce root)
    >>= case _ of
      Just p -> do
        r <- replace
          (unsafeRegex "\\bGreen\\b" giu) "Red"
          (unsafeCoerce p :: Element)
        case r of
          Right hy -> revert hy >>= logHype
          Left e -> error e
      _ -> pure unit
  Nothing -> pure unit

-- | Demo: revertAll — chain two replaces on the last <p>, then revertAll to
-- | restore the original text in one step.
revertAllDemo :: Effect Unit
revertAllDemo = window >>= document >>= documentElement >>= case _ of
  Just root ->
    querySelector (QuerySelector "body > p:last-of-type") (unsafeCoerce root)
    >>= case _ of
      Just p -> do
        let elmt = unsafeCoerce p :: Element
        r1 <- replace (unsafeRegex "\\bApple\\b" giu) "Orange" elmt
        case r1 of
          Right hy1 -> do
            r2 <- replace (unsafeRegex "\\bDinner\\b" giu) "Lunch" hy1
            case r2 of
              Right hy2 -> revertAll hy2 >>= logHype
              Left e -> error e
          Left e -> error e
      _ -> pure unit
  Nothing -> pure unit
