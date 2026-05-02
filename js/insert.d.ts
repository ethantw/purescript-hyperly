import type { Hyperly, Hype, Options } from './fp/hyperly.js'
import type { Insertion } from './fp/insert.js'

export type { Insertion }

export function insert(regex: RegExp, insertion: Insertion, src: Hyperly): Hype
export function insert(options: Options, regex: RegExp, insertion: Insertion, src: Hyperly): Hype

export function insertContextlessly(regex: RegExp, insertion: Insertion, src: Hyperly): Hype
