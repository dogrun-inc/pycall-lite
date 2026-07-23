import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/node";
import { loadPyodide } from "pyodide";
import { setupPyCall } from "../dist/index.js";

let rubyModulePromise;

async function getRubyModule() {
  if (!rubyModulePromise) {
    const wasmPath = path.resolve(
      "node_modules/@ruby/3.3-wasm-wasi/dist/ruby+stdlib.wasm"
    );
    rubyModulePromise = fs
      .readFile(wasmPath)
      .then((binary) => WebAssembly.compile(binary));
  }

  return rubyModulePromise;
}

describe("pycall-lite core features", () => {
  let pyodide;
  let vm;

  beforeEach(async () => {
    pyodide = await loadPyodide();

    const module = await getRubyModule();
    const runtime = await DefaultRubyVM(module);
    vm = runtime.vm;

    setupPyCall(vm, pyodide);

    await pyodide.runPythonAsync(`
def echo(v):
    return v

def call_with_value(func, val):
    return func(val)

class CallableHolder:
    def __init__(self):
        self.fn = lambda x, y: x + y
`);
  });

  afterEach(() => {
    delete globalThis.testResult;
    delete globalThis.dictValue;
    delete globalThis.boolValue;
    delete globalThis.nilValue;
  });

  it("should support PyCall.import_module and basic function calls", async () => {
    vm.eval(`
      require "pycall"

      math = PyCall.import_module("math")
      sin_val = math.sin(math.pi / 2)

      JS.global[:testResult] = sin_val
    `);

    assert.equal(globalThis.testResult, 1);
  });

  it("supports pyimport and pyfrom macros", () => {
    vm.eval(`
      require "pycall/import"

      module TestImport
        include PyCall::Import
        pyimport :math
        pyimport :json, as: :py_json
        pyfrom :math, import: [:cos, [:sin, :sin_alias]]
      end

      JS.global[:testResult] = (
        TestImport.math.sin(0) == 0 &&
        TestImport.py_json.respond_to?(:dumps) &&
        TestImport.cos(0) == 1 &&
        TestImport.sin_alias(0) == 0
      )
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("converts Python primitives to Ruby via wrap", () => {
    vm.eval(`
      require "pycall"

      json = PyCall.import_module(:json)
      JS.global[:boolValue] = (json.loads("true") == true)
      JS.global[:nilValue] = (json.loads("null") == nil)
    `);

    assert.equal(globalThis.boolValue, true);
    assert.equal(globalThis.nilValue, true);
  });

  it("supports property get/set through method_missing", () => {
    vm.eval(`
      require "pycall"

      # Attribute exercise on python-side object with writable value field
      demo_mod = PyCall.import_module(:types)
      ns = demo_mod.SimpleNamespace.new
      ns.value = 42
      before = ns.value
      ns.value = 100
      after = ns.value

      JS.global[:testResult] = (before == 42 && after == 100)
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("supports dictionary/list index access and assignment", () => {
    vm.eval(`
      require "pycall"

      json = PyCall.import_module(:json)
      d = json.loads('{"a": 1, "b": 2}')

      val_a = d["a"]
      d["c"] = 3
      val_c = d["c"]

      lst = json.loads('[1, 2, 3]')
      val_1 = lst[1]

      JS.global[:testResult] = (val_a == 1 && val_c == 3 && val_1 == 2)
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("converts Ruby Hash/Array/Symbol into Python-consumable values", () => {
    vm.eval(`
      require "pycall"

      payload = { key: [1, :two, true, nil] }
      converted = PyCall.ruby_to_js(payload)
      arr = converted["key"]
      JS.global[:dictValue] = (
        converted.is_a?(JS::Object) &&
        arr.is_a?(JS::Object) &&
        arr[1] == "two"
      )
    `);

    assert.equal(globalThis.dictValue, true);
  });

  it("creates callable JS function from Ruby Proc", () => {
    vm.eval(`
      require "pycall"

      callback = proc { |x| x * 2 }
      js_fn = PyCall.ruby_to_js(callback)
      JS.global[:testResult] = js_fn.is_a?(JS::Object) && js_fn.typeof == 'function'
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("calls callable attributes without shifting arguments", () => {
    vm.eval(`
      require "pycall"

      holder_class = PyCall.wrap(PyCall.pyodide[:globals].call(:get, "CallableHolder"))
      holder = holder_class.new
      result = holder.fn(2, 5)

      JS.global[:testResult] = (result == 7)
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("reports expected error for dotted pyimport without alias", () => {
    vm.eval(`
      require "pycall/import"

      begin
        module ImportErrorCase
          include PyCall::Import
          pyimport "xml.etree"
        end
      rescue => e
        JS.global[:testResult] = e.message.include?("not a valid module variable name")
      end
    `);

    assert.equal(globalThis.testResult, true);
  });
});
