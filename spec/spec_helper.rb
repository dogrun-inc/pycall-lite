# frozen_string_literal: true

require "json"
require "open3"

module WasmPycallRunner
  module_function

  def run_ruby(code)
    js = <<~JS
      import fs from "node:fs/promises";
      import path from "node:path";
      import { loadPyodide } from "pyodide";
      import { DefaultRubyVM } from "@ruby/wasm-wasi/dist/node";

      const userCode = #{JSON.generate(code)};

      async function main() {
        const pyodide = await loadPyodide();
        const wasmPath = path.resolve("node_modules/@ruby/3.3-wasm-wasi/dist/ruby+stdlib.wasm");
        const binary = await fs.readFile(wasmPath);
        const wasmModule = await WebAssembly.compile(binary);
        const { vm } = await DefaultRubyVM(wasmModule);

        globalThis.__pycall_pyodides__ = new Map();
        globalThis.__pycall_make_callback__ = function(rubyProc) {
          return function(...args) {
            return rubyProc.call(...args);
          };
        };

        const vmId = "rspec-" + Math.random().toString(36).slice(2);
        globalThis.__pycall_pyodides__.set(vmId, pyodide);

        const pycallRb = await fs.readFile("lib/pycall.rb", "utf8");
        const importRb = await fs.readFile("lib/pycall/import.rb", "utf8");

        vm.eval(pycallRb);
        vm.eval(`
          unless $LOADED_FEATURES.include?("pycall.rb")
            $LOADED_FEATURES << "pycall"
            $LOADED_FEATURES << "pycall.rb"
          end
        `);
        vm.eval(importRb);
        vm.eval(`
          PyCall.init_vm_id("${vmId}")
          unless $LOADED_FEATURES.include?("pycall/import.rb")
            $LOADED_FEATURES << "pycall/import"
            $LOADED_FEATURES << "pycall/import.rb"
          end
        `);

        await pyodide.runPythonAsync(`
class Box:
    def __init__(self):
        self.value = 42

def echo(v):
    return v
`);

        vm.eval(userCode);

        const out = globalThis.__rspec_result__;
        console.log(JSON.stringify({ ok: true, out }));
        process.exit(0);
      }

      main().catch((err) => {
        console.error(err && err.stack ? err.stack : String(err));
        console.log(JSON.stringify({ ok: false, error: String(err) }));
        process.exit(1);
      });
    JS

    stdout, stderr, status = Open3.capture3("node", "--input-type=module", "--eval", js)
    last_line = stdout.lines.map(&:strip).reject(&:empty?).last

    begin
      parsed = JSON.parse(last_line || "{}")
    rescue JSON::ParserError
      raise "Failed to parse runner output.\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    end

    unless status.success? && parsed["ok"] == true
      raise "Runner failed.\nParsed: #{parsed.inspect}\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
    end

    parsed["out"]
  end
end
