import { dict, isElement, convertOptions, unwrap } from '../utilities.js'

import * as hyperly from '#output/Data.Hyperly/index.js'

import {
  wrapperElement, wrapperString,
} from '#output/Data.Hyperly.Wrap/index.js'

const wrapperDict = w => isElement(w) ? wrapperElement : wrapperString

// Overloaded:
//   wrap(regex)(wrapper)(src)            — default options
//   wrap(options)(regex)(wrapper)(src)   — custom options
export const wrap = first =>
  first instanceof RegExp
    ? wrapper => src =>
        unwrap(hyperly.wrap(dict(src))(wrapperDict(wrapper))(first)(wrapper)(src)())
    : regex => wrapper => src =>
        unwrap(hyperly['wrap$p']()(dict(src))(wrapperDict(wrapper))(convertOptions(first))(regex)(wrapper)(src)())

export const wrapContextlessly = regex => wrapper => src =>
  unwrap(hyperly.wrapContextlessly(dict(src))(wrapperDict(wrapper))(regex)(wrapper)(src)())
