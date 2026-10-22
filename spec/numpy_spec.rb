# frozen_string_literal: true

require "spec_helper"
require "numpy"

RSpec.describe Numpy do
  it "exposes a version and wraps asarray results" do
    expect(Numpy::VERSION).to be_a(String)
    expect(Numpy::VERSION).not_to be_empty
    expect(Numpy.asarray([1])).to be_a(Numpy::NDArray)
  end

  {
    "integer" => [1, Integer],
    "float" => [1.3, Float],
    "complex" => [Complex(1.3, 1), Complex],
    "true" => [true, TrueClass],
    "false" => [false, FalseClass]
  }.each do |label, (value, ruby_class)|
    it "converts #{label} scalars through indexing and asscalar" do
      array = Numpy.asarray([value])

      expect(array[0]).to be_a(ruby_class)
      expect(array[0]).to eq(value)
      expect(Numpy.asscalar(array)).to be_a(ruby_class)
      expect(Numpy.asscalar(array)).to eq(value)
    end
  end

  it "computes the default mean as a Float" do
    result = Numpy.mean(Numpy.asarray([0.0]))

    expect(result).to be_a(Float)
    expect(result).to eq(0.0)
  end

  { int32: [0, Integer], complex128: [Complex(0, 0), Complex] }.each do |dtype, (value, ruby_class)|
    it "forwards the #{dtype} dtype keyword to mean" do
      result = Numpy.mean(Numpy.asarray([0.0]), dtype: dtype)

      expect(result).to be_a(ruby_class)
      expect(result).to eq(value)
    end
  end

  { int64: Integer, float64: Float, float32: Float }.each do |dtype, ruby_class|
    it "preserves #{dtype} scalar types when indexing" do
      result = Numpy.asarray([1, 2, 3], dtype: dtype)[0]

      expect(result).to be_a(ruby_class)
      expect(result).to eq(1)
    end
  end

  it "preserves every index and its order in multidimensional scalar access" do
    array = Numpy.asarray([[1, 2], [3, 4]])

    expect(array[1, 0]).to eq(3)
    expect(array[0, 1]).to eq(2)
    expect(array[-1, -1]).to eq(4)
  end

  it "preserves Float scalars in multidimensional indexing" do
    array = Numpy.asarray([[1, 2], [3, 4]], dtype: :float32)

    expect(array[1, 0]).to be_a(Float)
    expect(array[1, 0]).to eq(3.0)
  end

  it "wraps array views returned by partial multidimensional indexing" do
    array = Numpy.asarray([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
    result = array[1, 0]

    expect(result).to be_a(Numpy::NDArray)
    expect(result.to_a).to eq([5, 6])
  end

  it "converts out-of-bounds multidimensional index errors to PythonError" do
    array = Numpy.asarray([[1, 2], [3, 4]])

    expect { array[9, 0] }.to raise_error(PyCall::PythonError, /IndexError/)
  end

  it "converts excessive multidimensional index errors to PythonError" do
    array = Numpy.asarray([[1, 2], [3, 4]])

    expect { array[0, 0, 0] }.to raise_error(PyCall::PythonError, /IndexError/)
  end

  [
    [1, 2, 3, 4, 5],
    [[1, 2, 3], [4, 5, 6]],
    [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]
  ].each_with_index do |values, dimension|
    it "converts a #{dimension + 1}-dimensional ndarray to nested Ruby arrays" do
      result = Numpy.asarray(values).to_a

      expect(result).to be_a(Array)
      expect(result).to eq(values)
    end
  end

  it "accepts the Python float32 dtype object" do
    array = Numpy.asarray([1, 2, 3], dtype: Numpy.float32)

    expect(array.dtype.to_s).to eq("float32")
    expect(array[0]).to be_a(Float)
  end

  it "reports the unavailable native numo/narray dependency" do
    expect do
      Numpy.asarray([1, 2, 3]).to_narray
    end.to raise_error(RuntimeError, /Unable to load numo\/narray/)
  end
end
