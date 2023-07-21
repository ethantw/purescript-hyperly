import { dict, convertOptions, unwrap } from '../utilities.js'

import * as hyperly from '#output/Data.Hyperly/index.js'

// Overloaded:
//   replace(regex)(replacement)(src)            — default options
//   replace(options)(regex)(replacement)(src)   — custom options
export const replace = first =>
  first instanceof RegExp
    ? replacement => src =>
        unwrap(hyperly.replace(dict(src))(first)(replacement)(src)())
    : regex => replacement => src =>
        unwrap(hyperly['replace$p']()(dict(src))(convertOptions(first))(regex)(replacement)(src)())

export const replaceContextlessly = regex => replacement => src =>
  unwrap(hyperly.replaceContextlessly(dict(src))(regex)(replacement)(src)())
