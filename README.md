# jstreamer

Renders JSON directly to a stream from ruby templates.

[Full API Docs](http://dzirtusss.github.io/jstreamer/Jstreamer.html)

## Why?

- **Fast by design. Renders directly to string buffer** w/o building intermedium Hashes and calling `.to_json` on them.
Minimal RAM footprint on huge JSONs. Several optimizations for re-usable tasks (e.g. keys, partials).
Uses [Oj](https://github.com/ohler55/oj) for low-level streaming.

- **Simple ruby classes as templates** (or call them view models). Template must have only a `render` method.
All ruby power plus just a few well balanced DSL helpers. Easily extendable/configurable.

- **Fully integrated with Rails**. "Natural" seamless access to view and controller helpers like in other
rails view templates.

- Doesn't enforce data structure on generated JSON - can build any JSON in a JBuilder way,
not a JSON:API or some other serializer type.

- Many years in production environments.

- Can be used in parallel with any other libraries - code refactoring can be done slowly and seamlessly.

- Easier code maintenance, as, overall templates quantity is significantly decreased compared to typical solutions.

## Installing

```ruby
# In your Gemfile

gem "jstreamer"
```

## Usage

For full description and more detailed examles see [Full API Docs](http://dzirtusss.github.io/jstreamer/Jstreamer.html)

### Typical folder structure in Rails app

Just example, not required to follow.

```sh
/app
  /jsons
    applictaion_json.rb  # ApplicationJson < RailsJson   # for common configs and helpers
    some_json.rb         # SomeJson < ApplicationJson
    other_json.rb        # OtherJson < ApplicationJson
```

### Calling

```ruby
# As plain rendering

  json = SomeMyJson.generate(model)
  json = SomeMyJson.generate(model, notifications: [], view: :api)  # with options

  # collections are rarely or never needed to be called directly
  json = SomeMyJson.generate_collection(models)
  json = SomeMyJson.generate_collection(models, notifications: [], view: :api)  # with options

# from Rails controller actions

  def some_action
    # sugar for render(json: SomeMyJson.generate(model, view_context:))
    SomeMyJson.render(model, view_context:)
  end

  def some_action
    # sugar for render(json: SomeMyJson.generate_collection(models, view_context:))
    SomeMyJson.render_collection(models, view_context:)
  end

# from Jstreamer

  json = Jstreamer.generate(SomeJson, model, **options)       # render single object
  json = Jstreamer.generate([SomeMyJson], models, **options)  # render collection

# low-level

  json = SomeMyJson.new(**options).call(model).to_s
  json = SomeMyJson.new(**options).call_collection(models).to_s
```

### Template examples

```ruby
class SomeMyJson < ApplicationJson
  COMMON_PROPS = %i[id name title].freeze

  def render
    from(current_model, COMMON_PROPS)               # prop names are similar
    prop(:description, current_model.summary)       # prop name is different
    prop(:fetch_url, some_edit_url(current_model))  # calculated prop

    partial(:items, ItemsJson, current_model.items, **options)

    array(:notifications, options[:notifications]) do |notification|
      from(notification, :name, :level)
      prop(:idx, index)                     # e.g. array index
    end

    object(:api_props) if view?(:api)
  end

  def api_props
    prop(:some_api_specific_prop, 123)
  end
end

class ItemJson < ApplicationJson
  DEFAULT_PROPS = %[id name description price].freeze

  def render
    from(current_model, DEFAULT_PROPS)
  end
end
```

### Application config example
```ruby
class ApplicatoinJson < BaseJson
  def transform_key(key)
    super.camelize(:lower)        # camelize all keys
  end
end
```

### Rails integration
```ruby
# template
class SomeMyJson < ApplicationJson
  def render
    prop(:user_id, current_user.id)                    # controller methods integration
    prop(:profile_path, profile_path(current_user))    # view helpers integration
    prop(:abc, view_context_get(:@notifications))      # variables integration
  end
end

# api controller
class MyApiController
  def show
    SomeMyJson.render(model, view_context:)
  end
end

# page controller
class MyPageController
  def show
    @props_json = SomeMyJson.generate(model, view_context:)
  end
end

# Example JBuilder templates sugar helpers (e.g. of parallel usage)

json.owner render_jstreamer_hash(UserJson, current_user)
json.items render_jstreamer_hash([Item], items, some_options:)
```

### Template's DSL quick-reference

For full description and more detailed examles see [Full API Docs](http://dzirtusss.github.io/jstreamer/Jstreamer.html)

```ruby

# Push a single property to stream

  prop(:key, value)

# Extract properties from model or hash and push to stream

  # inline
  from(model, :key1, :key2)

  # with array
  KEYS = %i[key1 key2]

  from(model, KEYS)
  from(model, *KEYS)

# Push object to stream

  # with method
  object(:key)

  def key
    ...
  end

  # with block
  object(:key) do
    ...
  end

# Push array to stream

  # with method
  array(:key, array_of_items)

  def key(item)
    ...
  end

  # with block
  array(:key, array_of_items) do |item|
    ...
  end

# Push partial (another json streamer class) to stream

  # typical usage for a single object streaming
  class MainJson
    def render
      partial(:item, ItemJson, current_model.item, **options)
    end
  end

  class ItemJson
    def render
      prop(...)
    end
  end

  # collection
  class MainJson
    def render
      partial(:items, [ItemJson], current_model.items, **options)
    end
  end

  # collection with caching - uses cache_type: :local (memoization)
  class MainJson
    def render
      partial(:items, [ItemJson], current_model.items, cache_key:, cache_type: :local, **options)
    end
  end

  # more complex - uses lambda when need to skip execution
  class MainJson
    def render
      partial(:user, UserJson, -> { current_model.user.decorate }, cache_key:, cache_type: :local, **options)
    end
  end

  Jstreamer.generate([MainJson], models, **options)

# Push json directly (from string)

  merge_json(json)
```

### Helpers Quick-reference

For full description and more detailed examles see [Full API Docs](http://dzirtusss.github.io/jstreamer/Jstreamer.html)

```ruby
# Conditionally render views
  def render
    ...

    if view?(:api_v1, :api_v2)
      ...
    end
  end

# Delegate methods to options
  class SomeJson < ApplicationJson
    delegated_options :slug

    def render
      options[:slug]
      slug            # same as above
    end
  end
```

## License

[MIT](LICENSE)
