/**
 * Hyperly vs findAndReplaceDOMText — wrap and replace performance.
 *
 * Node.js : node src/Demo/benchmark/findAndReplaceDOMText.js
 * Browser : pnpm start  →  /benchmark/findAndReplaceDOMText.html
 *
 * Both libraries are run on the same DOM (happy-dom server-side, native
 * DOM in browser). Each iteration starts from a fresh `cloneNode(true)`
 * of the fixture so neither library sees a pre-mutated tree.
 */

// Import directly from the published lib bundle so the numbers reflect
// what users actually load. Switch the path between `.fp.js` and
// `.fp.min.js` if you want to measure the minified production build.
import { wrap, replace } from '../../../lib/hyperly.fp.js'

// ─── Environment setup ───────────────────────────────────────────────────────
//
// findAndReplaceDOMText is a UMD module that reads `document` from globals at
// load time, so we must (a) install happy-dom's globals first, then (b)
// dynamically import the library.

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
  globalThis.window   = w
  globalThis.document = w.document
  globalThis.Node     = w.Node
  globalThis.Element  = w.Element
  globalThis.Text     = w.Text
}

const findAndReplaceDOMText = (await import('findandreplacedomtext')).default

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

// ─── Fixtures ────────────────────────────────────────────────────────────────

const fixtures = {
  // One match contained entirely within a single text node.
  simple: '<p>Hello World, this is a simple test.</p>',

  // One match split across two text nodes by an inline element.
  crossElement: '<p>Hello <b>W</b>orld, with split match.</p>',

  // ~60 matches, mixed single-node and cross-element.
  bulky: Array.from({ length: 30 }, (_, i) =>
    `<p>The <b>W</b>orld of paragraph ${i} contains another World sandwiched among words.</p>`
  ).join('\n'),
}

function makeTemplate(html) {
  const el = testDoc.createElement('div')
  el.innerHTML = html
  return el
}

const templates = Object.fromEntries(
  Object.entries(fixtures).map(([k, v]) => [k, makeTemplate(v)])
)

// ─── Harness ─────────────────────────────────────────────────────────────────

const WARMUP_FACTOR = 0.1  // 10% of measurement iterations

function timeMs(fn, iter) {
  const warmup = Math.max(50, Math.ceil(iter * WARMUP_FACTOR))
  for (let i = 0; i < warmup; i++) fn()

  const t0 = performance.now()
  for (let i = 0; i < iter; i++) fn()
  return performance.now() - t0
}

function compare(label, hyperlyFn, findAndReplaceFn, iter) {
  const hyperlyMs        = timeMs(hyperlyFn,        iter)
  const findAndReplaceMs = timeMs(findAndReplaceFn, iter)

  const hyperlyUs        = (hyperlyMs        / iter * 1000)
  const findAndReplaceUs = (findAndReplaceMs / iter * 1000)
  const ratio            = (findAndReplaceMs / hyperlyMs)
  const winner           = ratio >= 1 ? 'hyperly' : 'findAndReplaceDOMText'
  const factor           = ratio >= 1 ? ratio : 1 / ratio

  print(`  ${label}  (${iter.toLocaleString()} iter)`)
  print(`    hyperly              : ${hyperlyUs.toFixed(2).padStart(8)} µs/op`)
  print(`    findAndReplaceDOMText: ${findAndReplaceUs.toFixed(2).padStart(8)} µs/op`)
  print(`    → ${winner} is ${factor.toFixed(2)}× faster`)
  print()
}

function section(title) {
  print()
  print('═'.repeat(64))
  print(` ${title}`)
  print('═'.repeat(64))
}

// ─── Helpers for each implementation ─────────────────────────────────────────

const fresh = (k) => templates[k].cloneNode(true)

// Hyperly: curried `wrap(regex)(wrapper)(element)`
const hWrap = (regex, wrapper) => (k) => wrap(regex)(wrapper)(fresh(k))

// Hyperly: curried `replace(regex)(replacement)(element)`
const hReplace = (regex, replacement) => (k) => replace(regex)(replacement)(fresh(k))

// findAndReplaceDOMText: imperative API, mutates the element in place.
const fWrap = (regex, tagName) => (k) =>
  findAndReplaceDOMText(fresh(k), { find: regex, wrap: tagName })

const fReplace = (regex, replacement) => (k) =>
  findAndReplaceDOMText(fresh(k), { find: regex, replace: () => replacement })

// ─── Run ─────────────────────────────────────────────────────────────────────

print(`Hyperly vs findAndReplaceDOMText  (${isBrowser ? 'browser DOM' : 'happy-dom'})`)
print(`Node ${typeof process !== 'undefined' ? process.version : '(browser)'}`)

section('wrap')

compare(
  'simple — 1 match, 1 text node',
  () => hWrap(/World/g, '<mark />')('simple'),
  () => fWrap(/World/g, 'mark')('simple'),
  3000,
)

compare(
  'crossElement — 1 match split across 2 nodes',
  () => hWrap(/World/g, '<mark />')('crossElement'),
  () => fWrap(/World/g, 'mark')('crossElement'),
  3000,
)

compare(
  'bulky — ~60 matches across 30 paragraphs',
  () => hWrap(/World/g, '<mark />')('bulky'),
  () => fWrap(/World/g, 'mark')('bulky'),
  300,
)

section('replace')

compare(
  'simple — 1 match, 1 text node',
  () => hReplace(/World/g, 'Universe')('simple'),
  () => fReplace(/World/g, 'Universe')('simple'),
  3000,
)

compare(
  'crossElement — 1 match split across 2 nodes',
  () => hReplace(/World/g, 'Universe')('crossElement'),
  () => fReplace(/World/g, 'Universe')('crossElement'),
  3000,
)

compare(
  'bulky — ~60 matches across 30 paragraphs',
  () => hReplace(/World/g, 'Universe')('bulky'),
  () => fReplace(/World/g, 'Universe')('bulky'),
  300,
)

print()
