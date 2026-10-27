require 'pycall'

# Ruby interface to Python NumPy; load the Pyodide numpy package before requiring this file.
module Numpy
  # Underlying Python numpy module.
  # @return [PyCall::PyObject]
  Backend = PyCall.import_module('numpy')

  # Python NumPy version, or nil if unavailable.
  # @return [String, nil]
  VERSION =
    begin
      Backend.__version__
    rescue StandardError
      nil
    end

  class << self
    # Returns the single element via NumPy's item method, preserving floating dtypes.
    # @param array [Numpy::NDArray] single-element array
    # @return [Object] converted Ruby scalar
    # @raise [PyCall::PythonError] if the array does not contain exactly one element
    def asscalar(array)
      value = array.item.call
      value.is_a?(Integer) && array.dtype.kind == 'f' ? value.to_f : value
    end

    # Delegates to NumPy mean, preserving arrays and complex values and normalizing real scalars.
    # @param args [Array<Object>] positional arguments
    # @param kwargs [Hash] keyword arguments forwarded to NumPy
    # @return [Object] wrapped NumPy result with real scalar types matching dtype
    def mean(*args, **kwargs)
      result = Backend.mean(*args, **kwargs)
      return result unless result.is_a?(Integer) || result.is_a?(Float)

      dtype = kwargs.fetch(:dtype) { kwargs.fetch('dtype', args[2]) }
      dtype.nil? || Backend.dtype(dtype).kind == 'f' ? result.to_f : result
    end

    # Delegates calls and dtype attribute access to {Backend}.
    # @param name [Symbol] Python attribute or method name
    # @param args [Array<Object>] arguments forwarded to Backend
    # @param block [Proc, nil] block forwarded to Backend
    # @return [Object] wrapped Python result
    def method_missing(name, *args, **kwargs, &block)
      Backend.__send__(name, *args, **kwargs, &block)
    end

    # Reports whether {Backend} responds to the requested name.
    # @param name [Symbol, String] method name
    # @param include_private [Boolean] whether to include private methods
    # @return [Boolean]
    def respond_to_missing?(name, include_private = false)
      Backend.respond_to?(name, include_private) || super
    end
  end
end

require 'numpy/ndarray'
