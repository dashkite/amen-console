#!/usr/bin/env node

const { fork } = require("child_process");
const { resolve, dirname } = require("path");
const { existsSync } = require("fs");
const chokidar = require("chokidar");
const { renderBlessedTUI } = require("../build/node/src/index.js");

// CLI Arguments
const args = process.argv.slice(2);
const watchMode = args.includes("--watch") || args.includes("-w");
const testFileIndex = args.findIndex(arg => !arg.startsWith("-"));
if (testFileIndex === -1) {
  console.error("Error: Please specify a test file.");
  process.exit(1);
}
const testFile = resolve(args[testFileIndex]);

if (!existsSync(testFile)) {
  console.error(`Error: Test file not found: ${testFile}`);
  process.exit(1);
}

// Queue system for feeding events into renderBlessedTUI
const { ReactorQueue } = require("@dashkite/river");
const eventQueue = ReactorQueue.make();

let child = null;
let currentTree = null;

function reconstructTree(serialized, parent = null) {
  const node = {
    description: serialized.description,
    parent: parent,
    status: "waiting",
    children: null
  };
  if (serialized.children) {
    node.children = serialized.children.map(child => reconstructTree(child, node));
  }
  return node;
}

function findChildWithDescription(node, description) {
  if (!node || !node.children) return null;
  const direct = node.children.find(child => child.description === description);
  if (direct) return direct;
  for (const child of node.children) {
    if (child.description === null || child.description === undefined) {
      const match = findChildWithDescription(child, description);
      if (match) return match;
    }
  }
  return null;
}

function findNodeByPath(node, path) {
  let current = node;
  for (const step of path) {
    current = findChildWithDescription(current, step);
    if (!current) return null;
  }
  return current;
}

function runTests() {
  if (child) {
    child.kill("SIGKILL");
  }

  child = fork(testFile, [], {
    stdio: ["ignore", "inherit", "inherit", "ipc"],
    env: {
      ...process.env,
      AMEN_IPC: "true"
    },
    execArgv: ["--enable-source-maps"]
  });

  child.on("message", (message) => {
    let node = null;
    if (message.type === "suite:start") {
      currentTree = reconstructTree(message.tree);
      require("fs").writeFileSync("debug_full.log", JSON.stringify(message, null, 2) + "\n");
    } else {
      node = findNodeByPath(currentTree, message.testPath);
    }
    require("fs").appendFileSync(
      "debug.log",
      `type: ${message.type}, path: ${JSON.stringify(message.testPath)}, resolved: ${node ? node.description : "NULL"}\n`
    );
    if (message.type === "suite:start") {
      eventQueue.enqueue({ type: "suite:start", tree: currentTree });
    } else {
      eventQueue.enqueue({
        type: message.type,
        test: node,
        error: message.error
      });
    }
  });

  child.on("exit", (code) => {
    eventQueue.enqueue({ type: "suite:end", code });
  });

  child.on("error", (err) => {
    eventQueue.enqueue({
      type: "suite:end",
      error: { message: err.message, stack: err.stack }
    });
  });
}

let watcher = null;
let watchActive = watchMode;

function startWatching() {
  if (watcher) return;
  const dirsToWatch = [];
  if (existsSync("src")) dirsToWatch.push("src");
  if (existsSync("test")) dirsToWatch.push("test");
  
  const testFileDir = dirname(testFile);
  if (!dirsToWatch.includes(testFileDir) && existsSync(testFileDir)) {
    dirsToWatch.push(testFileDir);
  }

  watcher = chokidar.watch(dirsToWatch, { ignoreInitial: true });
  watcher.on("all", () => {
    runTests();
  });
}

function stopWatching() {
  if (watcher) {
    watcher.close();
    watcher = null;
  }
}

// Start Blessed TUI in parent process
renderBlessedTUI(eventQueue, null, {
  onRerun: () => {
    runTests();
  },
  onToggleWatch: () => {
    watchActive = !watchActive;
    if (watchActive) {
      startWatching();
    } else {
      stopWatching();
    }
  },
  isWatchActive: () => {
    return watchActive;
  },
  onExit: () => {
    if (child) {
      child.kill("SIGKILL");
    }
    stopWatching();
    process.exit(0);
  }
});

if (watchActive) {
  startWatching();
}

// Kickoff first run
runTests();
