# frozen_string_literal: true

module Jstreamer
  # Provides main DSL and base class for json rendering.
  class BaseJson # rubocop:todo Metrics/ClassLength
    # TODO: add Scout instrumentation
    # include ScoutApm::Tracer
    # def self.generate(obj = NO_ARGUMENT, **opts)
    #   instrument("Jstreamer", name) do
    #     new(**opts).call(obj).to_s
    #   end
    # end

    # Generates json for a single object
    # @param obj [Object, nil]
    # @param opts [kwargs] options
    # @return [String] generated json
    def self.generate(obj = nil, **opts)
      new(**opts).call(obj).to_s
    end

    # Generates json for a collection of objects
    # @param collection [Array]
    # @param opts [kwargs] options
    # @return [String] generated json
    def self.generate_collection(collection, **opts)
      new(**opts).call_collection(collection).to_s
    end

    # Initializer
    # @param stream [stream]
    # @param opts [kwargs]
    def initialize(stream = nil, **opts)
      @current_stream = stream || create_new_stream
      @options = opts
      @local_cache = {}
      @index = nil
    end

    # @return [Object, nil] current model (data object) passed to the renderer
    attr_reader :current_model

    # @return [stream] current json stream (low-level)
    attr_reader :current_stream

    # @return [Integer, nil] index of currently rendering element inside array's rendering loop
    attr_reader :index

    # @return [Hash] current options passed to the renderer
    attr_reader :options

    # Performs render for a single object
    # @param obj [Object] current model
    # @return self
    def call(obj = nil)
      @current_model = obj
      current_stream.push_object
      render
      current_stream.pop
      self
    end

    # Performs render for a collection of objects
    # @param collection [Array]
    # @return self
    def call_collection(collection)
      current_stream.push_array
      collection.each_with_index do |obj, index|
        @index = index
        call(obj)
      end
      current_stream.pop
      self
    end

    # Returns json string of current object
    # @return [String]
    def to_s # rubocop:disable Rails/Delegate
      current_stream.to_s
    end

    # @!group DSL

    # Pushes a simple property to a json stream
    # @param key [Symbol]
    # @param value [Object]
    # @return void
    # @example
    #   prop(:abc, 123)
    #   prop(:xyz, "qwerty")
    def prop(key, value)
      key = normalized_key(key)
      if value.is_a?(Array)
        current_stream.push_array(key)
        value.each { |v| current_stream.push_value(encode_value(v)) }
        current_stream.pop
      else
        current_stream.push_value(encode_value(value), key)
      end
    end

    # Extracts properties from an object or hash and pushes them to a json stream
    # @param obj [Hash, Object]
    # @param keys [Array<Symbol>]
    # @return void
    # @example With inlined keys
    #   from(current_model, :method1, :method2)  # calling methods of provided object
    #   from(some_hash, :prop1, :prop2)          # fetching props of provided hash
    # @example With keys as array
    #   PROPS = %i[prop1 prop2]
    #
    #   from(some, PROPS)   # pass array directly
    #   from(some, *PROPS)  # pass array with splat
    def from(obj, *keys)
      from_hash = obj.is_a?(Hash)
      keys = keys[0] if keys[0].is_a?(Array)
      keys.each do |key|
        value = from_hash ? obj.fetch(key) : obj.__send__(key)
        prop(key, value)
      end
    end

    # Pushes an object to a json stream
    # @param key [Symbol]
    # @yield optional block
    # @return void
    # @example Object with a block
    #   object(:object_with_block) do
    #     prop(:a, 1)
    #   end
    # @example Object with helper method
    #   def render
    #     object(:object_with_helper_method)
    #   end
    #
    #   def object_with_helper_method
    #     prop(:a, 1)
    #   end
    def object(key)
      current_stream.push_object(normalized_key(key))
      block_given? ? yield : __send__(key)
      current_stream.pop
    end

    # Merges a json string to a json stream directly
    # @param json [String]
    # @return void
    def merge_json(json)
      return if [nil, "", "{}", "[]"].include?(json)

      key_start = json.index('"') + 1
      key_end = json.index('"', key_start) - 1
      key = json[key_start..key_end].to_sym
      key = normalized_key(key)

      value_start = json.index(":", key_end) + 1
      value_end = json.rindex("}") - 1
      value = json[value_start..value_end]

      current_stream.push_json(value, key)
    end

    # Pushes a partial to a stream
    # @param key [Symbol]
    # @param klass [Class] partial class
    # @param klass_obj [Object] data model passed to a class
    # @param klass_opts [kwargs] options
    def partial(key, klass, klass_obj, **klass_opts) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      normalized_key = normalized_key(key)
      current_stream.push_key(normalized_key)

      cache_key = klass_opts.delete(:cache_key)
      cache_type = klass_opts.delete(:cache_type)
      raise(Jstreamer::Error, "No cache_key provided") if cache_type && cache_key.nil?
      raise(Jstreamer::Error, "No cache_type provided") if cache_key && cache_type.nil?

      case cache_type
      when :local
        execute_partial_with_local_caching(normalized_key, cache_key, klass, klass_obj, **klass_opts)
      when :rails
        execute_partial_with_rails_caching(cache_key, klass, klass_obj, **klass_opts)
      when nil
        execute_partial_directly(current_stream, klass, klass_obj, **klass_opts)
      else
        raise(Jstreamer::Error, "Unknown cache_type: #{cache_type}")
      end
    end

    # Helper, checks current view(s) by name
    # @param views [Array<Symbol>] view names
    # @return [Boolean]
    # @example
    #   if view?(:api_v1, :api_v2)        # either of views
    #     prop(:some_api_only_prop, 1)
    #   end
    def view?(*views)
      views.include?(options[:view])
    end

    # Pushes an array to a json stream
    # @param key [Symbol]
    # @param array_obj [Array]
    # @yield optional block
    # @return void
    # @example Array with a block
    #   array(:my_items, items) do |item|
    #     from(item, :a, :b, :c)
    #     prop(:x, item.d)
    #   end
    # @example Array with a helper method
    #   def render
    #     array(:my_items, items)
    #   end
    #
    #   def my_items(item)
    #     from(item, :a, :b, :c)
    #     prop(:x, item.d)
    #   end
    def array(key, array_obj)
      current_stream.push_array(normalized_key(key))
      array_obj.each do |obj|
        current_stream.push_object
        block_given? ? yield(obj) : __send__(key, obj)
        current_stream.pop
      end
      current_stream.pop
    end

    # @!endgroup

    # @!group Helpers

    # Simple delegation helper for options as methods
    # @param opts [Array<Symbol>] option key(s)
    # @return void
    # @example
    #   class SomeMyJson < ApplicationJson
    #     delegated_options :slug
    #
    #     def render
    #       options[:slug]    # access directly
    #       slug              # access with delegate_options helper
    #     end
    #   end
    def self.delegated_options(*opts)
      opts.each do |opt|
        define_method(opt) { options.fetch(opt) }
      end
    end

    # @!endgroup

    # @!group Extendable methods

    # Key transformation logic (can be extended by ancestors)
    # @param key [Symbol]
    # @return [String] transformed key as string
    # @example Camelizing all props in json
    #   class ApplicationJson < BaseJson
    #     def transform_key(key)
    #       super.camelize(:lower)   # please always handle super gracefully
    #     end
    #   end
    def transform_key(key)
      raise(Jstreamer::Error, "Keys should be Symbols only") unless key.is_a?(Symbol)

      key.to_s.tr("?!", "")
    end

    # Value encoding logic (can be extended by ancestors)
    # @param value [Object]
    # @return [String] string to be written to json
    # @example
    #   class ApplicaiontJson < BaseJson
    #     def encode_value(value)
    #       case value
    #       when BigDecimal then value.to_f    # e.g. we want those as floats, not as strings
    #       else super
    #       end
    #     end
    #   end
    def encode_value(value)
      case value
      when String then value.to_str
      when Integer, Float, TrueClass, FalseClass, NilClass then value
      when Date then value.strftime("%F")
      when Time then value.strftime("%FT%T.%L%:z")
      else raise(Jstreamer::Error, "Unsupported json encode class #{value.class}")
      end
    end

    # @!endgroup

    private

    def create_new_stream
      Jstreamer.create_new_stream
    end

    def execute_partial_directly(stream, klass, klass_obj, **klass_opts)
      klass_obj = klass_obj.call if klass_obj.is_a?(Proc)

      if klass.is_a?(Array)
        klass.first.new(stream, **klass_opts).call_collection(klass_obj)
      else
        klass.new(stream, **klass_opts).call(klass_obj)
      end
    end

    def execute_partial_with_local_caching(normalized_key, cache_key, klass, klass_obj, **klass_opts)
      @local_cache[normalized_key] ||= {}
      @local_cache[normalized_key][cache_key] ||=
        execute_partial_directly(create_new_stream, klass, klass_obj, **klass_opts).to_s.chomp
      current_stream.push_json(@local_cache[normalized_key][cache_key])
    end

    def execute_partial_with_rails_caching(cache_key, klass, klass_obj, **klass_opts)
      result = Rails.cache.fetch(cache_key) do
        execute_partial_directly(create_new_stream, klass, klass_obj, **klass_opts).to_s.chomp
      end
      current_stream.push_json(result)
    end

    def normalized_keys
      self.class.instance_variable_get(:@normalized_keys) || self.class.instance_variable_set(:@normalized_keys, {})
    end

    def normalized_key(key)
      normalized_keys[key] ||= transform_key(key)
    end
  end
end
