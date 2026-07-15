import { test } from "@dashkite/amen"

import print from "../src"

do ->
  await print test "category", [

    test "success", ->

    test "failure", -> throw new Error "oops"

    test "pending"

  ]
