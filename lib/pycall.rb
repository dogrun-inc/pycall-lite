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
    @pyodide = nil
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
  # Supports unwrapping of Python objects (via PyProxy) and primitive types
  # back to Ruby native types. Python collection types (list, dict, tuple)
  # are preserved as PyObject for dynamic access via [] and method_missing.
  #
  # @param py_obj [Object] JavaScript-side value (PyProxy or primitive)
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

    # Fast-path heuristic for callable/type proxies (e.g. Python classes)
    # that expose Pyodide-specific call helpers.
    return true if obj[:callKwargs].typeof == 'function'

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

  # Performs Ruby-to-JS/Python conversion for method calls.
  #
  # Handles Ruby native types (Symbol, Hash, Array, Proc/Block) and converts them
  # to corresponding JS/Python equivalents. Proc/Block objects are wrapped as
  # callable JS functions that can be passed to Python functions.
  #
  # @param val [Object] Ruby-side value
  # @return [Object] JavaScript-side value
  def self.ruby_to_js(val)
    case val
    when PyCall::PyObject
      val.__js_obj__
    when Symbol
      val.to_s
    when Hash
      js_obj = JS.global[:Object].new
      val.each do |k, v|
        JS.global[:Reflect].call(:set, js_obj, k.to_s, ruby_to_js(v))
      end
      js_obj
    when Array
      js_arr = JS.global[:Array].new
      val.each do |v|
        js_arr.call(:push, ruby_to_js(v))
      end
      js_arr
    when Proc
      # Wrap a Ruby Proc/Block as a Python-callable JS function.
      # The wrapped function converts arguments and invokes the Proc.
      create_js_callback(val)
    when true
      true
    when false
      false
    when nil
      nil
    else
      val
    end
  end

  # Wraps a Ruby Proc/Block as a JS function callable from Python.
  #
  # Creates a JS function wrapper that can be passed to Python functions.
  # When invoked from Python, it converts arguments back to Ruby and calls the Proc.
  #
  # @param ruby_proc [Proc] Ruby block or Proc object
  # @return [Object] JS function that invokes the Proc
  def self.create_js_callback(ruby_proc)
    # Expose the Proc as a JS callable via js gem
    # The wrapper function converts JS/Python arguments to Ruby and calls the Proc
    JS.global.call(:eval, %{
      (function(proc) {
        return function(...args) {
          // Call the Ruby Proc with arguments; js gem handles conversion
          return proc.call(...args);
        };
      })
    }).call(:call, JS.global, ruby_proc)
  end

  # Splits a trailing Hash off +args+ to be treated as Python keyword arguments.
  #
  # @param args [Array<Object>]
  # @return [Array(Array<Object>, Hash, nil)] positional args and kwargs (or nil)
  def self.split_kwargs(args)
    if !args.empty? && args.last.is_a?(Hash)
      [args[0...-1], args.last]
    else
      [args, nil]
    end
  end

  # Emulates Python's `with` statement for a context-manager object.
  #
  # @param ctx [PyCall::PyObject] Python context manager
  # @yieldparam value [Object] the value returned by +__enter__+
  # @return [Object] the block's return value
  def self.with(ctx, &block)
    entered = ctx.invoke(:__enter__)
    python_none = pyodide[:globals].call(:get, 'None')

    begin
      result = block.call(entered)
    rescue StandardError => e
      suppressed = ctx.invoke(:__exit__, e.class.name, e.message, python_none)
      raise unless suppressed
    else
      ctx.invoke(:__exit__, python_none, python_none, python_none)
      result
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
      # Some proxies expose constructor behavior through callable invocation.
      begin
        return wrap_constructor_result(call(*args))
      rescue StandardError
        # Fall through to generic callable invocation.
      end

      # Fallback to generic callable invocation.
      wrap_constructor_result(call(*args))
    end

    def wrap_constructor_result(res)
      wrapped = PyCall.wrap(res)
      return wrapped unless res.is_a?(JS::Object) && !wrapped.is_a?(PyCall::PyObject)

      # In some runtimes PyProxy detection can miss class instances.
      # Constructor results should still behave as Python objects in Ruby.
      PyCall::PyObject.new(res)
    end

    # Calls a Python callable object.
    #
    # A trailing Hash is treated as Python keyword arguments and dispatched
    # through Pyodide's callKwargs when available.
    #
    # @param args [Array<Object>] call arguments (a trailing Hash is treated as kwargs)
    # @return [Object, PyCall::PyObject]
    def call(*args)
      positional, kwargs = PyCall.split_kwargs(args)

      if kwargs && @__js_obj__[:callKwargs].is_a?(JS::Object) && @__js_obj__[:callKwargs].typeof == 'function'
        js_positional = PyCall.ruby_to_js(positional)
        js_kwargs = PyCall.ruby_to_js(kwargs)
        return PyCall.wrap(@__js_obj__.call(:callKwargs, *js_positional, js_kwargs))
      end

      js_args = PyCall.ruby_to_js(args)

      # Pyodide may expose callables either as actual JS functions or as
      # proxy objects that provide a .call method.
      res = if @__js_obj__.typeof == 'function'
              JS.global[:Reflect].call(:apply, @__js_obj__, nil, js_args)
            elsif @__js_obj__[:call].is_a?(JS::Object) && @__js_obj__[:call].typeof == 'function'
              @__js_obj__.call(:call, *js_args)
            else
              raise TypeError, 'Python object is not callable'
            end

      PyCall.wrap(res)
    end

    # Forces invocation of a named Python method, even with zero arguments,
    # bypassing the argument-less "attribute vs. call" ambiguity used by
    # {#method_missing}. Needed for protocol methods such as +__enter__+ and
    # +__exit__+.
    #
    # @param name [Symbol, String] Python method name
    # @param args [Array<Object>] call arguments (a trailing Hash is treated as kwargs)
    # @return [Object, PyCall::PyObject]
    def invoke(name, *args)
      prop = @__js_obj__[name]
      raise NoMethodError, "undefined python method `#{name}'" unless prop.is_a?(JS::Object) && prop.typeof == 'function'

      positional, kwargs = PyCall.split_kwargs(args)

      if kwargs && prop[:callKwargs].is_a?(JS::Object) && prop[:callKwargs].typeof == 'function'
        js_positional = positional.map { |arg| PyCall.ruby_to_js(arg) }
        js_kwargs = PyCall.ruby_to_js(kwargs)
        return PyCall.wrap(prop.call(:callKwargs, *js_positional, js_kwargs))
      end

      js_args = args.map { |arg| PyCall.ruby_to_js(arg) }
      PyCall.wrap(prop.call(:call, @__js_obj__, *js_args))
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

      # Constructor call: python_class.new(args)
      if name == :new
        js_args = args.map { |arg| PyCall.ruby_to_js(arg) }

        if @__js_obj__[:new].is_a?(JS::Object) && @__js_obj__[:new].typeof == 'function'
          return PyCall.wrap(@__js_obj__.call(:new, *js_args))
        end

        return call(*args)
      end

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
        # Distinguish attribute access from invocation for callable attributes
        # (e.g. module.ClassName should return the class object itself).
        if args.empty? && block.nil?
          PyCall.wrap(prop)
        else
          positional, kwargs = PyCall.split_kwargs(args)

          if kwargs && prop[:callKwargs].is_a?(JS::Object) && prop[:callKwargs].typeof == 'function'
            js_positional = positional.map { |arg| PyCall.ruby_to_js(arg) }
            js_kwargs = PyCall.ruby_to_js(kwargs)
            res = prop.call(:callKwargs, *js_positional, js_kwargs)
          else
            js_args = args.map { |arg| PyCall.ruby_to_js(arg) }
            res = prop.call(:call, @__js_obj__, *js_args)
          end

          PyCall.wrap(res)
        end
      else
        if args.any? && prop.is_a?(JS::Object) && prop[:call].typeof == 'function'
          # Example: python_obj.callable_attr(args)
          positional, kwargs = PyCall.split_kwargs(args)

          if kwargs && prop[:callKwargs].is_a?(JS::Object) && prop[:callKwargs].typeof == 'function'
            js_positional = positional.map { |arg| PyCall.ruby_to_js(arg) }
            js_kwargs = PyCall.ruby_to_js(kwargs)
            res = prop.call(:callKwargs, *js_positional, js_kwargs)
          else
            js_args = args.map { |arg| PyCall.ruby_to_js(arg) }
            res = prop.call(:call, *js_args)
          end

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

# Lazily evaluates embedded Ruby sources registered on the JS side (see
# `__pycall_virtual_files__`), enabling `require "matplotlib"`-style loading
# of optional add-ons without eagerly executing them at PyCall setup time.
module Kernel
  unless method_defined?(:__pycall_lite_original_require__)
    alias_method :__pycall_lite_original_require__, :require
  end

  def require(name)
    key = name.to_s
    registry = JS.global[:__pycall_virtual_files__]

    if registry.is_a?(JS::Object) && registry.typeof == 'object' && registry.call(:has, key) == true
      return false if $LOADED_FEATURES.include?(key)

      source = registry.call(:get, key).to_s
      eval(source)
      $LOADED_FEATURES << key
      $LOADED_FEATURES << "#{key}.rb" unless key.end_with?('.rb')
      true
    else
      __pycall_lite_original_require__(key)
    end
  end
end
