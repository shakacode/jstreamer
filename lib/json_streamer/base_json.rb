# frozen_string_literal: true

module JsonStreamer
  class BaseJson # rubocop:todo Metrics/ClassLength
    # include ScoutApm::Tracer if defined?(ScoutApm)

    NO_ARGUMENT = Object.new

    def self.generate(obj = NO_ARGUMENT, **opts)
      # if defined?(ScoutApm)
      #   instrument("JsonStreamer", name) do
      #     new(**opts).call(obj).to_s
      #   end
      # else
      #  new(**opts).call(obj).to_s
      # end
      new(**opts).call(obj).to_s
    end

    def self.delegated_options(*opts)
      opts.each do |opt|
        define_method(opt) { options.fetch(opt) }
      end
    end

    def initialize(stream = nil, **opts)
      @current_stream = stream || create_new_stream
      @options = opts
      @reusable_cache = {}
    end

    attr_reader :current_model, :current_stream, :index, :options

    def call(obj = NO_ARGUMENT, **opts)
      @options.merge!(opts)
      object_is_collection?(obj) ? render_collection(obj) : render_single(obj)
      self
    end

    def to_s # rubocop:disable Rails/Delegate
      current_stream.to_s
    end

    protected

    ### DSL

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

    def from(obj, *keys)
      from_hash = obj.is_a?(Hash)
      keys = keys[0] if keys[0].is_a?(Array)
      keys.each do |key|
        value = from_hash ? obj.fetch(key) : obj.__send__(key)
        prop(key, value)
      end
    end

    def object(key)
      current_stream.push_object(normalized_key(key))
      block_given? ? yield : __send__(key)
      current_stream.pop
    end

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

    def partial( # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize, Metrics/MethodLength
      key,
      klass = NO_ARGUMENT,
      klass_obj = NO_ARGUMENT,
      reuse_by: nil,
      cache_by: nil,
      **klass_opts,
      &block
    )
      normalized_key = normalized_key(key)
      current_stream.push_key(normalized_key)

      if !cache_by.nil?
        result = Rails.cache.fetch(cache_by) do
          execute_partial(key, create_new_stream, klass, klass_obj, **klass_opts, &block).to_s
        end
        current_stream.push_json(result)
      elsif !reuse_by.nil?
        result = (@reusable_cache[normalized_key] ||= {})[reuse_by] ||=
          execute_partial(key, create_new_stream, klass, klass_obj, **klass_opts, &block).to_s
        current_stream.push_json(result)
      else
        execute_partial(key, current_stream, klass, klass_obj, **klass_opts, &block)
      end
    end

    def view?(*views)
      views.include?(options[:view])
    end

    def array(key, array_obj)
      current_stream.push_array(normalized_key(key))
      array_obj.each do |obj|
        current_stream.push_object
        block_given? ? yield(obj) : __send__(key, obj)
        current_stream.pop
      end
      current_stream.pop
    end

    private

    ### private-private

    def create_new_stream
      Oj::StringWriter.new
    end

    def execute_partial(key, stream, klass, klass_obj, **klass_opts)
      if klass != NO_ARGUMENT
        klass_obj = current_model if klass_obj == NO_ARGUMENT
        klass.new(stream).call(klass_obj, **klass_opts)
      elsif block_given?
        yield(stream)
      else
        __send__(key, stream)
      end
    end

    def render_single(obj)
      @current_model = obj
      current_stream.push_object
      render
      current_stream.pop
    end

    def render_collection(collection)
      current_stream.push_array
      collection.each_with_index do |obj, index|
        @index = index
        render_single(obj)
      end
      current_stream.pop
    end

    def normalized_keys
      self.class.instance_variable_get(:@normalized_keys) || self.class.instance_variable_set(:@normalized_keys, {})
    end

    def normalized_key(key)
      normalized_keys[key] ||= transform_key(key)
    end

    def transform_key(key)
      key.instance_of?(Symbol) ? key.to_s.tr("?!", "") : raise("keys should be Symbols only")
    end

    def encode_value(value)
      case value
      when String then value.to_str
      when Integer, Float, TrueClass, FalseClass, NilClass then value
      when Date then value.strftime("%F")
      when Time then value.strftime("%FT%T.%L%:z")
      else raise("Unsupported json encode class #{value.class}")
      end
    end

    def object_is_collection?(obj)
      obj.is_a?(Array) ||
        (defined?(ActiveRecord) &&
        (obj.is_a?(ActiveRecord::Associations::CollectionProxy) || obj.is_a?(ActiveRecord::Relation)))
    end
  end
end
