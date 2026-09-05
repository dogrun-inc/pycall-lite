require 'pycall'

module Numpy
  Backend = PyCall.import_module('numpy')

  VERSION =
    begin
      Backend.__version__
    rescue StandardError
      nil
    end

  class << self
    def asscalar(array)
      array.item.call
    end

    def mean(*args)
      positional, kwargs = PyCall.split_kwargs(args)
      result = kwargs ? Backend.mean(*positional, kwargs) : Backend.mean(*args)
      kwargs && kwargs.key?(:dtype) ? result : result.to_f
    end

    def method_missing(name, *args, &block)
      Backend.__send__(name, *args, &block)
    end

    def respond_to_missing?(name, include_private = false)
      Backend.respond_to?(name, include_private) || super
    end
  end
end

require 'numpy/ndarray'
