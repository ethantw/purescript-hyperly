module Data.Hyperly.TextContents (textContentsByContext) where

import Prelude

import Data.Array (snoc)

import Data.Hyperly.DOM
  (advanceWithinRange, elementToNode, isTextNode, textContent) as DOM
import Data.Hyperly.Options (Options)

import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple)
import Data.Tuple.Nested ((/\))

import Effect (Effect)

import Web.DOM (Element, Node)
import Web.DOM.Node (firstChild) as DOM

-- | Walks the DOM tree of an element and collects its text contents, partitioned
-- | by context boundaries (block-level elements, runs of loose inline content).
-- |
-- | Each entry in the result is a `(contextNode, accumulatedText)` tuple. A
-- | context is opened by a block-level element or a non-block-level node whose
-- | content is the first thing that follows a closed context. An empty `""`
-- | entry appears whenever a container has block-level children but no leading
-- | text before its first such child — see `Data.Hyperly.Options` for which
-- | elements are treated as context boundaries.
-- |
-- | Parameters:
-- | - `options`: rules controlling which nodes are ignored, treated as context
-- |   elements, etc.
-- | - `range`: the root element to walk.
-- |
-- | Returns:
-- | - One `(Node, String)` tuple per context, in document order.
-- |
textContentsByContext
  :: Record Options
  -> Element
  -> Effect (Array (Tuple Node String))
textContentsByContext options range =
  go [] Nothing (Just rangeNode)

  where
  advance = DOM.advanceWithinRange range

  { ignore
  , isContextElement
  , hasContextElements
  } = options

  rangeNode = DOM.elementToNode range

  -- | Add text to the current context. If no context exists yet, anchor a new
  -- | one to rangeNode (preserving the original behaviour for text that appears
  -- | before the first context element).
  addText :: String -> Maybe (Tuple Node String) -> Maybe (Tuple Node String)
  addText text Nothing         = Just (rangeNode /\ text)
  addText text (Just (n /\ t)) = Just (n /\ (t <> text))

  -- | Flush the current in-progress context into the completed list.
  closeCtx
    :: Array (Tuple Node String)
    -> Maybe (Tuple Node String)
    -> Array (Tuple Node String)
  closeCtx done Nothing    = done
  closeCtx done (Just ctx) = snoc done ctx

  -- | Traverse the DOM tree of the range element and scrape text contents by
  -- | contexts.
  -- |
  -- | `done` holds completed contexts; `cur` holds the in-progress context
  -- | (Nothing before the first context element is encountered). Keeping them
  -- | separate avoids the O(n) modifyAt-on-last-element pattern.
  go
    :: Array (Tuple Node String)
    -> Maybe (Tuple Node String)
    -> Maybe Node
    -> Effect (Array (Tuple Node String))
  -- E. Reached the end of the range: flush current context and return.
  go done cur Nothing = pure $ closeCtx done cur

  go done cur (Just atNode) =
    -- A. If the current node should be ignored, go forward.
    ignore atNode >>= case _ of
    true ->
      go done cur =<< advance atNode

    _ ->
      -- B. Text node: append its content to the current context.
      if DOM.isTextNode atNode
      then
        DOM.textContent atNode >>= \tc ->
        go done (addText tc cur) =<< advance atNode

      else
        hasContextElements atNode >>= case _ of
        true ->
          isContextElement atNode >>= case _ of
          -- C-1. Context element containing inner context elements: close the
          --      current context and open a new one for this node.
          true ->
            go (closeCtx done cur) (Just (atNode /\ ""))
            =<< DOM.firstChild atNode
          -- C-2. Non-context element containing inner context elements: descend
          --      while keeping the current context.
          _ ->
            go done cur =<< DOM.firstChild atNode

        _ ->
          DOM.textContent atNode >>= \tc ->
          advance atNode >>= \maybeAdvanced ->
          isContextElement atNode >>= case _ of
          -- D-1. Context element with no inner context elements: close the
          --      current context and record this node as a completed context.
          true ->
            let done'  = closeCtx done cur
                done'' = snoc done' (atNode /\ tc)
            in case maybeAdvanced of
              Just advanced ->
                isContextElement advanced >>= case _ of
                -- D-1-1-a. Next sibling is itself a context element.
                true  -> go done'' Nothing maybeAdvanced
                -- D-1-1-b. Next sibling is not a context element; seed a new
                --           context for it so later text appends correctly.
                _     -> go done'' (Just (advanced /\ "")) maybeAdvanced
              -- D-1-2. No next sibling; we are done.
              _     -> pure done''

          -- D-2. Non-context element with no inner context elements: append
          --      its text content to the current context.
          _ ->
            go done (addText tc cur) maybeAdvanced
