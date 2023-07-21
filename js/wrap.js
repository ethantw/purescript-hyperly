import * as fp from './fp/wrap.js'

// Overloaded:
//   wrap(regex, wrapper, src)
//   wrap(options, regex, wrapper, src)
export const wrap = (a, b, c, d) =>
  a instanceof RegExp
    ? fp.wrap(a)(b)(c)
    : fp.wrap(a)(b)(c)(d)

export const wrapContextlessly = (regex, wrapper, src) => fp.wrapContextlessly(regex)(wrapper)(src)
