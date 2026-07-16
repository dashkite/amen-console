import blessed from "neo-blessed"

debug = ( process.env.debug? ) || ( process.env.DEBUG? )

red = ( text ) -> "\x1b[31m#{text}\x1b[0m"
green = ( text ) -> "\x1b[32m#{text}\x1b[0m"
yellow = ( text ) -> "\x1b[33m#{text}\x1b[0m"
blue = ( text ) -> "\x1b[34m#{text}\x1b[0m"
cyan = ( text ) -> "\x1b[36m#{text}\x1b[0m"
gray = ( text ) -> "\x1b[90m#{text}\x1b[0m"
bold = ( text ) -> "\x1b[1m#{text}\x1b[0m"

getIndent = ( test ) ->
  indent = ""
  parent = test.parent
  while parent?
    if parent.description?
      indent += "  "
    parent = parent.parent
  indent

printSummary = ( stats ) ->
  duration = ( ( Date.now() - stats.startTime ) / 1000 ).toFixed 2
  console.error ""
  console.error bold "Test Summary:"
  console.error "  Tests:    " + green( "#{stats.passed} passed" ) + ", " +
                ( if stats.failed > 0 then red( "#{stats.failed} failed" ) else "0 failed" ) + ", " +
                yellow( "#{stats.skipped} skipped" ) + ", " +
                yellow( "#{stats.pending} pending" ) + " (#{stats.total} total)"
  console.error "  Duration: #{duration}s"
  if stats.failed > 0 && process?
    process.exitCode = 1

printTree = ( test, stats, indent = "" ) ->
  if test.description?
    if test.children?
      console.error indent + cyan( test.description )
      for child in test.children
        printTree child, stats, ( indent + "  " )
    else
      status = test.status
      if status == "passed"
        stats.passed++
        console.error indent + green( "✔ " + test.description )
      else if status == "failed"
        stats.failed++
        console.error indent + red( "✘ " + test.description )
        console.error indent + "  " + gray( test.error?.stack ? test.error?.message ? "Unknown error" )
      else if status == "skipped"
        stats.skipped++
        console.error indent + yellow( "- " + test.description )
      else if status == "pending"
        stats.pending++
        console.error indent + yellow( "? " + test.description )
  else
    if test.children?
      for child in test.children
        printTree child, stats, indent

streamEvents = ( iterator, target ) ->
  stats = { passed: 0, failed: 0, skipped: 0, pending: 0, total: 0, startTime: Date.now() }
  for await event from iterator
    if event.type == "test:start"
      stats.total++

  printTree target, stats
  printSummary stats

renderBlessedTUI = ( iterator, target ) ->
  screen = blessed.screen autoPadding: true
  
  treeView = blessed.list
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

  statusBar = blessed.box
    parent: screen
    bottom: 1
    height: 1
    tags: true
    content: "  Running tests..."

  shortcutBar = blessed.box
    parent: screen
    bottom: 0
    height: 1
    tags: true
    style:
      bg: "cyan"
      fg: "black"
    content: "  UP/DOWN/j/k: Navigate | ENTER: Toggle stack trace | ESC/q: Exit"
  
  stats = { passed: 0, failed: 0, skipped: 0, pending: 0, total: 0, startTime: Date.now() }

  exitResolver = null
  exitPromise = new Promise ( resolve ) -> exitResolver = resolve

  exit = ->
    screen.destroy()
    process.stdin.pause()
    printSummary stats
    exitResolver()

  screen.key [ "escape", "q", "C-c" ], exit

  updateStatus = ( finished = false ) ->
    passed = stats.passed
    failed = stats.failed
    skipped = stats.skipped
    pending = stats.pending
    total = stats.total
    
    percent = 0
    if total > 0
      percent = Math.round ( ( passed + failed + skipped + pending ) / total ) * 100

    statusText = if finished then "Execution Finished" else "Running tests..."
    statusBar.setContent "  #{statusText} | #{percent}% complete | ✔ #{passed} | ✘ #{failed} | - #{skipped} | ? #{pending} | total: #{total}"

  expandedTest = null
  updatingList = false
  testsArray = []

  renderTreeView = ->
    updatingList = true
    renderedItems = []
    testsArray = []
    
    walk = ( test, indent = "" ) ->
      if test.description?
        test.lineIndex = renderedItems.length
        testsArray.push test
        
        statusStr = gray("•") + " #{test.description}"
        if test.status == "passed"
          statusStr = green("✔") + " #{test.description}"
        else if test.status == "failed"
          msg = if test.error?.message? then " (#{test.error.message})" else ""
          statusStr = red("✘") + " #{test.description}" + red(msg)
        else if test.status == "skipped"
          statusStr = yellow("-") + " #{test.description}"
        else if test.status == "pending"
          statusStr = yellow("?") + " #{test.description}"
        else if test.status == "running"
          statusStr = yellow("*") + " #{test.description} (running...)"
        
        if test.children?
          renderedItems.push indent + cyan("+ " + test.description)
          for child in test.children
            walk child, ( indent + "  " )
        else
          renderedItems.push indent + statusStr
          if test == expandedTest
            stackLines = ( test.error?.stack ? test.error?.message ? "Unknown error" ).split "\n"
            for line in stackLines
              renderedItems.push indent + "  " + red(line)
              testsArray.push null
      else
        if test.children?
          for child in test.children
            walk child, indent

    walk target
    
    selectedIndex = treeView.selected
    treeView.setItems renderedItems
    treeView.select selectedIndex
    screen.render()
    updatingList = false

  renderTreeView()
  treeView.focus()

  treeView.on "action", ( item, index ) ->
    selectedTest = testsArray[ index ]
    if selectedTest?
      if selectedTest.status == "failed"
        if expandedTest == selectedTest
          expandedTest = null
        else
          expandedTest = selectedTest
        renderTreeView()
        treeView.select selectedTest.lineIndex

  try
    for await event from iterator
      test = event.test
      
      switch event.type
        when "test:start"
          stats.total++
          test.status = "running"
        when "test:success"
          stats.passed++
          test.status = "passed"
        when "test:failure"
          stats.failed++
          test.status = "failed"
          test.error = event.error
        when "test:skipped"
          stats.skipped++
          test.status = "skipped"
        when "test:pending"
          stats.pending++
          test.status = "pending"
      
      renderTreeView()
      updateStatus()
      screen.render()
    
    updateStatus true
    screen.render()

    await exitPromise
  catch error
    screen.destroy()
    process.stdin.pause()
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
