# Amen Console

*Print Amen test output to the console*

[![Hippocratic License HL3-CORE](https://img.shields.io/static/v1?label=Hippocratic%20License&message=HL3-CORE&labelColor=5e2751&color=bc8c3d)](https://firstdonoharm.dev/version/3/0/core.html)

Amen Console is a utility for the DashKite ecosystem that formats and prints Amen test output directly to the console.

## Features

- Formats Amen test results for console output
- Integrates easily with the Amen testing framework

## Installation

```bash
pnpm install -D @dashkite/amen-console
```

## Usage

Amen tests are very bare-bones by default. By integrating `@dashkite/amen-console`, you gain the ability to output test results with clear formatting and color directly in your terminal.

```coffeescript
import { test, success } from "@dashkite/amen"
import print from "@dashkite/amen-console"

# run the tests and capture the results
results = await test "my test suite", [
  test "a passing test", -> true
  test "a failing test", -> throw new Error "Something went wrong!"
]

# print the results to the console with color and formatting
print results

# exit with the appropriate status code
process.exit if success then 0 else 1
```

## Other Resources

- [Reference](docs/reference.md)
- [Recipes](docs/recipes.md)
- [Technical Notes](docs/technical-notes.md)
- [Testing](docs/testing.md)
