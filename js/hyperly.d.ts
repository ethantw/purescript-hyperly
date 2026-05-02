import type { Hyperly, Hype, Options, HTMLType } from './fp/hyperly.js'

export type { Hyperly, Hype, Options, HTMLType }

export const hype: (src: Hyperly) => Hype

export const document: (src: Hyperly) => Document
export const element: (src: Hyperly) => Element
export const htmlType: (src: Hyperly) => HTMLType
export const html: (src: Hyperly) => string

export function textContents(src: Hyperly): string[]
export function textContents(options: Options, src: Hyperly): string[]

export const contextlessTextContents: (src: Hyperly) => string[]
