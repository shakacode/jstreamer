# frozen_string_literal: true

require "spec_helper"

describe JsonStreamer::RailsJson do
  let(:template) do
    Class.new(described_class) do
      def render
        prop(:abc, current_model)
        prop(:api, true) if view?(:api)
        prop(:missing, missing(345)) if view?(:missing)
      end
    end
  end
  let(:controller) { double(render: true) } # rubocop:disable RSpec/VerifiedDoubles
  let(:view_context) { double(controller:) } # rubocop:disable RSpec/VerifiedDoubles

  describe ".render" do
    it "renders object" do
      template.render(123, view_context:)

      expect(controller).to have_received(:render).with(json: <<~JSON)
        {"abc":123}
      JSON
    end

    it "passes options" do
      template.render(123, view_context:, view: :api)

      expect(controller).to have_received(:render).with(json: <<~JSON)
        {"abc":123,"api":true}
      JSON
    end
  end

  describe ".render_collection" do
    it "renders collection" do
      template.render_collection([1, 2, 3], view_context:)

      expect(controller).to have_received(:render).with(json: <<~JSON)
        [{"abc":1},{"abc":2},{"abc":3}]
      JSON
    end

    it "passes options" do
      template.render_collection([1, 2], view_context:, view: :api)

      expect(controller).to have_received(:render).with(json: <<~JSON)
        [{"abc":1,"api":true},{"abc":2,"api":true}]
      JSON
    end
  end

  describe "#view_context" do
    it "returns view_context" do
      streamer = template.new(view_context:)

      expect(streamer.view_context).to eq(view_context)
    end
  end

  describe "#view_context_get" do
    it "fetches variable" do
      view_context.instance_variable_set(:@notifications, "some notifications")
      streamer = template.new(view_context:)

      expect(streamer.view_context_get(:@notifications)).to eq("some notifications")
    end
  end

  describe "#method_missing, #respond_to?" do
    it "passes missing to view_context" do
      allow(view_context).to receive(:missing) { |arg| arg }

      streamer = template.new(view_context:, view: :missing)

      expect(streamer.respond_to?(:missing)).to be(true)
      expect(streamer.call(123).to_s).to eq(<<~JSON)
        {"abc":123,"missing":345}
      JSON
    end

    it "raises when no view_context" do
      streamer = template.new(view_context: nil, view: :missing)

      expect(streamer.respond_to?(:missing)).to be(false)
      expect { streamer.call(123) }.to raise_error(NoMethodError)
    end

    it "raises when view_context doesn't have method" do
      streamer = template.new(view_context:, view: :missing)

      expect(streamer.respond_to?(:missing)).to be(false)
      expect { streamer.call(123) }.to raise_error(NoMethodError)
    end
  end
end
