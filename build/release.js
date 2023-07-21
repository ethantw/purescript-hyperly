// Pre-publish helper for hyperly.
//
// Usage:
//   node build/release.js next                # publish to @next dist-tag
//   node build/release.js promote <version>   # promote @next → @latest
//
// The `next` flow:
//   1. Verifies the git working tree is clean.
//   2. Runs `npm pack` to build the exact tarball that would be uploaded,
//      so its contents can be reviewed before anything goes to the registry.
//   3. Pauses for confirmation — type `publish` to proceed, anything else
//      aborts and keeps the tarball locally for further inspection.
//   4. Runs `npm publish --tag next` so the version does NOT become @latest;
//      `npm install hyperly` users are unaffected until you `promote`.
//
// Why the @next dance? npm only allows unpublishing within 72 hours, and
// even then it can break downstream lockfiles. Publishing to @next first
// gives you a real-world install path (`npm install hyperly@next`) without
// risk to anyone running plain `npm install hyperly`.

import { execSync } from 'node:child_process'
import { createInterface } from 'node:readline/promises'
import { existsSync, readFileSync, statSync, unlinkSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { stdin as input, stdout as output } from 'node:process'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
process.chdir(root)

const sh = (cmd) =>
  execSync(cmd, { stdio: 'inherit', encoding: 'utf-8' })

const shOut = (cmd) =>
  execSync(cmd, { encoding: 'utf-8' }).trim()

const ask = async (question) => {
  const rl = createInterface({ input, output })
  const answer = await rl.question(question)
  rl.close()
  return answer.trim()
}

const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf-8'))
const subcommand = process.argv[2]

if (subcommand === 'next') {
  // ── 1. Working tree clean? ──────────────────────────────────
  const dirty = shOut('git status --porcelain')
  if (dirty) {
    console.error('✗ Working tree not clean. Commit or stash first:\n')
    console.error(dirty)
    process.exit(1)
  }

  const branch = shOut('git rev-parse --abbrev-ref HEAD')
  if (branch !== 'main') {
    console.warn(`⚠  On branch '${branch}', not 'main'.\n`)
  }

  // ── 2. Build & inspect the tarball ──────────────────────────
  const tarball = `${pkg.name}-${pkg.version}.tgz`
  if (existsSync(tarball)) unlinkSync(tarball)

  console.log(`📦 Packing ${pkg.name}@${pkg.version}\n`)
  sh('npm pack')

  const kb = (statSync(tarball).size / 1024).toFixed(1)
  console.log(`\n✓ Built ${tarball} (${kb} KB)\n`)
  console.log('Review the file list above.')
  console.log('Optional install-test in another terminal:')
  console.log(`  cd $(mktemp -d) && npm init -y && npm install ${root}/${tarball}\n`)

  // ── 3. Confirm ──────────────────────────────────────────────
  const answer = await ask(
    `Publish ${pkg.name}@${pkg.version} to @next? Type 'publish' to confirm: `,
  )
  if (answer !== 'publish') {
    console.log(`\nAborted. Tarball kept at ./${tarball} for inspection.`)
    process.exit(0)
  }

  // ── 4. Publish ──────────────────────────────────────────────
  // Delete the inspection tarball; let `npm publish` re-run the lifecycle
  // hooks (prepack/postpack/prepublishOnly) to ensure consistency.
  unlinkSync(tarball)
  sh('npm publish --tag next')

  console.log(`\n✓ Published ${pkg.name}@${pkg.version} to @next.`)
  console.log('\nNext steps:')
  console.log(`  • Verify install:  npm install ${pkg.name}@next`)
  console.log(`  • Promote when ready:`)
  console.log(`      pnpm release:promote ${pkg.version}`)
  console.log(`  • If broken (within 72h):`)
  console.log(`      npm unpublish ${pkg.name}@${pkg.version}`)
  console.log(`  • If broken (after 72h, or already promoted):`)
  console.log(`      npm deprecate ${pkg.name}@${pkg.version} "<reason>"`)

} else if (subcommand === 'promote') {
  const version = process.argv[3]
  if (!version) {
    console.error('Usage: node build/release.js promote <version>')
    console.error(`  e.g.  node build/release.js promote ${pkg.version}`)
    process.exit(1)
  }

  const answer = (await ask(
    `Promote ${pkg.name}@${version} to @latest? [y/N] `,
  )).toLowerCase()

  if (answer !== 'y' && answer !== 'yes') {
    console.log('Aborted.')
    process.exit(0)
  }

  sh(`npm dist-tag add ${pkg.name}@${version} latest`)
  console.log(`\n✓ ${pkg.name}@${version} is now @latest.`)
  console.log(`\nDon't forget to tag the release in git:`)
  console.log(`  git tag v${version} && git push origin v${version}`)

} else {
  console.error('Usage:')
  console.error('  node build/release.js next                # publish to @next dist-tag')
  console.error('  node build/release.js promote <version>   # promote @next → @latest')
  process.exit(1)
}
