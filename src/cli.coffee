import { fork } from "child_process"
import { resolve, dirname } from "path"
import { existsSync } from "fs"
import chokidar from "chokidar"
import { ReactorQueue } from "@dashkite/river"
import { renderBlessedTUI } from "./index"

# CLI Arguments
args = ( process.argv.slice 2 )
watchMode = ( args.includes "--watch" ) || ( args.includes "-w" )
testFileIndex = ( args.findIndex ( arg ) -> ! ( arg.startsWith "-" ) )
if testFileIndex == -1
  ( console.error "Error: Please specify a test file." )
  ( process.exit 1 )

testFile = ( resolve args[ testFileIndex ] )

if ! ( existsSync testFile )
  ( console.error "Error: Test file not found: #{testFile}" )
  ( process.exit 1 )

eventQueue = do ReactorQueue.make

child = null
currentTree = null

reconstructTree = ( serialized, parent = null ) ->
  node =
    description: serialized.description
    parent: parent
    status: "waiting"
    children: null
  if serialized.children
    node.children =
      ( reconstructTree childNode, node for childNode in serialized.children )
  node

findChildWithDescription = ( node, description ) ->
  if ! node? || ! node.children?
    return null
  direct = ( node.children.find ( childNode ) -> childNode.description == description )
  if direct?
    return direct
  for childNode in node.children
    if ! childNode.description?
      match = ( findChildWithDescription childNode, description )
      if match?
        return match
  null

findNodeByPath = ( node, path ) ->
  current = node
  for step in path
    current = ( findChildWithDescription current, step )
    if ! current?
      return null
  current

runTests = ->
  if child?
    ( child.kill "SIGKILL" )

  child = ( fork testFile, [],
    stdio: [ "ignore", "inherit", "inherit", "ipc" ]
    env:
      {
        process.env...
        AMEN_IPC: "true"
      }
    execArgv: [ "--enable-source-maps" ]
  )

  ( child.on "message", ( message ) ->
    node = null
    if message.type == "suite:start"
      currentTree = ( reconstructTree message.tree )
    else
      node = ( findNodeByPath currentTree, message.testPath )

    if message.type == "suite:start"
      ( eventQueue.enqueue type: "suite:start", tree: currentTree )
    else
      ( eventQueue.enqueue
        type: message.type
        test: node
        error: message.error
      )
  )

  ( child.on "exit", ( code ) ->
    ( eventQueue.enqueue type: "suite:end", code: code )
  )

  ( child.on "error", ( error ) ->
    ( eventQueue.enqueue
      type: "suite:end"
      error:
        message: error.message
        stack: error.stack
    )
  )

watcher = null
watchActive = watchMode

startWatching = ->
  if watcher?
    return
  dirsToWatch = []
  if ( existsSync "src" )
    ( dirsToWatch.push "src" )
  if ( existsSync "test" )
    ( dirsToWatch.push "test" )

  testFileDir = ( dirname testFile )
  if ( ! ( dirsToWatch.includes testFileDir ) ) && ( existsSync testFileDir )
    ( dirsToWatch.push testFileDir )

  watcher = ( chokidar.watch dirsToWatch, ignoreInitial: true )
  ( watcher.on "all", -> do runTests )

stopWatching = ->
  if watcher?
    do watcher.close
    watcher = null

# Start Blessed TUI in parent process
( renderBlessedTUI eventQueue, null,
  onRerun: ->
    do runTests
  onToggleWatch: ->
    watchActive = ! watchActive
    if watchActive
      do startWatching
    else
      do stopWatching
  isWatchActive: ->
    watchActive
  onExit: ->
    if child?
      ( child.kill "SIGKILL" )
    do stopWatching
    ( process.exit 0 )
)

if watchActive
  do startWatching

do runTests
