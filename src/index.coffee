import blessed from "neo-blessed"
import { createColors } from "colorette"

{ red, green, yellow, blue, cyan, gray, bold } = createColors
  useColor: process?.stdout?.isTTY

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
  if ( statistics.failed > 0 ) && process?
    process.exitCode = 1

printTree = ( test, statistics, indent = "" ) ->
  if test.description?
    if test.children?
      console.error indent + ( cyan test.description )
      for child in test.children
        printTree child, statistics, ( indent + "  " )
    else
      status = test.status
      if status == "passed"
        statistics.passed++
        console.error indent + ( green "✔ #{test.description}" )
      else if status == "failed"
        statistics.failed++
        console.error indent + ( red "✘ #{test.description}" )
        console.error indent + "  " + ( gray test.error?.stack ? test.error?.message ? "Unknown error" )
      else if status == "skipped"
        statistics.skipped++
        console.error indent + ( yellow "- #{test.description}" )
      else if status == "pending"
        statistics.pending++
        console.error indent + ( yellow "? #{test.description}" )
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
    total: target?.count?() ? 0
    startTime: Date.now()
  for await event from iterator
    undefined

  printTree target, statistics
  printSummary statistics

renderBlessedTUI = ( iterator, target, options = {} ) ->
  screen = blessed.screen autoPadding: true
  
  tree = blessed.list
    parent: screen
    top: 0
    left: 0
    width: "100%"
    bottom: 2
    keys: true
    vi: true
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
    content: "  Running..."

  shortcuts = blessed.box
    parent: screen
    bottom: 0
    height: 1
    tags: true
    style:
      bg: "cyan"
      fg: "black"
  
  updateShortcuts = ->
    if options.onRerun?
      state = if options.isWatchActive? && do options.isWatchActive then "{bold}w: Watch{/bold}" else "w: Watch"
      shortcuts.setContent "  ↑/↓: Nav | ←/→: Jump | ↵: Toggle | r: Run | #{state} | q: Quit"
    else
      shortcuts.setContent "  ↑/↓: Nav | ←/→: Jump | ↵: Toggle | q: Quit"

  do updateShortcuts
  
  statistics =
    passed: 0
    failed: 0
    skipped: 0
    pending: 0
    total: target?.count?() ? 0
    startTime: Date.now()

  resolver = null
  promise = new Promise ( resolve ) -> resolver = resolve

  exit = ->
    do screen.destroy
    do process.stdin.pause
    printSummary statistics
    if options.onExit?
      do options.onExit
    do resolver

  screen.key [ "escape", "q", "C-c" ], exit

  screen.key [ "r" ], ->
    if options.onRerun?
      do options.onRerun

  screen.key [ "w" ], ->
    if options.onToggleWatch?
      do options.onToggleWatch
      do updateShortcuts
      do screen.render

  updateStatus = ( finished = false ) ->
    passed = statistics.passed
    failed = statistics.failed
    skipped = statistics.skipped
    pending = statistics.pending
    total = statistics.total
    
    percent = 0
    if total > 0
      percent = Math.round( ( passed + failed + skipped + pending ) / total * 100 )

    filled = Math.round( percent / 10 )
    bar = "█".repeat( filled ) + "░".repeat( 10 - filled )

    pad = ( n ) -> String( n ).padStart 3

    status.setContent "  #{bar} | " +
      "✔ #{pad passed} | ✘ #{pad failed} | - #{pad skipped} | ? #{pad pending} | total: #{pad total}"

  expanded = null
  updating = false
  tests = []

  renderTreeView = ->
    updating = true
    items = []
    tests = []
    
    walk = ( test, indent = "" ) ->
      if test?
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
            label = ( yellow "*" ) + " #{test.description}"
          
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

  tree.key "o", ->
    tree.emit "action", tree.items[ tree.selected ], tree.selected

  prefix = false

  tree.on "keypress", ( ch, key ) ->
    if prefix
      prefix = false
      if key?.name == "a"
        tree.emit "action", tree.items[ tree.selected ], tree.selected
    else
      if key?.name == "z"
        prefix = true

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
        when "suite:start"
          statistics.passed = 0
          statistics.failed = 0
          statistics.skipped = 0
          statistics.pending = 0
          statistics.total = event.total
          statistics.startTime = Date.now()
          target = event.tree
          expanded = null
          tests = []
        when "suite:end"
          updateStatus true
          do screen.render
          continue
        when "test:start"
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

serializeTree = ( test ) ->
  description: test.description
  children:
    if test.children?
      ( serializeTree child for child in test.children )
    else
      null

getTestPath = ( test, target ) ->
  path = []
  current = test
  while current? && current != target
    if current.description?
      path.unshift current.description
    current = current.parent
  path

streamIPCEvents = ( iterator, target ) ->
  process.send
    type: "suite:start"
    tree: serializeTree target
    total: if target?.count? then do target.count else 0
  for await event from iterator
    process.send
      type: event.type
      testPath: getTestPath event.test, target
      error:
        if event.error?
          message: event.error.message
          stack: event.error.stack
        else
          null

print = ( target, options = {} ) ->
  if ( process.send? ) && ( process.env.AMEN_IPC == "true" )
    if target?[ Symbol.asyncIterator ]?
      streamIPCEvents target, target
    else
      undefined
  else
    mode = options.mode
    if ! mode?
      isTest = process.env.npm_lifecycle_event == "test"
      isCI = ( process.env.CI? ) || ( ! process.stdout.isTTY ) || isTest
      mode = if isCI then "stream" else "tui"

    if target?[ Symbol.asyncIterator ]?
      if mode == "tui"
        renderBlessedTUI target, target
      else
        streamEvents target, target
    else
      printLegacyTree target, ""

export { print as default, renderBlessedTUI }
