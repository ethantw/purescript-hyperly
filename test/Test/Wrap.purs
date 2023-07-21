module Test.Wrap where

import Prelude

import Data.Hyperly (document, wrap)

import Data.String.Regex (Regex)
import Data.String.Regex.Unsafe (unsafeRegex)

import Test.Spec (Spec, describe)

import Test.Util
  ( assertHypeHTML
  , assertHypeLeft
  , giu
  , itEff
  )

import Web.DOM.Document (createElement)
import Web.DOM.Element (setAttribute)

reStops :: Regex
reStops = unsafeRegex "([,.;?!]+)" giu

testWrap :: Spec Unit
testWrap = describe "Wrap" do

  let input = (
    """
    <p>Hello, world! How <em>are</em> you doing? I hope you're doing <em>well.</em></p>
    <div><address>1, Guanqian Rd., North Dist., T'aichung City, R.O.C. 404023</address></div>
    """
  )

  itEff "Wrap with an element" do

    doc <- document ""
    b <- createElement "b" doc
    setAttribute "class" "stops" b

    wrap
      reStops
      b
      input
      >>= assertHypeHTML
      """
    <p>Hello<b class="stops">,</b> world<b class="stops">!</b> How <em>are</em> you doing<b class="stops">?</b> I hope you're doing <em>well<b class="stops">.</b></em></p>
    <div><address>1<b class="stops">,</b> Guanqian Rd<b class="stops">.,</b> North Dist<b class="stops">.,</b> T'aichung City<b class="stops">,</b> R<b class="stops">.</b>O<b class="stops">.</b>C<b class="stops">.</b> 404023</address></div>
    """

  itEff "Wrapper names of elements" do
    wrap
      reStops
      "a"
      input
      >>= assertHypeHTML
      """
    <p>Hello<a>,</a> world<a>!</a> How <em>are</em> you doing<a>?</a> I hope you're doing <em>well<a>.</a></em></p>
    <div><address>1<a>,</a> Guanqian Rd<a>.,</a> North Dist<a>.,</a> T'aichung City<a>,</a> R<a>.</a>O<a>.</a>C<a>.</a> 404023</address></div>
    """

    wrap
      reStops
      "i-punct"
      input
      >>= assertHypeHTML
      """
    <p>Hello<i-punct>,</i-punct> world<i-punct>!</i-punct> How <em>are</em> you doing<i-punct>?</i-punct> I hope you're doing <em>well<i-punct>.</i-punct></em></p>
    <div><address>1<i-punct>,</i-punct> Guanqian Rd<i-punct>.,</i-punct> North Dist<i-punct>.,</i-punct> T'aichung City<i-punct>,</i-punct> R<i-punct>.</i-punct>O<i-punct>.</i-punct>C<i-punct>.</i-punct> 404023</address></div>
    """

  itEff "Wrapper HTML strings with one valid element" do
    wrap
      reStops
      """<em class="punct" />"""
      input
      >>= assertHypeHTML
      """
    <p>Hello<em class="punct">,</em> world<em class="punct">!</em> How <em>are</em> you doing<em class="punct">?</em> I hope you're doing <em>well<em class="punct">.</em></em></p>
    <div><address>1<em class="punct">,</em> Guanqian Rd<em class="punct">.,</em> North Dist<em class="punct">.,</em> T'aichung City<em class="punct">,</em> R<em class="punct">.</em>O<em class="punct">.</em>C<em class="punct">.</em> 404023</address></div>
    """

  itEff "Void element: <br>, <wbr>, <input>, etc" do
    wrap reStops "br" input
      >>= assertHypeLeft
      "Wrapper cannot be a void element."

    wrap reStops """<wbr lang="ko">""" input
      >>= assertHypeLeft
      "Wrapper cannot be a void element."

    wrap reStops """<input type="number" />""" input
      >>= assertHypeLeft
      "Wrapper cannot be a void element."

  itEff "Invalid wrappable element names" do
    wrap reStops "" input
      >>= assertHypeLeft
      "Failed to create wrappable element: (``) is not a valid element name nor a possible HTML string."

    wrap reStops "!" input
      >>= assertHypeLeft
      "Failed to create wrappable element: (`!`) is not a valid element name nor a possible HTML string."

    wrap reStops "not!-a-proper-elmt-name!" input
      >>= assertHypeLeft
      "Failed to create wrappable element: (`not!-a-proper-elmt-name!`) is not a valid element name nor a possible HTML string."

    wrap reStops "1-starting-with-number" input
      >>= assertHypeLeft
      "Failed to create wrappable element: (`1-starting-with-number`) is not a valid element name nor a possible HTML string."

    wrap reStops "<1-starting-with-number />" input
      >>= assertHypeLeft
      "Failed to create wrappable element: (`<1-starting-with-number />`) is not a valid element name nor a possible HTML string."
