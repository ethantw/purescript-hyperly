declare global {
  export interface SourcePortion {
    /** The text node this portion lives in. */
    node: Node

    /** The text covered by this portion (a slice of `node.textContent`). */
    text: string

    /** Absolute offset of this portion's start within the surrounding context string. */
    atIndex: number

    /** 0-based index of this portion within the parent match. */
    index: number

    /** Char offset from the start of the full match where this portion begins. */
    indexInMatch: number

    /** Char offset within `node.textContent` where this portion begins. */
    indexInNode: number

    /** Char offset within `node.textContent` where this portion ends. */
    endIndexInNode: number

    /** True if this is the first portion of the match. */
    start: boolean

    /** True for middle portions of a multi-node match (neither first nor last). */
    inner: boolean

    /** True if this is the last portion of the match. */
    end: boolean
  }

  export type Target =
    Node | Element | string
    | Node[] | Element[] | string[]
}

type Transformer = (sourcePortion: SourcePortion) => (match: Match) => Target

export function transform(regex: RegExp, transformer: Transformer, src: Hyperly): Hype
export function transform(options: Options, regex: RegExp, transformer: Transformer, src: Hyperly): Hype

export function transformContextlessly(regex: RegExp, transformer: Transformer, src: Hyperly): Hype
