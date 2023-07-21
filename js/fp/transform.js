import { dict, convertOptions, convertTarget, unwrap } from '../utilities.js'

import * as hyperly from '#output/Data.Hyperly/index.js'

import {
  targetHTML,
} from '#output/Data.Hyperly.Transformer/index.js'

// Overloaded:
//   transform(regex)(transformer)(src)            — default options
//   transform(options)(regex)(transformer)(src)   — custom options
export const transform = first =>
  first instanceof RegExp
    ? transformer => src =>
        unwrap(hyperly.transform(dict(src))(targetHTML)(first)(convertTransformer(transformer))(src)())
    : regex => transformer => src =>
        unwrap(hyperly['transform$p']()(dict(src))(targetHTML)(convertOptions(first))(regex)(convertTransformer(transformer))(src)())

export const transformContextlessly = regex => transformer => src =>
  unwrap(hyperly.transformContextlessly(dict(src))(targetHTML)(regex)(convertTransformer(transformer))(src)())

const convertTransformer = transformer =>
  _dict => sp => m => () => convertTarget(transformer(sp)(m))
