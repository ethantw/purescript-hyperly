export type HTMLType = 'Outer' | 'Inner' | 'BodyOuter' | 'BodyInner'

export interface Hype {
  tag: 'Hype'
  _1: Element
  _2: HTMLType
  _3: Node[][]
}

export type Hyperly = string | Element | Hype

export interface Options {
  ignore?: (node: Node) => boolean
  isContextElement?: (node: Node) => boolean
  hasContextElements?: (node: Node) => boolean
  /** Used by `wrap` to refuse wrapping void elements like `<br>` / `<img>`. */
  isVoidElement?: (node: Node) => boolean
}

export const hype: (src: Hyperly) => Hype

export const document: (src: Hyperly) => Document
export const element: (src: Hyperly) => Element
export const htmlType: (src: Hyperly) => HTMLType
export const html: (src: Hyperly) => string

export function textContents(src: Hyperly): string[]
export function textContents(options: Options): (src: Hyperly) => string[]

export const contextlessTextContents: (src: Hyperly) => string[]
