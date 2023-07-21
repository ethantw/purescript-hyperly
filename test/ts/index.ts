import 'iterator-helpers-polyfill'
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'

// ── Uncurried (src/js/) ──────────────────────────────────────────────────────

import {
  html,
  textContents, contextlessTextContents,
} from '#hyperly/hyperly.js'
import { match, matchContextlessly } from '#hyperly/match.js'
import { replace, replaceContextlessly } from '#hyperly/replace.js'
import { transform, transformContextlessly } from '#hyperly/transform.js'
import { insert, insertContextlessly } from '#hyperly/insert.js'
import { wrap, wrapContextlessly } from '#hyperly/wrap.js'
import { revert, revertAll } from '#hyperly/revert.js'

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

  it('matchContextlessly matches across elements', () => {
    const matches = matchContextlessly(/\b([a-z])([a-z])([a-z])\b/gi, '<b>ab</b>c')
    assert.equal(matches.length, 1)
    assert.equal(matches[0].captures[0], 'abc')
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

  it('replaceContextlessly across element boundaries', () => {
    assert.equal(
      html(replaceContextlessly(/\b([a-z])([a-z])([a-z])\b/gi, '___', '<b>ab</b>c')),
      '<b>__</b>_',
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

  it('transformContextlessly across element boundaries', () => {
    assert.equal(
      html(transformContextlessly(/\b([a-z])([a-z])([a-z])\b/gi, sp => _m => sp.text.toUpperCase(), '<b>ab</b>c')),
      '<b>AB</b>C',
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

  it('wrap with cross-element match wraps each portion', () => {
    assert.equal(
      html(wrapContextlessly(/\b([a-z])([a-z])([a-z])\b/gi, '<mark />', '<b>ab</b>c')),
      '<b><mark>ab</mark></b><mark>c</mark>',
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
