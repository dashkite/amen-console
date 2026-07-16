import blessed from "neo-blessed"
import { red, green, yellow, blue, cyan, gray, bold } from "colorette"

debug = ( process.env.debug? ) || ( process.env.DEBUG? )

getIndent = ( test ) ->
  indent = ""
  parent = test.parent
  while parent?
    if parent.description?
      indent += "  "
    parent = parent.parent
  indent

printSummary = ( statistics ) ->
  duration = ( ( Date.now() - statistics.startTime ) / 1000 ).toFixed 2
  console.error ""
  console.error bold "Test Summary:"
  
  passed = green "#{statistics.passed} passed"
  failed =
    if statistics.failed > 0
      red "#{statistics.failed} failed"
    else
      "0 failed"
  skipped = yellow "#{statistics.skipped} skipped"
  pending = yellow "#{statistics.pending} pending"
  
  console.error "  Tests:    #{passed}, #{failed}, #{skipped}, " +
    "#{pending} (#{statistics.total} total)"
  console.error "  Duration: #{duration}s"
  if statistics.failed > 0 && process?
    process.exitCode = 1

printTree = ( test, statistics, indent = "" ) ->
  if test.description?
    if test.children?
      console.error indent + cyan( test.description )
      for child in test.children
        printTree child, statistics, ( indent + "  " )
    else
      status = test.status
      if status == "passed"
        statistics.passed++
        console.error indent + green( "✔ " + test.description )
      else if status == "failed"
        statistics.failed++
        console.error indent + red( "✘ " + test.description )
        console.error indent + "  " + gray( test.error?.stack ? test.error?.message ? "Unknown error" )
      else if status == "skipped"
        statistics.skipped++
        console.error indent + yellow( "- " + test.description )
      else if status == "pending"
        statistics.pending++
        console.error indent + yellow( "? " + test.description )
  else
    if test.children?
      for child in test.children
        printTree child, statistics, indent

streamEvents = ( iterator, target ) ->
  statistics =
    passed: 0
    failed: 0
    skipped: 0
    pending: 0
    total: 0
    startTime: Date.now()
  for await event from iterator
    if event.type == "test:start"
      statistics.total++

  printTree target, statistics
  printSummary statistics

renderBlessedTUI = ( iterator, target ) ->
  screen = blessed.screen autoPadding: true
  
  tree = blessed.list
    parent: screen
    top: 0
    left: 0
    width: "100%"
    bottom: 2
    keys: true
    mouse: true
    parseAnsi: true
    scrollbar: ch: " "
    style:
      selected:
        bg: "cyan"
        fg: "black"

  status = blessed.box
    parent: screen
    bottom: 1
    height: 1
    tags: true
    content: "  Running tests..."

  shortcuts = blessed.box
    parent: screen
    bottom: 0
    height: 1
    tags: true
    style:
      bg: "cyan"
      fg: "black"
    content:
      "  UP/DOWN: Scroll | LEFT/RIGHT: Top/Bottom | ENTER: Toggle | ESC/q: Exit"
  
  statistics =
    passed: 0
    failed: 0
    skipped: 0
    pending: 0
    total: 0
    startTime: Date.now()

  resolver = null
  promise = new Promise ( resolve ) -> resolver = resolve

  exit = ->
    do screen.destroy
    do process.stdin.pause
    printSummary statistics
    do resolver

  screen.key [ "escape", "q", "C-c" ], exit

  updateStatus = ( finished = false ) ->
    passed = statistics.passed
    failed = statistics.failed
    skipped = statistics.skipped
    pending = statistics.pending
    total = statistics.total
    
    percent = 0
    if total > 0
      percent = Math.round( ( passed + failed + skipped + pending ) / total ) * 100

    text = if finished then "Execution Finished" else "Running tests..."
    status.setContent "  #{text} | #{percent}% complete | " +
      "✔ #{passed} | ✘ #{failed} | - #{skipped} | ? #{pending} | total: #{total}"

  expanded = null
  updating = false
  tests = []

  renderTreeView = ->
    updating = true
    items = []
    tests = []
    
    walk = ( test, indent = "" ) ->
      if test.description?
        test.lineIndex = items.length
        tests.push test
        
        label = ( gray "•" ) + " #{test.description}"
        if test.status == "passed"
          label = ( green "✔" ) + " #{test.description}"
        else if test.status == "failed"
          msg = if test.error?.message? then " (#{test.error.message})" else ""
          label = ( red "✘" ) + " #{test.description}" + ( red msg )
        else if test.status == "skipped"
          label = ( yellow "-" ) + " #{test.description}"
        else if test.status == "pending"
          label = ( yellow "?" ) + " #{test.description}"
        else if test.status == "running"
          label = ( yellow "*" ) + " #{test.description} (running...)"
        
        if test.children?
          items.push indent + ( cyan "+ " + test.description )
          for child in test.children
            walk child, ( indent + "  " )
        else
          items.push indent + label
          if test == expanded
            error = test.error?.stack ? test.error?.message ? "Unknown error"
            stackLines = error.split "\n"
            for line in stackLines
              items.push indent + "  " + ( red line )
              tests.push null
      else
        if test.children?
          for child in test.children
            walk child, indent

    walk target
    
    selected = tree.selected
    tree.setItems items
    tree.select selected
    do screen.render
    updating = false

  do renderTreeView
  do tree.focus

  tree.key "left", ->
    tree.select 0
    do screen.render

  tree.key "right", ->
    tree.select ( tree.items.length - 1 )
    do screen.render

  tree.on "action", ( item, index ) ->
    test = tests[ index ]
    if test?
      if test.status == "failed"
        if expanded == test
          expanded = null
        else
          expanded = test
        do renderTreeView
        tree.select test.lineIndex

  try
    for await event from iterator
      test = event.test
      
      switch event.type
        when "test:start"
          statistics.total++
          test.status = "running"
        when "test:success"
          statistics.passed++
          test.status = "passed"
        when "test:failure"
          statistics.failed++
          test.status = "failed"
          test.error = event.error
        when "test:skipped"
          statistics.skipped++
          test.status = "skipped"
        when "test:pending"
          statistics.pending++
          test.status = "pending"
      
      do renderTreeView
      do updateStatus
      do screen.render
    
    updateStatus true
    do screen.render

    await promise
  catch error
    do screen.destroy
    do process.stdin.pause
    throw error

printLegacyTree = ( [ description, result ], indent = "" ) ->
  if Array.isArray result
    console.error indent + blue( description )
    for child in result
      printLegacyTree child, ( indent + "  " )
  else
    console.error indent +
      if result?
        if result == true
          green "✔ #{description}"
        else
          if process?
            process.exitCode = 1
          if ( result.message? ) && ( result.message != "" )
            if ( result.stack? ) && debug
              red "✘ #{description} (#{result.message})\n#{result.stack}"
            else
              red "✘ #{description} (#{result.message})"
          else
            red "✘ #{description}"
      else
        yellow "➖ #{description}"

print = ( target, options = {} ) ->
  mode = options.mode
  if ! mode?
    isCI = ( process.env.CI? ) || ( ! process.stdout.isTTY )
    mode = if isCI then "stream" else "tui"

  if target?[ Symbol.asyncIterator ]?
    if mode == "tui"
      renderBlessedTUI target, target
    else
      streamEvents target, target
  else
    printLegacyTree target, ""

export default print
