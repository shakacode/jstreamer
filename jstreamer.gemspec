# frozen_string_literal: true

require_relative "lib/jstreamer/version"

Gem::Specification.new do |spec|
  spec.name        = "jstreamer"
  spec.version     = Jstreamer::VERSION
  spec.author      = "Sergey Tarasov"
  spec.email       = "sergey@shakacode.com"

  spec.summary     = "Jstreamer - renders JSON directly to a stream from ruby templates"
  spec.description = "Jstreamer - renders JSON directly to a stream from ruby templates"
  spec.homepage    = "https://github.com/shakacode/jstreamer"
  spec.license     = "MIT"

  spec.files       = Dir["lib/**/*.rb"]

  spec.required_ruby_version = ">= 3.1.0"

  spec.add_dependency "json"
  spec.add_dependency "oj"

  spec.metadata["rubygems_mfa_required"] = "true"
end
