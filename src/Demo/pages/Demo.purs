module Demo.Demo (main) where

import Prelude

import Data.Array.NonEmpty (head) as NEA
import Data.Foldable (foldMap)
import Data.Hyperly
  ( match, matchContextlessly
  , replace, replaceContextlessly
  , wrap, wrapContextlessly
  , insert, insertContextlessly
  , Insert(..), Boundary(..), TargetHTML(..)
  , textContents, contextlessTextContents
  )
import Data.Hyperly.DOM (setInnerHTML, windowEffect)
import Data.Maybe (Maybe(..))
import Data.String (toLower)
import Data.String.Regex.Flags (RegexFlags(..))
import Data.String.Regex.Unsafe (unsafeRegex)
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Console (error)
import Unsafe.Coerce (unsafeCoerce)
import Web.DOM.Element (Element, setAttribute)
import Web.DOM.Node (Node, nodeName, toEventTarget)
import Web.DOM.NodeList (toArray) as Nodes
import Web.DOM.ParentNode (QuerySelector(..), querySelector, querySelectorAll)
import Web.Event.EventTarget (addEventListener, eventListener)
import Web.HTML.Event.EventTypes (input) as ET
import Web.HTML.HTMLDocument (documentElement)
import Web.HTML.HTMLHtmlElement (HTMLHtmlElement)
import Web.HTML.HTMLInputElement (checked, value) as Input
import Web.HTML.HTMLTextAreaElement (value) as Textarea
import Web.HTML.Window (document)

foreign import attrs :: Node -> Effect String

doc :: Effect (Maybe HTMLHtmlElement)
doc = windowEffect >>= document >>= documentElement

qs :: String -> Effect (Maybe Node)
qs s = doc >>= case _ of
  Just doc' ->
    querySelector (QuerySelector s) (unsafeCoerce doc')
    >>= case _ of
      Just elmt -> pure $ Just $ unsafeCoerce elmt
      _ -> pure Nothing
  _ -> pure Nothing

qsa :: String -> Effect (Array Node)
qsa s = doc >>= case _ of
  Just doc' ->
    querySelectorAll (QuerySelector s) (unsafeCoerce doc')
    >>= Nodes.toArray
  _ -> pure []

main :: Effect Unit
main = do
  article <- qs "article"
  inputs <- qsa "textarea, input"
  tcList <- qs ".tc-list"
  matchList <- qs ".match-list"

  let
    renderArticle' = (\_ -> renderArticle article inputs tcList matchList)
      :: forall a. a -> Effect Unit

  _ <- renderArticle' unit
  listener <- eventListener renderArticle'

  void
    $ traverse
    (\n -> addEventListener ET.input listener false $ toEventTarget n)
    inputs

  where
  renderArticle :: Maybe Node -> Array Node -> Maybe Node -> Maybe Node -> Effect Unit
  renderArticle
    (Just article)
    [ textarea
    , search
    , contextlessly, g, i, u
    , wrapper, start, btwn, end
    , boundary
    , replacement
    ]
    tcList
    matchList
    = do
    -- Set textarea HTML to the article:
    html <- Textarea.value $ unsafeCoerce textarea
    setInnerHTML html $ unsafeCoerce article

    -- Add `data-name` and `data-attrs` to all elements:
    void
      $ querySelectorAll (QuerySelector "*") (unsafeCoerce article)
      >>= Nodes.toArray
      >>= traverse (\n -> do
        a <- attrs n
        setAttribute "data-name" (toLower $ nodeName n) (unsafeCoerce n)
        setAttribute "data-attrs" a (unsafeCoerce n)
      )

    -- Flags:
    global <- Input.checked $ unsafeCoerce g
    ignoreCase <- Input.checked $ unsafeCoerce i
    unicode <- Input.checked $ unsafeCoerce u
    contextlessly' <- Input.checked $ unsafeCoerce contextlessly

    let
      flags =
        RegexFlags
        { global
        , ignoreCase
        , unicode
        , multiline: false
        , dotAll: false
        , sticky: false
        }

      article' = unsafeCoerce article :: Element

    pattern <-
      (Input.value $ unsafeCoerce search)
      >>= \p -> pure $ unsafeRegex p flags

    -- Display scraped text contents (one entry per context block):
    tcs <- (if contextlessly' then contextlessTextContents else textContents) article'
    setListHTML (foldMap (\tc -> "<li>" <> tc <> "</li>") tcs) tcList

    -- Display match results (matched text and position):
    ms <- (if contextlessly' then matchContextlessly else match) pattern article'
    setListHTML
      ( foldMap
          (\m -> "<li><code>" <> NEA.head m.captures <> "</code> @" <> show m.startIndex <> "</li>")
          ms
      )
      matchList

    -- Wrap matched texts:
    wrapper' <- Input.value $ unsafeCoerce wrapper

    -- Replace the matched texts:
    replacement' <- Input.value $ unsafeCoerce replacement

    -- Insertion around the matched texts:
    start' <- Input.value $ unsafeCoerce start
    btwn' <- Input.value $ unsafeCoerce btwn
    end' <- Input.value $ unsafeCoerce end
    boundary' <-
      Input.checked (unsafeCoerce boundary)
      >>= \b -> pure $ if b then Outer else Inner

    if wrapper' /= ""
    then void $ (if contextlessly' then wrapContextlessly else wrap) pattern wrapper' article'
    else pure unit

    if start' /= "" || btwn' /= "" || end' /= ""
    then
      void
      $ (if contextlessly' then insertContextlessly else insert)
        pattern
        (Around boundary' (TargetHTML start') (TargetHTML btwn') (TargetHTML end'))
        article'
    else pure unit

    if replacement' /= ""
    then void $ (if contextlessly' then replaceContextlessly else replace) pattern replacement' article'
    else pure unit

  renderArticle _ _ _ _ = error "Wrong HTML structure."

  setListHTML :: String -> Maybe Node -> Effect Unit
  setListHTML html (Just node) = setInnerHTML html (unsafeCoerce node :: Element)
  setListHTML _ Nothing = pure unit
