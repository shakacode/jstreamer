# frozen_string_literal: true

module JsonStreamer
  class RailsJson < BaseJson
    def self.render(obj = nil, **opts)
      opts.fetch(:view_context).controller.render(json: generate(obj, **opts))
    end

    def self.render_collection(collection, **opts)
      opts.fetch(:view_context).controller.render(json: generate_collection(collection, **opts))
    end

    # NOTE: useful view_context injection discussion
    # https://github.com/drapergem/draper/issues/124
    def view_context
      options.fetch(:view_context)
    end

    def method_missing(method, ...)
      return super if view_context.nil? || !view_context.respond_to?(method)

      # TODO: analogue of self.class.delegate(method, to: :view_context)
      self.class.define_method(method) do |*args|
        view_context.__send__(method, *args)
      end

      public_send(method, ...)
    end

    def respond_to_missing?(method, *)
      (!view_context.nil? && view_context.respond_to?(method)) || super
    end

    def view_context_get(var_name)
      view_context.instance_variable_get(var_name)
    end
  end
end
