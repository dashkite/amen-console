# Testing

This document outlines how to run the test suite for Amen Console.

## Running Tests

Amen Console uses the `genie` task manager for running its tests. You can run the test suite using the following command:

```bash
pnpm run test
```

Or using `genie` directly:

```bash
npx genie test
```

## Structure

Tests are located in the `test/` directory. They utilize the `@dashkite/amen` testing framework to verify that the console printing functionality works correctly across successful, failed, and pending test scenarios.
