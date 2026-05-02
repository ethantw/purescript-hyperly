import type { Hyperly, Hype, Options } from './fp/hyperly.js'
import type { SourcePortion, Target, Transformer } from './fp/transform.js'

export type { SourcePortion, Target, Transformer }

export function transform(regex: RegExp, transformer: Transformer, src: Hyperly): Hype
export function transform(options: Options, regex: RegExp, transformer: Transformer, src: Hyperly): Hype

export function transformContextlessly(regex: RegExp, transformer: Transformer, src: Hyperly): Hype
