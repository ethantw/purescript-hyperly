// esbuild handles the demo and benchmark bundles (dev server, demo bundling,
// benchmark page bundling). Library bundling moved to rollup — see
// ../rollup/config.js.
//
// `forDemo` and `forBench` share the same `outdir` (src/Demo/public/static)
// so the demo dev server can serve both demo HTML at `/index.html` and
// benchmark HTML at `/benchmark/*.html`. Benchmarks import the rolled lib
// bundle (`lib/hyperly.fp.js`) so `pnpm build` must run first; that's why
// `forBench` is a separate config — keeping it out of the demo entry points
// means `pnpm start` still works without a fresh `lib/`.

const common = {
  charset: 'utf8',

  bundle: true,
  format: 'esm',

  treeShaking: true,
  external: [
    'happy-dom',
    'iterator-helpers-polyfill',
  ],

  sourcemap: 'external',
  define: {
    'process.env.NODE_ENV': `"${process.env.NODE_ENV}"`,
    'Number.POSITIVE_INFINITY': 'false',
    'Number.NEGATIVE_INFINITY': 'false',
  },

  mainFields: ['main', 'module', 'browser'],
}

export const forDemo = {
  ...common,

  entryPoints: ['src/Demo/demo.js'],
  outdir: 'src/Demo/public/static',

  loader: { '.css': 'css' },
}

export const forBench = {
  ...common,

  entryPoints: [
    'src/Demo/benchmark/findAndReplaceDOMText.js',
    'src/Demo/benchmark/dom.js',
  ],
  outdir: 'src/Demo/public/static',
}
