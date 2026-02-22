# CoreEditor — Agent Guide

This directory contains the TypeScript/JavaScript editor built on CodeMirror 6.

## Build & Run

```bash
yarn install        # Install dependencies
yarn dev            # Vite dev server
yarn lint           # ESLint
yarn codegen        # Regenerate Swift bridge code via ts-gyb
yarn test           # Jest tests (jsdom)
yarn build          # Full pipeline: lint -> codegen -> vite build (2 variants)
```

Package manager is **Yarn 4.9.2** (via corepack). Do not use npm.

## Directory Structure

```
src/
  @codegen/        Code generation templates (ts-gyb config + mustache templates)
  @light/          Light/minimal build variant config
  @res/            Static resources
  @vendor/         Vendored libraries
  api/             Public API layer (exposed to extensions)
  bridge/
    native/        TypeScript interfaces for Web -> Native calls
    web/           TypeScript implementations for Native -> Web calls
  common/          Shared utilities and store
  modules/         Feature modules (commands, completion, search, selection, etc.)
  styling/         Theme system and CSS configuration
test/              Jest test files
```

## Key Conventions

- **No `any`** — use proper types or generics.
- **No non-null assertions** (`!`) — use proper null checks or optional chaining.
- **No arrow functions as class properties** — define methods instead.
- **Single quotes**, **semicolons required**, **2-space indent**.
- **Trailing commas** in multiline arrays/objects.
- **`no-public` accessibility** — omit `public` keyword, explicitly mark `private`/`protected`.
- **`await` over `.then()`** — enforced by `promise/prefer-await-to-then`.
- **Strict boolean expressions** — no truthy/falsy implicit coercion.

## Bridge Code Generation

The `@codegen/` folder drives ts-gyb. When you modify interfaces in `bridge/native/` or `bridge/web/`, run `yarn codegen` to regenerate the corresponding Swift files. The generated output lands in:

- `MarkEditKit/Sources/Bridge/Native/Generated/`
- `MarkEditKit/Sources/Bridge/Web/Generated/`
- `MarkEditCore/Sources/EditorSharedTypes.swift`

**Never edit the generated Swift files directly.**

## Adding a New Module

1. Create a directory under `src/modules/<name>/`.
2. Export its public API from an `index.ts`.
3. If it needs native communication, add interfaces in `bridge/native/` or `bridge/web/` and run `yarn codegen`.
4. Write tests in `test/`.

## Dependencies

- **CodeMirror 6** (`@codemirror/*`) — editor core, extensions, search, autocomplete
- **Lezer** (`@lezer/*`) — incremental parser for syntax highlighting
- **markedit-api** — public extension API (GitHub package)
- **js-yaml**, **uuid** — utility libraries
