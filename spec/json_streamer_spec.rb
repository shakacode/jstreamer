# frozen_string_literal: true

# require "json_streamer/base_json"

describe JsonStreamer do
  describe ".generate" do
    let(:template) do
      Class.new(JsonStreamer::BaseJson) do
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
  end
end
