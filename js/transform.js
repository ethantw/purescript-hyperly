import * as fp from './fp/transform.js'

// Overloaded:
//   transform(regex, transformer, src)
//   transform(options, regex, transformer, src)
export const transform = (a, b, c, d) =>
  a instanceof RegExp
    ? fp.transform(a)(b)(c)
    : fp.transform(a)(b)(c)(d)

export const transformContextlessly = (regex, transformer, src) => fp.transformContextlessly(regex)(transformer)(src)
