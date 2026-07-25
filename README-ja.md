# pycall-lite (日本語ドキュメント)

`pycall-lite` は、Ruby から Python を呼ぶ `PyCall` ライクなインターフェースを、Ruby.wasm + Pyodide 環境向けに実装したライブラリです。

目標は「`pycall.rb` に近い書き味」で、以下のようなコードをブラウザ/Node.js で使えることです。

```ruby
require "pycall"
math = PyCall.import_module("math")
math.sin(math.pi / 4)
```

---

## 動作環境

### ブラウザ

- ES Modules が使えるモダンブラウザ
- WebAssembly 対応
- `SharedArrayBuffer` まわりは実行構成に依存 (必要に応じて COOP/COEP 設定)

推奨依存バージョン:
- `@ruby/wasm-wasi`: `^2.9.3-2.9.4`
- `@ruby/3.3-wasm-wasi`: `^2.9.3-2.9.4`
- `pyodide`: `314.0.2`

### Node.js

- Node.js 18 以上 (ESM)

推奨依存バージョン:
- `@ruby/wasm-wasi`: `^2.9.3-2.9.4`
- `@ruby/3.3-wasm-wasi`: `^2.9.3-2.9.4`
- `pyodide`: `314.0.2`

---

## インストール

### ブラウザ (CDN)

`pycall-lite` は unpkg/jsDelivr から参照できます。

- `https://cdn.jsdelivr.net/npm/pycall-lite@0.1.0/dist/index.js`
- `https://unpkg.com/pycall-lite@0.1.0/dist/index.js`

jsDelivr から参照する場合、以下のように HTML に書きます。
各ライブラリのバージョンは適宜調整してください。

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

## クイックスタート

### ブラウザ (ローカル配布 / node_modules 参照)

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

➤最小構成イメージですので、実際の import パスはプロジェクト構成に合わせて調整してください。

### ブラウザ (CDN)

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

## 使い方

この章は `pycall.rb` の README の使い方を参考に、 `pycall-lite` での対応を示します。

### 1. モジュールの読み込み

```ruby
require "pycall"
math = PyCall.import_module("math")
math.sin(math.pi / 4)
```

### 2. コンストラクタ呼び出し

Python の `ClassName(x, y, z)` は、`pycall-lite` では `ClassName.new(x, y, z)` で呼びます。

```ruby
types = PyCall.import_module(:types)
ns = types.SimpleNamespace.new
ns.value = 10
```

### 3. callable オブジェクト呼び出し

`pycall-lite` では callable オブジェクトを `obj.call(...)` で呼びます。

```ruby
fn = PyCall.import_module("__main__").some_callable
fn.call(1, 2)
```

### 4. callable 属性の呼び出し

Python の `obj.meth(x, y)` に相当する呼び出しは、そのまま Ruby 側で `obj.meth(x, y)` と書けます。

```ruby
obj.meth(1, 2)
```

また `pycall-lite` では、引数なしの `obj.meth` は「呼び出し」ではなく属性取得として扱われます。

### 5. 属性参照・代入

```ruby
box = PyCall.import_module("__main__").box
box.value        # 読み取り
box.value = 100  # 書き込み
```

### 6. インデックスアクセス

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

### 8. Ruby -> Python の型変換

主な変換:
- `Symbol` -> `String`
- `Hash` -> JS Object (Python 側では dict 相当として利用)
- `Array` -> JS Array
- `Proc` -> Python から呼び出せる JS callable

例:

```ruby
payload = { key: [1, :two, true, nil] }
converted = PyCall.ruby_to_js(payload)
```

---

## pycall.rb との主な差分

- 実行基盤が CPython ではなく Pyodide (WebAssembly) です。
- Python callable の呼び出し記法は `obj.(...)` ではなく `obj.call(...)` が中心です。
- キーワード引数 (`x: 1`) の完全互換は未保証です。
- `without_gvl` や Python 実行ファイル選択 (`PYTHON` 環境変数) は対象外です。

---

## テスト

JavaScript 側:

```bash
npm run test:npm
```

Ruby 視点 (RSpec):

```bash
npm run test:rspec
```

全体:

```bash
npm test
```

---

## 制約 / 注意点

- Ruby.wasm と Pyodide の制約をそのまま受けます。
- Python の全機能・全型の完全互換を保証するものではありません。
- 環境差 (ブラウザ / Node.js, バージョン差) により挙動差が出る可能性があります。

---

## ライセンス

MIT
