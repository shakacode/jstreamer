# frozen_string_literal: true

module JsonStreamer
  class BaseJson # rubocop:todo Metrics/ClassLength
    NO_ARGUMENT = Object.new

    # TODO: add Scout instrumentation
    # include ScoutApm::Tracer
    # def self.generate(obj = NO_ARGUMENT, **opts)
    #   instrument("JsonStreamer", name) do
    #     new(**opts).call(obj).to_s
    #   end
    # end

    def self.generate(obj = NO_ARGUMENT, **opts)
      new(**opts).call(obj).to_s
    end

    def self.generate_collection(collection, **opts)
      new(**opts).call_collection(collection).to_s
    end

    def self.delegated_options(*opts)
      opts.each do |opt|
        define_method(opt) { options.fetch(opt) }
      end
    end

    def initialize(stream = nil, **opts)
      @current_stream = stream || create_new_stream
      @options = opts
      @local_cache = {}
    end

    attr_reader :current_model, :current_stream, :index, :options

    def call(obj = NO_ARGUMENT)
      @current_model = obj
      current_stream.push_object
      render
      current_stream.pop
      self
    end

    def call_collection(collection)
      current_stream.push_array
      collection.each_with_index do |obj, index|
        @index = index
        call(obj)
      end
      current_stream.pop
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
      klass,
      klass_obj = NO_ARGUMENT,
      cache_key: nil,
      cache_type: :local,
      **klass_opts,
      &block
    )
      normalized_key = normalized_key(key)
      current_stream.push_key(normalized_key)

      if cache_key.nil?
        execute_partial(current_stream, klass, klass_obj, **klass_opts, &block)
        return
      end

      cache_result =
        case cache_type
        when :local
          @local_cache[normalized_key] ||= {}
          @local_cache[normalized_key][cache_key] ||=
            execute_partial(create_new_stream, klass, klass_obj, **klass_opts, &block).to_s.chomp
        when :rails
          Rails.cache.fetch(cache_key) do
            execute_partial(create_new_stream, klass, klass_obj, **klass_opts, &block).to_s.chomp
          end
        else
          raise "Unknown cache_type #{cache_type}"
        end

      current_stream.push_json(cache_result)
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

    def create_new_stream
      JsonStreamer.create_new_stream
    end

    def execute_partial(stream, klass, klass_obj, **klass_opts, &block)
      if block
        klass_obj = yield
      elsif klass_obj == NO_ARGUMENT
        klass_obj = current_model
      end

      if klass.is_a?(Array)
        klass.first.new(stream, **klass_opts).call_collection(klass_obj)
      else
        klass.new(stream, **klass_opts).call(klass_obj)
      end
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
  end
end
