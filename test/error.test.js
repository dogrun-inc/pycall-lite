import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import fs from "node:fs/promises";
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

describe("pycall-lite error handling", () => {
  let pyodide;
  let vm;

  beforeEach(async () => {
    pyodide = await loadPyodide();

    const module = await getRubyModule();
    const runtime = await DefaultRubyVM(module);
    vm = runtime.vm;

    setupPyCall(vm, pyodide);

    await pyodide.runPythonAsync(`
  def raise_value_error():
    raise ValueError("from call")

  class RaisingIndex:
    def __getitem__(self, key):
      raise ValueError("from index")
  `);
  });

  afterEach(() => {
    delete globalThis.testResult;
  });

  it("wraps a Python-origin error into PyCall::PythonError with type/value/traceback", () => {
    vm.eval(`
      require "pycall"

      math = PyCall.import_module(:math)

      begin
        math.sqrt(-1)
        JS.global[:testResult] = false
      rescue => raw_error
        wrapped = PyCall.wrap_error(raw_error)

        JS.global[:testResult] = (
          wrapped.is_a?(PyCall::PythonError) &&
          !wrapped.type.nil? &&
          !wrapped.value.nil? &&
          !wrapped.traceback.nil? &&
          wrapped.message.include?("ValueError") &&
          wrapped.original_error.is_a?(JS::Error)
        )
      end
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("captures the exact sys.last_value instance, not a copy", () => {
    vm.eval(`
      require "pycall"

      math = PyCall.import_module(:math)

      begin
        math.sqrt(-1)
        JS.global[:testResult] = false
      rescue => raw_error
        wrapped = PyCall.wrap_error(raw_error)

        is_same_object = PyCall.wrap(
          PyCall.pyodide.call(:runPython, "lambda v: v is __import__('sys').last_value")
        )

        JS.global[:testResult] = is_same_object.call(wrapped.value)
      end
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("leaves non-Python-origin errors unchanged", () => {
    vm.eval(`
      require "pycall"

      begin
        raise "boom"
      rescue => raw_error
        wrapped = PyCall.wrap_error(raw_error)

        JS.global[:testResult] = wrapped.equal?(raw_error) && !wrapped.is_a?(PyCall::PythonError)
      end
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("returns nil from capture_last_python_error when nothing was raised yet", () => {
    vm.eval(`
      require "pycall"

      JS.global[:testResult] = PyCall.capture_last_python_error.nil?
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("detects Python-origin errors via python_error? and unwraps the JS error", () => {
    vm.eval(`
      require "pycall"

      math = PyCall.import_module(:math)

      begin
        math.sqrt(-1)
        JS.global[:testResult] = false
      rescue => raw_error
        js_error = PyCall.unwrap_js_error(raw_error.original_error)

        JS.global[:testResult] = (
          PyCall.python_error?(raw_error) &&
          js_error.is_a?(JS::Object) &&
          !PyCall.python_error?(RuntimeError.new("not a python error"))
        )
      end
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("automatically wraps errors raised while importing a Python module", () => {
    vm.eval(`
      require "pycall"

      begin
        PyCall.import_module("module_that_does_not_exist")
        JS.global[:testResult] = false
      rescue => error
        JS.global[:testResult] = error.is_a?(PyCall::PythonError)
      end
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("automatically wraps errors raised by PyObject#call", () => {
    vm.eval(`
      require "pycall"

      raiser = PyCall.wrap(PyCall.pyodide[:globals].call(:get, "raise_value_error"))

      begin
        raiser.call
        JS.global[:testResult] = false
      rescue => error
        JS.global[:testResult] = error.is_a?(PyCall::PythonError)
      end
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("automatically wraps errors raised by dynamic method calls", () => {
    vm.eval(`
      require "pycall"

      math = PyCall.import_module(:math)

      begin
        math.sqrt(-1)
        JS.global[:testResult] = false
      rescue => error
        JS.global[:testResult] = error.is_a?(PyCall::PythonError)
      end
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("automatically wraps errors raised by Python object index access", () => {
    vm.eval(`
      require "pycall"

      klass = PyCall.wrap(PyCall.pyodide[:globals].call(:get, "RaisingIndex"))
      values = klass.new

      begin
        values["key"]
        JS.global[:testResult] = false
      rescue => error
        JS.global[:testResult] = error.is_a?(PyCall::PythonError)
      end
    `);

    assert.equal(globalThis.testResult, true);
  });
});
