module Test.Match (testMatch) where

import Prelude

import Data.Array (all, length)
import Data.Array.NonEmpty (NonEmptyArray)
import Data.Hyperly (Match, match)
import Data.String.Regex.Unsafe (unsafeRegex)

import Test.Spec (Spec, describe)
import Test.Spec.Assertions (shouldEqual)

import Foreign.Object (Object, fromHomogeneous)
import Test.Util (giu, itEff)
import Unsafe.Coerce (unsafeCoerce)

toNEA :: forall a. Array a -> NonEmptyArray a
toNEA = unsafeCoerce

isZeroLength :: Match -> Boolean
isZeroLength m = m.startIndex == m.endIndex

type NodelessPortion =
  { text :: String

  , atIndex :: Int

  , index :: Int
  , indexInMatch :: Int

  , indexInNode :: Int
  , endIndexInNode :: Int

  , start :: Boolean
  , inner :: Boolean
  , end :: Boolean
  }

type NodelessMatch =
  { captures :: NonEmptyArray String

  , groups :: Object String
  , input :: String

  , startIndex :: Int
  , endIndex :: Int

  , portions :: Array NodelessPortion
  }

prepareNodelessMs :: Match -> NodelessMatch
prepareNodelessMs = unsafeCoerce

emptyObject :: Object String
emptyObject = fromHomogeneous {}

testMatch :: Spec Unit
testMatch = describe "Match" do

  itEff "Matches" do
    match
      (unsafeRegex "\\babc\\b" giu)
      "<p>abc cd</p> <p>def</p> <p>aac a<b>B</b>C</p> <p>a<div>b</div>c</p>"
      >>= \actual ->
        (prepareNodelessMs <$> actual) `shouldEqual`
        [ { captures: toNEA ["abc"], groups: emptyObject, input: "abc cd", startIndex: 0, endIndex: 3
          , portions:
            [ { text: "abc", atIndex: 0, index: 0, indexInMatch: 0, indexInNode: 0, endIndexInNode: 3, start: true, inner: false, end: true }
            ]
          }
        , { captures: toNEA ["aBC"], groups: emptyObject, input: "aac aBC", startIndex: 4, endIndex: 7
          , portions:
            [ { text: "a", atIndex: 0, index: 0, indexInMatch: 0, indexInNode: 4, endIndexInNode: 7, start: true, inner: false, end: false }
            , { text: "B", atIndex: 5, index: 1, indexInMatch: 1, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "C", atIndex: 6, index: 2, indexInMatch: 2, indexInNode: 0, endIndexInNode: 1, start: false, inner: false, end: true }
              ]
          }
        ]

  itEff "Capturing groups" do
    match
      (unsafeRegex "\\b([a-z])([a-z])([a-z])\\b" giu)
      "abc <b>A</b><b>b</b><b>C</b> de<em>F</em> c!j!k!"
      >>= \actual ->
        (prepareNodelessMs <$> actual) `shouldEqual`
        [ { captures: toNEA ["abc","a","b","c"], groups: emptyObject, input: "abc AbC deF c!j!k!", startIndex: 0, endIndex: 3
          , portions:
            [ { text: "abc", atIndex: 0, index: 0, indexInMatch: 0, indexInNode: 0, endIndexInNode: 3, start: true, inner: false, end: true }
            ]
          }
        , { captures: toNEA ["AbC","A","b","C"], groups: emptyObject, input: "abc AbC deF c!j!k!", startIndex: 4, endIndex: 7
          , portions:
            [ { text: "A", atIndex: 4, index: 0, indexInMatch: 0, indexInNode: 0, endIndexInNode: 3, start: true, inner: false, end: false }
            , { text: "b", atIndex: 5, index: 1, indexInMatch: 1, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "C", atIndex: 6, index: 2, indexInMatch: 2, indexInNode: 0, endIndexInNode: 1, start: false, inner: false, end: true }
            ]
          }
        , { captures: toNEA ["deF","d","e","F"], groups: emptyObject, input: "abc AbC deF c!j!k!", startIndex: 8, endIndex: 11
          , portions:
            [ { text: "de", atIndex: 7, index: 0, indexInMatch: 0, indexInNode: 1, endIndexInNode: 4, start: true, inner: false, end: false }
            , { text: "F", atIndex: 10, index: 1, indexInMatch: 2, indexInNode: 0, endIndexInNode: 1,  start: false, inner: false, end: true }
            ]
          }
        ]

  let
    fruits = """
      <p>Can I have...</p>
      <ul>
        <li>a box <em>of</em> <strong>apples</strong>,
        <li>a box of gr<i>A</i>pes,
        <li>a box of bananA<b>s</b>,
        <li>three box<u>es</u> of d<b>r</b>a<b>g</b>On fruit<b>s</b>, and
        <li>a <strong>single</strong> DuRiAn?
      </ul>
    """

  itEff "Named capturing groups" do
    match
      (unsafeRegex "\\b(?:box(?:es)? of )?(?<fruits>apples?|grapes?|bananas?|dragon fruits?|durians?)\\b" giu)
      fruits
      >>= \actual ->
        (prepareNodelessMs <$> actual) `shouldEqual`
        [ { captures: toNEA ["box of apples", "apples"]
          , startIndex: 2
          , endIndex: 15
          , groups: fromHomogeneous{ fruits: "apples" }
          , input: "a box of apples,\n        "
          , portions:
            [ { text: "box ", atIndex: 0, index: 0, indexInMatch: 0, indexInNode: 2, endIndexInNode: 15, start: true, inner: false, end: false }
            , { text: "of", atIndex: 6, index: 1, indexInMatch: 4, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: " ", atIndex: 8, index: 2, indexInMatch: 6, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "apples", atIndex: 9, index: 3, indexInMatch: 7, indexInNode: 0, endIndexInNode: 6, start: false, inner: false, end: true }
            ]
          }
        , { captures: toNEA ["box of grApes", "grApes"]
          , startIndex: 2
          , endIndex: 15
          , groups: fromHomogeneous{ fruits: "grApes" }
          , input: "a box of grApes,\n        "
          , portions:
            [ { text: "box of gr", atIndex: 0, index: 0, indexInMatch: 0, indexInNode: 2, endIndexInNode: 15, start: true, inner: false, end: false }
            , { text: "A", atIndex: 11, index: 1, indexInMatch: 9, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "pes", atIndex: 12, index: 2, indexInMatch: 10, indexInNode: 0, endIndexInNode: 3, start: false, inner: false, end: true }
            ]
          }
        , { captures: toNEA ["box of bananAs", "bananAs"]
          , endIndex: 16
          , groups: fromHomogeneous { fruits: "bananAs" }
          , input: "a box of bananAs,\n        "
          , portions:
            [ { text: "box of bananA", atIndex: 0, index: 0, indexInMatch: 0, indexInNode: 2, endIndexInNode: 16, start: true, inner: false, end: false }
            , { text: "s", atIndex: 15, index: 1, indexInMatch: 13, indexInNode: 0, endIndexInNode: 1, start: false, inner: false, end: true }
            ]
          , startIndex: 2
          }
        , { captures: toNEA ["boxes of dragOn fruits", "dragOn fruits"]
          , startIndex: 6
          , endIndex: 28
          , groups: fromHomogeneous { fruits: "dragOn fruits" }
          , input: "three boxes of dragOn fruits, and\n        "
          , portions:
            [ { text: "box", atIndex: 0, index: 0, indexInMatch: 0, indexInNode: 6, endIndexInNode: 28, start: true, inner: false, end: false }
            , { text: "es", atIndex: 9, index: 1, indexInMatch: 3, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: " of d", atIndex: 11, index: 2, indexInMatch: 5, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "r", atIndex: 16, index: 3, indexInMatch: 10, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "a", atIndex: 17, index: 4, indexInMatch: 11, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "g", atIndex: 18, index: 5, indexInMatch: 12, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "On fruit", atIndex: 19, index: 6, indexInMatch: 13, indexInNode: 0, endIndexInNode: -1, start: false, inner: true, end: false }
            , { text: "s", atIndex: 27, index: 7, indexInMatch: 21, indexInNode: 0, endIndexInNode: 1, start: false, inner: false, end: true }
            ]
          }
        , { captures: toNEA ["DuRiAn", "DuRiAn"]
          , startIndex: 9
          , endIndex: 15
          , groups: fromHomogeneous { fruits: "DuRiAn" }
          , input: "a single DuRiAn?\n      "
          , portions:
            [ { text: "DuRiAn", atIndex: 8, index: 0, indexInMatch: 0, indexInNode: 1, endIndexInNode: 7, start: true, inner: false, end: true }
            ]
          }
        ]

  itEff "Zero-length matches" do
    match (unsafeRegex "^" giu) fruits
      >>= \ms -> do
      (all isZeroLength ms) `shouldEqual` true
      (length ms) `shouldEqual` 10

    match (unsafeRegex "\\b" giu) fruits
      >>= \ms -> do
      (all isZeroLength ms) `shouldEqual` true
      (length ms) `shouldEqual` 48

    match (unsafeRegex "$" giu) fruits
      >>= \ms -> do
      (all isZeroLength ms) `shouldEqual` true
      (length ms) `shouldEqual` 10
