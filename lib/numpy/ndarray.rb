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

    # Converts via NumPy tolist, preserving the array's dimensions.
    # @return [Array] nested Ruby arrays for nonzero-dimensional arrays
    def to_a
      list = tolist.call
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

    # Tests the dtype name, returning false if it cannot be read.
    # @return [Boolean] whether the dtype name starts with float
    def float_dtype?
      dtype.to_s.start_with?('float')
    rescue StandardError
      false
    end

    # Recursively converts JavaScript Arrays and wraps other values.
    # @param value [Object] JavaScript value to convert
    # @return [Object, Array] converted Ruby value
    def js_to_ruby(value)
      return PyCall.wrap(value) unless value.is_a?(JS::Object)

      if JS.global[:Array].call(:isArray, value) == true
        length = value[:length].to_i
        Array.new(length) { |i| js_to_ruby(value[i]) }
      else
        PyCall.wrap(value)
      end
    end
  end
end

PyCall.register_python_type_mapping('numpy.ndarray', Numpy::NDArray)
