import { dict, convertOptions, convertTarget, throwError, unwrap } from '../utilities.js'

import * as hyperly from '#output/Data.Hyperly/index.js'

import {
  targetHTML,
} from '#output/Data.Hyperly.Transformer/index.js'

import {
  Around, Start, End, Both, Between,
  Inner, Outer,
} from '#output/Data.Hyperly.Insert/index.js'

// Overloaded:
//   insert(regex)(insertion)(src)            — default options
//   insert(options)(regex)(insertion)(src)   — custom options
export const insert = first =>
  first instanceof RegExp
    ? ins => src =>
        unwrap(hyperly.insert(dict(src))(targetHTML)(first)(convertInsertion(ins))(src)())
    : regex => ins => src =>
        unwrap(hyperly['insert$p']()(dict(src))(targetHTML)(convertOptions(first))(regex)(convertInsertion(ins))(src)())

export const insertContextlessly = regex => ins => src =>
  unwrap(hyperly.insertContextlessly(dict(src))(targetHTML)(regex)(convertInsertion(ins))(src)())

const convertInsertion = ({ start, between, end, outer } = {}) => {
  if (!start && !between && !end) {
    throwError('Insertion must specify at least one of `start`, `between`, or `end`.')
  }

  const b = outer ? Outer : Inner

  return start && between && end
    ? Around(b)(convertTarget(start))(convertTarget(between))(convertTarget(end))

    : start && end
    ? Both(b)(convertTarget(start))(convertTarget(end))

    : start
    ? Start(b)(convertTarget(start))

    : end
    ? End(b)(convertTarget(end))

    : Between(b)(convertTarget(between))
}
