type Wrapper = string | Element

export function wrap(regex: RegExp, wrapper: Wrapper, src: Hyperly): Hype
export function wrap(options: Options, regex: RegExp, wrapper: Wrapper, src: Hyperly): Hype

export function wrapContextlessly(regex: RegExp, wrapper: Wrapper, src: Hyperly): Hype
