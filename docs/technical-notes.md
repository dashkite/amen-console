# Technical Notes

### Debug Mode and Stack Traces

The `print` function checks for the presence of the `debug` or `DEBUG` environment variables. If either is set, it will include the full stack trace when printing failed tests. Otherwise, it only prints the error message.

### Output Stream

All test output is printed to `console.error` (standard error) rather than `console.log` (standard output). This ensures test results are not mixed with standard application output when piping or redirecting streams.

### TTY Autodetection and CI Mode

The console print utility automatically detects whether the execution environment supports interactive rendering. It defaults to streaming text output if:
1. The standard output stream is not a TTY (`! process.stdout.isTTY`).
2. The `CI` environment variable is defined (`process.env.CI?`).
3. The test suite is invoked via npm test (`process.env.npm_lifecycle_event == "test"`).

Otherwise, it launches the full interactive terminal user interface (TUI). This auto-fallback behavior prevents the TUI from executing in non-interactive shell environments (such as CI/CD pipelines) where rendering controls would fail.

### CLI and Watch Mode

The `amen` CLI binary runs the test suite in a child process with IPC enabled (`AMEN_IPC: "true"`). This allows the parent process to render the Blessed TUI independently of the test execution, safeguarding the terminal interface. When watch mode is activated via the `--watch` or `-w` flag, the CLI sets up filesystem observers (using `chokidar`) to automatically rebuild or rerun the suite upon file modifications, avoiding manual restarts.
