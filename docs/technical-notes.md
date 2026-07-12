# Technical Notes

### Debug Mode and Stack Traces

The `print` function checks for the presence of the `debug` or `DEBUG` environment variables. If either is set, it will include the full stack trace when printing failed tests. Otherwise, it only prints the error message.

### Output Stream

All test output is printed to `console.error` (standard error) rather than `console.log` (standard output). This ensures test results are not mixed with standard application output when piping or redirecting streams.
