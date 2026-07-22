# frozen_string_literal: true

require "spec_helper"

RSpec.describe "pycall-lite (Ruby viewpoint)" do
  it "imports module and calls Python function" do
    out = WasmPycallRunner.run_ruby(<<~RUBY)
      require "pycall"
      math = PyCall.import_module(:math)
      JS.global[:__rspec_result__] = (math.sin(math.pi / 2) == 1)
    RUBY

    expect(out).to eq(true)
  end

  it "supports attribute get/set on Python objects" do
    out = WasmPycallRunner.run_ruby(<<~RUBY)
      require "pycall"
      box_class = PyCall.wrap(PyCall.pyodide[:globals].call(:get, "Box"))
      box = box_class.new
      before = box.value
      box.value = 100
      after = box.value
      JS.global[:__rspec_result__] = (before == 42 && after == 100)
    RUBY

    expect(out).to eq(true)
  end

  it "supports index access for list/dict and converts bool/nil" do
    out = WasmPycallRunner.run_ruby(<<~RUBY)
      require "pycall"
      json = PyCall.import_module(:json)
      arr = json.loads("[1, 2, 3]")
      h = json.loads('{"a": true, "b": null}')
      JS.global[:__rspec_result__] = (arr[1] == 2 && h["a"] == true && h["b"] == nil)
    RUBY

    expect(out).to eq(true)
  end

  it "supports pyimport and pyfrom macros" do
    out = WasmPycallRunner.run_ruby(<<~RUBY)
      require "pycall/import"

      module SpecImport
        include PyCall::Import
        pyimport :math
        pyfrom :math, import: [:cos, [:sin, :sin_alias]]
      end

      JS.global[:__rspec_result__] = (
        SpecImport.math.sin(0) == 0 &&
        SpecImport.cos(0) == 1 &&
        SpecImport.sin_alias(0) == 0
      )
    RUBY

    expect(out).to eq(true)
  end

  it "wraps Proc into callable JS function via ruby_to_js" do
    out = WasmPycallRunner.run_ruby(<<~RUBY)
      require "pycall"
      cb = proc { |x| x * 2 }
      js_fn = PyCall.ruby_to_js(cb)
      JS.global[:__rspec_result__] = (js_fn.is_a?(JS::Object) && js_fn.typeof == "function")
    RUBY

    expect(out).to eq(true)
  end

  it "raises for dotted pyimport names without alias" do
    out = WasmPycallRunner.run_ruby(<<~RUBY)
      require "pycall/import"
      begin
        module BadImport
          include PyCall::Import
          pyimport "xml.etree"
        end
        JS.global[:__rspec_result__] = false
      rescue => e
        JS.global[:__rspec_result__] = e.message.include?("not a valid module variable name")
      end
    RUBY

    expect(out).to eq(true)
  end
end
