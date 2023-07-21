import {
  hyperlyHTML, hyperlyElement, hyperlyHype,
} from '#output/Data.Hyperly/index.js'

import {
  windowEffect,
} from '#output/Data.Hyperly.DOM/index.js'

// Cache the window once at module load (DOM.js's top-level await ensures
// happy-dom is fully initialized by the time this module runs). Avoids paying
// for a function call + property access on every type check.
const window = windowEffect()

export const isString = src => typeof src === 'string'
export const isElement = src => src instanceof window.Element
export const isNode = src => src instanceof window.Node
export const isHype = h => h?.tag === 'Hype'

// True when `first` is a Hyperly source value (string | Element | Hype),
// false when it is anything else — used by overloaded entry points to
// distinguish a default-mode call from a custom-options call.
export const isHyperlySrc = first =>
  isString(first) || isElement(first) || isHype(first)

export const dict = src =>
  isString(src) ? hyperlyHTML
  : isElement(src) ? hyperlyElement
  : isHype(src) ? hyperlyHype
  : throwError(`Hyperly only accepts an element or an HTML string as source.`)

export const throwError = e => { throw new Error(e) }

export const unwrap = result => {
  if (result.tag === 'Left') throw new Error(result._1)
  return result._1
}

const convertOptionFn = name => fn =>
  typeof fn === 'function'
  ? { [name]: node => () => fn(node) }
  : undefined

export const convertOptions = (options = {}) =>
  ['ignore', 'isContextElement', 'hasContextElements', 'isVoidElement']
  .reduce(
    (acc, name) => ({
      ...acc,
      ...convertOptionFn(name)(options[name]),
    }),
    {},
  )

export const convertTarget = target =>
  isString(target) ? target
  : isElement(target) ? (target.outerHTML ?? '')
  : Array.isArray(target)
    ? target.map(t => isString(t) ? t : isElement(t) ? (t.outerHTML ?? '') : '').join('')
  : ''
