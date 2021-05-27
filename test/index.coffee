import assert from "assert"
import {print, test, success} from "amen"

import * as x from "../src"

do ->

  print await test "", [

    test "", ->

  ]

  process.exit if success then 0 else 1
