import { build } from 'esbuild'
import * as config from './config.js'

try {
  await build(config.forDemo)
  console.log('Demo bundled with esbuild.')
} catch (e) {
  console.error(e)
  process.exit(1)
}
