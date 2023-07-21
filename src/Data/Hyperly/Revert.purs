module Data.Hyperly.Revert (revertSteps, revertAllSteps) where

import Prelude

import Data.Array (head, tail)
import Data.Either (Either(..))

import Data.Hyperly.DOM (removeNodes, replaceWith) as DOM
import Data.Hyperly.Transformer (Steps, Step)

import Data.Maybe (Maybe(..))
import Data.Foldable (foldr)
import Data.Tuple.Nested ((/\))

import Effect (Effect)

foldRevertingEithers
  :: forall a
   . (a -> Effect (Either String Unit))
   -> Array a
   -> Effect (Either String Unit)
foldRevertingEithers f = foldr (\x acc -> acc >>= folder x) (pure $ Right unit)
  where
  folder :: a -> Either String Unit -> Effect (Either String Unit)
  folder _ (Left e) = pure $ Left e
  folder x _ = f x

revertSteps :: Steps -> Effect (Either String Unit)
revertSteps steps = foldRevertingEithers revertOne steps
  where
  revertOne :: Step -> Effect (Either String Unit)
  revertOne (src /\ tgts) = case head tgts of
    Just tgt ->
      -- The first target is replaced by `src` in place; only the remaining
      -- targets (siblings inserted after it) need to be detached.
      DOM.replaceWith tgt [src]
      >>= case _ of
        Left e -> pure $ Left e
        _ -> case tail tgts of
          Just rest -> Right <$> DOM.removeNodes rest
          _ -> pure $ Right unit
    _ -> pure $ Right unit

revertAllSteps :: Array Steps -> Effect (Either String Unit)
revertAllSteps history = foldRevertingEithers revertSteps history
