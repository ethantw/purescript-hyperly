import {
  defaultOptions as psDefaultOptions,
  contextlessOptions as psContextlessOptions,
} from '#output/Data.Hyperly.Options/index.js'

// PS predicates are curried `Node -> Effect Boolean` (i.e. `n => () => bool`).
// The JS-facing `Options` interface is uncurried `(node: Node) => boolean`.
// `tsShape` wraps each predicate into the uncurried form and freezes the
// record so consumers can compose on top of it without accidentally mutating
// the shared default.
const tsShape = ps => Object.freeze({
  ignore:             n => ps.ignore(n)(),
  isContextElement:   n => ps.isContextElement(n)(),
  hasContextElements: n => ps.hasContextElements(n)(),
  isVoidElement:      n => ps.isVoidElement(n)(),
})

export const defaultOptions = tsShape(psDefaultOptions)
export const contextlessOptions = tsShape(psContextlessOptions)
