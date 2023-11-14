# frozen_string_literal: true

require "spec_helper"

describe Jstreamer::BaseJson do
  let(:basic_template) do
    Class.new(described_class) do
      def render
        prop(:abc, current_model)
      end
    end
  end

  describe ".generate" do
    it "generates object to json string" do
      expect(basic_template.generate(1)).to eq(<<~JSON)
        {"abc":1}
      JSON
    end
  end

  describe ".generate_collection" do
    it "generates collection to json string" do
      expect(basic_template.generate_collection([1, 2])).to eq(<<~JSON)
        [{"abc":1},{"abc":2}]
      JSON
    end
  end

  describe ".delegated_options" do
    let(:template) do
      Class.new(described_class) do
        delegated_options :option1, :option2

        def render
          prop(:abc, option1)
          prop(:xyz, option2)
        end
      end
    end

    it "delegates to options with methods" do
      streamer = template.new(option1: 111, option2: 222)

      expect(streamer.call.to_s).to eq(<<~JSON)
        {"abc":111,"xyz":222}
      JSON
      expect(streamer.public_methods).to include(:option1, :option2)
    end
  end

  describe "#call" do
    it "executes template for single object" do
      result = basic_template.new.call(1)

      expect(result).to be_a(described_class)
      expect(result.to_s).to eq(<<~JSON)
        {"abc":1}
      JSON
    end
  end

  describe "#call_collection" do
    it "executes template for collection of objects" do
      result = basic_template.new.call_collection([1, 2])

      expect(result).to be_a(described_class)
      expect(result.to_s).to eq(<<~JSON)
        [{"abc":1},{"abc":2}]
      JSON
    end
  end

  describe "#to_s" do
    it "renders to string" do
      expect(basic_template.new.call(1).to_s).to eq(<<~JSON)
        {"abc":1}
      JSON
    end
  end

  describe "DSL" do
    describe "values" do
      it "String" do
        expect(basic_template.generate("Some String")).to eq(<<~JSON)
          {"abc":"Some String"}
        JSON
      end

      it "Integer" do
        expect(basic_template.generate(123)).to eq(<<~JSON)
          {"abc":123}
        JSON
      end

      it "Float" do
        expect(basic_template.generate(123.456)).to eq(<<~JSON)
          {"abc":123.456}
        JSON
      end

      it "true" do
        expect(basic_template.generate(true)).to eq(<<~JSON)
          {"abc":true}
        JSON
      end

      it "false" do
        expect(basic_template.generate(false)).to eq(<<~JSON)
          {"abc":false}
        JSON
      end

      it "nil" do
        expect(basic_template.generate(nil)).to eq(<<~JSON)
          {"abc":null}
        JSON
      end

      it "Date" do
        expect(basic_template.generate(Date.new(2001, 10, 20))).to eq(<<~JSON)
          {"abc":"2001-10-20"}
        JSON
      end

      it "Time" do
        expect(basic_template.generate(Time.new(2001, 10, 20, 10, 20, 30, "-04:00"))).to eq(<<~JSON)
          {"abc":"2001-10-20T10:20:30.000-04:00"}
        JSON
      end

      it "unsupported types" do
        expect { basic_template.generate(:some) }.
          to raise_error(Jstreamer::Error, "Unsupported json encode class Symbol")

        expect { basic_template.generate(BigDecimal("1")) }.
          to raise_error(Jstreamer::Error, "Unsupported json encode class BigDecimal")
      end

      it "custom override" do
        basic_template.define_method(:encode_value) do |value|
          case value
          when BigDecimal then value.to_f
          when Symbol then value.to_s
          else super(value)
          end
        end

        expect(basic_template.generate(BigDecimal("1"))).to eq(<<~JSON)
          {"abc":1.0}
        JSON

        expect(basic_template.generate(:some)).to eq(<<~JSON)
          {"abc":"some"}
        JSON

        expect(basic_template.generate(123)).to eq(<<~JSON)
          {"abc":123}
        JSON
      end
    end

    describe "keys" do
      let(:template) do
        Class.new(described_class) do
          def render
            prop(current_model, 0)
          end
        end
      end

      it "no key transformation by default" do
        expect(template.generate(:some_prop)).to eq(<<~JSON)
          {"some_prop":0}
        JSON

        expect(template.generate(:SomeProp)).to eq(<<~JSON)
          {"SomeProp":0}
        JSON
      end

      it "strips exclamation and quotation marks" do
        expect(template.generate(:some!)).to eq(<<~JSON)
          {"some":0}
        JSON

        expect(template.generate(:some_prop!)).to eq(<<~JSON)
          {"some_prop":0}
        JSON

        expect(template.generate(:SomeProp!)).to eq(<<~JSON)
          {"SomeProp":0}
        JSON

        expect(template.generate(:some?)).to eq(<<~JSON)
          {"some":0}
        JSON

        expect(template.generate(:some_prop?)).to eq(<<~JSON)
          {"some_prop":0}
        JSON

        expect(template.generate(:SomeProp?)).to eq(<<~JSON)
          {"SomeProp":0}
        JSON
      end

      it "custom override" do
        template.define_method(:transform_key) do |key|
          super(key).tr("abc", "xB_")
        end

        expect(template.generate(:aabbbcca)).to eq(<<~JSON)
          {"xxBBB__x":0}
        JSON
      end
    end

    describe "#prop" do
      let(:template) do
        Class.new(described_class) do
          def render
            prop(:single, 1)
            prop(:array, [1, 2, "string"])
          end
        end
      end

      it "renders" do
        expect(template.generate).to eq(<<~JSON)
          {"single":1,"array":[1,2,"string"]}
        JSON
      end
    end

    describe "#from" do
      let(:template) do
        stub_const("KEYS", %i[a b])

        Class.new(described_class) do
          def render
            from(current_model, :a, :b)
            from(current_model, *KEYS)
            from(current_model, KEYS)
          end
        end
      end

      it "renders" do
        expected = <<~JSON
          {"a":1,"b":2,"a":1,"b":2,"a":1,"b":2}
        JSON

        hash = { a: 1, b: 2 }
        expect(template.generate(hash)).to eq(expected)

        object = Struct.new(:a, :b).new(1, 2)
        expect(template.generate(object)).to eq(expected)
      end
    end

    describe "#object" do
      let(:template) do
        Class.new(described_class) do
          def render
            object(:as_block) do
              prop(:abc, 0)
            end

            object(:as_method)
          end

          def as_method
            prop(:xyz, 0)
          end
        end
      end

      it "renders" do
        expect(template.generate).to eq(<<~JSON)
          {"as_block":{"abc":0},"as_method":{"xyz":0}}
        JSON
      end

      it "renders empty" do
        template = Class.new(described_class) do
          def render
            object(:as_block) {} # rubocop:disable Lint/EmptyBlock
            object(:as_method)
          end

          def as_method; end
        end

        expect(template.generate).to eq(<<~JSON)
          {"as_block":{},"as_method":{}}
        JSON
      end
    end

    describe "#merge_json" do
      let(:template) do
        Class.new(described_class) do
          def render
            prop(:abc, 0)
            merge_json(current_model[:json])
            prop(:qwe, 0)
          end
        end
      end

      it "renders" do
        expect(template.generate({ json: { xx: 1, yy: "some" }.to_json })).to eq(<<~JSON)
          {"abc":0,"xx":1,"yy":"some","qwe":0}
        JSON
      end

      it "skips empty" do
        expected = <<~JSON
          {"abc":0,"qwe":0}
        JSON

        expect(template.generate({ json: nil })).to eq(expected)
        expect(template.generate({ json: "" })).to eq(expected)
        expect(template.generate({ json: "{}" })).to eq(expected)
        expect(template.generate({ json: "[]" })).to eq(expected)
      end
    end

    describe "#partial" do
      before { stub_const("ItemPartial", basic_template) }

      it "renders partial as class" do
        template = Class.new(described_class) do
          def render
            partial(:items, ItemPartial, current_model)
          end
        end

        expect(template.generate(123)).to eq(<<~JSON)
          {"items":{"abc":123}}
        JSON
      end

      it "renders partial as class array" do
        template = Class.new(described_class) do
          def render
            partial(:items, [ItemPartial], current_model)
          end
        end

        expect(template.generate([1, 2, 3])).to eq(<<~JSON)
          {"items":[{"abc":1},{"abc":2},{"abc":3}]}
        JSON
      end

      it "caches locally (with data as lambda)" do
        template = Class.new(described_class) do
          def render
            partial(:items, ItemPartial, -> { current_model }, cache_key: current_model, cache_type: :local)
          end
        end
        allow(ItemPartial).to receive(:new).and_call_original

        expect(template.generate_collection([1, 2, 1, 1, 2])).to eq(<<~JSON)
          [{"items":{"abc":1}},{"items":{"abc":2}},{"items":{"abc":1}},{"items":{"abc":1}},{"items":{"abc":2}}]
        JSON
        expect(ItemPartial).to have_received(:new).exactly(2).times
      end
    end

    describe "#view?" do
      let(:template) do
        Class.new(described_class) do
          def render
            prop(:common, 0)
            prop(:conditional, 0) if view?(:api, :page)
          end
        end
      end

      it "renders" do
        expect(template.generate).to eq(<<~JSON)
          {"common":0}
        JSON

        expect(template.generate(view: :api)).to eq(<<~JSON)
          {"common":0,"conditional":0}
        JSON
      end
    end

    describe "#array" do
      let(:template) do
        Class.new(described_class) do
          def render
            array(:as_block, current_model[:items]) do |item|
              prop(:abc, item)
            end

            array(:as_method, current_model[:items])
          end

          def as_method(item)
            prop(:xyz, item)
          end
        end
      end

      it "renders" do
        expect(template.generate({ items: [1, 2] })).to eq(<<~JSON)
          {"as_block":[{"abc":1},{"abc":2}],"as_method":[{"xyz":1},{"xyz":2}]}
        JSON
      end

      it "renders empty" do
        expect(template.generate({ items: [] })).to eq(<<~JSON)
          {"as_block":[],"as_method":[]}
        JSON
      end
    end
  end
end
