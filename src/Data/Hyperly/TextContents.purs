module Data.Hyperly.TextContents (textContentsByContext) where

import Prelude

import Data.Array (snoc)

import Data.Hyperly.DOM
  (advanceWithinRange, elementToNode, isTextNode, nodeToElement, textContent) as DOM
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
          ignoreAwareTextContent ignore atNode >>= \tc ->
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

-- | Concatenate text content of a subtree, but **skip subtrees where `ignore`
-- | returns true**. Used by `textContentsByContext`'s D branch (`atNode` has
-- | no inner context elements), where the previous `DOM.textContent atNode`
-- | shortcut would otherwise leak text from ignored descendants — most
-- | visibly when a custom `ignore` predicate matches an element that is not
-- | also in `contextElements` (e.g. `<span class="skip">`).
-- |
-- | Caller's invariant: `atNode` is an element-like Node whose subtree
-- | contains **no inner context-establishing elements** (this function would
-- | otherwise need to track context boundaries; it does not). Empty subtrees
-- | yield `""`.
ignoreAwareTextContent
  :: (Node -> Effect Boolean) -> Node -> Effect String
ignoreAwareTextContent ignore atNode =
  DOM.firstChild atNode >>= case _ of
    Nothing -> pure ""
    Just first -> go "" first
  where
  -- The original `atNode` (coerced to Element) bounds the walk: when
  -- `advanceWithinRange` reaches it again, we stop, never escaping into
  -- siblings of the caller's node.
  range = DOM.nodeToElement atNode

  go :: String -> Node -> Effect String
  go acc node = ignore node >>= case _ of
    true ->
      DOM.advanceWithinRange range node >>= step acc
    _ ->
      if DOM.isTextNode node
      then DOM.textContent node >>= \tc ->
           DOM.advanceWithinRange range node >>= step (acc <> tc)
      else DOM.firstChild node >>= case _ of
        Just fc -> go acc fc
        _ -> DOM.advanceWithinRange range node >>= step acc

  step :: String -> Maybe Node -> Effect String
  step acc Nothing  = pure acc
  step acc (Just n) = go acc n
