require "spec_helper"

RSpec.describe "Matplotlib" do
  it "has a version number" do
    out = WasmPycallRunner.run_ruby(<<~RUBY)
      require "matplotlib"
      JS.global[:__rspec_result__] = !Matplotlib::VERSION.nil?
    RUBY

    expect(out).to eq(true)
  end

  describe "axes and spines" do
    specify "exposes xaxis and yaxis as PyCall objects" do
      out = WasmPycallRunner.run_ruby(<<~RUBY)
        require "matplotlib/pyplot"

        fig = Matplotlib::Pyplot.invoke(:figure)
        ax = fig.add_axes([0.1, 0.2, 0.8, 0.7])
        JS.global[:__rspec_result__] = (
          ax.xaxis.is_a?(PyCall::PyObject) &&
          ax.yaxis.is_a?(PyCall::PyObject)
        )
      RUBY

      expect(out).to eq(true)
    end

    specify "exposes spines through indexed PyCall access" do
      out = WasmPycallRunner.run_ruby(<<~RUBY)
        require "matplotlib/pyplot"

        fig = Matplotlib::Pyplot.invoke(:figure)
        ax = fig.add_axes([0.1, 0.2, 0.8, 0.7])
        JS.global[:__rspec_result__] = ax.spines["right"].is_a?(PyCall::PyObject)
      RUBY

      expect(out).to eq(true)
    end
  end
end
