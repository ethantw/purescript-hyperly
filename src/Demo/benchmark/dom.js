/**
 * happy-dom / browser DOM API benchmark
 *
 * Node.js : node src/Demo/benchmark/dom.js
 * Browser : pnpm start  →  /benchmark/dom.html
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

// ─── Fixtures (mirrors Options.purs exactly, including duplicates) ──────────
//
// The list and regex character class below must stay byte-identical with
// production code in `src/Data/Hyperly/Options.purs` so this benchmark
// reflects real `hasContextElementsDefault` cost.

const contextElements = [
  // contextElements proper:
  'html', 'body',
  'address', 'article', 'aside', 'blockquote', 'dd', 'div', 'dl',
  'fieldset', 'figcaption', 'figure', 'footer', 'form',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup',
  'main', 'nav',
  'ol', 'output', 'p', 'pre', 'section', 'ul', 'br', 'li', 'summary',
  'dt', 'details', 'rp', 'rt', 'rtc',
  'script', 'style', 'noscript',
  'img', 'video', 'audio', 'canvas', 'svg', 'map', 'object',
  'input', 'textarea', 'select', 'option', 'optgroup', 'button',
  'table', 'tbody', 'thead',
  'th', 'tr', 'td', 'caption', 'col', 'tfoot', 'colgroup',
  // contextualVoidElements (Options.purs concats this onto contextElements):
  'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link',
  'meta', 'param', 'source', 'track',
]

const qsaSelector    = contextElements.join(',')
const hasSelector    = `:has(${qsaSelector})`
// `[ />]` matches space, `/` (self-closing tags like <br/>), or `>`.
const innerHTMLRegex = new RegExp(`<(${contextElements.join('|')})[ />]`, 'i')

const html = {
  inlineOnly:
    '<span>Hello <em>world</em> and <strong>more</strong></span>',

  mixed:
    '<div><p>First <strong>para</strong></p><p>Second</p><ul><li>A</li><li>B</li></ul></div>',

  article: `
    <article>
      <h1>Benchmark Article</h1>
      <p>First paragraph with <a href="#">a link</a> and <em>emphasis</em>.</p>
      <p>Second paragraph with <strong>bold text</strong>.</p>
      <ul>
        <li>Item one</li>
        <li>Item two with <strong>bold</strong></li>
        <li>Item three</li>
      </ul>
      <blockquote>A quoted passage here.</blockquote>
      <p>Closing paragraph.</p>
    </article>`,

  table: `
    <table>
      <thead><tr><th>Name</th><th>Value</th><th>Note</th></tr></thead>
      <tbody>
        ${Array.from({ length: 20 }, (_, i) =>
          `<tr><td>Row ${i}</td><td>${i * 10}</td><td>note ${i}</td></tr>`
        ).join('\n        ')}
      </tbody>
    </table>`,
}

function makeEl(markup) {
  const el = testDoc.createElement('div')
  el.innerHTML = markup
  return el
}

const els = Object.fromEntries(
  Object.entries(html).map(([k, v]) => [k, makeEl(v)])
)

// ─── Harness ─────────────────────────────────────────────────────────────────

const WARMUP       = 2_000
const ITER         = 30_000
// Cloning-based benches keep one fresh DOM tree alive per iteration; on
// happy-dom each tree is a heavy JS object, so 30k clones overflow heap.
const ITER_CLONE   = 1_000
const WARMUP_CLONE = 100

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

function sub(label) {
  print()
  print(`  ▸ ${label}`)
}

// ─── Run ─────────────────────────────────────────────────────────────────────

const env = isBrowser
  ? `Browser  ${navigator.userAgent.match(/\(([^)]+)\)/)?.[1] ?? ''}`
  : `Node.js  ${process.version}  (happy-dom)`

print(`DOM API Benchmark — ${env}`)

// ─── Correctness check ───────────────────────────────────────────────────────

const verify = (label, got, expected) => {
  const ok = got === expected
  print(`  ${ok ? '✓' : '✗'} ${label}: got ${got}, expected ${expected}`)
  return ok
}

{
  print()
  print('── Correctness: matches(":has(...)") ──')
  const withCtx    = makeEl('<div><p>text</p></div>')
  const withoutCtx = makeEl('<span>only inline</span>')
  const allOk =
    verify('has context element   ', withCtx.matches(hasSelector),    true)  &&
    verify('no context element    ', withoutCtx.matches(hasSelector), false)
  if (!allOk) {
    print()
    print('⚠ matches(":has()") is returning wrong results — benchmark numbers will be meaningless.')
    print()
  }
}

// 1. hasContextElements
//    Two access patterns:
//      a) Reuse the same element across iterations (microbench style;
//         exposes any per-element selector caching the DOM impl might do).
//      b) cloneNode the element every iteration (mirrors hyperly's real
//         workload, where every wrap/replace operates on freshly-cloned
//         input elements — cache hits don't accumulate).
section('1. hasContextElements: QSA vs :has() vs innerHTML+regex')
for (const [name, el] of Object.entries(els)) {
  sub(`[${name}]  innerHTML length: ${el.innerHTML.length}  — same element reused`)
  bench('querySelector (first context el)', () => el.querySelector(qsaSelector))
  bench('matches(":has(...)")',             () => el.matches(hasSelector))
  bench('innerHTML + regex.test',           () => innerHTMLRegex.test(el.innerHTML))

  sub(`[${name}]  — fresh cloneNode each call (hyperly's pattern, ${ITER_CLONE.toLocaleString()} iter)`)
  bench('querySelector (first context el)',
        () => el.cloneNode(true).querySelector(qsaSelector),
        ITER_CLONE, WARMUP_CLONE)
  bench('matches(":has(...)")',
        () => el.cloneNode(true).matches(hasSelector),
        ITER_CLONE, WARMUP_CLONE)
  bench('innerHTML + regex.test',
        () => innerHTMLRegex.test(el.cloneNode(true).innerHTML),
        ITER_CLONE, WARMUP_CLONE)
}

// 2. Node traversal
section('2. Node traversal (article)')
const articleEl = els.article
sub('visit every node')
bench('querySelectorAll("*") + forEach', () =>
  articleEl.querySelectorAll('*').forEach(() => {})
)
bench('manual firstChild / nextSibling', () => {
  const stack = [articleEl.firstChild]
  while (stack.length) {
    const node = stack.pop()
    if (!node) continue
    if (node.firstChild)  stack.push(node.firstChild)
    if (node.nextSibling) stack.push(node.nextSibling)
  }
})

// 3. Text content
section('3. Text content extraction (article)')
sub('read text from element')
bench('.textContent (property)',          () => articleEl.textContent)
bench('.innerHTML then strip tags',       () => articleEl.innerHTML.replace(/<[^>]+>/g, ''))

// 4. Node name
section('4. Node name reading')
const pEl = testDoc.createElement('p')
sub('get tag name')
bench('.tagName',                         () => pEl.tagName)
bench('.nodeName',                        () => pEl.nodeName)
bench('.localName',                       () => pEl.localName)

// 5. Parsing cost
section('5. Parsing: createHTMLDocument vs createElement')
const ITER_CREATE = 5_000
sub(`parse article-size HTML  (${ITER_CREATE.toLocaleString()} iterations)`)
bench('createHTMLDocument + doc.write', () => {
  const d = testDoc.implementation.createHTMLDocument()
  d.write(`<html><body>${html.article}</body></html>`)
}, ITER_CREATE)
bench('createElement("div") + innerHTML', () => {
  const d = testDoc.createElement('div')
  d.innerHTML = html.article
}, ITER_CREATE)

print()
