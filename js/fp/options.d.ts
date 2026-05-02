import type { Options } from './hyperly.js'

/**
 * Default `Options` predicates in JS-facing uncurried form. The same lists
 * the un-`'`-suffixed operations apply when no `options` argument is passed,
 * exposed as a frozen record so callers can compose on top:
 *
 * ```ts
 * const onlyParagraphs: Options['isContextElement'] = (n) =>
 *   defaultOptions.isContextElement(n) && (n as Element).tagName === 'P'
 * ```
 *
 * The record is `Object.freeze`d; reassigning a predicate (e.g.
 * `defaultOptions.ignore = …`) throws in strict mode.
 */
export const defaultOptions: Required<Options>

/**
 * Predicates used by the `*Contextlessly` family — every predicate returns
 * `false`, collapsing the tree into one flat string. Frozen, like
 * `defaultOptions`.
 */
export const contextlessOptions: Required<Options>
