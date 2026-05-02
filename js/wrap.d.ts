import type { Hyperly, Hype, Options } from './fp/hyperly.js'
import type { Wrapper } from './fp/wrap.js'

export type { Wrapper }

export function wrap(regex: RegExp, wrapper: Wrapper, src: Hyperly): Hype
export function wrap(options: Options, regex: RegExp, wrapper: Wrapper, src: Hyperly): Hype

export function wrapContextlessly(regex: RegExp, wrapper: Wrapper, src: Hyperly): Hype
