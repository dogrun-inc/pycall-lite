require 'js'

# Lightweight PyCall-compatible bridge for Ruby.wasm + Pyodide.
#
# This module provides:
# - module import via {PyCall.import_module}
# - wrapper conversion between JS/PyProxy and Ruby values
# - dynamic method/property/index delegation through {PyCall::PyObject}
module PyCall
  # Sets the VM identifier used to resolve the matching Pyodide instance.
  #
  # @param vm_id [String] unique VM key managed by JavaScript
  def self.init_vm_id(vm_id)
    @vm_id = vm_id
  end

  # Returns the Pyodide instance associated with this Ruby VM.
  #
  # @return [Object] Pyodide instance
  def self.pyodide
    # Fetch Pyodide from the global map using VM ID
    @pyodide ||= JS.global[:__pycall_pyodides__].call(:get, @vm_id)
  end

  # Imports a Python module and wraps the result for Ruby-side access.
  #
  # @param mod_name [String, Symbol] Python module name
  # @return [Object, PyCall::PyObject]
  def self.import_module(mod_name)
    py_mod = pyodide.pyimport(mod_name.to_s)
    wrap(py_mod)
  end

  # Converts JS/Pyodide values into Ruby-friendly values.
  #
  # @param py_obj [Object] JavaScript-side value
  # @return [Object, PyCall::PyObject, nil]
  def self.wrap(py_obj)
    return py_obj unless py_obj.is_a?(JS::Object)

    # Unwrap JS null/undefined to Ruby nil
    type_str = JS.global[:Object][:prototype][:toString].call(:call, py_obj).to_s
    return nil if type_str == '[object Null]' || type_str == '[object Undefined]'

    # Unwrap primitive JS types back to native Ruby types
    case py_obj.typeof
    when 'number'
      val = py_obj.to_f
      val.to_i == val ? val.to_i : val
    when 'string'
      py_obj.to_s
    when 'boolean'
      py_obj.to_s == 'true'
    else
      if is_pyproxy?(py_obj)
        PyCall::PyObject.new(py_obj)
      else
        py_obj
      end
    end
  end

  def self.is_pyproxy?(obj)
    return false unless obj.is_a?(JS::Object)

    detector = pyodide[:isPyProxy]
    if detector.is_a?(JS::Object) && detector.typeof == 'function'
      return detector.call(:call, pyodide, obj) == true
    end

    # Fallback for Pyodide versions that expose proxy classes only via pyodide.ffi.
    ffi = pyodide[:ffi]
    return false unless ffi.is_a?(JS::Object)

    pyproxy_ctor = ffi[:PyProxy]
    return false unless pyproxy_ctor.is_a?(JS::Object) && pyproxy_ctor.typeof == 'function'

    pyproxy_proto = pyproxy_ctor[:prototype]
    return false unless pyproxy_proto.is_a?(JS::Object)

    JS.global[:Object][:prototype][:isPrototypeOf].call(:call, pyproxy_proto, obj) == true
  end

  # Performs basic Ruby-to-JS conversion used by delegated calls.
  #
  # @param val [Object] Ruby-side value
  # @return [Object] JavaScript-side value
  def self.ruby_to_js(val)
    case val
    when PyCall::PyObject
      val.__js_obj__
    else
      val
    end
  end

  # Wrapper around a Python object (typically a PyProxy).
  #
  # Exposes dynamic property/method/index access from Ruby.
  class PyObject
    # @return [Object] underlying JavaScript object
    attr_reader :__js_obj__

    # @param js_obj [Object] underlying JavaScript object (PyProxy or similar)
    def initialize(js_obj)
      @__js_obj__ = js_obj
    end

    # Instantiates a Python class object.
    #
    # @param args [Array<Object>] constructor arguments
    # @return [Object, PyCall::PyObject]
    def new(*args)
      # Instantiate a Python class (represented as a Callable JS object)
      js_args = PyCall.ruby_to_js(args)
      res = JS.global[:Reflect].call(:apply, @__js_obj__, nil, js_args)
      PyCall.wrap(res)
    end

    # Calls a Python callable object.
    #
    # @param args [Array<Object>] call arguments
    # @return [Object, PyCall::PyObject]
    def call(*args)
      # Call a Python function directly
      js_args = PyCall.ruby_to_js(args)
      res = JS.global[:Reflect].call(:apply, @__js_obj__, nil, js_args)
      PyCall.wrap(res)
    end

    # Handles dynamic property and method access.
    #
    # Supports:
    # - property read: +obj.attr+
    # - property write: +obj.attr = value+
    # - method call: +obj.func(arg1, arg2)+
    #
    # @param name [Symbol]
    # @param args [Array<Object>]
    # @return [Object, PyCall::PyObject]
    def method_missing(name, *args, &block)
      name_str = name.to_s

      # Property assignment: obj.attr = val
      if name_str.end_with?('=')
        prop_name = name_str[0...-1]
        val = args[0]
        JS.global[:Reflect].call(:set, @__js_obj__, prop_name.to_s, PyCall.ruby_to_js(val))
        return val
      end

      # Property/method resolution
      prop = @__js_obj__[name]

      if prop.is_a?(JS::Object) && prop.typeof == 'function'
        # Method execution
        js_args = args.map { |arg| PyCall.ruby_to_js(arg) }
        res = @__js_obj__.call(name, *js_args)
        PyCall.wrap(res)
      else
        if args.any? && prop.is_a?(JS::Object) && prop[:call].typeof == 'function'
          # Example: python_obj.callable_attr(args)
          js_args = args.map { |arg| PyCall.ruby_to_js(arg) }
          res = prop.call(:call, *js_args)
          PyCall.wrap(res)
        else
          PyCall.wrap(prop)
        end
      end
    end

    def respond_to_missing?(name, include_private = false)
      @__js_obj__[name].typeof != 'undefined'
    end

    # Index read: +obj[key]+.
    #
    # @param key [Object]
    # @return [Object, PyCall::PyObject]
    def [](key)
      if @__js_obj__[:get].typeof == 'function'
        PyCall.wrap(@__js_obj__.call(:get, PyCall.ruby_to_js(key)))
      else
        PyCall.wrap(@__js_obj__[key])
      end
    end

    # Index write: +obj[key] = val+.
    #
    # @param key [Object]
    # @param val [Object]
    # @return [Object] assigned value
    def []=(key, val)
      if @__js_obj__[:set].typeof == 'function'
        @__js_obj__.call(:set, PyCall.ruby_to_js(key), PyCall.ruby_to_js(val))
      else
        JS.global[:Reflect].call(:set, @__js_obj__, key.to_s, PyCall.ruby_to_js(val))
      end
      val
    end

    # Returns the Python object's string representation.
    #
    # @return [String]
    def to_s
      @__js_obj__.call(:toString).to_s
    end

    # Returns a debug representation of the wrapped object.
    #
    # @return [String]
    def inspect
      "#<PyCall::PyObject #{@__js_obj__.call(:toString).to_s}>"
    end
  end
end
