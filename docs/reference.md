# Reference

This document provides reference documentation for the Amen Console's API.

## print

$print: [ description, result ], indent \to \emptyset$

Prints the result of an Amen test to the console, formatting it based on its success, failure, or pending state. It recursively handles nested test results.

### Example

```coffeescript
import print from "@dashkite/amen-console"

print [ "test category", [ [ "success test", true ] ] ]
```
