import { rollup } from 'rollup'
import * as config from './config.js'

async function build(cfg) {
  const bundle = await rollup(cfg)
  await bundle.write(cfg.output)
  await bundle.close()
}

try {
  await Promise.all([
    build(config.forLib),
    build(config.forLibMinify),
    build(config.forLibFp),
    build(config.forLibFpMinify),
  ])
  console.log('Bundled with rollup.')
} catch (e) {
  console.error(e)
  process.exit(1)
}
