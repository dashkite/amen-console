# Amen Console

*Print Amen test output to the console*

[![Hippocratic License HL3-CORE](https://img.shields.io/static/v1?label=Hippocratic%20License&message=HL3-CORE&labelColor=5e2751&color=bc8c3d)](https://firstdonoharm.dev/version/3/0/core.html)

Amen Console is a utility for the Dashkite ecosystem that formats and prints Amen test output directly to the console.

## Features

- **TUI CLI**: Runs tests inside an interactive terminal user interface with watch mode (hot-reloading).
- **TTY Autodetection**: Automatically detects if the output stream is a TTY to render either the interactive TUI or a scrollable text stream.
- **CI / Non-TTY Support**: Prevents interactive control sequences when executing in headless environments (like GitHub Actions) or non-TTY pipes, falling back to a clean text output stream and avoiding crashes.

## Installation

Install Amen Console into your project using your favorite package manager:

```bash
pnpm add -D @dashkite/amen-console
```

## CLI Usage

Amen Console registers a CLI executable named `amen`. To run a test suite:

```bash
npx amen path/to/test.js
```

### Options

- `-w`, `--watch`: Runs tests in watch mode. The CLI watches the `src/` and `test/` directories (as well as the test file's directory) and automatically reruns the suite whenever a file change is detected.

## Programmatic Usage

You can import and invoke the console print utility directly in your test files:

```coffeescript
import { test } from "@dashkite/amen"
import print from "@dashkite/amen-console"

await print test "my test suite", [
  test "a passing test", -> true
  test "a failing test", -> throw new Error "Something went wrong!"
]
```

## Other Resources

- [Reference Guide](docs/reference.md)
- [Usage Recipes](docs/recipes.md)
- [Technical Notes](docs/technical-notes.md)
- [Testing Guide](docs/testing.md)

