module Test.Replace (testReplace) where

import Prelude

import Data.Hyperly (replace)
import Data.String.Regex.Unsafe (unsafeRegex)

import Test.Spec (Spec, describe)
import Test.Util (assertHypeHTML, giu, itEff)

testReplace :: Spec Unit
testReplace = do
  let ab = unsafeRegex "\\b([a-z])([a-z])\\b" giu

  describe "Replace" do

    itEff "AB -> _**_" do
      replace ab "_**_"
        "<a>A</a> <b>ab</b> BC <b>C</b>D E<em>f</em> abc<div>a<ol>b</ol>c</div> cd <i>J</i><u>K</u>"
        >>= assertHypeHTML
        "<a>A</a> <b>_**_</b> _**_ <b>_</b>**_ _<em>**_</em> abc<div>a<ol>b</ol>c</div> _**_ <i>_</i><u>**_</u>"

    itEff "Matched substring: $0 / $&" do
      replace ab "_$0_"
        "<a>A</a> <b>ab</b> BC <b>C</b>D E<em>f</em> abc cd <i>J</i><u>K</u>"
        >>= assertHypeHTML
        "<a>A</a> <b>_ab_</b> _BC_ <b>_</b>CD_ _<em>Ef_</em> abc _cd_ <i>_</i><u>JK_</u>"

      replace ab "_$&_"
        "<a>A</a> <b>ab</b> BC <b>C</b>D E<em>f</em> abc cd <i>J</i><u>K</u>"
        >>= assertHypeHTML
        "<a>A</a> <b>_ab_</b> _BC_ <b>_</b>CD_ _<em>Ef_</em> abc _cd_ <i>_</i><u>JK_</u>"

    itEff "The preceding substring: $`" do
      replace ab "$`_$&"
        "<a>A</a> <b>ab</b> BC <b>C</b>D"
        >>= assertHypeHTML
        "<a>A</a> <b>A _ab</b> A ab _BC <b>A</b> ab BC _CD"

    itEff "The following substring: $'" do
      replace ab "$&_$'"
        "<a>A</a> <b>ab</b> BC <b>C</b>D"
        >>= assertHypeHTML
        "<a>A</a> <b>ab_ BC CD</b> BC_ CD <b>C</b>D_"

    itEff "Indexed capturing groups: AB -> BA" do
      replace ab "$2$1"
        "abc <p>ab</p> <p>c<b>d</b></p> <p><b>e</b>f</p>"
        >>= assertHypeHTML
        "abc <p>ba</p> <p>d<b>c</b></p> <p><b>f</b>e</p>"

    itEff "Indexed capturing groups: AB -> AA" do
      replace ab "$1$1"
        "<a>A</a> <b>Ab</b> BC <b>C</b>D E<em>f</em> abc cd <i>J</i><u>K</u>"
        >>= assertHypeHTML
        "<a>A</a> <b>AA</b> BB <b>C</b>C E<em>E</em> abc cc <i>J</i><u>J</u>"

    itEff "Indexed capturing groups: AB -> BB" do
      replace ab "$2$2"
        "<a>A</a> <b>Ab</b> BC <b>C</b>D E<em>f</em> abc cd <i>J</i><u>K</u>"
        >>= assertHypeHTML
        "<a>A</a> <b>bb</b> CC <b>D</b>D f<em>f</em> abc dd <i>K</i><u>K</u>"

    itEff "Indexed capturing groups: AB -> B, A." do
      replace ab "$2, $1."
        "<a>A</a> <b>ab</b> BC <b>C</b>D E<em>f</em> abc cd <i>J</i><u>K</u>"
        >>= assertHypeHTML
        "<a>A</a> <b>b, a.</b> C, B. <b>D</b>, C. f<em>, E.</em> abc d, c. <i>K</i><u>, J.</u>"

    itEff "Named capturing groups: AB -> [B-A]" do
      replace
        (unsafeRegex "\\b(?<first>[a-z])(?<second>[a-z])\\b" giu)
        "[$<second>-$<first>]"
        "<a>A</a> <b>ab</b> BC <b>C</b>D E<em>f</em> abc cd <i>J</i><u>K</u>"
        >>= assertHypeHTML
        "<a>A</a> <b>[b-a]</b> [C-B] <b>[</b>D-C] [<em>f-E]</em> abc [d-c] <i>[</i><u>K-J]</u>"

    itEff "Literal dollar sign: $$" do
      replace ab "$$"
        "<a>A</a> <b>ab</b> BC <b>C</b>D"
        >>= assertHypeHTML
        "<a>A</a> <b>$</b> $ <b>$</b>"

      replace ab "$$$1"
        "<a>A</a> <b>ab</b> BC <b>C</b>D"
        >>= assertHypeHTML
        "<a>A</a> <b>$a</b> $B <b>$</b>C"

    itEff "Non-existent capturing groups: AB -> $5" do
      replace ab "$5"
        "<a>A</a> <b>ab</b> BC"
        >>= assertHypeHTML
        "<a>A</a> <b>$5</b> $5"

    itEff "Non-existent named capturing groups: AB -> $<missing>" do
      replace
        (unsafeRegex "\\b(?<first>[a-z])(?<second>[a-z])\\b" giu)
        "$<missing>"
        "<a>A</a> <b>ab</b> BC"
        >>= assertHypeHTML
        "<a>A</a> <b>$&lt;missing&gt;</b> $&lt;missing&gt;"
