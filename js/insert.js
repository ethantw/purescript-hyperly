import * as fp from './fp/insert.js'

// Overloaded:
//   insert(regex, insertion, src)
//   insert(options, regex, insertion, src)
export const insert = (a, b, c, d) =>
  a instanceof RegExp
    ? fp.insert(a)(b)(c)
    : fp.insert(a)(b)(c)(d)

export const insertContextlessly = (regex, ins, src) => fp.insertContextlessly(regex)(ins)(src)
