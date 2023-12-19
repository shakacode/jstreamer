# frozen_string_literal: true

# require "jstreamer/base_json"

describe Jstreamer do
  describe ".generate" do
    let(:template) do
      Class.new(Jstreamer::BaseJson) do
        def render
          prop(:abc, current_model)
        end
      end
    end

    it "generates single object json" do
      expect(described_class.generate(template, 1)).to eq(<<~JSON)
        {"abc":1}
      JSON
    end

    it "generates collection json" do
      expect(described_class.generate([template], [1, 2, 3])).to eq(<<~JSON)
        [{"abc":1},{"abc":2},{"abc":3}]
      JSON
    end
  end

  describe ".create_new_stream" do
    it "retruns stream" do
      expect(described_class.create_new_stream).not_to be_nil
    end

    it "handles Unicode XSS injections" do
      stream = described_class.create_new_stream

      stream.push_value("\u2028\u2029\u0000", "x")
      result = stream.to_s.split(":").last

      expect(result).to eq('"\\u2028\\u2029\\u0000"')
    end

    it "handles HTML XSS injections" do
      stream = described_class.create_new_stream

      stream.push_value("<>&", "x")
      result = stream.to_s.split(":").last

      expect(result).to eq('"\\u003c\\u003e\\u0026"')
    end
  end
end
