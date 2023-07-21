import { dict, convertOptions, isHyperlySrc } from '../utilities.js'

import * as hyperly from '#output/Data.Hyperly/index.js'

export const hype = src => dict(src).hype(src)()

export const document = src => dict(src).document(src)()
export const element = src => dict(src).element(src)()
export const htmlType = src => dict(src).htmlType(src)()
export const html = src => dict(src).html(src)()

// Overloaded:
//   textContents(src)            — default options, returns string[] directly
//   textContents(options)(src)   — custom options, returns curried (src) => string[]
export const textContents = first =>
  isHyperlySrc(first)
    ? hyperly.textContents(dict(first))(first)()
    : src => dict(src)["textContents'"]()(convertOptions(first))(src)()

export const contextlessTextContents = src =>
  hyperly.contextlessTextContents(dict(src))(src)()
