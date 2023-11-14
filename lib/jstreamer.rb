# frozen_string_literal: true

require "json"
require "oj"

require "jstreamer/base_json"
require "jstreamer/rails_json"

# Renders JSON directly to a stream from ruby templates.
# @example Default calling examples
#   json = SomeMyJson.generate(model)
#   json = SomeMyJson.generate(model, notifications: [], view: :api)  # with options
#
#   json = SomeMyJson.generate_collection(models)    # collections are rarely or never needed to be called directly
#
# @example Template example
#   class SomeMyJson < ApplicationJson
#     COMMON_PROPS = %i[id name title].freeze
#
#     def render
#       from(current_model, COMMON_PROPS)               # prop names are similar
#       prop(:description, current_model.summary)       # prop name is different
#       prop(:fetch_url, some_edit_url(current_model))  # calculated prop
#
#       partial(:items, ItemsJson, current_model.items, **options)
#
#       array(:notifications, options[:notifications]) do |notification|
#         from(notification, :name, :level)
#         prop(:idx, index)                     # e.g. array index
#       end
#
#       object(:api_props) if view?(:api)
#     end
#
#     def api_props
#       prop(:some_api_specific_prop, 123)
#     end
#   end
#
# @example Partial example (actually totally same logic as template)
#   class ItemJson < ApplicationJson
#     DEFAULT_PROPS = %[id name description price].freeze
#
#     def render
#       from(current_model, DEFAULT_PROPS)
#     end
#   end
#
# @example Application config or common helpers example
#   class ApplicatoinJson < BaseJson
#     def transform_key(key)
#       super.camelize(:lower)        # camelize all keys
#     end
#   end
# @example Rails integration
#   class MyApiController
#     def show
#       SomeMyJson.render(model, view_context:)
#     end
#   end
#
#   class SomeMyJson < ApplicationJson
#     def render
#       prop(:user_id, current_user.id)                    # controller methods integration
#       prop(:profile_path, profile_path(current_user))    # view helpers integration
#       prop(:abc, view_context_get(:@notifications))      # variables integration
#     end
#   end
module Jstreamer
  module_function

  # Default error class for errors raised by the gem
  class Error < StandardError; end

  # Generates json for a template (either sole or collection)
  # @param template [Class] name of jstreamer class
  # @param object [Object] object to render
  # @param options [kwargs]
  def generate(template, object = nil, **options)
    if template.is_a?(Array)
      template.first.generate_collection(object, **options)
    else
      template.generate(object, **options)
    end
  end

  # Creates new stream (low-level engine)
  # @return stream low-level engine
  def create_new_stream
    Oj::StringWriter.new
  end
end
