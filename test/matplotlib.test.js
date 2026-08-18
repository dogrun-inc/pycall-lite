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

describe("pycall-lite matplotlib add-on", () => {
  let pyodide;
  let vm;

  beforeEach(async () => {
    pyodide = await loadPyodide();

    const module = await getRubyModule();
    const runtime = await DefaultRubyVM(module);
    vm = runtime.vm;

    setupPyCall(vm, pyodide);

    // Stub `matplotlib` / `matplotlib.pyplot` so tests run fully offline
    // (no network access needed to fetch the real wheels).
    await pyodide.runPythonAsync(`
import sys
import types

matplotlib_stub = types.ModuleType("matplotlib")
matplotlib_stub.__version__ = "0.0.0-stub"

def use(backend):
    matplotlib_stub.backend = backend

def get_backend():
    return getattr(matplotlib_stub, "backend", "stub")

matplotlib_stub.use = use
matplotlib_stub.get_backend = get_backend
sys.modules["matplotlib"] = matplotlib_stub

pyplot_stub = types.ModuleType("matplotlib.pyplot")

def plot(*args, **kwargs):
    pyplot_stub.last_plot_args = args
    pyplot_stub.last_plot_kwargs = kwargs

def title(text, **kwargs):
    pyplot_stub.last_title = text
    pyplot_stub.last_title_kwargs = kwargs

class _XkcdContext:
    def __enter__(self):
        pyplot_stub.xkcd_active = True
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        pyplot_stub.xkcd_active = False
        return False

def xkcd(scale=1, length=100, randomness=2):
    return _XkcdContext()

pyplot_stub.plot = plot
pyplot_stub.title = title
pyplot_stub.xkcd = xkcd
pyplot_stub.xkcd_active = False
sys.modules["matplotlib.pyplot"] = pyplot_stub
    `);
  });

  afterEach(() => {
    delete globalThis.testResult;
  });

  it("delegates Matplotlib module calls to the underlying Python module", () => {
    vm.eval(`
      require "matplotlib"

      Matplotlib.use("Agg")
      # Zero-arg Python calls are treated as attribute access by pycall-lite
      # (see README "Key differences"), so force invocation via #invoke.
      backend_ok = (Matplotlib.invoke(:get_backend) == "Agg")
      version_ok = (Matplotlib::VERSION == "0.0.0-stub")

      JS.global[:testResult] = (backend_ok && version_ok)
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("supports Matplotlib::Pyplot calls with keyword arguments", () => {
    vm.eval(`
      require "matplotlib/pyplot"

      plt = Matplotlib::Pyplot
      plt.plot([1, 2, 3], [4, 5, 6])
      plt.title("hello", fontsize: 14)

      JS.global[:testResult] = (plt.last_title == "hello")
    `);

    assert.equal(globalThis.testResult, true);
  });

  it("supports Matplotlib::Pyplot.xkcd as a context manager block", () => {
    vm.eval(`
      require "matplotlib/pyplot"

      plt = Matplotlib::Pyplot
      active_inside = nil
      plt.xkcd { active_inside = plt.xkcd_active }
      active_after = plt.xkcd_active

      JS.global[:testResult] = (active_inside == true && active_after == false)
    `);

    assert.equal(globalThis.testResult, true);
  });
});
