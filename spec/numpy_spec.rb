# frozen_string_literal: true

require "spec_helper"
require "numpy"

RSpec.describe Numpy do
  [ [1], [1, 2] ].each do |values|
    it "preserves a masked array with #{values.length} elements" do
      array = Numpy.ma.array(values)

      expect(array).to be_a(PyCall::PyObject)
      expect(PyCall.import_module(:builtins).isinstance(array, Numpy.ma.MaskedArray)).to eq(true)
      expect(array.size).to eq(values.length)
      expect(array[0]).to eq(1)
    end
  end

  it "preserves masked elements when wrapping masked arrays" do
    array = Numpy.ma.array([1, 2], mask: [false, true])

    expect(array).to be_a(PyCall::PyObject)
    expect(array.count.call).to eq(1)
    expect(array.mask[0]).to eq(false)
    expect(array.mask[1]).to eq(true)
    expect(array[0]).to eq(1)
  end

  {int32: Integer, float32: Float, complex64: Complex}.each do |dtype, klass|
    it "converts a user-defined subclass of numpy.#{dtype}" do
      scalar = PyCall.pyodide.call(:runPython, "type('CustomScalar', (__import__('numpy').#{dtype},), {'__module__': 'custom_scalars'})(2)")
      result = PyCall.wrap(scalar)

      expect(result).to be_a(klass)
      expect(result).to eq(2)
    end
  end

  it "preserves array results from axis reductions" do
    result = Numpy.mean(Numpy.asarray([[1, 2], [3, 4]]), axis: 0)

    expect(result).to be_a(Numpy::NDArray)
    expect(result.to_a).to eq([2, 3])
    expect(result.dtype.kind).to eq('f')
  end

  it "preserves complex means with a nonzero imaginary part" do
    result = Numpy.mean(Numpy.asarray([Complex(1, 2), Complex(3, 4)]))

    expect(result).to be_a(Complex)
    expect(result).to eq(Complex(2, 3))
  end

  [:float32, :float64, :int32, :complex128].each do |dtype|
    it "honors #{dtype} through symbol, string, and positional dtype arguments" do
      array = Numpy.asarray([1, 3])
      results = [
        Numpy.mean(array, dtype: dtype),
        Numpy.mean(array, **{'dtype' => dtype}),
        Numpy.mean(array, 0, dtype)
      ]
      klass = {float32: Float, float64: Float, int32: Integer, complex128: Complex}.fetch(dtype)

      results.each do |result|
        expect(result).to be_a(klass)
        expect(result).to eq(2)
      end
    end
  end

  it "accepts a floating dtype object" do
    array = Numpy.asarray([1, 3])

    expect(Numpy.mean(array, dtype: Numpy.float64)).to be_a(Float)
  end

  [:float16, :float32, :float64].each do |dtype|
    it "preserves #{dtype} values as Float through asscalar" do
      [0.0, 1.0, -2.0, 1.5].each do |value|
        [value, [value], [[value]]].each do |values|
          result = Numpy.asscalar(Numpy.asarray(values, dtype: dtype))

          expect(result).to be_a(Float)
          expect(result).to eq(value)
        end
      end
    end
  end

  it "preserves the inferred floating dtype through asscalar" do
    array = Numpy.asarray([1.5])

    expect(array.dtype.kind).to eq('f')
    expect(Numpy.asscalar(array)).to be_a(Float)
    expect(Numpy.asscalar(array)).to eq(1.5)
  end

  [[], [1.0, 2.0]].each do |values|
    it "rejects asscalar input with #{values.length} elements" do
      expect do
        Numpy.asscalar(Numpy.asarray(values))
      end.to raise_error(PyCall::PythonError, /ValueError/)
    end
  end

  # These scalar types reach wrap as PyProxy objects; float64 is converted by Pyodide first.
  [:float16, :float32].each do |dtype|
    [0, 2, -2, 1.5].each do |value|
      it "preserves #{dtype} scalar #{value} as Float" do
        result = Numpy.__send__(dtype).call(value)

        expect(result).to be_a(Float)
        expect(result).to eq(value.to_f)
      end
    end
  end

  {int32: Integer, int64: Integer, bool_: TrueClass, complex64: Complex}.each do |dtype, klass|
    it "preserves non-floating #{dtype} scalar types" do
      result = Numpy.__send__(dtype).call(2)

      expect(result).to be_a(klass)
      expect(result).to eq(dtype == :bool_ ? true : 2)
    end
  end

  it "forwards keyword-only calls through NumPy delegation" do
    expect(Numpy.zeros(shape: [2]).to_a).to eq([0, 0])
  end

  it "preserves positional Hash values alongside NumPy keywords" do
    array = Numpy.full([2], {key: 3}, dtype: :object)

    expect(array[0][:key].to_i).to eq(3)
  end

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

  it "reads single indices at both ends with positive and negative indices" do
    array = Numpy.asarray([1, 2])

    expect(array[0]).to eq(1)
    expect(array[1]).to eq(2)
    expect(array[-1]).to eq(2)
    expect(array[-2]).to eq(1)
  end

  [2, 9, -3].each do |index|
    it "converts out-of-bounds single index #{index} to PythonError" do
      array = Numpy.asarray([1, 2])

      expect { array[index] }.to raise_error(PyCall::PythonError, /IndexError/)
    end
  end

  it "converts indexing an empty array to PythonError" do
    expect { Numpy.asarray([])[0] }.to raise_error(PyCall::PythonError, /IndexError/)
  end

  it "preserves array views from single-index access" do
    result = Numpy.asarray([[1, 2], [3, 4]])[-1]

    expect(result).to be_a(Numpy::NDArray)
    expect(result.to_a).to eq([3, 4])
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
