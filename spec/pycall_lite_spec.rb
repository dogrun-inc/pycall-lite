# frozen_string_literal: true

require "spec_helper"

RSpec.describe "pycall-lite (Ruby viewpoint)" do
  ['nan', 'inf', '-inf'].each do |text|
    it "preserves Python float #{text} as Ruby Float" do
      result = PyCall.import_module(:builtins).float(text)

      expect(result).to be_a(Float)
      if text == 'nan'
        expect(result.nan?).to eq(true)
      else
        expect(result.infinite?).to eq(text == 'inf' ? 1 : -1)
      end
    end
  end

  [0, 42, -42, 2**31, 9007199254740991, -9007199254740991,
   9007199254740992, 9007199254740993, -9007199254740993, 2**100, -(2**100)].each do |value|
    it "passes Ruby integer #{value} to Python without precision loss" do
      builtins = PyCall.import_module(:builtins)
      main = PyCall.import_module(:__main__)
      js_value = PyCall.ruby_to_js(value)

      expect(js_value.typeof).to eq(value.abs <= 9007199254740991 ? 'number' : 'bigint')
      expect(builtins.str(value)).to eq(value.to_s)
      expect(main.echo(value)).to eq(value)
      expect(main.echo.call(value)).to eq(value)
      expect(main.keyword_probe(offset: value)).to eq(value)
    end
  end

  it "preserves large integers nested inside arrays and Hashes" do
    value = 2**100 + 1
    inspect_values = PyCall.wrap(PyCall.pyodide.call(:runPython,
      'lambda payload: str(payload.values[0]) + ":" + str(payload.values[1])'))

    expect(inspect_values.call({values: [value, -value]})).to eq("#{value}:#{-value}")
  end

  [9007199254740991, 9007199254740992, 9007199254740993,
   -9007199254740993, 2**100, -(2**100)].each do |value|
    it "converts Python integer #{value} to Ruby Integer without precision loss" do
      result = PyCall.import_module(:builtins).int(value.to_s)

      expect(result).to be_a(Integer)
      expect(result).to eq(value)
    end
  end

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
