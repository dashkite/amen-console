import assert from "assert"
import {test, success} from "@dashkite/amen"

import print from "../src"

do ->

  print await test "category", [

    test "success", ->

    test "failure", -> throw new Error "oops"

    test "pending"

  ]

  process.exit if success then 0 else 1
