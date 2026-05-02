import type { Hyperly, Options } from './hyperly.js'
import type { SourcePortion } from './transform.js'

export interface Match {
  /**
   * `[fullMatch, ...captureGroups]`. Index 0 is always the whole matched
   * substring; subsequent indices are positional capture groups, which may
   * be `undefined` if the corresponding group did not participate in the
   * match.
   */
  captures: [string, ...(string | undefined)[]]

  /** Named capture groups; values are `undefined` for groups that did not match. */
  groups: Record<string, string | undefined>

  /** The full context string against which the regex was run. */
  input: string

  /** Start index of the match within `input`. */
  startIndex: number

  /** End index of the match within `input` (exclusive). */
  endIndex: number

  /** Per-text-node slices of the match across the DOM. */
  portions: SourcePortion[]

  /** The context node within which this match was found. */
  context: Node
}

export function match(regex: RegExp): (src: Hyperly) => Match[]
export function match(options: Options): (regex: RegExp) => (src: Hyperly) => Match[]

export function matchContextlessly(regex: RegExp): (src: Hyperly) => Match[]
