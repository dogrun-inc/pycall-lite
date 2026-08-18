require "spec_helper"

RSpec.describe "Matplotlib::Pyplot" do
  describe ".xkcd" do
      specify "restores rcParams after the block" do
        out = WasmPycallRunner.run_ruby(<<~RUBY)
          require "matplotlib/pyplot"

          saved_font_family = Matplotlib.rcParams["font.family"]
          saved_path_sketch = Matplotlib.rcParams["path.sketch"]
          yielded = false
          inside_ok = false

          Matplotlib::Pyplot.xkcd(scale: 42, length: 43, randomness: 44) do
            yielded = true
            inside_ok = (
              Matplotlib.rcParams["font.family"].to_s.include?("xkcd") &&
              Matplotlib.rcParams["path.sketch"][0] == 42 &&
              Matplotlib.rcParams["path.sketch"][1] == 43 &&
              Matplotlib.rcParams["path.sketch"][2] == 44
            )
          end

          restored = (
            Matplotlib.rcParams["font.family"].to_s == saved_font_family.to_s &&
            Matplotlib.rcParams["path.sketch"].to_s == saved_path_sketch.to_s
          )
          JS.global[:__rspec_result__] = yielded && inside_ok && restored
        RUBY

        expect(out).to eq(true)
      end
  end
end
