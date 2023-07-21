import * as fp from './fp/replace.js'

// Overloaded:
//   replace(regex, replacement, src)
//   replace(options, regex, replacement, src)
export const replace = (a, b, c, d) =>
  a instanceof RegExp
    ? fp.replace(a)(b)(c)
    : fp.replace(a)(b)(c)(d)

export const replaceContextlessly = (regex, replacement, src) => fp.replaceContextlessly(regex)(replacement)(src)
