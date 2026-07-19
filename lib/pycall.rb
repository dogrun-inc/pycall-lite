require 'js'

module PyCall
  def self.init_vm_id(vm_id)
    @vm_id = vm_id
  end

  def self.pyodide
    # Fetch Pyodide from the global map using VM ID
    @pyodide ||= JS.global[:__pycall_pyodides__].call(:get, @vm_id)
  end

  def self.import_module(mod_name)
    py_mod = pyodide.pyimport(mod_name.to_s)
    wrap(py_mod)
  end

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
    pyodide.isPyProxy(obj) == true
  end

  # Ruby から JS への基本的な型変換
  def self.ruby_to_js(val)
    case val
    when PyCall::PyObject
      val.__js_obj__
    else
      val
    end
  end

  class PyObject
    attr_reader :__js_obj__

    def initialize(js_obj)
      @__js_obj__ = js_obj
    end

    def new(*args)
      # Instantiate a Python class (represented as a Callable JS object)
      js_args = PyCall.ruby_to_js(args)
      res = JS.global[:Reflect].call(:apply, @__js_obj__, nil, js_args)
      PyCall.wrap(res)
    end

    def call(*args)
      # Call a Python function directly
      js_args = PyCall.ruby_to_js(args)
      res = JS.global[:Reflect].call(:apply, @__js_obj__, nil, js_args)
      PyCall.wrap(res)
    end

    def method_missing(name, *args, &block)
      name_str = name.to_s

      # 属性代入: obj.attr = val
      if name_str.end_with?('=')
        prop_name = name_str[0...-1]
        val = args[0]
        JS.global[:Reflect].call(:set, @__js_obj__, prop_name.to_s, PyCall.ruby_to_js(val))
        return val
      end

      # 属性/メソッドの取得
      prop = @__js_obj__[name]

      if prop.is_a?(JS::Object) && prop.typeof == 'function'
        # メソッドの実行
        js_args = args.map { |arg| PyCall.ruby_to_js(arg) }
        res = @__js_obj__.call(name, *js_args)
        PyCall.wrap(res)
      else
        if args.any? && prop.is_a?(JS::Object) && prop[:call].typeof == 'function'
          # 例: python_obj.callable_attr(args)
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

    # インデクスアクセス obj[key]
    def [](key)
      if @__js_obj__[:get].typeof == 'function'
        PyCall.wrap(@__js_obj__.call(:get, PyCall.ruby_to_js(key)))
      else
        PyCall.wrap(@__js_obj__[key])
      end
    end

    # インデクス設定 obj[key] = val
    def []=(key, val)
      if @__js_obj__[:set].typeof == 'function'
        @__js_obj__.call(:set, PyCall.ruby_to_js(key), PyCall.ruby_to_js(val))
      else
        JS.global[:Reflect].call(:set, @__js_obj__, key.to_s, PyCall.ruby_to_js(val))
      end
      val
    end

    # Pythonオブジェクトの文字列表現
    def to_s
      @__js_obj__.call(:toString).to_s
    end

    def inspect
      "#<PyCall::PyObject #{@__js_obj__.call(:toString).to_s}>"
    end
  end
end
