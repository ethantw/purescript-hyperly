import { dict, convertOptions } from '../utilities.js'

import * as hyperly from '#output/Data.Hyperly/index.js'

// Overloaded:
//   match(regex)(src)            — default options
//   match(options)(regex)(src)   — custom options
export const match = first =>
  first instanceof RegExp
    ? src => hyperly.match(dict(src))(first)(src)()
    : regex => src =>
        hyperly['match$p']()(dict(src))(convertOptions(first))(regex)(src)()

export const matchContextlessly = regex => src =>
  hyperly.matchContextlessly(dict(src))(regex)(src)()
