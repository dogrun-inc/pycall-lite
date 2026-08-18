require 'pycall'

# Lightweight Ruby bindings for the `matplotlib` Python package, mirroring
# the public API shape of the `matplotlib` gem
# (https://github.com/red-data-tools/matplotlib.rb). Unlike the upstream
# gem, this add-on ships built into pycall-lite because matplotlib is
# already available inside the Pyodide runtime.
module Matplotlib
  # Underlying `matplotlib` Python module.
  Backend = PyCall.import_module('matplotlib')

  class Error < StandardError
  end

  class << self
    # Delegates unknown module-level calls to the underlying Python module
    # (e.g. Matplotlib.use('Agg'), Matplotlib.get_backend).
    def method_missing(name, *args, &block)
      Backend.__send__(name, *args, &block)
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  VERSION =
    begin
      Backend.__version__
    rescue StandardError
      nil
    end

  module Axis
    class XAxis < PyCall::PyObject
    end

    class YAxis < PyCall::PyObject
    end
  end

  class Spine < PyCall::PyObject
  end

  PyCall.register_python_type_mapping('matplotlib.axis', 'XAxis', Axis::XAxis)
  PyCall.register_python_type_mapping('matplotlib.axis', 'YAxis', Axis::YAxis)
  PyCall.register_python_type_mapping('matplotlib.spines', 'Spine', Spine)
  PyCall.register_python_type_mapping('', 'XAxis', Axis::XAxis)
  PyCall.register_python_type_mapping('', 'YAxis', Axis::YAxis)
  PyCall.register_python_type_mapping('', 'Spine', Spine)
end
