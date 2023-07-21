declare global {
  export interface Insertion {
    start?: Target
    between?: Target
    end?: Target
    outer?: boolean
  }
}

export function insert(regex: RegExp, insertion: Insertion, src: Hyperly): Hype
export function insert(options: Options, regex: RegExp, insertion: Insertion, src: Hyperly): Hype

export function insertContextlessly(regex: RegExp, insertion: Insertion, src: Hyperly): Hype
