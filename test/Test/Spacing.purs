module Test.Spacing (testInsertSpacing) where

import Prelude

import Demo.ISS (insertISS)
import Test.Spec (Spec, describe)
import Test.Util
  (assertHypeHTML, itEff)

testInsertSpacing :: Spec Unit
testInsertSpacing = describe "Spacing adjustments" do

  itEff "A字B -> A 字 B" do
    insertISS false
      "A字b漢Π"
      >>= assertHypeHTML
      "A 字 b 漢 Π"

  itEff "A漢字B -> A 漢字 B" do
    insertISS false
      "A字漢b, Πナかπ, Ё글한ё, é喃𡨸ï"
      >>= assertHypeHTML
      "A 字漢 b, Π ナか π, Ё 글한 ё, é 喃𡨸 ï"

  itEff "A字B -> A 字 B" do
    insertISS false
      "A字b漢ΠナπかЁ한ё자é𡨸ï"
      >>= assertHypeHTML
      "A 字 b 漢 Π ナ π か Ё 한 ё 자 é 𡨸 ï"

  itEff "<a>A</a><b>字</b><c>B</c>" do
    insertISS false
      "<a>A</a>字漢<b>b</b>, <a>Π</a><b>ナ</b>か<c>π</c>, <a><b><c>Ё</c></b></a><i>글<j>한</j>ё</i>, é<i>喃</i>𡨸ï"
      >>= assertHypeHTML
      "<a>A</a> 字漢 <b>b</b>, <a>Π</a> <b>ナ</b>か <c>π</c>, <a><b><c>Ё</c></b></a> <i>글<j>한</j> ё</i>, é <i>喃</i>𡨸 ï"

  itEff "<a>A</a><b>字</b><c>B</c> [with <h-iss>]" do
    insertISS true
      "Test測試test。<a>A</a>字漢<b>b</b>, <a>Π</a><b>ナ</b>か<c>π</c>, <a><b><c>Ё</c></b></a><i>글<j>한</j>ё</i>, é<i>喃</i>𡨸ï"
      >>= assertHypeHTML
      "Test<h-iss> </h-iss>測試<h-iss> </h-iss>test。<a>A</a><h-iss> </h-iss>字漢<h-iss> </h-iss><b>b</b>, <a>Π</a><h-iss> </h-iss><b>ナ</b>か<h-iss> </h-iss><c>π</c>, <a><b><c>Ё</c></b></a><h-iss> </h-iss><i>글<j>한</j><h-iss> </h-iss>ё</i>, é<h-iss> </h-iss><i>喃</i>𡨸<h-iss> </h-iss>ï"
