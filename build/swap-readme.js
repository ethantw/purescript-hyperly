// During `npm pack` / `npm publish`, swap README.js.md into README.md so the
// package page on npm shows JS docs to JS consumers. `postpack` restores both.
//
// We rename (not copy) README.js.md → README.md and stash the PS original
// under build/. This way npm — which always auto-includes top-level README*
// files regardless of `files` — packs only the JS-flavoured README, with no
// duplicates and no stray backup file in the tarball.
//
// Usage:
//   node build/swap-readme.js apply     # before packing
//   node build/swap-readme.js restore   # after packing

import { existsSync, renameSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

const README     = resolve(root, 'README.md')
const README_JS  = resolve(root, 'README.js.md')
// Stash the original under build/ so it cannot land in the tarball — npm
// auto-includes any top-level file matching README*, regardless of `files`.
const README_BAK = resolve(root, 'build', '.README.original.md')

const cmd = process.argv[2]

if (cmd === 'apply') {
  if (!existsSync(README_JS)) {
    console.error('swap-readme: README.js.md not found; nothing to swap.')
    process.exit(1)
  }
  if (existsSync(README_BAK)) {
    console.error('swap-readme: build/.README.original.md already exists; run `restore` first.')
    process.exit(1)
  }
  renameSync(README, README_BAK)
  renameSync(README_JS, README)
  console.log('swap-readme: README.md ⇐ README.js.md (PS original stashed at build/.README.original.md)')

} else if (cmd === 'restore') {
  // Idempotent — safe to run even if `apply` failed midway or wasn't run.
  if (!existsSync(README_BAK)) {
    process.exit(0)
  }
  // Move the JS README back to README.js.md, then restore the PS original.
  if (existsSync(README)) {
    renameSync(README, README_JS)
  }
  renameSync(README_BAK, README)
  console.log('swap-readme: restored README.md (PS) and README.js.md (JS)')

} else {
  console.error('Usage: node build/swap-readme.js [apply|restore]')
  process.exit(1)
}
