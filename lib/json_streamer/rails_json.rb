# frozen_string_literal: true

module JsonStreamer
  # Rails extensions class - provides some helpers methods:
  # - view methods delegation
  # - view variables access
  # - render helpers
  # @example In controller
  #   class MyApiController
  #     def show1
  #       SomeJson.render(model, view_context:)    # we always need to provide view_context for rails magic to work
  #     end
  #
  #     def show2
  #       render(json: SomeJson.generate(model, view_context:)) # this is actually sugar equivalent of above
  #     end
  #   end
  # @example In template
  #   class SomeMyJson < RailsJson
  #     def render
  #       # all methods are automatically coming from view context
  #
  #       prop(:about_path, about_path)               # view helpers
  #       prop(:user_id, current_user.id)             # controller methods
  #
  #       view_context_get(:@notifications)           # variables are not magically added, they need a method
  #     end
  #   end
  class RailsJson < BaseJson
    # Helper to call controller's render method on a single object
    # @param obj [Object] data object
    # @param opts [kwargs] options
    def self.render(obj = nil, **opts)
      opts.fetch(:view_context).controller.render(json: generate(obj, **opts))
    end

    # Helper to call controller's render method on a collection
    # @param collection [Array]
    # @param opts [kwargs] options
    def self.render_collection(collection, **opts)
      opts.fetch(:view_context).controller.render(json: generate_collection(collection, **opts))
    end

    # Returns view_context provided in options
    # @return [view_context]
    def view_context
      # NOTE: useful view_context injection discussion
      # https://github.com/drapergem/draper/issues/124
      options.fetch(:view_context)
    end

    # Gets instance variable value from view_context
    # @param var_name [Symbol] variable name as :@abc
    # @return variable value
    def view_context_get(var_name)
      view_context.instance_variable_get(var_name)
    end

    private

    # Automatically delegates methods to view_context provided in options
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
  end
end
