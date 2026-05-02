/**
 * `ignoreAwareTextContent` — manual walk vs TreeWalker
 *
 * NEGATIVE RESULT — DO NOT SWAP. Kept in-repo as the empirical evidence so
 * future contributors don't relitigate. Full discussion in
 * `plans/dom-text-manipulation-design-notes.md` §2.
 *
 * Node.js : node src/Demo/benchmark/treewalker-spike.js
 * Browser : pnpm start  →  /benchmark/treewalker-spike.html
 *
 * Summary:
 *   happy-dom   : TreeWalker -6 to -7% (faster). Looks promising.
 *   Real Chrome : TreeWalker +174 to +207% (~3× SLOWER). Veto.
 *
 * The likely cause is JS-callback overhead inside `acceptNode`: each call
 * crosses V8 ↔ Blink, while a manual `firstChild` / `nextSibling` DFS is
 * a tight pure-JS loop V8 inlines aggressively. happy-dom is all JS so
 * the relative costs flip — its manual walk pays for everything in JS,
 * TreeWalker doesn't add an FFI hop. The browser is the dominant
 * deployment target, so happy-dom-only wins don't justify shipping a
 * change that regresses Chrome 3×.
 */

// ─── Environment setup ───────────────────────────────────────────────────────

const isBrowser = typeof globalThis.window !== 'undefined'

let testDoc
if (isBrowser) {
  testDoc = globalThis.document
} else {
  const { Window } = await import('happy-dom')
  const w = new Window({
    settings: {
      disableJavaScriptEvaluation: true,
      disableJavaScriptFileLoading: true,
      disableComputedStyleRendering: true,
      disableCSSFileLoading: true,
      disableIframePageLoading: true,
    },
  })
  testDoc = w.document
}

// ─── Output ──────────────────────────────────────────────────────────────────

let outputEl
if (isBrowser) {
  outputEl = document.createElement('pre')
  outputEl.style.cssText =
    'font:14px/1.6 monospace;padding:1.5rem;margin:0;white-space:pre-wrap'
  document.body.style.margin = '0'
  document.body.appendChild(outputEl)
}

const print = (text = '') => {
  console.log(text)
  if (outputEl) outputEl.textContent += text + '\n'
}

// ─── Implementations under test ──────────────────────────────────────────────
//
// Both must mirror `Data.Hyperly.TextContents.ignoreAwareTextContent`'s
// contract: walk the subtree of `atNode`, skip subtrees rooted at any node
// where `ignore(node)` is true, concatenate text-node content. Empty
// subtrees yield "". The walk does not escape past `atNode`'s children.

// (A) Manual walk — mirrors the current PS algorithm faithfully.
//     Iterative DFS using `advanceWithinRange` (nextSibling-or-up, bounded).
function manualImpl(atNode, ignore) {
  function advance(node) {
    if (node === atNode) return null
    if (node.nextSibling) return node.nextSibling
    if (node.parentNode) return advance(node.parentNode)
    return null
  }
  let acc = ''
  let node = atNode.firstChild
  while (node) {
    if (ignore(node)) {
      node = advance(node)
    } else if (node.nodeType === 3) { // TEXT_NODE
      acc += node.nodeValue
      node = advance(node)
    } else if (node.firstChild) {
      node = node.firstChild
    } else {
      node = advance(node)
    }
  }
  return acc
}

// (B) TreeWalker — declarative filter, FILTER_REJECT skips the entire
//     subtree rooted at the rejected node. SHOW_TEXT-only would still
//     descend into ignored elements (text-only filters skip non-matching
//     ancestors but don't reject their subtrees), so we ask for
//     SHOW_ELEMENT | SHOW_TEXT and FILTER_SKIP unwanted elements.
//
// NodeFilter constants (per DOM spec): hard-coded so we don't depend on
// the global being defined (happy-dom only exposes it on its own Window).
const SHOW_ELEMENT  = 0x1
const SHOW_TEXT     = 0x4
const FILTER_ACCEPT = 1
const FILTER_REJECT = 2
const FILTER_SKIP   = 3

function treeWalkerImpl(atNode, ignore) {
  const doc = atNode.ownerDocument
  const walker = doc.createTreeWalker(
    atNode,
    SHOW_ELEMENT | SHOW_TEXT,
    {
      acceptNode: (n) =>
        ignore(n) ? FILTER_REJECT
        : n.nodeType === 3 ? FILTER_ACCEPT
        : FILTER_SKIP,
    },
  )
  let acc = ''
  let n
  while ((n = walker.nextNode())) acc += n.nodeValue
  return acc
}

// ─── ignore predicate (mirrors ignoreDefault for empty text + script/style) ──

function defaultIgnore(node) {
  if (node.nodeType === 3) return (node.nodeValue ?? '') === ''
  if (node.nodeType !== 1) return false
  const tag = node.tagName?.toLowerCase()
  return tag === 'script' || tag === 'style' || tag === 'head'
}

// Custom ignore for stress: skip `<span class="skip">` subtrees too.
// Mirrors the README composition pattern.
function customIgnore(node) {
  if (defaultIgnore(node)) return true
  return node.nodeType === 1 && node.classList?.contains('skip')
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

const html = {
  // Hot path: trivial single-paragraph subtree, nothing to skip.
  small: '<p>Hello world.</p>',

  // Typical: article with a few default-ignored subtrees (script/style).
  medium: `
    <article>
      <h1>Benchmark Article</h1>
      <style>.x { color: red; }</style>
      <p>First paragraph with <a href="#">a link</a> and <em>emphasis</em>.</p>
      <p>Second paragraph with <strong>bold text</strong>.</p>
      <ul>
        <li>Item one</li>
        <li>Item two with <strong>bold</strong></li>
        <li>Item three</li>
      </ul>
      <script>console.log('ignored')</script>
      <blockquote>A quoted passage here.</blockquote>
      <p>Closing paragraph.</p>
    </article>`,

  // Stress: 50 paragraphs, every fifth wraps text in <span class="skip">,
  // exercises both default- and custom-ignored subtrees.
  large: `<article>${
    Array.from({ length: 50 }, (_, i) => {
      const inner = i % 5 === 0
        ? `Para <span class="skip">SKIP-${i}</span> end ${i}.`
        : `Plain text in paragraph ${i} with <em>emphasis</em>.`
      return `<p>${inner}</p>`
    }).join('')
  }<style>.a{color:red}</style><script>x()</script></article>`,
}

function makeEl(markup) {
  const el = testDoc.createElement('div')
  el.innerHTML = markup.trim()
  return el
}

const fixtures = {
  small:  { el: makeEl(html.small),  ignore: defaultIgnore },
  medium: { el: makeEl(html.medium), ignore: defaultIgnore },
  large:  { el: makeEl(html.large),  ignore: customIgnore  },
}

// ─── Harness ─────────────────────────────────────────────────────────────────

const WARMUP = 1_000
const ITER   = 20_000

function bench(label, fn, iter = ITER, warmup = WARMUP) {
  for (let i = 0; i < warmup; i++) fn()
  const t0 = performance.now()
  for (let i = 0; i < iter; i++) fn()
  const ms = performance.now() - t0
  const us = (ms / iter * 1000).toFixed(2)
  print(`  · ${label}`)
  print(`    ${ms.toFixed(1).padStart(8)} ms total   ${us.padStart(7)} µs/op`)
}

function section(title) {
  print()
  print('═'.repeat(60))
  print(` ${title}`)
  print('═'.repeat(60))
}

// ─── Correctness check (both impls must agree on every fixture) ──────────────

print()
const env = isBrowser
  ? `Browser  ${navigator.userAgent.match(/\(([^)]+)\)/)?.[1] ?? ''}`
  : `Node.js  ${process.version}  (happy-dom)`

print(`ignoreAwareTextContent — manual vs TreeWalker — ${env}`)
print()
print('── Correctness: both impls must produce the same output ──')
let allOk = true
for (const [name, { el, ignore }] of Object.entries(fixtures)) {
  const manual = manualImpl(el, ignore)
  const walker = treeWalkerImpl(el, ignore)
  const ok = manual === walker
  if (!ok) {
    print(`  ✗ ${name}:`)
    print(`     manual: ${JSON.stringify(manual.slice(0, 80))}…`)
    print(`     walker: ${JSON.stringify(walker.slice(0, 80))}…`)
    allOk = false
  } else {
    print(`  ✓ ${name}  (${manual.length} chars)`)
  }
}
if (!allOk) {
  print()
  print('⚠ implementations disagree — bench numbers below would be meaningless.')
  process.exit(1)
}

// ─── Run ─────────────────────────────────────────────────────────────────────

for (const [name, { el, ignore }] of Object.entries(fixtures)) {
  section(`${name}  (innerHTML: ${el.innerHTML.length} chars)`)
  bench('manual    (firstChild / nextSibling DFS)', () => manualImpl(el, ignore))
  bench('TreeWalker (FILTER_REJECT subtree skip) ', () => treeWalkerImpl(el, ignore))
}

print()
