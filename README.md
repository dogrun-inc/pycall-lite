# pycall-lite

`pycall-lite` is a library that provides a PyCall-like interface for calling Python from Ruby in a Ruby.wasm + Pyodide environment.

The goal is to offer a coding style close to `pycall.rb`, so code like the following can run in browsers and Node.js:

```ruby
require "pycall"
math = PyCall.import_module("math")
math.sin(math.pi / 4)
```

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

- `https://cdn.jsdelivr.net/npm/pycall-lite@0.1.0/dist/index.js`
- `https://unpkg.com/pycall-lite@0.1.0/dist/index.js`

If you use jsDelivr, add an import map like this in your HTML.
Adjust library versions as needed.

```html
<script type="importmap">
{
	"imports": {
		"pycall-lite": "https://cdn.jsdelivr.net/npm/pycall-lite@0.1.0/dist/index.js",
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
		"pycall-lite": "https://cdn.jsdelivr.net/npm/pycall-lite@0.1.0/dist/index.js",
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
- `Symbol` -> `String`
- `Hash` -> JS Object (used as dict-like data on the Python side)
- `Array` -> JS Array
- `Proc` -> JS callable from Python

Example:

```ruby
payload = { key: [1, :two, true, nil] }
converted = PyCall.ruby_to_js(payload)
```

---

## Key differences from pycall.rb

- Runtime is Pyodide (WebAssembly), not CPython.
- Preferred callable syntax is `obj.call(...)` rather than `obj.(...)`.
- Full keyword argument compatibility (`x: 1`) is not guaranteed.
- `without_gvl` and Python executable selection (`PYTHON` environment variable) are out of scope.

---

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