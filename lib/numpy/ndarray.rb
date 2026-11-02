module Numpy
  # Wraps Python numpy.ndarray objects and provides Ruby scalar and Array conversions.
  class NDArray < PyCall::PyObject
    # Reads elements or views, preserving Float scalars for float dtypes.
    # @param index [Array<Object>] indices; multiple indices form a Python tuple
    # @return [Object, Numpy::NDArray] converted scalar or wrapped array view
    def [](*index)
      value = PyCall.with_error_handling do
        getitem = PyCall.pyodide.call(:runPython, 'lambda array, *items: array[items[0] if len(items) == 1 else tuple(items)]')
        PyCall.wrap(getitem.call(:call, nil, @__js_obj__, *index.map { |i| PyCall.ruby_to_js(i) }))
      end

      value.is_a?(Integer) && float_dtype? ? value.to_f : value
    end

    # Converts via NumPy tolist: zero-dimensional arrays return a scalar, not an Array.
    # @return [Object] Ruby scalar for zero-dimensional arrays, nested Arrays otherwise
    def to_a
      list = tolist.call
      return js_to_ruby(list) if ndim == 0

      js_value = list.__js_obj__.call(:toJs)
      js_to_ruby(js_value)
    end

    # Converts via Numo::NArray, whose native extension is not bundled with pycall-lite.
    # @return [Numo::NArray] converted array
    # @raise [RuntimeError] if numo/narray cannot be loaded
    def to_narray
      begin
        require 'numo/narray'
      rescue LoadError
        raise RuntimeError,
              'Unable to load numo/narray library; please do gem install numo-narray before use to_narray method'
      end

      Numo::NArray[*to_a]
    end

    private

    # Tests the dtype kind, returning false if it cannot be read.
    # @return [Boolean] whether the dtype is floating-point
    def float_dtype?
      dtype.kind == 'f'
    rescue StandardError
      false
    end

    # Recursively converts JavaScript Arrays and wraps other values.
    # @param value [Object] JavaScript value to convert
    # @param floating [Boolean] whether to preserve floating-point numeric leaves
    # @return [Object, Array] converted Ruby value
    def js_to_ruby(value, floating: float_dtype?)
      if value.is_a?(JS::Object) && JS.global[:Array].call(:isArray, value) == true
        length = value[:length].to_i
        Array.new(length) { |i| js_to_ruby(value[i], floating: floating) }
      else
        result = PyCall.wrap(value)
        result.is_a?(Integer) && floating ? result.to_f : result
      end
    end
  end
end

PyCall.register_python_type_mapping('numpy.ndarray', Numpy::NDArray)
