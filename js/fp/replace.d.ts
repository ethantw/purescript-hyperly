export function replace(regex: RegExp): (replacement: string) => (src: Hyperly) => Hype
export function replace(options: Options): (regex: RegExp) => (replacement: string) => (src: Hyperly) => Hype

export function replaceContextlessly(regex: RegExp): (replacement: string) => (src: Hyperly) => Hype
