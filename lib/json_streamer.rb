# frozen_string_literal: true

require "json"
require "oj"

require "json_streamer/base_json"
require "json_streamer/rails_json"

module JsonStreamer
  module_function

  def generate(template, object = BaseJson::NO_ARGUMENT, **options)
    if template.is_a?(Array)
      template.first.generate_collection(object, **options)
    else
      template.generate(object, **options)
    end
  end

  def create_new_stream
    Oj::StringWriter.new
  end
end
