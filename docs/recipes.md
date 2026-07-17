# Recipes

This guide provides task-based recipes for running and formatting tests with `@dashkite/amen-console`.

## Recipes

### 1. Outputting Test Results Programmatically

#### Task
Programmatically execute a test suite and format the output dynamically in a terminal.

#### How the software enables the task
The `print` utility accepts test suites (which implement `[Symbol.asyncIterator]`) and automatically formats output in real-time. In interactive TTY terminals, it launches the interactive TUI. In headless, CI, or pipe environments, it automatically falls back to a scrollable text stream to prevent crashes and log pollution.

#### Code Example
```coffeescript
import { test } from "@dashkite/amen"
import print from "@dashkite/amen-console"

# Define the suite
suite = test "Core Logic Suite", [
  test "performs computation", -> true
  test "handles error states", -> throw new Error "Expected failure"
]

# Execute and print results
await print suite
```

#### Algorithm
1. Import `test` from `@dashkite/amen` and the default `print` function from `@dashkite/amen-console`.
2. Define the test suite or test cases using the `test` factory.
3. Pass the test suite instance directly as the first argument to `print` and await it.
4. The output is streamed in real-time to standard error using the appropriate layout (TUI or text stream).

### 2. Running and Watching Tests with the TUI CLI

#### Task
Run tests in an interactive, keyboard-driven terminal interface that automatically reruns when source or test files change.

#### How the software enables the task
The package registers an `amen` command-line executable. The CLI forks your test script, establishes an IPC channel to receive events, and renders them in an interactive Blessed TUI. When `--watch` is enabled, the CLI watches the workspace filesystem for changes and triggers test reruns.

#### Code Example
```bash
# Run tests in watch mode
npx amen --watch build/node/test/index.js
```

#### Algorithm
1. Build or compile your test files to JavaScript.
2. Run the `amen` binary passing the path to the main test script.
3. Pass `--watch` or `-w` to enable hot-reloading.
4. Interact with the running TUI using keyboard shortcuts:
   - Use Up/Down arrows to navigate the test tree list.
   - Press Enter to toggle details/stack traces for failed tests.
   - Press `r` to manually rerun the test suite.
   - Press `w` to toggle file-watching on/off.
   - Press `q`, `escape`, or `Ctrl+C` to quit.
