import nodeResolve from '@rollup/plugin-node-resolve'
import replace from '@rollup/plugin-replace'
import terser from '@rollup/plugin-terser'

const common = {
  external: [
    'happy-dom',
    'iterator-helpers-polyfill',
  ],

  plugins: [
    nodeResolve({
      mainFields: ['browser', 'module', 'main'],
      exportConditions: ['default', 'module', 'browser'],
    }),

    replace({
      preventAssignment: true,
      values: {
        'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'production'),
        'Number.POSITIVE_INFINITY': 'false',
        'Number.NEGATIVE_INFINITY': 'false',
      },
    }),
  ],

  // Don't warn about circular deps (PS output has many).
  onwarn(warning, warn) {
    if (warning.code === 'CIRCULAR_DEPENDENCY') return
    warn(warning)
  },
}

// Strip comments without minifying — purs-backend-es output carries the
// original PS docstrings, which inflate the unminified bundle by ~3 KB
// for no debugging benefit (sourcemaps point back to source anyway).
const beautifyTerser = terser({
  compress: false,
  mangle: false,
  format: {
    comments: false,
    beautify: true,
  },
})

const minifyTerser = terser({
  compress: {
    // Match esbuild's pure-call annotations so terser can drop unused calls.
    pure_funcs: [
      'String.fromCharCode',
      'String.prototype.fromCodePoint',
      'getEffProp',
      'getEffProp2',
    ],
    passes: 2,
  },
  mangle: true,
})

const bundle = (input, file, minPlugin) => ({
  ...common,
  input,
  output: {
    file,
    format: 'esm',
    sourcemap: true,
  },
  plugins: [...common.plugins, minPlugin],
})

// ============
// MAIN ENTRY (uncurried):
// ============
export const forLib       = bundle('hyperly.js', 'lib/hyperly.js',     beautifyTerser)
export const forLibMinify = bundle('hyperly.js', 'lib/hyperly.min.js', minifyTerser)

// ===============
// FP ENTRY (curried, exposed as 'hyperly/fp'):
// ===============
export const forLibFp       = bundle('js/fp/index.js', 'lib/hyperly.fp.js',     beautifyTerser)
export const forLibFpMinify = bundle('js/fp/index.js', 'lib/hyperly.fp.min.js', minifyTerser)
