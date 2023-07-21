export { hype, document, element, htmlType, html } from './fp/hyperly.js'
export { contextlessTextContents } from './fp/hyperly.js'

import { textContents as fpTextContents } from './fp/hyperly.js'

// Overloaded:
//   textContents(src)
//   textContents(options, src)
export const textContents = (...args) =>
  args.length === 1
    ? fpTextContents(args[0])
    : fpTextContents(args[0])(args[1])
