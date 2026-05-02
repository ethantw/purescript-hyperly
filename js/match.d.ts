import type { Hyperly, Options } from './fp/hyperly.js'
import type { Match } from './fp/match.js'

export type { Match }

export function match(regex: RegExp, src: Hyperly): Match[]
export function match(options: Options, regex: RegExp, src: Hyperly): Match[]

export function matchContextlessly(regex: RegExp, src: Hyperly): Match[]
