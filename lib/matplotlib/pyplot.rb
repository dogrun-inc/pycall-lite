require 'matplotlib'

# Ruby bindings for `matplotlib.pyplot`, mirroring `Matplotlib::Pyplot` from
# the matplotlib gem (https://github.com/red-data-tools/matplotlib.rb).
module Matplotlib
  # Underlying `matplotlib.pyplot` Python module.
  Pyplot = PyCall.import_module('matplotlib.pyplot')

  # `pyplot.xkcd` is a Python context manager; wrap it with PyCall.with so
  # it can be used as `Matplotlib::Pyplot.xkcd { ... }` from Ruby.
  Pyplot.define_singleton_method(:xkcd) do |scale: 1, length: 100, randomness: 2, &block|
    ctx = invoke(:xkcd, scale: scale, length: length, randomness: randomness)
    PyCall.with(ctx, &block)
  end
end
