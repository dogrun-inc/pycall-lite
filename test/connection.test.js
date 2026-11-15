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

describe("Ruby.wasm + Pyodide bootstrap", () => {
  let vm;
  let pyodide;

  beforeEach(async () => {
    pyodide = await loadPyodide();

    const module = await getRubyModule();
    const runtime = await DefaultRubyVM(module);
    vm = runtime.vm;

    setupPyCall(vm, pyodide);
  });

  afterEach(() => {
    delete globalThis.bootstrapResult;
  });

  it("initializes pycall-lite bridge and executes Python through imported module", () => {
    vm.eval(`
      require "pycall"
      math = PyCall.import_module(:math)
      JS.global[:bootstrapResult] = math.sin(math.pi / 2)
    `);

    assert.equal(globalThis.bootstrapResult, 1);
  });

  it("rejects switching interpreters without changing the original connection", async () => {
    const anotherPyodide = await loadPyodide();
    await pyodide.loadPackage("numpy");
    await anotherPyodide.loadPackage("numpy");
    pyodide.runPython("import numpy; numpy.connection_marker = 11");
    anotherPyodide.runPython("import numpy; numpy.connection_marker = 22");
    const readConnection = (rubyVM) => {
      rubyVM.eval(`
        require "numpy"
        array = Numpy.asarray([1, 2])
        JS.global[:bootstrapResult] = Numpy.connection_marker + array[0]
      `);
      return globalThis.bootstrapResult;
    };

    assert.equal(readConnection(vm), 12);
    const connectionCount = globalThis.__pycall_pyodides__.size;
    assert.throws(() => setupPyCall(vm, anotherPyodide), /already connected to a different Pyodide instance/);
    assert.equal(globalThis.__pycall_pyodides__.size, connectionCount);
    assert.equal(readConnection(vm), 12);

    setupPyCall(vm, pyodide);
    assert.equal(readConnection(vm), 12);

    const { vm: anotherVM } = await DefaultRubyVM(await getRubyModule());
    setupPyCall(anotherVM, anotherPyodide);
    assert.equal(readConnection(anotherVM), 23);
    assert.equal(readConnection(vm), 12);
  });

  it("registers callback factory required by Proc-to-JS conversion", () => {
    assert.equal(typeof globalThis.__pycall_make_callback__, "function");

    vm.eval(`
      require "pycall"
      js_fn = PyCall.ruby_to_js(proc { |x| x * 2 })
      JS.global[:bootstrapResult] = js_fn.typeof == 'function'
    `);

    assert.equal(globalThis.bootstrapResult, true);
  });
});
