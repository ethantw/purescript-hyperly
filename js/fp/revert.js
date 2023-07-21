import * as hyperly from '#output/Data.Hyperly/index.js'
import { unwrap } from '../utilities.js'

export const revert = hype => unwrap(hyperly.revert(hype)())
export const revertAll = hype => unwrap(hyperly.revertAll(hype)())
