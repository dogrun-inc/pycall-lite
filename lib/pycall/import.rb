require 'pycall'

module PyCall
  module Import
    def self.included(mod)
      mod.extend(self)
    end

    def pyimport(mod_name, as: nil)
      as = mod_name unless as
      check_valid_module_variable_name(mod_name, as)

      mod = PyCall.import_module(mod_name)
      define_singleton_method(as) do
        mod
      end

      mod
    end

    def pyfrom(mod_name, import:)
      mod = PyCall.import_module(mod_name)
      imports = Array(import).map do |import_name|
        case import_name
        when assoc_array_matcher
          [import_name[0], import_name[1]]
        when Symbol, String
          [import_name, import_name]
        else
          raise ArgumentError, "wrong type of import name #{import_name.class} (expected String or Symbol)"
        end
      end

      imports.each do |name, alias_name|
        # Import the attribute object itself without invoking callable attributes.
        py_obj = if mod.is_a?(PyCall::PyObject)
                   PyCall.wrap(mod.__js_obj__[name])
                 else
                   mod.__send__(name)
                 end

        define_singleton_method(alias_name) do |*args|
          if args.empty?
            py_obj
          else
            mod.__send__(name, *args)
          end
        end
      end
    end

    private

    def check_valid_module_variable_name(mod_name, var_name)
      var_name = var_name.to_s if var_name.is_a?(Symbol)
      if var_name.include?('.')
        raise ArgumentError, "#{var_name} is not a valid module variable name, use pyimport #{mod_name}, as: <name>"
      end
    end

    def assoc_array_matcher
      @assoc_array_matcher ||= ->(ary) do
        ary.is_a?(Array) && ary.length == 2
      end
    end
  end
end
