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

describe("NumPy JavaScript integration", () => {
  let pyodide;
  let vm;

  beforeEach(async () => {
    pyodide = await loadPyodide();
    await pyodide.loadPackage("numpy");
    const runtime = await DefaultRubyVM(await getRubyModule());
    vm = runtime.vm;
    setupPyCall(vm, pyodide);
  });

  afterEach(() => {
    globalThis.numpyArray?.destroy();
    delete globalThis.numpyArray;
    delete globalThis.numpyResult;
  });

  it("loads the embedded add-on lazily and only once with either require spelling", () => {
    vm.eval(`
      raise "NumPy was loaded eagerly" if defined?(Numpy)
      first_load = require "numpy.rb"
      second_load = require "numpy"
      ndarray_load = require "numpy/ndarray"
      JS.global[:numpyResult] = first_load && !second_load && !ndarray_load
    `);

    assert.equal(globalThis.numpyResult, true);
  });

  it("returns a real Python ndarray from the Ruby wrapper to JavaScript", () => {
    vm.eval(`
      require "numpy"
      array = Numpy.asarray([[1, 2], [3, 4]], dtype: Numpy.float32)
      JS.global[:numpyResult] = array.is_a?(Numpy::NDArray)
      JS.global[:numpyArray] = array.__js_obj__
    `);

    assert.equal(globalThis.numpyResult, true);
    const array = globalThis.numpyArray;
    assert.equal(array.type, "numpy.ndarray");
    const dtype = array.dtype;
    const shape = array.shape;
    const list = array.tolist();
    try {
      assert.equal(dtype.toString(), "float32");
      assert.deepEqual(shape.toJs(), [2, 2]);
      assert.deepEqual(list.toJs(), [[1, 2], [3, 4]]);
    } finally {
      dtype.destroy();
      shape.destroy();
      list.destroy();
    }
  });

  it("exposes Ruby numeric results to JavaScript after keyword dispatch", () => {
    vm.eval(`
      require "numpy"
      JS.global[:numpyResult] = Numpy.mean(Numpy.asarray([2, 4, 6]), dtype: :int32)
    `);

    assert.equal(globalThis.numpyResult, 4);
  });

  it("propagates NumPy failures through PyCall::PythonError", () => {
    vm.eval(`
      require "numpy"
      begin
        Numpy.asarray([1], dtype: "not_a_numpy_dtype")
        JS.global[:numpyResult] = false
      rescue PyCall::PythonError => error
        JS.global[:numpyResult] = error.message.include?("TypeError")
      end
    `);

    assert.equal(globalThis.numpyResult, true);
  });
});