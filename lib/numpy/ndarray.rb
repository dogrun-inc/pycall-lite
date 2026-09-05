module Numpy
  class NDArray < PyCall::PyObject
    def [](*index)
      value = if index.length == 1
                super(index[0])
              else
                tuple = PyCall.pyodide.call(:runPython, 'lambda *items: tuple(items)')
                PyCall.wrap(@__js_obj__.call(:get, tuple.call(:call, *index.map { |i| PyCall.ruby_to_js(i) })))
              end

      value.is_a?(Integer) && float_dtype? ? value.to_f : value
    end

    def to_a
      list = tolist.call
      js_value = list.__js_obj__.call(:toJs)
      js_to_ruby(js_value)
    end

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

    def float_dtype?
      dtype.to_s.start_with?('float')
    rescue StandardError
      false
    end

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
