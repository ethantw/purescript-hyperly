module Test.Insert (testInsert) where

import Prelude

import Data.Hyperly
  (Boundary(..), Insert(..), TargetHTML(..), document, insert)
import Data.Hyperly.DOM (setInnerHTML)

import Data.String.Regex (Regex)
import Data.String.Regex.Unsafe (unsafeRegex)

import Test.Spec (Spec, describe)

import Test.Util (assertHypeHTML, giu, itEff)

import Web.DOM.Document (createElement)

reAB :: Regex
reAB = unsafeRegex "\\b([a-z])([a-z])\\b" giu

testInsert :: Spec Unit
testInsert = describe "Insertion" do

  itEff "Insert around (text)" do
    (insert
      reAB
      (Around Outer ["[", "["] ["|"] ["]", "]"])
      "[Around/Outer/Text] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Around/Outer/Text] <a>a</a> [[<b>b</b>|c]] abc [[cd]]"

    (insert
      reAB
      (Around Inner "[" "|" "]")
      "[Around/Inner/Text] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Around/Inner/Text] <a>a</a> <b>[b|</b>c] abc [cd]"

  describe "Insert element blocks" do
    itEff "Insert around (element)" do
      doc <- document ""
      start <- createElement "em" doc
      btwn <- createElement "b" doc
      end <- createElement "em" doc

      setInnerHTML "((" start
      setInnerHTML "||" btwn
      setInnerHTML "))" end

      (insert
        reAB
        (Around Outer start btwn end)
        "[Around/Outer] <a>a</a> <b>b</b>c abc cd")
        >>= assertHypeHTML
        "[Around/Outer] <a>a</a> <em>((</em><b>b</b><b>||</b>c<em>))</em> abc <em>((</em>cd<em>))</em>"

      (insert
        reAB
        (Around Inner start btwn end)
        "[Around/Inner] <a>a</a> <b>b</b>c abc cd")
        >>= assertHypeHTML
        "[Around/Inner] <a>a</a> <b><em>((</em>b<b>||</b></b>c<em>))</em> abc <em>((</em>cd<em>))</em>"

  itEff "Insert both (text)" do
    (insert
      reAB
      (Both Outer ">" "<")
      "[Both/Outer/Text] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Both/Outer/Text] <a>a</a> &gt;<b>b</b>c&lt; abc &gt;cd&lt;"

    (insert
      reAB
      (Both Inner ">" "<")
      "[Both/Inner/Text] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Both/Inner/Text] <a>a</a> <b>&gt;b</b>c&lt; abc &gt;cd&lt;"

  itEff "Insert start" do
    doc <- document ""
    start <- createElement "em" doc
    setInnerHTML "((" start

    (insert
      reAB
      (Start Outer start)
      "[Start/Outer] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Start/Outer] <a>a</a> <em>((</em><b>b</b>c abc <em>((</em>cd"

    (insert
      reAB
      (Start Inner start)
      "[Start/Inner] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Start/Inner] <a>a</a> <b><em>((</em>b</b>c abc <em>((</em>cd"

  itEff "Insert between" do
    doc <- document ""
    btwn <- createElement "b" doc
    setInnerHTML "||" btwn

    (insert
      reAB
      (Between Outer btwn)
      "[Between/Outer] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Between/Outer] <a>a</a> <b>b</b><b>||</b>c abc cd"

    (insert
      reAB
      (Between Inner btwn)
      "[Between/Inner] <a>a</a> <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[Between/Inner] <a>a</a> <b>b<b>||</b></b>c abc cd"

  itEff "Insert end" do
    doc <- document ""
    end <- createElement "em" doc
    setInnerHTML "))" end

    (insert
      reAB
      (End Outer end)
      "[End/Outer] <a>a</a> y<x>z.</x> i<x>j</x>. <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[End/Outer] <a>a</a> y<x>z<em>))</em>.</x> i<x>j</x><em>))</em>. <b>b</b>c<em>))</em> abc cd<em>))</em>"

    (insert
      reAB
      (End Inner end)
      "[End/Inner] <a>a</a> y<x>z.</x> i<x>j</x>. <b>b</b>c abc cd")
      >>= assertHypeHTML
      "[End/Inner] <a>a</a> y<x>z<em>))</em>.</x> i<x>j<em>))</em></x>. <b>b</b>c<em>))</em> abc cd<em>))</em>"

  itEff "Insert targetable HTML" do
    (insert
      reAB
      (Around Outer (TargetHTML """<em class="inserted">[[</em>(""") (TargetHTML " ") (TargetHTML """)<em class="inserted">]]</em>"""))
      """[Around/Outer/HTML] <a>a</a> y<x>z.</x> i<x>j</x>. <b>b</b>c abc cd""")
      >>= assertHypeHTML
      """[Around/Outer/HTML] <a>a</a> <em class="inserted">[[</em>(y <x>z)<em class="inserted">]]</em>.</x> <em class="inserted">[[</em>(i <x>j</x>)<em class="inserted">]]</em>. <em class="inserted">[[</em>(<b>b</b> c)<em class="inserted">]]</em> abc <em class="inserted">[[</em>(cd)<em class="inserted">]]</em>"""
