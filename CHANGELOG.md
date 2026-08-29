# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-08-29

### Added

- `PyCall::PythonError`, a Ruby exception that wraps Python-origin errors
  crossing the Pyodide/JS/Ruby boundary. It exposes `type`, `value`,
  `traceback`, `original_error`, and a formatted `message`, recovered from
  `sys.last_type` / `sys.last_value` / `sys.last_traceback` per Pyodide's
  recommended error-handling pattern.
- Automatic conversion of Python-origin errors into `PyCall::PythonError` at
  `PyCall.import_module`, `PyCall::PyObject#call`, dynamic method calls, and
  `PyCall::PyObject#[]` / `#[]=`. Non-Python errors are re-raised unchanged,
  preserving their original backtrace.
- `lib/pycall/error.rb`, embedded and loaded alongside `lib/pycall.rb` and
  `lib/pycall/import.rb` in both the JavaScript setup path (`setupPyCall`)
  and the RSpec test runner.

### Fixed

- The Python error capture helper is no longer cached as a single Ruby-side
  flag; it now checks the current `PyCall.pyodide` instance's own globals,
  so switching Pyodide instances within the same Ruby VM can no longer leave
  a stale/incorrect cached state.

## [0.1.0] - 2026-08-19

### What's Changed

- Implement minimal PyCall wrapper core APIs in [#1](https://github.com/dogrun-inc/pycall-lite/pull/1)
- Implement macro import APIs for PyCall::Import in [#2](https://github.com/dogrun-inc/pycall-lite/pull/2)
- feat: Step 5 - Bidirectional type conversion support in [#3](https://github.com/dogrun-inc/pycall-lite/pull/3)
- test: add automated npm and rspec suites for pycall-lite in [#4](https://github.com/dogrun-inc/pycall-lite/pull/4)
- fix: stabilize callable dispatch and PyProxy wrapping in tests in [#5](https://github.com/dogrun-inc/pycall-lite/pull/5)
- Prepare first release docs and npm package payload in [#6](https://github.com/dogrun-inc/pycall-lite/pull/6)

**Full Changelog**: [https://github.com/dogrun-inc/pycall-lite/commits/v0.1.0](https://github.com/dogrun-inc/pycall-lite/commits/v0.1.0)
