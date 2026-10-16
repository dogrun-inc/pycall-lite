# frozen_string_literal: true

require "spec_helper"

RSpec.describe "pycall-lite (Ruby viewpoint)" do
  it "imports module and calls Python function" do
    math = PyCall.import_module(:math)

    expect(math.sin(math.pi / 2)).to eq(1)
  end

  it "supports attribute get/set on Python objects" do
    box_class = PyCall.wrap(PyCall.pyodide[:globals].call(:get, "Box"))
    box = box_class.new

    expect(box.value).to eq(42)

    box.value = 100
    expect(box.value).to eq(100)
  end

  it "supports index access for list/dict and converts bool/nil" do
    json = PyCall.import_module(:json)
    array = json.loads("[1, 2, 3]")
    hash = json.loads('{"a": true, "b": null}')

    expect(array[1]).to eq(2)
    expect(hash["a"]).to eq(true)
    expect(hash["b"]).to be_nil
  end

  it "supports pyimport and pyfrom macros" do
    stub_const("SpecImport", Module.new do
      include PyCall::Import
      pyimport :math
      pyfrom :math, import: [:cos, [:sin, :sin_alias]]
    end)

    expect(SpecImport.math.sin(0)).to eq(0)
    expect(SpecImport.cos(0)).to eq(1)
    expect(SpecImport.sin_alias(0)).to eq(0)
  end

  it "wraps Proc into callable JS function via ruby_to_js" do
    callback = proc { |value| value * 2 }
    js_function = PyCall.ruby_to_js(callback)

    expect(js_function.is_a?(JS::Object)).to eq(true)
    expect(js_function.typeof).to eq("function")
  end

  it "raises for dotted pyimport names without alias" do
    expect do
      Module.new do
        include PyCall::Import
        pyimport "xml.etree"
      end
    end.to raise_error(ArgumentError, /not a valid module variable name/)
  end
end
