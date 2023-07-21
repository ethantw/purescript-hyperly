module Test.Util where

import Prelude
import Prim

import Data.Either (Either(..))
import Data.Hyperly (Hype, html)
import Data.String.Regex.Flags (RegexFlags(..))

import Effect (Effect)
import Effect.Class (liftEffect)

import Test.Spec (Spec, it)
import Test.Spec.Assertions (shouldEqual)

itEff :: String -> Effect Unit -> Spec Unit
itEff name effAction = it name (liftEffect effAction)


giu :: RegexFlags
giu = RegexFlags
  { global: true
  , ignoreCase: true
  , multiline: false
  , dotAll: false
  , sticky: false
  , unicode: true
  }

assertHypeHTML :: String -> Either String Hype -> Effect Unit
assertHypeHTML expected result = do
  actual <- case result of
    Left msg -> pure $ Left msg
    Right h -> html h >>= \actual' -> pure $ Right actual'
  actual `shouldEqual` (Right expected)

assertHypeLeft :: String -> Either String Hype -> Effect Unit
assertHypeLeft expected result = do
  actual <- case result of
    Left msg -> pure $ Left msg
    Right h -> html h >>= \actual' -> pure $ Right actual'
  actual `shouldEqual` (Left expected)
