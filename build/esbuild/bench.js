import { build } from 'esbuild'
import * as config from './config.js'

try {
  await build(config.forBench)
  console.log('Benchmark pages bundled into src/Demo/public/static.')
} catch (e) {
  console.error(e)
  process.exit(1)
}
