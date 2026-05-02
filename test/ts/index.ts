import 'iterator-helpers-polyfill'
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'

// ── Uncurried (src/js/) ──────────────────────────────────────────────────────

import {
  html, element,
  textContents, contextlessTextContents,
} from '#hyperly/hyperly.js'
import { match, matchContextlessly } from '#hyperly/match.js'
import { replace, replaceContextlessly } from '#hyperly/replace.js'
import { transform, transformContextlessly } from '#hyperly/transform.js'
import { insert, insertContextlessly } from '#hyperly/insert.js'
import { wrap, wrapContextlessly } from '#hyperly/wrap.js'
import { revert, revertAll } from '#hyperly/revert.js'
import { defaultOptions, contextlessOptions } from '#hyperly/options.js'

// ── Curried / fp (mirrors the public 'hyperly/fp' subpath) ───────────────────

import {
  textContents as fpTextContents,
  match as fpMatch,
  replace as fpReplace,
  transform as fpTransform,
  insert as fpInsert,
  wrap as fpWrap,
  revert as fpRevert,
} from '#hyperly/fp'

// ── Uncurried tests ──────────────────────────────────────────────────────────

describe('textContents (uncurried)', () => {
  it('textContents(src) — default options', () => {
    assert.deepEqual(textContents('<b>hello</b> <p>world</p>'), ['hello ', 'world'])
  })

  it('textContents(options, src) — custom options (empty == default)', () => {
    assert.deepEqual(textContents({}, '<a>A</a> <b>ab</b> BC <p>para</p>'), ['A ab BC ', 'para'])
  })

  it('contextlessTextContents joins all text', () => {
    assert.deepEqual(contextlessTextContents('<b>hello</b> <p>world</p>'), ['hello world'])
  })

  it('returns one empty string for empty HTML', () => {
    assert.deepEqual(textContents(''), [''])
  })
})

describe('match (uncurried)', () => {
  it('match(regex, src) — default', () => {
    const matches = match(/\b([a-z])([a-z])\b/gi, '<b>ab</b> BC')
    assert.equal(matches.length, 2)
    assert.equal(matches[0].captures[0], 'ab')
    assert.equal(matches[1].captures[0], 'BC')
  })

  it('match(options, regex, src) — custom options', () => {
    assert.equal(match({}, /\b([a-z])([a-z])\b/gi, '<b>ab</b> BC').length, 2)
  })

  it('matchContextlessly across block boundaries', () => {
    // Contextful: /ab/ can't span the <p> seam → 0 matches.
    // Contextless: tree is flattened to "ab" → 1 match.
    assert.equal(match(/ab/g, '<p>a</p><p>b</p>').length, 0)
    const matches = matchContextlessly(/ab/g, '<p>a</p><p>b</p>')
    assert.equal(matches.length, 1)
    assert.equal(matches[0].captures[0], 'ab')
  })

  it('matchContextlessly with text-level inline elements (parity)', () => {
    // <a>/<b> aren't context boundaries — both modes match. This pins that
    // contextless mode doesn't introduce surprises for inline elements.
    assert.equal(match(/ab/g, '<a>a</a><b>b</b>').length, 1)
    assert.equal(matchContextlessly(/ab/g, '<a>a</a><b>b</b>').length, 1)
  })

  it('returns empty array when no matches', () => {
    assert.equal(match(/xyz/g, '<b>ab</b>').length, 0)
  })

  it('captures named groups', () => {
    const [m] = match(/\b(?<first>[a-z])(?<second>[a-z])\b/gi, 'ab')
    assert.equal(m.groups.first, 'a')
    assert.equal(m.groups.second, 'b')
  })
})

describe('replace (uncurried)', () => {
  it('replace(regex, replacement, src) — default', () => {
    assert.equal(
      html(replace(/\b([a-z])([a-z])\b/gi, '_**_', '<a>A</a> <b>ab</b> BC')),
      '<a>A</a> <b>_**_</b> _**_',
    )
  })

  it('replace(options, regex, replacement, src) — custom options', () => {
    assert.equal(
      html(replace({}, /\b([a-z])([a-z])\b/gi, '_**_', '<a>A</a> <b>ab</b> BC')),
      '<a>A</a> <b>_**_</b> _**_',
    )
  })

  it('group back-references', () => {
    assert.equal(
      html(replace(/\b([a-z])([a-z])\b/gi, '$2$1', 'abc <p>ab</p>')),
      'abc <p>ba</p>',
    )
  })

  it('replaceContextlessly across block boundaries', () => {
    // Replacement is sliced across portions in proportion to original length:
    // 'a' (1 char) → 'X', 'b' (1 char) → 'Y'.
    assert.equal(
      html(replaceContextlessly(/ab/g, 'XY', '<p>a</p><p>b</p>')),
      '<p>X</p><p>Y</p>',
    )
  })

  it('replaceContextlessly with text-level inline elements', () => {
    // Same per-portion slicing across <a>/<b> — non-context elements behave
    // identically to the block-level case.
    assert.equal(
      html(replaceContextlessly(/ab/g, 'XY', '<a>a</a><b>b</b>')),
      '<a>X</a><b>Y</b>',
    )
  })

  it('result is a Hype with history', () => {
    const h = replace(/ab/g, 'XY', '<p>ab</p>')
    assert.equal(h.tag, 'Hype')
    assert.equal(h._3.length, 1)
  })
})

describe('transform (uncurried)', () => {
  it('transform(regex, transformer, src) — default', () => {
    assert.equal(
      html(transform(/\b([a-z])([a-z])\b/gi, sp => _m => sp.text.toUpperCase(), '<a>A</a> <b>ab</b> BC')),
      '<a>A</a> <b>AB</b> BC',
    )
  })

  it('transform(options, regex, transformer, src) — custom options', () => {
    assert.equal(
      html(transform({}, /\b([a-z])([a-z])\b/gi, sp => _m => sp.text.toUpperCase(), '<b>ab</b> BC')),
      '<b>AB</b> BC',
    )
  })

  it('transformer receives portion info', () => {
    const portions: any[] = []
    transform(/\b([a-z])([a-z])([a-z])\b/gi, sp => _m => { portions.push(sp); return sp.text }, '<b>ab</b>c')
    assert.ok(portions.length > 0)
    assert.ok(typeof portions[0].text === 'string')
    assert.ok(typeof portions[0].start === 'boolean')
  })

  it('transformContextlessly across block boundaries', () => {
    // Each portion is fed to the transformer separately and the result lands
    // in that portion's original parent.
    assert.equal(
      html(transformContextlessly(/ab/g, sp => _m => sp.text.toUpperCase(), '<p>a</p><p>b</p>')),
      '<p>A</p><p>B</p>',
    )
  })

  it('transformContextlessly with text-level inline elements', () => {
    assert.equal(
      html(transformContextlessly(/ab/g, sp => _m => sp.text.toUpperCase(), '<a>a</a><b>b</b>')),
      '<a>A</a><b>B</b>',
    )
  })
})

describe('insert (uncurried)', () => {
  it('insert(regex, insertion, src) — outer brackets', () => {
    assert.equal(
      html(insert(/\b([a-z])([a-z])\b/gi, { start: '[', end: ']', outer: true }, '<a>a</a> <b>b</b>c abc cd')),
      '<a>a</a> [<b>b</b>c] abc [cd]',
    )
  })

  it('insert(regex, insertion, src) — inner brackets', () => {
    assert.equal(
      html(insert(/\b([a-z])([a-z])\b/gi, { start: '[', end: ']' }, '<a>a</a> <b>b</b>c abc cd')),
      '<a>a</a> <b>[b</b>c] abc [cd]',
    )
  })

  it('insert with between separator (outer)', () => {
    assert.equal(
      html(insert(/\b([a-z])([a-z])([a-z])\b/gi, { between: '|', outer: true }, '<b>ab</b>c')),
      '<b>ab</b>|c',
    )
  })

  it('insert(options, regex, insertion, src) — custom options', () => {
    assert.equal(
      html(insert({}, /\b([a-z])([a-z])\b/gi, { start: '(', end: ')' }, 'ab CD')),
      '(ab) (CD)',
    )
  })

  it('insert with empty insertion throws', () => {
    assert.throws(
      () => insert(/\bfoo\b/g, {} as any, '<p>foo</p>'),
      /at least one of/,
    )
  })

  it('insert with only `outer: true` (no start/between/end) throws', () => {
    assert.throws(
      () => insert(/\bfoo\b/g, { outer: true } as any, '<p>foo</p>'),
      /at least one of/,
    )
  })

  // `Around Outer` walks up to the enclosing element boundary by skipping
  // empty text-node placeholders that the portion-split injects. Without
  // that skip (which is centralised in PS's `Insert.purs:untilInsertable`),
  // contextless mode would stop at every placeholder and trap brackets
  // inside the original parent.
  //
  // Inner places brackets directly in the portion's text flow (no walk-up),
  // so Inner and Outer differ in both `start`/`end` (adjacent vs. boundary)
  // and `between` (end of previous portion's container vs. inter-element gap).

  it('insertContextlessly across block boundaries (Inner)', () => {
    assert.equal(
      html(insertContextlessly(/ab/g, { start: '[', between: '|', end: ']' }, '<p>a</p><p>b</p>')),
      '<p>[a|</p><p>b]</p>',
    )
  })

  it('insertContextlessly across block boundaries (Outer)', () => {
    assert.equal(
      html(insertContextlessly(/ab/g, { start: '[', between: '|', end: ']', outer: true }, '<p>a</p><p>b</p>')),
      '[<p>a</p>|<p>b</p>]',
    )
  })

  it('insertContextlessly with text-level inline elements (Inner)', () => {
    // Inner brackets stay adjacent to the matched text inside the inline
    // parents — same as the block-level case.
    assert.equal(
      html(insertContextlessly(/ab/g, { start: '[', between: '|', end: ']' }, '<a>a</a><b>b</b>')),
      '<a>[a|</a><b>b]</b>',
    )
  })

  it('insertContextlessly with text-level inline elements (Outer)', () => {
    // Outer reaches the enclosing boundary even past inline parents.
    assert.equal(
      html(insertContextlessly(/ab/g, { start: '[', between: '|', end: ']', outer: true }, '<a>a</a><b>b</b>')),
      '[<a>a</a>|<b>b</b>]',
    )
  })
})

describe('wrap (uncurried)', () => {
  it('wrap(regex, wrapper, src) — default', () => {
    assert.equal(
      html(wrap(/\b([a-z])([a-z])\b/gi, '<mark />', '<a>A</a> <b>ab</b> BC')),
      '<a>A</a> <b><mark>ab</mark></b> <mark>BC</mark>',
    )
  })

  it('wrap(options, regex, wrapper, src) — custom options', () => {
    assert.equal(
      html(wrap({}, /\b\w+\b/gi, '<b />', 'foo bar')),
      '<b>foo</b> <b>bar</b>',
    )
  })

  it('wrapContextlessly across block boundaries', () => {
    // Each portion of the cross-boundary match is wrapped in its original
    // parent. Contextful wrap(/ab/) would not match — /ab/ can't span the
    // <p> seam.
    assert.equal(
      html(wrapContextlessly(/ab/g, '<em />', '<p>a</p><p>b</p>')),
      '<p><em>a</em></p><p><em>b</em></p>',
    )
  })

  it('wrapContextlessly with text-level inline elements', () => {
    assert.equal(
      html(wrapContextlessly(/ab/g, '<em />', '<a>a</a><b>b</b>')),
      '<a><em>a</em></a><b><em>b</em></b>',
    )
  })

  it('wrap with no matches leaves source untouched', () => {
    assert.equal(
      html(wrap(/xyz/g, '<mark />', '<p>abc</p>')),
      '<p>abc</p>',
    )
  })
})

describe('revert (uncurried)', () => {
  it('revert undoes last replace', () => {
    const h1 = replace(/ab/g, 'XY', '<p>ab cd</p>')
    assert.equal(html(revert(h1)), '<p>ab cd</p>')
  })

  it('revertAll undoes all operations', () => {
    const h1 = replace(/ab/g, 'XY', '<p>ab cd ab</p>')
    const h2 = replace(/cd/g, 'ZZ', h1)
    assert.equal(html(h2), '<p>XY ZZ XY</p>')
    assert.equal(html(revertAll(h2)), '<p>ab cd ab</p>')
  })

  it('revert undoes wrap', () => {
    const h1 = wrap(/\b\w+\b/gi, '<mark />', '<p>foo bar</p>')
    assert.equal(html(h1), '<p><mark>foo</mark> <mark>bar</mark></p>')
    assert.equal(html(revert(h1)), '<p>foo bar</p>')
  })
})

// ── Error propagation: PS Left → JS throw ────────────────────────────────────
//
// Operations that return `Either String Hype` in PS unwrap on the JS side:
// `Right` becomes the `Hype`; `Left` becomes a thrown `Error` carrying the
// PS-side message. These tests pin that contract.

describe('throws on Left (zero-length match)', () => {
  // /^/g matches at position 0 — a zero-length match. PS rejects these for
  // any operation that needs to splice the matched range.
  const ZL = /^/g
  const expected = /zero-length matches/

  it('replace throws', () => {
    assert.throws(() => replace(ZL, 'X', '<p>foo</p>'), expected)
  })

  it('insert throws', () => {
    assert.throws(() => insert(ZL, { start: '[', end: ']' }, '<p>foo</p>'), expected)
  })

  it('transform throws', () => {
    assert.throws(() => transform(ZL, _p => _m => 'X', '<p>foo</p>'), expected)
  })

  it('wrap throws', () => {
    assert.throws(() => wrap(ZL, '<mark />', '<p>foo</p>'), expected)
  })

  it('error is a real Error instance with the PS message', () => {
    try {
      replace(ZL, 'X', '<p>foo</p>')
      assert.fail('did not throw')
    } catch (e) {
      assert.ok(e instanceof Error)
      assert.match((e as Error).message, expected)
    }
  })
})

describe('throws on Left (invalid wrapper)', () => {
  it('wrap with a void element throws', () => {
    assert.throws(
      () => wrap(/\bfoo\b/g, '<br />', '<p>foo</p>'),
      /void element/,
    )
  })

  it('wrap with another void element (<wbr>) throws', () => {
    assert.throws(
      () => wrap(/\bfoo\b/g, '<wbr />', '<p>foo</p>'),
      /void element/,
    )
  })

  it('isVoidElement override is honoured (wrap rejects custom-marked element)', () => {
    assert.throws(
      () => wrap(
        { isVoidElement: node => (node as Element).tagName?.toLowerCase() === 'span' },
        /\bfoo\b/g,
        '<span />',
        '<p>foo</p>',
      ),
      /void element/,
    )
  })
})

describe('throws on invalid source', () => {
  it('match with non-Hyperly source throws', () => {
    assert.throws(
      () => match(/foo/g, 42 as any),
      /Hyperly only accepts/,
    )
  })

  it('match with null source throws', () => {
    assert.throws(
      () => match(/foo/g, null as any),
      /Hyperly only accepts/,
    )
  })
})

// ── Curried / fp tests ───────────────────────────────────────────────────────

describe('fp (curried) — default', () => {
  it('textContents(src) — bare', () => {
    assert.deepEqual(fpTextContents('<b>hello</b> <p>world</p>'), ['hello ', 'world'])
  })

  it('match(regex)(src)', () => {
    const matches = fpMatch(/\b([a-z])([a-z])\b/gi)('<b>ab</b> BC')
    assert.equal(matches.length, 2)
    assert.equal(matches[0].captures[0], 'ab')
  })

  it('replace(regex)(replacement)(src)', () => {
    assert.equal(
      html(fpReplace(/\b([a-z])([a-z])\b/gi)('_**_')('<a>A</a> <b>ab</b> BC')),
      '<a>A</a> <b>_**_</b> _**_',
    )
  })

  it('transform(regex)(transformer)(src)', () => {
    assert.equal(
      html(fpTransform(/\b([a-z])([a-z])\b/gi)(sp => _m => sp.text.toUpperCase())('<a>A</a> <b>ab</b> BC')),
      '<a>A</a> <b>AB</b> BC',
    )
  })

  it('insert(regex)(insertion)(src)', () => {
    assert.equal(
      html(fpInsert(/\b([a-z])([a-z])\b/gi)({ start: '[', end: ']', outer: true })('<a>a</a> <b>b</b>c abc cd')),
      '<a>a</a> [<b>b</b>c] abc [cd]',
    )
  })

  it('wrap(regex)(wrapper)(src)', () => {
    assert.equal(
      html(fpWrap(/\b\w+\b/gi)('<mark />')('<a>A</a> <b>ab</b> BC')),
      '<a><mark>A</mark></a> <b><mark>ab</mark></b> <mark>BC</mark>',
    )
  })

  it('revert', () => {
    const h1 = fpReplace(/ab/g)('XY')('<p>ab cd</p>')
    assert.equal(html(fpRevert(h1)), '<p>ab cd</p>')
  })
})

describe('fp (curried) — custom options', () => {
  it('textContents(options)(src)', () => {
    assert.deepEqual(fpTextContents({})('<b>hello</b> <p>world</p>'), ['hello ', 'world'])
  })

  it('match(options)(regex)(src)', () => {
    const matches = fpMatch({})(/\b\w+\b/gi)('<b>ab</b> cd')
    assert.equal(matches.length, 2)
  })

  it('replace(options)(regex)(replacement)(src)', () => {
    assert.equal(
      html(fpReplace({})(/\b\w+\b/g)('X')('foo bar')),
      'X X',
    )
  })

  it('insert(options)(regex)(insertion)(src)', () => {
    assert.equal(
      html(fpInsert({})(/\b\w+\b/g)({ start: '[', end: ']' })('foo')),
      '[foo]',
    )
  })

  it('wrap(options)(regex)(wrapper)(src)', () => {
    assert.equal(
      html(fpWrap({})(/\b\w+\b/g)('<b />')('foo')),
      '<b>foo</b>',
    )
  })
})

// ── defaultOptions / contextlessOptions ──────────────────────────────────────
//
// The four predicates from the PS-side `defaultOptions` / `contextlessOptions`
// records, surfaced as a frozen, uncurried `Required<Options>` so consumers
// can compose on top of them. See `js/options.js`.

// Borrow the same happy-dom window hyperly initialised internally (any
// Element will do — its ownerDocument carries the right Node/Element
// constructors). Avoids a second `new Window()` and keeps prototype
// identity consistent with what the operations see.
const $owner = element('<div></div>').ownerDocument!
const make = (tag: string, innerHTML?: string): Element => {
  const el = $owner.createElement(tag)
  if (innerHTML != null) el.innerHTML = innerHTML
  return el
}

describe('defaultOptions — predicate behaviour', () => {
  it('ignore: <script>, <style>, <head>, comment, empty text → true', () => {
    assert.equal(defaultOptions.ignore(make('script')), true)
    assert.equal(defaultOptions.ignore(make('style')), true)
    assert.equal(defaultOptions.ignore(make('head')), true)
    assert.equal(defaultOptions.ignore($owner.createComment('x')), true)
    assert.equal(defaultOptions.ignore($owner.createTextNode('')), true)
  })

  it('ignore: normal element / non-empty text → false', () => {
    assert.equal(defaultOptions.ignore(make('div')), false)
    assert.equal(defaultOptions.ignore(make('p')), false)
    assert.equal(defaultOptions.ignore($owner.createTextNode('hi')), false)
  })

  it('isContextElement: <p>, <article>, <br> → true; <span> → false', () => {
    assert.equal(defaultOptions.isContextElement(make('p')), true)
    assert.equal(defaultOptions.isContextElement(make('article')), true)
    assert.equal(defaultOptions.isContextElement(make('br')), true)
    assert.equal(defaultOptions.isContextElement(make('span')), false)
  })

  it('hasContextElements: <div><p>…</p></div> → true; <span><em>…</em></span> → false', () => {
    assert.equal(defaultOptions.hasContextElements(make('div', '<p>x</p>')), true)
    assert.equal(defaultOptions.hasContextElements(make('span', '<em>x</em>')), false)
  })

  it('isVoidElement: <br>, <img>, <wbr> → true; <div> → false', () => {
    assert.equal(defaultOptions.isVoidElement(make('br')), true)
    assert.equal(defaultOptions.isVoidElement(make('img')), true)
    assert.equal(defaultOptions.isVoidElement(make('wbr')), true)
    assert.equal(defaultOptions.isVoidElement(make('div')), false)
  })
})

describe('contextlessOptions — uniformly false', () => {
  const probes: Node[] = [
    make('p'),
    make('div', '<p>x</p>'),
    make('br'),
    make('script'),
    $owner.createComment('x'),
    $owner.createTextNode(''),
    $owner.createTextNode('hi'),
  ]

  it('every predicate returns false for every probe', () => {
    for (const n of probes) {
      assert.equal(contextlessOptions.ignore(n), false)
      assert.equal(contextlessOptions.isContextElement(n), false)
      assert.equal(contextlessOptions.hasContextElements(n), false)
      assert.equal(contextlessOptions.isVoidElement(n), false)
    }
  })
})

describe('defaultOptions — identity vs. operations called bare', () => {
  // Drift detector: if the JS-shape `defaultOptions` and the PS-internal
  // default options ever fall out of sync, this fixture-based round-trip is
  // what catches it.
  const fixture =
    '<article><h1>Foo bar</h1><p>Hello <b>w</b>orld <i>foo</i> bar.</p>' +
    '<ul><li>foo bar baz</li><li>just foo</li></ul></article>'
  const re = /\bfoo\b/gi

  it('match: bare === with-defaultOptions', () => {
    assert.deepEqual(
      match(re, fixture).map(m => m.captures[0]),
      match(defaultOptions, re, fixture).map(m => m.captures[0]),
    )
  })

  it('replace: bare === with-defaultOptions', () => {
    assert.equal(
      html(replace(re, 'X', fixture)),
      html(replace(defaultOptions, re, 'X', fixture)),
    )
  })

  it('transform: bare === with-defaultOptions', () => {
    const t = (sp: any) => (_m: any) => sp.text.toUpperCase()
    assert.equal(
      html(transform(re, t, fixture)),
      html(transform(defaultOptions, re, t, fixture)),
    )
  })

  it('insert: bare === with-defaultOptions', () => {
    const ins = { start: '[', end: ']' }
    assert.equal(
      html(insert(re, ins, fixture)),
      html(insert(defaultOptions, re, ins, fixture)),
    )
  })

  it('wrap: bare === with-defaultOptions', () => {
    assert.equal(
      html(wrap(re, '<mark />', fixture)),
      html(wrap(defaultOptions, re, '<mark />', fixture)),
    )
  })

  it('textContents: bare === with-defaultOptions', () => {
    assert.deepEqual(
      textContents(fixture),
      textContents(defaultOptions, fixture),
    )
  })
})

describe('defaultOptions — composition pattern', () => {
  // The headline use case: build a stricter `isContextElement` on top of the
  // default. The composition's boundaries must differ observably from the
  // bare default's — otherwise the override isn't doing anything.

  // Custom predicate: "default boundary AND not <p>". Effectively excludes
  // <p> from the context list while keeping every other default boundary.
  const notParagraph: Required<Options>['isContextElement'] = (n) =>
    defaultOptions.isContextElement(n) && (n as Element).tagName !== 'P'

  // Fixture: <p> followed by loose inline text. With <p> as a boundary
  // (default), the trailing " world" sits in its own context, so
  // /hello world/ cannot match across the <p>/text seam. With <p> demoted
  // (composed), the <p>'s text and the trailing text merge into one
  // context — the regex matches.
  const src = '<p>hello</p> world'

  it('bare default: /hello world/ is split across two contexts and does not match', () => {
    assert.equal(match(/hello world/g, src).length, 0)
    assert.deepEqual(textContents(src), ['', 'hello', ' world'])
  })

  it('composed (no <p>): /hello world/ matches because <p> no longer splits the text', () => {
    const matches = match(
      { isContextElement: notParagraph },
      /hello world/g,
      src,
    )
    assert.equal(matches.length, 1, 'the demoted <p> lets the regex span')
    assert.equal(matches[0].captures[0], 'hello world')

    assert.deepEqual(
      textContents({ isContextElement: notParagraph }, src),
      ['hello world'],
      'demoting <p> collapses the partition into one entry',
    )
  })

  it('composed predicate runs cleanly through replace and produces a valid Hype', () => {
    const result = replace(
      { isContextElement: notParagraph },
      /hello world/g,
      'HW',
      src,
    )
    assert.equal(result.tag, 'Hype')
    // The replacement happens because the text now reads as one stretch.
    assert.match(html(result), /HW/)
  })
})

describe('defaultOptions — frozen', () => {
  it('reassigning a predicate throws in strict mode', () => {
    assert.throws(
      () => { (defaultOptions as any).ignore = () => true },
      TypeError,
    )
    assert.throws(
      () => { (contextlessOptions as any).isContextElement = () => true },
      TypeError,
    )
  })

  it('the failed mutation does not change subsequent operation behaviour', () => {
    const before = html(replace(/foo/g, 'X', '<p>foo</p>'))
    try { (defaultOptions as any).ignore = () => true } catch {}
    assert.equal(html(replace(/foo/g, 'X', '<p>foo</p>')), before)
  })
})

// ── Type-level assertions ────────────────────────────────────────────────────
//
// These never run; they exist to make the typechecker enforce the documented
// shape. If `defaultOptions` slips back to plain `Options` (with optional
// keys), the `Required` check below fails to compile, and `pnpm typecheck`
// rejects the change.

type _Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends (<T>() => T extends Y ? 1 : 2)
    ? true
    : false
type _Assert<T extends true> = T

// eslint-disable-next-line @typescript-eslint/no-unused-vars
type _DefaultIsRequired = _Assert<_Equals<typeof defaultOptions, Required<Options>>>
// eslint-disable-next-line @typescript-eslint/no-unused-vars
type _ContextlessIsRequired = _Assert<_Equals<typeof contextlessOptions, Required<Options>>>

// Composition pattern compiles cleanly: the `&&` produces a `boolean` because
// every predicate on `Required<Options>` is guaranteed-defined.
const _composedTypeCheck: Required<Options>['isContextElement'] = (n) =>
  defaultOptions.isContextElement(n) && (n as Element).tagName === 'P'
void _composedTypeCheck

describe('defaultOptions — idempotent merge', () => {
  // Convert-back round-trip: passing the JS-shape defaultOptions back through
  // the operations' option converter must not double-wrap. If it did, the PS
  // side would call the predicates with `node` and get a function back rather
  // than a boolean — the result would diverge from the bare-call output.
  const fixture =
    '<article><h1>foo</h1><p>foo bar <b>foo</b></p><ul><li>foo</li></ul></article>'

  it('replace(defaultOptions, …) === replace(…)', () => {
    assert.equal(
      html(replace(defaultOptions, /foo/g, 'X', fixture)),
      html(replace(/foo/g, 'X', fixture)),
    )
  })

  it('wrap(defaultOptions, …) === wrap(…)', () => {
    assert.equal(
      html(wrap(defaultOptions, /foo/g, '<mark />', fixture)),
      html(wrap(/foo/g, '<mark />', fixture)),
    )
  })

  it('match(defaultOptions, …) yields exactly the same .captures[0]s', () => {
    assert.deepEqual(
      match(defaultOptions, /foo/g, fixture).map(m => m.captures[0]),
      match(/foo/g, fixture).map(m => m.captures[0]),
    )
  })
})

// ── Custom ignore: D branch leak (regression test for 0.2.0-rc.2 fix) ────────
//
// Before the fix, `textContentsByContext`'s D branch (parent has no inner
// context-establishing children) used `Element.textContent` directly, which
// includes text from descendants regardless of `ignore`. Custom predicates
// that match elements NOT already in `contextElements` (e.g. <span class=
// "skip">) would have their text leak into the regex's input string. The
// portion-builder in turn DOES respect `ignore`, so the regex's match
// indices would slide onto the next visible text node — a wrong fire on
// adjacent content.
//
// This test mirrors the original repro: <span class="skip"> wrapping
// "SKIPPED" inside a <p>, custom ignore composed on top of defaultOptions.

describe('custom ignore: D branch leak (regression)', () => {
  const skipClass: Required<Options>['ignore'] = (n) =>
    defaultOptions.ignore(n) ||
    (n.nodeType === 1 && (n as Element).classList?.contains('skip'))

  const src = '<p>before<span class="skip">SKIPPED</span>after</p>'

  it('match: 0 hits for /SKIPPED/', () => {
    const ms = match({ ignore: skipClass }, /SKIPPED/g, src)
    assert.equal(ms.length, 0, 'SKIPPED is inside an ignored subtree')
  })

  it('replace: source unchanged (no spurious fire on adjacent text)', () => {
    assert.equal(
      html(replace({ ignore: skipClass }, /SKIPPED/g, 'X', src)),
      src,
    )
  })

  it('transform: transformer never fires', () => {
    let fired = 0
    transform(
      { ignore: skipClass },
      /SKIPPED/g,
      sp => _m => { fired += 1; return sp.text },
      src,
    )
    assert.equal(fired, 0, 'transformer must not fire on ignored content')
  })

  it('without the custom ignore: SKIPPED is matched (control)', () => {
    // Sanity check — the bug is specifically about CUSTOM ignore. With the
    // bare default (which doesn't recognise .skip), the match should land
    // normally on SKIPPED. This pins the contrast.
    const ms = match(/SKIPPED/g, src)
    assert.equal(ms.length, 1)
    assert.equal(ms[0].captures[0], 'SKIPPED')
  })

  it('matches /beforeafter/ across the bridged gap (positive: bridge is clean)', () => {
    // The other tests confirm "SKIPPED is gone" (negative). This one confirms
    // the joined context string is *exactly* "beforeafter" with no artifact
    // in place of the ignored span — a buggy implementation that leaves a
    // stray separator would still pass the SKIPPED-is-gone tests but fail
    // this one.
    const ms = match({ ignore: skipClass }, /beforeafter/gi, src)
    assert.equal(ms.length, 1, 'the ignored subtree should be invisible to the regex')
    assert.equal(ms[0].captures[0], 'beforeafter')
  })
})
