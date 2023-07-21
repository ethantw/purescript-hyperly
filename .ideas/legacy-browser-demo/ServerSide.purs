module Demo.ServerSide (main) where

import Prelude

import Data.Either (Either(..))
import Data.Hyperly (Transformer, html, transform)
import Data.String.Regex (Regex, regex)
import Demo.Util.ISS (giu)
import Effect (Effect)
import Effect.Console (error, log)

main :: Effect Unit
main =
  case re of
  Left e -> error e
  Right re' ->
    transform re' trans "<p>ab <em>B</em>c <b>C</b><a>D</a></p>"
    >>= case _ of
    Right hype -> html hype >>= log
    Left e -> error e

  where
  re :: Either String Regex
  re = regex "\\b([a-z])([a-z])\\b" giu

  trans :: Transformer String
  trans { start, end } _mat =
    pure $
    if start && end then "XY"
    else if start then "X"
    else if end then "Y"
    else ""
