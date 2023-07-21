module Test.Hyperly (testHyperly) where

import Prelude

import Data.Array (length)

import Data.Hyperly
  ( Hype(..)
  , history
  , defaultOptions
  , document
  , element
  , html
  , htmlType
  , hype
  , contextlessTextContents
  , textContents'
  , textContents
  )
import Data.Hyperly.DOM (HTMLType(..), isSameAs, setInnerHTML)

import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

import Test.Util (itEff)

import Web.DOM.Document (createElement, url)
import Web.DOM.Element (matches, setAttribute)
import Web.DOM.ParentNode (QuerySelector(..))

testHyperly :: Spec Unit
testHyperly = describe "Hyperly" do
  hyperlyHTML
  hyperlyElement
  hyperlyHype

fullHTML :: String
fullHTML =
  """
    <!DOCTYPE html>
    <html lang="en-GB">
      <head>
        <title>Hyperly</title>
        <meta charset="UTF-8">
        <style>.hyperly { color: var(--hyperly-color) }</style>
        <script defer type="module" src="hyperly.js"></script>
      </head>
      <body class="hyperly"><main><h1>Hyperly</h1><p>This <em>is</em> a full sentence.</p></main><footer>No rights reserved.</footer></body>
    </html>
  """

headBodyHTML :: String
headBodyHTML = """<head class="strong-head"><title>Hyperly!</title></head><body class="hyperly"><h1>Hyperly</h1></body>"""

bodyOnlyHTML :: String
bodyOnlyHTML = """<body class="hyperly"><main><h1>Hyperly</h1></main></body>"""

contentHTML :: String
contentHTML = """<style scoped="scoped">.hyperly { color: green; }</style><main><h1>Hyperly</h1><p>This <em>is</em> a full sentence.</p></main><footer>No rights reserved.</footer>"""

hyperlyHTML :: Spec Unit
hyperlyHTML = describe "Hyperly HTML" do

  itEff "Result of `htmlType html`" do
    htmlType fullHTML
      >>= case _ of
        Outer -> pure true
        _ -> pure false
      >>= \res -> res `shouldEqual` true
    htmlType headBodyHTML
      >>= case _ of
        Inner -> pure true
        _ -> pure false
      >>= \res -> res `shouldEqual` true
    htmlType bodyOnlyHTML
      >>= case _ of
        BodyOuter -> pure true
        _ -> pure false
      >>= \res -> res `shouldEqual` true
    htmlType contentHTML
      >>= case _ of
        BodyInner -> pure true
        _ -> pure false
      >>= \res -> res `shouldEqual` true

  itEff "Result of `html html`" do
    html fullHTML
      >>= \actual -> actual `shouldEqual` fullHTML

  itEff "Result of `element html`" do
    element fullHTML
      >>= matches (QuerySelector "html")
      >>= \res -> res `shouldEqual` true

  itEff "Result of `document html`" do
    document fullHTML
      >>= url >>= \url' ->
        url' `shouldEqual` "about:blank"

  itEff "Result of `hype html`" do
    hype fullHTML
      >>= case _ of
        (Hype _elmt Outer []) -> pure true
        _ -> pure false
      >>= \res -> res `shouldEqual` true

  itEff "Result of `history html`" do
    (length (history fullHTML)) `shouldEqual` 0

  itEff "Result of `textContents html`, etc" do
    textContents fullHTML
      >>= \actual -> actual `shouldEqual`
      ["","","","Hyperly","This is a full sentence.","No rights reserved.","\n    \n  "]
    textContents fullHTML
      >>= \actual -> actual `shouldEqual`
      ["","","","Hyperly","This is a full sentence.","No rights reserved.","\n    \n  "]
    contextlessTextContents fullHTML
      >>= \actual -> actual `shouldEqual`
      ["\n        Hyperly\n        \n        .hyperly { color: var(--hyperly-color) }\n        \n      \n      HyperlyThis is a full sentence.No rights reserved.\n    \n  "]

hyperlyElement :: Spec Unit
hyperlyElement = describe "Hyperly Element" do
  itEff "Element methods" do
    doc <- document ""
    elmt <- createElement "section" doc
    setAttribute "class" "important" elmt
    setAttribute "data-author-contact" "Earth, the Solar System" elmt
    setInnerHTML contentHTML elmt

    htmlType elmt
      >>= case _ of
      Outer -> pure true
      _ -> pure false
      >>= \res -> res `shouldEqual` true

    html elmt
      >>= \actual ->
      actual `shouldEqual`
      ("<section class=\"important\" data-author-contact=\"Earth, the Solar System\">" <> contentHTML <> "</section>")

    element elmt
      >>= matches (QuerySelector "section")
      >>= \res -> res `shouldEqual` true

    document elmt
      >>= \doc' ->
        (doc' `isSameAs` doc) `shouldEqual` true

    hype elmt
      >>= case _ of
        (Hype _elmt Outer []) -> pure true
        _ -> pure false
      >>= \res -> res `shouldEqual` true

    (length (history elmt)) `shouldEqual` 0

    textContents elmt
      >>= \actual ->
      actual `shouldEqual`
      ["", "", "Hyperly","This is a full sentence.","No rights reserved."]
    textContents' defaultOptions elmt
      >>= \actual ->
      actual `shouldEqual`
      ["", "", "Hyperly","This is a full sentence.","No rights reserved."]
    contextlessTextContents elmt
      >>= \actual ->
      actual `shouldEqual`
      [".hyperly { color: green; }HyperlyThis is a full sentence.No rights reserved."]

hyperlyHype :: Spec Unit
hyperlyHype = describe "Hyperly Hype" do
  itEff "Hype methods" do
    doc <- document ""
    elmt <- createElement "section" doc
    setAttribute "class" "important" elmt
    setAttribute "data-author-contact" "Earth, the Solar System" elmt
    setInnerHTML contentHTML elmt

    hy <- hype elmt

    htmlType hy
      >>= case _ of
      Outer -> pure true
      _ -> pure false
      >>= \res -> res `shouldEqual` true

    html hy
      >>= \actual ->
      actual `shouldEqual`
      ("<section class=\"important\" data-author-contact=\"Earth, the Solar System\">" <> contentHTML <> "</section>")

    element hy
      >>= matches (QuerySelector "section")
      >>= \res -> res `shouldEqual` true

    document hy
      >>= \doc' ->
        (doc' `isSameAs` doc) `shouldEqual` true

    hype hy
      >>= case _ of
        (Hype _elmt Outer []) -> pure true
        _ -> pure false
      >>= \res -> res `shouldEqual` true

    (length (history hy)) `shouldEqual` 0

    textContents' defaultOptions hy
      >>= \actual ->
      actual `shouldEqual`
      ["", "", "Hyperly","This is a full sentence.","No rights reserved."]
    textContents hy
      >>= \actual ->
      actual `shouldEqual`
      ["", "", "Hyperly","This is a full sentence.","No rights reserved."]
    contextlessTextContents hy
      >>= \actual ->
      actual `shouldEqual`
      [".hyperly { color: green; }HyperlyThis is a full sentence.No rights reserved."]

  itEff "Regular text contents" do
    textContents "<abc>abc</abc> <p>DeFg <b>HijK</b></p> <em>Emphas<i>i</i>s</em>"
      >>= \actual -> actual `shouldEqual` ["abc ", "DeFg HijK", " Emphasis"]

    textContents "<html><head><title>ABC</title></head><body><abc>abc</abc> <p>DeFg <b>HijK</b></p> <em>Emphas<i>i</i>s</em></body></html>"
      >>= \actual -> actual `shouldEqual` ["", "abc ", "DeFg HijK", " Emphasis"]
