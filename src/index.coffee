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
    indent += "  "
    parent = parent.parent
  indent

printSummary = ( stats ) ->
  duration = ( ( Date.now() - stats.startTime ) / 1000 ).toFixed 2
  console.error ""
  console.error bold "Test Summary:"
  console.error "  Tests:    " + green( "#{stats.passed} passed" ) + ", " +
                ( if stats.failed > 0 then red( "#{stats.failed} failed" ) else "0 failed" ) + ", " +
                yellow( "#{stats.skipped} pending/skipped" ) + " (#{stats.total} total)"
  console.error "  Duration: #{duration}s"

streamEvents = ( iterator ) ->
  stats = { passed: 0, failed: 0, skipped: 0, total: 0, startTime: Date.now() }
  for await event from iterator
    indent = getIndent event.test
    switch event.type
      when "test:start"
        stats.total++
      when "test:success"
        stats.passed++
        console.error indent + green( "✔ " + event.test.description )
      when "test:failure"
        stats.failed++
        console.error indent + red( "✘ " + event.test.description )
        console.error indent + "  " + gray( event.error.stack ? event.error.message )
      when "test:skipped", "test:pending"
        stats.skipped++
        console.error indent + yellow( "➖ " + event.test.description + " (pending)" )
      when "group:start"
        console.error indent + cyan( event.test.description )

  printSummary stats

renderBlessedTUI = ( iterator ) ->
  screen = blessed.screen autoPadding: true
  treeView = blessed.log parent: screen, bottom: 2, tags: true, scrollable: true
  progressBar = blessed.progressbar
    parent: screen
    bottom: 0
    height: 1
    style:
      bar: bg: "green"
      bg: bg: "gray"
  
  stats = { passed: 0, failed: 0, skipped: 0, total: 0, startTime: Date.now() }

  try
    for await event from iterator
      indent = getIndent event.test
      switch event.type
        when "test:start"
          stats.total++
        when "test:success"
          stats.passed++
          treeView.log indent + "{green-fg}✔{/green-fg} " + event.test.description
        when "test:failure"
          stats.failed++
          treeView.log indent + "{red-fg}✘{/red-fg} " + event.test.description
          stackLines = ( event.error?.stack ? "" ).split "\n"
          for line in stackLines
            treeView.log indent + "  {red-fg}#{line}{/red-fg}"
        when "test:skipped", "test:pending"
          stats.skipped++
          treeView.log indent + "{yellow-fg}➖ " + event.test.description + " (pending){/yellow-fg}"
        when "group:start"
          treeView.log indent + "{cyan-fg}📂 " + event.test.description + "{/cyan-fg}"
      
      if stats.total > 0
        progressBar.setProgress ( ( stats.passed + stats.skipped ) / stats.total ) * 100
      screen.render()
  finally
    screen.destroy()
    process.stdin.pause()

  printSummary stats

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
        else if ( result.message? ) && ( result.message != "" )
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
      renderBlessedTUI target
    else
      streamEvents target
  else
    printLegacyTree target, ""

export default print
