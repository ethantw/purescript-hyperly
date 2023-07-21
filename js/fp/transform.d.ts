type Transformer = (sourcePortion: SourcePortion) => (match: Match) => Target

export function transform(regex: RegExp): (transformer: Transformer) => (src: Hyperly) => Hype
export function transform(options: Options): (regex: RegExp) => (transformer: Transformer) => (src: Hyperly) => Hype

export function transformContextlessly(regex: RegExp): (transformer: Transformer) => (src: Hyperly) => Hype
