module Test.Piping (testPiping) where

import Prelude

import Data.Either (Either(..))
import Data.Hyperly
  ( Boundary(..), Insert(..)
  , class Hyperly, Hype
  , insert, replace, revert, revertAll, transform
  )
import Data.String.Regex (Regex)
import Data.String.Regex.Unsafe (unsafeRegex)

import Effect (Effect)

import Test.Spec (Spec, describe)
import Test.Util
  (assertHypeHTML, giu, itEff)

pipeReplace
  :: forall h
   . Hyperly h
  => Regex
  -> String
  -> (Either String h)
  -> Effect (Either String Hype)
pipeReplace _ _ (Left e) = pure $ Left e
pipeReplace re s (Right hy) = replace re s hy

testPiping :: Spec Unit
testPiping = describe "Piping" do

  let input = "A<b>b</b>c<b>D</b>E<b>f</b>g<b>H</b>"

  itEff "AB -> CD -> EF -> GH -> Reverts" do
    forward <-
      replace
        (unsafeRegex "(A)(B)" giu) "CD" input
      >>= pipeReplace
        (unsafeRegex "(C)(D)" giu) "EF"
      >>= pipeReplace
        (unsafeRegex "(E)(F)" giu) "GH"

    assertHypeHTML "G<b>H</b>G<b>H</b>G<b>H</b>g<b>H</b>" forward

    backward <-
      case forward of
      Left e -> pure $ Left e
      Right hy -> revert hy
    assertHypeHTML "E<b>F</b>E<b>F</b>E<b>f</b>g<b>H</b>" backward

    _ <-
      case backward of
      Left _ -> pure unit
      Right hy -> assertHypeHTML input =<< revertAll hy
    
    pure unit

  itEff "Insert → Revert" do
    insert (unsafeRegex "ab" giu) (Around Inner "[" "|" "]") "<p>ab</p>"
      >>= case _ of
        Left _ -> pure unit
        Right hy -> revert hy >>= assertHypeHTML "<p>ab</p>"

  itEff "Insert Outer → Revert" do
    insert (unsafeRegex "ab" giu) (Around Outer "<wrap>" "||" "</wrap>") "<div><p>ab</p></div>"
      >>= case _ of
        Left _ -> pure unit
        Right hy -> revert hy >>= assertHypeHTML "<div><p>ab</p></div>"

  itEff "Transform [] → Revert: restores all portions" do
    transform (unsafeRegex "abc" giu) (\_ _ -> pure ([] :: Array String))
      "<p><b>a</b>b<b>c</b></p>"
      >>= case _ of
        Left _ -> pure unit
        Right hy -> revert hy >>= assertHypeHTML "<p><b>a</b>b<b>c</b></p>"
