/**
 * Focused CPU profile for hyperly wrap on the bulky case (server-side).
 *
 * Run:  node --cpu-prof --cpu-prof-dir=. --cpu-prof-name=hyperly.cpuprofile src/Demo/benchmark/profile.js
 * Then drag the resulting .cpuprofile into Chrome DevTools → Performance → Load Profile.
 */

import { wrap } from '../../../lib/hyperly.fp.js'

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
const doc = w.document

const html = Array.from({ length: 30 }, (_, i) =>
  `<p>The <b>W</b>orld of paragraph ${i} contains another World sandwiched among words.</p>`
).join('\n')

const template = doc.createElement('div')
template.innerHTML = html

// Warm up.
for (let i = 0; i < 200; i++) {
  wrap(/World/g)('<mark />')(template.cloneNode(true))
}

// Profile region: many iterations to dominate the profile signal.
console.log('Profiling 2000 iterations of wrap (bulky)...')
const t0 = performance.now()
for (let i = 0; i < 2000; i++) {
  wrap(/World/g)('<mark />')(template.cloneNode(true))
}
const elapsed = performance.now() - t0
console.log(`Done. ${(elapsed / 2000).toFixed(2)} µs/op average.`)
