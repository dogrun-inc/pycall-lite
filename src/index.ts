import { pycallRb, errorRb, importRb } from "./ruby_code.js";

// Initialize global pyodides Map
if (!(globalThis as any).__pycall_pyodides__) {
  (globalThis as any).__pycall_pyodides__ = new Map();
}

/**
 * Sets up pycall-lite on the given RubyVM instance, connecting it with the Pyodide instance.
 * @param rubyVM The RubyVM instance from @ruby/wasm-wasi.
 * @param pyodide The Pyodide instance loaded via loadPyodide.
 */
export function setupPyCall(rubyVM: any, pyodide: any): void {
  // Expose isPyProxy helper on pyodide instance if it doesn't exist (e.g. in node environments)
  if (typeof pyodide.isPyProxy === "undefined") {
    pyodide.isPyProxy = (obj: any) => {
      const ffi = pyodide.ffi;
      if (!ffi || typeof ffi.PyProxy !== "function") {
        return false;
      }

      return obj instanceof ffi.PyProxy;
    };
  }

  // 1. Generate a unique VM ID and register it
  const vmId = globalThis.crypto?.randomUUID?.() ?? Math.random().toString(36).substring(2, 15);
  (globalThis as any).__pycall_pyodides__.set(vmId, pyodide);

  // Register a callback factory used by tests and future callback bridging.
  if (typeof (globalThis as any).__pycall_make_callback__ !== "function") {
    (globalThis as any).__pycall_make_callback__ = function (rubyProc: any) {
      return function (...args: any[]) {
        return rubyProc.call(...args);
      };
    };
  }

  // 2. Evaluate the Ruby source code directly to define PyCall modules and classes.
  rubyVM.eval(pycallRb);

  // Mark pycall as loaded before evaluating errorRb/importRb, since both
  // `require "pycall"`.
  rubyVM.eval(`
    unless $LOADED_FEATURES.include?("pycall.rb")
      $LOADED_FEATURES << "pycall"
      $LOADED_FEATURES << "pycall.rb"
    end
  `);

  rubyVM.eval(errorRb);

  rubyVM.eval(`
    unless $LOADED_FEATURES.include?("pycall/error.rb")
      $LOADED_FEATURES << "pycall/error"
      $LOADED_FEATURES << "pycall/error.rb"
    end
  `);

  rubyVM.eval(importRb);

  // 3. Initialize VM ID in Ruby and Fake the require system.
  rubyVM.eval(`
    PyCall.init_vm_id("${vmId}")

    unless $LOADED_FEATURES.include?("pycall/import.rb")
      $LOADED_FEATURES << "pycall/import"
      $LOADED_FEATURES << "pycall/import.rb"
    end
  `);
}
export default setupPyCall;
