# Contributing to purescript-hyperly

Thank you for your interest in contributing to purescript-hyperly! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- Node.js 22+
- pnpm 9+
- PureScript 0.15+

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/ethantw/purescript-hyperly.git
   cd purescript-hyperly
   ```
3. Install dependencies:
   ```bash
   pnpm install
   ```
4. Compile PureScript and build the library:
   ```bash
   pnpm compile     # PureScript → output/
   pnpm build       # produces lib/hyperly.{js,min.js}
   ```
5. Run tests:
   ```bash
   pnpm test
   ```

> **A note on naming:** the `build/` directory contains the bundling tool
> configuration (rollup for the library, esbuild for the demo). The
> `pnpm build` script produces the npm-publishable library. Don't confuse
> the two — the directory holds *how to build*, the script *runs the build*.

## Scripts

| Command | Purpose |
|---|---|
| `pnpm compile` | Compile PureScript sources via Spago (output/) |
| `pnpm build` | Bundle the library for npm publishing (lib/) — uses rollup |
| `pnpm build:demo` | Bundle the demo as static assets (src/Demo/public/static/) — uses esbuild |
| `pnpm start` | Run the dev server for the demo (esbuild serve mode) |
| `pnpm typecheck` | Type-check `.d.ts` declarations against test usage (no emit) |
| `pnpm test:purs` | Run PureScript tests |
| `pnpm test:js` | Type-check + run TypeScript tests against the JS API |
| `pnpm test` | Run both PS and JS test suites |
| `pnpm all` | `compile` + `build` + `build:demo` |

## Development Workflow

### Making Changes

1. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-fix-name
   ```

2. Make your changes following the coding standards below

3. Test your changes:
   ```bash
   pnpm test
   ```

4. Commit your changes with a descriptive message:
   ```bash
   git commit -m "feat: add new feature for X"
   # or
   git commit -m "fix: resolve issue with Y"
   ```

5. Push your branch and create a pull request

### Coding Standards

- Follow PureScript style guidelines
- Use meaningful variable and function names
- Add type annotations where helpful
- Include JSDoc comments for complex functions
- Ensure all tests pass
- Add tests for new functionality

### Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `style:` for formatting changes
- `refactor:` for code refactoring
- `test:` for adding or updating tests
- `chore:` for maintenance tasks

## Design decisions you should know about

Several things in this codebase were chosen deliberately, often after measurement or back-and-forth discussion. Before proposing a change that touches any of these, please read this section — and if you still think it should change, open an issue first to discuss.

> **Note:** the same content is mirrored in machine-readable form at [`.claude/skills/hyperly-design-invariants/SKILL.md`](.claude/skills/hyperly-design-invariants/SKILL.md) so AI agents working on the repo pick it up automatically.

### Naming

| Decision | Why |
|---|---|
| `Match.captures` | Aligns with .NET / Rust / Python regex naming where `captures[0]` is the full match |
| JS uses overloading `match(regex, src)` ↔ `match(options, regex, src)`; **no** `*Custom` suffix | Matches lodash/Express/jQuery JS idiom; dispatched by `instanceof RegExp` |
| PS uses Haskell-style prime `match'` for the option-taking variant | Standard PS/Haskell convention |
| `*Contextlessly` is a separate function in both, never folded into the overload | It's a different default-mode, not a configuration of the same operation |
| Instance variables stay camelCase even when accessing constructor properties (`window.Element`, not `Win.Element`) | PascalCase signals "constructor/type" — an instance is a value |

### Error handling: PS returns `Either`, JS throws

This is deliberate **boundary translation**, not a stylistic choice. PS's pure `Either String Hype` is converted to JS `throw` at `js/utilities.js:unwrap`. Don't try to unify these:

- Exposing `Either` to JS users would be alien to JS idiom.
- Converting PS to throw would lose the explicit error tracking and pure-FP guarantees that PS users expect.

`match` and `textContents` don't return `Either` because they cannot fail.

### `textContents` returns leading `""` placeholders

`<div><p>A</p></div>` produces `["", "", "A"]`. The empty strings are *intentional* — they preserve the ability for callers to operate on (or detect) empty container slots. Removing them would silently lose information.

If your use case wants only non-empty entries, filter at the call site:
```purescript
tcs <- textContents src <#> Array.filter (_ /= "")
```
```js
const tcs = textContents(src).filter(Boolean)
```

This was discussed and intentionally kept.

### Performance characteristics — measured, not guessed

- **`Array` over `Set`** for `contextElements`/`elementsToBeIgnored`/`voidElements`. Under 100 elements, Array wins or ties via cache locality. These are HTML5 spec lists that won't grow.
- **`innerHTML + regex` over `querySelector`** in `Options.purs:hasContextElementsDefault` on the server side — happy-dom's `querySelector` is several times slower. This was tried 3 years ago.
- **`STArray` in `Transformer.purs:transformMatches`** — accumulating via `acc <> src'tgts` was O(N²); the current `STArray.push` is O(1) amortized.
- **Comment-stripping in unminified rollup output** — `purs-backend-es` carries hundreds of lines of PS docstrings into JS, bloating the unminified bundle by ~3 KB. Source maps already point back to source for debugging.

### Build pipeline

- `compile → purs-backend-es → bundler` is mandatory. Every `pnpm build*` script starts with `pnpm compile &&` because skipping it lets stale `output/` produce stale bundles silently.
- **rollup** for the npm library (`pnpm build` → `lib/`); **esbuild** for the demo (`pnpm build:demo`, `pnpm start` → `src/Demo/public/static/`). Each tool was chosen for its strength: terser produces ~6–8% smaller minified output for the lib, esbuild's native CSS loader keeps the demo simple.

### File structure

- `src/` holds PS sources plus PS-required foreign JS (the PS compiler enforces co-location).
- `js/` at the project root holds the JS wrapper layer (uncurried + curried + `.d.ts`).
- Demo HTML is at `src/Demo/public/`, not at a top-level `demo/`.
- Build tooling configs are at `build/{rollup,esbuild}/`, not the project root.

### Public API surface

The `exports` field in `package.json` deliberately encapsulates the package — only `'hyperly'` and `'hyperly/fp'` are reachable externally. Internal files under `js/` are not exposed. This lets us refactor `js/` internals without breaking users.

### Things that look weird but are correct

- `Hype` retains references to detached old DOM nodes. This is *required* for `revert`/`revertAll` to work. The `commit`/`discardHistory` API to release them is on the backlog.
- `js/wrap.js` exists as a first-class wrapper — earlier in the codebase users had to use `transform` for wrapping. The dedicated function is a real ergonomic win and matches PS's `wrap`.
- `isHype = h => h?.tag === 'Hype'` — the `?.` is intentional null-guard.

## Testing

### Running Tests

```bash
# Run all tests
pnpm test

# Run tests in watch mode
spago test --watch

# Run specific test module
spago test --main Test.Specific.Module
```

### Writing Tests

- Tests should be in the `test/` directory
- Use descriptive test names
- Test both success and failure cases
- Test edge cases and boundary conditions

## Pull Request Process

1. Ensure your code follows the project's style guidelines
2. Update documentation if necessary
3. Add or update tests for new functionality
4. Ensure all tests pass
5. Update the CHANGELOG.md if applicable
6. Provide a clear description of your changes

## Code Review

All contributions require review before merging. Reviewers will check:

- Code quality and style
- Test coverage
- Documentation updates
- Performance implications
- Security considerations

## Getting Help

If you need help or have questions:

- Open an issue for bugs or feature requests
- Join our discussions in GitHub Discussions
- Check existing issues and pull requests

## License

By contributing to purescript-hyperly, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing! 🎉
