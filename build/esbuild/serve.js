import { context } from 'esbuild'

import { join as joinPath } from 'path'

import * as config from './config.js'

try {
  const ctx = await context(config.forDemo)

  const { host = 'localhost', port } = await ctx.serve(
    {
      servedir: joinPath(process.env.PWD, `src/Demo/public`),
      port: 7700,
    },
  )

  console.log(`Demo started locally on http://${host}:${port}.`)
} catch (e) {
  console.error(e)
}
