# frozen_string_literal: true

require "spec_helper"

RSpec.describe "pycall-lite (Ruby viewpoint)" do
  it "distinguishes positional Hashes from keywords in callable dispatch" do
    main = PyCall.import_module(:__main__)
    probe = main.keyword_probe

    expect(main.echo({key: 1})[:key].to_i).to eq(1)
    expect(main.echo.call({key: 1})[:key].to_i).to eq(1)
    expect(probe.call({key: 3}, offset: 4)).to eq(7)
    expect(probe.call(offset: 4)).to eq(4)
    expect(main.keyword_probe({key: 3}, offset: 4)).to eq(7)
    expect(main.keyword_probe(offset: 4)).to eq(4)
    expect(main.keyword_probe(**{"offset" => 4})).to eq(4)
    expect(main.keyword_probe({key: 3}, **{})).to eq(3)
    expect { probe.call(key: 1) }.to raise_error(PyCall::PythonError, /TypeError/)
  end

  it "preserves positional Hashes and keywords in constructors" do
    klass = PyCall.import_module(:__main__).KeywordBox

    expect(klass.new({key: 3}).value).to eq(3)
    expect(klass.new({key: 3}, offset: 4).value).to eq(7)
    expect(klass.new(offset: 4).value).to eq(4)
  end

  it "preserves positional Hashes and keywords through import helpers" do
    helpers = Module.new do
      include PyCall::Import
      pyfrom :__main__, import: [:keyword_probe]
    end

    expect(helpers.keyword_probe({key: 3})).to eq(3)
    expect(helpers.keyword_probe({key: 3}, offset: 4)).to eq(7)
    expect(helpers.keyword_probe(offset: 4)).to eq(4)
  end

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
