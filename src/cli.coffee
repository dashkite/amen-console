import { fork } from "child_process"
import { resolve, dirname } from "path"
import { existsSync } from "fs"
import chokidar from "chokidar"
import { ReactorQueue } from "@dashkite/river"
import { renderBlessedTUI } from "./index"

# CLI Arguments
args = process.argv.slice 2
watch = ( args.includes "--watch" ) || ( args.includes "-w" )
index = ( args.findIndex ( arg ) -> ! ( arg.startsWith "-" ) )

if index == -1
  console.error "Error: Please specify a test file."
  process.exit 1

file = resolve args[ index ]

if ! ( existsSync file )
  console.error "Error: Test file not found: #{file}"
  process.exit 1

queue = do ReactorQueue.make

child = null
tree = null

reconstruct = ( serialized, parent = null ) ->
  node =
    description: serialized.description
    parent: parent
    status: "waiting"
    children: null
  if serialized.children
    node.children =
      ( reconstruct childNode, node for childNode in serialized.children )
  node

findChild = ( node, description ) ->
  if node? && node.children?
    direct = ( node.children.find ( childNode ) -> childNode.description == description )
    if direct?
      direct
    else
      found = null
      for childNode in node.children
        if ( ! childNode.description? ) && ( ! found? )
          match = findChild childNode, description
          if match?
            found = match
      found
  else
    null

findNode = ( node, path ) ->
  current = node
  for step in path
    if current?
      current = findChild current, step
  current

reset = ( node ) ->
  if node?
    node.status = "waiting"
    if node.children?
      ( reset childNode for childNode in node.children )

run = ->
  if child?
    do child.removeAllListeners
    child.kill "SIGKILL"

  if tree?
    ( reset tree )
  ( queue.enqueue type: "suite:start", tree: tree )

  child = fork file, [],
    stdio: [ "ignore", "inherit", "inherit", "ipc" ]
    env:
      {
        process.env...
        AMEN_IPC: "true"
      }
    execArgv: [ "--enable-source-maps" ]

  child.on "message", ( message ) ->
    node = null
    if message.type == "suite:start"
      tree = reconstruct message.tree
    else
      node = findNode tree, message.testPath

    if message.type == "suite:start"
      queue.enqueue type: "suite:start", tree: tree
    else
      queue.enqueue
        type: message.type
        test: node
        error: message.error

  child.on "exit", ( code ) ->
    queue.enqueue type: "suite:end", code: code

  child.on "error", ( error ) ->
    queue.enqueue
      type: "suite:end"
      error:
        message: error.message
        stack: error.stack

watcher = null
active = watch

observe = ->
  if watcher?
    return
  dirs = []
  if ( existsSync "src" )
    dirs.push "src"
  if ( existsSync "test" )
    dirs.push "test"

  dir = dirname file
  if ( ! ( dirs.includes dir ) ) && ( existsSync dir )
    dirs.push dir

  watcher = chokidar.watch dirs, ignoreInitial: true
  watcher.on "all", -> do run

stop = ->
  if watcher?
    do watcher.close
    watcher = null

# Start Blessed TUI in parent process
renderBlessedTUI queue, null,
  onRerun: ->
    do run
  onToggleWatch: ->
    active = ! active
    if active
      do observe
    else
      do stop
  isWatchActive: ->
    active
  onExit: ->
    if child?
      child.kill "SIGKILL"
    do stop
    process.exit 0

if active
  do observe

do run
