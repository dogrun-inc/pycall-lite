# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-11-16

### Added

- A Ruby NumPy interface inspired by [numpy.rb](https://github.com/red-data-tools/numpy.rb),
  with `Numpy::VERSION`, `asarray`, `asscalar`, `mean`, dtype access, and delegation
  to Python NumPy. Load the Pyodide `numpy` package before `require "numpy"`.
- `Numpy::NDArray` wrappers with single- and multidimensional indexing and
  conversion to nested Ruby Arrays. Like NumPy's `tolist()`, `to_a` returns a
  scalar for zero-dimensional arrays. Full numpy.rb compatibility is not guaranteed;
  the native `numo/narray` dependency for `to_narray` is not bundled.
- Python type mappings and conversion of NumPy integer, floating, complex, and
  boolean scalars, including user-defined subclasses of those scalar types.
- Keyword argument forwarding through callables, constructors, import helpers,
  and NumPy delegation, preserving the distinction from positional Hash arguments.
- Bidirectional conversion of Ruby/Python complex values and large integers,
  using JavaScript BigInt to preserve integer precision outside the safe-number range.
- NumPy RSpec and JavaScript integration coverage, and bilingual documentation
  for setup, numeric conversions, and compatibility limitations.

### Changed

- `setupPyCall` rejects a different Pyodide instance for an already connected Ruby VM
  before modifying its state. Repeated setup with the same pair remains supported;
  use a new Ruby VM for another interpreter.
- NumPy wrappers are embedded and loaded lazily through both `require` and
  `Kernel.require`, including path-like arguments accepted by `File.path`.

### Fixed

- Repeated setup no longer overwrites the original `require` alias and causes
  recursive fallback loading.
- Invalid ndarray indices consistently raise `PyCall::PythonError`. The Python
  indexing helper is cached per Ruby VM and reset during setup.
- Floating ndarray values retain their Ruby Float type through indexing,
  `asscalar`, and `to_a`, including non-native byte orders. `mean` preserves array
  and complex results and honors positional and keyword dtype arguments.
- Numeric wrapping preserves NaN, positive/negative infinity, and negative zero.
- NumPy array subclasses such as `MaskedArray` are no longer mistaken for scalars.
- Python helper calls use builtins independently of application globals named
  `int`, `float`, `complex`, `bool`, `len`, `tuple`, or `isinstance`.

**Full Changelog**: [v0.1.1...v0.2.0](https://github.com/dogrun-inc/pycall-lite/compare/v0.1.1...v0.2.0)

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
