# pycall-lite

`pycall-lite` is a library that provides a PyCall-like interface for calling Python from Ruby in a Ruby.wasm + Pyodide environment.

The goal is to offer a coding style close to `pycall.rb`, so code like the following can run in browsers and Node.js:

```ruby
require "pycall"
math = PyCall.import_module("math")
math.sin(math.pi / 4)
```

v0.2.0 adds a Ruby NumPy interface inspired by
[numpy.rb](https://github.com/red-data-tools/numpy.rb), including ndarray wrappers,
dtype-aware scalar conversion, and conversion to Ruby Arrays. It supports the core
(operations described below; full compatibility with the numpy.rb gem is not guaranteed.)

---

## Environment

### Browser

- A modern browser with ES Modules support
- WebAssembly support
- `SharedArrayBuffer` behavior depends on runtime configuration (configure COOP/COEP if needed)

Recommended dependency versions:
- `@ruby/wasm-wasi`: `^2.9.3-2.9.4`
- `@ruby/3.3-wasm-wasi`: `^2.9.3-2.9.4`
- `pyodide`: `314.0.2`

### Node.js

- Node.js 18 or later (ESM)

Recommended dependency versions:
- `@ruby/wasm-wasi`: `^2.9.3-2.9.4`
- `@ruby/3.3-wasm-wasi`: `^2.9.3-2.9.4`
- `pyodide`: `314.0.2`

---

## Installation

### Browser (CDN)

`pycall-lite` is available via unpkg and jsDelivr.

- `https://cdn.jsdelivr.net/npm/pycall-lite@0.2.0/dist/index.js`
- `https://unpkg.com/pycall-lite@0.2.0/dist/index.js`

If you use jsDelivr, add an import map like this in your HTML.
Adjust library versions as needed.

```html
<script type="importmap">
{
	"imports": {
		"pycall-lite": "https://cdn.jsdelivr.net/npm/pycall-lite@0.2.0/dist/index.js",
		"@ruby/wasm-wasi/dist/esm/browser.js": "https://cdn.jsdelivr.net/npm/@ruby/wasm-wasi@2.9.3-2.9.4/dist/esm/browser.js",
		"@bjorn3/browser_wasi_shim": "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.4.2/dist/index.js",
		"pyodide": "https://cdn.jsdelivr.net/npm/pyodide@314.0.2/pyodide.mjs"
	}
}
</script>
```

### Node.js / Bundler (Vite, Webpack, etc.)

```bash
npm install pycall-lite
```

---

## Quick Start

### Browser (Local Distribution / node_modules)

```html
<script type="module">
	import { DefaultRubyVM } from "./node_modules/@ruby/wasm-wasi/dist/esm/browser.js";
	import { loadPyodide } from "./node_modules/pyodide/pyodide.mjs";
	import { setupPyCall } from "./node_modules/pycall-lite/dist/index.js";

	const pyodide = await loadPyodide({
		indexURL: new URL("./node_modules/pyodide/", import.meta.url).href,
	});

	const wasmUrl = new URL("./node_modules/@ruby/3.3-wasm-wasi/dist/ruby+stdlib.wasm", import.meta.url);
	const wasmBinary = await fetch(wasmUrl).then((r) => r.arrayBuffer());
	const rubyModule = await WebAssembly.compile(wasmBinary);
	const { vm } = await DefaultRubyVM(rubyModule);

	setupPyCall(vm, pyodide);

	vm.eval(`
		require "pycall"
		math = PyCall.import_module("math")
		JS.global[:browser_result] = math.sin(math.pi / 2)
	`);

	console.log(globalThis.browser_result); // => 1
</script>
```

This is a minimal example. Adjust import paths to match your project layout.

### Browser (CDN)

```html
<script type="importmap">
{
	"imports": {
		"pycall-lite": "https://cdn.jsdelivr.net/npm/pycall-lite@0.2.0/dist/index.js",
		"@ruby/wasm-wasi/dist/esm/browser.js": "https://cdn.jsdelivr.net/npm/@ruby/wasm-wasi@2.9.3-2.9.4/dist/esm/browser.js",
		"@bjorn3/browser_wasi_shim": "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.4.2/dist/index.js",
		"pyodide": "https://cdn.jsdelivr.net/npm/pyodide@314.0.2/pyodide.mjs"
	}
}
</script>

<script type="module">
	import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/esm/browser.js";
	import { loadPyodide } from "pyodide";
	import { setupPyCall } from "pycall-lite";

	const pyodide = await loadPyodide({
		indexURL: "https://cdn.jsdelivr.net/npm/pyodide@314.0.2/",
	});

	const wasmUrl = "https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.9.3-2.9.4/dist/ruby+stdlib.wasm";
	const wasmBinary = await fetch(wasmUrl).then((r) => r.arrayBuffer());
	const rubyModule = await WebAssembly.compile(wasmBinary);
	const { vm } = await DefaultRubyVM(rubyModule);

	setupPyCall(vm, pyodide);

	vm.eval(`
		require "pycall"
		math = PyCall.import_module("math")
		JS.global[:browser_result] = math.sin(math.pi / 2)
	`);

	console.log(globalThis.browser_result); // => 1
</script>
```

### Node.js

```js
import fs from "node:fs/promises";
import path from "node:path";
import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/node";
import { loadPyodide } from "pyodide";
import { setupPyCall } from "pycall-lite";

async function main() {
	const pyodide = await loadPyodide();

	const wasmPath = path.resolve("node_modules/@ruby/3.3-wasm-wasi/dist/ruby+stdlib.wasm");
	const binary = await fs.readFile(wasmPath);
	const wasmModule = await WebAssembly.compile(binary);
	const { vm } = await DefaultRubyVM(wasmModule);

	setupPyCall(vm, pyodide);

	vm.eval(`
		require "pycall"
		math = PyCall.import_module(:math)
		JS.global[:result] = math.sin(math.pi / 2)
	`);

	console.log(globalThis.result); // => 1
}

main().catch(console.error);
```

---

## Usage

This section follows the usage style in `pycall.rb` README and shows the corresponding behavior in `pycall-lite`.

### 1. Importing modules

```ruby
require "pycall"
math = PyCall.import_module("math")
math.sin(math.pi / 4)
```

### 2. Calling constructors

Python's `ClassName(x, y, z)` is called as `ClassName.new(x, y, z)` in `pycall-lite`.

```ruby
types = PyCall.import_module(:types)
ns = types.SimpleNamespace.new
ns.value = 10
```

### 3. Calling callable objects

In `pycall-lite`, call callable objects with `obj.call(...)`.

```ruby
fn = PyCall.import_module("__main__").some_callable
fn.call(1, 2)
```

### 4. Calling callable attributes

Equivalent to Python `obj.meth(x, y)`, you can write `obj.meth(x, y)` directly in Ruby.

```ruby
obj.meth(1, 2)
```

Also, in `pycall-lite`, `obj.meth` without arguments is treated as attribute access, not a function call.

### 5. Attribute read/write

```ruby
box = PyCall.import_module("__main__").box
box.value        # read
box.value = 100  # write
```

### 6. Index access

```ruby
d = PyCall.import_module(:json).loads('{"a": 1}')
d["a"]   # => 1
d["b"] = 2
```

### 7. `pyimport` / `pyfrom`

```ruby
require "pycall/import"

module M
	include PyCall::Import

	pyimport :math
	pyimport :json, as: :py_json
	pyfrom :math, import: [:cos, [:sin, :sin_alias]]
end

M.math.sin(0)      # => 0
M.cos(0)           # => 1
M.sin_alias(0)     # => 0
M.py_json.dumps({a: 1})
```

### 8. Ruby -> Python type conversion

Main conversions:

- `Integer` -> JS Number within the safe-integer range, BigInt otherwise (preserves integer precision)
- `Complex` -> Python complex; components use Python's floating-point precision
- `Symbol` -> `String`
- Positional `Hash` -> JS Object, exposed as a proxy on the Python side, not a native Python dict
- `Array` -> JS Array
- `Proc` -> JS callable from Python

Example:

```ruby
payload = { key: [1, :two, true, nil] }
converted = PyCall.ruby_to_js(payload)
```

Python integers returned as JS BigInt become Ruby Integer without precision loss.
Python complex and supported NumPy numeric/boolean scalars are converted to Ruby
values. NaN, positive/negative infinity, and negative zero remain Float values.

### 9. Keyword arguments

Ruby keyword arguments are forwarded separately from positional arguments through
callables, constructors, import helpers, and the NumPy interface.

```ruby
types = PyCall.import_module(:types)
ns = types.SimpleNamespace.new(answer: 42)
ns.answer # => 42
```

`fn.call({key: 1})` passes a positional JS object; `fn.call(key: 1)` passes a
Python keyword argument. Use `**options` to pass a Hash as keywords.

---

## Key differences from pycall.rb

- Python runs inside Pyodide (WebAssembly), rather than a native CPython shared library.
- Preferred callable syntax is `obj.call(...)` rather than `obj.(...)`.
- Positional Hashes cross the bridge as JS objects, rather than native Python dicts.
- `without_gvl` and Python executable selection (`PYTHON` environment variable) are out of scope.

---

## Error Handling

Exceptions raised on the Python side are automatically converted into
`PyCall::PythonError` when they cross a boundary (`PyCall.import_module`,
`PyObject#call`, dynamic method calls, `[]`/`[]=`).

```ruby
require "pycall"

math = PyCall.import_module(:math)

begin
  math.sqrt(-1)
rescue PyCall::PythonError => e
  e.message          # => a formatted message, e.g. "ValueError: expected a nonnegative input, got -1.0\n"
  e.type             # => the Python exception class (e.g. ValueError)
  e.value            # => the Python exception instance
  e.traceback        # => the Python traceback object
  e.original_error   # => the error before conversion
end
```

Errors that are not `PyCall::PythonError` (e.g. a plain `raise "boom"` in
Ruby) are re-raised unchanged, preserving their original backtrace.

---

## Connection lifetime

A Ruby VM stays connected to its initial Pyodide instance. Calling `setupPyCall`
again with the same pair is supported. Passing a different Pyodide instance for
that VM throws an Error before changing the connection. Create a new Ruby VM to
use another Pyodide instance; separate VM/Pyodide pairs can coexist.

## NumPy (v0.2.0)

### Setup and basic operations

After creating `vm` and `pyodide` as in Quick Start, load the Python package before
requiring the embedded Ruby wrapper. No separate Ruby `numpy` gem installation is needed.

```js
await pyodide.loadPackage("numpy");
setupPyCall(vm, pyodide);
vm.eval(`
  require "numpy"
  a = Numpy.asarray([[1, 2], [3, 4]], dtype: :float64)
  JS.global[:numpyResult] = a[1, 0]
`);
console.log(globalThis.numpyResult); // => 3
```

```ruby
require "numpy"

a = Numpy.asarray([[1, 2], [3, 4]], dtype: :float64)
a.is_a?(Numpy::NDArray)          # => true
a[1, 0]                        # => 3.0
a[-1, -1]                      # => 4.0
a.to_a                         # => [[1.0, 2.0], [3.0, 4.0]]
Numpy.mean(a)                  # => 2.5
Numpy.mean(a, axis: 0).to_a      # => [2.0, 3.0]
Numpy.mean(a, dtype: :int32)     # => 2
Numpy.asscalar(Numpy.asarray([1], dtype: Numpy.float32)) # => 1.0
Numpy.zeros(shape: [2]).to_a     # => [0.0, 0.0]
Numpy::VERSION                  # Python NumPy version
```

Other attributes and functions are delegated to Python NumPy. For a zero-argument
function, use `.call`, e.g. `a.tolist.call`. Invalid ndarray indices raise
`PyCall::PythonError`. Ruby Range slicing and the full numpy.rb API are not guaranteed.

### Array conversion

Load NumPy with `await pyodide.loadPackage("numpy")` before Ruby's `require "numpy"`.
`Numpy::NDArray#to_a` follows Python NumPy's `tolist()`: arrays with one or more
dimensions return nested Ruby Arrays, while a zero-dimensional array (shape `()`)
returns its scalar value. Unlike the usual Ruby `to_a` convention, the return
value is therefore not always an Array. Floating array dtypes retain Ruby Float values.

```ruby
require "numpy"

Numpy.asarray(1).to_a                      # => 1
Numpy.asarray(1, dtype: :float64).to_a     # => 1.0
Numpy.asarray([1]).to_a                    # => [1]
Numpy.asarray([[1, 2]]).to_a               # => [[1, 2]]
```

### Compatibility notes

- Specify a dtype when its numeric type matters. Ruby `1.0` becomes JS Number `1`,
  so `Numpy.asarray([1.0])` can infer an integer dtype. Use `dtype: :float64` to retain Float.
- Direct `Numpy.float64.call(2)` can still become Ruby Integer because Pyodide
  converts the result to a JS Number before the wrapper can inspect its dtype.
  Float restoration is provided for ndarray indexing, `asscalar`, `mean`, and `to_a`.
- `to_narray` requires the native `numo/narray` extension, which is not bundled or
  provided by this WebAssembly setup. It raises an error when that dependency is unavailable;
  use `to_a` for Ruby values.

## Tests

JavaScript side:

```bash
npm run test:npm
```

Ruby perspective (RSpec):

```bash
npm run test:rspec
```

All tests:

```bash
npm test
```

---

## Limitations / Notes

- Inherits constraints from Ruby.wasm and Pyodide.
- Does not guarantee full compatibility with all Python features and types.
- Behavior may differ by environment (browser / Node.js and version differences).

---

## License

MIT
