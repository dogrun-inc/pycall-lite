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
    # Returns the single element via NumPy's item method.
    # @param array [Numpy::NDArray] single-element array
    # @return [Object] converted Ruby scalar
    # @raise [PyCall::PythonError] if the array does not contain exactly one element
    def asscalar(array)
      array.item.call
    end

    # Delegates to NumPy mean, converting the result to Float unless dtype is supplied.
    # @param args [Array<Object>] positional arguments and an optional trailing keyword Hash
    # @return [Object] wrapped NumPy result, or Float when dtype is omitted
    def mean(*args)
      positional, kwargs = PyCall.split_kwargs(args)
      result = kwargs ? Backend.mean(*positional, kwargs) : Backend.mean(*args)
      kwargs && kwargs.key?(:dtype) ? result : result.to_f
    end

    # Delegates calls and dtype attribute access to {Backend}.
    # @param name [Symbol] Python attribute or method name
    # @param args [Array<Object>] arguments forwarded to Backend
    # @param block [Proc, nil] block forwarded to Backend
    # @return [Object] wrapped Python result
    def method_missing(name, *args, &block)
      Backend.__send__(name, *args, &block)
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
