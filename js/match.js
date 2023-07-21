import * as fp from './fp/match.js'

// Overloaded:
//   match(regex, src)
//   match(options, regex, src)
export const match = (a, b, c) =>
  a instanceof RegExp
    ? fp.match(a)(b)
    : fp.match(a)(b)(c)

export const matchContextlessly = (regex, src) => fp.matchContextlessly(regex)(src)
