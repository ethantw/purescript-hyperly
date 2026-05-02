# Design notes: why hyperly looks the way it does

Two related questions that came up during 0.2.0-rc.3 development. They aren't action items — they're context for understanding what hyperly is trading off, and where simplification is and isn't possible.

## 1. Why a library is needed at all

Browsers' Ctrl+F and Word's Find both handle text spanning multiple nodes / elements transparently. JavaScript code with full DOM API access has to write a library to get the same affordance. Why?

**Browser Find runs on the layout tree, not the DOM tree.** It has access to line boxes, text fragmentation, post-whitespace-collapse text flow, and block boundaries — all products of the render phase, deliberately not exposed via DOM API. JavaScript only sees pre-render input. So "find across visual paragraph" requires post-render information that browsers keep private.

**Word's internal model is paragraph + run, not arbitrarily nested elements.** Paragraphs are first-class. Styled runs are first-class. "Find across runs in a paragraph" is O(runs in paragraph) — trivial. HTML traded that ergonomics for the markup expressiveness of arbitrary nesting; the cost is that a "run" abstraction doesn't exist and every text-manipulation library has to reconstruct one at runtime on top of DOM nodes.

**The platform deliberately ships primitives, not opinions.** Range, TreeWalker, Selection, Custom Highlight API — these are ingredients. Browsers don't ship a "find with these block-element semantics, splice with these strategies" API because each design choice is a 20-year contract once it's in: which elements split context? Shadow DOM? iframes? whitespace handling? Unicode normalization? case-folding? The W3C tradition is to leave opinions to library authors.

**The hard part isn't finding — it's splicing.** `root.textContent.match(/…/)` already finds matches. The cliff is mapping match indices back to `(textNode, offsetInNode)` pairs and performing the splice without disturbing parent attributes, sibling order, or — critically — `Range` / `Selection` objects held by other code. Browser Find doesn't need to splice; it only highlights. Any DOM-mutating "find & replace" library inherits the splice problem.

**This gap has been open ~20 years, and hyperly is one of a genre.** findAndReplaceDOMText, mark.js, Rangy — same niche. The platform isn't filling the gap. Each new requirement (PureScript binding, history/revert, composable context predicates) gets reimplemented from scratch by another library.

The fundamental impedance: HTML's representation says "what tags wrap what"; the user's mental model is "text flow with formatting". Word aligns representation with mental model; HTML inverts the priority. Hyperly is, in practice, a runtime reimplementation of the run-paragraph model on top of DOM, dressed up to look like "just run a regex".

## 2. Where higher-level DOM APIs help (and where they don't)

`TreeWalker` looks tempting as a simplification target. Honest assessment:

**TreeWalker solves "node iteration with subtree filtering".** Sweet spot: `whatToShow` + `acceptNode` returning `FILTER_REJECT` skips a node and all its descendants in one declaration. The 0.2.0-rc.2 fix's `ignoreAwareTextContent` walker (in `Data.Hyperly.TextContents`) is precisely this pattern hand-written with `firstChild` / `nextSibling` recursion. Replacing it with TreeWalker would express the intent directly:

```js
const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
  acceptNode: (n) => ignore(n.parentElement) ? FILTER_REJECT : FILTER_ACCEPT
})
```

**Hyperly's complexity is not in node iteration.** Three places where it actually lives:

1. **Context partitioning** (`TextContents.purs:textContentsByContext`'s A/B/C/D branches) — these are *structural decision logic*, not walk logic. "Does this parent have context-establishing children? If yes, recurse per child to keep contexts separate; if no, scrape the whole subtree as one entry." TreeWalker doesn't help with the decision; you'd still need bookkeeping for "current context" alongside the linear visit sequence.

2. **Match → portion index mapping** — projecting matches found in flattened text back to per-text-node `(node, offsetInNode, length)` slices. This is string-index ↔ DOM-position bijection; TreeWalker is irrelevant.

3. **Splice operations** (`Insert.purs`, `Transformer.purs`) — TreeWalker is a read-only iterator. The bulk of hyperly's code is structural mutation: portion-aware text-node split, `replaceWith` orchestration, `untilInsertable` walk-up logic for Outer-boundary insertion. None of this is in TreeWalker's wheelhouse.

**Per-module assessment (a priori):**

| Module | What TreeWalker buys |
|---|---|
| `ignoreAwareTextContent` | Real-looking win. Fewer lines, intent is direct. |
| `textContentsByContext` main flow | Marginal. Decision branches dominate; the walking part is small. |
| `Match.js` matching | Nothing. Runs on extracted strings, not the tree. |
| `Insert.purs` / `Transformer.purs` mutation | Nothing. TreeWalker is read-only. |

**Performance caveat (the warning we still managed to underestimate).** `:has(…)` and `querySelector` were once tempting for `hasContextElements` and lost to `innerHTML + regex` because happy-dom's selector parser dominated 64% of wrap/replace time on fresh-clone workloads (per 0.1.0 benchmarks). The lesson there was "higher-level API ≠ faster, benchmark before swapping". The TreeWalker spike below is a second instance of the same lesson, this time in the opposite direction (browser, not server).

**Spike outcome — DO NOT REPEAT.** Two implementations of `ignoreAwareTextContent` were benchmarked side-by-side on small / medium / large fixtures (`src/Demo/benchmark/treewalker-spike.js`, kept in-repo as evidence). The numbers are decisively against TreeWalker:

| Fixture | Manual (Chrome) | TreeWalker (Chrome) | Δ | Manual (happy-dom) | TreeWalker (happy-dom) | Δ |
|---|---:|---:|---:|---:|---:|---:|
| small  (19 chars)        | 0.27 µs   | 0.74 µs    | **+174%** | 0.42 µs | 0.44 µs | parity |
| medium (502 chars)       | 3.98 µs   | 12.24 µs   | **+207%** | 8.50 µs | 7.93 µs | -7%    |
| large  (2865 chars)      | 23.70 µs  | 68.25 µs   | **+188%** | 58.86 µs | 55.51 µs | -6%    |

happy-dom shows a 6–7% TreeWalker speedup; Chrome shows TreeWalker is **~3× slower across the board**. The criterion "if TreeWalker wins or ties on happy-dom, land it" was incomplete — we set it expecting happy-dom to be the slow path that gates the decision, but Chrome's optimisation gap between manual JS DFS and TreeWalker turned out to be much larger than happy-dom's. Probable cause: each `acceptNode` call crosses the V8 ↔ Blink boundary as a JS callback; manual DFS is a tight pure-JS loop that V8 inlines aggressively. happy-dom is all JS so the relative costs flip.

Decision (2026-05-02): **kept the hand-written manual walker**. The spike file is retained as a permanent benchmark so any future contributor can verify the result before re-proposing the swap. The plain `<p>` and inline-element fixtures used in the test suite already pin the contract; the spike covers the perf side of the same surface.

**Generalisation.** The "platform primitive APIs are slower than tight JS in V8" pattern probably applies to other tempting swaps too (`Range.createContextualFragment`, `Range.deleteContents` for splice, etc.). Don't assume; benchmark. Document negative results here so the next person doesn't relitigate.

**Out of scope for 0.2.0.** The deeper simplifications — better intermediate representation for Insert/Transformer splice (e.g. linearise the tree into a portion stream, operate on the stream, reify back to DOM); collapsing the A/B/C/D branches into a single uniform algorithm — are not TreeWalker-shaped and not 0.2.0-sized changes. Revisit post-1.0.
