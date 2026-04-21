# Changelog for v1.2

## Colocated CSS

LiveView v1.2 introduces colocated CSS to allow writing CSS rules in the same file as your regular component code.

To use Colocated CSS, you need to implement the `Phoenix.LiveView.ColocatedCSS` behaviour. See the module documentation for more details.

Then, you can define it similar to how you would define a colocated hook or `Phoenix.LiveView.ColocatedJS`:

```elixir
def table(assigns) do
  ~H"""
  <style :type={MyAppWeb.ColocatedCSS}>
    thead color: {
      ...;
    }
    tbody, tr:hover {
      ...
    }
  </style>
  <table>...</table>
  """
end
```

## Formatting script and style tags

This behaviour allows you to format `<script>` and `<style>` tags with third party tooling
when running `mix format`, especially useful if your project uses `Phoenix.LiveView.ColocatedHook`
a lot.

The module documentation contains an example using [prettier](https://prettier.io/), which we also
use [in the LiveView repository itself](https://github.com/phoenixframework/phoenix_live_view/blob/main/lib/prettier.ex).

## Encoding JS commands to JSON

`Phoenix.LiveView.JS` structs can now be encoded to JSON for usage in `push_event`. So now you can do

```elixir
push_event(socket, "highlight", %{toggle: JS.toggle_class(...)})
```

```javascript
// some hook
this.handleEvent("highlight", ({ toggle }) => {
  this.js().execJS(this.el, toggle);
});
```

while in the past you'd have to render the command in an element attribute and
then refer back to it in your hook.

LiveView implements `JSON.Encoder` and `Jason.Encoder` automatically. If you use a different
library, you can invoke `JS.to_encodable/1` manually.

## Opting out of debug annotations

You can now opt out of HEEx debug annotations for specific modules by setting

```elixir
@debug_heex_annotations false
@debug_attributes false
```

as module attributes in the module that defines your HEEx template. The module
attributes override the application configuration:

```elixir
config :phoenix_live_view,
  debug_heex_annotations: true
  debug_attributes: true
```

This is useful if you render some templates for different purposes like email
where the comments and attributes LiveView adds for debugging in development are
a problem.

Here's an example that shows the debug annotations:

```html
<!-- @caller lib/demo_web/live/posts_live/index.ex:19 (demo) -->
<!-- <DemoWeb.CoreComponents.table> lib/demo_web/components/core_components.ex:362 (demo) -->
<table data-phx-loc="363" class="table table-zebra">
  <thead data-phx-loc="364">
    <tr data-phx-loc="365">
      <th data-phx-loc="366">Title</th>
      <th data-phx-loc="367">
        <span data-phx-loc="368" class="sr-only">Actions</span>
      </th>
    </tr>
  </thead>
  ...
```

The comments can be disabled with `debug_heex_annotations` and the `data-phx-loc` attributes with `debug_attributes`.

## v1.2.0-rc.0 (Unreleased)

### Enhancements

* Add `Phoenix.LiveView.ColocatedCSS`
* Deprecate the `:colocated_js` configuration in favor of `:colocated_assets`
* Add `phx-no-unused-field` to prevent sending `_unused` parameters to the server ([#3577](https://github.com/phoenixframework/phoenix_live_view/issues/3577))
* Add `Phoenix.LiveView.JS.to_encodable/1` pushing JS commands via events ([#4060](https://github.com/phoenixframework/phoenix_live_view/pull/4060))
  * `%JS{}` now also implements the `JSON.Encoder` and `Jason.Encoder` protocols
* HTMLFormatter: Better preserve whitespace around tags and inside inline elements ([#3718](https://github.com/phoenixframework/phoenix_live_view/issues/3718))
* HEEx: Allow to opt out of debug annotations for a module ([#4119](https://github.com/phoenixframework/phoenix_live_view/pull/4119))
* HEEx: warn when missing a space between attributes ([#3999](https://github.com/phoenixframework/phoenix_live_view/issues/3999))
* HTMLFormatter: Add `TagFormatter` behaviour for formatting `<style>` and `<script>` tags ([#4140](https://github.com/phoenixframework/phoenix_live_view/pull/4140))
* Performance optimizations in diffing hot path (Thank you [@preciz](https://github.com/preciz)!)

## v1.1

The CHANGELOG for v1.1 releases can be found [in the v1.1 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.1/CHANGELOG.md).
