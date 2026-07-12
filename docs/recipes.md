# Recipes

## Outputting Test Results

This recipe demonstrates how to format and print the results of your Amen tests to the console using the `print` function. The console utility takes the raw test results and outputs them with appropriate coloration (e.g., green for passing, red for failing).

### Code Example

```coffeescript
import { test, success } from "@dashkite/amen"
import print from "@dashkite/amen-console"

# run the tests and capture the results
results = await test "my test suite", [
  test "a passing test", -> true
]

# print the results to the console
print results

# exit with the appropriate status code
process.exit if success then 0 else 1
```

### Explanation

1. We import the necessary testing framework (`@dashkite/amen`) including the `success` status, and the printing utility (`@dashkite/amen-console`).
2. We run a set of tests using the `test` function, awaiting its results.
3. We pass the returned `results` array directly to the `print` function, which handles iterating through the nested test structure and printing colored output to standard error.
4. We use the `success` boolean exported by `@dashkite/amen` to exit the process with a `0` (success) or `1` (failure) status code.
