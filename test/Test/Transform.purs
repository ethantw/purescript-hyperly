module Test.Transform (testTransform) where

import Prelude

import Data.Array (foldl)
import Data.Array.NonEmpty (index) as NEA

import Data.Hyperly (Portion, document, transform)
import Data.Hyperly.DOM (elementToNode, nodeToElement, setInnerHTML, textToNode)

import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), length, split, toLower, toUpper)
import Data.String.Regex.Unsafe (unsafeRegex)
import Data.Tuple (snd)
import Data.Tuple.Nested ((/\))

import Test.Spec (Spec, describe)

import Test.Util
  (assertHypeHTML, giu, itEff)

import Web.DOM.Document (createElement, createTextNode)
import Web.DOM.Element (setAttribute)

startingFrom :: Portion -> Int
startingFrom { text, start, inner, end } =
  if start then 1
  else if inner then 2
  else if end then 4 - (length text)
  else 0

testTransform :: Spec Unit
testTransform = describe "Transform" do
  let reABC = unsafeRegex "\\b([a-z])([a-z])([a-z])\\b" giu

  itEff "ABC -> A1_B2_C3_" do
    transform
      reABC
      (\sp _m ->
        pure $ snd $ foldl
          (\(index /\ acc) t -> ((index + 1) /\ (acc <> t <> show index <> "_")))
          (startingFrom sp /\ "")
          $ split (Pattern "") sp.text
      )
      "<a>A</a> <b>Abc</b> BC<em>D</em> <b>C</b>DE E<em>f</em>G abc cdefg <i>J</i><u>KL</u> <i>I</i>J<i>K</i> <x>x</x><x>y</x><x>Z</x> ab_c"
      >>= assertHypeHTML
      "<a>A</a> <b>A1_b2_c3_</b> B1_C2_<em>D3_</em> <b>C1_</b>D2_E3_ E1_<em>f2_</em>G3_ a1_b2_c3_ cdefg <i>J1_</i><u>K2_L3_</u> <i>I1_</i>J2_<i>K3_</i> <x>x1_</x><x>y2_</x><x>Z3_</x> ab_c"

  itEff "Replace & wrap" do
    transform
      reABC
      (\{ node, text, index } _m -> do
        doc <- document $ nodeToElement node
        em <- createElement "em" doc
        setAttribute "class" "wrapper" em
        setInnerHTML
          ("""<span class="index">""" <> (show index) <> "</span>: " <> text <> """</span>""") em
        pure em
      )
      """Foo <b>Ba</b>r Barz Foos <b>Bar</b>z <b>B</b><b>A</b><b>R</b>"""
      >>= assertHypeHTML
      """<em class="wrapper"><span class="index">0</span>: Foo</em> <b><em class="wrapper"><span class="index">0</span>: Ba</em></b><em class="wrapper"><span class="index">1</span>: r</em> Barz Foos <b>Bar</b>z <b><em class="wrapper"><span class="index">0</span>: B</em></b><b><em class="wrapper"><span class="index">1</span>: A</em></b><b><em class="wrapper"><span class="index">2</span>: R</em></b>"""

    transform
      reABC
      (\{ node, text, index } _m -> do
        doc <- document $ nodeToElement node
        i <- createElement "i" doc
        b <- createElement "b" doc

        setInnerHTML ("[" <> show index <> "]") i
        setInnerHTML ("[" <> text <> "]") b
        pure [i, b]
      )
      """Foo <b>Ba</b>r Barz Foos <b>Bar</b>z <b>B</b><b>A</b><b>R</b>"""
      >>= assertHypeHTML
      """<i>[0]</i><b>[Foo]</b> <b><i>[0]</i><b>[Ba]</b></b><i>[1]</i><b>[r]</b> Barz Foos <b>Bar</b>z <b><i>[0]</i><b>[B]</b></b><b><i>[1]</i><b>[A]</b></b><b><i>[2]</i><b>[R]</b></b>"""

  itEff "Relocate to the first portion" do
    transform
      reABC
      (\{ node, index } { captures } -> do
        doc <- document $ nodeToElement node
        i <- createElement "i" doc
        u <- createTextNode "_" doc
        b <- createElement "b" doc

        let
          text = (
            case NEA.index captures 0 of
              Just x -> x
              Nothing -> ""
          )

        setInnerHTML (toUpper text) i
        setInnerHTML (toLower text) b

        pure
          if index == 0
          then [elementToNode i, textToNode u, elementToNode b]
          else []
      )
      """<body lang="fr"><p>A<b>B</b>C Foo <em>C</em><em>D</em><b>E</b></p></body>"""
      >>= assertHypeHTML
      """<body lang="fr"><p><i>ABC</i>_<b>abc</b><b></b> <i>FOO</i>_<b>foo</b> <em><i>CDE</i>_<b>cde</b></em><em></em><b></b></p></body>"""

  itEff "Relocate to the last portion" do
    transform
      reABC
      (\{ node, end } { captures } -> do
        doc <- document $ nodeToElement node
        i <- createElement "i" doc
        u <- createTextNode "_" doc
        b <- createElement "b" doc

        let
          text = (
            case NEA.index captures 0 of
              Just x -> x
              Nothing -> ""
          )

        setInnerHTML (toUpper text) i
        setInnerHTML (toLower text) b

        pure
          if end
          then [elementToNode i, textToNode u, elementToNode b]
          else []
      )
      """<body lang="fr"><p>A<b>B</b>C Foo <em>C</em><em>D</em><b>E</b></p></body>"""
      >>= assertHypeHTML
      """<body lang="fr"><p><b></b><i>ABC</i>_<b>abc</b> <i>FOO</i>_<b>foo</b> <em></em><em></em><b><i>CDE</i>_<b>cde</b></b></p></body>"""
