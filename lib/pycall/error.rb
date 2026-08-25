require 'pycall'

# Python-origin exception handling for pycall-lite.
#
# Pyodide raises a JS `PythonError` when a Python exception escapes to JS.
# To avoid leaking Python stack frames, `PythonError` does not carry the
# original exception, so it is instead recovered from
# `sys.last_type`/`sys.last_value`/`sys.last_traceback` (see
# {PyCall.capture_last_python_error}).
module PyCall
  # Name of the Python-side helper function (defined lazily in the Pyodide
  # global scope) that reads back `sys.last_type`/`sys.last_value`/
  # `sys.last_traceback`, per Pyodide's recommended error-handling pattern.
  PYTHON_ERROR_CAPTURE_FN = '__pycall_capture_last_python_error__'

  # Wraps a Python-origin exception that crossed the JS/Ruby boundary.
  class PythonError < StandardError
    # @return [Object] the Python exception type (e.g. a PyProxy of `ValueError`)
    attr_reader :type

    # @return [Object] the Python exception instance
    attr_reader :value

    # @return [Object] the Python traceback object
    attr_reader :traceback

    # @return [Object] the original JS/Ruby error that was caught
    attr_reader :original_error

    # @param message [String] formatted Python traceback text
    # @param type [Object, nil] Python exception type
    # @param value [Object, nil] Python exception instance
    # @param traceback [Object, nil] Python traceback object
    # @param original_error [Object, nil] the error object that was caught
    def initialize(message = nil, type: nil, value: nil, traceback: nil, original_error: nil)
      super(message || 'Python exception')
      @type = type
      @value = value
      @traceback = traceback
      @original_error = original_error
    end

    # Builds a {PythonError} from the currently-captured
    # `sys.last_type`/`sys.last_value`/`sys.last_traceback`, if any.
    #
    # @param original_error [Object, nil] the error object that was caught
    # @return [PyCall::PythonError, nil] nil when no Python error is captured
    def self.capture(original_error = nil)
      info = PyCall.capture_last_python_error
      return nil unless info

      message = info[:formatted]
      message = 'Python exception' if message.nil? || message.empty?

      new(
        message,
        type: info[:type],
        value: info[:value],
        traceback: info[:traceback],
        original_error: original_error
      )
    end
  end

  # Determines whether +error+ originates from a Python exception raised
  # through Pyodide (as opposed to a plain JS/Ruby error).
  #
  # @param error [Object] error caught in Ruby (typically a `JS::Error`)
  # @return [Boolean]
  def self.python_error?(error)
    return true if error.is_a?(PythonError)

    js_error = unwrap_js_error(error)
    return false unless js_error

    return true if js_error[:name].to_s == 'PythonError'

    ffi = pyodide[:ffi]
    return false unless ffi.is_a?(JS::Object)

    python_error_ctor = ffi[:PythonError]
    return false unless python_error_ctor.is_a?(JS::Object) && python_error_ctor.typeof == 'function'

    python_error_proto = python_error_ctor[:prototype]
    return false unless python_error_proto.is_a?(JS::Object)

    JS.global[:Object][:prototype][:isPrototypeOf].call(:call, python_error_proto, js_error) == true
  rescue StandardError
    false
  end

  # Extracts the underlying JS error object from +error+.
  #
  # Errors raised by JS calls surface in Ruby as `JS::Error`, which stores
  # the original JS exception in its `@exception` instance variable.
  #
  # @param error [Object]
  # @return [JS::Object, nil]
  def self.unwrap_js_error(error)
    return error if error.is_a?(JS::Object)

    if error.instance_variable_defined?(:@exception)
      inner = error.instance_variable_get(:@exception)
      return inner if inner.is_a?(JS::Object)
    end

    nil
  rescue StandardError
    nil
  end

  # Reads back the last Python exception captured by Pyodide.
  #
  # Per Pyodide's recommended pattern, `PythonError` intentionally does not
  # reference the original Python exception (to avoid leaking stack frames),
  # so it is instead recovered from `sys.last_type`/`sys.last_value`/
  # `sys.last_traceback` via a small Python helper defined lazily.
  #
  # @return [Hash{Symbol => Object}, nil] nil when no Python error is captured
  def self.capture_last_python_error
    ensure_python_error_capture_helper!

    capture_fn = pyodide[:globals].call(:get, PYTHON_ERROR_CAPTURE_FN)
    return nil unless capture_fn.is_a?(JS::Object) && capture_fn.typeof == 'function'

    result = capture_fn.call(:call)
    return nil if js_null_or_undefined?(result)

    type = result.call(:get, 'type')
    # NOTE: holding onto `value`/`traceback` retains their Python stack
    # frames; callers that don't need them should let this Hash go out of scope promptly.
    value = result.call(:get, 'value')
    traceback = result.call(:get, 'traceback')
    formatted = result.call(:get, 'formatted').to_s

    result.call(:destroy) if result[:destroy].is_a?(JS::Object) && result[:destroy].typeof == 'function'

    { type: type, value: value, traceback: traceback, formatted: formatted }
  rescue StandardError
    nil
  end

  # Defines the Python-side helper used by {capture_last_python_error}, once
  # per Pyodide instance.
  #
  # @return [void]
  def self.ensure_python_error_capture_helper!
    return if @python_error_capture_helper_defined

    pyodide.call(:runPython, <<~PY)
      def #{PYTHON_ERROR_CAPTURE_FN}():
          import sys
          import traceback

          if sys.last_value is None:
              return None

          return {
              "type": sys.last_type,
              "value": sys.last_value,
              "traceback": sys.last_traceback,
              "formatted": "".join(
                  traceback.format_exception(sys.last_type, sys.last_value, sys.last_traceback)
              ),
          }
    PY

    @python_error_capture_helper_defined = true
  end

  # Returns whether +obj+ is JS `null`/`undefined` (or Ruby `nil`).
  #
  # @param obj [Object]
  # @return [Boolean]
  def self.js_null_or_undefined?(obj)
    return obj.nil? unless obj.is_a?(JS::Object)

    type_str = JS.global[:Object][:prototype][:toString].call(:call, obj).to_s
    type_str == '[object Null]' || type_str == '[object Undefined]'
  rescue StandardError
    false
  end

  # Wraps +error+ into a {PyCall::PythonError} when it originates from a
  # Python exception; otherwise returns +error+ unchanged.
  #
  # @param error [Object] error caught in Ruby
  # @return [Object] a {PyCall::PythonError}, or +error+ unchanged
  def self.wrap_error(error)
    return error if error.is_a?(PythonError)
    return error unless python_error?(error)

    PythonError.capture(error) || error
  end

  # Converts Python-origin errors at a Ruby/JS boundary and preserves others.
  def self.with_error_handling
    yield
  rescue StandardError => error
    wrapped = wrap_error(error)
    raise wrapped.equal?(error) ? error : wrapped
  end
end
