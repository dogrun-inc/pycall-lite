module PyCall
  module Import
    def self.included(mod)
      mod.extend(self)
    end

    def pyimport(mod_name, as: nil)
      mod = PyCall.import_module(mod_name)
      method_name = as ? as.to_sym : mod_name.to_sym
      
      # Define method on the target (class, module, or Object)
      target = self.is_a?(Module) ? self : self.class
      
      target.send(:define_method, method_name) do
        mod
      end
      
      if self.is_a?(Module)
        begin
          target.send(:module_function, method_name)
        rescue => e
          # Ignore if module_function is not supported on target
        end
      end
      
      mod
    end

    def pyfrom(mod_name, import:)
      mod = PyCall.import_module(mod_name)
      target = self.is_a?(Module) ? self : self.class

      imports = case import
                when Array
                  import.map { |i| [i.to_sym, i.to_sym] }
                when Hash
                  import.map { |k, v| [k.to_sym, v.to_sym] }
                else
                  [[import.to_sym, import.to_sym]]
                end

      imports.each do |name, alias_name|
        # Import the attribute object itself without invoking callable attributes.
        py_obj = if mod.is_a?(PyCall::PyObject)
                   PyCall.wrap(mod.__js_obj__[name])
                 else
                   mod.__send__(name)
                 end
        target.send(:define_method, alias_name) do |*args|
          if args.empty?
            py_obj
          else
            mod.__send__(name, *args)
          end
        end
        if self.is_a?(Module)
          begin
            target.send(:module_function, alias_name)
          rescue => e
          end
        end
      end
    end
  end
end
