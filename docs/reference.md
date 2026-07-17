# Reference

This document provides reference documentation for the Amen Console's API.

## Functions

### print

Prints the result of an Amen test suite to the console. It supports real-time streaming of events via the async iterator interface, and falls back to a legacy result tree if needed.

$print: \text{target}, \text{options} \dashrightarrow \text{promise}$

- **target**: An instance of a test class inheriting from `AbstractTest` (consumed via its async iterator), or a legacy nested result array.
- **options**: An optional configuration object:
  - `mode`: The rendering mode, either `"tui"` or `"stream"`. If omitted, `print` automatically detects whether to run in TUI or streaming mode based on the environment (checking TTY, the `CI` environment variable, or npm lifecycle events).

#### Example

```coffeescript
import { test } from "@dashkite/amen"
import print from "@dashkite/amen-console"

suite = test "API Suite", [
  test "Endpoint responds", -> true
]

# Streams results to the console, automatically choosing TUI or streaming mode
await print suite
```

### renderBlessedTUI

Launches and renders an interactive Blessed terminal user interface to view and manage test execution.

$renderBlessedTUI: \text{iterator}, \text{target}, \text{options} \dashrightarrow \text{promise}$

- **iterator**: The event stream iterator (e.g., the suite's async iterator or a `ReactorQueue` instance).
- **target**: The root test suite model being executed (used to build the interactive test hierarchy tree).
- **options**: An optional configuration object:
  - `onRerun`: A callback invoked when the developer presses the `r` key in the TUI to manually re-execute the test suite.
  - `onToggleWatch`: A callback invoked when the developer presses the `w` key to toggle hot-reloading watch mode.
  - `isWatchActive`: A callback returning a boolean indicating if watch mode is currently active.
  - `onExit`: A callback invoked when the TUI exits (e.g., via `q`, `escape`, or `Ctrl+C`).

#### Example

```coffeescript
import { renderBlessedTUI } from "@dashkite/amen-console"

# Launches the interactive TUI directly with custom controls
await renderBlessedTUI suiteIterator, suiteTarget,
  onRerun: -> console.error "Rerunning suite..."
  onExit: -> process.exit 0
```

